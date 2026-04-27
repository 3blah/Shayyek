import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_text.dart';
import '../login.dart';
import '../theme_controller.dart';
import '../welcome.dart';
import 'pages/driver_dashboard_page.dart';
import 'pages/driver_favorites_page.dart';
import 'pages/driver_map_page.dart';
import 'pages/driver_notifications_page.dart';
import 'pages/driver_profile_page.dart';
import 'pages/driver_sessions_page.dart';
import 'services/driver_receipt_service.dart';
import 'services/driver_task_service.dart';
import 'ui/driver_palette.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({
    super.key,
    this.initialTab = 0,
  });

  final int initialTab;

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  late final DriverTaskService _service;
  final DriverReceiptService _receiptService = DriverReceiptService();
  final List<StreamSubscription<DatabaseEvent>> _subscriptions = [];
  StreamSubscription<Position>? _positionSubscription;
  final Map<String, String> _nodeErrors = {};
  final Map<String, String> _previousStallStates = {};
  final Set<String> _readNotificationIds = {};

  Timer? _clockTimer;
  DateTime _now = DateTime.now().toUtc();

  DriverUserContext? _user;
  DriverPreferences _preferences = DriverPreferences.defaults();

  Map<String, dynamic> _lotsRoot = {};
  Map<String, dynamic> _liveMapRoot = {};
  Map<String, dynamic> _stallsRoot = {};
  Map<String, dynamic> _camerasRoot = {};
  Map<String, dynamic> _sessionsRoot = {};
  Map<String, dynamic> _notificationsRoot = {};
  Map<String, dynamic> _favoritRoot = {};
  Map<String, dynamic> _announcementRoot = {};
  Map<String, dynamic> _businessRulesRoot = {};

  bool _loading = true;
  bool _processingReminder = false;
  bool _processingNearby = false;
  bool _processingReroute = false;
  bool _coreNodesSubscribed = false;
  String? _subscribedUserKey;
  String? _subscribedUserPreferencesKey;

  double? _currentLat;
  double? _currentLong;
  String? _selectedLotId;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _service = DriverTaskService(_db);
    _subscribeCoreNodes();
    _bootstrap();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _now = DateTime.now().toUtc();
      });
      _runRealtimeGuards();
    });
  }

  Future<void> _bootstrap() async {
    try {
      unawaited(_startLocationTracking());
      final resolvedUser = await _service
          .resolveSignedInOrSavedDriver()
          .timeout(const Duration(seconds: 6), onTimeout: () => null);
      if (!mounted) {
        return;
      }

      _user = resolvedUser;
      if (_user != null) {
        _subscribeUserNodes();
        _preferences = await _service
            .ensurePreferences(
              _user!,
              defaultLanguage:
                  ThemeController.supportedLanguageCodeForPlatform(),
            )
            .timeout(
              const Duration(seconds: 6),
              onTimeout: () => DriverPreferences.defaults(
                userId: _user!.primaryUserId,
                language: ThemeController.supportedLanguageCodeForPlatform(),
              ),
            );
        if (mounted) {
          ThemeScope.of(context).applySessionLocale(_preferences.language);
        }
        await _loadReadNotifications();
      }
    } catch (error) {
      _nodeErrors['bootstrap'] = error.toString();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _positionSubscription?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _startLocationTracking() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      _applyPosition(position);
      await _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 10,
        ),
      ).listen(
        _applyPosition,
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _applyPosition(Position position) {
    _currentLat = position.latitude;
    _currentLong = position.longitude;
    if (mounted) {
      setState(() {});
    }
  }

  void _subscribeCoreNodes() {
    if (_coreNodesSubscribed) {
      return;
    }
    _coreNodesSubscribed = true;
    _listen('LOTs', (value) => _lotsRoot = value);
    _listen('live_map', (value) => _liveMapRoot = value);
    _listen('stalls', (value) => _stallsRoot = value);
    _listen('cameras', (value) => _camerasRoot = value);
    _listen('Sessions', (value) => _sessionsRoot = value);
    _listen('Notification', (value) => _notificationsRoot = value);
    _listen('favorit', (value) => _favoritRoot = value);
    _listen('announcement', (value) => _announcementRoot = value);
    _listen('business_rules', (value) => _businessRulesRoot = value);
  }

  void _subscribeUserNodes() {
    final user = _user;
    if (user == null) {
      return;
    }

    if (_subscribedUserKey != user.userKey) {
      _subscribedUserKey = user.userKey;
      _listen('User/${user.userKey}', (value) {
        final current = _user;
        if (current == null) {
          return;
        }
        _user = DriverUserContext(
          userKey: current.userKey,
          primaryUserId: current.primaryUserId,
          appUserId: current.appUserId,
          authUid: current.authUid,
          name: (value['name'] ?? current.name).toString(),
          email: (value['email'] ?? current.email).toString(),
          phone: (value['phone'] ?? current.phone).toString(),
          roleId: current.roleId,
          roleName: current.roleName,
          status: (value['status'] ?? current.status).toString(),
        );
      });
    }

    if (_subscribedUserPreferencesKey != user.preferencesKey) {
      _subscribedUserPreferencesKey = user.preferencesKey;
      _listen('UserPreferences/${user.preferencesKey}', (value) {
        if (value.isEmpty) {
          _service
              .ensurePreferences(
            user,
            defaultLanguage: ThemeController.supportedLanguageCodeForPlatform(),
          )
              .then((prefs) {
            if (!mounted) {
              return;
            }
            setState(() {
              _preferences = prefs;
            });
          });
        } else {
          _preferences = DriverPreferences.fromMap(
            value,
            fallbackUserId: user.primaryUserId,
          );
          if (mounted) {
            ThemeScope.of(context).applySessionLocale(_preferences.language);
          }
        }
      });
    }
  }

  void _listen(
    String path,
    void Function(Map<String, dynamic> value) onData,
  ) {
    final subscription = _db.ref(path).onValue.listen(
      (event) {
        _nodeErrors.remove(path);
        onData(_asMap(event.snapshot.value));
        _afterRealtimeUpdate();
      },
      onError: (error) {
        _nodeErrors[path] = error.toString();
        if (mounted) {
          setState(() {});
        }
      },
    );
    _subscriptions.add(subscription);
  }

  void _afterRealtimeUpdate() {
    _syncSelectedLot();
    _runRealtimeGuards();
    if (mounted) {
      setState(() {});
    }
  }

  void _syncSelectedLot() {
    if (_selectedLotId != null && _lotById(_selectedLotId!) != null) {
      return;
    }
    final active = _activeSession;
    final navigating = _navigatingSession;
    if (navigating != null && _lotById(navigating.lotId) != null) {
      _selectedLotId = navigating.lotId;
      return;
    }
    if (active != null && _lotById(active.lotId) != null) {
      _selectedLotId = active.lotId;
      return;
    }
    if (_lots.isNotEmpty) {
      _selectedLotId = _preferredLot()?.id ?? _lots.first.id;
    }
  }

  Future<void> _runRealtimeGuards() async {
    final user = _user;
    if (user == null) {
      _captureCurrentStates();
      return;
    }
    final currentStates = _currentStallStates;
    if (_previousStallStates.isEmpty) {
      _previousStallStates
        ..clear()
        ..addAll(currentStates);
      return;
    }

    final notifications = _notifications;
    final rules = _asMap(_businessRulesRoot['rules_001']);
    final alertPolicies = _asMap(rules['alert_policies']);

    final active = _activeSession;
    if (active != null && !_processingReminder) {
      _processingReminder = true;
      try {
        final reminder = await _service.maybeSendExpiryReminder(
          user: user,
          session: active,
          alertBeforeMinutes:
              _asInt(alertPolicies['time_expire_before_min'], 15),
          existingNotifications: notifications,
        );
        if (reminder?.message.trim().isNotEmpty == true) {
          _showMessage(reminder!.message);
        }
      } finally {
        _processingReminder = false;
      }
    }

    final navigating = _navigatingSession;
    if (navigating != null && !_processingReroute) {
      _processingReroute = true;
      try {
        final reroute = await _service.autoRerouteIfNeeded(
          user: user,
          preferences: _preferences,
          session: navigating,
          lotStalls: _selectedLotId == navigating.lotId
              ? _selectedStalls
              : _service.stallsForLot(
                  lotId: navigating.lotId,
                  stallsRoot: _stallsRoot,
                  liveMapRoot: _liveMapRoot,
                ),
        );
        if (reroute.message.trim().isNotEmpty) {
          _showMessage(reroute.message);
        }
      } finally {
        _processingReroute = false;
      }
    }

    if (!_processingNearby) {
      _processingNearby = true;
      try {
        final allStalls = <DriverStall>[];
        for (final lot in _lots) {
          allStalls.addAll(
            _service.stallsForLot(
              lotId: lot.id,
              stallsRoot: _stallsRoot,
              liveMapRoot: _liveMapRoot,
            ),
          );
        }
        final nearby = await _service.maybeSendNearbySpotOpenedNotification(
          user: user,
          nearbySpotOpenEnabled:
              _asBool(alertPolicies['nearby_spot_open'], false),
          relevantLotIds: _relevantLotIds,
          previousStates: Map<String, String>.from(_previousStallStates),
          allStalls: allStalls,
          existingNotifications: notifications,
        );
        if (nearby?.message.trim().isNotEmpty == true) {
          _showMessage(nearby!.message);
        }
      } finally {
        _processingNearby = false;
      }
    }

    _captureCurrentStates();
  }

  void _captureCurrentStates() {
    _previousStallStates
      ..clear()
      ..addAll(_currentStallStates);
  }

  Map<String, String> get _currentStallStates {
    final values = <String, String>{};
    for (final lot in _lots) {
      final stalls = _service.stallsForLot(
        lotId: lot.id,
        stallsRoot: _stallsRoot,
        liveMapRoot: _liveMapRoot,
      );
      for (final stall in stalls) {
        values[stall.id] = stall.state;
      }
    }
    return values;
  }

  List<String> get _relevantLotIds {
    final ids = <String>{};
    if (_selectedLotId != null && _selectedLotId!.isNotEmpty) {
      ids.add(_selectedLotId!);
    }
    if (_currentLat != null && _currentLong != null) {
      for (final lot in _lots) {
        final distance = lot.distanceKm ?? double.infinity;
        if (distance <= _preferences.defaultDistanceKm) {
          ids.add(lot.id);
        }
      }
    } else if (_lots.isNotEmpty) {
      ids.add(_lots.first.id);
    }
    return ids.toList();
  }

  List<DriverLot> get _lots => _service.parseLots(
        _lotsRoot,
        originLat: _currentLat,
        originLong: _currentLong,
      );

  Map<String, DriverLiveLot> get _liveLots {
    final result = <String, DriverLiveLot>{};
    for (final lot in _lots) {
      result[lot.id] = _service.parseLiveLot(
        lot.id,
        _liveMapRoot,
        stallsRoot: _stallsRoot,
      );
    }
    return result;
  }

  Set<String> get _favoriteLotIds => _user == null
      ? <String>{}
      : _service.favoriteLotIdsForUser(_favoritRoot, _user!).toSet();

  List<DriverSession> get _sessions => _user == null
      ? <DriverSession>[]
      : _service.sessionsForUser(_sessionsRoot, _user!);

  DriverSession? get _activeSession =>
      _service.activeSessionFromList(_sessions);

  DriverSession? get _navigatingSession =>
      _service.navigatingSessionFromList(_sessions);

  List<DriverNotificationItem> get _notifications => _user == null
      ? <DriverNotificationItem>[]
      : _service.notificationsForUser(_notificationsRoot, _user!);

  List<DriverAnnouncement> get _dashboardAnnouncements => _service
      .activeAnnouncements(_announcementRoot, currentLotId: _selectedLotId);

  List<DriverAnnouncement> get _selectedLotAnnouncements =>
      _service.activeAnnouncements(
        _announcementRoot,
        currentLotId: _selectedLot?.id,
      );

  DriverLot? get _selectedLot =>
      _selectedLotId == null ? null : _lotById(_selectedLotId!);

  List<DriverStall> get _selectedStalls => _selectedLot == null
      ? <DriverStall>[]
      : _service.stallsForLot(
          lotId: _selectedLot!.id,
          stallsRoot: _stallsRoot,
          liveMapRoot: _liveMapRoot,
        );

  List<DriverLot> get _favoriteLots =>
      _lots.where((lot) => _favoriteLotIds.contains(lot.id)).toList();

  List<DriverLotCamera> get _selectedLotCameras => _selectedLot == null
      ? const <DriverLotCamera>[]
      : _service.camerasForLot(
          lotId: _selectedLot!.id,
          camerasRoot: _camerasRoot,
        );

  int get _totalFree => _liveLots.values.fold(0, (sum, lot) => sum + lot.free);

  int get _totalOccupied =>
      _liveLots.values.fold(0, (sum, lot) => sum + lot.occupied);

  String get _nearestLotLabel => _lots.isEmpty ? '-' : _lots.first.name;

  String? get _combinedError {
    if (_nodeErrors.isEmpty) {
      return null;
    }
    return _nodeErrors.entries.first.value;
  }

  DriverLot? _lotById(String lotId) {
    for (final lot in _lots) {
      if (_service.lotIdMatches(lot.id, lotId)) {
        return lot;
      }
    }
    return null;
  }

  DriverLot? _preferredLot() {
    for (final lot in _lots) {
      final cameras = _service.camerasForLot(
        lotId: lot.id,
        camerasRoot: _camerasRoot,
      );
      final hasOnlineCamera = cameras.any((camera) => camera.isOnline);
      final live = _liveLots[lot.id];
      if (hasOnlineCamera && (live?.free ?? 0) >= 0) {
        return lot;
      }
    }
    for (final lot in _lots) {
      final cameras = _service.camerasForLot(
        lotId: lot.id,
        camerasRoot: _camerasRoot,
      );
      if (cameras.isNotEmpty) {
        return lot;
      }
    }
    for (final lot in _lots) {
      final live = _liveLots[lot.id];
      if ((live?.free ?? 0) > 0) {
        return lot;
      }
    }
    return _lots.isEmpty ? null : _lots.first;
  }

  DriverStall? _stallById(String stallId) {
    for (final lot in _lots) {
      final stalls = _service.stallsForLot(
        lotId: lot.id,
        stallsRoot: _stallsRoot,
        liveMapRoot: _liveMapRoot,
      );
      for (final stall in stalls) {
        if (stall.id == stallId) {
          return stall;
        }
      }
    }
    return null;
  }

  String _lotNameOf(String lotId) => _lotById(lotId)?.name ?? lotId;

  String _lotAddressOf(String lotId) =>
      _lotById(lotId)?.address ?? 'العنوان غير متوفر';

  String _stallLabelOf(String stallId) => _stallById(stallId)?.label ?? stallId;

  Future<void> _loadReadNotifications() async {
    final user = _user;
    if (user == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final values = prefs
            .getStringList('driver_read_notifications_${user.primaryUserId}') ??
        const <String>[];
    _readNotificationIds
      ..clear()
      ..addAll(values);
  }

  Future<void> _markNotificationRead(String notificationId) async {
    final user = _user;
    if (user == null) {
      return;
    }
    _readNotificationIds.add(notificationId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'driver_read_notifications_${user.primaryUserId}',
      _readNotificationIds.toList(),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refresh() async {
    await _startLocationTracking().timeout(
      const Duration(seconds: 4),
      onTimeout: () {},
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleFavorite(String lotId) async {
    final user = _user;
    if (user == null) {
      await _promptLoginForGuest(
        AppText.of(
          context,
          ar: 'أضف المفضلة بعد تسجيل الدخول.',
          en: 'Sign in to use favorites.',
        ),
      );
      return;
    }
    final result = await _service.toggleFavorite(user: user, lotId: lotId);
    _showMessage(result.message);
  }

  Future<void> _navigateToStall(
    DriverStall stall, {
    int reservedMinutes = 30,
  }) async {
    final user = _user;
    final lot = _selectedLot;
    if (user == null || lot == null) {
      await _promptLoginForGuest(
        AppText.of(
          context,
          ar: 'يلزم تسجيل الدخول قبل حجز أو بدء الملاحة.',
          en: 'Please sign in before reserving or starting navigation.',
        ),
      );
      return;
    }
    final result = await _service.prepareNavigation(
      user: user,
      lot: lot,
      stall: stall,
      existingSessions: _sessions,
      reservedMinutes: reservedMinutes,
    );
    _showMessage(result.message);
    if (result.success && mounted) {
      setState(() {
        _tab = 2;
      });
    }
  }

  Future<void> _confirmParking() async {
    final user = _user;
    final session = _navigatingSession;
    if (user == null || session == null) {
      _showMessage('اختر موقفاً أولاً لبدء الملاحة.');
      return;
    }
    final lot = _lotById(session.lotId);
    final stall = _stallById(session.targetStallId);
    if (lot == null || stall == null) {
      _showMessage('تعذر العثور على بيانات الموقف أو الفراغ المحدد.');
      return;
    }
    if (!stall.isFree) {
      final reroute = await _service.autoRerouteIfNeeded(
        user: user,
        preferences: _preferences,
        session: session,
        lotStalls: _service.stallsForLot(
          lotId: lot.id,
          stallsRoot: _stallsRoot,
          liveMapRoot: _liveMapRoot,
        ),
      );
      if (reroute.message.trim().isNotEmpty) {
        _showMessage(reroute.message);
      }
      return;
    }

    final result = await _service.confirmParking(
      user: user,
      session: session,
      lot: lot,
      stall: stall,
      parkedLat: _currentLat,
      parkedLong: _currentLong,
    );
    _showMessage(result.message);
  }

  Future<void> _saveParkedPin() async {
    final session = _activeSession;
    if (session == null) {
      _showMessage('لا توجد جلسة نشطة لحفظ موقع السيارة.');
      return;
    }
    final lat = _currentLat ?? session.lat;
    final long = _currentLong ?? session.long;
    final result = await _service.saveWhereIParked(
      session: session,
      lat: lat,
      long: long,
    );
    _showMessage(result.message);
  }

  Future<void> _endSession() async {
    final user = _user;
    final session = _activeSession;
    if (user == null || session == null) {
      _showMessage('لا توجد جلسة نشطة الآن.');
      return;
    }
    final result = await _service.endSession(user: user, session: session);
    _showMessage(result.message);
    if (mounted) {
      setState(() {
        _tab = 0;
      });
    }
  }

  Future<void> _shareInvoice(DriverSession session) async {
    final isArabic = AppText.isArabic(context);
    final errorMessage = AppText.of(
      context,
      ar: 'تعذر تجهيز الفاتورة حالياً.',
      en: 'Unable to prepare the invoice right now.',
    );
    try {
      final lot = _lotById(session.lotId);
      final stallId = session.stallId.trim().isNotEmpty
          ? session.stallId
          : session.targetStallId;
      final stall = _stallById(stallId);
      final message = await _receiptService.shareInvoice(
        session: session,
        lot: lot,
        stall: stall,
        isArabic: isArabic,
      );
      _showMessage(message);
    } catch (error) {
      _showMessage(errorMessage);
    }
  }

  Future<void> _saveProfile({
    required String name,
    required String phone,
    required DriverPreferences preferences,
  }) async {
    final user = _user;
    if (user == null) {
      await _promptLoginForGuest(
        AppText.of(
          context,
          ar: 'سجّل الدخول لتعديل الحساب والإعدادات.',
          en: 'Sign in to update your account and settings.',
        ),
      );
      return;
    }
    if (name.trim().isEmpty) {
      _showMessage('الاسم مطلوب.');
      return;
    }
    await _service.updateProfileAndPreferences(
      user: user,
      name: name,
      phone: phone,
      preferences: preferences,
    );
    _showMessage('تم حفظ الملف الشخصي والتفضيلات.');
  }

  Future<void> _promptLoginForGuest(String message) async {
    if (!mounted) {
      return;
    }

    final shouldLogin = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(
                AppText.of(
                  context,
                  ar: 'تسجيل الدخول مطلوب',
                  en: 'Sign In Required',
                ),
              ),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    AppText.of(
                      context,
                      ar: 'لاحقاً',
                      en: 'Later',
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    AppText.of(
                      context,
                      ar: 'تسجيل الدخول',
                      en: 'Sign In',
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldLogin || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _logout() async {
    await _service.logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );

    if (_loading) {
      return Scaffold(
        backgroundColor: palette.pageBg,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(palette.secondary),
          ),
        ),
      );
    }

    final pages = [
      DriverDashboardPage(
        user: _user,
        nearbyLots: _lots,
        liveLots: _liveLots,
        favoriteLotIds: _favoriteLotIds,
        announcements: _dashboardAnnouncements,
        activeSession: _activeSession,
        activeLotName:
            _activeSession == null ? null : _lotNameOf(_activeSession!.lotId),
        activeStallLabel: _activeSession == null
            ? null
            : _stallLabelOf(_activeSession!.stallId),
        totalFree: _totalFree,
        totalOccupied: _totalOccupied,
        nearestLotLabel: _nearestLotLabel,
        favoriteCount: _favoriteLotIds.length,
        onRefresh: _refresh,
        onOpenLots: () => setState(() => _tab = 1),
        onOpenNotifications: () => setState(() => _tab = 3),
        onOpenSessions: () => setState(() => _tab = 2),
        onOpenFavorites: () => setState(() => _tab = 4),
        onOpenProfile: () => setState(() => _tab = 5),
        onOpenLot: (lotId) {
          setState(() {
            _selectedLotId = lotId;
            _tab = 1;
          });
        },
        onToggleFavorite: (lotId) {
          _toggleFavorite(lotId);
        },
        onViewActiveSession: () => setState(() => _tab = 2),
        onEndSession: () {
          _endSession();
        },
        errorText: _combinedError,
      ),
      DriverMapPage(
        lots: _lots,
        selectedLotId: _selectedLotId,
        liveLots: _liveLots,
        selectedLotCameras: _selectedLotCameras,
        favoriteLotIds: _favoriteLotIds,
        preferences: _preferences,
        stalls: _selectedStalls,
        announcements: _selectedLotAnnouncements,
        currentLat: _currentLat,
        currentLong: _currentLong,
        onRefresh: _refresh,
        onSelectLot: (lotId) => setState(() => _selectedLotId = lotId),
        onToggleFavorite: (lotId) {
          _toggleFavorite(lotId);
        },
        onUpdatePreferences: (preferences) async {
          final user = _user;
          if (user == null) {
            _showMessage('سجّل الدخول أولاً لتحديث تفضيلات السائق.');
            return;
          }
          await _service.updateProfileAndPreferences(
            user: user,
            name: user.name,
            phone: user.phone,
            preferences: preferences,
          );
        },
        onNavigateToStall: (stall, reservedMinutes) =>
            _navigateToStall(stall, reservedMinutes: reservedMinutes),
        errorText: _combinedError,
      ),
      DriverSessionsPage(
        now: _now,
        activeSession: _activeSession,
        navigatingSession: _navigatingSession,
        completedSessions: _sessions.where((item) => item.isCompleted).toList(),
        lotNameOf: _lotNameOf,
        lotAddressOf: _lotAddressOf,
        stallLabelOf: _stallLabelOf,
        onRefresh: _refresh,
        onConfirmParking: _confirmParking,
        onEndSession: _endSession,
        onSaveParkedPin: _saveParkedPin,
        onShareInvoice: _shareInvoice,
        errorText: _combinedError,
      ),
      DriverNotificationsPage(
        notifications: _notifications,
        readIds: _readNotificationIds,
        onRefresh: _refresh,
        onMarkRead: (notificationId) {
          _markNotificationRead(notificationId);
        },
      ),
      DriverFavoritesPage(
        favoriteLots: _favoriteLots,
        liveLots: _liveLots,
        favoriteLotIds: _favoriteLotIds,
        onRefresh: _refresh,
        onOpenLot: (lotId) {
          setState(() {
            _selectedLotId = lotId;
            _tab = 1;
          });
        },
        onToggleFavorite: (lotId) {
          _toggleFavorite(lotId);
        },
      ),
      DriverProfilePage(
        user: _user,
        preferences: _preferences,
        onSave: _saveProfile,
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      backgroundColor: palette.pageBg,
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            label: AppText.of(context, ar: 'الرئيسية', en: 'Home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            label: AppText.of(context, ar: 'المواقف', en: 'Lots'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.timer_outlined),
            label: AppText.of(context, ar: 'حجوزاتي', en: 'Bookings'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications_outlined),
            label: AppText.of(context, ar: 'الإشعارات', en: 'Alerts'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_border_rounded),
            label: AppText.of(context, ar: 'المفضلة', en: 'Favorites'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            label: AppText.of(context, ar: 'الحساب', en: 'Profile'),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return <String, dynamic>{};
}

bool _asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final text = value?.toString().trim().toLowerCase() ?? '';
  if (text == 'true' || text == '1') {
    return true;
  }
  if (text == 'false' || text == '0') {
    return false;
  }
  return fallback;
}

int _asInt(dynamic value, [int fallback = 0]) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
