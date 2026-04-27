import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../app_text.dart';
import '../config.dart';
import 'admin_utils.dart';
import 'admin_widgets.dart';

String _camT(BuildContext context, String text) {
  if (!AppText.isArabic(context)) {
    return text;
  }

  const translations = <String, String>{
    'Cameras': 'الكاميرات',
    'Search camera id, lot, status, settings...':
        'ابحث في معرّف الكاميرا أو الموقف أو الحالة أو الإعدادات...',
    'Add': 'إضافة',
    'Refresh': 'تحديث',
    'All statuses': 'كل الحالات',
    'Online': 'متصلة',
    'Offline': 'غير متصلة',
    'Stale': 'متأخرة',
    'Status filter': 'فلتر الحالة',
    'All lots': 'كل المواقف',
    'Lot filter': 'فلتر المواقف',
    'No results': 'لا توجد نتائج',
    'No cameras yet. Add your first camera.':
        'لا توجد كاميرات بعد. أضف أول كاميرا.',
    'No cameras match your search/filters.':
        'لا توجد كاميرات مطابقة للبحث أو الفلاتر.',
    'Add camera': 'إضافة كاميرا',
    'Add Camera': 'إضافة كاميرا',
    'Cancel': 'إلغاء',
    'Create': 'إنشاء',
    'Camera ID (e.g., camera_001)': 'معرّف الكاميرا (مثال: camera_001)',
    'Lot': 'الموقف',
    'Lot ID': 'معرّف الموقف',
    'FPS target': 'FPS المستهدف',
    'Threshold': 'الحد',
    'Update threshold (sec)': 'حد التحديث (ثانية)',
    'Map FOV / for_map': 'الخريطة / for_map',
    'Status': 'الحالة',
    'Saved': 'تم الحفظ',
    'Created': 'تم الإنشاء',
    'Deleted': 'تم الحذف',
    'Save': 'حفظ',
    'Delete camera': 'حذف الكاميرا',
    'Delete': 'حذف',
    'Edit': 'تعديل',
    'Heartbeat': 'آخر نبضة',
    'Map FOV': 'مجال الخريطة',
    'Latency': 'الاستجابة',
    'Drop': 'الفقد',
    'Set Offline': 'تحويل إلى غير متصلة',
    'Set Online': 'تحويل إلى متصلة',
    'Heartbeat now': 'تحديث النبضة الآن',
  };

  return translations[text] ?? text;
}

class AdminCamerasPage extends StatefulWidget {
  const AdminCamerasPage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<AdminCamerasPage> createState() => _AdminCamerasPageState();
}

class _AdminCamerasPageState extends State<AdminCamerasPage> {
  final _db = FirebaseDatabase.instance;

  final TextEditingController _search = TextEditingController();
  String _q = '';
  String _statusFilter = 'all';
  String _lotFilter = 'all';
  Key _reloadKey = UniqueKey();
  bool _aiAnalyzing = false;

  late bool _darkMode;

  @override
  void initState() {
    super.initState();
    _darkMode = widget.isDarkMode;
  }

