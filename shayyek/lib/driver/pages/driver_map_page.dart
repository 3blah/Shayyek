import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_text.dart';
import '../../config.dart';
import '../services/driver_navigation_service.dart';
import '../services/driver_task_service.dart';
import '../ui/driver_palette.dart';
import '../ui/driver_shared_widgets.dart';

class DriverMapPage extends StatefulWidget {
  const DriverMapPage({
    super.key,
    required this.lots,
    required this.selectedLotId,
    required this.liveLots,
    required this.selectedLotCameras,
    required this.favoriteLotIds,
    required this.preferences,
    required this.stalls,
    required this.announcements,
    required this.onRefresh,
    required this.onSelectLot,
    required this.onToggleFavorite,
    required this.onUpdatePreferences,
    required this.onNavigateToStall,
    this.currentLat,
    this.currentLong,
    this.showTileLayer = true,
    this.errorText,
  });

  final List<DriverLot> lots;
  final String? selectedLotId;
  final Map<String, DriverLiveLot> liveLots;
  final List<DriverLotCamera> selectedLotCameras;
  final Set<String> favoriteLotIds;
  final DriverPreferences preferences;
  final List<DriverStall> stalls;
  final List<DriverAnnouncement> announcements;
  final Future<void> Function() onRefresh;
  final void Function(String lotId) onSelectLot;
  final void Function(String lotId) onToggleFavorite;
  final Future<void> Function(DriverPreferences preferences)
      onUpdatePreferences;
  final Future<void> Function(DriverStall stall, int reservedMinutes)
      onNavigateToStall;
  final double? currentLat;
  final double? currentLong;
  final bool showTileLayer;
  final String? errorText;

  @override
  State<DriverMapPage> createState() => _DriverMapPageState();
}

class _DriverMapPageState extends State<DriverMapPage> {
  final MapController _mapController = MapController();
  final DriverNavigationService _navigationService = DriverNavigationService();
  final TextEditingController _searchController = TextEditingController();

  bool _freeOnly = true;
  bool _savingFilters = false;
  bool _loadingRoute = false;
  bool _searchingPlaces = false;
  bool _isMapReady = false;
  int _cameraPreviewTick = 0;

  Timer? _routeDebounce;
  Timer? _cameraPreviewTimer;
  DriverRoutePath? _routePath;
  DriverSearchPlace? _searchedPlace;
  LatLng? _pendingMapCenter;
  double? _pendingMapZoom;

  DriverLotCamera? get _selectedCamera {
    if (widget.selectedLotCameras.isEmpty) {
      return null;
    }
    return widget.selectedLotCameras.first;
  }

  DriverLot? get _selectedLot {
    final lotId = widget.selectedLotId?.trim() ?? '';
    if (lotId.isEmpty) {
      return widget.lots.isEmpty ? null : widget.lots.first;
    }
    for (final lot in widget.lots) {
      if (lot.id == lotId) {
        return lot;
      }
    }
    return widget.lots.isEmpty ? null : widget.lots.first;
  }

  List<DriverStall> _filterStalls(List<DriverStall> stalls) {
    return stalls.where((stall) {
      if (_freeOnly && !stall.isFree) {
        return false;
      }
      if (widget.preferences.filterAccessible && !stall.accessible) {
        return false;
      }
      if (widget.preferences.filterEv && !stall.ev) {
        return false;
      }
      if (stall.maxStay > 0 &&
          stall.maxStay > widget.preferences.filterMaxStayMin) {
        return false;
      }
      if (stall.rateHou > 0 &&
          stall.rateHou > widget.preferences.filterPriceMax) {
        return false;
      }
      return true;
    }).toList();
  }

  LatLng get _fallbackCenter {
    final selected = _selectedLot;
    if (selected != null) {
      return LatLng(selected.lat, selected.long);
    }
    if (widget.lots.isNotEmpty) {
      final first = widget.lots.first;
      return LatLng(first.lat, first.long);
    }
    return LatLng(16.8892, 42.5511);
  }

  LatLng? get _currentPoint {
    if (widget.currentLat == null || widget.currentLong == null) {
      return null;
    }
    return LatLng(widget.currentLat!, widget.currentLong!);
  }

