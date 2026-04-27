import 'dart:io';

import 'package:excel/excel.dart' as ex;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../app_text.dart';
import 'admin_theme.dart';
import 'admin_utils.dart';
import 'admin_widgets.dart';

String _annT(BuildContext context, String text) {
  if (!AppText.isArabic(context)) {
    return text;
  }

  const translations = <String, String>{
    'Announcements': 'الإعلانات',
    'Search title, body, target, status':
        'ابحث في العنوان أو المحتوى أو الهدف أو الحالة',
    'Clear': 'مسح',
    'Create': 'إنشاء',
    'More': 'المزيد',
    'Download filtered (Excel)': 'تنزيل المصفى (Excel)',
    'Download filtered (PDF)': 'تنزيل المصفى (PDF)',
    'Delete filtered': 'حذف الإعلانات المصفاة',
    'Purge all': 'حذف الكل',
    'Refresh': 'تحديث',
    'Status': 'الحالة',
    'Target': 'الهدف',
    'Time': 'الوقت',
    'Sort': 'الترتيب',
    'All': 'الكل',
    'published': 'منشور',
    'draft': 'مسودة',
    'archived': 'مؤرشف',
    'lot': 'موقف',
    'system': 'النظام',
    'all': 'الكل',
    'Active now': 'نشط الآن',
    'Scheduled': 'مجدول',
    'Expired': 'منتهي',
    'Last 24h (created)': 'آخر 24 ساعة (إنشاء)',
    'Last 7 days (created)': 'آخر 7 أيام (إنشاء)',
    'Last 30 days (created)': 'آخر 30 يومًا (إنشاء)',
    'Newest': 'الأحدث',
    'Oldest': 'الأقدم',
    'Reset': 'إعادة ضبط',
    'Total': 'الإجمالي',
    'Published': 'المنشور',
    'Draft': 'المسودات',
    'No announcements found': 'لا توجد إعلانات',
    'View details': 'عرض التفاصيل',
    'Edit': 'تعديل',
    'Duplicate': 'نسخ',
    'Copy id': 'نسخ المعرّف',
    'Download (Excel)': 'تنزيل (Excel)',
    'Download (PDF)': 'تنزيل (PDF)',
    'Publish': 'نشر',
    'Move to draft': 'إرجاع إلى مسودة',
    'Archive': 'أرشفة',
    'Delete': 'حذف',
    'Unpublish': 'إلغاء النشر',
    'Title': 'العنوان',
    'Short clear headline': 'عنوان قصير وواضح',
    'Body': 'المحتوى',
    'Write the announcement message': 'اكتب نص الإعلان',
    'Target type': 'نوع الهدف',
    'Target ref': 'مرجع الهدف',
    'Created by': 'أنشئ بواسطة',
    'Disabled': 'معطل',
    'From': 'من',
    'To': 'إلى',
    'Validated before saving.': 'يتم التحقق قبل الحفظ.',
    'Cancel': 'إلغاء',
    'Save': 'حفظ',
    'Create Announcement': 'إنشاء إعلان',
    'Edit Announcement': 'تعديل الإعلان',
    'Window': 'النافذة الزمنية',
    'Id': 'المعرّف',
    'Close': 'إغلاق',
    'Excel': 'Excel',
    'PDF': 'PDF',
    'Copied': 'تم النسخ',
    'Announcement id copied': 'تم نسخ معرّف الإعلان',
    'Done': 'تم',
    'Duplicated as draft': 'تم النسخ كمسودة',
    'Delete announcement?': 'حذف الإعلان؟',
    'Deleted': 'تم الحذف',
    'Announcement deleted': 'تم حذف الإعلان',
    'No filtered announcements to delete.': 'لا توجد إعلانات مصفاة للحذف.',
    'Delete filtered?': 'حذف الإعلانات المصفاة؟',
    'Filtered announcements deleted': 'تم حذف الإعلانات المصفاة',
    'No announcements to purge.': 'لا توجد إعلانات للحذف الكلي.',
    'Purge ALL?': 'حذف كل الإعلانات؟',
    'Purge': 'حذف كلي',
    'Purged': 'تم الحذف الكلي',
    'All announcements deleted': 'تم حذف جميع الإعلانات',
    'Nothing to download.': 'لا توجد بيانات للتنزيل.',
    'Failed to generate Excel.': 'تعذر إنشاء ملف Excel.',
    'Announcements Excel': 'Excel الإعلانات',
    'Announcements export (Excel)': 'تصدير الإعلانات (Excel)',
    'Announcements PDF': 'PDF الإعلانات',
    'Announcements export (PDF)': 'تصدير الإعلانات (PDF)',
    'Announcements Export': 'تصدير الإعلانات',
    'Search': 'بحث',
  };

  return translations[text] ?? text;
}

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  final _db = FirebaseDatabase.instance;

  String _q = '';
  String _statusFilter = 'all';
  String _targetTypeFilter = 'all';
  String _timeFilter = 'all';
  String _sort = 'newest';

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

  String _windowLabel(_AnnItem n, DateTime nowUtc) {
    final active = _isActiveNow(n, nowUtc);
    final scheduled = _isScheduled(n, nowUtc);
    final expired = _isExpired(n, nowUtc);
    if (active) return _annT(context, 'Active now');
    if (scheduled) return _annT(context, 'Scheduled');
    if (expired) return _annT(context, 'Expired');
    return '-';
  }

  Future<void> _downloadExcel(List<_AnnItem> rows,
      {required String scope}) async {
    final nothingToDownloadMessage = _annT(context, 'Nothing to download.');
    final failedToGenerateExcelMessage =
        _annT(context, 'Failed to generate Excel.');
    final excelSubject = _annT(context, 'Announcements Excel');
    final excelText = _annT(context, 'Announcements export (Excel)');

    if (rows.isEmpty) {
      if (!mounted) return;
      await showError(context, nothingToDownloadMessage);
      return;
    }

    try {
      final now = DateTime.now().toUtc();

      final excel = ex.Excel.createExcel();
      final sheet = excel['Announcements'];

      sheet.appendRow(<ex.CellValue?>[
        ex.TextCellValue('id'),
        ex.TextCellValue('title'),
        ex.TextCellValue('body'),
        ex.TextCellValue('status'),
        ex.TextCellValue('target_type'),
        ex.TextCellValue('target_ref'),
        ex.TextCellValue('window'),
        ex.TextCellValue('created_by'),
        ex.TextCellValue('valid_from'),
        ex.TextCellValue('valid_to'),
        ex.TextCellValue('create_at'),
        ex.TextCellValue('update_at'),
      ]);

      for (final n in rows) {
        sheet.appendRow(<ex.CellValue?>[
          ex.TextCellValue(n.id),
          ex.TextCellValue(n.title),
          ex.TextCellValue(n.body),
          ex.TextCellValue(n.status),
          ex.TextCellValue(n.targetType),
          ex.TextCellValue(n.targetRef),
          ex.TextCellValue(_windowLabel(n, now)),
          ex.TextCellValue(n.createdBy),
          ex.TextCellValue(n.validFrom),
          ex.TextCellValue(n.validTo),
          ex.TextCellValue(n.createAt),
          ex.TextCellValue(n.updateAt),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) {
        if (!mounted) return;
        await showError(context, failedToGenerateExcelMessage);
        return;
      }

      final file = await _writeBytes(
        'announcements_${scope}_${_safeStamp()}.xlsx',
        bytes,
      );
      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: excelSubject,
        text: excelText,
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _downloadPdf(List<_AnnItem> rows,
      {required String scope}) async {
    final nothingToDownloadMessage = _annT(context, 'Nothing to download.');
    final exportTitle = _annT(context, 'Announcements Export');
    final pdfSubject = _annT(context, 'Announcements PDF');
    final pdfText = _annT(context, 'Announcements export (PDF)');

    if (rows.isEmpty) {
      if (!mounted) return;
      await showError(context, nothingToDownloadMessage);
      return;
    }

    try {
      final now = DateTime.now().toUtc();
      final doc = pw.Document();

      String cut(String s, int max) {
        final t = s.trim();
        if (t.length <= max) return t;
        return '${t.substring(0, max)}…';
      }

      final header = <String>[
        'Title',
        'Status',
        'Target',
        'Window',
        'From',
        'To',
        'By',
      ];

      final data = rows.map((n) {
        final title = n.title.trim().isEmpty ? n.id : n.title.trim();
        final st = n.status.trim().isEmpty ? '-' : n.status.trim();
        final tt = n.targetType.trim().isEmpty ? '-' : n.targetType.trim();
        final tr = n.targetRef.trim().isEmpty ? '-' : n.targetRef.trim();
        final by = n.createdBy.trim().isEmpty ? '-' : n.createdBy.trim();

        return <String>[
          cut(title, 36),
          st,
          cut('$tt / $tr', 26),
          _windowLabel(n, now),
          dateShort(n.validFrom),
          dateShort(n.validTo),
          cut(by, 18),
        ];
      }).toList();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(22, 22, 22, 22),
          build: (ctx) {
            return [
              pw.Text(
                exportTitle,
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
                  0: const pw.FlexColumnWidth(2.2),
                  1: const pw.FlexColumnWidth(1.0),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.0),
                  4: const pw.FlexColumnWidth(1.0),
                  5: const pw.FlexColumnWidth(1.0),
                  6: const pw.FlexColumnWidth(1.0),
                },
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Note: Body text is not included in the table to keep the PDF clean.',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ];
          },
        ),
      );

      final bytes = await doc.save();
      final file = await _writeBytes(
        'announcements_${scope}_${_safeStamp()}.pdf',
        bytes,
      );
      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: pdfSubject,
        text: pdfText,
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      title: _annT(context, 'Announcements'),
      isDarkMode: widget.isDarkMode,
      onToggleTheme: widget.onToggleTheme,
      child: StreamBuilder<DatabaseEvent>(
        stream: _db.ref('announcement').onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return errorBox(context, () => setState(() {}));
          }
          if (!snapshot.hasData) return loadingBox(context);

          final entries = childEntries(snapshot.data!.snapshot.value);
          final items = entries
              .map((e) {
                final m = mapOf(e.value);
                return _AnnItem(
                  key: s(e.key),
                  id: s(m['id'], e.key),
                  title: s(m['title']),
                  body: s(m['body']),
                  status: s(m['status'], 'draft'),
                  targetType: s(m['target_type'], 'lot'),
                  targetRef: s(m['target_ref']),
                  createdBy: s(m['created_by']),
                  validFrom: s(m['valid_from']),
                  validTo: s(m['valid_to']),
                  createAt: s(m['create_at'], s(m['valid_from'])),
                  updateAt: s(m['update_at']),
                  raw: m,
                );
              })
              .where((x) => x.id.isNotEmpty)
              .toList();

          items.sort((a, b) {
            final ad = _parseTs(a.createAt);
            final bd = _parseTs(b.createAt);
            final c = ad.compareTo(bd);
            return _sort == 'oldest' ? c : -c;
          });

          final now = DateTime.now().toUtc();
          final minTs = _timeMin(now, _timeFilter);

          final filtered = items.where((n) {
            final st = n.status.toLowerCase().trim();
            final tt = n.targetType.toLowerCase().trim();

            if (_statusFilter != 'all' && st != _statusFilter) return false;
            if (_targetTypeFilter != 'all' && tt != _targetTypeFilter) {
              return false;
            }

            if (_timeFilter == 'active_now') {
              if (!_isActiveNow(n, now)) return false;
            } else if (_timeFilter == 'scheduled') {
              if (!_isScheduled(n, now)) return false;
            } else if (_timeFilter == 'expired') {
              if (!_isExpired(n, now)) return false;
            } else if (minTs != null) {
              final d = _parseTs(n.createAt);
              if (d.isBefore(minTs)) return false;
            }

            if (_q.isNotEmpty) {
              final blob =
                  '${n.title} ${n.body} ${n.status} ${n.targetType} ${n.targetRef} ${n.createdBy} ${n.validFrom} ${n.validTo}'
                      .toLowerCase();
              if (!blob.contains(_q)) return false;
            }

            return true;
          }).toList();

          int published = 0;
          int draft = 0;
          int activeNow = 0;
          int scheduled = 0;
          int expired = 0;

          for (final n in items) {
            final st = n.status.toLowerCase().trim();
            if (st == 'published') published++;
            if (st == 'draft') draft++;
            if (_isActiveNow(n, now)) activeNow++;
            if (_isScheduled(n, now)) scheduled++;
            if (_isExpired(n, now)) expired++;
          }

          final targetTypes = <String>{};
          for (final n in items) {
            final tt = n.targetType.trim();
            if (tt.isNotEmpty) targetTypes.add(tt);
          }
          final targetTypeOptions = targetTypes.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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
                        hintText: _annT(
                            context, 'Search title, body, target, status'),
                        suffixIcon: _q.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => setState(() => _q = ''),
                                icon: const Icon(Icons.close_rounded),
                                tooltip: _annT(context, 'Clear'),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => _openEditor(context),
                    icon: const Icon(Icons.campaign_outlined),
                    label: Text(_annT(context, 'Create')),
                  ),
                  const SizedBox(width: 10),
                  PopupMenuButton<String>(
                    tooltip: _annT(context, 'More'),
                    onSelected: (v) async {
                      if (v == 'download_excel') {
                        await _downloadExcel(filtered, scope: 'filtered');
                        return;
                      }
                      if (v == 'download_pdf') {
                        await _downloadPdf(filtered, scope: 'filtered');
                        return;
                      }
                      if (v == 'delete_filtered') {
                        await _deleteFiltered(context, filtered);
                        return;
                      }
                      if (v == 'purge_all') {
                        await _purgeAll(context, items);
                        return;
                      }
                      if (v == 'refresh') {
                        setState(() {});
                        return;
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                          value: 'download_excel',
                          child: Text(_annT(ctx, 'Download filtered (Excel)'))),
                      PopupMenuItem(
                          value: 'download_pdf',
                          child: Text(_annT(ctx, 'Download filtered (PDF)'))),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                          value: 'delete_filtered',
                          child: Text(_annT(ctx, 'Delete filtered'))),
                      PopupMenuItem(
                          value: 'purge_all',
                          child: Text(_annT(ctx, 'Purge all'))),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'refresh',
                        child: Text(_annT(ctx, 'Refresh')),
                      ),
                    ],
                    icon: const Icon(Icons.tune_rounded,
                        color: AdminColors.primaryGlow),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterPill(
                    context,
                    icon: Icons.verified_user_outlined,
                    label: _annT(context, 'Status'),
                    value: _statusFilter,
                    options: [
                      _Opt('all', _annT(context, 'All')),
                      _Opt('published', _annT(context, 'published')),
                      _Opt('draft', _annT(context, 'draft')),
                      _Opt('archived', _annT(context, 'archived')),
                    ],
                    onSelected: (v) => setState(() => _statusFilter = v),
                  ),
                  _filterPill(
                    context,
                    icon: Icons.track_changes_outlined,
                    label: _annT(context, 'Target'),
                    value: _targetTypeFilter,
                    options: [
                      _Opt('all', _annT(context, 'All')),
                      ...targetTypeOptions.map(
                        (x) => _Opt(x.toLowerCase(), _annT(context, x)),
                      ),
                    ],
                    onSelected: (v) => setState(() => _targetTypeFilter = v),
                  ),
                  _filterPill(
                    context,
                    icon: Icons.schedule_outlined,
                    label: _annT(context, 'Time'),
                    value: _timeFilter,
                    options: [
                      _Opt('all', _annT(context, 'All')),
                      _Opt('active_now', _annT(context, 'Active now')),
                      _Opt('scheduled', _annT(context, 'Scheduled')),
                      _Opt('expired', _annT(context, 'Expired')),
                      _Opt(
                        '24h',
                        _annT(context, 'Last 24h (created)'),
                      ),
                      _Opt(
                        '7d',
                        _annT(context, 'Last 7 days (created)'),
                      ),
                      _Opt(
                        '30d',
                        _annT(context, 'Last 30 days (created)'),
                      ),
                    ],
                    onSelected: (v) => setState(() => _timeFilter = v),
                  ),
                  _filterPill(
                    context,
                    icon: Icons.sort_rounded,
                    label: _annT(context, 'Sort'),
                    value: _sort,
                    options: [
                      _Opt('newest', _annT(context, 'Newest')),
                      _Opt('oldest', _annT(context, 'Oldest')),
                    ],
                    onSelected: (v) => setState(() => _sort = v),
                  ),
                  if (_hasAnyFilterApplied())
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _q = '';
                        _statusFilter = 'all';
                        _targetTypeFilter = 'all';
                        _timeFilter = 'all';
                        _sort = 'newest';
                      }),
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: Text(_annT(context, 'Reset')),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: _annT(context, 'Total'),
                            value: '${items.length}',
                            icon: Icons.campaign_outlined,
                            color: AdminColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            title: _annT(context, 'Published'),
                            value: '$published',
                            icon: Icons.public_rounded,
                            color: AdminColors.success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            title: _annT(context, 'Draft'),
                            value: '$draft',
                            icon: Icons.edit_note_rounded,
                            color: AdminColors.primaryGlow,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: _annT(context, 'Active now'),
                            value: '$activeNow',
                            icon: Icons.flash_on_rounded,
                            color: AdminColors.success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            title: _annT(context, 'Scheduled'),
                            value: '$scheduled',
                            icon: Icons.event_available_outlined,
                            color: AdminColors.warning,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            title: _annT(context, 'Expired'),
                            value: '$expired',
                            icon: Icons.event_busy_outlined,
                            color: AdminColors.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Center(
                          child: Text(_annT(context, 'No announcements found'),
                              style: TextStyle(color: uiSub(context))),
                        ),
                      ),
                    ...filtered.map((n) => _card(context, n)),
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

  bool _hasAnyFilterApplied() {
    return _q.isNotEmpty ||
        _statusFilter != 'all' ||
        _targetTypeFilter != 'all' ||
        _timeFilter != 'all' ||
        _sort != 'newest';
  }

  Widget _card(BuildContext context, _AnnItem n) {
    final st = n.status.toLowerCase().trim();
    final now = DateTime.now().toUtc();

    final active = _isActiveNow(n, now);
    final scheduled = _isScheduled(n, now);
    final expired = _isExpired(n, now);

    Color accent;
    if (st == 'archived') {
      accent = AdminColors.warning;
    } else if (st == 'published' && active) {
      accent = AdminColors.success;
    } else if (st == 'published' && scheduled) {
      accent = AdminColors.warning;
    } else if (st == 'published' && expired) {
      accent = AdminColors.danger;
    } else if (st == 'draft') {
      accent = AdminColors.primaryGlow;
    } else {
      accent = AdminColors.primary;
    }

    final border = accent.withOpacity(.22);
    final title = n.title.trim().isEmpty ? '-' : n.title.trim();
    final body = n.body.trim().isEmpty ? '-' : n.body.trim();
    final tt =
        n.targetType.trim().isEmpty ? '-' : _annT(context, n.targetType.trim());
    final tr = n.targetRef.trim().isEmpty ? '-' : n.targetRef.trim();

    final windowLabel = active
        ? _annT(context, 'Active now')
        : scheduled
            ? _annT(context, 'Scheduled')
            : expired
                ? _annT(context, 'Expired')
                : '-';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetails(context, n),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: uiCard(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: accent.withOpacity(.14),
                    child: Icon(Icons.campaign_outlined, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: uiText(context))),
                        const SizedBox(height: 2),
                        Text(
                          '$tt • $tr',
                          style: TextStyle(
                              fontSize: 12,
                              color: uiSub(context),
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(_annT(context, st)),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'details') {
                        await _openDetails(context, n);
                        return;
                      }
                      if (v == 'edit') {
                        await _openEditor(context, existing: n);
                        return;
                      }
                      if (v == 'duplicate') {
                        await _duplicate(context, n);
                        return;
                      }
                      if (v == 'copy_id') {
                        await _copyText(
                          context,
                          n.id,
                          _annT(context, 'Copied'),
                          _annT(context, 'Announcement id copied'),
                        );
                        return;
                      }
                      if (v == 'download_excel') {
                        await _downloadExcel([n], scope: 'single');
                        return;
                      }
                      if (v == 'download_pdf') {
                        await _downloadPdf([n], scope: 'single');
                        return;
                      }
                      if (v == 'publish') {
                        await _setStatus(context, id: n.id, next: 'published');
                        return;
                      }
                      if (v == 'draft') {
                        await _setStatus(context, id: n.id, next: 'draft');
                        return;
                      }
                      if (v == 'archive') {
                        await _setStatus(context, id: n.id, next: 'archived');
                        return;
                      }
                      if (v == 'delete') {
                        await _deleteOne(context, n);
                        return;
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'details',
                        child: Text(_annT(ctx, 'View details')),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(_annT(ctx, 'Edit')),
                      ),
                      PopupMenuItem(
                        value: 'duplicate',
                        child: Text(_annT(ctx, 'Duplicate')),
                      ),
                      PopupMenuItem(
                        value: 'copy_id',
                        child: Text(_annT(ctx, 'Copy id')),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'download_excel',
                        child: Text(_annT(ctx, 'Download (Excel)')),
                      ),
                      PopupMenuItem(
                        value: 'download_pdf',
                        child: Text(_annT(ctx, 'Download (PDF)')),
                      ),
                      const PopupMenuDivider(),
                      if (st != 'published')
                        PopupMenuItem(
                          value: 'publish',
                          child: Text(_annT(ctx, 'Publish')),
                        ),
                      if (st != 'draft')
                        PopupMenuItem(
                          value: 'draft',
                          child: Text(_annT(ctx, 'Move to draft')),
                        ),
                      if (st != 'archived')
                        PopupMenuItem(
                          value: 'archive',
                          child: Text(_annT(ctx, 'Archive')),
                        ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(_annT(ctx, 'Delete')),
                      ),
                    ],
                    icon: Icon(Icons.more_vert_rounded, color: uiSub(context)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: TextStyle(
                    color: uiSub(context), fontWeight: FontWeight.w700),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(
                    context,
                    AppText.of(
                      context,
                      ar: 'النافذة: $windowLabel',
                      en: 'Window: $windowLabel',
                    ),
                    Icons.schedule_outlined,
                  ),
                  _chip(
                    context,
                    AppText.of(
                      context,
                      ar: 'من: ${dateShort(n.validFrom)}',
                      en: 'From: ${dateShort(n.validFrom)}',
                    ),
                    Icons.calendar_today_outlined,
                  ),
                  _chip(
                    context,
                    AppText.of(
                      context,
                      ar: 'إلى: ${dateShort(n.validTo)}',
                      en: 'To: ${dateShort(n.validTo)}',
                    ),
                    Icons.event_outlined,
                  ),
                  if (s(n.createdBy).isNotEmpty)
                    _chip(
                      context,
                      AppText.of(
                        context,
                        ar: 'بواسطة: ${n.createdBy}',
                        en: 'By: ${n.createdBy}',
                      ),
                      Icons.person_outline_rounded,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: st == 'published'
                          ? () => _setStatus(context, id: n.id, next: 'draft')
                          : () =>
                              _setStatus(context, id: n.id, next: 'published'),
                      icon: Icon(st == 'published'
                          ? Icons.unpublished_outlined
                          : Icons.publish_outlined),
                      label: Text(
                        st == 'published'
                            ? _annT(context, 'Unpublish')
                            : _annT(context, 'Publish'),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: st == 'published'
                            ? AdminColors.warning
                            : AdminColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _openEditor(context, existing: n),
                    icon: const Icon(Icons.edit_rounded),
                    label: Text(_annT(context, 'Edit')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String t, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
            t,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: uiText(context)),
          ),
        ],
      ),
    );
  }

  Widget _filterPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required List<_Opt> options,
    required ValueChanged<String> onSelected,
  }) {
    final show = options
        .firstWhere((o) => o.id == value, orElse: () => options.first)
        .label;
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (ctx) => options
          .map((o) => PopupMenuItem(value: o.id, child: Text(o.label)))
          .toList(),
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
            Icon(icon, size: 16, color: AdminColors.primaryGlow),
            const SizedBox(width: 8),
            Text(
              '$label: $show',
              style: TextStyle(
                  color: uiText(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 12),
            ),
            const SizedBox(width: 6),
            Icon(Icons.expand_more_rounded, size: 18, color: uiSub(context)),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, {_AnnItem? existing}) async {
    final isEdit = existing != null;

    final titleCtrl = TextEditingController(text: isEdit ? existing.title : '');
    final bodyCtrl = TextEditingController(text: isEdit ? existing.body : '');
    final targetRefCtrl =
        TextEditingController(text: isEdit ? existing.targetRef : 'lot_001');
    final createdByCtrl =
        TextEditingController(text: isEdit ? existing.createdBy : 'user_002');

    String status = isEdit ? s(existing.status, 'draft') : 'published';
    String targetType = isEdit ? s(existing.targetType, 'lot') : 'lot';

    DateTime from = _parseTs(
        isEdit ? existing.validFrom : DateTime.now().toUtc().toIso8601String());
    DateTime to = _parseTs(isEdit
        ? existing.validTo
        : DateTime.now()
            .toUtc()
            .add(const Duration(days: 1))
            .toIso8601String());

    final formKey = GlobalKey<FormState>();

    String? vTitle(String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'العنوان مطلوب', en: 'Title is required');
      }
      if (t.length < 3) {
        return AppText.of(context,
            ar: 'العنوان قصير جدًا', en: 'Title is too short');
      }
      if (t.length > 80) {
        return AppText.of(context,
            ar: 'العنوان طويل جدًا', en: 'Title is too long');
      }
      return null;
    }

    String? vBody(String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) {
        return AppText.of(context, ar: 'المحتوى مطلوب', en: 'Body is required');
      }
      if (t.length < 5) {
        return AppText.of(context,
            ar: 'المحتوى قصير جدًا', en: 'Body is too short');
      }
      if (t.length > 600) {
        return AppText.of(context,
            ar: 'المحتوى طويل جدًا', en: 'Body is too long');
      }
      return null;
    }

    String? vTargetRef(String? v) {
      if (targetType == 'all' || targetType == 'system') return null;
      final t = (v ?? '').trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'مرجع الهدف مطلوب', en: 'Target ref is required');
      }
      if (t.length < 3) {
        return AppText.of(context,
            ar: 'مرجع الهدف قصير جدًا', en: 'Target ref is too short');
      }
      return null;
    }

    String? vCreatedBy(String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'حقل أنشئ بواسطة مطلوب', en: 'Created by is required');
      }
      if (t.length < 3) {
        return AppText.of(context,
            ar: 'قيمة أنشئ بواسطة قصيرة جدًا', en: 'Created by is too short');
      }
      return null;
    }

    Future<DateTime?> pickDateTime(DateTime initial) async {
      final d = await showDatePicker(
        context: context,
        initialDate: initial.toLocal(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (d == null) return null;
      if (!context.mounted) return null;
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial.toLocal()),
      );
      if (t == null) return null;
      final local = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      return local.toUtc();
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
                  Icon(isEdit ? Icons.edit_rounded : Icons.campaign_outlined,
                      color: AdminColors.primaryGlow),
                  const SizedBox(width: 8),
                  Text(
                    isEdit
                        ? _annT(ctx, 'Edit Announcement')
                        : _annT(ctx, 'Create Announcement'),
                    style: TextStyle(
                        color: uiText(ctx), fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: titleCtrl,
                          validator: vTitle,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.title_rounded),
                            labelText: _annT(ctx, 'Title'),
                            hintText: _annT(ctx, 'Short clear headline'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: bodyCtrl,
                          validator: vBody,
                          minLines: 3,
                          maxLines: 8,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.notes_rounded),
                            labelText: _annT(ctx, 'Body'),
                            hintText:
                                _annT(ctx, 'Write the announcement message'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: status,
                                items: [
                                  DropdownMenuItem(
                                      value: 'published',
                                      child: Text(_annT(ctx, 'published'))),
                                  DropdownMenuItem(
                                      value: 'draft',
                                      child: Text(_annT(ctx, 'draft'))),
                                  DropdownMenuItem(
                                      value: 'archived',
                                      child: Text(_annT(ctx, 'archived'))),
                                ],
                                onChanged: (v) =>
                                    setLocal(() => status = v ?? 'draft'),
                                decoration: InputDecoration(
                                  prefixIcon:
                                      const Icon(Icons.verified_user_outlined),
                                  labelText: _annT(ctx, 'Status'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: targetType,
                                items: [
                                  DropdownMenuItem(
                                      value: 'lot',
                                      child: Text(_annT(ctx, 'lot'))),
                                  DropdownMenuItem(
                                      value: 'system',
                                      child: Text(_annT(ctx, 'system'))),
                                  DropdownMenuItem(
                                      value: 'all',
                                      child: Text(_annT(ctx, 'all'))),
                                ],
                                onChanged: (v) =>
                                    setLocal(() => targetType = v ?? 'lot'),
                                decoration: InputDecoration(
                                  prefixIcon:
                                      const Icon(Icons.track_changes_outlined),
                                  labelText: _annT(ctx, 'Target type'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: targetRefCtrl,
                          validator: (v) => vTargetRef(v),
                          enabled:
                              !(targetType == 'all' || targetType == 'system'),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.link_rounded),
                            labelText: _annT(ctx, 'Target ref'),
                            hintText: targetType == 'lot'
                                ? 'lot_001'
                                : _annT(ctx, 'Disabled'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: createdByCtrl,
                          validator: vCreatedBy,
                          decoration: InputDecoration(
                            prefixIcon:
                                const Icon(Icons.person_outline_rounded),
                            labelText: _annT(ctx, 'Created by'),
                            hintText: 'user_002',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
                                  final picked = await pickDateTime(from);
                                  if (picked == null) return;
                                  setLocal(() => from = picked);
                                  if (!to.isAfter(from)) {
                                    setLocal(() => to =
                                        from.add(const Duration(hours: 1)));
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(ctx).brightness ==
                                            Brightness.dark
                                        ? AdminColors.darkCard2
                                        : const Color(0xFFF2F7FE),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: uiBorder(ctx)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_outlined,
                                          size: 16,
                                          color: AdminColors.primaryGlow),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          AppText.of(
                                            ctx,
                                            ar: 'من: ${dateShort(from.toIso8601String())}',
                                            en: 'From: ${dateShort(from.toIso8601String())}',
                                          ),
                                          style: TextStyle(
                                              color: uiText(ctx),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
                                  final picked = await pickDateTime(to);
                                  if (picked == null) return;
                                  setLocal(() => to = picked);
                                  if (!to.isAfter(from)) {
                                    setLocal(() => to =
                                        from.add(const Duration(hours: 1)));
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(ctx).brightness ==
                                            Brightness.dark
                                        ? AdminColors.darkCard2
                                        : const Color(0xFFF2F7FE),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: uiBorder(ctx)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.event_outlined,
                                          size: 16,
                                          color: AdminColors.primaryGlow),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          AppText.of(
                                            ctx,
                                            ar: 'إلى: ${dateShort(to.toIso8601String())}',
                                            en: 'To: ${dateShort(to.toIso8601String())}',
                                          ),
                                          style: TextStyle(
                                              color: uiText(ctx),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _annT(ctx, 'Validated before saving.'),
                            style: TextStyle(
                                color: uiSub(ctx),
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
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
                    child: Text(_annT(ctx, 'Cancel'))),
                FilledButton.icon(
                  onPressed: () async {
                    final ok = formKey.currentState?.validate() ?? false;
                    if (!ok) return;

                    if (!to.isAfter(from)) {
                      await showError(
                        ctx,
                        AppText.of(
                          ctx,
                          ar: 'يجب أن يكون وقت "إلى" بعد وقت "من".',
                          en: 'Valid "To" must be after "From".',
                        ),
                      );
                      return;
                    }

                    final nowIso = DateTime.now().toUtc().toIso8601String();
                    final id = isEdit
                        ? existing.id
                        : 'announcement_${DateTime.now().millisecondsSinceEpoch}';

                    final payload = <String, dynamic>{
                      'id': id,
                      'title': titleCtrl.text.trim(),
                      'body': bodyCtrl.text.trim(),
                      'status': status,
                      'target_type': targetType,
                      'target_ref':
                          (targetType == 'all' || targetType == 'system')
                              ? ''
                              : targetRefCtrl.text.trim(),
                      'created_by': createdByCtrl.text.trim(),
                      'valid_from': from.toIso8601String(),
                      'valid_to': to.toIso8601String(),
                      'update_at': nowIso,
                    };

                    if (!isEdit) payload['create_at'] = nowIso;
                    if (isEdit && s(existing.createAt).isNotEmpty) {
                      payload['create_at'] = existing.createAt;
                    }

                    try {
                      await _db.ref('announcement/$id').update(payload);
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      if (!mounted) return;
                      await showOk(
                          context,
                          _annT(context, 'Save'),
                          isEdit
                              ? AppText.of(
                                  context,
                                  ar: 'تم تحديث الإعلان',
                                  en: 'Announcement updated',
                                )
                              : AppText.of(
                                  context,
                                  ar: 'تم إنشاء الإعلان',
                                  en: 'Announcement created',
                                ));
                    } catch (e) {
                      if (!ctx.mounted) return;
                      await showError(ctx, e.toString());
                    }
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: Text(_annT(ctx, 'Save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openDetails(BuildContext context, _AnnItem n) async {
    final now = DateTime.now().toUtc();
    final windowLabel = _windowLabel(n, now);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: uiCard(ctx),
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.campaign_outlined,
                  color: AdminColors.primaryGlow),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  n.title.trim().isEmpty ? n.id : n.title.trim(),
                  style: TextStyle(
                      color: uiText(ctx), fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  InfoRow(label: _annT(ctx, 'Id'), value: n.id),
                  InfoRow(
                      label: _annT(ctx, 'Status'), value: _annT(ctx, n.status)),
                  InfoRow(
                      label: _annT(ctx, 'Target'),
                      value:
                          '${_annT(ctx, n.targetType)} / ${n.targetRef.isEmpty ? '-' : n.targetRef}'),
                  InfoRow(label: _annT(ctx, 'Window'), value: windowLabel),
                  InfoRow(
                      label: _annT(ctx, 'From'), value: dateShort(n.validFrom)),
                  InfoRow(label: _annT(ctx, 'To'), value: dateShort(n.validTo)),
                  InfoRow(
                      label: _annT(ctx, 'Created by'),
                      value: s(n.createdBy, '-')),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? AdminColors.darkCard2
                          : const Color(0xFFF2F7FE),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: uiBorder(ctx)),
                    ),
                    child: Text(
                      n.body.trim().isEmpty ? '-' : n.body.trim(),
                      style: TextStyle(
                          color: uiText(ctx), fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(_annT(ctx, 'Close'))),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _downloadExcel([n], scope: 'single');
              },
              icon: const Icon(Icons.grid_on_rounded),
              label: Text(_annT(ctx, 'Excel')),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _downloadPdf([n], scope: 'single');
              },
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: Text(_annT(ctx, 'PDF')),
            ),
            FilledButton.icon(
              onPressed: () async {
                await _copyText(
                  ctx,
                  n.id,
                  _annT(ctx, 'Copied'),
                  _annT(ctx, 'Announcement id copied'),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: Text(_annT(ctx, 'Copy id')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _setStatus(BuildContext context,
      {required String id, required String next}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await _db
          .ref('announcement/$id')
          .update({'status': next, 'update_at': now});
      if (!mounted) return;
      await showOk(
        context,
        _annT(context, 'Save'),
        AppText.of(
          context,
          ar: 'تم تحديث الحالة إلى ${_annT(context, next)}',
          en: 'Status updated to $next',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _duplicate(BuildContext context, _AnnItem n) async {
    final now = DateTime.now().toUtc();
    final id = 'announcement_${now.millisecondsSinceEpoch}';
    try {
      await _db.ref('announcement/$id').set({
        'id': id,
        'title': n.title,
        'body': n.body,
        'status': 'draft',
        'target_type': n.targetType,
        'target_ref': n.targetRef,
        'created_by': s(n.createdBy, 'user_002'),
        'valid_from': now.toIso8601String(),
        'valid_to': now.add(const Duration(days: 1)).toIso8601String(),
        'create_at': now.toIso8601String(),
        'update_at': now.toIso8601String(),
      });
      if (!mounted) return;
      await showOk(
        context,
        _annT(context, 'Done'),
        _annT(context, 'Duplicated as draft'),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _deleteOne(BuildContext context, _AnnItem n) async {
    final ok = await _confirm(
      context,
      title: _annT(context, 'Delete announcement?'),
      message: AppText.of(
        context,
        ar: 'سيتم حذف "${n.title.trim().isEmpty ? n.id : n.title.trim()}" نهائيًا.',
        en: 'This will permanently delete "${n.title.trim().isEmpty ? n.id : n.title.trim()}".',
      ),
      danger: true,
      okText: _annT(context, 'Delete'),
    );
    if (ok != true) return;

    try {
      await _db.ref('announcement/${n.id}').remove();
      if (!mounted) return;
      await showOk(
        context,
        _annT(context, 'Deleted'),
        _annT(context, 'Announcement deleted'),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _deleteFiltered(
      BuildContext context, List<_AnnItem> list) async {
    if (list.isEmpty) {
      await showError(
        context,
        _annT(context, 'No filtered announcements to delete.'),
      );
      return;
    }

    final ok = await _confirm(
      context,
      title: _annT(context, 'Delete filtered?'),
      message: AppText.of(
        context,
        ar: 'سيتم حذف ${list.length} إعلانًا مطابقًا للبحث أو الفلاتر نهائيًا.',
        en: 'This will permanently delete ${list.length} announcement(s) that match your filters/search.',
      ),
      danger: true,
      okText: _annT(context, 'Delete'),
    );
    if (ok != true) return;

    final updates = <String, dynamic>{};
    for (final n in list) {
      updates['announcement/${n.id}'] = null;
    }

    try {
      await _db.ref().update(updates);
      if (!mounted) return;
      await showOk(
        context,
        _annT(context, 'Deleted'),
        _annT(context, 'Filtered announcements deleted'),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _purgeAll(BuildContext context, List<_AnnItem> all) async {
    if (all.isEmpty) {
      await showError(context, _annT(context, 'No announcements to purge.'));
      return;
    }

    final ok = await _confirm(
      context,
      title: _annT(context, 'Purge ALL?'),
      message: AppText.of(
        context,
        ar: 'سيتم حذف جميع الإعلانات نهائيًا (${all.length}).',
        en: 'This will permanently delete ALL announcements (${all.length}).',
      ),
      danger: true,
      okText: _annT(context, 'Purge'),
    );
    if (ok != true) return;

    try {
      await _db.ref('announcement').remove();
      if (!mounted) return;
      await showOk(
        context,
        _annT(context, 'Purged'),
        _annT(context, 'All announcements deleted'),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _copyText(
      BuildContext context, String text, String t1, String t2) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      await showOk(this.context, t1, t2);
    } catch (e) {
      if (!mounted) return;
      await showError(this.context, e.toString());
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
                  color: danger ? AdminColors.danger : AdminColors.primaryGlow),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style: TextStyle(
                          color: uiText(ctx), fontWeight: FontWeight.w900))),
            ],
          ),
          content: Text(message,
              style: TextStyle(color: uiSub(ctx), fontWeight: FontWeight.w700)),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(_annT(ctx, 'Cancel'))),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                  backgroundColor:
                      danger ? AdminColors.danger : AdminColors.primary),
              child: Text(okText),
            ),
          ],
        );
      },
    );
  }

  bool _isActiveNow(_AnnItem n, DateTime nowUtc) {
    if (n.status.toLowerCase().trim() != 'published') return false;
    final from = _parseTs(n.validFrom);
    final to = _parseTs(n.validTo);
    if (!to.isAfter(from)) return false;
    return (nowUtc.isAfter(from) || nowUtc.isAtSameMomentAs(from)) &&
        nowUtc.isBefore(to);
  }

  bool _isScheduled(_AnnItem n, DateTime nowUtc) {
    if (n.status.toLowerCase().trim() != 'published') return false;
    final from = _parseTs(n.validFrom);
    final to = _parseTs(n.validTo);
    if (!to.isAfter(from)) return false;
    return nowUtc.isBefore(from);
  }

  bool _isExpired(_AnnItem n, DateTime nowUtc) {
    if (n.status.toLowerCase().trim() != 'published') return false;
    final to = _parseTs(n.validTo);
    return nowUtc.isAfter(to) || nowUtc.isAtSameMomentAs(to);
  }

  DateTime? _timeMin(DateTime nowUtc, String tf) {
    if (tf == '24h') return nowUtc.subtract(const Duration(hours: 24));
    if (tf == '7d') return nowUtc.subtract(const Duration(days: 7));
    if (tf == '30d') return nowUtc.subtract(const Duration(days: 30));
    return null;
  }

  DateTime _parseTs(dynamic ts) {
    if (ts == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
    if (ts is double) {
      return DateTime.fromMillisecondsSinceEpoch(ts.toInt(), isUtc: true);
    }

    final sTs = ts.toString().trim();
    if (sTs.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    final asInt = int.tryParse(sTs);
    if (asInt != null && asInt > 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(asInt, isUtc: true);
    }

    final d = DateTime.tryParse(sTs);
    return d ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}

class _Opt {
  final String id;
  final String label;
  const _Opt(this.id, this.label);
}

class _AnnItem {
  final String key;
  final String id;
  final String title;
  final String body;
  final String status;
  final String targetType;
  final String targetRef;
  final String createdBy;
  final String validFrom;
  final String validTo;
  final String createAt;
  final String updateAt;
  final Map<String, dynamic> raw;

  const _AnnItem({
    required this.key,
    required this.id,
    required this.title,
    required this.body,
    required this.status,
    required this.targetType,
    required this.targetRef,
    required this.createdBy,
    required this.validFrom,
    required this.validTo,
    required this.createAt,
    required this.updateAt,
    required this.raw,
  });
}
