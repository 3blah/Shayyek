import 'dart:io';
import 'dart:ui';

import 'package:excel/excel.dart' as ex;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../app_text.dart';
import 'admin_l10n.dart';
import 'admin_theme.dart';
import 'admin_utils.dart';
import 'admin_widgets.dart';

class AdminStallsPage extends StatefulWidget {
  const AdminStallsPage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<AdminStallsPage> createState() => _AdminStallsPageState();
}

class _AdminStallsPageState extends State<AdminStallsPage> {
  final _db = FirebaseDatabase.instance;

  String _q = '';
  String _stateFilter = 'all';
  bool _onlyAccessible = false;
  bool _onlyEv = false;
  bool _onlyReserved = false;
  String _sort = 'last_seen_desc';

  bool _selectMode = false;
  final Set<String> _selected = <String>{};

  String _t(String text) => adminL10n(context, text);

  String _yesNo(bool value) => value
      ? AppText.of(context, ar: 'نعم', en: 'Yes')
      : AppText.of(context, ar: 'لا', en: 'No');

  String _safeStamp() {
    final x = DateTime.now().toUtc().toIso8601String();
    return x.replaceAll(':', '-').replaceAll('.', '-');
  }

  String _normalizeCurrency(String? raw) {
    final currency = (raw ?? '').trim().toUpperCase();
    if (currency.isEmpty || currency == 'USD') return 'SAR';
    return currency;
  }

