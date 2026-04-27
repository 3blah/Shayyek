import 'dart:io';

import 'package:excel/excel.dart' as ex;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../app_text.dart';
import 'admin_theme.dart';
import 'admin_utils.dart';
import 'admin_widgets.dart';

String _auditT(BuildContext context, String text) {
  if (!AppText.isArabic(context)) {
    return text;
  }

  const translations = <String, String>{
    'Audit Logs': 'سجلات التدقيق',
    'Search action, user, target, ip, device':
        'ابحث في الإجراء أو المستخدم أو الهدف أو عنوان IP أو الجهاز',
    'Clear': 'مسح',
    'Actions': 'الإجراءات',
    'Download filtered (Excel)': 'تنزيل المصفى (Excel)',
    'Download filtered (PDF)': 'تنزيل المصفى (PDF)',
    'Delete filtered': 'حذف السجلات المصفاة',
    'Purge all logs': 'حذف كل السجلات',
    'Refresh': 'تحديث',
    'Action': 'الإجراء',
    'Target': 'الهدف',
    'User': 'المستخدم',
    'More users...': 'مستخدمون آخرون...',
    'Pick user': 'اختر مستخدمًا',
    'Time': 'الوقت',
    'All': 'الكل',
    'Last 24h': 'آخر 24 ساعة',
    'Last 7 days': 'آخر 7 أيام',
    'Last 30 days': 'آخر 30 يومًا',
    'Sort': 'الترتيب',
    'Newest': 'الأحدث',
    'Oldest': 'الأقدم',
    'Reset': 'إعادة ضبط',
    'Events': 'الأحداث',
    'Users': 'المستخدمون',
    'Latest': 'الأحدث',
    'Create': 'إنشاء',
    'Update': 'تحديث',
    'Delete': 'حذف',
    'No audit logs found': 'لا توجد سجلات تدقيق',
    'View details': 'عرض التفاصيل',
    'Device': 'الجهاز',
    'IP': 'عنوان IP',
    'Close': 'إغلاق',
    'Delete log?': 'حذف السجل؟',
    'Deleted': 'تم الحذف',
    'Audit log deleted': 'تم حذف سجل التدقيق',
    'No filtered logs to delete.': 'لا توجد سجلات مصفاة للحذف.',
    'Delete filtered logs?': 'حذف السجلات المصفاة؟',
    'Filtered logs deleted': 'تم حذف السجلات المصفاة',
    'No logs to purge.': 'لا توجد سجلات للحذف الكلي.',
    'Purge ALL logs?': 'حذف كل السجلات؟',
    'Purge': 'حذف كلي',
    'Purged': 'تم الحذف الكلي',
    'All audit logs deleted': 'تم حذف جميع سجلات التدقيق',
    'Cancel': 'إلغاء',
    'Search': 'بحث',
    'logged': 'مسجل',
    'Nothing to download.': 'لا توجد بيانات للتنزيل.',
    'Failed to generate Excel.': 'تعذر إنشاء ملف Excel.',
    'Audit Logs Excel': 'Excel سجلات التدقيق',
    'Audit Logs export (Excel)': 'تصدير سجلات التدقيق (Excel)',
    'Audit Logs PDF': 'PDF سجلات التدقيق',
    'Audit Logs export (PDF)': 'تصدير سجلات التدقيق (PDF)',
    'Audit Logs Export': 'تصدير سجلات التدقيق',
    'Excel': 'Excel',
    'PDF': 'PDF',
  };

  return translations[text] ?? text;
}

class AdminAuditLogsPage extends StatefulWidget {
  const AdminAuditLogsPage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<AdminAuditLogsPage> createState() => _AdminAuditLogsPageState();
}

class _AdminAuditLogsPageState extends State<AdminAuditLogsPage> {
  final _db = FirebaseDatabase.instance;

  String _q = '';
  String _actionFilter = 'all';
  String _targetFilter = 'all';
  String _userFilter = 'all';
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

