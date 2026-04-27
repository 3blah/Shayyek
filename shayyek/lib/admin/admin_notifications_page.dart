import 'dart:math';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_text.dart';
import 'admin_l10n.dart';
import 'admin_theme.dart';
import 'admin_utils.dart';
import 'admin_widgets.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final _db = FirebaseDatabase.instance;

  final TextEditingController _searchCtrl = TextEditingController();

  String _q = '';
  String _statusFilter = 'all';
  String _channelFilter = 'all';
  String _typeFilter = 'all';
  String _targetFilter = 'all';
  String _sort = 'newest';

  static const List<String> _channels = ['push', 'email', 'in_app'];
  static const List<String> _statuses = [
    'draft',
    'queued',
    'sent',
    'failed',
    'cancelled'
  ];

  static const List<String> _baseTypes = [
    'admin_notice',
    'system',
    'promo',
    'alert',
    'time_expiry',
    'nearby_spot_opened',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _t(String text) => adminL10n(context, text);

  String _targetText(String uid) {
    if (uid == 'all') {
      return _t('Target: all users');
    }
    return AppText.of(context, ar: 'الهدف: $uid', en: 'Target: $uid');
  }

  String _mailQuery(Map<String, String> params) {
    return params.entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .map((entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');
  }

  Future<List<String>> _resolveEmailRecipients(String userId) async {
    final snap = await _db.ref('User').get();
    final entries = childEntries(snap.value);
    final recipients = <String>{};
    final target = userId.trim();

    for (final entry in entries) {
      final row = mapOf(entry.value);
      final email = s(row['email']).trim();
      if (email.isEmpty) {
        continue;
      }

      final status = s(row['status'], 'active').trim().toLowerCase();
      if (target == 'all') {
        if (status != 'inactive') {
          recipients.add(email);
        }
        continue;
      }

      final ids = <String>{
        s(entry.key).trim(),
        s(row['id'], entry.key).trim(),
        s(row['auth_uid']).trim(),
      }..removeWhere((value) => value.isEmpty);

      if (ids.contains(target)) {
        recipients.add(email);
      }
    }

    return recipients.toList()..sort();
  }

  Future<bool> _maybeOpenEmailComposer({
    required String channel,
    required String status,
    required String title,
    required String body,
    required String userId,
  }) async {
    if (channel.trim().toLowerCase() != 'email' ||
        status.trim().toLowerCase() != 'sent') {
      return false;
    }

    final recipients = await _resolveEmailRecipients(userId);
    if (recipients.isEmpty) {
      if (mounted) {
        await showError(
          context,
          AppText.of(
            context,
            ar: 'لا يوجد مستلمون ببريد إلكتروني صالح لهذا الإشعار.',
            en: 'No valid email recipients were found for this notification.',
          ),
        );
      }
      return false;
    }

    final primaryRecipient = recipients.length == 1 ? recipients.first : '';
    final uri = Uri(
      scheme: 'mailto',
      path: primaryRecipient,
      query: _mailQuery({
        if (recipients.length > 1) 'bcc': recipients.join(','),
        'subject': title,
        'body': body,
      }),
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      await showError(
        context,
        AppText.of(
          context,
          ar: 'تعذر فتح تطبيق البريد الإلكتروني على هذا الجهاز.',
          en: 'Unable to open an email app on this device.',
        ),
      );
    }
    return launched;
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final isDark = base.brightness == Brightness.dark;
    final menuBg = isDark ? AdminColors.darkCard2 : Colors.white;

    return Theme(
      data: base.copyWith(
        canvasColor: menuBg,
        popupMenuTheme: PopupMenuThemeData(
          color: menuBg,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: TextStyle(
            color: uiText(context),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: AdminPageFrame(
        title: _t('Notifications'),
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) =>
                        setState(() => _q = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: _t(
                        'Search title, body, user, type, channel, status',
                      ),
                      suffixIcon: _q.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => setState(() {
                                _q = '';
                                _searchCtrl.clear();
                              }),
                              icon: const Icon(Icons.close_rounded),
                              tooltip: _t('Clear'),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () => _openNotifEditor(context),
                  icon: const Icon(Icons.add_alert_rounded),
                  label: Text(_t('Create')),
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
                  icon: Icons.filter_alt_outlined,
                  label: _t('Status'),
                  value: _statusFilter,
                  options: [
                    _Opt('all', _t('All')),
                    _Opt('draft', _t('draft')),
                    _Opt('queued', _t('queued')),
                    _Opt('sent', _t('sent')),
                    _Opt('failed', _t('failed')),
                    _Opt('cancelled', _t('cancelled')),
                  ],
                  onSelected: (v) => setState(() => _statusFilter = v),
                ),
                _filterPill(
                  context,
                  icon: Icons.route_outlined,
                  label: _t('Channel'),
                  value: _channelFilter,
                  options: [
                    _Opt('all', _t('All')),
                    const _Opt('push', 'push'),
                    const _Opt('email', 'email'),
                    const _Opt('in_app', 'in_app'),
                  ],
                  onSelected: (v) => setState(() => _channelFilter = v),
                ),
                _filterPill(
                  context,
                  icon: Icons.category_outlined,
                  label: _t('Type'),
                  value: _typeFilter,
                  options: [
                    _Opt('all', _t('All')),
                    const _Opt('admin_notice', 'admin_notice'),
                    const _Opt('system', 'system'),
                    const _Opt('promo', 'promo'),
                    const _Opt('alert', 'alert'),
                    const _Opt('time_expiry', 'time_expiry'),
                    const _Opt('nearby_spot_opened', 'nearby_spot_opened'),
                  ],
                  onSelected: (v) => setState(() => _typeFilter = v),
                ),
                _filterPill(
                  context,
                  icon: Icons.people_alt_outlined,
                  label: _t('Target'),
                  value: _targetFilter,
                  options: [
                    _Opt('all', _t('All')),
                    _Opt('broadcast', _t('all users')),
                    _Opt('user', _t('specific user')),
                  ],
                  onSelected: (v) => setState(() => _targetFilter = v),
                ),
                _filterPill(
                  context,
                  icon: Icons.sort_rounded,
                  label: _t('Sort'),
                  value: _sort,
                  options: [
                    _Opt('newest', _t('newest')),
                    _Opt('oldest', _t('oldest')),
                  ],
                  onSelected: (v) => setState(() => _sort = v),
                ),
                if (_hasAnyFilterApplied())
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _statusFilter = 'all';
                      _channelFilter = 'all';
                      _typeFilter = 'all';
                      _targetFilter = 'all';
                      _sort = 'newest';
                      _q = '';
                      _searchCtrl.clear();
                    }),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: Text(_t('Reset')),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<DatabaseEvent>(
                stream: _db.ref('Notification').onValue,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return errorBox(context, () => setState(() {}));
                  }
                  if (!snapshot.hasData) return loadingBox(context);

                  final raw = childEntries(snapshot.data!.snapshot.value);

                  final items = raw
                      .map((e) {
                        final m = mapOf(e.value);
                        final id = s(m['id'], e.key);
                        return _NotifItem(
                          key: s(e.key),
                          id: id,
                          title: s(m['title']),
                          body: s(m['body']),
                          channel: s(m['channel'], 'push'),
                          status: s(m['status'], 'queued'),
                          type: s(m['type'], 'admin_notice'),
                          userId: s(m['user_id'], 'all'),
                          createAt: s(m['create_at']),
                          updateAt: s(m['update_at']),
                          sentAt: s(m['sent_at']),
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

                  int queued = 0;
                  int sent = 0;
                  int failed = 0;
                  int cancelled = 0;
                  int draft = 0;

                  for (final n in items) {
                    final st = n.status.toLowerCase().trim();
                    if (st == 'queued') queued++;
                    if (st == 'sent') sent++;
                    if (st == 'failed') failed++;
                    if (st == 'cancelled') cancelled++;
                    if (st == 'draft') draft++;
                  }

                  final filtered = items.where((n) {
                    final st = n.status.toLowerCase().trim();
                    final ch = n.channel.toLowerCase().trim();
                    final ty = n.type.toLowerCase().trim();
                    final uid = n.userId.toLowerCase().trim();

                    if (_statusFilter != 'all' && st != _statusFilter) {
                      return false;
                    }
                    if (_channelFilter != 'all' && ch != _channelFilter) {
                      return false;
                    }
                    if (_typeFilter != 'all' && ty != _typeFilter) return false;

                    if (_targetFilter == 'broadcast' && uid != 'all') {
                      return false;
                    }
                    if (_targetFilter == 'user' &&
                        (uid.isEmpty || uid == 'all')) return false;

                    if (_q.isNotEmpty) {
                      final blob =
                          '${n.title} ${n.body} ${n.userId} ${n.type} ${n.channel} ${n.status}'
                              .toLowerCase();
                      if (!blob.contains(_q)) return false;
                    }

                    return true;
                  }).toList();

                  return ListView(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: _t('Total'),
                              value: '${items.length}',
                              icon: Icons.notifications_active_outlined,
                              color: AdminColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              title: _t('Queued'),
                              value: '$queued',
                              icon: Icons.schedule_send_outlined,
                              color: AdminColors.primaryGlow,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              title: _t('Sent'),
                              value: '$sent',
                              icon: Icons.check_circle_outline_rounded,
                              color: AdminColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: _t('Failed'),
                              value: '$failed',
                              icon: Icons.error_outline_rounded,
                              color: AdminColors.danger,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              title: _t('Cancelled'),
                              value: '$cancelled',
                              icon: Icons.do_disturb_alt_outlined,
                              color: AdminColors.warning,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              title: _t('Draft'),
                              value: '$draft',
                              icon: Icons.edit_note_rounded,
                              color: AdminColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Center(
                            child: Text(_t('No notifications found'),
                                style: TextStyle(color: uiSub(context))),
                          ),
                        ),
                      ...filtered.map((n) => _notifCard(context, n)),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasAnyFilterApplied() {
    return _statusFilter != 'all' ||
        _channelFilter != 'all' ||
        _typeFilter != 'all' ||
        _targetFilter != 'all' ||
        _sort != 'newest' ||
        _q.isNotEmpty;
  }

  Widget _notifCard(BuildContext context, _NotifItem n) {
    final st = n.status.toLowerCase().trim();
    final ch = n.channel.toLowerCase().trim();
    final ty = n.type.toLowerCase().trim();
    final uid = n.userId.trim().isEmpty ? 'all' : n.userId.trim();

    final icon = _channelIcon(ch);
    final iconColor = _statusColor(st);
    final border = st == 'sent'
        ? AdminColors.success.withOpacity(.22)
        : st == 'failed'
            ? AdminColors.danger.withOpacity(.22)
            : st == 'cancelled'
                ? AdminColors.warning.withOpacity(.22)
                : uiBorder(context);

    final lotId = s(n.raw['lot_id']);
    final stallId = s(n.raw['stall_id']);
    final sessionId = s(n.raw['session_id']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                  backgroundColor: iconColor.withOpacity(.14),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title.isEmpty ? '-' : n.title,
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: uiText(context)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _targetText(uid),
                        style: TextStyle(
                            fontSize: 12,
                            color: uiSub(context),
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                StatusPill(st),
                const SizedBox(width: 6),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      await _openNotifEditor(context, existing: n);
                      return;
                    }
                    if (v == 'duplicate') {
                      await _duplicateNotif(context, n);
                      return;
                    }
                    if (v == 'cancel') {
                      await _setStatus(context, id: n.id, next: 'cancelled');
                      return;
                    }
                    if (v == 'retry') {
                      await _setStatus(context, id: n.id, next: 'queued');
                      return;
                    }
                    if (v == 'delete') {
                      await _deleteNotif(context, n);
                      return;
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(value: 'edit', child: Text(_t('Edit'))),
                    PopupMenuItem(
                        value: 'duplicate', child: Text(_t('Duplicate'))),
                    if (st != 'cancelled')
                      PopupMenuItem(
                          value: 'cancel',
                          child: Text(
                              AppText.of(context, ar: 'إلغاء', en: 'Cancel'))),
                    if (st == 'failed')
                      PopupMenuItem(
                          value: 'retry',
                          child: Text(_t('Retry (set queued)'))),
                    const PopupMenuDivider(),
                    PopupMenuItem(value: 'delete', child: Text(_t('Delete'))),
                  ],
                  icon: Icon(Icons.more_vert_rounded, color: uiSub(context)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              n.body.isEmpty ? '-' : n.body,
              style:
                  TextStyle(color: uiSub(context), fontWeight: FontWeight.w700),
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
                    '${_t('Channel')}: ${n.channel.isEmpty ? '-' : n.channel}',
                    Icons.route_outlined),
                _chip(context, '${_t('Type')}: ${ty.isEmpty ? '-' : _t(ty)}',
                    Icons.category_outlined),
                _chip(context, '${_t('Status')}: ${st.isEmpty ? '-' : _t(st)}',
                    Icons.verified_user_outlined),
                _chip(context, '${_t('Created')}: ${dateShort(n.createAt)}',
                    Icons.calendar_today_outlined),
                if (s(n.sentAt).isNotEmpty)
                  _chip(context, '${_t('Sent')}: ${dateShort(n.sentAt)}',
                      Icons.check_circle_outline_rounded),
                if (lotId.isNotEmpty)
                  _chip(context, '${_t('Lot')}: $lotId', Icons.map_outlined),
                if (stallId.isNotEmpty)
                  _chip(context, '${_t('Stall id')}: $stallId',
                      Icons.local_parking_outlined),
                if (sessionId.isNotEmpty)
                  _chip(context, '${_t('Session id')}: $sessionId',
                      Icons.timer_outlined),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (st == 'draft' || st == 'queued') ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          _setStatus(context, id: n.id, next: 'sent'),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: Text(_t('Mark Sent')),
                      style: FilledButton.styleFrom(
                          backgroundColor: AdminColors.success),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          _setStatus(context, id: n.id, next: 'cancelled'),
                      icon: const Icon(Icons.do_disturb_alt_outlined),
                      label:
                          Text(AppText.of(context, ar: 'إلغاء', en: 'Cancel')),
                      style: FilledButton.styleFrom(
                          backgroundColor: AdminColors.warning),
                    ),
                  ),
                ] else if (st == 'failed') ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          _setStatus(context, id: n.id, next: 'queued'),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(_t('Retry')),
                      style: FilledButton.styleFrom(
                          backgroundColor: AdminColors.primary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          _setStatus(context, id: n.id, next: 'cancelled'),
                      icon: const Icon(Icons.do_disturb_alt_outlined),
                      label:
                          Text(AppText.of(context, ar: 'إلغاء', en: 'Cancel')),
                      style: FilledButton.styleFrom(
                          backgroundColor: AdminColors.warning),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openNotifEditor(context, existing: n),
                      icon: const Icon(Icons.edit_rounded),
                      label: Text(_t('Edit')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _deleteNotif(context, n),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(_t('Delete')),
                      style: FilledButton.styleFrom(
                          backgroundColor: AdminColors.danger),
                    ),
                  ),
                ],
              ],
            ),
          ],
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

  Future<void> _openNotifEditor(BuildContext context,
      {_NotifItem? existing}) async {
    final isEdit = existing != null;
    final existingItem = existing;

    final titleCtrl = TextEditingController(text: existingItem?.title ?? '');
    final bodyCtrl = TextEditingController(text: existingItem?.body ?? '');
    final userCtrl = TextEditingController(
        text: isEdit && (existingItem?.userId ?? 'all') != 'all'
            ? existingItem?.userId ?? ''
            : '');

    final lotCtrl = TextEditingController(text: s(existingItem?.raw['lot_id']));
    final stallCtrl =
        TextEditingController(text: s(existingItem?.raw['stall_id']));
    final sessionCtrl =
        TextEditingController(text: s(existingItem?.raw['session_id']));

    final typeFromDb =
        isEdit ? s(existingItem?.type, 'admin_notice') : 'admin_notice';
    final statusFromDb = isEdit ? s(existingItem?.status, 'queued') : 'draft';
    final channelFromDb = isEdit ? s(existingItem?.channel, 'push') : 'push';

    String target = isEdit
        ? (s(existingItem?.userId, 'all') == 'all' ? 'broadcast' : 'user')
        : 'broadcast';

    final types = <String>{
      ..._baseTypes,
      if (typeFromDb.isNotEmpty && !_baseTypes.contains(typeFromDb)) typeFromDb,
    }.toList();

    String type = types.contains(typeFromDb) ? typeFromDb : 'admin_notice';
    String status = _statuses.contains(statusFromDb) ? statusFromDb : 'draft';
    String channel = _channels.contains(channelFromDb) ? channelFromDb : 'push';

    final formKey = GlobalKey<FormState>();

    String? vTitle(String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'العنوان مطلوب', en: 'Title is required');
      }
      if (t.length < 3) {
        return AppText.of(context,
            ar: 'العنوان قصير جداً', en: 'Title is too short');
      }
      if (t.length > 80) {
        return AppText.of(context,
            ar: 'العنوان طويل جداً', en: 'Title is too long');
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
            ar: 'المحتوى قصير جداً', en: 'Body is too short');
      }
      if (t.length > 500) {
        return AppText.of(context,
            ar: 'المحتوى طويل جداً', en: 'Body is too long');
      }
      return null;
    }

    String? vUser(String? v) {
      if (target != 'user') return null;
      final t = (v ?? '').trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'معرف المستخدم مطلوب', en: 'User id is required');
      }
      if (t.length < 3) {
        return AppText.of(context,
            ar: 'معرف المستخدم قصير جداً', en: 'User id is too short');
      }
      return null;
    }

    String? vLot(String? v) {
      if (type != 'nearby_spot_opened') return null;
      final t = (v ?? '').trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'معرف الموقف مطلوب لهذا النوع',
            en: 'Lot id is required for this type');
      }
      return null;
    }

    String? vStall(String? v) {
      if (type != 'nearby_spot_opened') return null;
      final t = (v ?? '').trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'معرف الفراغ مطلوب لهذا النوع',
            en: 'Stall id is required for this type');
      }
      return null;
    }

    String? vSession(String? v) {
      if (type != 'time_expiry') return null;
      final t = (v ?? '').trim();
      if (t.isEmpty) {
        return AppText.of(context,
            ar: 'معرف الجلسة مطلوب لهذا النوع',
            en: 'Session id is required for this type');
      }
      return null;
    }

    final base = Theme.of(context);
    final isDark = base.brightness == Brightness.dark;
    final menuBg = isDark ? AdminColors.darkCard2 : Colors.white;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'notif_editor',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dCtx, a1, a2) {
        final h = MediaQuery.of(dCtx).size.height;
        final w = MediaQuery.of(dCtx).size.width;
        final maxH = min(h * 0.88, 740.0);
        final maxW = min(w - 28, 560.0);
        final narrow = maxW < 520;

        return SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              child: Theme(
                data: base.copyWith(
                  canvasColor: menuBg,
                  popupMenuTheme: PopupMenuThemeData(
                    color: menuBg,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: TextStyle(
                      color: uiText(dCtx),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: maxW,
                        height: maxH,
                        decoration: BoxDecoration(
                          color: uiCard(dCtx).withOpacity(isDark ? 0.92 : 0.98),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: uiBorder(dCtx).withOpacity(0.9),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.28),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: StatefulBuilder(
                          builder: (ctx, setDlg) {
                            Widget fieldGap() => const SizedBox(height: 10);

                            DropdownButtonFormField<String> dd({
                              required String value,
                              required List<String> values,
                              required ValueChanged<String?> onChanged,
                              required String label,
                              required IconData icon,
                            }) {
                              final safeValue =
                                  values.contains(value) ? value : values.first;

                              return DropdownButtonFormField<String>(
                                value: safeValue,
                                isExpanded: true,
                                dropdownColor: menuBg,
                                items: values
                                    .map((x) => DropdownMenuItem(
                                          value: x,
                                          child: Text(
                                            x,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: onChanged,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(icon),
                                  labelText: label,
                                ),
                              );
                            }

                            Widget row2(Widget a, Widget b) {
                              if (narrow) {
                                return Column(
                                  children: [
                                    a,
                                    fieldGap(),
                                    b,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: a),
                                  const SizedBox(width: 10),
                                  Expanded(child: b),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 12, 10, 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isEdit
                                            ? Icons.edit_notifications_outlined
                                            : Icons.add_alert_rounded,
                                        color: AdminColors.primaryGlow,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          isEdit
                                              ? _t('Edit Notification')
                                              : _t('Create Notification'),
                                          style: TextStyle(
                                            color: uiText(ctx),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(),
                                        icon: Icon(Icons.close_rounded,
                                            color: uiSub(ctx)),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  height: 1,
                                  color: uiBorder(ctx).withOpacity(0.9),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        14, 12, 14, 10),
                                    child: Form(
                                      key: formKey,
                                      child: SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            TextFormField(
                                              controller: titleCtrl,
                                              validator: vTitle,
                                              textInputAction:
                                                  TextInputAction.next,
                                              decoration: InputDecoration(
                                                prefixIcon: const Icon(
                                                    Icons.title_rounded),
                                                labelText: _t('Title'),
                                                hintText:
                                                    _t('Short, clear title'),
                                              ),
                                            ),
                                            fieldGap(),
                                            TextFormField(
                                              controller: bodyCtrl,
                                              validator: vBody,
                                              minLines: 3,
                                              maxLines: 6,
                                              decoration: InputDecoration(
                                                prefixIcon: const Icon(
                                                    Icons.notes_rounded),
                                                labelText: _t('Body'),
                                                hintText: _t(
                                                    'Write the message content'),
                                              ),
                                            ),
                                            fieldGap(),
                                            row2(
                                              dd(
                                                value: channel,
                                                values: _channels,
                                                onChanged: (v) => setDlg(() =>
                                                    channel = (v ?? 'push')),
                                                label: _t('Channel'),
                                                icon: Icons.route_outlined,
                                              ),
                                              dd(
                                                value: type,
                                                values: types,
                                                onChanged: (v) => setDlg(() {
                                                  type = (v ?? types.first);
                                                }),
                                                label: _t('Type'),
                                                icon: Icons.category_outlined,
                                              ),
                                            ),
                                            fieldGap(),
                                            row2(
                                              DropdownButtonFormField<String>(
                                                value: target == 'user'
                                                    ? 'user'
                                                    : 'broadcast',
                                                isExpanded: true,
                                                dropdownColor: menuBg,
                                                items: [
                                                  DropdownMenuItem(
                                                      value: 'broadcast',
                                                      child: Text(
                                                        _t('all users'),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      )),
                                                  DropdownMenuItem(
                                                      value: 'user',
                                                      child: Text(
                                                        _t('specific user'),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      )),
                                                ],
                                                onChanged: (v) => setDlg(() =>
                                                    target =
                                                        (v ?? 'broadcast')),
                                                decoration: InputDecoration(
                                                  prefixIcon: const Icon(Icons
                                                      .people_alt_outlined),
                                                  labelText: _t('Target'),
                                                ),
                                              ),
                                              dd(
                                                value: status,
                                                values: _statuses,
                                                onChanged: (v) => setDlg(() =>
                                                    status = (v ?? 'draft')),
                                                label: _t('Status'),
                                                icon: Icons
                                                    .verified_user_outlined,
                                              ),
                                            ),
                                            fieldGap(),
                                            TextFormField(
                                              controller: userCtrl,
                                              validator: vUser,
                                              enabled: target == 'user',
                                              decoration: InputDecoration(
                                                prefixIcon: const Icon(Icons
                                                    .person_outline_rounded),
                                                labelText: _t('User id'),
                                                hintText: target == 'user'
                                                    ? _t('Enter target user id')
                                                    : _t(
                                                        'Disabled (broadcast)'),
                                              ),
                                            ),
                                            fieldGap(),
                                            row2(
                                              TextFormField(
                                                controller: lotCtrl,
                                                validator: vLot,
                                                enabled: type ==
                                                    'nearby_spot_opened',
                                                decoration: InputDecoration(
                                                  prefixIcon: const Icon(
                                                      Icons.map_outlined),
                                                  labelText: _t('Lot id'),
                                                  hintText: type ==
                                                          'nearby_spot_opened'
                                                      ? 'lot_001 ...'
                                                      : AppText.of(context,
                                                          ar: 'اختياري',
                                                          en: 'Optional'),
                                                ),
                                              ),
                                              TextFormField(
                                                controller: stallCtrl,
                                                validator: vStall,
                                                enabled: type ==
                                                    'nearby_spot_opened',
                                                decoration: InputDecoration(
                                                  prefixIcon: const Icon(Icons
                                                      .local_parking_outlined),
                                                  labelText: _t('Stall id'),
                                                  hintText: type ==
                                                          'nearby_spot_opened'
                                                      ? 'stall_001 ...'
                                                      : AppText.of(context,
                                                          ar: 'اختياري',
                                                          en: 'Optional'),
                                                ),
                                              ),
                                            ),
                                            fieldGap(),
                                            TextFormField(
                                              controller: sessionCtrl,
                                              validator: vSession,
                                              enabled: type == 'time_expiry',
                                              decoration: InputDecoration(
                                                prefixIcon: const Icon(
                                                    Icons.timer_outlined),
                                                labelText: _t('Session id'),
                                                hintText: type == 'time_expiry'
                                                    ? 'session_001 ...'
                                                    : AppText.of(context,
                                                        ar: 'اختياري',
                                                        en: 'Optional'),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                _t('Validated before saving.'),
                                                style: TextStyle(
                                                  color: uiSub(ctx),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(),
                                          child: Text(AppText.of(context,
                                              ar: 'إلغاء', en: 'Cancel')),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: () async {
                                            final ok = formKey.currentState
                                                    ?.validate() ??
                                                false;
                                            if (!ok) return;

                                            final title = titleCtrl.text.trim();
                                            final body = bodyCtrl.text.trim();
                                            final userId = target == 'user'
                                                ? userCtrl.text.trim()
                                                : 'all';

                                            final lotId = lotCtrl.text.trim();
                                            final stallId =
                                                stallCtrl.text.trim();
                                            final sessionId =
                                                sessionCtrl.text.trim();

                                            final now = DateTime.now()
                                                .toUtc()
                                                .toIso8601String();
                                            final id = isEdit
                                                ? existingItem?.id ?? ''
                                                : 'notif_${DateTime.now().millisecondsSinceEpoch}';

                                            final payload = <String, dynamic>{
                                              'id': id,
                                              'title': title,
                                              'body': body,
                                              'channel': channel,
                                              'type': type,
                                              'status': status,
                                              'user_id': userId.isEmpty
                                                  ? 'all'
                                                  : userId,
                                              'update_at': now,
                                            };

                                            if (!isEdit) {
                                              payload['create_at'] = now;
                                            } else {
                                              payload['create_at'] = s(
                                                  existingItem?.createAt, now);
                                            }

                                            if (status == 'sent') {
                                              payload['sent_at'] =
                                                  s(existing?.sentAt, now);
                                            }

                                            if (type == 'nearby_spot_opened') {
                                              payload['lot_id'] = lotId;
                                              payload['stall_id'] = stallId;
                                            } else {
                                              if (lotId.isNotEmpty) {
                                                payload['lot_id'] = lotId;
                                              }
                                              if (stallId.isNotEmpty) {
                                                payload['stall_id'] = stallId;
                                              }
                                            }

                                            if (type == 'time_expiry') {
                                              payload['session_id'] = sessionId;
                                            } else {
                                              if (sessionId.isNotEmpty) {
                                                payload['session_id'] =
                                                    sessionId;
                                              }
                                            }

                                            try {
                                              await _db
                                                  .ref('Notification/$id')
                                                  .update(payload);
                                              final openedEmail =
                                                  await _maybeOpenEmailComposer(
                                                channel: channel,
                                                status: status,
                                                title: title,
                                                body: body,
                                                userId: userId.isEmpty
                                                    ? 'all'
                                                    : userId,
                                              );
                                              if (!ctx.mounted) return;
                                              Navigator.of(ctx).pop();
                                              if (!mounted) return;
                                              await showOk(
                                                context,
                                                _t('Saved'),
                                                openedEmail
                                                    ? AppText.of(
                                                        context,
                                                        ar: 'تم حفظ الإشعار وفتح رسالة البريد الإلكتروني.',
                                                        en: 'The notification was saved and the email composer was opened.',
                                                      )
                                                    : isEdit
                                                        ? AppText.of(context,
                                                            ar:
                                                                'تم تحديث الإشعار',
                                                            en:
                                                                'Notification updated')
                                                        : AppText.of(context,
                                                            ar: 'تم إنشاء الإشعار',
                                                            en: 'Notification created'),
                                              );
                                            } catch (e) {
                                              if (!ctx.mounted) return;
                                              await showError(
                                                  ctx, e.toString());
                                            }
                                          },
                                          icon: const Icon(Icons.save_rounded),
                                          label: Text(AppText.of(context,
                                              ar: 'حفظ', en: 'Save')),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, sec, child) {
        final a = Curves.easeOutCubic.transform(anim.value);
        return Transform.scale(
          scale: 0.98 + (0.02 * a),
          child: Opacity(opacity: a, child: child),
        );
      },
    );

    titleCtrl.dispose();
    bodyCtrl.dispose();
    userCtrl.dispose();
    lotCtrl.dispose();
    stallCtrl.dispose();
    sessionCtrl.dispose();
  }

  Future<void> _setStatus(BuildContext context,
      {required String id, required String next}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final currentSnap = await _db.ref('Notification/$id').get();
    final current = mapOf(currentSnap.value);
    final payload = <String, dynamic>{
      'status': next,
      'update_at': now,
    };
    if (next == 'sent') payload['sent_at'] = now;

    try {
      await _db.ref('Notification/$id').update(payload);
      final openedEmail = await _maybeOpenEmailComposer(
        channel: s(current['channel'], 'push'),
        status: next,
        title: s(current['title']),
        body: s(current['body']),
        userId: s(current['user_id'], 'all'),
      );
      if (!mounted) return;
      await showOk(
        context,
        _t('Saved'),
        openedEmail
            ? AppText.of(
                context,
                ar: 'تم تحديث الحالة وفتح رسالة البريد الإلكتروني.',
                en: 'The status was updated and the email composer was opened.',
              )
            : AppText.of(
                context,
                ar: 'تم تحديث الحالة إلى ${_t(next)}',
                en: 'Status updated to $next',
              ),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _duplicateNotif(BuildContext context, _NotifItem n) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = 'notif_${DateTime.now().millisecondsSinceEpoch}';

    final payload = <String, dynamic>{
      'id': id,
      'title': n.title,
      'body': n.body,
      'channel': _channels.contains(s(n.channel, 'push'))
          ? s(n.channel, 'push')
          : 'push',
      'status': 'queued',
      'type': s(n.type, 'admin_notice').isEmpty
          ? 'admin_notice'
          : s(n.type, 'admin_notice'),
      'user_id': s(n.userId, 'all').isEmpty ? 'all' : s(n.userId, 'all'),
      'create_at': now,
      'update_at': now,
    };

    final lotId = s(n.raw['lot_id']);
    final stallId = s(n.raw['stall_id']);
    final sessionId = s(n.raw['session_id']);

    if (lotId.isNotEmpty) payload['lot_id'] = lotId;
    if (stallId.isNotEmpty) payload['stall_id'] = stallId;
    if (sessionId.isNotEmpty) payload['session_id'] = sessionId;

    try {
      await _db.ref('Notification/$id').set(payload);
      if (!mounted) return;
      await showOk(
        context,
        AppText.of(context, ar: 'تم', en: 'Done'),
        AppText.of(context, ar: 'تم النسخ كـ $id', en: 'Duplicated as $id'),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _deleteNotif(BuildContext context, _NotifItem n) async {
    final ok = await _confirm(
      context,
      title:
          AppText.of(context, ar: 'حذف الإشعار؟', en: 'Delete notification?'),
      message: AppText.of(
        context,
        ar: 'سيتم حذف "${n.title.isEmpty ? n.id : n.title}" نهائياً.',
        en: 'This will permanently delete "${n.title.isEmpty ? n.id : n.title}".',
      ),
      danger: true,
      okText: _t('Delete'),
    );
    if (ok != true) return;

    try {
      await _db.ref('Notification/${n.id}').remove();
      if (!mounted) return;
      await showOk(
        context,
        AppText.of(context, ar: 'تم الحذف', en: 'Deleted'),
        AppText.of(context, ar: 'تم حذف الإشعار', en: 'Notification deleted'),
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
                  color: danger ? AdminColors.danger : AdminColors.primaryGlow),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: uiText(ctx), fontWeight: FontWeight.w900)),
            ],
          ),
          content: Text(message,
              style: TextStyle(color: uiSub(ctx), fontWeight: FontWeight.w700)),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(AppText.of(context, ar: 'إلغاء', en: 'Cancel'))),
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

  DateTime _parseTs(String iso) {
    final t = iso.trim();
    if (t.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final d = DateTime.tryParse(t);
    return d ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  IconData _channelIcon(String ch) {
    if (ch == 'email') return Icons.mark_email_read_outlined;
    if (ch == 'in_app') return Icons.app_shortcut_outlined;
    return Icons.notifications_active_outlined;
  }

  Color _statusColor(String st) {
    if (st == 'sent') return AdminColors.success;
    if (st == 'failed') return AdminColors.danger;
    if (st == 'cancelled') return AdminColors.warning;
    if (st == 'draft') return AdminColors.primaryGlow;
    return AdminColors.primary;
  }
}

class _Opt {
  final String id;
  final String label;
  const _Opt(this.id, this.label);
}

class _NotifItem {
  final String key;
  final String id;
  final String title;
  final String body;
  final String channel;
  final String status;
  final String type;
  final String userId;
  final String createAt;
  final String updateAt;
  final String sentAt;
  final Map<String, dynamic> raw;

  const _NotifItem({
    required this.key,
    required this.id,
    required this.title,
    required this.body,
    required this.channel,
    required this.status,
    required this.type,
    required this.userId,
    required this.createAt,
    required this.updateAt,
    required this.sentAt,
    required this.raw,
  });
}