  Future<void> _migrateStallCurrencies() async {
    try {
      final snap = await _db.ref('stalls').get();
      final updates = <String, dynamic>{};
      for (final entry in childEntries(snap.value)) {
        final m = mapOf(entry.value);
        final stallId = s(m['id'], entry.key);
        if (stallId.trim().isEmpty) continue;
        final current = s(m['currency']).trim().toUpperCase();
        final normalized = _normalizeCurrency(current);
        if (normalized != current) {
          updates['stalls/$stallId/currency'] = normalized;
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
    _migrateStallCurrencies();
  }

  Future<File> _writeBytes(String name, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$name';
    final f = File(path);
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  Future<void> _downloadExcel(List<_Stall> rows,
      {required String scope}) async {
    if (rows.isEmpty) return;

    try {
      final excel = ex.Excel.createExcel();
      final sheet = excel['Stalls'];

      sheet.appendRow(<ex.CellValue?>[
        ex.TextCellValue('id'),
        ex.TextCellValue('label'),
        ex.TextCellValue('lot_id'),
        ex.TextCellValue('state'),
        ex.TextCellValue('attr_acces'),
        ex.TextCellValue('attr_ev'),
        ex.TextCellValue('attr_res'),
        ex.TextCellValue('rate_hou'),
        ex.TextCellValue('currency'),
        ex.TextCellValue('maxstay'),
        ex.TextCellValue('last_confidence'),
        ex.TextCellValue('last_seen'),
      ]);

      for (final r in rows) {
        sheet.appendRow(<ex.CellValue?>[
          ex.TextCellValue(r.id),
          ex.TextCellValue(r.label),
          ex.TextCellValue(r.lotId),
          ex.TextCellValue(r.state),
          ex.TextCellValue(r.attrAccess ? 'true' : 'false'),
          ex.TextCellValue(r.attrEv ? 'true' : 'false'),
          ex.TextCellValue(r.attrRes ? 'true' : 'false'),
          ex.DoubleCellValue(r.rateHou),
          ex.TextCellValue(r.currency),
          ex.IntCellValue(r.maxStay),
          ex.TextCellValue(r.lastConfidence),
          ex.TextCellValue(r.lastSeen),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) return;

      final file = await _writeBytes(
        'stalls_${scope}_${_safeStamp()}.xlsx',
        bytes,
      );

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Stalls Excel',
        text: 'Stalls export (Excel)',
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _downloadPdf(List<_Stall> rows, {required String scope}) async {
    if (rows.isEmpty) return;

    try {
      final doc = pw.Document();

      final header = <String>[
        'id',
        'label',
        'lot_id',
        'state',
        'accessible',
        'ev',
        'reserved',
        'rate',
        'maxstay',
        'confidence',
        'last_seen',
      ];

      final data = rows.map((r) {
        return <String>[
          r.id,
          r.label,
          r.lotId,
          r.state,
          r.attrAccess ? 'Yes' : 'No',
          r.attrEv ? 'Yes' : 'No',
          r.attrRes ? 'Yes' : 'No',
          _fmtRate(r.rateHou, r.currency),
          r.maxStay <= 0 ? '-' : '${r.maxStay} min',
          r.lastConfidence.isEmpty ? '-' : r.lastConfidence,
          dateShort(r.lastSeen),
        ];
      }).toList();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(22, 22, 22, 22),
          build: (ctx) {
            return [
              pw.Text(
                'Stalls Export',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Records: ${rows.length}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: header,
                data: data,
                headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2),
                  1: const pw.FlexColumnWidth(1.3),
                  2: const pw.FlexColumnWidth(1.0),
                  3: const pw.FlexColumnWidth(0.9),
                  4: const pw.FlexColumnWidth(0.9),
                  5: const pw.FlexColumnWidth(0.7),
                  6: const pw.FlexColumnWidth(0.9),
                  7: const pw.FlexColumnWidth(1.1),
                  8: const pw.FlexColumnWidth(1.0),
                  9: const pw.FlexColumnWidth(1.0),
                  10: const pw.FlexColumnWidth(1.3),
                },
              ),
            ];
          },
        ),
      );

      final bytes = await doc.save();
      final file = await _writeBytes(
        'stalls_${scope}_${_safeStamp()}.pdf',
        bytes,
      );

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Stalls PDF',
        text: 'Stalls export (PDF)',
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      title: _t('Stalls'),
      isDarkMode: widget.isDarkMode,
      onToggleTheme: widget.onToggleTheme,
      child: StreamBuilder<DatabaseEvent>(
        stream: _db.ref('stalls').onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return errorBox(context, () => setState(() {}));
          }
          if (!snapshot.hasData) return loadingBox(context);

          final entries = childEntries(snapshot.data!.snapshot.value);
          final all = entries
              .map((e) => _stallFromEntry(e))
              .where((x) => x.id.isNotEmpty)
              .toList();

          final nowUtc = DateTime.now().toUtc();
          int free = 0;
          int occupied = 0;
          int accessible = 0;
          int ev = 0;
          int reserved = 0;

          for (final s1 in all) {
            final st = s1.state.toLowerCase().trim();
            if (st == 'free') {
              free++;
            } else if (st == 'occupied') {
              occupied++;
            }

            if (s1.attrAccess) accessible++;
            if (s1.attrEv) ev++;
            if (s1.attrRes) reserved++;
          }

          final filtered = all.where((x) {
            final st = x.state.toLowerCase().trim();
            if (_stateFilter != 'all' && st != _stateFilter) return false;
            if (_onlyAccessible && !x.attrAccess) return false;
            if (_onlyEv && !x.attrEv) return false;
            if (_onlyReserved && !x.attrRes) return false;

            if (_q.isNotEmpty) {
              final hay =
                  '${x.id} ${x.label} ${x.lotId} ${x.state} ${x.currency} ${x.rateHou} ${x.maxStay} ${x.lastConfidence}'
                      .toLowerCase();
              if (!hay.contains(_q)) return false;
            }
            return true;
          }).toList();

          _sortList(filtered);

          if (_selectMode) {
            _selected.removeWhere(
                (id) => filtered.indexWhere((x) => x.id == id) == -1);
            if (_selected.isEmpty) {
              _selectMode = false;
            }
          }

          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) =>
                          setState(() => _q = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: _t('Search by label, lot, id'),
                        suffixIcon: _q.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => setState(() => _q = ''),
                                icon: const Icon(Icons.close_rounded),
                                tooltip: _t('Clear'),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => _openEditor(context),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(_t('Add')),
                  ),
                  const SizedBox(width: 10),
                  PopupMenuButton<String>(
                    tooltip: _t('More'),
                    onSelected: (v) async {
                      if (v == 'refresh') {
                        setState(() {});
                        return;
                      }
                      if (v == 'select') {
                        setState(() {
                          _selectMode = true;
                          _selected.clear();
                        });
                        return;
                      }
                      if (v == 'export_excel') {
                        await _downloadExcel(filtered, scope: 'filtered');
                        return;
                      }
                      if (v == 'export_pdf') {
                        await _downloadPdf(filtered, scope: 'filtered');
                        return;
                      }
                      if (v == 'delete_filtered') {
                        await _deleteFiltered(context, filtered);
                        return;
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                          value: 'refresh', child: Text(_t('Refresh'))),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                          value: 'select',
                          child: Text(_t('Select (bulk actions)'))),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                          value: 'export_excel',
                          child: Text(_t('Download filtered (Excel)'))),
                      PopupMenuItem(
                          value: 'export_pdf',
                          child: Text(_t('Download filtered (PDF)'))),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                          value: 'delete_filtered',
                          child: Text(_t('Delete filtered'))),
                    ],
                    icon: const Icon(Icons.tune_rounded,
                        color: AdminColors.primaryGlow),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_selectMode) _bulkBar(context, filtered),
              if (_selectMode) const SizedBox(height: 10),
              _filtersCard(context),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: _t('Free'),
                            value: '$free',
                            icon: Icons.local_parking_rounded,
                            color: AdminColors.success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            title: _t('Occupied'),
                            value: '$occupied',
                            icon: Icons.block_rounded,
                            color: AdminColors.danger,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            title: _t('Total'),
                            value: '${all.length}',
                            icon: Icons.grid_view_rounded,
                            color: AdminColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: _t('Accessible'),
                            value: '$accessible',
                            icon: Icons.accessible_rounded,
                            color: AdminColors.primaryGlow,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            title: 'EV',
                            value: '$ev',
                            icon: Icons.bolt_rounded,
                            color: AdminColors.warning,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            title: _t('Reserved'),
                            value: '$reserved',
                            icon: Icons.bookmark_rounded,
                            color: AdminColors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Center(
                          child: Text(
                            AppText.of(context,
                                ar: 'لا توجد فراغات', en: 'No stalls found'),
                            style: TextStyle(color: uiSub(context)),
                          ),
                        ),
                      ),
                    ...filtered.map((x) => _stallCard(context, x, nowUtc)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filtersCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: uiCard(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: uiBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppText.of(context,
                      ar: 'الفلاتر والترتيب', en: 'Filters & Sort'),
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: uiText(context)),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _stateFilter = 'all';
                  _onlyAccessible = false;
                  _onlyEv = false;
                  _onlyReserved = false;
                  _sort = 'last_seen_desc';
                }),
                icon: const Icon(Icons.restart_alt_rounded),
                label: Text(_t('Reset')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(_t('All')),
                selected: _stateFilter == 'all',
                onSelected: (_) => setState(() => _stateFilter = 'all'),
              ),
              ChoiceChip(
                label: Text(_t('Free')),
                selected: _stateFilter == 'free',
                onSelected: (_) => setState(() => _stateFilter = 'free'),
              ),
              ChoiceChip(
                label: Text(_t('Occupied')),
                selected: _stateFilter == 'occupied',
                onSelected: (_) => setState(() => _stateFilter = 'occupied'),
              ),
              ChoiceChip(
                label: Text(_t('Unknown')),
                selected: _stateFilter == 'unknown',
                onSelected: (_) => setState(() => _stateFilter = 'unknown'),
              ),
              FilterChip(
                label: Text(_t('Accessible')),
                selected: _onlyAccessible,
                onSelected: (v) => setState(() => _onlyAccessible = v),
              ),
              FilterChip(
                label: const Text('EV'),
                selected: _onlyEv,
                onSelected: (v) => setState(() => _onlyEv = v),
              ),
              FilterChip(
                label: Text(_t('Reserved')),
                selected: _onlyReserved,
                onSelected: (v) => setState(() => _onlyReserved = v),
              ),
              _sortPill(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sortPill(BuildContext context) {
    String label = AppText.of(context, ar: 'آخر تحديث ↓', en: 'Last seen ↓');
    if (_sort == 'last_seen_asc') {
      label = AppText.of(context, ar: 'آخر تحديث ↑', en: 'Last seen ↑');
    }
    if (_sort == 'label_asc') {
      label = AppText.of(context, ar: 'الرمز أ→ي', en: 'Label A→Z');
    }
    if (_sort == 'label_desc') {
      label = AppText.of(context, ar: 'الرمز ي→أ', en: 'Label Z→A');
    }
    if (_sort == 'rate_desc') {
      label = AppText.of(context, ar: 'السعر ↓', en: 'Rate ↓');
    }
    if (_sort == 'rate_asc') {
      label = AppText.of(context, ar: 'السعر ↑', en: 'Rate ↑');
    }
    if (_sort == 'confidence_desc') {
      label = AppText.of(context, ar: 'الثقة ↓', en: 'Confidence ↓');
    }
    if (_sort == 'confidence_asc') {
      label = AppText.of(context, ar: 'الثقة ↑', en: 'Confidence ↑');
    }

    return PopupMenuButton<String>(
      onSelected: (v) => setState(() => _sort = v),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'last_seen_desc',
          child: Text(
            AppText.of(context,
                ar: 'آخر تحديث (الأحدث)', en: 'Last seen (newest)'),
          ),
        ),
        PopupMenuItem(
          value: 'last_seen_asc',
          child: Text(
            AppText.of(context,
                ar: 'آخر تحديث (الأقدم)', en: 'Last seen (oldest)'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'label_asc',
          child: Text(
            AppText.of(context, ar: 'الرمز (أ→ي)', en: 'Label (A→Z)'),
          ),
        ),
        PopupMenuItem(
          value: 'label_desc',
          child: Text(
            AppText.of(context, ar: 'الرمز (ي→أ)', en: 'Label (Z→A)'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'rate_desc',
          child: Text(
            AppText.of(context,
                ar: 'السعر (مرتفع→منخفض)', en: 'Rate (high→low)'),
          ),
        ),
        PopupMenuItem(
          value: 'rate_asc',
          child: Text(
            AppText.of(context,
                ar: 'السعر (منخفض→مرتفع)', en: 'Rate (low→high)'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'confidence_desc',
          child: Text(
            AppText.of(context,
                ar: 'الثقة (مرتفعة→منخفضة)', en: 'Confidence (high→low)'),
          ),
        ),
        PopupMenuItem(
          value: 'confidence_asc',
          child: Text(
            AppText.of(context,
                ar: 'الثقة (منخفضة→مرتفعة)', en: 'Confidence (low→high)'),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: uiCard(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: uiBorder(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded,
                size: 16, color: AdminColors.primaryGlow),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: uiText(context),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.expand_more_rounded, size: 18, color: uiSub(context)),
          ],
        ),
      ),
    );
  }

  Widget _bulkBar(BuildContext context, List<_Stall> filtered) {
    final allIds = filtered.map((x) => x.id).toSet();
    final selectedCount = _selected.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: uiCard(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.primary.withOpacity(.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AdminColors.primary.withOpacity(.14),
                child: const Icon(Icons.checklist_rounded,
                    color: AdminColors.primaryGlow, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppText.of(
                    context,
                    ar: 'إجراءات جماعية • المحدد: $selectedCount',
                    en: 'Bulk actions • Selected: $selectedCount',
                  ),
                  style: TextStyle(
                      color: uiText(context), fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _selectMode = false;
                  _selected.clear();
                }),
                icon: const Icon(Icons.close_rounded),
                label: Text(AppText.of(context, ar: 'خروج', en: 'Exit')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  if (_selected.length == allIds.length) {
                    _selected.clear();
                  } else {
                    _selected
                      ..clear()
                      ..addAll(allIds);
                  }
                }),
                icon: const Icon(Icons.select_all_rounded),
                label: Text(
                  _selected.length == allIds.length
                      ? AppText.of(context,
                          ar: 'إلغاء تحديد الكل', en: 'Unselect all')
                      : AppText.of(context,
                          ar: 'تحديد كل العناصر المصفاة',
                          en: 'Select all filtered'),
                ),
              ),
              FilledButton.icon(
                onPressed: selectedCount == 0
                    ? null
                    : () => _bulkSetState(context, next: 'free'),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(_t('Mark Free')),
                style: FilledButton.styleFrom(
                    backgroundColor: AdminColors.success),
              ),
              FilledButton.icon(
                onPressed: selectedCount == 0
                    ? null
                    : () => _bulkSetState(context, next: 'occupied'),
                icon: const Icon(Icons.block_outlined),
                label: Text(_t('Mark Occupied')),
                style:
                    FilledButton.styleFrom(backgroundColor: AdminColors.danger),
              ),
              OutlinedButton.icon(
                onPressed: selectedCount == 0
                    ? null
                    : () => _bulkToggleFlag(context, key: 'attr_res'),
                icon: const Icon(Icons.bookmark_outline_rounded),
                label: Text(_t('Toggle Reserved')),
              ),
              OutlinedButton.icon(
                onPressed: selectedCount == 0
                    ? null
                    : () => _bulkToggleFlag(context, key: 'attr_acces'),
                icon: const Icon(Icons.accessible_rounded),
                label: Text(_t('Toggle Accessible')),
              ),
              OutlinedButton.icon(
                onPressed: selectedCount == 0
                    ? null
                    : () => _bulkToggleFlag(context, key: 'attr_ev'),
                icon: const Icon(Icons.bolt_rounded),
                label: Text(_t('Toggle EV')),
              ),
              FilledButton.icon(
                onPressed:
                    selectedCount == 0 ? null : () => _bulkDelete(context),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(_t('Delete')),
                style:
                    FilledButton.styleFrom(backgroundColor: AdminColors.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stallCard(BuildContext context, _Stall st, DateTime nowUtc) {
    final state = st.state.toLowerCase().trim();
    final isFree = state == 'free';
    final isOcc = state == 'occupied';

    Color accent = AdminColors.primaryGlow;
    if (isFree) accent = AdminColors.success;
    if (isOcc) accent = AdminColors.danger;

    final selected = _selected.contains(st.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onLongPress: () => setState(() {
          _selectMode = true;
          if (selected) {
            _selected.remove(st.id);
          } else {
            _selected.add(st.id);
          }
        }),
        onTap: _selectMode
            ? () => setState(() {
                  if (selected) {
                    _selected.remove(st.id);
                  } else {
                    _selected.add(st.id);
                  }
                })
            : () => _openDetails(context, st),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: uiCard(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AdminColors.primary.withOpacity(.35)
                  : uiBorder(context),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_selectMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Checkbox(
                        value: selected,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(st.id);
                          } else {
                            _selected.remove(st.id);
                          }
                        }),
                      ),
                    ),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: accent.withOpacity(.14),
                    child: Icon(Icons.local_parking_outlined, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${st.label.isEmpty ? st.id : st.label}  (${st.lotId.isEmpty ? '-' : st.lotId})',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: uiText(context)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_t('Id')}: ${st.id}',
                          style: TextStyle(
                            fontSize: 12,
                            color: uiSub(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(st.state.isEmpty ? 'unknown' : st.state),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'details') {
                        await _openDetails(context, st);
                        return;
                      }
                      if (v == 'edit') {
                        await _openEditor(context, existing: st);
                        return;
                      }
                      if (v == 'duplicate') {
                        await _duplicate(context, st);
                        return;
                      }
                      if (v == 'toggle_state') {
                        await _toggleState(st.id, st.state);
                        return;
                      }
                      if (v == 'toggle_access') {
                        await _toggleBool(st.id, 'attr_acces', st.attrAccess);
                        return;
                      }
                      if (v == 'toggle_ev') {
                        await _toggleBool(st.id, 'attr_ev', st.attrEv);
                        return;
                      }
                      if (v == 'toggle_res') {
                        await _toggleBool(st.id, 'attr_res', st.attrRes);
                        return;
                      }
                      if (v == 'download_excel') {
                        await _downloadExcel([st], scope: 'single');
                        return;
                      }
                      if (v == 'download_pdf') {
                        await _downloadPdf([st], scope: 'single');
                        return;
                      }
                      if (v == 'delete') {
                        await _deleteOne(context, st);
                        return;
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                          value: 'details', child: Text(_t('View details'))),
                      PopupMenuItem(value: 'edit', child: Text(_t('Edit'))),
                      PopupMenuItem(
                          value: 'duplicate', child: Text(_t('Duplicate'))),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'toggle_state',
                        child: Text(
                          AppText.of(
                            context,
                            ar: 'تبديل الحالة (فارغ/مشغول)',
                            en: 'Toggle state (free/occupied)',
                          ),
                        ),
                      ),
                      PopupMenuItem(
                          value: 'toggle_access',
                          child: Text(_t('Toggle Accessible'))),
                      PopupMenuItem(
                          value: 'toggle_ev', child: Text(_t('Toggle EV'))),
                      PopupMenuItem(
                          value: 'toggle_res',
                          child: Text(_t('Toggle Reserved'))),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                          value: 'download_excel',
                          child: Text(_t('Download (Excel)'))),
                      PopupMenuItem(
                          value: 'download_pdf',
                          child: Text(_t('Download (PDF)'))),
                      const PopupMenuDivider(),
                      PopupMenuItem(value: 'delete', child: Text(_t('Delete'))),
                    ],
                    icon: Icon(Icons.more_vert_rounded, color: uiSub(context)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _dotChip(
                      context,
                      '${_t('Accessible')}: ${_yesNo(st.attrAccess)}',
                      Icons.accessible_rounded),
                  _dotChip(
                      context, 'EV: ${_yesNo(st.attrEv)}', Icons.bolt_rounded),
                  _dotChip(context, '${_t('Reserved')}: ${_yesNo(st.attrRes)}',
                      Icons.bookmark_rounded),
                  _dotChip(
                      context,
                      '${_t('Rate')}: ${_fmtRate(st.rateHou, st.currency)}',
                      Icons.attach_money_rounded),
                  _dotChip(
                    context,
                    '${_t('Max stay')}: ${st.maxStay <= 0 ? "-" : "${st.maxStay} min"}',
                    Icons.timer_outlined,
                  ),
                  _dotChip(
                    context,
                    '${_t('Confidence')}: ${st.lastConfidence.isEmpty ? "-" : st.lastConfidence}',
                    Icons.verified_outlined,
                  ),
                  _dotChip(
                      context,
                      '${_t('Last seen')}: ${dateShort(st.lastSeen)}',
                      Icons.schedule_outlined),
                ],
              ),
              const SizedBox(height: 10),
              if (!_selectMode)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _toggleState(st.id, st.state),
                        icon: Icon(isFree
                            ? Icons.block_outlined
                            : Icons.check_circle_outline_rounded),
                        label: Text(
                            isFree ? _t('Mark Occupied') : _t('Mark Free')),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              isFree ? AdminColors.danger : AdminColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _openEditor(context, existing: st),
                      icon: const Icon(Icons.edit_rounded),
                      label: Text(_t('Edit')),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dotChip(BuildContext context, String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AdminColors.darkCard2
            : const Color(0xFFF2F7FE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AdminColors.primaryGlow),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: uiText(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetails(BuildContext context, _Stall st) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = uiCard(ctx);
        final sub = uiSub(ctx);
        final title = uiText(ctx);

        Color accent = AdminColors.primaryGlow;
        final state = st.state.toLowerCase().trim();
        if (state == 'free') accent = AdminColors.success;
        if (state == 'occupied') accent = AdminColors.danger;

        final head = st.label.isEmpty ? st.id : st.label;
        final lot = st.lotId.isEmpty ? '-' : st.lotId;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  color: bg.withOpacity(dark ? .86 : .96),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: uiBorder(ctx).withOpacity(.9)),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                      color: Colors.black.withOpacity(dark ? .45 : .14),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withOpacity(.14),
                              border:
                                  Border.all(color: accent.withOpacity(.30)),
                            ),
                            child: Icon(Icons.local_parking_rounded,
                                color: accent, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  head,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: title,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_t('Lot')}: $lot • ${st.state.isEmpty ? _t('unknown') : _t(st.state)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: sub,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: Icon(Icons.close_rounded, color: sub),
                            splashRadius: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(dark ? .05 : .55),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: uiBorder(ctx)),
                        ),
                        child: Column(
                          children: [
                            InfoRow(label: _t('Id'), value: st.id),
                            InfoRow(label: _t('Lot'), value: lot),
                            InfoRow(
                                label: _t('State'),
                                value: st.state.isEmpty
                                    ? _t('unknown')
                                    : _t(st.state)),
                            InfoRow(
                                label: _t('Accessible'),
                                value: _yesNo(st.attrAccess)),
                            InfoRow(label: 'EV', value: _yesNo(st.attrEv)),
                            InfoRow(
                                label: _t('Reserved'),
                                value: _yesNo(st.attrRes)),
                            InfoRow(
                                label: _t('Rate'),
                                value: _fmtRate(st.rateHou, st.currency)),
                            InfoRow(
                                label: _t('Max stay'),
                                value: st.maxStay <= 0
                                    ? '-'
                                    : '${st.maxStay} min'),
                            InfoRow(
                                label: _t('Confidence'),
                                value: st.lastConfidence.isEmpty
                                    ? '-'
                                    : st.lastConfidence),
                            InfoRow(
                                label: _t('Last seen'),
                                value: dateShort(st.lastSeen)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await _downloadExcel([st], scope: 'single');
                            },
                            icon: const Icon(Icons.grid_on_rounded),
                            label: Text(_t('Excel')),
                          ),
                          FilledButton.icon(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await _downloadPdf([st], scope: 'single');
                            },
                            icon: const Icon(Icons.picture_as_pdf_rounded),
                            label: Text(_t('PDF')),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _openEditor(context, existing: st);
                            },
                            icon: const Icon(Icons.edit_rounded),
                            label: Text(_t('Edit')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditor(BuildContext context, {_Stall? existing}) async {
    final isEdit = existing != null;

    final idCtrl = TextEditingController(text: isEdit ? existing.id : '');
    final labelCtrl = TextEditingController(text: isEdit ? existing.label : '');
    final lotCtrl = TextEditingController(text: isEdit ? existing.lotId : '');
    final rateCtrl = TextEditingController(
      text: isEdit
          ? (existing.rateHou <= 0 ? '' : existing.rateHou.toString())
          : '',
    );
    final curCtrl = TextEditingController(
      text: isEdit ? _normalizeCurrency(existing.currency) : 'SAR',
    );
    final maxCtrl = TextEditingController(
      text: isEdit
          ? (existing.maxStay <= 0 ? '' : existing.maxStay.toString())
          : '',
    );
    final confCtrl =
        TextEditingController(text: isEdit ? existing.lastConfidence : '');

    bool acc = isEdit ? existing.attrAccess : false;
    bool ev = isEdit ? existing.attrEv : false;
    bool res = isEdit ? existing.attrRes : false;
    String state =
        isEdit ? (existing.state.isEmpty ? 'free' : existing.state) : 'free';

    final formKey = GlobalKey<FormState>();

    String? vId(String? v) {
      final t = (v ?? '').trim();
      if (isEdit) return null;
      if (t.isEmpty) return null;
      if (t.length < 3) {
        return AppText.of(context, ar: 'المعرف قصير جداً', en: 'Id too short');
      }
      if (t.length > 60) {
        return AppText.of(context, ar: 'المعرف طويل جداً', en: 'Id too long');
      }
      return null;
    }

    String? vLabel(String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) {
        return AppText.of(context, ar: 'الرمز مطلوب', en: 'Label required');
      }
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'الرمز قصير جداً', en: 'Label too short');
      }
      if (t.length > 60) {
        return AppText.of(context, ar: 'الرمز طويل جداً', en: 'Label too long');
      }
      return null;
    }

    String? vLot(String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'معرف الموقف مطلوب', en: 'Lot id required');
      }
      if (t.length < 3) {
        return AppText.of(context,
            ar: 'معرف الموقف قصير جداً', en: 'Lot id too short');
      }
      if (t.length > 60) {
        return AppText.of(context,
            ar: 'معرف الموقف طويل جداً', en: 'Lot id too long');
      }
      return null;
    }

    String? vRate(String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return null;
      final d = double.tryParse(t);
      if (d == null) {
        return AppText.of(context, ar: 'السعر غير صحيح', en: 'Rate invalid');
      }
      if (d < 0) {
        return AppText.of(context,
            ar: 'يجب أن يكون السعر أكبر أو يساوي صفر', en: 'Rate must be >= 0');
      }
      if (d > 9999) {
        return AppText.of(context, ar: 'السعر مرتفع جداً', en: 'Rate too high');
      }
      return null;
    }

    String? vCur(String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'العملة مطلوبة', en: 'Currency required');
      }
      if (t.length < 2) {
        return AppText.of(context,
            ar: 'العملة غير صحيحة', en: 'Currency invalid');
      }
      if (t.length > 10) {
        return AppText.of(context,
            ar: 'العملة غير صحيحة', en: 'Currency invalid');
      }
      return null;
    }

    String? vMax(String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return null;
      final n = int.tryParse(t);
      if (n == null) return 'Max stay invalid';
      if (n < 0) return 'Max stay must be >= 0';
      if (n > 100000) return 'Max stay too high';
      return null;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              backgroundColor: uiCard(ctx),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  Icon(isEdit ? Icons.edit_rounded : Icons.add_rounded,
                      color: AdminColors.primaryGlow),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEdit ? _t('Edit Stall') : _t('Add Stall'),
                      style: TextStyle(
                          color: uiText(ctx), fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isEdit)
                          TextFormField(
                            controller: idCtrl,
                            validator: vId,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.fingerprint_rounded),
                              labelText: _t('Custom Id (optional)'),
                              hintText: _t('leave empty to auto-generate'),
                            ),
                          ),
                        if (!isEdit) const SizedBox(height: 10),
                        TextFormField(
                          controller: labelCtrl,
                          validator: vLabel,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.label_outline_rounded),
                            labelText: _t('Label'),
                            hintText: 'A1, B12, VIP-3…',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: lotCtrl,
                          validator: vLot,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.map_outlined),
                            labelText: _t('Lot id'),
                            hintText: 'lot_001',
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: state,
                          items: [
                            DropdownMenuItem(
                                value: 'free', child: Text(_t('free'))),
                            DropdownMenuItem(
                                value: 'occupied', child: Text(_t('occupied'))),
                            DropdownMenuItem(
                                value: 'unknown', child: Text(_t('unknown'))),
                          ],
                          onChanged: (v) => setLocal(() => state = v ?? 'free'),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.verified_outlined),
                            labelText: _t('State'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: rateCtrl,
                                validator: vRate,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  prefixIcon:
                                      const Icon(Icons.attach_money_rounded),
                                  labelText: _t('Rate per hour'),
                                  hintText: '2.5',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: curCtrl,
                                validator: vCur,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                      Icons.currency_exchange_rounded),
                                  labelText: _t('Currency'),
                                  hintText: 'SAR',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: maxCtrl,
                                validator: vMax,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.timer_outlined),
                                  labelText: AppText.of(
                                    context,
                                    ar: 'الحد الأقصى (دقيقة)',
                                    en: 'Max stay (min)',
                                  ),
                                  hintText: '240',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: confCtrl,
                                decoration: InputDecoration(
                                  prefixIcon:
                                      const Icon(Icons.insights_outlined),
                                  labelText: AppText.of(
                                    context,
                                    ar: 'آخر ثقة (اختياري)',
                                    en: 'Last confidence (optional)',
                                  ),
                                  hintText: '0.92',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).brightness == Brightness.dark
                                ? AdminColors.darkCard2
                                : const Color(0xFFF2F7FE),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: uiBorder(ctx)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      value: acc,
                                      onChanged: (v) => setLocal(() => acc = v),
                                      title: Text(
                                        _t('Accessible'),
                                        style: TextStyle(
                                            color: uiText(ctx),
                                            fontWeight: FontWeight.w800),
                                      ),
                                      secondary: const Icon(
                                          Icons.accessible_rounded,
                                          color: AdminColors.primaryGlow),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      value: ev,
                                      onChanged: (v) => setLocal(() => ev = v),
                                      title: Text(
                                        'EV',
                                        style: TextStyle(
                                            color: uiText(ctx),
                                            fontWeight: FontWeight.w800),
                                      ),
                                      secondary: const Icon(Icons.bolt_rounded,
                                          color: AdminColors.warning),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      value: res,
                                      onChanged: (v) => setLocal(() => res = v),
                                      title: Text(
                                        _t('Reserved'),
                                        style: TextStyle(
                                            color: uiText(ctx),
                                            fontWeight: FontWeight.w800),
                                      ),
                                      secondary: const Icon(
                                          Icons.bookmark_rounded,
                                          color: AdminColors.warning),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child:
                        Text(AppText.of(context, ar: 'إلغاء', en: 'Cancel'))),
                FilledButton.icon(
                  onPressed: () async {
                    final ok = formKey.currentState?.validate() ?? false;
                    if (!ok) return;

                    final nowIso = DateTime.now().toUtc().toIso8601String();
                    final id = isEdit
                        ? existing.id
                        : (idCtrl.text.trim().isEmpty
                            ? 'stall_${DateTime.now().millisecondsSinceEpoch}'
                            : idCtrl.text.trim());

                    final rate = double.tryParse(rateCtrl.text.trim()) ?? 0.0;
                    final maxStay = int.tryParse(maxCtrl.text.trim()) ?? 0;
                    final duplicateIdMessage = AppText.of(
                      ctx,
                      ar: 'المعرف موجود بالفعل. اختر معرفاً آخر.',
                      en: 'Id already exists. Choose another.',
                    );

                    try {
                      final ref = _db.ref('stalls/$id');

                      if (!isEdit && idCtrl.text.trim().isNotEmpty) {
                        final exists = await ref.get();
                        if (!ctx.mounted) return;
                        if (exists.exists) {
                          await showError(ctx, duplicateIdMessage);
                          return;
                        }
                      }

                      final payload = <String, dynamic>{
                        'id': id,
                        'label': labelCtrl.text.trim(),
                        'lot_id': lotCtrl.text.trim(),
                        'state': state,
                        'attr_acces': acc,
                        'attr_ev': ev,
                        'attr_res': res,
                        'rate_hou': rate,
                        'currency': _normalizeCurrency(curCtrl.text),
                        'maxstay': maxStay,
                        'last_confidence': confCtrl.text.trim(),
                        'last_seen': nowIso,
                        'update_at': nowIso,
                      };

                      if (!isEdit) payload['create_at'] = nowIso;

                      await ref.update(payload);

                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      if (!mounted) return;
                      await showOk(
                        context,
                        _t('Saved'),
                        isEdit
                            ? AppText.of(context,
                                ar: 'تم تحديث الفراغ', en: 'Stall updated')
                            : AppText.of(context,
                                ar: 'تم إنشاء الفراغ', en: 'Stall created'),
                      );
                    } catch (e) {
                      if (!ctx.mounted) return;
                      await showError(ctx, e.toString());
                    }
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: Text(AppText.of(context, ar: 'حفظ', en: 'Save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleState(String stallId, String current) async {
    final cur = current.toLowerCase().trim();
    final next = cur == 'free' ? 'occupied' : 'free';
    try {
      await _db.ref('stalls/$stallId').update({
        'state': next,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
        'update_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (!mounted) return;
      await showOk(
        context,
        _t('Saved'),
        AppText.of(
          context,
          ar: 'تم تحديث الفراغ إلى ${_t(next)}',
          en: 'Stall updated to $next',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _toggleBool(String stallId, String key, bool current) async {
    try {
      await _db.ref('stalls/$stallId').update({
        key: !current,
        'update_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (!mounted) return;
      await showOk(
        context,
        _t('Saved'),
        AppText.of(context, ar: 'تم التحديث', en: 'Updated'),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _deleteOne(BuildContext context, _Stall st) async {
    final ok = await _confirm(
      context,
      title: AppText.of(context, ar: 'حذف الفراغ؟', en: 'Delete stall?'),
      message: AppText.of(
        context,
        ar: 'سيتم حذف "${st.label.isEmpty ? st.id : st.label}" نهائياً.',
        en: 'This will permanently delete "${st.label.isEmpty ? st.id : st.label}".',
      ),
      danger: true,
      okText: _t('Delete'),
    );
    if (ok != true) return;

    try {
      await _db.ref('stalls/${st.id}').remove();
      if (!mounted) return;
      await showOk(
        context,
        AppText.of(context, ar: 'تم الحذف', en: 'Deleted'),
        AppText.of(context, ar: 'تم حذف الفراغ', en: 'Stall deleted'),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _deleteFiltered(BuildContext context, List<_Stall> list) async {
    if (list.isEmpty) {
      await showError(
        context,
        AppText.of(
          context,
          ar: 'لا توجد فراغات مصفاة للحذف.',
          en: 'No filtered stalls to delete.',
        ),
      );
      return;
    }

    final ok = await _confirm(
      context,
      title: AppText.of(context,
          ar: 'حذف العناصر المصفاة؟', en: 'Delete filtered?'),
      message: AppText.of(
        context,
        ar: 'سيتم حذف ${list.length} فراغاً يطابق الفلاتر أو البحث نهائياً.',
        en: 'This will permanently delete ${list.length} stall(s) that match your filters/search.',
      ),
      danger: true,
      okText: _t('Delete'),
    );
    if (ok != true) return;

    final updates = <String, dynamic>{};
    for (final x in list) {
      updates['stalls/${x.id}'] = null;
    }

    try {
      await _db.ref().update(updates);
      if (!mounted) return;
      await showOk(
        context,
        AppText.of(context, ar: 'تم الحذف', en: 'Deleted'),
        AppText.of(context,
            ar: 'تم حذف الفراغات المصفاة', en: 'Filtered stalls deleted'),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _duplicate(BuildContext context, _Stall st) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final id = 'stall_${DateTime.now().millisecondsSinceEpoch}';
    final payload = <String, dynamic>{
      'id': id,
      'label': st.label.isEmpty ? id : '${st.label} (copy)',
      'lot_id': st.lotId,
      'state': 'free',
      'attr_acces': st.attrAccess,
      'attr_ev': st.attrEv,
      'attr_res': st.attrRes,
      'rate_hou': st.rateHou,
      'currency': _normalizeCurrency(st.currency),
      'maxstay': st.maxStay,
      'last_confidence': '',
      'last_seen': nowIso,
      'create_at': nowIso,
      'update_at': nowIso,
    };

    try {
      await _db.ref('stalls/$id').set(payload);
      if (!mounted) return;
      await showOk(
        context,
        AppText.of(context, ar: 'تم', en: 'Done'),
        AppText.of(context,
            ar: 'تم إنشاء نسخة كفراغ جديد', en: 'Duplicated as new stall'),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _bulkSetState(BuildContext context,
      {required String next}) async {
    if (_selected.isEmpty) return;

    final ok = await _confirm(
      context,
      title: AppText.of(context, ar: 'تحديث جماعي؟', en: 'Bulk update?'),
      message: AppText.of(
        context,
        ar: 'تعيين الحالة "${_t(next)}" لعدد ${_selected.length} فراغات؟',
        en: 'Set state="$next" for ${_selected.length} stall(s)?',
      ),
      danger: false,
      okText: AppText.of(context, ar: 'تطبيق', en: 'Apply'),
    );
    if (ok != true) return;

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final updates = <String, dynamic>{};
    for (final id in _selected) {
      updates['stalls/$id/state'] = next;
      updates['stalls/$id/last_seen'] = nowIso;
      updates['stalls/$id/update_at'] = nowIso;
    }

    try {
      await _db.ref().update(updates);
      if (!mounted) return;
      await showOk(
        context,
        _t('Saved'),
        AppText.of(context,
            ar: 'تم تطبيق التحديث الجماعي', en: 'Bulk update applied'),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _bulkToggleFlag(BuildContext context,
      {required String key}) async {
    if (_selected.isEmpty) return;

    final ok = await _confirm(
      context,
      title: AppText.of(context, ar: 'تبديل جماعي؟', en: 'Bulk toggle?'),
      message: AppText.of(
        context,
        ar: 'تبديل "$key" لعدد ${_selected.length} فراغات؟',
        en: 'Toggle "$key" for ${_selected.length} stall(s)?',
      ),
      danger: false,
      okText: AppText.of(context, ar: 'تطبيق', en: 'Apply'),
    );
    if (ok != true) return;

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final snap = await _db.ref('stalls').get();
      final all = childEntries(snap.value)
          .map((e) => _stallFromEntry(e))
          .where((x) => x.id.isNotEmpty)
          .toList();
      final mapById = {for (final x in all) x.id: x};

      final updates = <String, dynamic>{};
      for (final id in _selected) {
        final cur = mapById[id];
        if (cur == null) continue;
        bool current = false;
        if (key == 'attr_acces') current = cur.attrAccess;
        if (key == 'attr_ev') current = cur.attrEv;
        if (key == 'attr_res') current = cur.attrRes;

        updates['stalls/$id/$key'] = !current;
        updates['stalls/$id/update_at'] = nowIso;
      }

      await _db.ref().update(updates);
      if (!mounted) return;
      await showOk(
        context,
        _t('Saved'),
        AppText.of(context,
            ar: 'تم تطبيق التحديث الجماعي', en: 'Bulk update applied'),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _bulkDelete(BuildContext context) async {
    if (_selected.isEmpty) return;

    final ok = await _confirm(
      context,
      title: AppText.of(context, ar: 'حذف المحدد؟', en: 'Delete selected?'),
      message: AppText.of(
        context,
        ar: 'سيتم حذف ${_selected.length} فراغاً نهائياً.',
        en: 'This will permanently delete ${_selected.length} stall(s).',
      ),
      danger: true,
      okText: _t('Delete'),
    );
    if (ok != true) return;

    final updates = <String, dynamic>{};
    for (final id in _selected) {
      updates['stalls/$id'] = null;
    }

    try {
      await _db.ref().update(updates);
      if (!mounted) return;
      setState(() {
        _selected.clear();
        _selectMode = false;
      });
      await showOk(
        context,
        AppText.of(context, ar: 'تم الحذف', en: 'Deleted'),
        AppText.of(context,
            ar: 'تم حذف الفراغات المحددة', en: 'Selected stalls deleted'),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    bool danger = false,
    String okText = 'OK',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: uiCard(ctx),
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(
                danger
                    ? Icons.warning_amber_rounded
                    : Icons.help_outline_rounded,
                color: danger ? AdminColors.danger : AdminColors.primaryGlow,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                      color: uiText(ctx), fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(color: uiSub(ctx), fontWeight: FontWeight.w700),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(AppText.of(context, ar: 'إلغاء', en: 'Cancel'))),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor:
                    danger ? AdminColors.danger : AdminColors.primary,
              ),
              child: Text(okText),
            ),
          ],
        );
      },
    );
  }

  _Stall _stallFromEntry(dynamic e) {
    final m = mapOf(e.value);
    final id = s(m['id'], e.key);
    return _Stall(
      id: id,
      label: s(m['label']),
      lotId: s(m['lot_id']),
      state: s(m['state'], 'unknown'),
      attrAccess: toBool(m['attr_acces']),
      attrEv: toBool(m['attr_ev']),
      attrRes: toBool(m['attr_res']),
      rateHou: _toDouble(m['rate_hou']),
      currency: _normalizeCurrency(s(m['currency'], 'SAR')),
      maxStay: _toInt(m['maxstay']),
      lastConfidence: s(m['last_confidence']),
      lastSeen: s(m['last_seen']),
      raw: m,
    );
  }

  void _sortList(List<_Stall> list) {
    int cmpStr(String a, String b) =>
        a.toLowerCase().trim().compareTo(b.toLowerCase().trim());

    double confOf(_Stall x) =>
        double.tryParse(x.lastConfidence.toString().trim()) ?? 0.0;

    DateTime tsOf(_Stall x) {
      final sTs = x.lastSeen.trim();
      final d = DateTime.tryParse(sTs);
      if (d != null) return d.toUtc();
      final asInt = int.tryParse(sTs);
      if (asInt != null && asInt > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(asInt, isUtc: true);
      }
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    list.sort((a, b) {
      if (_sort == 'label_asc') return cmpStr(a.label, b.label);
      if (_sort == 'label_desc') return -cmpStr(a.label, b.label);

      if (_sort == 'rate_desc') return b.rateHou.compareTo(a.rateHou);
      if (_sort == 'rate_asc') return a.rateHou.compareTo(b.rateHou);

      if (_sort == 'confidence_desc') return confOf(b).compareTo(confOf(a));
      if (_sort == 'confidence_asc') return confOf(a).compareTo(confOf(b));

      if (_sort == 'last_seen_asc') return tsOf(a).compareTo(tsOf(b));
      return -tsOf(a).compareTo(tsOf(b));
    });
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    final s1 = v.toString().trim();
    return double.tryParse(s1) ?? 0.0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    final s1 = v.toString().trim();
    return int.tryParse(s1) ?? 0;
  }

  String _fmtRate(double rate, String cur) {
    final c = _normalizeCurrency(cur);
    if (rate <= 0) return '-';
    final r =
        (rate % 1 == 0) ? rate.toStringAsFixed(0) : rate.toStringAsFixed(2);
    return '$r $c/h';
  }
}

class _Stall {
  final String id;
  final String label;
  final String lotId;
  final String state;
  final bool attrAccess;
  final bool attrEv;
  final bool attrRes;
  final double rateHou;
  final String currency;
  final int maxStay;
  final String lastConfidence;
  final String lastSeen;
  final Map<String, dynamic> raw;

  const _Stall({
    required this.id,
    required this.label,
    required this.lotId,
    required this.state,
    required this.attrAccess,
    required this.attrEv,
    required this.attrRes,
    required this.rateHou,
    required this.currency,
    required this.maxStay,
    required this.lastConfidence,
    required this.lastSeen,
    required this.raw,
  });
}
