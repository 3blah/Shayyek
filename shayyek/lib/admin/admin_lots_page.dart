import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../app_text.dart';
import 'admin_utils.dart';
import 'admin_widgets.dart';

String _lotT(BuildContext context, String text) {
  if (!AppText.isArabic(context)) {
    return text;
  }

  const translations = <String, String>{
    'Lots': 'المواقف',
    'Stalls': 'الفراغات',
    'Search by name, ID, address, currency...':
        'ابحث بالاسم أو المعرّف أو العنوان أو العملة...',
    'Add': 'إضافة',
    'Refresh': 'تحديث',
    'No results': 'لا توجد نتائج',
    'No lots yet. Add your first lot.': 'لا توجد مواقف بعد. أضف أول موقف.',
    'No lots match your search.': 'لا توجد مواقف مطابقة للبحث.',
    'Add lot': 'إضافة موقف',
    'Add Lot': 'إضافة موقف',
    'ID': 'المعرّف',
    'Name': 'الاسم',
    'Address': 'العنوان',
    'Hours': 'الساعات',
    'Currency': 'العملة',
    'Rate/hour': 'السعر/ساعة',
    'Max stay (min)': 'الحد الأقصى (دقيقة)',
    'Max stay': 'الحد الأقصى',
    'Lat': 'خط العرض',
    'Lng': 'خط الطول',
    'Lat/Lng': 'الإحداثيات',
    'Cancel': 'إلغاء',
    'Create': 'إنشاء',
    'Save': 'حفظ',
    'Created': 'تم الإنشاء',
    'Saved': 'تم الحفظ',
    'Deleted': 'تم الحذف',
    'Availability': 'التوفر',
    'Occupied': 'المشغول',
    'Manage': 'إدارة',
    'Edit': 'تعديل',
    'Delete': 'حذف',
    'Available': 'متاح',
    'Inactive': 'غير نشط',
    'Degraded': 'متدهور',
    'Active': 'نشط',
    'Full': 'ممتلئ',
  };

  return translations[text] ?? text;
}

class AdminLotsPage extends StatefulWidget {
  const AdminLotsPage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<AdminLotsPage> createState() => _AdminLotsPageState();
}

class _AdminLotsPageState extends State<AdminLotsPage> {
  static const String _dbUrl = 'https://smartpasrk-default-rtdb.firebaseio.com';

  late final FirebaseDatabase _db;
  final TextEditingController _search = TextEditingController();
  String _q = '';
  Key _reloadKey = UniqueKey();

  void _reload() => setState(() => _reloadKey = UniqueKey());

  Color uiBg(BuildContext context) => Theme.of(context).scaffoldBackgroundColor;

  String _normalizeCurrency(String? raw) {
    final currency = (raw ?? '').trim().toUpperCase();
    if (currency.isEmpty || currency == 'USD') return 'SAR';
    return currency;
  }