  @override
  void initState() {
    super.initState();
    _cameraPreviewTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraPreviewTick++;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _moveToSelectedLot();
      _scheduleRouteRefresh();
    });
  }

  @override
  void didUpdateWidget(covariant DriverMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lotChanged = oldWidget.selectedLotId != widget.selectedLotId;
    final locationChanged = oldWidget.currentLat != widget.currentLat ||
        oldWidget.currentLong != widget.currentLong;
    if (lotChanged ||
        locationChanged ||
        oldWidget.lots.length != widget.lots.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _moveToSelectedLot();
        _scheduleRouteRefresh();
      });
    }
  }

  @override
  void dispose() {
    _isMapReady = false;
    _routeDebounce?.cancel();
    _cameraPreviewTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updatePreferences(DriverPreferences next) async {
    setState(() => _savingFilters = true);
    try {
      await widget.onUpdatePreferences(next);
    } finally {
      if (mounted) {
        setState(() => _savingFilters = false);
      }
    }
  }

  void _moveToSelectedLot() {
    final selected = _selectedLot;
    if (selected == null) {
      return;
    }
    _moveMapSafely(LatLng(selected.lat, selected.long), 16);
  }

  void _moveMapSafely(LatLng center, double zoom) {
    _pendingMapCenter = center;
    _pendingMapZoom = zoom;
    if (!mounted || !_isMapReady) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isMapReady) {
        return;
      }
      final pendingCenter = _pendingMapCenter;
      final pendingZoom = _pendingMapZoom;
      if (pendingCenter == null || pendingZoom == null) {
        return;
      }

      try {
        _mapController.move(pendingCenter, pendingZoom);
      } catch (_) {
        return;
      }
    });
  }

  void _flushPendingMapMove() {
    final pendingCenter = _pendingMapCenter;
    final pendingZoom = _pendingMapZoom;
    if (pendingCenter == null || pendingZoom == null) {
      return;
    }
    _moveMapSafely(pendingCenter, pendingZoom);
  }

  void _selectLotAndMove(DriverLot lot, {double zoom = 16}) {
    widget.onSelectLot(lot.id);
    _moveMapSafely(LatLng(lot.lat, lot.long), zoom);
    _scheduleRouteRefresh();
  }

  void _scheduleRouteRefresh() {
    _routeDebounce?.cancel();
    _routeDebounce = Timer(
      const Duration(milliseconds: 350),
      _refreshRoute,
    );
  }

  Future<void> _refreshRoute() async {
    final origin = _currentPoint;
    final selected = _selectedLot;
    if (!mounted) {
      return;
    }
    if (origin == null || selected == null) {
      setState(() {
        _routePath = null;
        _loadingRoute = false;
      });
      return;
    }

    setState(() => _loadingRoute = true);
    try {
      final route = await _navigationService.buildRoute(
        origin: origin,
        destination: LatLng(selected.lat, selected.long),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _routePath = route;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _routePath = DriverRoutePath(
          points: <LatLng>[origin, LatLng(selected.lat, selected.long)],
          distanceMeters: const Distance().as(
            LengthUnit.Meter,
            origin,
            LatLng(selected.lat, selected.long),
          ),
          isFallback: true,
          notice: AppText.of(
            context,
            ar: 'تعذر تحميل المسار الفعلي، لذلك تم عرض خط مباشر مؤقتاً.',
            en: 'Unable to load the road route, so a direct fallback line is shown.',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loadingRoute = false);
      }
    }
  }

  Future<void> _searchPlaces() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }

    setState(() => _searchingPlaces = true);
    try {
      final results = await _navigationService.searchPlaces(query);
      if (!mounted) {
        return;
      }
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppText.of(
                context,
                ar: 'لم يتم العثور على نتيجة لهذا البحث.',
                en: 'No places were found for this search.',
              ),
            ),
          ),
        );
        return;
      }

      final selected = await showModalBottomSheet<DriverSearchPlace>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return SafeArea(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemBuilder: (context, index) {
                final place = results[index];
                return ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(place.title),
                  subtitle: Text(
                    place.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.of(context).pop(place),
                );
              },
              separatorBuilder: (_, __) => const Divider(),
              itemCount: results.length,
            ),
          );
        },
      );

      if (selected == null || !mounted) {
        return;
      }

      setState(() {
        _searchedPlace = selected;
      });
      _moveMapSafely(selected.point, 15);
    } finally {
      if (mounted) {
        setState(() => _searchingPlaces = false);
      }
    }
  }

  String _estimatedMaxCharge(DriverStall stall) {
    if (stall.rateHou <= 0) {
      return AppText.of(context, ar: 'غير متوفر', en: 'Unavailable');
    }
    final maxMinutes = stall.maxStay <= 0 ? 60 : stall.maxStay;
    final total = stall.rateHou * (maxMinutes / 60);
    return AppText.of(
      context,
      ar: '${total.toStringAsFixed(2)} ${stall.currency} حتى الحد الأقصى',
      en: '${total.toStringAsFixed(2)} ${stall.currency} up to the time limit',
    );
  }

  String _pricePerMinute(DriverStall stall) {
    final perMinute = stall.rateHou <= 0 ? 0 : stall.rateHou / 60;
    return AppText.of(
      context,
      ar: '${perMinute.toStringAsFixed(2)} ${stall.currency}/دقيقة',
      en: '${perMinute.toStringAsFixed(2)} ${stall.currency}/min',
    );
  }

  String? _snapshotUrlFor(DriverLotCamera camera) {
    final base = camera.resolvedSnapshotUrl?.trim() ?? '';
    if (base.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(base);
    if (uri == null) {
      return base;
    }
    final updatedQuery = Map<String, String>.from(uri.queryParameters)
      ..['ts'] = _cameraPreviewTick.toString();
    return uri.replace(queryParameters: updatedQuery).toString();
  }

  Future<void> _openLiveStream(DriverLotCamera camera) async {
    final snapshotUrl = camera.resolvedSnapshotUrl?.trim() ?? '';
    final streamUrl = camera.resolvedStreamUrl?.trim() ?? '';
    if (snapshotUrl.isEmpty && streamUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppText.of(
              context,
              ar: 'لا يوجد رابط بث حي مضبوط لهذه الكاميرا.',
              en: 'No live stream URL is configured for this camera.',
            ),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final palette = DriverPalette.of(
          Theme.of(context).brightness == Brightness.dark,
        );
        final cameraStalls = widget.stalls
            .where((stall) => stall.lotId == camera.lotId)
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));
        final live = widget.liveLots[camera.lotId];
        final freeCount = live?.free ??
            cameraStalls
                .where((stall) => stall.isFree && !stall.reserved)
                .length;
        final occupiedCount = live?.occupied ??
            cameraStalls
                .where((stall) => !stall.isFree || stall.reserved)
                .length;
        final totalCount = live?.total ??
            (cameraStalls.isNotEmpty
                ? cameraStalls.length
                : freeCount + occupiedCount);
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppText.of(
                      context,
                      ar: 'البث الحي للموقف',
                      en: 'Live parking camera',
                    ),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PrivacyLiveCameraView(
                    snapshotUrl: snapshotUrl,
                    streamUrl: streamUrl,
                    palette: palette,
                    live: live,
                  ),
                  const SizedBox(height: 10),
                  _DriverCameraAvailabilityCard(
                    free: freeCount,
                    occupied: occupiedCount,
                    total: totalCount,
                    updatedAt: live?.ts,
                    palette: palette,
                  ),
                  const SizedBox(height: 10),
                  DriverInfoCard(
                    title: AppText.of(context,
                        ar: 'خصوصية البث', en: 'Stream privacy'),
                    body: AppText.of(
                      context,
                      ar: 'يتم عرض البث داخل التطبيق مع طبقة طمس للوجوه واللوحات. لو تم ضبط رابط redacted_snapshot_url من خادم الذكاء الاصطناعي سيتم استخدامه تلقائياً بدلاً من الرابط الخام.',
                      en: 'The in-app stream is shown with a privacy mask over faces and plates. If a redacted_snapshot_url is configured by the AI bridge, it is used automatically instead of the raw camera URL.',
                    ),
                    icon: Icons.privacy_tip_outlined,
                    color: palette.secondary,
                  ),
                  if (cameraStalls.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      AppText.of(
                        context,
                        ar: 'اختر موقفاً من هذه الكاميرا',
                        en: 'Choose a stall from this camera',
                      ),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...cameraStalls.map((stall) {
                      final isFree = stall.isFree && !stall.reserved;
                      final stateText = stall.reserved
                          ? AppText.of(context, ar: 'محجوز', en: 'Reserved')
                          : stall.isFree
                              ? AppText.of(context, ar: 'فارغ', en: 'Free')
                              : stall.isOccupied
                                  ? AppText.of(
                                      context,
                                      ar: 'مشغول',
                                      en: 'Occupied',
                                    )
                                  : AppText.of(
                                      context,
                                      ar: 'غير معروف',
                                      en: 'Unknown',
                                    );
                      final perMinute =
                          stall.rateHou <= 0 ? 0 : stall.rateHou / 60;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: palette.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isFree
                                  ? palette.available.withOpacity(0.35)
                                  : palette.border.withOpacity(0.45),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isFree
                                    ? Icons.local_parking_rounded
                                    : Icons.block_rounded,
                                color: isFree
                                    ? palette.available
                                    : palette.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${stall.label} • $stateText',
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      AppText.of(
                                        context,
                                        ar: '${perMinute.toStringAsFixed(2)} ${stall.currency}/دقيقة',
                                        en: '${perMinute.toStringAsFixed(2)} ${stall.currency}/min',
                                      ),
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton(
                                onPressed: isFree
                                    ? () {
                                        Navigator.of(context).pop();
                                        _reserveStallWithDuration(stall);
                                      }
                                    : null,
                                child: Text(
                                  AppText.of(
                                    context,
                                    ar: 'احجز',
                                    en: 'Reserve',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  if (streamUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final uri = Uri.tryParse(streamUrl);
                          if (uri != null) {
                            launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.open_in_browser_rounded),
                        label: Text(
                          AppText.of(
                            context,
                            ar: 'فتح رابط Arduino الخام',
                            en: 'Open raw Arduino stream',
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSelectedCamera() async {
    final camera = _selectedCamera;
    if (camera == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppText.of(
              context,
              ar: 'لا توجد كاميرا مرتبطة بهذا الموقف.',
              en: 'No camera is linked to this lot.',
            ),
          ),
        ),
      );
      return;
    }
    await _openLiveStream(camera);
  }

  Future<void> _openAllLotsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final palette = DriverPalette.of(
          Theme.of(context).brightness == Brightness.dark,
        );
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.38,
            maxChildSize: 0.92,
            builder: (context, controller) {
              return ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                itemBuilder: (context, index) {
                  final lot = widget.lots[index];
                  final live = widget.liveLots[lot.id] ??
                      DriverLiveLot(
                        lotId: lot.id,
                        free: 0,
                        occupied: 0,
                        total: 0,
                        degradedMode: false,
                        ts: null,
                        stalls: const <String, DriverLiveStall>{},
                      );
                  final distanceText = lot.distanceKm == null
                      ? AppText.of(context,
                          ar: 'المسافة غير متوفرة', en: 'Distance unavailable')
                      : AppText.of(
                          context,
                          ar: '${lot.distanceKm!.toStringAsFixed(1)} كم منك',
                          en: '${lot.distanceKm!.toStringAsFixed(1)} km away',
                        );
                  return DriverInfoCard(
                    title: lot.name,
                    body:
                        '${lot.address}\n$distanceText\n${AppText.of(context, ar: 'فارغ', en: 'Free')}: ${live.free} | ${AppText.of(context, ar: 'غير فارغ', en: 'Unavailable')}: ${live.occupied}\n${AppText.of(context, ar: 'السعر بالدقيقة', en: 'Per-minute price')}: ${(lot.rateHou / 60).toStringAsFixed(2)} ${lot.currency}',
                    icon: Icons.local_parking_rounded,
                    color: live.free > 0 ? palette.available : palette.occupied,
                    action: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _selectLotAndMove(lot);
                          },
                          icon: const Icon(Icons.map_outlined),
                          label: Text(
                            AppText.of(context,
                                ar: 'افتح على الخريطة', en: 'Open on map'),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _selectLotAndMove(lot);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                _openSelectedCamera();
                              }
                            });
                          },
                          icon: const Icon(Icons.videocam_outlined),
                          label: Text(
                            AppText.of(context,
                                ar: 'فتح المواقف مباشرة',
                                en: 'Open live stalls'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: widget.lots.length,
              );
            },
          ),
        );
      },
    );
  }

  DriverLot? _bestLot() {
    if (widget.lots.isEmpty) {
      return null;
    }
    for (final lot in widget.lots) {
      final live = widget.liveLots[lot.id];
      if ((live?.free ?? 0) > 0) {
        return lot;
      }
    }
    return widget.lots.first;
  }

  Future<void> _reserveStallWithDuration(DriverStall stall) async {
    final maxMinutes = stall.maxStay <= 0 ? 240 : stall.maxStay;
    var selectedMinutes = maxMinutes < 30 ? maxMinutes : 30;
    if (selectedMinutes < 1) {
      selectedMinutes = 1;
    }

    final minutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final palette = DriverPalette.of(
          Theme.of(context).brightness == Brightness.dark,
        );
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final ratePerMinute = stall.rateHou <= 0 ? 0 : stall.rateHou / 60;
            final total = ratePerMinute * selectedMinutes;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppText.of(
                        context,
                        ar: 'حدد مدة الحجز',
                        en: 'Choose booking duration',
                      ),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DriverInfoCard(
                      title: stall.label,
                      body: AppText.of(
                        context,
                        ar: 'المدة: $selectedMinutes دقيقة\nالسعر التقديري: ${total.toStringAsFixed(2)} ${stall.currency}',
                        en: 'Duration: $selectedMinutes min\nEstimated price: ${total.toStringAsFixed(2)} ${stall.currency}',
                      ),
                      icon: Icons.timer_outlined,
                      color: palette.primary,
                    ),
                    const SizedBox(height: 10),
                    Slider(
                      value: selectedMinutes.toDouble(),
                      min: 1,
                      max: maxMinutes.toDouble(),
                      divisions: maxMinutes > 1 ? maxMinutes - 1 : null,
                      label: '$selectedMinutes',
                      onChanged: (value) {
                        setSheetState(() {
                          selectedMinutes = value.round().clamp(1, maxMinutes);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pop(selectedMinutes),
                        icon: const Icon(Icons.lock_clock_rounded),
                        label: Text(
                          AppText.of(
                            context,
                            ar: 'تأكيد الحجز',
                            en: 'Confirm booking',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (minutes == null) {
      return;
    }
    await widget.onNavigateToStall(stall, minutes);
  }

  Future<void> _openStallSheet(DriverStall stall) async {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppText.of(
                    context,
                    ar: 'تفاصيل ${stall.label}',
                    en: '${stall.label} details',
                  ),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                DriverLabelValue(
                  label: AppText.of(context, ar: 'الحالة', en: 'Status'),
                  value: stall.isFree
                      ? AppText.of(context, ar: 'متاح', en: 'Free')
                      : stall.isOccupied
                          ? AppText.of(context, ar: 'مشغول', en: 'Occupied')
                          : stall.state,
                ),
                const SizedBox(height: 10),
                DriverLabelValue(
                  label: AppText.of(context, ar: 'السعر', en: 'Price'),
                  value: AppText.of(
                    context,
                    ar: '${stall.rateHou.toStringAsFixed(1)} ${stall.currency}/ساعة',
                    en: '${stall.rateHou.toStringAsFixed(1)} ${stall.currency}/hour',
                  ),
                ),
                const SizedBox(height: 10),
                DriverLabelValue(
                  label: AppText.of(context,
                      ar: 'سعر الدقيقة', en: 'Per-minute price'),
                  value: _pricePerMinute(stall),
                ),
                const SizedBox(height: 10),
                DriverLabelValue(
                  label: AppText.of(context, ar: 'الحد الأقصى', en: 'Max stay'),
                  value: AppText.of(
                    context,
                    ar: '${stall.maxStay} دقيقة',
                    en: '${stall.maxStay} min',
                  ),
                ),
                const SizedBox(height: 10),
                DriverLabelValue(
                  label: AppText.of(
                    context,
                    ar: 'التكلفة التقديرية',
                    en: 'Estimated amount',
                  ),
                  value: _estimatedMaxCharge(stall),
                ),
                const SizedBox(height: 10),
                DriverLabelValue(
                  label:
                      AppText.of(context, ar: 'ذوي الإعاقة', en: 'Accessible'),
                  value: stall.accessible
                      ? AppText.of(context, ar: 'نعم', en: 'Yes')
                      : AppText.of(context, ar: 'لا', en: 'No'),
                ),
                const SizedBox(height: 10),
                DriverLabelValue(
                  label: 'EV',
                  value: stall.ev
                      ? AppText.of(context, ar: 'نعم', en: 'Yes')
                      : AppText.of(context, ar: 'لا', en: 'No'),
                ),
                const SizedBox(height: 10),
                DriverLabelValue(
                  label: AppText.of(context, ar: 'محجوز', en: 'Reserved'),
                  value: stall.reserved
                      ? AppText.of(context, ar: 'نعم', en: 'Yes')
                      : AppText.of(context, ar: 'لا', en: 'No'),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: stall.isFree
                        ? () async {
                            Navigator.of(context).pop();
                            await _reserveStallWithDuration(stall);
                          }
                        : null,
                    icon: const Icon(Icons.navigation_outlined),
                    label: Text(
                      AppText.of(
                        context,
                        ar: 'احجز هذا الموقف وابدأ الملاحة',
                        en: 'Reserve this stall and continue to payment',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Marker> _buildMarkers(BuildContext context) {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final markers = <Marker>[];
    final selectedLotId = _selectedLot?.id;

    for (final lot in widget.lots) {
      final live = widget.liveLots[lot.id] ??
          DriverLiveLot(
            lotId: lot.id,
            free: 0,
            occupied: 0,
            total: 0,
            degradedMode: false,
            ts: null,
            stalls: const <String, DriverLiveStall>{},
          );
      final isSelected = selectedLotId == lot.id;
      final markerColor = live.free > 0
          ? palette.available
          : live.occupied > 0
              ? palette.occupied
              : palette.secondary;

      markers.add(
        Marker(
          width: 96,
          height: 86,
          point: LatLng(lot.lat, lot.long),
          builder: (context) {
            return GestureDetector(
              onTap: () {
                _selectLotAndMove(lot);
                Future<void>.delayed(const Duration(milliseconds: 180), () {
                  if (mounted) {
                    _openSelectedCamera();
                  }
                });
              },
              child: _LotMarker(
                title: lot.name,
                free: live.free,
                occupied: live.occupied,
                color: markerColor,
                isSelected: isSelected,
              ),
            );
          },
        ),
      );
    }

    final currentPoint = _currentPoint;
    if (currentPoint != null) {
      markers.add(
        Marker(
          width: 52,
          height: 52,
          point: currentPoint,
          builder: (context) => _PinMarker(
            color: palette.primary,
            icon: Icons.my_location_rounded,
            label: AppText.of(context, ar: 'أنت', en: 'You'),
          ),
        ),
      );
    }

    if (_searchedPlace != null) {
      markers.add(
        Marker(
          width: 56,
          height: 56,
          point: _searchedPlace!.point,
          builder: (context) => _PinMarker(
            color: Colors.orange,
            icon: Icons.search_rounded,
            label: AppText.of(context, ar: 'نتيجة', en: 'Result'),
          ),
        ),
      );
    }

    return markers;
  }

  String _formatDistance(double? meters) {
    if (meters == null) {
      return AppText.of(context, ar: 'غير متوفر', en: 'Unavailable');
    }
    if (meters < 1000) {
      return AppText.of(
        context,
        ar: '${meters.round()} م',
        en: '${meters.round()} m',
      );
    }
    return AppText.of(
      context,
      ar: '${(meters / 1000).toStringAsFixed(1)} كم',
      en: '${(meters / 1000).toStringAsFixed(1)} km',
    );
  }

  String _formatDuration(double? seconds) {
    if (seconds == null || seconds <= 0) {
      return AppText.of(context, ar: 'غير متوفر', en: 'Unavailable');
    }
    final totalMinutes = (seconds / 60).ceil();
    if (totalMinutes < 60) {
      return AppText.of(
        context,
        ar: '$totalMinutes دقيقة',
        en: '$totalMinutes min',
      );
    }
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return AppText.of(
      context,
      ar: '$hours س ${minutes.toString().padLeft(2, '0')} د',
      en: '$hours h ${minutes.toString().padLeft(2, '0')} min',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final selectedLot = _selectedLot;
    final selectedLive = selectedLot == null
        ? null
        : widget.liveLots[selectedLot.id] ??
            DriverLiveLot(
              lotId: selectedLot.id,
              free: 0,
              occupied: 0,
              total: widget.stalls.length,
              degradedMode: false,
              ts: null,
              stalls: const <String, DriverLiveStall>{},
            );
    final filteredStalls = _filterStalls(widget.stalls);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          DriverTopHeader(
            title:
                AppText.of(context, ar: 'الخريطة والمواقف', en: 'Map and lots'),
            subtitle: AppText.of(
              context,
              ar: 'خريطة OpenStreetMap حية مع موقعك الحالي ومسار إلى الموقف المحدد وأعداد الفارغ والمشغول.',
              en: 'A live OpenStreetMap view with your current position, lot route, and free/occupied counts.',
            ),
            icon: Icons.map_rounded,
          ),
          if (widget.errorText != null) ...[
            const SizedBox(height: 14),
            DriverInfoCard(
              title: AppText.of(context,
                  ar: 'خطأ في البيانات الحية', en: 'Live data error'),
              body: widget.errorText!,
              icon: Icons.error_outline_rounded,
              color: palette.occupied,
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchPlaces(),
            decoration: InputDecoration(
              hintText: AppText.of(
                context,
                ar: 'ابحث عن مكان أو عنوان أو رمز بريدي',
                en: 'Search a place, address, or postal code',
              ),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchingPlaces
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      onPressed: _searchPlaces,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              filled: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.lots.isEmpty ? null : _openAllLotsSheet,
              icon: const Icon(Icons.list_alt_rounded),
              label: Text(
                AppText.of(
                  context,
                  ar: 'عرض كل المواقف والمسافة والكاميرا',
                  en: 'View all lots, distance, and camera',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          DriverSectionTitle(
            AppText.of(context, ar: 'خريطة المواقف', en: 'Parking map'),
          ),
          const SizedBox(height: 10),
          if (widget.lots.isEmpty)
            DriverEmptyState(
              title:
                  AppText.of(context, ar: 'لا توجد مواقف', en: 'No lots found'),
              body: AppText.of(
                context,
                ar: 'تحقق من بيانات LOTs لإظهار المواقف على الخريطة.',
                en: 'Check LOTs data to show parking lots on the map.',
              ),
              icon: Icons.map_outlined,
            )
          else
            _buildMapCard(context, palette, selectedLot, selectedLive),
          const SizedBox(height: 14),
          DriverInfoCard(
            title: AppText.of(context,
                ar: 'المسار إلى الموقف المحدد',
                en: 'Route to the selected lot'),
            body: _loadingRoute
                ? AppText.of(context,
                    ar: 'جارٍ حساب المسار...', en: 'Calculating route...')
                : _routePath == null
                    ? AppText.of(
                        context,
                        ar: 'اختر موقفاً وفعّل الموقع على الجهاز لعرض المسار والمسافة.',
                        en: 'Select a lot and enable device location to show the route and distance.',
                      )
                    : '${AppText.of(context, ar: 'المسافة', en: 'Distance')}: ${_formatDistance(_routePath!.distanceMeters)}\n'
                        '${AppText.of(context, ar: 'المدة', en: 'Duration')}: ${_formatDuration(_routePath!.durationSeconds)}\n'
                        '${_routePath!.notice ?? AppText.of(context, ar: 'تم تحميل المسار بنجاح.', en: 'Route loaded successfully.')}',
            icon: Icons.alt_route_rounded,
            color: _routePath?.isFallback == true
                ? Colors.orange
                : palette.primary,
          ),
          if (_bestLot() != null) ...[
            const SizedBox(height: 14),
            DriverInfoCard(
              title: AppText.of(context,
                  ar: 'أفضل موقف الآن', en: 'Best lot right now'),
              body: (() {
                final lot = _bestLot()!;
                final live = widget.liveLots[lot.id];
                final ratePerMinute = lot.rateHou <= 0 ? 0 : lot.rateHou / 60;
                return AppText.of(
                  context,
                  ar: '${lot.name}\nالفارغ: ${live?.free ?? 0} • المشغول: ${live?.occupied ?? 0}\n'
                      'السعر بالدقيقة: ${ratePerMinute.toStringAsFixed(2)} ${lot.currency}\n'
                      '${lot.distanceKm == null ? '' : 'يبعد ${lot.distanceKm!.toStringAsFixed(1)} كم'}',
                  en: '${lot.name}\nFree: ${live?.free ?? 0} • Occupied: ${live?.occupied ?? 0}\n'
                      'Per-minute price: ${ratePerMinute.toStringAsFixed(2)} ${lot.currency}\n'
                      '${lot.distanceKm == null ? '' : 'About ${lot.distanceKm!.toStringAsFixed(1)} km away'}',
                );
              })(),
              icon: Icons.auto_awesome_outlined,
              color: palette.available,
              action: FilledButton(
                onPressed: () {
                  final lot = _bestLot()!;
                  _selectLotAndMove(lot);
                },
                child: Text(
                  AppText.of(context,
                      ar: 'اختر الأفضل الآن', en: 'Use best lot'),
                ),
              ),
            ),
          ],
          if (selectedLot != null && selectedLive != null) ...[
            const SizedBox(height: 18),
            DriverSectionTitle(
              AppText.of(context,
                  ar: 'تفاصيل الموقف المحدد', en: 'Selected lot details'),
            ),
            const SizedBox(height: 10),
            DriverInfoCard(
              title: selectedLot.name,
              body: '${selectedLot.address}\n'
                  '${AppText.of(context, ar: 'الساعات', en: 'Hours')}: ${selectedLot.hours}\n'
                  '${AppText.of(context, ar: 'السعر', en: 'Rate')}: ${selectedLot.rateHou.toStringAsFixed(1)} ${selectedLot.currency}/${AppText.of(context, ar: 'ساعة', en: 'hour')}\n'
                  '${AppText.of(context, ar: 'الحد الأقصى', en: 'Max stay')}: ${selectedLot.maxStay} ${AppText.of(context, ar: 'دقيقة', en: 'min')}\n'
                  '${AppText.of(context, ar: 'آخر تحديث', en: 'Last update')}: ${selectedLive.ts ?? '-'}',
              icon: Icons.place_rounded,
              color:
                  selectedLive.degradedMode ? Colors.orange : palette.secondary,
            ),
            const SizedBox(height: 14),
            DriverSectionTitle(
              AppText.of(
                context,
                ar: 'معاينة الكاميرا الحية',
                en: 'Live camera preview',
              ),
            ),
            const SizedBox(height: 10),
            _buildCameraPreviewCard(
              context,
              palette,
              selectedLot,
              selectedLive,
            ),
          ],
          const SizedBox(height: 18),
          DriverSectionTitle(
            AppText.of(context, ar: 'المواقف', en: 'Lots'),
          ),
          const SizedBox(height: 10),
          ...widget.lots.map((lot) {
            final live = widget.liveLots[lot.id] ??
                DriverLiveLot(
                  lotId: lot.id,
                  free: 0,
                  occupied: 0,
                  total: 0,
                  degradedMode: false,
                  ts: null,
                  stalls: const <String, DriverLiveStall>{},
                );
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DriverLotCard(
                lot: lot,
                live: live,
                isFavorite: widget.favoriteLotIds.contains(lot.id),
                onTap: () {
                  _selectLotAndMove(lot);
                },
                onToggleFavorite: () => widget.onToggleFavorite(lot.id),
              ),
            );
          }),
          if (widget.announcements.isNotEmpty) ...[
            const SizedBox(height: 18),
            DriverSectionTitle(
              AppText.of(context,
                  ar: 'إعلانات الموقف', en: 'Lot announcements'),
            ),
            const SizedBox(height: 10),
            ...widget.announcements.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DriverAnnouncementCard(announcement: item),
              ),
            ),
          ],
          const SizedBox(height: 18),
          _buildFiltersCard(context, palette),
          const SizedBox(height: 18),
          DriverSectionTitle(
            AppText.of(
              context,
              ar: 'الفراغات (${filteredStalls.length})',
              en: 'Stalls (${filteredStalls.length})',
            ),
            trailing: selectedLive != null
                ? DriverPill(
                    text: AppText.of(
                      context,
                      ar: 'فارغ ${selectedLive.free} / مشغول ${selectedLive.occupied}',
                      en: 'Free ${selectedLive.free} / Occupied ${selectedLive.occupied}',
                    ),
                    color: selectedLive.degradedMode
                        ? Colors.orange
                        : palette.secondary,
                  )
                : null,
          ),
          const SizedBox(height: 10),
          DriverInfoCard(
            title: AppText.of(context, ar: 'طريقة الحجز', en: 'How to book'),
            body: AppText.of(
              context,
              ar: 'اضغط على أي فراغ متاح من القائمة بالأسفل، ثم اختر "احجز هذا الموقف وابدأ الملاحة". سيظهر الحجز بعد ذلك في صفحة حجوزاتي مع الوقت الأقصى والفاتورة.',
              en: 'Tap any free stall below, then choose "Reserve this stall and navigate". The booking will appear in My Bookings with the time limit and invoice.',
            ),
            icon: Icons.how_to_reg_rounded,
            color: palette.secondary,
          ),
          const SizedBox(height: 10),
          if (filteredStalls.isEmpty)
            DriverEmptyState(
              title: AppText.of(context,
                  ar: 'لا توجد فراغات مطابقة', en: 'No matching stalls'),
              body: AppText.of(
                context,
                ar: 'غيّر الفلاتر أو اختر موقفاً آخر من الخريطة.',
                en: 'Change the filters or pick another lot from the map.',
              ),
              icon: Icons.filter_alt_off_outlined,
            )
          else
            ...filteredStalls.map(
              (stall) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DriverStallCard(
                  stall: stall,
                  onTap: () => _openStallSheet(stall),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapCard(
    BuildContext context,
    DriverPalette palette,
    DriverLot? selectedLot,
    DriverLiveLot? selectedLive,
  ) {
    return Container(
      height: 340,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: _fallbackCenter,
                zoom: 15,
                interactiveFlags: InteractiveFlag.all - InteractiveFlag.rotate,
                onMapReady: () {
                  if (!mounted) {
                    return;
                  }
                  _isMapReady = true;
                  _flushPendingMapMove();
                },
              ),
              children: [
                if (widget.showTileLayer)
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        AppServiceConfig.openStreetMapUserAgent,
                  ),
                if (_routePath != null && _routePath!.points.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePath!.points,
                        strokeWidth: 5,
                        color: palette.primary,
                      ),
                    ],
                  ),
                MarkerLayer(markers: _buildMarkers(context)),
              ],
            ),
            PositionedDirectional(
              top: 12,
              start: 12,
              end: 12,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MapBubble(
                    icon: Icons.touch_app_outlined,
                    label: AppText.of(context,
                        ar: 'اضغط على أي موقف', en: 'Tap any lot'),
                  ),
                  if (_currentPoint == null)
                    _MapBubble(
                      icon: Icons.location_disabled_outlined,
                      label: AppText.of(
                        context,
                        ar: 'فعّل الموقع للمسار الحي',
                        en: 'Enable location for live routing',
                      ),
                    ),
                ],
              ),
            ),
            if (selectedLot != null && selectedLive != null)
              PositionedDirectional(
                start: 12,
                end: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedLot.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        selectedLot.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          DriverPill(
                            text: AppText.of(
                              context,
                              ar: 'فارغ ${selectedLive.free}',
                              en: 'Free ${selectedLive.free}',
                            ),
                            color: palette.available,
                          ),
                          DriverPill(
                            text: AppText.of(
                              context,
                              ar: 'مشغول ${selectedLive.occupied}',
                              en: 'Occupied ${selectedLive.occupied}',
                            ),
                            color: palette.occupied,
                          ),
                          DriverPill(
                            text: AppText.of(
                              context,
                              ar: 'الإجمالي ${selectedLive.total}',
                              en: 'Total ${selectedLive.total}',
                            ),
                            color: palette.secondary,
                          ),
                          if (selectedLive.degradedMode)
                            DriverPill(
                              text: AppText.of(context,
                                  ar: 'وضع محدود', en: 'Degraded'),
                              color: Colors.orange,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreviewCard(
    BuildContext context,
    DriverPalette palette,
    DriverLot selectedLot,
    DriverLiveLot selectedLive,
  ) {
    final camera = _selectedCamera;
    if (camera == null) {
      return DriverInfoCard(
        title: AppText.of(
          context,
          ar: 'لا توجد كاميرا مربوطة',
          en: 'No linked camera',
        ),
        body: AppText.of(
          context,
          ar: 'هذا الموقف لا يحتوي على كاميرا مربوطة حاليًا، لكن لا يزال بإمكانك اختيار الفراغ من القائمة بالأسفل.',
          en: 'This lot does not have a linked camera right now, but you can still choose a stall from the list below.',
        ),
        icon: Icons.videocam_off_rounded,
        color: Colors.orange,
      );
    }

    final snapshotUrl = _snapshotUrlFor(camera);
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: snapshotUrl == null
                  ? Container(
                      color: palette.surfaceAlt,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        AppText.of(
                          context,
                          ar: 'لا يوجد رابط snapshot مضبوط لهذه الكاميرا.',
                          en: 'No snapshot URL is configured for this camera.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          snapshotUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: palette.surfaceAlt,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(18),
                              child: Text(
                                AppText.of(
                                  context,
                                  ar: 'تعذر تحميل صورة الكاميرا. تأكد من أن الجوال والكاميرا على نفس شبكة الواي فاي.',
                                  en: 'Unable to load the camera image. Make sure the phone and camera are on the same Wi-Fi network.',
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  height: 1.45,
                                ),
                              ),
                            );
                          },
                        ),
                        _DriverParkingBoxesOverlay(
                          live: selectedLive,
                          freeColor: palette.available,
                          occupiedColor: palette.occupied,
                          reservedColor: Colors.orange,
                        ),
                        PositionedDirectional(
                          top: 12,
                          start: 12,
                          child: DriverPill(
                            text: camera.isOnline
                                ? AppText.of(context, ar: 'مباشر', en: 'Live')
                                : AppText.of(
                                    context,
                                    ar: 'غير متصلة',
                                    en: 'Offline',
                                  ),
                            color: camera.isOnline
                                ? palette.available
                                : palette.occupied,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedLot.name,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    DriverPill(
                      text: AppText.of(
                        context,
                        ar: 'فارغ ${selectedLive.free}',
                        en: 'Free ${selectedLive.free}',
                      ),
                      color: palette.available,
                    ),
                    DriverPill(
                      text: AppText.of(
                        context,
                        ar: 'مشغول ${selectedLive.occupied}',
                        en: 'Occupied ${selectedLive.occupied}',
                      ),
                      color: palette.occupied,
                    ),
                    DriverPill(
                      text: AppText.of(
                        context,
                        ar: 'الإجمالي ${selectedLive.total}',
                        en: 'Total ${selectedLive.total}',
                      ),
                      color: palette.secondary,
                    ),
                    DriverPill(
                      text: AppText.of(
                        context,
                        ar: '${(selectedLot.rateHou / 60).toStringAsFixed(2)} ${selectedLot.currency}/دقيقة',
                        en: '${(selectedLot.rateHou / 60).toStringAsFixed(2)} ${selectedLot.currency}/min',
                      ),
                      color: palette.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  AppText.of(
                    context,
                    ar: 'إذا ظهرت الصورة فالكاميرا مربوطة بشكل صحيح. بعدها اختر أي فراغ متاح من القائمة بالأسفل لبدء الحجز.',
                    en: 'If the preview appears, the camera is linked correctly. Then choose any free stall below to start the booking.',
                  ),
                  style: TextStyle(
                    color: palette.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: snapshotUrl == null
                            ? null
                            : () => setState(() {
                                  _cameraPreviewTick++;
                                }),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          AppText.of(
                            context,
                            ar: 'تحديث الصورة',
                            en: 'Refresh preview',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openLiveStream(camera),
                        icon: const Icon(Icons.open_in_browser_rounded),
                        label: Text(
                          AppText.of(
                            context,
                            ar: 'فتح البث الحي',
                            en: 'Open live stream',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard(BuildContext context, DriverPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DriverSectionTitle(
          AppText.of(context, ar: 'فلاتر السائق', en: 'Driver filters'),
          trailing: _savingFilters
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _freeOnly,
                title: Text(
                  AppText.of(context,
                      ar: 'عرض الشواغر فقط', en: 'Free spots only'),
                ),
                onChanged: (value) => setState(() => _freeOnly = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: widget.preferences.filterAccessible,
                title: Text(
                  AppText.of(context,
                      ar: 'مطابقة ذوي الإعاقة', en: 'Match accessible'),
                ),
                onChanged: (value) => _updatePreferences(
                  widget.preferences.copyWith(filterAccessible: value),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: widget.preferences.filterEv,
                title: Text(
                  AppText.of(context, ar: 'مطابقة EV', en: 'Match EV'),
                ),
                onChanged: (value) => _updatePreferences(
                  widget.preferences.copyWith(filterEv: value),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppText.of(context,
                          ar: 'الحد الأقصى للبقاء', en: 'Maximum stay'),
                    ),
                  ),
                  Text(
                    AppText.of(
                      context,
                      ar: '${widget.preferences.filterMaxStayMin} دقيقة',
                      en: '${widget.preferences.filterMaxStayMin} min',
                    ),
                  ),
                ],
              ),
              Slider(
                value: widget.preferences.filterMaxStayMin.toDouble(),
                min: 30,
                max: 360,
                divisions: 11,
                label: '${widget.preferences.filterMaxStayMin}',
                onChanged: (value) => _updatePreferences(
                  widget.preferences.copyWith(filterMaxStayMin: value.round()),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppText.of(context,
                          ar: 'الحد الأعلى للسعر', en: 'Maximum price'),
                    ),
                  ),
                  Text(widget.preferences.filterPriceMax.toStringAsFixed(1)),
                ],
              ),
              Slider(
                value: widget.preferences.filterPriceMax,
                min: 1,
                max: 20,
                divisions: 19,
                label: widget.preferences.filterPriceMax.toStringAsFixed(1),
                onChanged: (value) => _updatePreferences(
                  widget.preferences.copyWith(filterPriceMax: value),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapBubble extends StatelessWidget {
  const _MapBubble({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: palette.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinMarker extends StatelessWidget {
  const _PinMarker({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

String _formatTime(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min';
}

class _DriverCameraAvailabilityCard extends StatelessWidget {
  const _DriverCameraAvailabilityCard({
    required this.free,
    required this.occupied,
    required this.total,
    required this.updatedAt,
    required this.palette,
  });

  final int free;
  final int occupied;
  final int total;
  final String? updatedAt;
  final DriverPalette palette;

  @override
  Widget build(BuildContext context) {
    final updated = updatedAt == null || updatedAt!.trim().isEmpty
        ? ''
        : AppText.of(
            context,
            ar: 'آخر تحديث: ${_formatTime(updatedAt!)}',
            en: 'Updated: ${_formatTime(updatedAt!)}',
          );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view_rounded, color: palette.available),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppText.of(
                    context,
                    ar: 'حالة المواقف الآن',
                    en: 'Current stall status',
                  ),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DriverAvailabilityPill(
                icon: Icons.local_parking_rounded,
                label: AppText.of(context, ar: 'فارغ', en: 'Free'),
                value: free,
                color: palette.available,
                palette: palette,
              ),
              _DriverAvailabilityPill(
                icon: Icons.block_rounded,
                label: AppText.of(context, ar: 'مشغول', en: 'Occupied'),
                value: occupied,
                color: palette.occupied,
                palette: palette,
              ),
              _DriverAvailabilityPill(
                icon: Icons.apps_rounded,
                label: AppText.of(context, ar: 'الإجمالي', en: 'Total'),
                value: total,
                color: palette.secondary,
                palette: palette,
              ),
            ],
          ),
          if (updated.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              updated,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DriverAvailabilityPill extends StatelessWidget {
  const _DriverAvailabilityPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final DriverPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyLiveCameraView extends StatefulWidget {
  const _PrivacyLiveCameraView({
    required this.snapshotUrl,
    required this.streamUrl,
    required this.palette,
    required this.live,
  });

  final String snapshotUrl;
  final String streamUrl;
  final DriverPalette palette;
  final DriverLiveLot? live;

  @override
  State<_PrivacyLiveCameraView> createState() => _PrivacyLiveCameraViewState();
}

class _PrivacyLiveCameraViewState extends State<_PrivacyLiveCameraView> {
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted) {
        setState(() => _tick++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _url {
    final raw = widget.snapshotUrl.trim().isNotEmpty
        ? widget.snapshotUrl
        : widget.streamUrl;
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      return raw;
    }
    final query = Map<String, String>.from(uri.queryParameters)
      ..['privacy'] = '1'
      ..['ts'] = _tick.toString();
    return uri.replace(queryParameters: query).toString();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _url,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: palette.surfaceAlt,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    AppText.of(
                      context,
                      ar: 'تعذر عرض البث. تأكد أن الجوال والكاميرا على نفس شبكة Wi-Fi وأن الرابط /capture يعمل.',
                      en: 'Unable to show the stream. Make sure the phone and camera are on the same Wi-Fi and /capture works.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
            const _PrivacyMaskOverlay(),
            _DriverParkingBoxesOverlay(
              live: widget.live,
              freeColor: palette.available,
              occupiedColor: palette.occupied,
              reservedColor: Colors.orange,
            ),
            PositionedDirectional(
              top: 10,
              start: 10,
              child: DriverPill(
                text: AppText.of(context, ar: 'خصوصية مفعلة', en: 'Privacy on'),
                color: palette.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyMaskOverlay extends StatelessWidget {
  const _PrivacyMaskOverlay();

  @override
  Widget build(BuildContext context) {
    Widget mask({
      required Alignment alignment,
      required double widthFactor,
      required double height,
    }) {
      return Align(
        alignment: alignment,
        child: FractionallySizedBox(
          widthFactor: widthFactor,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: height,
                color: Colors.black.withOpacity(0.34),
              ),
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: Stack(
        children: [
          mask(
            alignment: const Alignment(-0.65, -0.18),
            widthFactor: 0.22,
            height: 22,
          ),
          mask(
            alignment: const Alignment(-0.18, -0.16),
            widthFactor: 0.22,
            height: 22,
          ),
          mask(
            alignment: const Alignment(0.58, -0.16),
            widthFactor: 0.22,
            height: 22,
          ),
          mask(
            alignment: const Alignment(-0.58, 0.40),
            widthFactor: 0.25,
            height: 24,
          ),
          mask(
            alignment: const Alignment(0.18, 0.42),
            widthFactor: 0.25,
            height: 24,
          ),
          mask(
            alignment: const Alignment(0.72, 0.42),
            widthFactor: 0.25,
            height: 24,
          ),
        ],
      ),
    );
  }
}

class _DriverParkingBoxesOverlay extends StatelessWidget {
  const _DriverParkingBoxesOverlay({
    required this.live,
    required this.freeColor,
    required this.occupiedColor,
    required this.reservedColor,
  });

  final DriverLiveLot? live;
  final Color freeColor;
  final Color occupiedColor;
  final Color reservedColor;

  @override
  Widget build(BuildContext context) {
    final current = live;
    if (current == null) {
      return const SizedBox.shrink();
    }
    final boxes = current.stalls.values
        .where((stall) => stall.bbox.length >= 4)
        .toList(growable: false);
    if (boxes.isEmpty) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: CustomPaint(
        painter: _DriverParkingBoxesPainter(
          stalls: boxes,
          imageWidth: current.imageWidth,
          imageHeight: current.imageHeight,
          freeColor: freeColor,
          occupiedColor: occupiedColor,
          reservedColor: reservedColor,
        ),
      ),
    );
  }
}

class _DriverParkingBoxesPainter extends CustomPainter {
  const _DriverParkingBoxesPainter({
    required this.stalls,
    required this.imageWidth,
    required this.imageHeight,
    required this.freeColor,
    required this.occupiedColor,
    required this.reservedColor,
  });

  final List<DriverLiveStall> stalls;
  final int imageWidth;
  final int imageHeight;
  final Color freeColor;
  final Color occupiedColor;
  final Color reservedColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (stalls.isEmpty || size.isEmpty) return;
    final sourceWidth = imageWidth > 0
        ? imageWidth.toDouble()
        : stalls
            .map((stall) => stall.bbox[2])
            .fold<double>(0, (max, value) => value > max ? value : max);
    final sourceHeight = imageHeight > 0
        ? imageHeight.toDouble()
        : stalls
            .map((stall) => stall.bbox[3])
            .fold<double>(0, (max, value) => value > max ? value : max);
    if (sourceWidth <= 0 || sourceHeight <= 0) return;

    final scale = (size.width / sourceWidth) > (size.height / sourceHeight)
        ? size.width / sourceWidth
        : size.height / sourceHeight;
    final paintedWidth = sourceWidth * scale;
    final paintedHeight = sourceHeight * scale;
    final dx = (size.width - paintedWidth) / 2;
    final dy = (size.height - paintedHeight) / 2;

    for (final stall in stalls) {
      final box = stall.bbox;
      if (box.length < 4 || box[2] <= box[0] || box[3] <= box[1]) continue;
      final color = stall.state == 'free'
          ? freeColor
          : stall.state == 'reserved'
              ? reservedColor
              : occupiedColor;
      final rect = Rect.fromLTRB(
        dx + box[0] * scale,
        dy + box[1] * scale,
        dx + box[2] * scale,
        dy + box[3] * scale,
      );
      final border = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      final fill = Paint()
        ..color = color.withOpacity(0.12)
        ..style = PaintingStyle.fill;
      final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(rounded, fill);
      canvas.drawRRect(rounded, border);
    }
  }

  @override
  bool shouldRepaint(covariant _DriverParkingBoxesPainter oldDelegate) {
    return oldDelegate.stalls != stalls ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight ||
        oldDelegate.freeColor != freeColor ||
        oldDelegate.occupiedColor != occupiedColor ||
        oldDelegate.reservedColor != reservedColor;
  }
}

class _LotMarker extends StatelessWidget {
  const _LotMarker({
    required this.title,
    required this.free,
    required this.occupied,
    required this.color,
    required this.isSelected,
  });

  final String title;
  final int free;
  final int occupied;
  final Color color;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.55),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppText.of(
                  context,
                  ar: 'ف:$free  م:$occupied',
                  en: 'F:$free  O:$occupied',
                ),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ],
    );
  }
}