  @override
  void didUpdateWidget(covariant AdminCamerasPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      _darkMode = widget.isDarkMode;
    }
  }

  void _toggleTheme() {
    setState(() => _darkMode = !_darkMode);
    widget.onToggleTheme();
  }

  void _reload() => setState(() => _reloadKey = UniqueKey());

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<dynamic> _safeEntries(dynamic v) {
    if (v is Map) return childEntries(v);
    return <dynamic>[];
  }

  SystemUiOverlayStyle _overlayStyle(_Palette p) {
    final base =
        p.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    return base.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: p.dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: p.dark ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness:
          p.dark ? Brightness.light : Brightness.dark,
    );
  }

  ThemeData _theme(_Palette p) {
    final cs = ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: p.dark ? Brightness.dark : Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.dark ? Brightness.dark : Brightness.light,
      colorScheme: cs,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: p.menuBg,
      dialogBackgroundColor: p.dialogBg,
      dividerColor: p.border,
      iconTheme: IconThemeData(color: p.icon),
      textTheme: const TextTheme().apply(
        bodyColor: p.text,
        displayColor: p.text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.text,
        iconTheme: IconThemeData(color: p.icon),
        titleTextStyle: TextStyle(
          color: p.text,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
        systemOverlayStyle: _overlayStyle(p),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: p.fieldFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.accentGlow, width: 1.2),
        ),
        labelStyle: TextStyle(color: p.textMuted),
        hintStyle: TextStyle(color: p.textHint),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.menuBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: TextStyle(color: p.text, fontWeight: FontWeight.w800),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: p.dialogBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  BoxDecoration _pageGradient(_Palette p) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [p.bg1, p.bg2, p.bg3, p.bg4],
      ),
      boxShadow: [
        BoxShadow(
          color: p.accentGlow.withOpacity(p.dark ? 0.10 : 0.14),
          blurRadius: 40,
          spreadRadius: 8,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  BoxDecoration _glassCard(_Palette p) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [p.cardA, p.cardB],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: p.border),
      boxShadow: [
        BoxShadow(
          color: p.shadow,
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  BoxDecoration _softCard(_Palette p) {
    return BoxDecoration(
      color: p.softCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: p.border),
    );
  }

  InputDecoration _searchDec(_Palette p) {
    return InputDecoration(
      hintText: _camT(context, 'Search camera id, lot, status, settings...'),
      prefixIcon: Icon(Icons.search_rounded, color: p.iconMuted),
      suffixIcon: _q.trim().isEmpty
          ? null
          : IconButton(
              onPressed: () {
                _search.clear();
                setState(() => _q = '');
              },
              icon: Icon(Icons.close_rounded, color: p.iconMuted),
            ),
    );
  }

  InputDecoration _ddDec(String label) =>
      InputDecoration(labelText: _camT(context, label));

  Widget _iconChipBtn(
    _Palette p, {
    required VoidCallback onTap,
    required IconData icon,
    String? tooltip,
    bool danger = false,
    double size = 46,
  }) {
    final c = danger ? p.danger : p.icon;

    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: p.softCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
        ),
        child: Icon(icon, color: c),
      ),
    );

    if (tooltip == null || tooltip.trim().isEmpty) return btn;
    return Tooltip(message: tooltip, child: btn);
  }

  Future<T?> _showNeonDialog<T>({
    required _Palette p,
    required String title,
    required IconData icon,
    required Widget content,
    required String cancelText,
    required String primaryText,
    required VoidCallback onPrimary,
    bool danger = false,
  }) {
    final border =
        danger ? p.danger.withOpacity(0.60) : p.accentGlow.withOpacity(0.65);
    final grad = danger
        ? <Color>[p.danger, p.danger.withOpacity(0.85)]
        : p.primaryGradient;

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dialog',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) {
        return SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 640),
                      decoration: BoxDecoration(
                        color: p.dialogBg.withOpacity(0.96),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: border, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.28),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: border.withOpacity(0.85)),
                                    color: p.fieldFill.withOpacity(0.75),
                                  ),
                                  child: Icon(
                                    icon,
                                    color: danger ? p.danger : p.accentGlow,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      color: p.text,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(Icons.close_rounded,
                                      color: p.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Container(
                              height: 1, color: p.border.withOpacity(0.8)),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                            child: content,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _GhostButton(
                                    height: 46,
                                    radius: 16,
                                    label: cancelText,
                                    border: p.border,
                                    bg: p.fieldFill.withOpacity(0.65),
                                    fg: p.textMuted,
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _GradientButton(
                                    height: 46,
                                    radius: 16,
                                    label: primaryText,
                                    icon: null,
                                    colors: grad,
                                    glow: danger ? p.danger : p.accentGlow,
                                    onPressed: onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final a = Curves.easeOutCubic.transform(anim.value);
        return Transform.scale(
          scale: 0.98 + (0.02 * a),
          child: Opacity(opacity: a, child: child),
        );
      },
    );
  }

  Future<String> _loadAiBridgeUrl() async {
    try {
      final snap = await _db.ref('app_settings/parking_ai_bridge_url').get();
      final fromDb = s(snap.value, '').trim();
      if (fromDb.isNotEmpty) return fromDb;
    } catch (_) {}
    return AppServiceConfig.parkingAiBridgeBaseUrl.trim();
  }

  String _normalizeAiBaseUrl(String value) {
    var base = value.trim();
    if (base.isEmpty) return '';
    if (!base.startsWith('http://') && !base.startsWith('https://')) {
      base = 'http://$base';
    }
    base = base.replaceAll(RegExp(r'/+$'), '');
    if (base.endsWith('/analyze-parking')) {
      base = base.substring(0, base.length - '/analyze-parking'.length);
    }
    if (base.endsWith('/health')) {
      base = base.substring(0, base.length - '/health'.length);
    }
    return base.replaceAll(RegExp(r'/+$'), '');
  }

  List<String> _candidateAiBridgeUrls(String preferred) {
    final ordered = <String>[
      preferred,
      AppServiceConfig.parkingAiBridgeBaseUrl,
      'http://192.168.8.105:8000',
      'http://192.168.0.101:8000',
      'http://192.168.1.100:8000',
      'http://10.0.2.2:8000',
    ];
    final seen = <String>{};
    final values = <String>[];
    for (final value in ordered) {
      final normalized = _normalizeAiBaseUrl(value);
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      seen.add(normalized);
      values.add(normalized);
    }
    return values;
  }

  Uri _healthUri(String baseUrl) {
    final base = _normalizeAiBaseUrl(baseUrl);
    if (base.isEmpty) throw const FormatException('Empty AI bridge URL');
    return Uri.parse('$base/health');
  }

  Future<String> _resolveWorkingAiBridgeUrl(String preferred) async {
    final candidates = _candidateAiBridgeUrls(preferred);
    for (final candidate in candidates) {
      try {
        final response = await http
            .get(_healthUri(candidate))
            .timeout(const Duration(seconds: 2));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          await _db.ref('app_settings/parking_ai_bridge_url').set(candidate);
          return candidate;
        }
      } catch (_) {
        // Keep trying the next known local address.
      }
    }
    return candidates.isNotEmpty ? candidates.first : '';
  }

  Uri _analysisUri(String baseUrl) {
    var base = _normalizeAiBaseUrl(baseUrl);
    if (base.isEmpty) {
      throw FormatException(
        AppText.of(
          context,
          ar: 'رابط خدمة الذكاء الاصطناعي غير مضبوط.',
          en: 'The AI bridge URL is not configured.',
        ),
      );
    }
    return Uri.parse('$base/analyze-parking');
  }

  Future<String?> _promptAiBridgeUrl(String initial) async {
    final p = _PaletteScope.of(context);
    final controller = TextEditingController(
      text: initial.trim().isEmpty ? 'http://YOUR-PC-IP:8000' : initial.trim(),
    );
    final formKey = GlobalKey<FormState>();

    final ok = await _showNeonDialog<bool>(
      p: p,
      title: AppText.of(
        context,
        ar: 'رابط خدمة تحليل المواقف',
        en: 'Parking AI bridge URL',
      ),
      icon: Icons.hub_outlined,
      cancelText: _camT(context, 'Cancel'),
      primaryText: _camT(context, 'Save'),
      onPrimary: () {
        FocusScope.of(context).unfocus();
        if (formKey.currentState?.validate() != true) return;
        Navigator.pop(context, true);
      },
      content: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppText.of(
                context,
                ar: 'شغل خدمة Python على الكمبيوتر ثم ضع الرابط هنا. مثال: http://192.168.8.100:8000',
                en: 'Run the Python bridge on the computer, then enter its URL here. Example: http://192.168.8.100:8000',
              ),
              style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'AI bridge URL',
                hintText: 'http://192.168.8.100:8000',
              ),
              validator: (value) {
                final raw = value?.trim() ?? '';
                if (raw.isEmpty) return 'URL is required';
                final normalized = raw.startsWith('http') ? raw : 'http://$raw';
                final uri = Uri.tryParse(normalized);
                if (uri == null || uri.host.isEmpty) {
                  return 'Enter a valid URL';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );

    if (ok != true) return null;
    final value = controller.text.trim();
    await _db.ref('app_settings/parking_ai_bridge_url').set(value);
    return value;
  }

  Future<_LotMini?> _chooseLotForAi(List<_LotMini> lots) async {
    if (lots.isEmpty) {
      await showError(
        context,
        AppText.of(
          context,
          ar: 'أضف موقفاً أولاً قبل تحليل الصور.',
          en: 'Add a lot before analyzing images.',
        ),
      );
      return null;
    }
    if (_lotFilter != 'all') {
      for (final lot in lots) {
        if (lot.id == _lotFilter) return lot;
      }
    }

    final p = _PaletteScope.of(context);
    var selected = lots.first.id;
    final ok = await _showNeonDialog<bool>(
      p: p,
      title: AppText.of(
        context,
        ar: 'اختر الموقف للصورة',
        en: 'Choose the lot for this image',
      ),
      icon: Icons.local_parking_rounded,
      cancelText: _camT(context, 'Cancel'),
      primaryText: AppText.of(context, ar: 'متابعة', en: 'Continue'),
      onPrimary: () => Navigator.pop(context, true),
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return DropdownButtonFormField<String>(
            value: selected,
            isExpanded: true,
            dropdownColor: p.menuBg,
            items: [
              for (final lot in lots)
                DropdownMenuItem(
                  value: lot.id,
                  child: Text(
                    lot.name.isEmpty ? lot.id : '${lot.name} (${lot.id})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setDialogState(() => selected = value);
            },
            decoration: InputDecoration(labelText: _camT(context, 'Lot')),
          );
        },
      ),
    );

    if (ok != true) return null;
    return lots.firstWhere((lot) => lot.id == selected,
        orElse: () => lots.first);
  }

  Future<void> _writeAiResultToLiveMap(
    _LotMini lot,
    _ParkingAiResult result,
  ) async {
    final ts = DateTime.now().toUtc().toIso8601String();
    final stalls = <String, dynamic>{};
    for (var i = 0; i < result.stalls.length; i++) {
      final stall = result.stalls[i];
      final id = stall.id.trim().isEmpty
          ? 'ai_stall_${(i + 1).toString().padLeft(3, '0')}'
          : stall.id.trim();
      stalls[id] = {
        'state': stall.state,
        'confidence': stall.confidence,
        'last_seen': ts,
        'bbox': stall.bbox,
        'source': 'admin_image_ai',
      };
    }

    final payload = <String, dynamic>{
      'lot_id': lot.id,
      'free': result.free,
      'occupied': result.occupied,
      'total': result.total,
      'image_width': result.imageWidth,
      'image_height': result.imageHeight,
      'degraded_mode': false,
      'source': 'admin_image_ai',
      'model': result.model,
      'ts': ts,
      'stalls': stalls,
    };

    await _db.ref('live_map/${lot.id}').update(payload);
    await _db.ref('ai_analysis_logs').push().set({
      ...payload,
      'lot_name': lot.name,
      'created_at': ts,
    });
  }

  Future<void> _showAiResultDialog(
    _LotMini lot,
    _ParkingAiResult result,
  ) async {
    final p = _PaletteScope.of(context);
    await _showNeonDialog<void>(
      p: p,
      title: AppText.of(
        context,
        ar: 'تم تحليل الصورة',
        en: 'Image analyzed',
      ),
      icon: Icons.auto_awesome_rounded,
      cancelText: AppText.of(context, ar: 'إغلاق', en: 'Close'),
      primaryText: AppText.of(context, ar: 'موافق', en: 'OK'),
      onPrimary: () => Navigator.pop(context),
      content: _AiResultSummary(lot: lot, result: result),
    );
  }

  Future<void> _analyzeUploadedParkingImage(List<_LotMini> lots) async {
    if (_aiAnalyzing) return;
    final lot = await _chooseLotForAi(lots);
    if (lot == null || !mounted) return;

    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (image == null || !mounted) return;

    setState(() => _aiAnalyzing = true);
    showSnack(
      context,
      AppText.of(
        context,
        ar: 'جاري تحليل الصورة بالموديل...',
        en: 'Analyzing image with the AI model...',
      ),
    );

    try {
      var bridgeUrl = await _loadAiBridgeUrl();
      bridgeUrl = await _resolveWorkingAiBridgeUrl(bridgeUrl);
      if (bridgeUrl.trim().isEmpty && mounted) {
        bridgeUrl = await _promptAiBridgeUrl(bridgeUrl) ?? '';
      }
      if (bridgeUrl.trim().isEmpty || !mounted) return;

      final request = http.MultipartRequest('POST', _analysisUri(bridgeUrl))
        ..fields['lot_id'] = lot.id
        ..files.add(await http.MultipartFile.fromPath('image', image.path));

      final streamed =
          await request.send().timeout(const Duration(seconds: 90));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        throw Exception('AI bridge ${streamed.statusCode}: $body');
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw const FormatException('AI bridge returned invalid JSON');
      }
      final result = _ParkingAiResult.fromJson(mapOf(decoded));
      await _writeAiResultToLiveMap(lot, result);
      if (!mounted) return;
      await _showAiResultDialog(lot, result);
      if (!mounted) return;
      setState(() => _lotFilter = lot.id);
    } catch (e) {
      if (!mounted) return;
      await showError(
        context,
        AppText.of(
          context,
          ar: 'تعذر تحليل الصورة. تأكد أن خدمة Python تعمل وأن الجوال والكمبيوتر على نفس الشبكة.\n\n$e',
          en: 'Image analysis failed. Make sure the Python bridge is running and the phone/computer are on the same network.\n\n$e',
        ),
      );
    } finally {
      if (mounted) setState(() => _aiAnalyzing = false);
    }
  }

  Future<void> _showCameraLive(_CamVM cam) async {
    final p = _PaletteScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.90,
            minChildSize: 0.70,
            maxChildSize: 0.96,
            builder: (context, controller) {
              return ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
                child: Material(
                  color: p.dialogBg,
                  child: ListView(
                    controller: controller,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                    children: [
                      Center(
                        child: Container(
                          width: 46,
                          height: 5,
                          decoration: BoxDecoration(
                            color: p.textMuted.withOpacity(.28),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _LiveSheetHeader(
                        title: cam.lotName.isEmpty ? cam.lotId : cam.lotName,
                        subtitle: '${cam.id} • ${cam.rawStatus}',
                        onClose: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 14),
                      _AdminPrivacyLiveView(
                        lotId: cam.lotId,
                        snapshotUrl: cam.snapshotUrl,
                        streamUrl: cam.streamUrl,
                      ),
                      const SizedBox(height: 14),
                      StreamBuilder<DatabaseEvent>(
                        stream: _db.ref('live_map/${cam.lotId}').onValue,
                        builder: (context, snap) {
                          final live = _AdminLiveLotSnapshot.fromDb(
                            cam.lotId,
                            snap.data?.snapshot.value,
                          );
                          return _AdminLiveOccupancyPanel(live: live);
                        },
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<DatabaseEvent>(
                        stream: _db.ref('Sessions').onValue,
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const _BookingsLoadingCard();
                          }
                          final sessions = childEntries(
                                  snap.data!.snapshot.value)
                              .map((e) => mapOf(e.value))
                              .where((m) =>
                                  (m['lot_id'] ?? '').toString() == cam.lotId)
                              .toList()
                            ..sort((a, b) =>
                                (b['update_at'] ?? b['starttime'] ?? '')
                                    .toString()
                                    .compareTo(
                                        (a['update_at'] ?? a['starttime'] ?? '')
                                            .toString()));
                          final active = sessions
                              .where((m) =>
                                  (m['status'] ?? '').toString() == 'active')
                              .length;
                          final navigating = sessions
                              .where((m) =>
                                  (m['status'] ?? '').toString() ==
                                  'navigating')
                              .length;

                          return _BookingsPanel(
                            sessions: sessions,
                            active: active,
                            navigating: navigating,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeRef = _db.ref('app_settings/ui_theme');

    return StreamBuilder<DatabaseEvent>(
      stream: themeRef.onValue,
      builder: (context, themeSnap) {
        final dbTheme = _DbTheme.fromDb(themeSnap.data?.snapshot.value);
        final p = _Palette(theme: dbTheme, dark: _darkMode);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: _overlayStyle(p),
          child: Theme(
            data: _theme(p),
            child: _PaletteScope(
              palette: p,
              child: Stack(
                children: [
                  Positioned.fill(
                      child: DecoratedBox(decoration: _pageGradient(p))),
                  AdminPageFrame(
                    title: _camT(context, 'Cameras'),
                    isDarkMode: _darkMode,
                    onToggleTheme: _toggleTheme,
                    child: StreamBuilder<DatabaseEvent>(
                      key: _reloadKey,
                      stream: _db.ref('LOTs').onValue,
                      builder: (context, lotSnap) {
                        if (lotSnap.hasError) return errorBox(context, _reload);
                        if (!lotSnap.hasData) return loadingBox(context);

                        final lotsEntries =
                            _safeEntries(lotSnap.data?.snapshot.value);
                        final lots = lotsEntries.map((e) {
                          final m = mapOf(e.value);
                          final id = m['id']?.toString() ?? e.key;
                          return _LotMini(
                            id: id,
                            name: displayText(
                              m['name'],
                              AppText.of(
                                context,
                                ar: 'موقف بدون اسم',
                                en: 'Unnamed Lot',
                              ),
                            ),
                          );
                        }).toList()
                          ..sort((a, b) => a.name
                              .toLowerCase()
                              .compareTo(b.name.toLowerCase()));

                        final lotNameById = {
                          for (final l in lots) l.id: l.name
                        };

                        return StreamBuilder<DatabaseEvent>(
                          stream: _db.ref('cameras').onValue,
                          builder: (context, camSnap) {
                            if (camSnap.hasError) {
                              return errorBox(context, _reload);
                            }
                            if (!camSnap.hasData) {
                              return loadingBox(context);
                            }

                            final camsEntries =
                                _safeEntries(camSnap.data?.snapshot.value);

                            return StreamBuilder<DatabaseEvent>(
                              stream: _db.ref('CameraHealth').onValue,
                              builder: (context, healthSnap) {
                                if (healthSnap.hasError) {
                                  return errorBox(context, _reload);
                                }
                                if (!healthSnap.hasData) {
                                  return loadingBox(context);
                                }

                                final healthEntries = _safeEntries(
                                    healthSnap.data?.snapshot.value);

                                final healthByCamera =
                                    <String, Map<String, dynamic>>{};
                                for (final e in healthEntries) {
                                  final m = mapOf(e.value);
                                  final camId =
                                      m['camera_id']?.toString() ?? '';
                                  if (camId.isNotEmpty) {
                                    healthByCamera[camId] = m;
                                  }
                                }

                                final all = camsEntries.map((e) {
                                  final cam = mapOf(e.value);
                                  final id = cam['id']?.toString() ?? e.key;
                                  final lotId = cam['lot_id']?.toString() ?? '';
                                  final status =
                                      cam['status']?.toString() ?? 'unknown';
                                  final fps = toInt(cam['fps']);
                                  final hb =
                                      cam['last_heartbeat']?.toString() ?? '';
                                  final thr =
                                      toInt(cam['update_threshold_sec']);
                                  final forMap =
                                      cam['for_map']?.toString() ?? '';
                                  final health = healthByCamera[id] ?? {};

                                  final now = DateTime.now().toUtc();
                                  final hbDt = DateTime.tryParse(hb);
                                  final isStale = hbDt != null &&
                                      (thr > 0
                                          ? now
                                                  .difference(hbDt.toUtc())
                                                  .inSeconds >
                                              thr
                                          : now
                                                  .difference(hbDt.toUtc())
                                                  .inMinutes >
                                              5);

                                  final effectiveStatus =
                                      status == 'online' && isStale
                                          ? 'stale'
                                          : status;

                                  return _CamVM(
                                    id: id,
                                    lotId: lotId,
                                    lotName: lotNameById[lotId] ?? '',
                                    status: effectiveStatus,
                                    rawStatus: status,
                                    fpsTarget: fps,
                                    heartbeatIso: hb,
                                    thresholdSec: thr,
                                    forMap: forMap,
                                    health: health,
                                    raw: cam,
                                  );
                                }).toList();

                                all.sort((a, b) => a.id
                                    .toLowerCase()
                                    .compareTo(b.id.toLowerCase()));

                                final online = all
                                    .where((x) => x.rawStatus == 'online')
                                    .length;
                                final offline = all
                                    .where((x) => x.rawStatus != 'online')
                                    .length;
                                final stale = all
                                    .where((x) => x.status == 'stale')
                                    .length;

                                final existingIds =
                                    all.map((e) => e.id).toSet();
                                final q = _q.trim().toLowerCase();

                                final filtered = all.where((x) {
                                  if (_statusFilter != 'all') {
                                    if (_statusFilter == 'online' &&
                                        x.status != 'online') return false;
                                    if (_statusFilter == 'offline' &&
                                        x.rawStatus == 'online') return false;
                                    if (_statusFilter == 'stale' &&
                                        x.status != 'stale') return false;
                                  }
                                  if (_lotFilter != 'all' &&
                                      x.lotId != _lotFilter) return false;
                                  if (q.isEmpty) return true;

                                  final t =
                                      '${x.id} ${x.status} ${x.lotId} ${x.lotName} ${x.fpsTarget} ${x.thresholdSec} ${x.forMap}'
                                          .toLowerCase();
                                  return t.contains(q);
                                }).toList();

                                return _buildDashboard(
                                  context: context,
                                  palette: p,
                                  all: all,
                                  filtered: filtered,
                                  lots: lots,
                                  online: online,
                                  offline: offline,
                                  stale: stale,
                                  existingIds: existingIds,
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDashboard({
    required BuildContext context,
    required _Palette palette,
    required List<_CamVM> all,
    required List<_CamVM> filtered,
    required List<_LotMini> lots,
    required int online,
    required int offline,
    required int stale,
    required Set<String> existingIds,
  }) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final compact = w < 520;
        final cross = w >= 1100 ? 3 : (w >= 820 ? 2 : 1);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _BlueStatCard(
                            title: _camT(context, 'Online'),
                            value: '$online',
                            icon: Icons.videocam_rounded,
                            accent: palette.success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _BlueStatCard(
                            title: _camT(context, 'Offline'),
                            value: '$offline',
                            icon: Icons.videocam_off_outlined,
                            accent: palette.danger,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _BlueStatCard(
                            title: _camT(context, 'Stale'),
                            value: '$stale',
                            icon: Icons.timer_outlined,
                            accent: palette.warn,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: _glassCard(palette),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (compact) ...[
                            TextField(
                              controller: _search,
                              onChanged: (v) => setState(() => _q = v),
                              decoration: _searchDec(palette),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _GradientButton(
                                    height: 46,
                                    radius: 999,
                                    label: _camT(context, 'Add'),
                                    icon: Icons.add_rounded,
                                    colors: palette.primaryGradient,
                                    glow: palette.accentGlow,
                                    onPressed: () => _addCameraDialog(
                                      existingIds: existingIds,
                                      lots: lots,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _iconChipBtn(
                                  palette,
                                  tooltip: AppText.of(
                                    context,
                                    ar: 'تحليل صورة بالموديل',
                                    en: 'Analyze image with AI',
                                  ),
                                  onTap: _aiAnalyzing
                                      ? () {}
                                      : () =>
                                          _analyzeUploadedParkingImage(lots),
                                  icon: _aiAnalyzing
                                      ? Icons.hourglass_top_rounded
                                      : Icons.auto_awesome_rounded,
                                ),
                                const SizedBox(width: 10),
                                _iconChipBtn(
                                  palette,
                                  tooltip: _camT(context, 'Refresh'),
                                  onTap: _reload,
                                  icon: Icons.refresh_rounded,
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _search,
                                    onChanged: (v) => setState(() => _q = v),
                                    decoration: _searchDec(palette),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _GradientButton(
                                  height: 46,
                                  radius: 16,
                                  label: _camT(context, 'Add'),
                                  icon: Icons.add_rounded,
                                  colors: palette.primaryGradient,
                                  glow: palette.accentGlow,
                                  onPressed: () => _addCameraDialog(
                                    existingIds: existingIds,
                                    lots: lots,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _GradientButton(
                                  height: 46,
                                  radius: 16,
                                  label: _aiAnalyzing
                                      ? AppText.of(
                                          context,
                                          ar: 'جاري التحليل',
                                          en: 'Analyzing',
                                        )
                                      : AppText.of(
                                          context,
                                          ar: 'تحليل صورة',
                                          en: 'Analyze image',
                                        ),
                                  icon: _aiAnalyzing
                                      ? Icons.hourglass_top_rounded
                                      : Icons.auto_awesome_rounded,
                                  colors: <Color>[
                                    palette.success,
                                    palette.accent
                                  ],
                                  glow: palette.success,
                                  onPressed: _aiAnalyzing
                                      ? () {}
                                      : () =>
                                          _analyzeUploadedParkingImage(lots),
                                ),
                                const SizedBox(width: 10),
                                _iconChipBtn(
                                  palette,
                                  tooltip: _camT(context, 'Refresh'),
                                  onTap: _reload,
                                  icon: Icons.refresh_rounded,
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          if (compact) ...[
                            DropdownButtonFormField<String>(
                              value: _statusFilter,
                              isExpanded: true,
                              dropdownColor: palette.menuBg,
                              items: [
                                DropdownMenuItem(
                                    value: 'all',
                                    child:
                                        Text(_camT(context, 'All statuses'))),
                                DropdownMenuItem(
                                    value: 'online',
                                    child: Text(_camT(context, 'Online'))),
                                DropdownMenuItem(
                                    value: 'offline',
                                    child: Text(_camT(context, 'Offline'))),
                                DropdownMenuItem(
                                    value: 'stale',
                                    child: Text(_camT(context, 'Stale'))),
                              ],
                              onChanged: (v) =>
                                  setState(() => _statusFilter = v ?? 'all'),
                              decoration: _ddDec('Status filter'),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              value: _lotFilter,
                              isExpanded: true,
                              dropdownColor: palette.menuBg,
                              items: [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text(_camT(context, 'All lots')),
                                ),
                                ...lots.map(
                                  (l) => DropdownMenuItem(
                                    value: l.id,
                                    child: Text(
                                      l.name.isEmpty ? l.id : l.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _lotFilter = v ?? 'all'),
                              decoration: _ddDec('Lot filter'),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _statusFilter,
                                    isExpanded: true,
                                    dropdownColor: palette.menuBg,
                                    items: [
                                      DropdownMenuItem(
                                          value: 'all',
                                          child: Text(
                                              _camT(context, 'All statuses'))),
                                      DropdownMenuItem(
                                          value: 'online',
                                          child:
                                              Text(_camT(context, 'Online'))),
                                      DropdownMenuItem(
                                          value: 'offline',
                                          child:
                                              Text(_camT(context, 'Offline'))),
                                      DropdownMenuItem(
                                          value: 'stale',
                                          child: Text(_camT(context, 'Stale'))),
                                    ],
                                    onChanged: (v) => setState(
                                        () => _statusFilter = v ?? 'all'),
                                    decoration: _ddDec('Status filter'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _lotFilter,
                                    isExpanded: true,
                                    dropdownColor: palette.menuBg,
                                    items: [
                                      DropdownMenuItem(
                                        value: 'all',
                                        child: Text(_camT(context, 'All lots')),
                                      ),
                                      ...lots.map(
                                        (l) => DropdownMenuItem(
                                          value: l.id,
                                          child: Text(
                                            l.name.isEmpty ? l.id : l.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _lotFilter = v ?? 'all'),
                                    decoration: _ddDec('Lot filter'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _BluePill(
                                icon: Icons.tune_rounded,
                                text: _q.trim().isEmpty
                                    ? AppText.of(
                                        context,
                                        ar: 'عرض الكل (${all.length})',
                                        en: 'Showing all (${all.length})',
                                      )
                                    : AppText.of(
                                        context,
                                        ar: 'عرض ${filtered.length} من ${all.length}',
                                        en: 'Showing ${filtered.length} of ${all.length}',
                                      ),
                              ),
                              const Spacer(),
                              if (_q.trim().isNotEmpty && filtered.isEmpty)
                                Text(
                                  _camT(context, 'No results'),
                                  style: TextStyle(
                                    color: palette.textMuted,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: _softCard(palette),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: palette.accentGlow,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _q.trim().isEmpty
                                    ? _camT(
                                        context,
                                        'No cameras yet. Add your first camera.',
                                      )
                                    : _camT(
                                        context,
                                        'No cameras match your search/filters.',
                                      ),
                                softWrap: true,
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: palette.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _GradientButton(
                          height: 40,
                          radius: 999,
                          label: _camT(context, 'Add camera'),
                          icon: Icons.add_rounded,
                          colors: palette.primaryGradient,
                          glow: palette.accentGlow,
                          onPressed: () => _addCameraDialog(
                              existingIds: existingIds, lots: lots),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                sliver: cross == 1
                    ? SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CameraCardBlue(
                              vm: filtered[i],
                              onViewLive: () => _showCameraLive(filtered[i]),
                              onToggle: () => _toggleCamera(
                                  filtered[i].id, filtered[i].rawStatus),
                              onHeartbeat: () =>
                                  _touchHeartbeat(filtered[i].id),
                              onEdit: () => _editCameraDialog(
                                  cam: filtered[i], lots: lots),
                              onDelete: () =>
                                  _deleteCamera(filtered[i].id, filtered[i].id),
                            ),
                          ),
                          childCount: filtered.length,
                        ),
                      )
                    : SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _CameraCardBlue(
                            vm: filtered[i],
                            onViewLive: () => _showCameraLive(filtered[i]),
                            onToggle: () => _toggleCamera(
                                filtered[i].id, filtered[i].rawStatus),
                            onHeartbeat: () => _touchHeartbeat(filtered[i].id),
                            onEdit: () =>
                                _editCameraDialog(cam: filtered[i], lots: lots),
                            onDelete: () =>
                                _deleteCamera(filtered[i].id, filtered[i].id),
                          ),
                          childCount: filtered.length,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: cross == 2 ? 1.35 : 1.55,
                        ),
                      ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _addCameraDialog(
      {required Set<String> existingIds, required List<_LotMini> lots}) async {
    final p = _PaletteScope.of(context);

    final formKey = GlobalKey<FormState>();
    final id = TextEditingController();
    final fps = TextEditingController(text: '15');
    final thr = TextEditingController(text: '30');
    final forMap = TextEditingController(text: 'default');
    String status = 'online';
    String lotId = lots.isNotEmpty ? lots.first.id : '';

    String? vId(String v) {
      final t = v.trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'معرّف الكاميرا مطلوب', en: 'Camera ID is required');
      }
      if (!RegExp(r'^[a-zA-Z0-9_\-]+$').hasMatch(t)) {
        return AppText.of(
          context,
          ar: 'مسموح فقط بالحروف والأرقام و "_" أو "-"',
          en: 'Only letters, numbers, "_" or "-"',
        );
      }
      if (existingIds.contains(t)) {
        return AppText.of(context,
            ar: 'معرّف الكاميرا موجود مسبقًا', en: 'Camera ID already exists');
      }
      return null;
    }

    String? vLot(String v) {
      final t = v.trim();
      if (t.isEmpty) {
        return AppText.of(context, ar: 'الموقف مطلوب', en: 'Lot is required');
      }
      if (lots.isNotEmpty && !lots.any((l) => l.id == t)) {
        return AppText.of(context, ar: 'الموقف غير موجود', en: 'Lot not found');
      }
      return null;
    }

    String? vInt(String v, {required String label, int? min, int? max}) {
      final t = v.trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: '${_camT(context, label)} مطلوب', en: '$label is required');
      }
      final n = int.tryParse(t);
      if (n == null) {
        return AppText.of(context,
            ar: 'أدخل رقمًا صحيحًا', en: 'Enter a valid integer');
      }
      if (min != null && n < min) {
        return AppText.of(context,
            ar: 'الحد الأدنى هو $min', en: 'Minimum is $min');
      }
      if (max != null && n > max) {
        return AppText.of(context,
            ar: 'الحد الأقصى هو $max', en: 'Maximum is $max');
      }
      return null;
    }

    String? vText(String v, String label) {
      final t = v.trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: '$label مطلوب', en: '$label is required');
      }
      if (t.length > 120) {
        return AppText.of(context,
            ar: '$label طويل جدًا', en: '$label is too long');
      }
      return null;
    }

    final ok = await _showNeonDialog<bool>(
      p: p,
      title: _camT(context, 'Add Camera'),
      icon: Icons.videocam_outlined,
      cancelText: _camT(context, 'Cancel'),
      primaryText: _camT(context, 'Create'),
      onPrimary: () {
        FocusScope.of(context).unfocus();
        if (formKey.currentState?.validate() != true) return;
        Navigator.pop(context, true);
      },
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: StatefulBuilder(
          builder: (context, setD) => Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(
                    controller: id,
                    decoration: InputDecoration(
                      labelText: _camT(context, 'Camera ID (e.g., camera_001)'),
                    ),
                    validator: (v) => vId(v ?? ''),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  if (lots.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: lotId,
                      isExpanded: true,
                      dropdownColor: p.menuBg,
                      items: lots
                          .map(
                            (l) => DropdownMenuItem(
                              value: l.id,
                              child: Text(l.name.isEmpty ? l.id : l.name,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setD(() => lotId = v ?? lotId),
                      validator: (_) => vLot(lotId),
                      decoration:
                          InputDecoration(labelText: _camT(context, 'Lot')),
                    )
                  else
                    TextFormField(
                      initialValue: lotId,
                      onChanged: (v) => setD(() => lotId = v),
                      decoration:
                          InputDecoration(labelText: _camT(context, 'Lot ID')),
                      validator: (v) => vLot(v ?? ''),
                      textInputAction: TextInputAction.next,
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: fps,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: _camT(context, 'FPS target')),
                          validator: (v) => vInt(v ?? '',
                              label: 'FPS target', min: 1, max: 120),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: thr,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _camT(context, 'Update threshold (sec)'),
                          ),
                          validator: (v) => vInt(v ?? '',
                              label: 'Threshold', min: 0, max: 86400),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: forMap,
                    decoration: InputDecoration(
                      labelText: _camT(context, 'Map FOV / for_map'),
                    ),
                    validator: (v) => vText(v ?? '', 'for_map'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: status,
                    isExpanded: true,
                    dropdownColor: p.menuBg,
                    items: [
                      DropdownMenuItem(
                        value: 'online',
                        child: Text(_camT(context, 'Online')),
                      ),
                      DropdownMenuItem(
                        value: 'offline',
                        child: Text(_camT(context, 'Offline')),
                      ),
                    ],
                    onChanged: (v) => setD(() => status = v ?? status),
                    decoration:
                        InputDecoration(labelText: _camT(context, 'Status')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (ok != true) return;

    final camId = id.text.trim();
    final payload = {
      'id': camId,
      'lot_id': lotId.trim(),
      'status': status,
      'fps': int.tryParse(fps.text.trim()) ?? 15,
      'update_threshold_sec': int.tryParse(thr.text.trim()) ?? 30,
      'for_map': forMap.text.trim(),
      'last_heartbeat': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _db.ref('cameras/$camId').set(payload);
      if (!mounted) return;
      await showOk(
        context,
        _camT(context, 'Created'),
        AppText.of(
          context,
          ar: 'تمت إضافة الكاميرا بنجاح',
          en: 'Camera added successfully',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _editCameraDialog(
      {required _CamVM cam, required List<_LotMini> lots}) async {
    final p = _PaletteScope.of(context);

    final formKey = GlobalKey<FormState>();
    final fps = TextEditingController(text: '${cam.fpsTarget}');
    final thr = TextEditingController(text: '${cam.thresholdSec}');
    final forMap = TextEditingController(text: cam.forMap);
    String status = cam.rawStatus;
    String lotId = cam.lotId;

    String? vLot(String v) {
      final t = v.trim();
      if (t.isEmpty) {
        return AppText.of(context, ar: 'الموقف مطلوب', en: 'Lot is required');
      }
      if (lots.isNotEmpty && !lots.any((l) => l.id == t)) {
        return AppText.of(context, ar: 'الموقف غير موجود', en: 'Lot not found');
      }
      return null;
    }

    String? vInt(String v, {required String label, int? min, int? max}) {
      final t = v.trim();
      if (t.isEmpty) return '$label is required';
      final n = int.tryParse(t);
      if (n == null) {
        return AppText.of(context,
            ar: 'أدخل رقمًا صحيحًا', en: 'Enter a valid integer');
      }
      if (min != null && n < min) {
        return AppText.of(context,
            ar: 'الحد الأدنى هو $min', en: 'Minimum is $min');
      }
      if (max != null && n > max) {
        return AppText.of(context,
            ar: 'الحد الأقصى هو $max', en: 'Maximum is $max');
      }
      return null;
    }

    String? vText(String v, String label) {
      final t = v.trim();
      if (t.isEmpty) return '$label is required';
      if (t.length > 120) return '$label is too long';
      return null;
    }

    final ok = await _showNeonDialog<bool>(
      p: p,
      title: AppText.of(
        context,
        ar: 'تعديل ${cam.id}',
        en: 'Edit ${cam.id}',
      ),
      icon: Icons.edit_outlined,
      cancelText: _camT(context, 'Cancel'),
      primaryText: _camT(context, 'Save'),
      onPrimary: () {
        FocusScope.of(context).unfocus();
        if (formKey.currentState?.validate() != true) return;
        Navigator.pop(context, true);
      },
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: StatefulBuilder(
          builder: (context, setD) => Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (lots.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: lots.any((l) => l.id == lotId)
                          ? lotId
                          : lots.first.id,
                      isExpanded: true,
                      dropdownColor: p.menuBg,
                      items: lots
                          .map(
                            (l) => DropdownMenuItem(
                              value: l.id,
                              child: Text(l.name.isEmpty ? l.id : l.name,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setD(() => lotId = v ?? lotId),
                      validator: (_) => vLot(lotId),
                      decoration:
                          InputDecoration(labelText: _camT(context, 'Lot')),
                    )
                  else
                    TextFormField(
                      initialValue: lotId,
                      onChanged: (v) => setD(() => lotId = v),
                      decoration:
                          InputDecoration(labelText: _camT(context, 'Lot ID')),
                      validator: (v) => vLot(v ?? ''),
                      textInputAction: TextInputAction.next,
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: fps,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: _camT(context, 'FPS target')),
                          validator: (v) => vInt(v ?? '',
                              label: 'FPS target', min: 1, max: 120),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: thr,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Update threshold (sec)'),
                          validator: (v) => vInt(v ?? '',
                              label: 'Threshold', min: 0, max: 86400),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: forMap,
                    decoration: InputDecoration(
                        labelText: _camT(context, 'Map FOV / for_map')),
                    validator: (v) => vText(v ?? '', 'for_map'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: status,
                    isExpanded: true,
                    dropdownColor: p.menuBg,
                    items: [
                      DropdownMenuItem(
                        value: 'online',
                        child: Text(_camT(context, 'Online')),
                      ),
                      DropdownMenuItem(
                        value: 'offline',
                        child: Text(_camT(context, 'Offline')),
                      ),
                    ],
                    onChanged: (v) => setD(() => status = v ?? status),
                    decoration:
                        InputDecoration(labelText: _camT(context, 'Status')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (ok != true) return;

    try {
      await _db.ref('cameras/${cam.id}').update({
        'lot_id': lotId.trim(),
        'status': status,
        'fps': int.tryParse(fps.text.trim()) ?? 15,
        'update_threshold_sec': int.tryParse(thr.text.trim()) ?? 30,
        'for_map': forMap.text.trim(),
      });
      if (!mounted) return;
      await showOk(
        context,
        _camT(context, 'Saved'),
        AppText.of(
          context,
          ar: 'تم تحديث الكاميرا بنجاح',
          en: 'Camera updated successfully',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _deleteCamera(String id, String name) async {
    final p = _PaletteScope.of(context);

    bool hasHealth = false;
    try {
      final snap = await _db.ref('CameraHealth').get();
      final entries = _safeEntries(snap.value);
      hasHealth = entries.any((e) => s(mapOf(e.value)['camera_id']) == id);
    } catch (_) {}
    if (!mounted) return;

    final msg = hasHealth
        ? AppText.of(
            context,
            ar: 'هذه الكاميرا لها سجلات صحة. حذف الكاميرا لن يحذف سجلات الصحة تلقائيًا.\n\nهل تريد حذف الكاميرا رغم ذلك؟',
            en: 'This camera has health records.\nDeleting camera will not automatically remove health entries.\n\nDelete camera anyway?',
          )
        : AppText.of(
            context,
            ar: 'هل تريد حذف هذه الكاميرا نهائيًا؟',
            en: 'Delete this camera permanently?',
          );

    final ok = await _showNeonDialog<bool>(
      p: p,
      title: _camT(context, 'Delete camera'),
      icon: Icons.delete_outline_rounded,
      danger: true,
      cancelText: _camT(context, 'Cancel'),
      primaryText: _camT(context, 'Delete'),
      onPrimary: () => Navigator.pop(context, true),
      content: Text(
        msg,
        style: TextStyle(
          color: p.text.withOpacity(0.92),
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (ok != true) return;

    try {
      await _db.ref('cameras/$id').remove();
      if (!mounted) return;
      await showOk(
        context,
        _camT(context, 'Deleted'),
        AppText.of(
          context,
          ar: 'تم حذف الكاميرا بنجاح',
          en: 'Camera removed successfully',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _toggleCamera(String id, String status) async {
    final next = status == 'online' ? 'offline' : 'online';
    try {
      await _db.ref('cameras/$id').update({
        'status': next,
        'last_heartbeat': DateTime.now().toUtc().toIso8601String(),
      });
      if (!mounted) return;
      await showOk(
        context,
        _camT(context, 'Saved'),
        AppText.of(
          context,
          ar: 'تم تحديث حالة الكاميرا إلى ${_camT(context, next == 'online' ? 'Online' : 'Offline')}',
          en: 'Camera status updated to $next',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _touchHeartbeat(String id) async {
    try {
      await _db
          .ref('cameras/$id/last_heartbeat')
          .set(DateTime.now().toUtc().toIso8601String());
      if (!mounted) return;
      await showOk(
        context,
        _camT(context, 'Saved'),
        AppText.of(
          context,
          ar: 'تم تحديث آخر نبضة',
          en: 'Heartbeat updated',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }
}

class _LotMini {
  final String id;
  final String name;
  _LotMini({required this.id, required this.name});
}

class _LiveSheetHeader extends StatelessWidget {
  const _LiveSheetHeader({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [p.cardA, p.cardB],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: p.primaryGradient),
              boxShadow: [
                BoxShadow(
                  color: p.accentGlow.withOpacity(.24),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.live_tv_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: p.softCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.border),
              ),
              child: Icon(Icons.close_rounded, color: p.icon),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingsLoadingCard extends StatelessWidget {
  const _BookingsLoadingCard();

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.softCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: p.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppText.of(
                context,
                ar: 'جاري تحميل الحجوزات...',
                en: 'Loading bookings...',
              ),
              style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingsPanel extends StatelessWidget {
  const _BookingsPanel({
    required this.sessions,
    required this.active,
    required this.navigating,
  });

  final List<Map<String, dynamic>> sessions;
  final int active;
  final int navigating;

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppText.of(context, ar: 'الحجوزات المرتبطة', en: 'Linked bookings'),
          style: TextStyle(
            color: p.text,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _BluePill(
              icon: Icons.local_parking_rounded,
              text: AppText.of(
                context,
                ar: 'الحجوزات: ${sessions.length}',
                en: 'Bookings: ${sessions.length}',
              ),
            ),
            _BluePill(
              icon: Icons.timer_outlined,
              text: AppText.of(
                context,
                ar: 'بالطريق: $navigating',
                en: 'Navigating: $navigating',
              ),
            ),
            _BluePill(
              icon: Icons.check_circle_outline_rounded,
              text: AppText.of(context,
                  ar: 'نشطة: $active', en: 'Active: $active'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (sessions.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.softCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                Icon(Icons.event_available_outlined, color: p.iconMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppText.of(
                      context,
                      ar: 'لا توجد حجوزات لهذا الموقف.',
                      en: 'No bookings for this lot.',
                    ),
                    style: TextStyle(
                      color: p.textMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...sessions.take(20).map((m) => _BookingRecordCard(data: m)),
      ],
    );
  }
}

String _normalizeParkingState(dynamic value) {
  final raw = s(value, 'unknown').trim().toLowerCase();
  if (raw.contains('empty') ||
      raw.contains('free') ||
      raw.contains('available') ||
      raw.contains('vacant') ||
      raw.contains('فارغ') ||
      raw.contains('متاح')) {
    return 'free';
  }
  if (raw.contains('occupied') ||
      raw.contains('busy') ||
      raw.contains('taken') ||
      raw.contains('not_free') ||
      raw.contains('not-free') ||
      raw.contains('مشغول')) {
    return 'occupied';
  }
  if (raw.contains('reserved') ||
      raw.contains('booked') ||
      raw.contains('محجوز')) {
    return 'reserved';
  }
  return raw.isEmpty ? 'unknown' : raw;
}

String _parkingStateText(BuildContext context, String state) {
  if (state == 'free') {
    return AppText.of(context, ar: 'فارغ', en: 'Free');
  }
  if (state == 'occupied') {
    return AppText.of(context, ar: 'مشغول', en: 'Occupied');
  }
  if (state == 'reserved') {
    return AppText.of(context, ar: 'محجوز', en: 'Reserved');
  }
  return AppText.of(context, ar: 'غير معروف', en: 'Unknown');
}

Color _parkingStateColor(_Palette p, String state) {
  if (state == 'free') return p.success;
  if (state == 'occupied') return p.danger;
  if (state == 'reserved') return p.warn;
  return p.textMuted;
}

class _ParkingAiStall {
  const _ParkingAiStall({
    required this.id,
    required this.state,
    required this.confidence,
    required this.bbox,
  });

  final String id;
  final String state;
  final double confidence;
  final List<double> bbox;

  static List<double> _bbox(dynamic value) {
    if (value is List) {
      return value.map((e) => toDouble(e)).toList(growable: false);
    }
    return const <double>[];
  }

  factory _ParkingAiStall.fromJson(Map<String, dynamic> json, int index) {
    return _ParkingAiStall(
      id: s(json['id'], 'stall_${(index + 1).toString().padLeft(3, '0')}'),
      state: _normalizeParkingState(
        json['state'] ?? json['class_name'] ?? json['name'],
      ),
      confidence: toDouble(json['confidence'] ?? json['score']),
      bbox: _bbox(json['bbox']),
    );
  }
}

class _ParkingAiResult {
  const _ParkingAiResult({
    required this.free,
    required this.occupied,
    required this.total,
    required this.imageWidth,
    required this.imageHeight,
    required this.model,
    required this.stalls,
  });

  final int free;
  final int occupied;
  final int total;
  final int imageWidth;
  final int imageHeight;
  final String model;
  final List<_ParkingAiStall> stalls;

  factory _ParkingAiResult.fromJson(Map<String, dynamic> json) {
    final rawStalls = json['stalls'];
    final stalls = <_ParkingAiStall>[];
    if (rawStalls is List) {
      for (var i = 0; i < rawStalls.length; i++) {
        stalls.add(_ParkingAiStall.fromJson(mapOf(rawStalls[i]), i));
      }
    }

    final countedFree = stalls.where((s) => s.state == 'free').length;
    final countedOccupied = stalls.where((s) => s.state == 'occupied').length;
    final free = toInt(json['free']);
    final occupied = toInt(json['occupied']);
    final total = toInt(json['total']);

    return _ParkingAiResult(
      free: free > 0 ? free : countedFree,
      occupied: occupied > 0 ? occupied : countedOccupied,
      total: total > 0 ? total : stalls.length,
      imageWidth: toInt(json['image_width']),
      imageHeight: toInt(json['image_height']),
      model: s(json['model'], 'parking_detector_fast.pt'),
      stalls: stalls,
    );
  }
}

class _AdminLiveStallSnapshot {
  const _AdminLiveStallSnapshot({
    required this.id,
    required this.state,
    required this.confidence,
    required this.lastSeen,
    required this.bbox,
  });

  final String id;
  final String state;
  final double? confidence;
  final String lastSeen;
  final List<double> bbox;

  static List<double> _bbox(dynamic value) {
    if (value is List) {
      return value.map((entry) => toDouble(entry)).toList(growable: false);
    }
    return const <double>[];
  }

  factory _AdminLiveStallSnapshot.fromEntry(MapEntry<String, dynamic> entry) {
    final row = mapOf(entry.value);
    return _AdminLiveStallSnapshot(
      id: s(row['id'], entry.key),
      state: _normalizeParkingState(row['state']),
      confidence:
          row.containsKey('confidence') ? toDouble(row['confidence']) : null,
      lastSeen: s(row['last_seen'], ''),
      bbox: _bbox(row['bbox']),
    );
  }
}

class _AdminLiveLotSnapshot {
  const _AdminLiveLotSnapshot({
    required this.lotId,
    required this.free,
    required this.occupied,
    required this.total,
    required this.ts,
    required this.source,
    required this.stalls,
    required this.hasData,
    required this.imageWidth,
    required this.imageHeight,
  });

  final String lotId;
  final int free;
  final int occupied;
  final int total;
  final String ts;
  final String source;
  final List<_AdminLiveStallSnapshot> stalls;
  final bool hasData;
  final int imageWidth;
  final int imageHeight;

  factory _AdminLiveLotSnapshot.fromDb(String lotId, dynamic value) {
    final row = mapOf(value);
    final rawStalls = mapOf(row['stalls']);
    final stalls = rawStalls.entries
        .map(_AdminLiveStallSnapshot.fromEntry)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    var free = toInt(row['free']);
    var occupied = toInt(row['occupied']);
    final countedFree = stalls.where((s) => s.state == 'free').length;
    final countedOccupied = stalls.where((s) => s.state == 'occupied').length;
    if (countedFree + countedOccupied > 0) {
      free = countedFree;
      occupied = countedOccupied;
    }

    var total = toInt(row['total']);
    if (total <= 0) total = stalls.length;
    if (total < free + occupied) total = free + occupied;

    return _AdminLiveLotSnapshot(
      lotId: lotId,
      free: free,
      occupied: occupied,
      total: total,
      ts: s(row['ts'], ''),
      source: s(row['source'], ''),
      stalls: stalls,
      hasData: row.isNotEmpty,
      imageWidth: toInt(row['image_width']),
      imageHeight: toInt(row['image_height']),
    );
  }
}

class _AdminLiveOccupancyPanel extends StatelessWidget {
  const _AdminLiveOccupancyPanel({required this.live});

  final _AdminLiveLotSnapshot live;

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.softCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view_rounded, color: p.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppText.of(
                    context,
                    ar: 'حالة المواقف من الذكاء الاصطناعي',
                    en: 'AI stall availability',
                  ),
                  style: TextStyle(
                    color: p.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (live.source.isNotEmpty)
                _BluePill(
                  icon: Icons.memory_rounded,
                  text: live.source,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LiveCountPill(
                icon: Icons.local_parking_rounded,
                label: AppText.of(context, ar: 'فارغة', en: 'Free'),
                value: live.free,
                color: p.success,
              ),
              _LiveCountPill(
                icon: Icons.block_rounded,
                label: AppText.of(context, ar: 'مشغولة', en: 'Occupied'),
                value: live.occupied,
                color: p.danger,
              ),
              _LiveCountPill(
                icon: Icons.apps_rounded,
                label: AppText.of(context, ar: 'الإجمالي', en: 'Total'),
                value: live.total,
                color: p.accentGlow,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!live.hasData)
            Text(
              AppText.of(
                context,
                ar: 'لا توجد نتيجة تحليل بعد. ارفع صورة أو شغل خدمة الكاميرا ليتم تحديث الأرقام هنا.',
                en: 'No analysis result yet. Upload an image or run the camera bridge to update these numbers here.',
              ),
              style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w800),
            )
          else if (live.stalls.isEmpty)
            Text(
              AppText.of(
                context,
                ar: 'الأعداد موجودة لكن تفاصيل كل موقف غير مرسلة بعد.',
                en: 'Counts are available, but stall-level details were not sent yet.',
              ),
              style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w800),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final stall in live.stalls) _LiveStallChip(stall: stall),
              ],
            ),
          if (live.ts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              AppText.of(
                context,
                ar: 'آخر تحديث: ${dateShort(live.ts)}',
                en: 'Updated: ${dateShort(live.ts)}',
              ),
              style: TextStyle(
                color: p.textMuted,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveCountPill extends StatelessWidget {
  const _LiveCountPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(p.dark ? 0.15 : 0.11),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(p.dark ? 0.30 : 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: TextStyle(color: p.text, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _CameraAvailabilityStrip extends StatelessWidget {
  const _CameraAvailabilityStrip({required this.live});

  final _AdminLiveLotSnapshot live;

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.fieldFill.withOpacity(0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          _MiniAvailabilityItem(
            icon: Icons.local_parking_rounded,
            label: AppText.of(context, ar: 'فارغ', en: 'Free'),
            value: live.free,
            color: p.success,
          ),
          const SizedBox(width: 8),
          _MiniAvailabilityItem(
            icon: Icons.block_rounded,
            label: AppText.of(context, ar: 'مشغول', en: 'Occupied'),
            value: live.occupied,
            color: p.danger,
          ),
          const SizedBox(width: 8),
          _MiniAvailabilityItem(
            icon: Icons.apps_rounded,
            label: AppText.of(context, ar: 'كلي', en: 'Total'),
            value: live.total,
            color: p.accentGlow,
          ),
        ],
      ),
    );
  }
}

class _MiniAvailabilityItem extends StatelessWidget {
  const _MiniAvailabilityItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              '$label $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.text,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveStallChip extends StatelessWidget {
  const _LiveStallChip({required this.stall});

  final _AdminLiveStallSnapshot stall;

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);
    final color = _parkingStateColor(p, stall.state);
    final confidence = stall.confidence == null
        ? ''
        : ' ${(stall.confidence! * 100).clamp(0, 100).toStringAsFixed(0)}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(p.dark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(p.dark ? 0.30 : 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            stall.state == 'free'
                ? Icons.local_parking_rounded
                : stall.state == 'occupied'
                    ? Icons.block_rounded
                    : Icons.help_outline_rounded,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 6),
          Text(
            '${stall.id}  ${_parkingStateText(context, stall.state)}$confidence',
            style: TextStyle(
              color: p.text,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiResultSummary extends StatelessWidget {
  const _AiResultSummary({
    required this.lot,
    required this.result,
  });

  final _LotMini lot;
  final _ParkingAiResult result;

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);
    final shown = result.stalls.take(12).toList();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lot.name.isEmpty ? lot.id : lot.name,
            style: TextStyle(
              color: p.text,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LiveCountPill(
                icon: Icons.local_parking_rounded,
                label: AppText.of(context, ar: 'فارغة', en: 'Free'),
                value: result.free,
                color: p.success,
              ),
              _LiveCountPill(
                icon: Icons.block_rounded,
                label: AppText.of(context, ar: 'مشغولة', en: 'Occupied'),
                value: result.occupied,
                color: p.danger,
              ),
              _LiveCountPill(
                icon: Icons.apps_rounded,
                label: AppText.of(context, ar: 'الإجمالي', en: 'Total'),
                value: result.total,
                color: p.accentGlow,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppText.of(
              context,
              ar: 'تم تحديث live_map/${lot.id} بهذه النتيجة، وستظهر في الخريطة وصفحة الكاميرا.',
              en: 'live_map/${lot.id} was updated, so the map and camera sheet will show this result.',
            ),
            style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w800),
          ),
          if (shown.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final stall in shown)
                  _LiveStallChip(
                    stall: _AdminLiveStallSnapshot(
                      id: stall.id,
                      state: stall.state,
                      confidence: stall.confidence,
                      lastSeen: '',
                      bbox: stall.bbox,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BookingRecordCard extends StatelessWidget {
  const _BookingRecordCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);
    final stallId = displayText(data['stall_id'], '-');
    final status = displayText(data['status'], '-');
    final userId = displayText(data['user_id'], '-');
    final time = (data['starttime'] ?? data['update_at'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.softCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.accentGlow.withOpacity(.12),
              border: Border.all(color: p.accentGlow.withOpacity(.22)),
            ),
            child: Icon(Icons.receipt_long_rounded, color: p.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$stallId • $status',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  userId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  dateShort(time),
                  style: TextStyle(
                    color: p.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminPrivacyLiveView extends StatefulWidget {
  const _AdminPrivacyLiveView({
    required this.lotId,
    required this.snapshotUrl,
    required this.streamUrl,
  });

  final String lotId;
  final String snapshotUrl;
  final String streamUrl;

  @override
  State<_AdminPrivacyLiveView> createState() => _AdminPrivacyLiveViewState();
}

class _AdminPrivacyLiveViewState extends State<_AdminPrivacyLiveView> {
  Timer? _timer;
  Timer? _timeoutTimer;
  int _tick = 0;
  bool _hasFrame = false;
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();
    _scheduleTimeout();
    _timer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!mounted || !_hasFrame || _hasLoadError) return;
      setState(() => _tick++);
    });
  }

  @override
  void didUpdateWidget(covariant _AdminPrivacyLiveView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshotUrl != widget.snapshotUrl ||
        oldWidget.streamUrl != widget.streamUrl) {
      _retry();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _scheduleTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || _hasFrame) return;
      setState(() => _hasLoadError = true);
    });
  }

  String get _url {
    final raw = widget.snapshotUrl.trim().isNotEmpty
        ? widget.snapshotUrl
        : widget.streamUrl;
    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;
    final query = Map<String, String>.from(uri.queryParameters)
      ..['privacy'] = '1'
      ..['ts'] = _tick.toString();
    return uri.replace(queryParameters: query).toString();
  }

  void _retry() {
    _scheduleTimeout();
    setState(() {
      _hasLoadError = false;
      _hasFrame = false;
      _tick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rawUrl = widget.snapshotUrl.trim().isNotEmpty
        ? widget.snapshotUrl.trim()
        : widget.streamUrl.trim();
    if (rawUrl.isEmpty) {
      return _CameraUnavailableCard(
        message: AppText.of(
          context,
          ar: 'لا يوجد رابط بث أو لقطة لهذه الكاميرا.',
          en: 'No stream or snapshot URL is configured for this camera.',
        ),
        onRetry: _retry,
      );
    }
    if (_hasLoadError && !_hasFrame) {
      return _CameraUnavailableCard(
        message: AppText.of(
          context,
          ar: 'لم تصل أي لقطة من الكاميرا خلال المهلة. تأكد من الشبكة ثم أعد المحاولة.',
          en: 'No camera frame arrived in time. Check the network, then retry.',
        ),
        onRetry: _retry,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _url,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if ((frame != null || wasSynchronouslyLoaded) &&
                    (!_hasFrame || _hasLoadError)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _timeoutTimer?.cancel();
                    setState(() {
                      _hasFrame = true;
                      _hasLoadError = false;
                    });
                  });
                }
                return child;
              },
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _CameraLoadingCard(progress: progress);
              },
              errorBuilder: (context, error, stackTrace) {
                if (!_hasLoadError) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _timeoutTimer?.cancel();
                    setState(() => _hasLoadError = true);
                  });
                }
                return _CameraUnavailableCard(
                  message: AppText.of(
                    context,
                    ar: 'تعذر فتح بث الكاميرا. تأكد أن الجوال أو الكمبيوتر على نفس شبكة الكاميرا.',
                    en: 'Unable to open the camera stream. Make sure this device is on the same camera network.',
                  ),
                  onRetry: _retry,
                );
              },
            ),
            if (_hasFrame && !_hasLoadError) ...[
              const _AdminPrivacyMask(),
              StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance
                    .ref('live_map/${widget.lotId}')
                    .onValue,
                builder: (context, snapshot) {
                  final live = _AdminLiveLotSnapshot.fromDb(
                    widget.lotId,
                    snapshot.data?.snapshot.value,
                  );
                  return _AdminParkingBoxesOverlay(live: live);
                },
              ),
              PositionedDirectional(
                top: 10,
                start: 10,
                child: _BluePill(
                  icon: Icons.privacy_tip_outlined,
                  text: AppText.of(context,
                      ar: 'طمس الوجوه واللوحات', en: 'Faces/plates masked'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminParkingBoxesOverlay extends StatelessWidget {
  const _AdminParkingBoxesOverlay({required this.live});

  final _AdminLiveLotSnapshot live;

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);
    final boxes = live.stalls.where((stall) => stall.bbox.length >= 4).toList();
    if (boxes.isEmpty) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: CustomPaint(
        painter: _AdminParkingBoxesPainter(
          stalls: boxes,
          imageWidth: live.imageWidth,
          imageHeight: live.imageHeight,
          freeColor: p.success,
          occupiedColor: p.danger,
          reservedColor: p.warn,
        ),
      ),
    );
  }
}

class _AdminParkingBoxesPainter extends CustomPainter {
  const _AdminParkingBoxesPainter({
    required this.stalls,
    required this.imageWidth,
    required this.imageHeight,
    required this.freeColor,
    required this.occupiedColor,
    required this.reservedColor,
  });

  final List<_AdminLiveStallSnapshot> stalls;
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
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      final fill = Paint()
        ..color = color.withOpacity(0.12)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AdminParkingBoxesPainter oldDelegate) {
    return oldDelegate.stalls != stalls ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight ||
        oldDelegate.freeColor != freeColor ||
        oldDelegate.occupiedColor != occupiedColor ||
        oldDelegate.reservedColor != reservedColor;
  }
}

class _CameraLoadingCard extends StatelessWidget {
  const _CameraLoadingCard({this.progress});

  final ImageChunkEvent? progress;

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);
    final expected = progress?.expectedTotalBytes;
    final loaded = progress?.cumulativeBytesLoaded ?? 0;
    final value = expected == null || expected <= 0 ? null : loaded / expected;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.softCard, p.cardB],
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_rounded, color: p.accentGlow, size: 34),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: value,
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: p.border.withOpacity(.45),
          ),
          const SizedBox(height: 10),
          Text(
            AppText.of(
              context,
              ar: 'جاري فتح بث الكاميرا...',
              en: 'Opening camera feed...',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CameraUnavailableCard extends StatelessWidget {
  const _CameraUnavailableCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [p.softCard, p.cardA],
            ),
            border: Border.all(color: p.border),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.danger.withOpacity(.10),
                  border: Border.all(color: p.danger.withOpacity(.22)),
                ),
                child:
                    Icon(Icons.videocam_off_rounded, color: p.danger, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.text,
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                    AppText.of(context, ar: 'إعادة المحاولة', en: 'Retry')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminPrivacyMask extends StatelessWidget {
  const _AdminPrivacyMask();

  @override
  Widget build(BuildContext context) {
    Widget mask(Alignment alignment, double widthFactor, double height) {
      return Align(
        alignment: alignment,
        child: FractionallySizedBox(
          widthFactor: widthFactor,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                  height: height, color: Colors.black.withOpacity(.34)),
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: Stack(
        children: [
          mask(const Alignment(-.65, -.18), .22, 22),
          mask(const Alignment(-.18, -.16), .22, 22),
          mask(const Alignment(.58, -.16), .22, 22),
          mask(const Alignment(-.58, .40), .25, 24),
          mask(const Alignment(.18, .42), .25, 24),
          mask(const Alignment(.72, .42), .25, 24),
        ],
      ),
    );
  }
}

class _CamVM {
  final String id;
  final String lotId;
  final String lotName;
  final String status;
  final String rawStatus;
  final int fpsTarget;
  final String heartbeatIso;
  final int thresholdSec;
  final String forMap;
  final Map<String, dynamic> health;
  final Map<String, dynamic> raw;

  _CamVM({
    required this.id,
    required this.lotId,
    required this.lotName,
    required this.status,
    required this.rawStatus,
    required this.fpsTarget,
    required this.heartbeatIso,
    required this.thresholdSec,
    required this.forMap,
    required this.health,
    required this.raw,
  });

  String get baseUrl => (raw['base_url'] ?? raw['rtsp_url'] ?? '').toString();

  String get snapshotUrl {
    final explicit = (raw['redacted_snapshot_url'] ??
            raw['privacy_snapshot_url'] ??
            raw['snapshot_url'] ??
            '')
        .toString()
        .trim();
    if (explicit.isNotEmpty) return explicit;
    final base = baseUrl.trim();
    if (base.isEmpty) return '';
    return '${base.replaceAll(RegExp(r'/$'), '')}/capture';
  }

  String get streamUrl {
    final explicit = (raw['redacted_stream_url'] ??
            raw['privacy_stream_url'] ??
            raw['stream_url'] ??
            '')
        .toString()
        .trim();
    if (explicit.isNotEmpty) return explicit;
    final base = baseUrl.trim();
    if (base.isEmpty) return '';
    return '${base.replaceAll(RegExp(r'/$'), '')}/stream';
  }
}

class _DbTheme {
  final Color primaryA;
  final Color primaryB;
  final Color primaryGlow;
  final Color success;
  final Color danger;

  const _DbTheme({
    required this.primaryA,
    required this.primaryB,
    required this.primaryGlow,
    required this.success,
    required this.danger,
  });

  static const fallback = _DbTheme(
    primaryA: Color(0xFF00C2FF),
    primaryB: Color(0xFF0B5CFF),
    primaryGlow: Color(0xFF56D6FF),
    success: Color(0xFF22C55E),
    danger: Color(0xFFEF4444),
  );

  static _DbTheme fromDb(dynamic v) {
    final m = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

    Color parse(dynamic x, Color fb) {
      if (x is int) return Color(x);
      if (x is String) {
        var t = x.trim();
        if (t.isEmpty) return fb;
        if (t.startsWith('#')) t = t.substring(1);
        if (t.startsWith('0x') || t.startsWith('0X')) t = t.substring(2);
        if (t.length == 6) t = 'FF$t';
        final n = int.tryParse(t, radix: 16);
        if (n == null) return fb;
        return Color(n);
      }
      return fb;
    }

    return _DbTheme(
      primaryA: parse(
          m['primaryA'] ?? m['primary1'] ?? m['primary'], fallback.primaryA),
      primaryB: parse(m['primaryB'] ?? m['primary2'], fallback.primaryB),
      primaryGlow: parse(
          m['primaryGlow'] ?? m['glow'] ?? m['accent'], fallback.primaryGlow),
      success: parse(m['success'], fallback.success),
      danger: parse(m['danger'], fallback.danger),
    );
  }
}

class _Palette {
  final bool dark;
  final _DbTheme theme;

  _Palette({required this.theme, required this.dark});

  Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

  Color get bg1 => dark
      ? _mix(const Color(0xFF041126), theme.primaryB, 0.08)
      : _mix(const Color(0xFFF3F8FF), theme.primaryA, 0.06);
  Color get bg2 => dark
      ? _mix(const Color(0xFF061B3A), theme.primaryB, 0.10)
      : _mix(const Color(0xFFE6F1FF), theme.primaryA, 0.07);
  Color get bg3 => dark
      ? _mix(const Color(0xFF082A5E), theme.primaryA, 0.12)
      : _mix(const Color(0xFFD3E9FF), theme.primaryB, 0.08);
  Color get bg4 => dark
      ? _mix(const Color(0xFF0B3F8E), theme.primaryA, 0.16)
      : _mix(const Color(0xFFB9DCFF), theme.primaryB, 0.10);

  List<Color> get primaryGradient => <Color>[theme.primaryA, theme.primaryB];

  Color get accent => theme.primaryA;
  Color get accentGlow => theme.primaryGlow;

  Color get success => theme.success;
  Color get danger => theme.danger;
  Color get warn => const Color(0xFFFFC857);

  Color get text =>
      dark ? Colors.white.withOpacity(0.92) : const Color(0xFF061B3A);
  Color get textMuted => dark
      ? Colors.white.withOpacity(0.72)
      : const Color(0xFF1B3B6A).withOpacity(0.78);
  Color get textHint => dark
      ? Colors.white.withOpacity(0.48)
      : const Color(0xFF1B3B6A).withOpacity(0.55);

  Color get icon =>
      dark ? Colors.white.withOpacity(0.92) : const Color(0xFF0A2A55);
  Color get iconMuted => dark
      ? Colors.white.withOpacity(0.70)
      : const Color(0xFF0A2A55).withOpacity(0.65);

  Color get border => dark
      ? Colors.white.withOpacity(0.12)
      : theme.primaryGlow.withOpacity(0.20);

  Color get softCard =>
      dark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.78);
  Color get cardA =>
      dark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.82);
  Color get cardB =>
      dark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.62);

  Color get fieldFill =>
      dark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.86);

  Color get shadow =>
      dark ? Colors.black.withOpacity(0.22) : Colors.black.withOpacity(0.08);

  Color get dialogBg => dark
      ? _mix(const Color(0xFF0A2147), const Color(0xFF0B1430), 0.20)
      : Colors.white;

  Color get menuBg => dark
      ? _mix(const Color(0xFF0A2147), const Color(0xFF0B1430), 0.36)
      : Colors.white;
}

class _PaletteScope extends InheritedWidget {
  const _PaletteScope({required this.palette, required super.child});

  final _Palette palette;

  static _Palette of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<_PaletteScope>();
    if (w != null) return w.palette;

    final t = Theme.of(context);
    final dark = t.brightness == Brightness.dark;
    return _Palette(theme: _DbTheme.fallback, dark: dark);
  }

  @override
  bool updateShouldNotify(_PaletteScope oldWidget) {
    return oldWidget.palette.dark != palette.dark ||
        oldWidget.palette.theme.primaryA.value !=
            palette.theme.primaryA.value ||
        oldWidget.palette.theme.primaryB.value !=
            palette.theme.primaryB.value ||
        oldWidget.palette.theme.primaryGlow.value !=
            palette.theme.primaryGlow.value ||
        oldWidget.palette.theme.success.value != palette.theme.success.value ||
        oldWidget.palette.theme.danger.value != palette.theme.danger.value;
  }
}

class _BlueStatCard extends StatelessWidget {
  const _BlueStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.softCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(p.dark ? 0.10 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withOpacity(p.dark ? 0.14 : 0.12),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: accent.withOpacity(p.dark ? 0.25 : 0.22)),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: p.textMuted,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: p.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _BluePill extends StatelessWidget {
  const _BluePill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.softCard,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: p.iconMuted),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: p.text,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraCardBlue extends StatelessWidget {
  const _CameraCardBlue({
    required this.vm,
    required this.onViewLive,
    required this.onToggle,
    required this.onHeartbeat,
    required this.onEdit,
    required this.onDelete,
  });

  final _CamVM vm;
  final VoidCallback onViewLive;
  final VoidCallback onToggle;
  final VoidCallback onHeartbeat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color _statusColor(_Palette p, String st) {
    if (st == 'online') return p.success;
    if (st == 'stale') return p.warn;
    return p.danger;
  }

  IconData _statusIcon(String st) {
    if (st == 'online') return Icons.videocam_outlined;
    if (st == 'stale') return Icons.videocam_outlined;
    return Icons.videocam_off_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);

    final st = vm.status;
    final stColor = _statusColor(p, st);
    final icon = _statusIcon(st);

    final lotText = vm.lotName.isNotEmpty
        ? '${vm.lotName} (${vm.lotId})'
        : (vm.lotId.isEmpty ? '-' : vm.lotId);

    final hasHealth = vm.health.isNotEmpty;
    final fpsH =
        hasHealth && vm.health['fps'] != null ? f1(vm.health['fps']) : '-';
    final latH = hasHealth && vm.health['latency_ms'] != null
        ? '${f1(vm.health['latency_ms'])} ms'
        : '-';
    final dropH = hasHealth && vm.health['drop_rate'] != null
        ? '${(toDouble(vm.health['drop_rate']) * 100).toStringAsFixed(1)}%'
        : '-';

    final toggleIsOnline = vm.rawStatus == 'online';
    final toggleLabel = toggleIsOnline
        ? _camT(context, 'Set Offline')
        : _camT(context, 'Set Online');
    final toggleIcon = toggleIsOnline
        ? Icons.power_settings_new_rounded
        : Icons.play_circle_outline_rounded;
    final toggleGrad = toggleIsOnline
        ? <Color>[p.danger, p.danger.withOpacity(0.85)]
        : <Color>[p.success, p.success.withOpacity(0.85)];
    final toggleGlow = toggleIsOnline ? p.danger : p.success;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.cardA, p.cardB],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: stColor.withOpacity(p.dark ? 0.10 : 0.12),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: stColor.withOpacity(p.dark ? 0.14 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: stColor.withOpacity(p.dark ? 0.28 : 0.22)),
                ),
                child: Icon(icon, color: stColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  vm.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: p.text,
                  ),
                ),
              ),
              _StatusPillBlue(text: _camT(context, st), color: stColor),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'del') onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(_camT(context, 'Edit')),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'del',
                    child: Text(_camT(context, 'Delete')),
                  ),
                ],
                icon: Icon(Icons.more_horiz_rounded, color: p.icon),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoRowBlue(label: _camT(context, 'Lot'), value: lotText),
          _InfoRowBlue(
            label: _camT(context, 'FPS target'),
            value: '${vm.fpsTarget}',
          ),
          _InfoRowBlue(
            label: _camT(context, 'Heartbeat'),
            value: dateShort(vm.heartbeatIso),
          ),
          _InfoRowBlue(
            label: _camT(context, 'Threshold'),
            value: '${vm.thresholdSec} sec',
          ),
          _InfoRowBlue(
            label: _camT(context, 'Map FOV'),
            value: vm.forMap.isEmpty ? '-' : vm.forMap,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _GradientButton(
              height: 42,
              radius: 16,
              label: AppText.of(context,
                  ar: 'مشاهدة المواقف المتصلة', en: 'View live lot'),
              icon: Icons.live_tv_rounded,
              colors: p.primaryGradient,
              glow: p.accentGlow,
              onPressed: onViewLive,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<DatabaseEvent>(
            stream:
                FirebaseDatabase.instance.ref('live_map/${vm.lotId}').onValue,
            builder: (context, snapshot) {
              final live = _AdminLiveLotSnapshot.fromDb(
                vm.lotId,
                snapshot.data?.snapshot.value,
              );
              return _CameraAvailabilityStrip(live: live);
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  title: _camT(context, 'FPS target'),
                  value: fpsH,
                  icon: Icons.speed_rounded,
                  accent: p.accentGlow,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  title: _camT(context, 'Latency'),
                  value: latH,
                  icon: Icons.timer_outlined,
                  accent: p.warn,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  title: _camT(context, 'Drop'),
                  value: dropH,
                  icon: Icons.trending_down_rounded,
                  accent: p.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _GradientButton(
                  height: 44,
                  radius: 16,
                  label: toggleLabel,
                  icon: toggleIcon,
                  colors: toggleGrad,
                  glow: toggleGlow,
                  onPressed: onToggle,
                ),
              ),
              const SizedBox(width: 10),
              _IconSquareButton(
                icon: Icons.favorite_outline_rounded,
                tooltip: _camT(context, 'Heartbeat now'),
                onPressed: onHeartbeat,
              ),
              const SizedBox(width: 8),
              _IconSquareButton(
                icon: Icons.edit_outlined,
                tooltip: _camT(context, 'Edit'),
                onPressed: onEdit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPillBlue extends StatelessWidget {
  const _StatusPillBlue({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(p.dark ? 0.14 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(p.dark ? 0.28 : 0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.withOpacity(0.95),
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoRowBlue extends StatelessWidget {
  const _InfoRowBlue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);

    final labelStyle = TextStyle(
      color: p.textMuted,
      fontWeight: FontWeight.w800,
      fontSize: 12,
    );
    final valueStyle = TextStyle(
      color: p.text,
      fontWeight: FontWeight.w900,
      fontSize: 12.5,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Text(label, style: labelStyle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: valueStyle,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.softCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withOpacity(p.dark ? 0.14 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: accent.withOpacity(p.dark ? 0.25 : 0.22)),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: p.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  const _GradientButton({
    required this.height,
    required this.radius,
    required this.label,
    required this.colors,
    required this.glow,
    required this.onPressed,
    this.icon,
  });

  final double height;
  final double radius;
  final String label;
  final IconData? icon;
  final List<Color> colors;
  final Color glow;
  final VoidCallback onPressed;

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _down ? 0.985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.colors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: widget.glow.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: InkWell(
            onTap: widget.onPressed,
            onTapDown: (_) => setState(() => _down = true),
            onTapCancel: () => setState(() => _down = false),
            onTapUp: (_) => setState(() => _down = false),
            borderRadius: BorderRadius.circular(widget.radius),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatefulWidget {
  const _GhostButton({
    required this.height,
    required this.radius,
    required this.label,
    required this.border,
    required this.bg,
    required this.fg,
    required this.onPressed,
  });

  final double height;
  final double radius;
  final String label;
  final Color border;
  final Color bg;
  final Color fg;
  final VoidCallback onPressed;

  @override
  State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _down ? 0.985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.bg,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: widget.border),
          ),
          child: InkWell(
            onTap: widget.onPressed,
            onTapDown: (_) => setState(() => _down = true),
            onTapCancel: () => setState(() => _down = false),
            onTapUp: (_) => setState(() => _down = false),
            borderRadius: BorderRadius.circular(widget.radius),
            child: Center(
              child: Text(
                widget.label,
                style: TextStyle(
                  color: widget.fg,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconSquareButton extends StatelessWidget {
  const _IconSquareButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = _PaletteScope.of(context);
    final btn = InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: p.softCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
        ),
        child: Icon(icon, color: p.icon),
      ),
    );

    if (tooltip.trim().isEmpty) return btn;
    return Tooltip(message: tooltip, child: btn);
  }
}