  Future<void> _migrateLotCurrencies() async {
    try {
      final snap = await _db.ref('LOTs').get();
      final updates = <String, dynamic>{};
      for (final entry in _entries(snap.value)) {
        final m = mapOf(entry.value);
        final lotId = s(m['id'], entry.key);
        if (lotId.trim().isEmpty) continue;
        final current = s(m['currency']).trim().toUpperCase();
        final normalized = _normalizeCurrency(current);
        if (normalized != current) {
          updates['LOTs/$lotId/currency'] = normalized;
        }
      }
      if (updates.isNotEmpty) {
        await _db.ref().update(updates);
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _db = _createDb();
    _migrateLotCurrencies();
  }

  FirebaseDatabase _createDb() {
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _dbUrl,
      );
    } catch (_) {
      return FirebaseDatabase.instance;
    }
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  List<MapEntry<String, dynamic>> _entries(dynamic v) {
    final m = _asMap(v);
    return m.entries.toList();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeRef = _db.ref('app_settings/ui_theme');

    return AdminPageFrame(
      title: _lotT(context, 'Lots'),
      isDarkMode: widget.isDarkMode,
      onToggleTheme: widget.onToggleTheme,
      child: StreamBuilder<DatabaseEvent>(
        stream: themeRef.onValue,
        builder: (context, themeSnap) {
          final theme = _DbTheme.fromDb(themeSnap.data?.snapshot.value);

          return StreamBuilder<DatabaseEvent>(
            key: _reloadKey,
            stream: _db.ref('LOTs').onValue,
            builder: (context, snapshot) {
              if (snapshot.hasError) return errorBox(context, _reload);
              if (!snapshot.hasData) return loadingBox(context);

              final raw = _entries(snapshot.data!.snapshot.value);

              final all = raw.map((e) {
                final m = mapOf(e.value);
                final id = s(m['id'], e.key);
                return _LotVM(
                  id: id,
                  name: s(m['name']),
                  address: s(m['address']),
                  hours: s(m['hours']),
                  currency: _normalizeCurrency(s(m['currency'])),
                  rateHou: toDouble(m['rate_hou']),
                  maxStay: toInt(m['maxstay']),
                  lat: toDouble(m['lat']),
                  lng: toDouble(m['long']),
                  create: s(m['create']),
                  raw: m,
                );
              }).toList();

              all.sort((a, b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()));

              final query = _q.trim().toLowerCase();
              final filtered = query.isEmpty
                  ? all
                  : all.where((x) {
                      final t = '${x.id} ${x.name} ${x.address} ${x.currency}'
                          .toLowerCase();
                      return t.contains(query);
                    }).toList();

              final existingIds = all.map((e) => e.id).toSet();

              return StreamBuilder<DatabaseEvent>(
                stream: _db.ref('live_map').onValue,
                builder: (context, liveSnap) {
                  final liveAll = _asMap(liveSnap.data?.snapshot.value);

                  _LotLive? liveFor(String lotId) {
                    final m = _asMap(liveAll[lotId]);
                    if (m.isEmpty) return null;
                    return _LotLive.fromMap(m);
                  }

                  return LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;

                      int cross = 1;
                      if (w >= 1100) {
                        cross = 3;
                      } else if (w >= 820) {
                        cross = 2;
                      }

                      final compact = w < 520;

                      return CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: StatCard(
                                        title: _lotT(context, 'Lots'),
                                        value: '${all.length}',
                                        icon: Icons.map_rounded,
                                        color: theme.primaryA,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: StreamBuilder<DatabaseEvent>(
                                        stream: _db.ref('stalls').onValue,
                                        builder: (context, sSnap) {
                                          final count = sSnap.hasData
                                              ? _entries(sSnap
                                                      .data!.snapshot.value)
                                                  .length
                                              : 0;
                                          return StatCard(
                                            title: _lotT(context, 'Stalls'),
                                            value: '$count',
                                            icon: Icons.local_parking_rounded,
                                            color: theme.success,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: uiCard(context),
                                    borderRadius: BorderRadius.circular(18),
                                    border:
                                        Border.all(color: uiBorder(context)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (compact) ...[
                                        TextField(
                                          controller: _search,
                                          onChanged: (v) =>
                                              setState(() => _q = v),
                                          decoration: InputDecoration(
                                            hintText: _lotT(
                                              context,
                                              'Search by name, ID, address, currency...',
                                            ),
                                            prefixIcon: const Icon(
                                                Icons.search_rounded),
                                            isDense: true,
                                            filled: true,
                                            fillColor: uiBg(context),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 14),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              borderSide: BorderSide(
                                                  color: uiBorder(context)),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              borderSide: BorderSide(
                                                  color: uiBorder(context)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              borderSide: BorderSide(
                                                color: theme.primaryGlow,
                                                width: 1.2,
                                              ),
                                            ),
                                            suffixIcon: _q.trim().isEmpty
                                                ? null
                                                : IconButton(
                                                    onPressed: () {
                                                      _search.clear();
                                                      setState(() => _q = '');
                                                    },
                                                    icon: const Icon(
                                                        Icons.close_rounded),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _GradientButton(
                                                theme: theme,
                                                height: 46,
                                                radius: 999,
                                                icon: Icons.add_rounded,
                                                label: _lotT(context, 'Add'),
                                                onPressed: () => _addLotDialog(
                                                    existingIds, theme),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            _IconChipButton(
                                              theme: theme,
                                              size: 46,
                                              icon: Icons.refresh_rounded,
                                              tooltip:
                                                  _lotT(context, 'Refresh'),
                                              onPressed: _reload,
                                            ),
                                          ],
                                        ),
                                      ] else ...[
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _search,
                                                onChanged: (v) =>
                                                    setState(() => _q = v),
                                                decoration: InputDecoration(
                                                  hintText: _lotT(
                                                    context,
                                                    'Search by name, ID, address, currency...',
                                                  ),
                                                  prefixIcon: const Icon(
                                                      Icons.search_rounded),
                                                  isDense: true,
                                                  filled: true,
                                                  fillColor: uiBg(context),
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 14,
                                                          vertical: 14),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    borderSide: BorderSide(
                                                        color:
                                                            uiBorder(context)),
                                                  ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    borderSide: BorderSide(
                                                        color:
                                                            uiBorder(context)),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    borderSide: BorderSide(
                                                      color: theme.primaryGlow,
                                                      width: 1.2,
                                                    ),
                                                  ),
                                                  suffixIcon: _q.trim().isEmpty
                                                      ? null
                                                      : IconButton(
                                                          onPressed: () {
                                                            _search.clear();
                                                            setState(
                                                                () => _q = '');
                                                          },
                                                          icon: const Icon(Icons
                                                              .close_rounded),
                                                        ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            _GradientButton(
                                              theme: theme,
                                              height: 46,
                                              radius: 16,
                                              icon: Icons.add_rounded,
                                              label: _lotT(context, 'Add'),
                                              onPressed: () => _addLotDialog(
                                                  existingIds, theme),
                                            ),
                                            const SizedBox(width: 10),
                                            _IconChipButton(
                                              theme: theme,
                                              size: 46,
                                              icon: Icons.refresh_rounded,
                                              tooltip:
                                                  _lotT(context, 'Refresh'),
                                              onPressed: _reload,
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: uiBg(context),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                  color: uiBorder(context)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.filter_alt_rounded,
                                                  size: 16,
                                                  color: uiText(context)
                                                      .withOpacity(0.75),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  query.isEmpty
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
                                                  style: TextStyle(
                                                    color: uiText(context)
                                                        .withOpacity(0.8),
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Spacer(),
                                          if (query.isNotEmpty &&
                                              filtered.isEmpty)
                                            Text(
                                              _lotT(context, 'No results'),
                                              style: TextStyle(
                                                color: uiText(context)
                                                    .withOpacity(0.7),
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
                          if (filtered.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: uiCard(context),
                                    borderRadius: BorderRadius.circular(18),
                                    border:
                                        Border.all(color: uiBorder(context)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded,
                                          color: theme.primaryGlow),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          query.isEmpty
                                              ? _lotT(
                                                  context,
                                                  'No lots yet. Add your first lot.',
                                                )
                                              : _lotT(
                                                  context,
                                                  'No lots match your search.',
                                                ),
                                          style: TextStyle(
                                            color: uiText(context),
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      if (query.isEmpty)
                                        _GradientButton(
                                          theme: theme,
                                          height: 40,
                                          radius: 999,
                                          icon: Icons.add_rounded,
                                          label: _lotT(context, 'Add lot'),
                                          onPressed: () =>
                                              _addLotDialog(existingIds, theme),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.only(bottom: 24),
                              sliver: cross == 1
                                  ? SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, i) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
                                          child: _LotCard(
                                            theme: theme,
                                            lot: filtered[i],
                                            live: liveFor(filtered[i].id),
                                            onEdit: () => _editLotDialog(
                                                filtered[i].id,
                                                filtered[i].raw,
                                                theme),
                                            onDelete: () => _deleteLot(
                                                filtered[i].id,
                                                filtered[i].name,
                                                theme),
                                          ),
                                        ),
                                        childCount: filtered.length,
                                      ),
                                    )
                                  : SliverGrid(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, i) => _LotCard(
                                          theme: theme,
                                          lot: filtered[i],
                                          live: liveFor(filtered[i].id),
                                          onEdit: () => _editLotDialog(
                                              filtered[i].id,
                                              filtered[i].raw,
                                              theme),
                                          onDelete: () => _deleteLot(
                                              filtered[i].id,
                                              filtered[i].name,
                                              theme),
                                        ),
                                        childCount: filtered.length,
                                      ),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: cross,
                                        mainAxisExtent: cross == 2 ? 372 : 352,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                      ),
                                    ),
                            ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addLotDialog(Set<String> existingIds, _DbTheme theme) async {
    final formKey = GlobalKey<FormState>();
    final id = TextEditingController();
    final name = TextEditingController();
    final address = TextEditingController();
    final hours = TextEditingController(text: 'Sun-Thu 08:00-22:00');
    final currency = TextEditingController(text: 'SAR');
    final rate = TextEditingController(text: '2.5');
    final maxStay = TextEditingController(text: '240');
    final lat = TextEditingController();
    final lng = TextEditingController();

    String? req(String v, String label) => v.trim().isEmpty
        ? AppText.of(
            context,
            ar: '$label مطلوب',
            en: '$label is required',
          )
        : null;

    String? vId(String v) {
      final t = v.trim();
      if (t.isEmpty) {
        return AppText.of(context, ar: 'المعرّف مطلوب', en: 'ID is required');
      }
      final ok = RegExp(r'^[a-zA-Z0-9_\-]+$').hasMatch(t);
      if (!ok) {
        return AppText.of(
          context,
          ar: 'مسموح فقط بالحروف والأرقام و "_" أو "-"',
          en: 'Only letters, numbers, "_" or "-"',
        );
      }
      if (existingIds.contains(t)) {
        return AppText.of(context,
            ar: 'المعرّف موجود مسبقًا', en: 'ID already exists');
      }
      return null;
    }

    String? vCurrency(String v) {
      final t = v.trim().toUpperCase();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'العملة مطلوبة', en: 'Currency is required');
      }
      if (!RegExp(r'^[A-Z]{3}$').hasMatch(t)) {
        return 'Use 3-letter code (e.g., SAR)';
      }
      return null;
    }

    String? vRate(String v) {
      final t = v.trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'السعر/ساعة مطلوب', en: 'Rate/hour is required');
      }
      final d = double.tryParse(t);
      if (d == null) return 'Enter a valid number';
      if (d < 0) return 'Must be 0 or more';
      return null;
    }

    String? vMaxStay(String v) {
      final t = v.trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'الحد الأقصى مطلوب', en: 'Max stay is required');
      }
      final n = int.tryParse(t);
      if (n == null) return 'Enter a valid integer';
      if (n <= 0) return 'Must be greater than 0';
      return null;
    }

    String? vLat(String v) {
      final t = v.trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'خط العرض مطلوب', en: 'Latitude is required');
      }
      final d = double.tryParse(t);
      if (d == null) return 'Enter a valid number';
      if (d < -90 || d > 90) return 'Range: -90 to 90';
      return null;
    }

    String? vLng(String v) {
      final t = v.trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'خط الطول مطلوب', en: 'Longitude is required');
      }
      final d = double.tryParse(t);
      if (d == null) return 'Enter a valid number';
      if (d < -180 || d > 180) return 'Range: -180 to 180';
      return null;
    }

    final ok = await _showNeonDialog<bool>(
      title: _lotT(context, 'Add Lot'),
      icon: Icons.add_rounded,
      theme: theme,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: id,
                  decoration: _dec(theme, context,
                      label: _lotT(context, 'ID'), hint: 'e.g., lot_003'),
                  validator: (v) => vId(v ?? ''),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: name,
                  decoration:
                      _dec(theme, context, label: _lotT(context, 'Name')),
                  validator: (v) => req(v ?? '', _lotT(context, 'Name')),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: address,
                  decoration:
                      _dec(theme, context, label: _lotT(context, 'Address')),
                  validator: (v) => req(v ?? '', _lotT(context, 'Address')),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: hours,
                  decoration: _dec(theme, context,
                      label: _lotT(context, 'Hours'),
                      hint: 'Sun-Thu 08:00-22:00'),
                  validator: (v) => req(v ?? '', _lotT(context, 'Hours')),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: currency,
                        decoration: _dec(theme, context,
                            label: _lotT(context, 'Currency'), hint: 'SAR'),
                        validator: (v) => vCurrency(v ?? ''),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: rate,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: _dec(theme, context,
                            label: _lotT(context, 'Rate/hour'), hint: '2.5'),
                        validator: (v) => vRate(v ?? ''),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: maxStay,
                        keyboardType: TextInputType.number,
                        decoration: _dec(theme, context,
                            label: _lotT(context, 'Max stay (min)'),
                            hint: '240'),
                        validator: (v) => vMaxStay(v ?? ''),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: lat,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        decoration:
                            _dec(theme, context, label: _lotT(context, 'Lat')),
                        validator: (v) => vLat(v ?? ''),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: lng,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        decoration:
                            _dec(theme, context, label: _lotT(context, 'Lng')),
                        validator: (v) => vLng(v ?? ''),
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
      cancelText: _lotT(context, 'Cancel'),
      primaryText: _lotT(context, 'Create'),
      onPrimary: () {
        FocusScope.of(context).unfocus();
        if (formKey.currentState?.validate() != true) return;
        Navigator.pop(context, true);
      },
    );

    if (ok != true) return;

    final lotId = id.text.trim();
    final payload = {
      'id': lotId,
      'name': name.text.trim(),
      'address': address.text.trim(),
      'hours': hours.text.trim(),
      'currency': _normalizeCurrency(currency.text),
      'rate_hou': double.parse(rate.text.trim()),
      'maxstay': int.parse(maxStay.text.trim()),
      'lat': double.parse(lat.text.trim()),
      'long': double.parse(lng.text.trim()),
      'create': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _db.ref('LOTs/$lotId').set(payload);
      if (!mounted) return;
      await showOk(
        context,
        _lotT(context, 'Created'),
        AppText.of(context,
            ar: 'تمت إضافة الموقف بنجاح', en: 'Lot added successfully'),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _editLotDialog(
      String id, Map<String, dynamic> m, _DbTheme theme) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: s(m['name'], ''));
    final address = TextEditingController(text: s(m['address'], ''));
    final hours = TextEditingController(text: s(m['hours'], ''));
    final currency = TextEditingController(
        text: _normalizeCurrency(s(m['currency'], 'SAR')));
    final rate = TextEditingController(text: s(m['rate_hou'], ''));
    final maxStay = TextEditingController(text: s(m['maxstay'], ''));
    final lat = TextEditingController(text: s(m['lat'], ''));
    final lng = TextEditingController(text: s(m['long'], ''));

    String? req(String v, String label) => v.trim().isEmpty
        ? AppText.of(
            context,
            ar: '$label مطلوب',
            en: '$label is required',
          )
        : null;

    String? vCurrency(String v) {
      final t = v.trim().toUpperCase();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'العملة مطلوبة', en: 'Currency is required');
      }
      if (!RegExp(r'^[A-Z]{3}$').hasMatch(t)) {
        return 'Use 3-letter code (e.g., SAR)';
      }
      return null;
    }

    String? vRate(String v) {
      final t = v.trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'السعر/ساعة مطلوب', en: 'Rate/hour is required');
      }
      final d = double.tryParse(t);
      if (d == null) return 'Enter a valid number';
      if (d < 0) return 'Must be 0 or more';
      return null;
    }

    String? vMaxStay(String v) {
      final t = v.trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'الحد الأقصى مطلوب', en: 'Max stay is required');
      }
      final n = int.tryParse(t);
      if (n == null) return 'Enter a valid integer';
      if (n <= 0) return 'Must be greater than 0';
      return null;
    }

    String? vLat(String v) {
      final t = v.trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'خط العرض مطلوب', en: 'Latitude is required');
      }
      final d = double.tryParse(t);
      if (d == null) return 'Enter a valid number';
      if (d < -90 || d > 90) return 'Range: -90 to 90';
      return null;
    }