  Future<void> _downloadExcel(List<_AuditItem> rows,
      {required String scope}) async {
    final nothingToDownloadMessage = _auditT(context, 'Nothing to download.');
    final failedToGenerateExcelMessage =
        _auditT(context, 'Failed to generate Excel.');
    final excelSubject = _auditT(context, 'Audit Logs Excel');
    final excelText = _auditT(context, 'Audit Logs export (Excel)');

    if (rows.isEmpty) {
      if (!mounted) return;
      await showError(context, nothingToDownloadMessage);
      return;
    }

    try {
      final excel = ex.Excel.createExcel();
      final sheet = excel['AuditLogs'];

      sheet.appendRow(<ex.CellValue?>[
        ex.TextCellValue('key'),
        ex.TextCellValue('action'),
        ex.TextCellValue('user_id'),
        ex.TextCellValue('device'),
        ex.TextCellValue('ip'),
        ex.TextCellValue('target_type'),
        ex.TextCellValue('target_id'),
        ex.TextCellValue('ts'),
      ]);

      for (final n in rows) {
        sheet.appendRow(<ex.CellValue?>[
          ex.TextCellValue(n.key),
          ex.TextCellValue(n.action),
          ex.TextCellValue(n.userId),
          ex.TextCellValue(n.device),
          ex.TextCellValue(n.ip),
          ex.TextCellValue(n.targetType),
          ex.TextCellValue(n.targetId),
          ex.TextCellValue(n.ts),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) {
        if (!mounted) return;
        await showError(context, failedToGenerateExcelMessage);
        return;
      }

      final file = await _writeBytes(
        'audit_logs_${scope}_${_safeStamp()}.xlsx',
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

  Future<void> _downloadPdf(List<_AuditItem> rows,
      {required String scope}) async {
    final nothingToDownloadMessage = _auditT(context, 'Nothing to download.');
    final exportTitle = _auditT(context, 'Audit Logs Export');
    final pdfSubject = _auditT(context, 'Audit Logs PDF');
    final pdfText = _auditT(context, 'Audit Logs export (PDF)');

    if (rows.isEmpty) {
      if (!mounted) return;
      await showError(context, nothingToDownloadMessage);
      return;
    }

    try {
      final doc = pw.Document();

      final header = <String>[
        'action',
        'user_id',
        'target',
        'device',
        'ip',
        'time',
      ];

      final data = rows.map((n) {
        final tt = n.targetType.trim().isEmpty ? '-' : n.targetType.trim();
        final tid = n.targetId.trim().isEmpty ? '-' : n.targetId.trim();
        final device = n.device.trim().isEmpty ? '-' : n.device.trim();
        final ip = n.ip.trim().isEmpty ? '-' : n.ip.trim();
        final user = n.userId.trim().isEmpty ? '-' : n.userId.trim();
        final action = n.action.trim().isEmpty ? '-' : n.action.trim();

        return <String>[
          action,
          user,
          '$tt / $tid',
          device,
          ip,
          dateShort(n.ts),
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
                  0: const pw.FlexColumnWidth(1.3),
                  1: const pw.FlexColumnWidth(1.1),
                  2: const pw.FlexColumnWidth(1.8),
                  3: const pw.FlexColumnWidth(1.3),
                  4: const pw.FlexColumnWidth(1.0),
                  5: const pw.FlexColumnWidth(1.2),
                },
              ),
            ];
          },
        ),
      );

      final bytes = await doc.save();
      final file = await _writeBytes(
        'audit_logs_${scope}_${_safeStamp()}.pdf',
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
      title: _auditT(context, 'Audit Logs'),
      isDarkMode: widget.isDarkMode,
      onToggleTheme: widget.onToggleTheme,
      child: StreamBuilder<DatabaseEvent>(
        stream: _db.ref('auditLogs').onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return errorBox(context, () => setState(() {}));
          }
          if (!snapshot.hasData) return loadingBox(context);

          final entries = childEntries(snapshot.data!.snapshot.value);
          final items = entries
              .map((e) {
                final m = mapOf(e.value);
                return _AuditItem(
                  key: s(e.key),
                  action: s(m['action']),
                  userId: s(m['user_id']),
                  device: s(m['device']),
                  ip: s(m['ip']),
                  targetType: s(m['target_type']),
                  targetId: s(m['target_id']),
                  ts: s(m['ts']),
                  raw: m,
                );
              })
              .where((x) => x.key.isNotEmpty)
              .toList();

          items.sort((a, b) {
            final ad = _parseTs(a.ts);
            final bd = _parseTs(b.ts);
            final c = ad.compareTo(bd);
            return _sort == 'oldest' ? c : -c;
          });

          final actions = <String>{};
          final targets = <String>{};
          final users = <String>{};

          for (final n in items) {
            final a = n.action.trim();
            final t = n.targetType.trim();
            final u = n.userId.trim();
            if (a.isNotEmpty) actions.add(a);
            if (t.isNotEmpty) targets.add(t);
            if (u.isNotEmpty) users.add(u);
          }

          final actionOptions = actions.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          final targetOptions = targets.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          final userOptions = users.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          final now = DateTime.now().toUtc();
          final minTs = _timeMin(now, _timeFilter);

          final filtered = items.where((n) {
            if (_actionFilter != 'all' && n.action.trim() != _actionFilter) {
              return false;
            }
            if (_targetFilter != 'all' &&
                n.targetType.trim() != _targetFilter) {
              return false;
            }
            if (_userFilter != 'all' && n.userId.trim() != _userFilter) {
              return false;
            }

            if (minTs != null) {
              final d = _parseTs(n.ts);
              if (d.isBefore(minTs)) return false;
            }

            if (_q.isNotEmpty) {
              final blob =
                  '${n.action} ${n.userId} ${n.device} ${n.ip} ${n.targetType} ${n.targetId} ${n.ts}'
                      .toLowerCase();
              if (!blob.contains(_q)) return false;
            }

            return true;
          }).toList();

          final latest = items.isNotEmpty ? items.first.ts : '';
          final uniqueUsers = users.length;

          int createCount = 0;
          int updateCount = 0;
          int deleteCount = 0;
          for (final n in items) {
            final a = n.action.toLowerCase();
            if (a.contains('create') || a.contains('add')) createCount++;
            if (a.contains('update') || a.contains('edit')) updateCount++;
            if (a.contains('delete') || a.contains('remove')) deleteCount++;
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
                        hintText: _auditT(
                          context,
                          'Search action, user, target, ip, device',
                        ),
                        suffixIcon: _q.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => setState(() => _q = ''),
                                icon: const Icon(Icons.close_rounded),
                                tooltip: _auditT(context, 'Clear'),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PopupMenuButton<String>(
                    tooltip: _auditT(context, 'Actions'),
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
                          child:
                              Text(_auditT(ctx, 'Download filtered (Excel)'))),
                      PopupMenuItem(
                          value: 'download_pdf',
                          child: Text(_auditT(ctx, 'Download filtered (PDF)'))),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                          value: 'delete_filtered',
                          child: Text(_auditT(ctx, 'Delete filtered'))),
                      PopupMenuItem(
                          value: 'purge_all',
                          child: Text(_auditT(ctx, 'Purge all logs'))),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'refresh',
                        child: Text(_auditT(ctx, 'Refresh')),
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
                    icon: Icons.fact_check_outlined,
                    label: _auditT(context, 'Action'),
                    value: _actionFilter,
                    options: [
                      _Opt('all', _auditT(context, 'All')),
                      ...actionOptions.map((x) => _Opt(x, x)),
                    ],
                    onSelected: (v) => setState(() => _actionFilter = v),
                  ),
                  _filterPill(
                    context,
                    icon: Icons.track_changes_outlined,
                    label: _auditT(context, 'Target'),
                    value: _targetFilter,
                    options: [
                      _Opt('all', _auditT(context, 'All')),
                      ...targetOptions.map((x) => _Opt(x, x)),
                    ],
                    onSelected: (v) => setState(() => _targetFilter = v),
                  ),
                  _filterPill(
                    context,
                    icon: Icons.person_outline_rounded,
                    label: _auditT(context, 'User'),
                    value: _userFilter,
                    options: [
                      _Opt('all', _auditT(context, 'All')),
                      ...userOptions.take(30).map((x) => _Opt(x, x)),
                      if (userOptions.length > 30)
                        _Opt('__more__', _auditT(context, 'More users...')),
                    ],
                    onSelected: (v) async {
                      if (v == '__more__') {
                        final picked = await _pickFromList(
                          context,
                          title: _auditT(context, 'Pick user'),
                          items: userOptions,
                          selected: _userFilter == 'all' ? null : _userFilter,
                        );
                        if (picked != null) {
                          setState(() => _userFilter = picked);
                        }
                        return;
                      }
                      setState(() => _userFilter = v);
                    },
                  ),
                  _filterPill(
                    context,
                    icon: Icons.schedule_outlined,
                    label: _auditT(context, 'Time'),
                    value: _timeFilter,
                    options: [
                      _Opt('all', _auditT(context, 'All')),
                      _Opt('24h', _auditT(context, 'Last 24h')),
                      _Opt('7d', _auditT(context, 'Last 7 days')),
                      _Opt('30d', _auditT(context, 'Last 30 days')),
                    ],
                    onSelected: (v) => setState(() => _timeFilter = v),
                  ),
                  _filterPill(
                    context,
                    icon: Icons.sort_rounded,
                    label: _auditT(context, 'Sort'),
                    value: _sort,
                    options: [
                      _Opt('newest', _auditT(context, 'Newest')),
                      _Opt('oldest', _auditT(context, 'Oldest')),
                    ],
                    onSelected: (v) => setState(() => _sort = v),
                  ),
                  if (_hasAnyFilterApplied())
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _q = '';
                        _actionFilter = 'all';
                        _targetFilter = 'all';
                        _userFilter = 'all';
                        _timeFilter = 'all';
                        _sort = 'newest';
                      }),
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: Text(_auditT(context, 'Reset')),
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
                            title: _auditT(context, 'Events'),
                            value: '${items.length}',
                            icon: Icons.fact_check_outlined,
                            color: AdminColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            title: _auditT(context, 'Users'),
                            value: '$uniqueUsers',
                            icon: Icons.people_alt_outlined,
                            color: AdminColors.primaryGlow,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            title: _auditT(context, 'Latest'),
                            value: latest.isEmpty ? '-' : dateShort(latest),
                            icon: Icons.schedule_outlined,
                            color: AdminColors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: _auditT(context, 'Create'),
                            value: '$createCount',
                            icon: Icons.add_circle_outline_rounded,
                            color: AdminColors.success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            title: _auditT(context, 'Update'),
                            value: '$updateCount',
                            icon: Icons.edit_outlined,
                            color: AdminColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            title: _auditT(context, 'Delete'),
                            value: '$deleteCount',
                            icon: Icons.delete_outline_rounded,
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
                          child: Text(_auditT(context, 'No audit logs found'),
                              style: TextStyle(color: uiSub(context))),
                        ),
                      ),
                    ...filtered.map((n) => _logCard(context, n)),
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
        _actionFilter != 'all' ||
        _targetFilter != 'all' ||
        _userFilter != 'all' ||
        _timeFilter != 'all' ||
        _sort != 'newest';
  }

  Widget _logCard(BuildContext context, _AuditItem n) {
    final title = n.action.trim().isEmpty ? '-' : n.action.trim();
    final user = n.userId.trim().isEmpty ? '-' : n.userId.trim();
    final tt = n.targetType.trim().isEmpty ? '-' : n.targetType.trim();
    final tid = n.targetId.trim().isEmpty ? '-' : n.targetId.trim();
    final ip = n.ip.trim().isEmpty ? '-' : n.ip.trim();
    final device = n.device.trim().isEmpty ? '-' : n.device.trim();

    final icon = _iconForAction(title.toLowerCase());
    final color = _colorForAction(title.toLowerCase());
    final border = color.withOpacity(.22);

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
                    backgroundColor: color.withOpacity(.14),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: uiText(context)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppText.of(
                            context,
                            ar: 'المستخدم: $user',
                            en: 'User: $user',
                          ),
                          style: TextStyle(
                              fontSize: 12,
                              color: uiSub(context),
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(_auditT(context, 'logged')),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'details') {
                        await _openDetails(context, n);
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
                      if (v == 'delete') {
                        await _deleteOne(context, n);
                        return;
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                          value: 'details',
                          child: Text(_auditT(ctx, 'View details'))),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                          value: 'download_excel',
                          child: Text(_auditT(ctx, 'Download (Excel)'))),
                      PopupMenuItem(
                          value: 'download_pdf',
                          child: Text(_auditT(ctx, 'Download (PDF)'))),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(_auditT(ctx, 'Delete')),
                      ),
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
                  _chip(
                    context,
                    AppText.of(
                      context,
                      ar: 'الهدف: $tt / $tid',
                      en: 'Target: $tt / $tid',
                    ),
                    Icons.track_changes_outlined,
                  ),
                  _chip(
                    context,
                    AppText.of(context, ar: 'عنوان IP: $ip', en: 'IP: $ip'),
                    Icons.public_rounded,
                  ),
                  _chip(
                    context,
                    AppText.of(
                      context,
                      ar: 'الجهاز: $device',
                      en: 'Device: $device',
                    ),
                    Icons.devices_other_outlined,
                  ),
                  _chip(
                    context,
                    AppText.of(
                      context,
                      ar: 'الوقت: ${dateShort(n.ts)}',
                      en: 'Time: ${dateShort(n.ts)}',
                    ),
                    Icons.schedule_outlined,
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
                color: uiText(context),
                fontWeight: FontWeight.w800),
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

  Future<void> _openDetails(BuildContext context, _AuditItem n) async {
    final title = n.action.trim().isEmpty ? '-' : n.action.trim();
    final user = n.userId.trim().isEmpty ? '-' : n.userId.trim();
    final tt = n.targetType.trim().isEmpty ? '-' : n.targetType.trim();
    final tid = n.targetId.trim().isEmpty ? '-' : n.targetId.trim();
    final ip = n.ip.trim().isEmpty ? '-' : n.ip.trim();
    final device = n.device.trim().isEmpty ? '-' : n.device.trim();

    final icon = _iconForAction(title.toLowerCase());
    final color = _colorForAction(title.toLowerCase());

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
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withOpacity(.14),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                      color: uiText(ctx), fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  InfoRow(label: _auditT(ctx, 'User'), value: user),
                  InfoRow(label: _auditT(ctx, 'Device'), value: device),
                  InfoRow(label: _auditT(ctx, 'IP'), value: ip),
                  InfoRow(label: _auditT(ctx, 'Target'), value: '$tt / $tid'),
                  InfoRow(label: _auditT(ctx, 'Time'), value: dateShort(n.ts)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(_auditT(ctx, 'Close'))),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _downloadExcel([n], scope: 'single');
              },
              icon: const Icon(Icons.grid_on_rounded),
              label: Text(_auditT(ctx, 'Excel')),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _downloadPdf([n], scope: 'single');
              },
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: Text(_auditT(ctx, 'PDF')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteOne(BuildContext context, _AuditItem n) async {
    final ok = await _confirm(
      context,
      title: _auditT(context, 'Delete log?'),
      message: AppText.of(
        context,
        ar: 'سيتم حذف سجل التدقيق هذا نهائيًا.',
        en: 'This will permanently delete this audit log entry.',
      ),
      danger: true,
      okText: _auditT(context, 'Delete'),
    );
    if (ok != true) return;

    try {
      await _db.ref('auditLogs/${n.key}').remove();
      if (!mounted) return;
      await showOk(
        context,
        _auditT(context, 'Deleted'),
        _auditT(context, 'Audit log deleted'),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _deleteFiltered(
      BuildContext context, List<_AuditItem> list) async {
    if (list.isEmpty) {
      await showError(context, _auditT(context, 'No filtered logs to delete.'));
      return;
    }

    final ok = await _confirm(
      context,
      title: _auditT(context, 'Delete filtered logs?'),
      message: AppText.of(
        context,
        ar: 'سيتم حذف ${list.length} سجلًا مطابقًا للبحث أو الفلاتر نهائيًا.',
        en: 'This will permanently delete ${list.length} log(s) that match your filters/search.',
      ),
      danger: true,
      okText: _auditT(context, 'Delete'),
    );
    if (ok != true) return;

    final updates = <String, dynamic>{};
    for (final n in list) {
      updates['auditLogs/${n.key}'] = null;
    }

    try {
      await _db.ref().update(updates);
      if (!mounted) return;
      await showOk(
        context,
        _auditT(context, 'Deleted'),
        _auditT(context, 'Filtered logs deleted'),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _purgeAll(BuildContext context, List<_AuditItem> all) async {
    if (all.isEmpty) {
      await showError(context, _auditT(context, 'No logs to purge.'));
      return;
    }

    final ok = await _confirm(
      context,
      title: _auditT(context, 'Purge ALL logs?'),
      message: AppText.of(
        context,
        ar: 'سيتم حذف جميع سجلات التدقيق نهائيًا (${all.length}).',
        en: 'This will permanently delete ALL audit logs (${all.length}).',
      ),
      danger: true,
      okText: _auditT(context, 'Purge'),
    );
    if (ok != true) return;

    try {
      await _db.ref('auditLogs').remove();
      if (!mounted) return;
      await showOk(
        context,
        _auditT(context, 'Purged'),
        _auditT(context, 'All audit logs deleted'),
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
          content: Text(message,
              style: TextStyle(color: uiSub(ctx), fontWeight: FontWeight.w700)),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(_auditT(ctx, 'Cancel'))),
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

  Future<String?> _pickFromList(
    BuildContext context, {
    required String title,
    required List<String> items,
    String? selected,
  }) async {
    String q = '';
    List<String> filtered = items;

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            filtered = items
                .where((x) =>
                    q.isEmpty || x.toLowerCase().contains(q.toLowerCase()))
                .toList();
            return AlertDialog(
              backgroundColor: uiCard(ctx),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Text(title,
                  style: TextStyle(
                      color: uiText(ctx), fontWeight: FontWeight.w900)),
              content: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 520, maxHeight: 460),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (v) => setLocal(() => q = v.trim()),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: _auditT(ctx, 'Search'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView(
                        children: [
                          ListTile(
                            title: Text(_auditT(ctx, 'All')),
                            trailing: selected == null
                                ? const Icon(Icons.check_rounded)
                                : null,
                            onTap: () => Navigator.of(ctx).pop('all'),
                          ),
                          ...filtered.map((x) {
                            return ListTile(
                              title: Text(x),
                              trailing: selected == x
                                  ? const Icon(Icons.check_rounded)
                                  : null,
                              onTap: () => Navigator.of(ctx).pop(x),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: Text(_auditT(ctx, 'Close'))),
              ],
            );
          },
        );
      },
    );
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

  IconData _iconForAction(String a) {
    if (a.contains('delete') || a.contains('remove')) {
      return Icons.delete_outline_rounded;
    }
    if (a.contains('update') || a.contains('edit')) return Icons.edit_outlined;
    if (a.contains('create') || a.contains('add')) {
      return Icons.add_circle_outline_rounded;
    }
    if (a.contains('login') || a.contains('auth')) return Icons.login_rounded;
    return Icons.fact_check_outlined;
  }

  Color _colorForAction(String a) {
    if (a.contains('delete') || a.contains('remove')) return AdminColors.danger;
    if (a.contains('update') || a.contains('edit')) return AdminColors.primary;
    if (a.contains('create') || a.contains('add')) return AdminColors.success;
    if (a.contains('login') || a.contains('auth')) return AdminColors.warning;
    return AdminColors.primaryGlow;
  }
}

class _Opt {
  final String id;
  final String label;
  const _Opt(this.id, this.label);
}

class _AuditItem {
  final String key;
  final String action;
  final String userId;
  final String device;
  final String ip;
  final String targetType;
  final String targetId;
  final String ts;
  final Map<String, dynamic> raw;

  const _AuditItem({
    required this.key,
    required this.action,
    required this.userId,
    required this.device,
    required this.ip,
    required this.targetType,
    required this.targetId,
    required this.ts,
    required this.raw,
  });
}
