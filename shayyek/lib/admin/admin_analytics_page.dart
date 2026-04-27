import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:excel/excel.dart' as ex;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../app_text.dart';
import 'admin_l10n.dart';
import 'admin_theme.dart';
import 'admin_utils.dart';
import 'admin_widgets.dart';

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  Key _reloadKey = UniqueKey();

  String _lotFilter = 'All';
  int _rangeDays = 30;
  bool _newestFirst = true;
  bool _compactCards = false;

  void _reload() => setState(() => _reloadKey = UniqueKey());

  String _t(String text) => adminL10n(context, text);

  DateTime? _parseDay(dynamic v) {
    final ss = s(v).trim();
    if (ss.isEmpty) return null;
    final iso = DateTime.tryParse(ss);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final digits = ss.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 8) {
      final y = int.tryParse(digits.substring(0, 4));
      final m = int.tryParse(digits.substring(4, 6));
      final d = int.tryParse(digits.substring(6, 8));
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return null;
  }

  List<_Rollup> _parseRollups(dynamic v) {
    final entries = childEntries(v);
    final out = <_Rollup>[];
    for (final e in entries) {
      final m = mapOf(e.value);
      final dayRaw = m['day'];
      final lotId = s(m['lot_id']);
      final occAvg = toDouble(m['occ_avg']);
      final turnover = toInt(m['turnover']);
      final dwellMed = toDouble(m['dwellmed']);
      final stallsTotal = toInt(m['stallstotal']);
      final generated = m['generatat'];
      final dayDt = _parseDay(dayRaw);
      out.add(
        _Rollup(
          day: s(dayRaw),
          dayDt: dayDt,
          lotId: lotId.isEmpty ? '—' : lotId,
          occAvg: occAvg.isFinite ? occAvg.clamp(0.0, 1.0) : 0.0,
          turnover: max(0, turnover),
          dwellMed: max(0.0, dwellMed),
          stallsTotal: max(0, stallsTotal),
          generated: generated,
          raw: m,
        ),
      );
    }
    return out;
  }

  List<_Rollup> _applyFilters(List<_Rollup> all) {
    final now = DateTime.now();
    final from = _rangeDays <= 0
        ? null
        : DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: _rangeDays));

    final filtered = all.where((r) {
      if (_lotFilter != 'All' && r.lotId != _lotFilter) return false;
      if (from != null && r.dayDt != null && r.dayDt!.isBefore(from)) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final ad = a.dayDt;
      final bd = b.dayDt;
      int cmp;
      if (ad != null && bd != null) {
        cmp = ad.compareTo(bd);
      } else {
        cmp = a.day.compareTo(b.day);
      }
      return _newestFirst ? -cmp : cmp;
    });

    return filtered;
  }

  double _avg(List<double> v) {
    if (v.isEmpty) return 0.0;
    double s0 = 0;
    for (final x in v) {
      if (!x.isFinite) continue;
      s0 += x;
    }
    return s0 / v.length;
  }

  int _sumInt(List<int> v) {
    int s0 = 0;
    for (final x in v) {
      s0 += x;
    }
    return s0;
  }

  List<double> _seriesOcc(List<_Rollup> rows) {
    final list = rows.toList();
    list.sort((a, b) {
      final ad = a.dayDt;
      final bd = b.dayDt;
      if (ad != null && bd != null) return ad.compareTo(bd);
      return a.day.compareTo(b.day);
    });
    return list.map((e) => e.occAvg).toList();
  }

  List<double> _seriesTurnover(List<_Rollup> rows) {
    final list = rows.toList();
    list.sort((a, b) {
      final ad = a.dayDt;
      final bd = b.dayDt;
      if (ad != null && bd != null) return ad.compareTo(bd);
      return a.day.compareTo(b.day);
    });
    return list.map((e) => e.turnover.toDouble()).toList();
  }

  String _summaryText(List<_Rollup> rows) {
    if (rows.isEmpty) return _t('No records.');
    final occ = _avg(rows.map((e) => e.occAvg).toList());
    final turn = _sumInt(rows.map((e) => e.turnover).toList());
    final dwell = _avg(rows.map((e) => e.dwellMed).toList());
    final stalls = rows.map((e) => e.stallsTotal).where((e) => e > 0).toList();
    final stallsMax = stalls.isEmpty ? 0 : stalls.reduce(max);
    final lotText = _lotFilter == 'All' ? _t('All Lots') : _lotFilter;
    final rangeText = _rangeDays <= 0
        ? _t('All time')
        : AppText.of(context,
            ar: 'آخر $_rangeDays يوماً', en: 'Last $_rangeDays days');
    return '${_t('Analytics Summary')}\n'
        '${_t('Lot')}: $lotText\n'
        '${_t('Range')}: $rangeText\n'
        '${_t('Records')}: ${rows.length}\n'
        '${_t('Avg Occupancy')}: ${(occ * 100).toStringAsFixed(1)}%\n'
        '${_t('Turnover (sum)')}: $turn\n'
        '${_t('Avg Median Dwell')}: ${dwell.toStringAsFixed(1)} min\n'
        '${_t('Stalls (max)')}: $stallsMax';
  }

  String _safeStamp() {
    final x = DateTime.now().toUtc().toIso8601String();
    return x.replaceAll(':', '-').replaceAll('.', '-');
  }

  Future<File> _writeBytes(String name, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$name';
    final f = File(path);
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  Future<void> _downloadExcel(List<_Rollup> rows,
      {required String scope}) async {
    if (rows.isEmpty) return;

    try {
      final excel = ex.Excel.createExcel();
      final sheet = excel['Analytics'];

      final headers = <ex.CellValue?>[
        ex.TextCellValue('lot_id'),
        ex.TextCellValue('day'),
        ex.TextCellValue('occ_avg_%'),
        ex.TextCellValue('turnover'),
        ex.TextCellValue('dwell_median_min'),
        ex.TextCellValue('stalls_total'),
        ex.TextCellValue('generated'),
      ];
      sheet.appendRow(headers);

      for (final r in rows) {
        final occP = double.parse((r.occAvg * 100).toStringAsFixed(2));
        final dwell = double.parse(r.dwellMed.toStringAsFixed(2));

        sheet.appendRow(<ex.CellValue?>[
          ex.TextCellValue(r.lotId),
          ex.TextCellValue(r.day),
          ex.DoubleCellValue(occP),
          ex.IntCellValue(r.turnover),
          ex.DoubleCellValue(dwell),
          ex.IntCellValue(r.stallsTotal),
          ex.TextCellValue(dateShort(r.generated)),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) return;

      final file = await _writeBytes(
        'analytics_${scope}_${_safeStamp()}.xlsx',
        bytes,
      );

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Analytics Excel',
        text: 'Analytics export (Excel)',
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _downloadPdf(List<_Rollup> rows, {required String scope}) async {
    if (rows.isEmpty) return;

    try {
      final doc = pw.Document();

      final header = <String>[
        'lot_id',
        'day',
        'occ_avg_%',
        'turnover',
        'dwell_median_min',
        'stalls_total',
        'generated',
      ];

      final data = rows.map((r) {
        return <String>[
          r.lotId,
          r.day,
          (r.occAvg * 100).toStringAsFixed(2),
          '${r.turnover}',
          r.dwellMed.toStringAsFixed(2),
          '${r.stallsTotal}',
          dateShort(r.generated),
        ];
      }).toList();

      final summary = _summaryText(rows);

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
          build: (ctx) {
            return [
              pw.Text(
                'Analytics Export',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text(summary, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: header,
                data: data,
                headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2),
                  1: const pw.FlexColumnWidth(1.0),
                  2: const pw.FlexColumnWidth(1.0),
                  3: const pw.FlexColumnWidth(1.0),
                  4: const pw.FlexColumnWidth(1.2),
                  5: const pw.FlexColumnWidth(1.0),
                  6: const pw.FlexColumnWidth(1.2),
                },
              ),
            ];
          },
        ),
      );

      final bytes = await doc.save();
      final file = await _writeBytes(
        'analytics_${scope}_${_safeStamp()}.pdf',
        bytes,
      );

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Analytics PDF',
        text: 'Analytics export (PDF)',
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  void _openOperationsSheet(List<_Rollup> rows, List<String> lots) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: (dark ? AdminColors.darkCard2 : Colors.white)
                        .withOpacity(dark ? .82 : .97),
                    borderRadius: BorderRadius.circular(26),
                    border:
                        Border.all(color: uiBorder(context).withOpacity(.85)),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 34,
                        offset: const Offset(0, 18),
                        color: Colors.black.withOpacity(dark ? .45 : .16),
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
                            Text(
                              'Operations',
                              style: TextStyle(
                                color: uiText(context),
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              splashRadius: 20,
                              icon: Icon(Icons.close_rounded,
                                  color: uiSub(context)),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                        child: _OpsHeader(
                          lot: _lotFilter,
                          rangeDays: _rangeDays,
                          newestFirst: _newestFirst,
                          compact: _compactCards,
                          onSetLot: (v) => setState(() => _lotFilter = v),
                          onSetRange: (v) => setState(() => _rangeDays = v),
                          onToggleSort: () =>
                              setState(() => _newestFirst = !_newestFirst),
                          onToggleCompact: () =>
                              setState(() => _compactCards = !_compactCards),
                          lots: lots,
                        ),
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                          children: [
                            _OpsTile(
                              icon: Icons.refresh_rounded,
                              title: _t('Refresh data'),
                              subtitle: _t('Reload latest analytics rollups'),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _reload();
                              },
                            ),
                            _OpsTile(
                              icon: Icons.copy_all_rounded,
                              title: _t('Copy summary'),
                              subtitle: _t('Copy filtered analytics summary'),
                              onTap: () async {
                                final t = _summaryText(rows);
                                await Clipboard.setData(ClipboardData(text: t));
                                if (ctx.mounted) Navigator.of(ctx).pop();
                              },
                            ),
                            _OpsTile(
                              icon: Icons.grid_on_rounded,
                              title: _t('Download Excel'),
                              subtitle: _t('Export filtered records as .xlsx'),
                              onTap: () async {
                                Navigator.of(ctx).pop();
                                await _downloadExcel(rows, scope: 'filtered');
                              },
                            ),
                            _OpsTile(
                              icon: Icons.picture_as_pdf_rounded,
                              title: _t('Download PDF'),
                              subtitle: _t('Export filtered records as .pdf'),
                              onTap: () async {
                                Navigator.of(ctx).pop();
                                await _downloadPdf(rows, scope: 'filtered');
                              },
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseDatabase.instance;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AdminPageFrame(
      title: _t('Analytics'),
      isDarkMode: widget.isDarkMode,
      onToggleTheme: widget.onToggleTheme,
      child: StreamBuilder<DatabaseEvent>(
        key: _reloadKey,
        stream: db.ref('analytics_rollups').onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [errorBox(context, _reload)],
            );
          }
          if (!snapshot.hasData) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [loadingBox(context)],
            );
          }

          final all = _parseRollups(snapshot.data!.snapshot.value);
          final lots = <String>{'All'};
          for (final r in all) {
            if (r.lotId.isNotEmpty && r.lotId != '—') lots.add(r.lotId);
          }
          final lotsList = lots.toList()..sort();

          final rows = _applyFilters(all);

          final occ = _avg(rows.map((e) => e.occAvg).toList());
          final turnSum = _sumInt(rows.map((e) => e.turnover).toList());
          final dwellAvg = _avg(rows.map((e) => e.dwellMed).toList());

          final stalls =
              rows.map((e) => e.stallsTotal).where((e) => e > 0).toList();
          final stallsMax = stalls.isEmpty ? 0 : stalls.reduce(max);

          final occSeries = _seriesOcc(rows);
          final turnSeries = _seriesTurnover(rows);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              _AnalyticsHeader(
                dark: dark,
                lot: _lotFilter,
                rangeDays: _rangeDays,
                newestFirst: _newestFirst,
                records: rows.length,
                onOpenOps: () => _openOperationsSheet(rows, lotsList),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: _t('Avg Occupancy'),
                      value: rows.isEmpty
                          ? '—'
                          : '${(occ * 100).toStringAsFixed(0)}%',
                      icon: Icons.pie_chart_outline_rounded,
                      color: AdminColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      title: _t('Turnover (sum)'),
                      value: rows.isEmpty ? '—' : '$turnSum',
                      icon: Icons.swap_horiz_rounded,
                      color: AdminColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      title: _t('Dwell (avg)'),
                      value: rows.isEmpty
                          ? '—'
                          : '${dwellAvg.toStringAsFixed(1)} min',
                      icon: Icons.timer_outlined,
                      color: AdminColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ChartsGrid(
                dark: dark,
                occSeries: occSeries,
                turnSeries: turnSeries,
                stallsMax: stallsMax,
              ),
              const SizedBox(height: 12),
              _FiltersBar(
                dark: dark,
                lots: lotsList,
                lotValue: _lotFilter,
                rangeDays: _rangeDays,
                newestFirst: _newestFirst,
                compact: _compactCards,
                onLotChanged: (v) => setState(() => _lotFilter = v),
                onRangeChanged: (v) => setState(() => _rangeDays = v),
                onToggleSort: () =>
                    setState(() => _newestFirst = !_newestFirst),
                onToggleCompact: () =>
                    setState(() => _compactCards = !_compactCards),
                onDownloadExcel: rows.isEmpty
                    ? null
                    : () => _downloadExcel(rows, scope: 'filtered'),
                onDownloadPdf: rows.isEmpty
                    ? null
                    : () => _downloadPdf(rows, scope: 'filtered'),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      _t('No analytics records'),
                      style: TextStyle(
                          color: uiSub(context), fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ...rows.map((r) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RollupCard(
                    dark: dark,
                    compact: _compactCards,
                    rollup: r,
                    onCopy: () async {
                      final txt = _rollupText(r);
                      await Clipboard.setData(ClipboardData(text: txt));
                    },
                    onDownloadExcel: () => _downloadExcel([r], scope: 'single'),
                    onDownloadPdf: () => _downloadPdf([r], scope: 'single'),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  String _rollupText(_Rollup r) {
    return 'Rollup ${r.day}\n'
        '${_t('Lot')}: ${r.lotId}\n'
        '${_t('Avg Occupancy')}: ${(r.occAvg * 100).toStringAsFixed(1)}%\n'
        '${_t('Turnover (sum)')}: ${r.turnover}\n'
        '${adminL10n(context, 'Avg Median Dwell')}: ${r.dwellMed.toStringAsFixed(1)} min\n'
        '${adminL10n(context, 'Total')}: ${r.stallsTotal}\n'
        '${_t('Generated')}: ${dateShort(r.generated)}';
  }
}

class _Rollup {
  _Rollup({
    required this.day,
    required this.dayDt,
    required this.lotId,
    required this.occAvg,
    required this.turnover,
    required this.dwellMed,
    required this.stallsTotal,
    required this.generated,
    required this.raw,
  });

  final String day;
  final DateTime? dayDt;
  final String lotId;
  final double occAvg;
  final int turnover;
  final double dwellMed;
  final int stallsTotal;
  final dynamic generated;
  final Map<String, dynamic> raw;
}

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader({
    required this.dark,
    required this.lot,
    required this.rangeDays,
    required this.newestFirst,
    required this.records,
    required this.onOpenOps,
  });

  final bool dark;
  final String lot;
  final int rangeDays;
  final bool newestFirst;
  final int records;
  final VoidCallback onOpenOps;

  @override
  Widget build(BuildContext context) {
    final bg = (dark ? AdminColors.darkCard2 : Colors.white)
        .withOpacity(dark ? .72 : .95);
    final lotText = lot == 'All' ? adminL10n(context, 'All lots') : lot;
    final rangeText = rangeDays <= 0
        ? adminL10n(context, 'All time')
        : AppText.of(context,
            ar: 'آخر $rangeDays يوماً', en: 'Last $rangeDays days');

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: uiBorder(context).withOpacity(.85)),
            boxShadow: [
              BoxShadow(
                blurRadius: 22,
                offset: const Offset(0, 12),
                color: Colors.black.withOpacity(dark ? .30 : .10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AdminColors.primary.withOpacity(.12),
                  border:
                      Border.all(color: AdminColors.primary.withOpacity(.22)),
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  color: dark ? AdminColors.primaryGlow : AdminColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adminL10n(context, 'Analytics Center'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: uiText(context),
                        fontWeight: FontWeight.w900,
                        fontSize: 15.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        StatusPill(lotText),
                        StatusPill(rangeText),
                        StatusPill(newestFirst
                            ? adminL10n(context, 'Newest first')
                            : adminL10n(context, 'Oldest first')),
                        StatusPill(AppText.of(
                          context,
                          ar: '$records ${adminL10n(context, 'records')}',
                          en: '$records records',
                        )),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _HeaderIcon(
                icon: Icons.tune_rounded,
                onTap: onOpenOps,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(dark ? .06 : .10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: uiBorder(context).withOpacity(.85)),
        ),
        child: Icon(icon, color: uiSub(context)),
      ),
    );
  }
}

class _ChartsGrid extends StatelessWidget {
  const _ChartsGrid({
    required this.dark,
    required this.occSeries,
    required this.turnSeries,
    required this.stallsMax,
  });

  final bool dark;
  final List<double> occSeries;
  final List<double> turnSeries;
  final int stallsMax;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ChartCard(
            dark: dark,
            title: adminL10n(context, 'Occupancy Trend'),
            rightValue: occSeries.isEmpty
                ? '—'
                : '${(occSeries.last * 100).toStringAsFixed(0)}%',
            icon: Icons.show_chart_rounded,
            footer: adminL10n(context, 'Based on filtered days'),
            child: _SparkLine(values: occSeries, dark: dark),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ChartCard(
            dark: dark,
            title: adminL10n(context, 'Turnover Trend'),
            rightValue:
                turnSeries.isEmpty ? '—' : turnSeries.last.toStringAsFixed(0),
            icon: Icons.stacked_bar_chart_rounded,
            footer: stallsMax > 0
                ? AppText.of(context,
                    ar: 'أقصى الفراغات: $stallsMax',
                    en: 'Max stalls: $stallsMax')
                : adminL10n(context, 'Based on filtered days'),
            child: _SparkBars(values: _normBars(turnSeries), dark: dark),
          ),
        ),
      ],
    );
  }

  List<double> _normBars(List<double> v) {
    if (v.isEmpty) return v;
    double mx = 0;
    for (final x in v) {
      if (x.isFinite) mx = max(mx, x);
    }
    if (mx <= 0) return v.map((_) => 0.0).toList();
    return v.map((e) => (e / mx).clamp(0.0, 1.0)).toList();
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.dark,
    required this.title,
    required this.rightValue,
    required this.icon,
    required this.child,
    required this.footer,
  });

  final bool dark;
  final String title;
  final String rightValue;
  final IconData icon;
  final Widget child;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final bg = (dark ? AdminColors.darkCard : Colors.white)
        .withOpacity(dark ? .92 : 1);

    return Container(
      height: 150,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: uiBorder(context)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(dark ? .22 : .06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 16,
                  color: dark ? AdminColors.primaryGlow : AdminColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: uiText(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                rightValue,
                style: TextStyle(
                  color: uiSub(context),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
          const SizedBox(height: 6),
          Text(
            footer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: uiSub(context),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.dark,
    required this.lots,
    required this.lotValue,
    required this.rangeDays,
    required this.newestFirst,
    required this.compact,
    required this.onLotChanged,
    required this.onRangeChanged,
    required this.onToggleSort,
    required this.onToggleCompact,
    required this.onDownloadExcel,
    required this.onDownloadPdf,
  });

  final bool dark;
  final List<String> lots;
  final String lotValue;
  final int rangeDays;
  final bool newestFirst;
  final bool compact;

  final void Function(String) onLotChanged;
  final void Function(int) onRangeChanged;
  final VoidCallback onToggleSort;
  final VoidCallback onToggleCompact;
  final VoidCallback? onDownloadExcel;
  final VoidCallback? onDownloadPdf;

  @override
  Widget build(BuildContext context) {
    final bg = (dark ? AdminColors.darkCard2 : Colors.white)
        .withOpacity(dark ? .72 : .95);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: uiBorder(context).withOpacity(.85)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Drop(
                      label: adminL10n(context, 'Lot'),
                      value: lotValue,
                      items: lots,
                      onChanged: onLotChanged,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Drop(
                      label: adminL10n(context, 'Range'),
                      value: rangeDays <= 0 ? 'All' : '${rangeDays}D',
                      items: const ['7D', '30D', '90D', 'All'],
                      onChanged: (v) {
                        if (v == '7D') onRangeChanged(7);
                        if (v == '30D') onRangeChanged(30);
                        if (v == '90D') onRangeChanged(90);
                        if (v == 'All') onRangeChanged(0);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniBtn(
                      icon: newestFirst
                          ? Icons.south_rounded
                          : Icons.north_rounded,
                      label: newestFirst
                          ? adminL10n(context, 'Newest')
                          : adminL10n(context, 'Oldest'),
                      onTap: onToggleSort,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniBtn(
                      icon: compact
                          ? Icons.view_agenda_outlined
                          : Icons.view_compact_alt_outlined,
                      label: compact
                          ? adminL10n(context, 'Compact ON')
                          : adminL10n(context, 'Compact OFF'),
                      onTap: onToggleCompact,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _IconBtn(
                    icon: Icons.grid_on_rounded,
                    onTap: onDownloadExcel,
                    enabled: onDownloadExcel != null,
                  ),
                  const SizedBox(width: 8),
                  _IconBtn(
                    icon: Icons.picture_as_pdf_rounded,
                    onTap: onDownloadPdf,
                    enabled: onDownloadPdf != null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Drop extends StatelessWidget {
  const _Drop({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: (dark ? AdminColors.darkCard : Colors.white)
            .withOpacity(dark ? .92 : 1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: uiBorder(context)),
      ),
      child: Row(
        children: [
          Text(
            adminL10n(context, label),
            style: TextStyle(
              color: uiSub(context),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: value,
                icon: Icon(Icons.expand_more_rounded, color: uiSub(context)),
                items: items
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e,
                        child: Text(
                          e == 'All' ? adminL10n(context, 'All') : e,
                          style: TextStyle(
                            color: uiText(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: (dark ? AdminColors.darkCard : Colors.white)
              .withOpacity(dark ? .92 : 1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: uiBorder(context)),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: dark ? AdminColors.primaryGlow : AdminColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                adminL10n(context, label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: uiText(context),
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn(
      {required this.icon, required this.onTap, required this.enabled});

  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: (dark ? AdminColors.darkCard : Colors.white)
              .withOpacity(dark ? .92 : 1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: uiBorder(context)),
        ),
        child: Icon(
          icon,
          color: enabled
              ? (dark ? AdminColors.primaryGlow : AdminColors.primary)
              : uiSub(context).withOpacity(.5),
        ),
      ),
    );
  }
}

class _RollupCard extends StatelessWidget {
  const _RollupCard({
    required this.dark,
    required this.compact,
    required this.rollup,
    required this.onCopy,
    required this.onDownloadExcel,
    required this.onDownloadPdf,
  });

  final bool dark;
  final bool compact;
  final _Rollup rollup;

  final VoidCallback onCopy;
  final VoidCallback onDownloadExcel;
  final VoidCallback onDownloadPdf;

  @override
  Widget build(BuildContext context) {
    final bg = (dark ? AdminColors.darkCard : Colors.white)
        .withOpacity(dark ? .92 : 1);
    final occP = (rollup.occAvg * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: uiBorder(context)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(dark ? .22 : .06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined,
                  color: AdminColors.primaryGlow),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rollup ${rollup.day}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: uiText(context),
                  ),
                ),
              ),
              StatusPill(rollup.lotId),
            ],
          ),
          const SizedBox(height: 10),
          if (compact)
            Row(
              children: [
                Expanded(
                    child: _KpiChip(
                        label: adminL10n(context, 'Occ'), value: '$occP%')),
                const SizedBox(width: 8),
                Expanded(
                    child: _KpiChip(
                        label: adminL10n(context, 'Turn'),
                        value: '${rollup.turnover}')),
                const SizedBox(width: 8),
                Expanded(
                    child: _KpiChip(
                        label: adminL10n(context, 'Dwell'),
                        value: '${rollup.dwellMed.toStringAsFixed(1)}m')),
                const SizedBox(width: 8),
                Expanded(
                    child: _KpiChip(
                        label: adminL10n(context, 'Stalls'),
                        value: '${rollup.stallsTotal}')),
              ],
            )
          else ...[
            InfoRow(label: adminL10n(context, 'Lot'), value: rollup.lotId),
            InfoRow(label: adminL10n(context, 'Day'), value: rollup.day),
            InfoRow(
                label: adminL10n(context, 'Avg Occupancy'), value: '$occP %'),
            InfoRow(
                label: adminL10n(context, 'Turnover (sum)'),
                value: '${rollup.turnover}'),
            InfoRow(
                label: adminL10n(context, 'Avg Median Dwell'),
                value: '${rollup.dwellMed.toStringAsFixed(1)} min'),
            InfoRow(
                label: adminL10n(context, 'Stalls'),
                value: '${rollup.stallsTotal}'),
            InfoRow(
                label: adminL10n(context, 'Generated'),
                value: dateShort(rollup.generated)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionChip(
                  icon: Icons.copy_all_rounded,
                  label: adminL10n(context, 'Copy'),
                  onTap: onCopy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionChip(
                  icon: Icons.grid_on_rounded,
                  label: adminL10n(context, 'Excel'),
                  onTap: onDownloadExcel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionChip(
                  icon: Icons.picture_as_pdf_rounded,
                  label: adminL10n(context, 'PDF'),
                  onTap: onDownloadPdf,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiChip extends StatelessWidget {
  const _KpiChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, c) {
        final tight = c.maxWidth < 86;

        final labelW = Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: uiSub(context),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        );

        final valueW = Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: uiText(context),
            fontWeight: FontWeight.w900,
            fontSize: 12.5,
          ),
        );

        final valueFit = Align(
          alignment: Alignment.centerRight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: valueW,
          ),
        );

        final content = tight
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  labelW,
                  const SizedBox(height: 2),
                  valueFit,
                ],
              )
            : Row(
                children: [
                  Flexible(child: labelW),
                  const SizedBox(width: 6),
                  Flexible(child: valueFit),
                ],
              );

        return Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(dark ? .06 : .08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: uiBorder(context)),
          ),
          child: content,
        );
      },
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: (dark ? AdminColors.darkCard2 : Colors.white)
              .withOpacity(dark ? .72 : .95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: uiBorder(context)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: dark ? AdminColors.primaryGlow : AdminColors.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: uiText(context),
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparkBars extends StatelessWidget {
  const _SparkBars({required this.values, required this.dark});

  final List<double> values;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparkBarsPainter(values: values, dark: dark),
      child: const SizedBox.expand(),
    );
  }
}

class _SparkBarsPainter extends CustomPainter {
  _SparkBarsPainter({required this.values, required this.dark});

  final List<double> values;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color =
          (dark ? Colors.white : Colors.black).withOpacity(dark ? .06 : .05)
      ..style = PaintingStyle.fill;

    final barPaint = Paint()
      ..color = (dark ? AdminColors.primaryGlow : AdminColors.primary)
          .withOpacity(dark ? .85 : .70)
      ..style = PaintingStyle.fill;

    final rrBg =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    canvas.drawRRect(rrBg, bgPaint);

    if (values.isEmpty) return;

    final n = values.length;
    const gap = 4.0;
    final barW = max(2.0, (size.width - gap * (n - 1)) / n);

    for (int i = 0; i < n; i++) {
      final v = values[i].clamp(0.0, 1.0);
      final h = max(2.0, size.height * v);
      final x = i * (barW + gap);
      final y = size.height - h;
      final rr = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barW, h), const Radius.circular(10));
      canvas.drawRRect(rr, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkBarsPainter oldDelegate) {
    return oldDelegate.dark != dark || oldDelegate.values != values;
  }
}

class _SparkLine extends StatelessWidget {
  const _SparkLine({required this.values, required this.dark});

  final List<double> values;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparkLinePainter(values: values, dark: dark),
      child: const SizedBox.expand(),
    );
  }
}

class _SparkLinePainter extends CustomPainter {
  _SparkLinePainter({required this.values, required this.dark});

  final List<double> values;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color =
          (dark ? Colors.white : Colors.black).withOpacity(dark ? .06 : .05)
      ..style = PaintingStyle.fill;

    final rrBg =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    canvas.drawRRect(rrBg, bgPaint);

    if (values.length < 2) return;

    final clean = values.where((e) => e.isFinite).toList();
    if (clean.length < 2) return;

    double mn = clean.reduce(min);
    double mx = clean.reduce(max);
    if ((mx - mn).abs() < 1e-6) mx = mn + 1.0;

    final linePaint = Paint()
      ..color = (dark ? AdminColors.primaryGlow : AdminColors.primary)
          .withOpacity(dark ? .92 : .75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final areaPaint = Paint()
      ..color = (dark ? AdminColors.primaryGlow : AdminColors.primary)
          .withOpacity(dark ? .14 : .12)
      ..style = PaintingStyle.fill;

    final path = Path();
    final area = Path();

    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      final t = values.length == 1 ? 0.0 : i / (values.length - 1);
      final x = t * size.width;
      final y =
          size.height - ((v - mn) / (mx - mn)).clamp(0.0, 1.0) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        area.moveTo(x, size.height);
        area.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        area.lineTo(x, y);
      }
    }

    area.lineTo(size.width, size.height);
    area.close();

    canvas.drawPath(area, areaPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparkLinePainter oldDelegate) {
    return oldDelegate.dark != dark || oldDelegate.values != values;
  }
}

class _OpsHeader extends StatelessWidget {
  const _OpsHeader({
    required this.lot,
    required this.rangeDays,
    required this.newestFirst,
    required this.compact,
    required this.onSetLot,
    required this.onSetRange,
    required this.onToggleSort,
    required this.onToggleCompact,
    required this.lots,
  });

  final String lot;
  final int rangeDays;
  final bool newestFirst;
  final bool compact;

  final void Function(String) onSetLot;
  final void Function(int) onSetRange;
  final VoidCallback onToggleSort;
  final VoidCallback onToggleCompact;

  final List<String> lots;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Drop(
                label: adminL10n(context, 'Lot'),
                value: lot,
                items: lots,
                onChanged: onSetLot,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Drop(
                label: adminL10n(context, 'Range'),
                value: rangeDays <= 0 ? 'All' : '${rangeDays}D',
                items: const ['7D', '30D', '90D', 'All'],
                onChanged: (v) {
                  if (v == '7D') onSetRange(7);
                  if (v == '30D') onSetRange(30);
                  if (v == '90D') onSetRange(90);
                  if (v == 'All') onSetRange(0);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MiniBtn(
                icon: newestFirst ? Icons.south_rounded : Icons.north_rounded,
                label: newestFirst
                    ? adminL10n(context, 'Newest')
                    : adminL10n(context, 'Oldest'),
                onTap: onToggleSort,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniBtn(
                icon: compact
                    ? Icons.view_agenda_outlined
                    : Icons.view_compact_alt_outlined,
                label: compact
                    ? adminL10n(context, 'Compact ON')
                    : adminL10n(context, 'Compact OFF'),
                onTap: onToggleCompact,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OpsTile extends StatelessWidget {
  const _OpsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: (dark ? AdminColors.darkCard : Colors.white)
              .withOpacity(dark ? .80 : 1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: uiBorder(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AdminColors.primary.withOpacity(.12),
                border: Border.all(color: AdminColors.primary.withOpacity(.20)),
              ),
              child: Icon(
                icon,
                color: dark ? AdminColors.primaryGlow : AdminColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    adminL10n(context, title),
                    style: TextStyle(
                      color: uiText(context),
                      fontWeight: FontWeight.w900,
                      fontSize: 13.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    adminL10n(context, subtitle),
                    style: TextStyle(
                      color: uiSub(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: uiSub(context)),
          ],
        ),
      ),
    );
  }
}