    String? vLng(String v) {
      final t = v.trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'خط الطول مطلوب', en: 'Longitude is required');
      }
      final d = double.tryParse(t);
      if (d == null) return 'Enter a valid number';
      if (d < -180 || d > 180) return 'Range: -180 to 180';
      return null;
    }

    final ok = await _showNeonDialog<bool>(
      title:
          AppText.of(context, ar: 'تعديل الموقف ($id)', en: 'Edit Lot ($id)'),
      icon: Icons.edit_outlined,
      theme: theme,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: name,
                  decoration:
                      _dec(theme, context, label: _lotT(context, 'Name')),
                  validator: (v) => req(v ?? '', _lotT(context, 'Name')),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: address,
                  decoration:
                      _dec(theme, context, label: _lotT(context, 'Address')),
                  validator: (v) => req(v ?? '', _lotT(context, 'Address')),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: hours,
                  decoration:
                      _dec(theme, context, label: _lotT(context, 'Hours')),
                  validator: (v) => req(v ?? '', _lotT(context, 'Hours')),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: currency,
                        decoration: _dec(theme, context,
                            label: _lotT(context, 'Currency'), hint: 'SAR'),
                        validator: (v) => vCurrency(v ?? ''),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: rate,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: _dec(theme, context,
                            label: _lotT(context, 'Rate/hour')),
                        validator: (v) => vRate(v ?? ''),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: maxStay,
                        keyboardType: TextInputType.number,
                        decoration: _dec(theme, context,
                            label: _lotT(context, 'Max stay (min)')),
                        validator: (v) => vMaxStay(v ?? ''),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: lat,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        decoration:
                            _dec(theme, context, label: _lotT(context, 'Lat')),
                        validator: (v) => vLat(v ?? ''),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: lng,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        decoration:
                            _dec(theme, context, label: _lotT(context, 'Lng')),
                        validator: (v) => vLng(v ?? ''),
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
      cancelText: _lotT(context, 'Cancel'),
      primaryText: _lotT(context, 'Save'),
      onPrimary: () {
        FocusScope.of(context).unfocus();
        if (formKey.currentState?.validate() != true) return;
        Navigator.pop(context, true);
      },
    );

    if (ok != true) return;

    try {
      await _db.ref('LOTs/$id').update({
        'name': name.text.trim(),
        'address': address.text.trim(),
        'hours': hours.text.trim(),
        'currency': _normalizeCurrency(currency.text),
        'rate_hou': double.parse(rate.text.trim()),
        'maxstay': int.parse(maxStay.text.trim()),
        'lat': double.parse(lat.text.trim()),
        'long': double.parse(lng.text.trim()),
      });
      if (!mounted) return;
      await showOk(
        context,
        _lotT(context, 'Saved'),
        AppText.of(context,
            ar: 'تم تحديث الموقف بنجاح', en: 'Lot updated successfully'),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _deleteLot(String id, String name, _DbTheme theme) async {
    int stallsCount = 0;
    try {
      final stallsSnap = await _db.ref('stalls').get();
      final stalls = _entries(stallsSnap.value);
      for (final e in stalls) {
        final m = mapOf(e.value);
        if (s(m['lot_id']) == id) stallsCount++;
      }
    } catch (_) {}
    if (!mounted) return;

    final msg = stallsCount > 0
        ? AppText.of(
            context,
            ar: 'هذا الموقف مرتبط بـ $stallsCount فراغًا. حذف الموقف سيترك هذه الفراغات بدون موقف.\n\nهل تريد الحذف رغم ذلك؟',
            en: 'This lot has $stallsCount stalls linked to it.\nDeleting the lot will leave those stalls without a lot.\n\nDelete anyway?',
          )
        : AppText.of(
            context,
            ar: 'هل تريد حذف هذا الموقف نهائيًا؟',
            en: 'Delete this lot permanently?',
          );

    final ok = await _showNeonDialog<bool>(
      title: AppText.of(context, ar: 'حذف $name', en: 'Delete $name'),
      icon: Icons.delete_outline_rounded,
      theme: theme,
      danger: true,
      content: Text(
        msg,
        style: TextStyle(
          color: uiText(context).withOpacity(0.9),
          fontWeight: FontWeight.w700,
        ),
      ),
      cancelText: _lotT(context, 'Cancel'),
      primaryText: _lotT(context, 'Delete'),
      onPrimary: () => Navigator.pop(context, true),
    );

    if (ok != true) return;

    try {
      await _db.ref('LOTs/$id').remove();
      if (!mounted) return;
      await showOk(
        context,
        _lotT(context, 'Deleted'),
        AppText.of(context,
            ar: 'تم حذف الموقف بنجاح', en: 'Lot removed successfully'),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  InputDecoration _dec(
    _DbTheme theme,
    BuildContext context, {
    required String label,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: uiBg(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: uiBorder(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: uiBorder(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.primaryGlow, width: 1.2),
      ),
    );
  }

  Future<T?> _showNeonDialog<T>({
    required String title,
    required IconData icon,
    required _DbTheme theme,
    required Widget content,
    required String cancelText,
    required String primaryText,
    required VoidCallback onPrimary,
    bool danger = false,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dialog',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) {
        final border = danger
            ? theme.danger.withOpacity(0.6)
            : theme.primaryGlow.withOpacity(0.65);
        final grad = danger
            ? <Color>[theme.danger, theme.danger.withOpacity(0.85)]
            : theme.primaryGradient;

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
                      constraints: const BoxConstraints(maxWidth: 620),
                      decoration: BoxDecoration(
                        color: uiCard(context).withOpacity(0.96),
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
                                        color: border.withOpacity(0.8)),
                                    color: uiBg(context).withOpacity(0.7),
                                  ),
                                  child: Icon(
                                    icon,
                                    color: danger
                                        ? theme.danger
                                        : theme.primaryGlow,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      color: uiText(context),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(Icons.close_rounded,
                                      color: uiText(context).withOpacity(0.75)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 1,
                            color: uiBorder(context).withOpacity(0.7),
                          ),
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
                                    theme: theme,
                                    height: 46,
                                    radius: 16,
                                    label: cancelText,
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _GradientButton(
                                    theme: theme.copyWithPrimaryGradient(grad),
                                    height: 46,
                                    radius: 16,
                                    icon: null,
                                    label: primaryText,
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

  List<Color> get primaryGradient => <Color>[primaryA, primaryB];

  _DbTheme copyWithPrimaryGradient(List<Color> g) {
    final a = g.isNotEmpty ? g.first : primaryA;
    final b = g.length > 1 ? g[1] : primaryB;
    return _DbTheme(
      primaryA: a,
      primaryB: b,
      primaryGlow: primaryGlow,
      success: success,
      danger: danger,
    );
  }

  static _DbTheme fromDb(dynamic v) {
    final m = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

    Color parse(dynamic x, Color fb) {
      if (x is int) return Color(x);
      if (x is String) {
        final t = x.trim();
        if (t.isEmpty) return fb;
        String s = t;
        if (s.startsWith('#')) s = s.substring(1);
        if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
        if (s.length == 6) s = 'FF$s';
        final n = int.tryParse(s, radix: 16);
        if (n == null) return fb;
        return Color(n);
      }
      return fb;
    }

    const fallback = _DbTheme(
      primaryA: Color(0xFF00C2FF),
      primaryB: Color(0xFF0B5CFF),
      primaryGlow: Color(0xFF56D6FF),
      success: Color(0xFF22C55E),
      danger: Color(0xFFEF4444),
    );

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

class _LotLive {
  final bool degraded;
  final int free;
  final int occupied;
  final int total;
  final DateTime? ts;

  const _LotLive({
    required this.degraded,
    required this.free,
    required this.occupied,
    required this.total,
    required this.ts,
  });

  static _LotLive fromMap(Map<String, dynamic> m) {
    final degraded = (m['degraded_mode'] == true);
    final free = (m['free'] is int)
        ? (m['free'] as int)
        : int.tryParse('${m['free']}') ?? 0;
    final occupied = (m['occupied'] is int)
        ? (m['occupied'] as int)
        : int.tryParse('${m['occupied']}') ?? 0;
    final total = (m['total'] is int)
        ? (m['total'] as int)
        : int.tryParse('${m['total']}') ?? (free + occupied);
    final ts = DateTime.tryParse('${m['ts'] ?? ''}');
    return _LotLive(
      degraded: degraded,
      free: free,
      occupied: occupied,
      total: total,
      ts: ts,
    );
  }
}

class _LotVM {
  final String id;
  final String name;
  final String address;
  final String hours;
  final String currency;
  final double rateHou;
  final int maxStay;
  final double lat;
  final double lng;
  final String create;
  final Map<String, dynamic> raw;

  _LotVM({
    required this.id,
    required this.name,
    required this.address,
    required this.hours,
    required this.currency,
    required this.rateHou,
    required this.maxStay,
    required this.lat,
    required this.lng,
    required this.create,
    required this.raw,
  });
}

class _LotCard extends StatelessWidget {
  const _LotCard({
    required this.theme,
    required this.lot,
    required this.live,
    required this.onEdit,
    required this.onDelete,
  });

  final _DbTheme theme;
  final _LotVM lot;
  final _LotLive? live;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isActive = live != null;
    final isDegraded = live?.degraded == true;
    final hasFree = (live?.free ?? 0) > 0;
    final total = live?.total ?? 0;

    String stateText() {
      if (!isActive) return _lotT(context, 'Inactive');
      if (isDegraded) return _lotT(context, 'Degraded');
      if (total <= 0) return _lotT(context, 'Active');
      return hasFree ? _lotT(context, 'Available') : _lotT(context, 'Full');
    }

    Color stateColor() {
      if (!isActive) return uiText(context).withOpacity(0.55);
      if (isDegraded) return theme.primaryGlow;
      if (total <= 0) return theme.primaryGlow;
      return hasFree ? theme.success : theme.danger;
    }

    final details = Column(
      children: [
        InfoRow(label: _lotT(context, 'ID'), value: lot.id),
        InfoRow(label: _lotT(context, 'Address'), value: lot.address),
        InfoRow(label: _lotT(context, 'Hours'), value: lot.hours),
        Row(
          children: [
            Expanded(
              child: InfoRow(
                  label: _lotT(context, 'Currency'), value: lot.currency),
            ),
            Expanded(
              child: InfoRow(
                label: _lotT(context, 'Rate/hour'),
                value: lot.rateHou.toStringAsFixed(2),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: InfoRow(
                label: _lotT(context, 'Max stay'),
                value: AppText.of(
                  context,
                  ar: '${lot.maxStay} دقيقة',
                  en: '${lot.maxStay} min',
                ),
              ),
            ),
            Expanded(
              child: InfoRow(
                label: _lotT(context, 'Lat/Lng'),
                value:
                    '${lot.lat.toStringAsFixed(6)}, ${lot.lng.toStringAsFixed(6)}',
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: InfoRow(
                label: _lotT(context, 'Availability'),
                value: live == null
                    ? '-'
                    : AppText.of(
                        context,
                        ar: '${live!.free}/${live!.total} فارغ',
                        en: '${live!.free}/${live!.total} free',
                      ),
              ),
            ),
            Expanded(
              child: InfoRow(
                label: _lotT(context, 'Occupied'),
                value: live == null ? '-' : '${live!.occupied}',
              ),
            ),
          ],
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: uiCard(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: uiBorder(context)),
      ),
      child: LayoutBuilder(
        builder: (context, bc) {
          final boundedH = bc.hasBoundedHeight;

          Widget scrollArea;
          if (boundedH) {
            scrollArea = Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: details,
              ),
            );
          } else {
            scrollArea = details;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_city_outlined, color: theme.primaryGlow),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lot.name.isEmpty
                          ? AppText.of(context,
                              ar: '(بدون اسم)', en: '(No name)')
                          : lot.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: uiText(context),
                        fontSize: 15,
                      ),
                    ),
                  ),
                  _StatePill(
                    text: stateText(),
                    color: stateColor(),
                    bg: uiBg(context),
                    border: uiBorder(context),
                  ),
                  const SizedBox(width: 6),
                  _IconChipButton(
                    theme: theme,
                    size: 38,
                    icon: Icons.edit_outlined,
                    tooltip: _lotT(context, 'Edit'),
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: 8),
                  _IconChipButton(
                    theme: theme,
                    size: 38,
                    icon: Icons.delete_outline_rounded,
                    tooltip: _lotT(context, 'Delete'),
                    danger: true,
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              scrollArea,
              const SizedBox(height: 10),
              _GradientButton(
                theme: theme,
                height: 46,
                radius: 999,
                icon: Icons.tune_rounded,
                label: _lotT(context, 'Manage'),
                onPressed: onEdit,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({
    required this.text,
    required this.color,
    required this.bg,
    required this.border,
  });

  final String text;
  final Color color;
  final Color bg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: uiText(context).withOpacity(0.9),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconChipButton extends StatelessWidget {
  const _IconChipButton({
    required this.theme,
    required this.size,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
  });

  final _DbTheme theme;
  final double size;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = danger ? theme.danger : theme.primaryGlow;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: uiBorder(context)),
          ),
          child: Icon(icon, color: c, size: 20),
        ),
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  const _GradientButton({
    required this.theme,
    required this.height,
    required this.radius,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final _DbTheme theme;
  final double height;
  final double radius;
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.theme.primaryGradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: widget.theme.primaryGlow.withOpacity(0.18),
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
    required this.theme,
    required this.height,
    required this.radius,
    required this.label,
    required this.onPressed,
  });

  final _DbTheme theme;
  final double height;
  final double radius;
  final String label;
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
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: uiBorder(context)),
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
                  color: uiText(context).withOpacity(0.85),
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
