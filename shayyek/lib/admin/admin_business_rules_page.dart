import 'dart:ui';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_text.dart';
import 'admin_audit_logs_page.dart';
import 'admin_analytics_page.dart';
import 'admin_announcements_page.dart';
import 'admin_l10n.dart';
import 'admin_notifications_page.dart';
import 'admin_theme.dart';
import 'admin_utils.dart';
import 'admin_widgets.dart';

class AdminBusinessRulesPage extends StatefulWidget {
  const AdminBusinessRulesPage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<AdminBusinessRulesPage> createState() => _AdminBusinessRulesPageState();
}

class _AdminBusinessRulesPageState extends State<AdminBusinessRulesPage> {
  final _db = FirebaseDatabase.instance;
  Key _reloadKey = UniqueKey();

  void _reload() => setState(() => _reloadKey = UniqueKey());

  String _t(String text) => adminL10n(context, text);

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      title: _t('Business Rules'),
      isDarkMode: widget.isDarkMode,
      onToggleTheme: widget.onToggleTheme,
      child: StreamBuilder<DatabaseEvent>(
        key: _reloadKey,
        stream: _db.ref('business_rules/rules_001').onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) return errorBox(context, _reload);
          if (!snapshot.hasData) return loadingBox(context);

          final m = mapOf(snapshot.data!.snapshot.value);
          final alert = mapOf(m['alert_policies']);
          final privacy = mapOf(m['privacy_redaction']);
          final retention = mapOf(m['retention_windows']);

          final minConfidence = toDouble(m['min_confidence']);
          final debounceMs = toInt(m['debounce_ms']);
          final fallbackMode = s(m['fallback_mode']);

          return Stack(
            children: [
              const _RulesBackdrop(),
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  _OpsHeaderCard(
                    onOpenOps: () => _openOpsSheet(
                      rules: m,
                      alert: alert,
                      privacy: privacy,
                      retention: retention,
                    ),
                    onRefresh: _reload,
                    onToggleTheme: widget.onToggleTheme,
                    onGoAnalytics: () => _open(
                      context,
                      AdminAnalyticsPage(
                        isDarkMode: widget.isDarkMode,
                        onToggleTheme: widget.onToggleTheme,
                      ),
                    ),
                    onGoAlerts: () => _open(
                      context,
                      AdminNotificationsPage(
                        isDarkMode: widget.isDarkMode,
                        onToggleTheme: widget.onToggleTheme,
                      ),
                    ),
                    onGoAudit: () => _open(
                      context,
                      AdminAuditLogsPage(
                        isDarkMode: widget.isDarkMode,
                        onToggleTheme: widget.onToggleTheme,
                      ),
                    ),
                    onGoAnnouncements: () => _open(
                      context,
                      AdminAnnouncementsPage(
                        isDarkMode: widget.isDarkMode,
                        onToggleTheme: widget.onToggleTheme,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StatsStrip(
                    minConfidence: minConfidence,
                    debounceMs: debounceMs,
                    fallbackMode: fallbackMode,
                  ),
                  const SizedBox(height: 12),
                  _RuleSectionCard(
                    title: _t('Core Thresholds'),
                    subtitle: _t(
                        'Tune detection confidence, debounce, and fallback behavior'),
                    icon: Icons.tune_rounded,
                    child: Column(
                      children: [
                        _RuleValueTile(
                          icon: Icons.verified_outlined,
                          title: _t('Min confidence'),
                          subtitle:
                              _t('Lower is more sensitive, higher is stricter'),
                          value: minConfidence.isFinite
                              ? minConfidence.toStringAsFixed(2)
                              : '—',
                          onTap: () => _editDouble(
                            'business_rules/rules_001/min_confidence',
                            minConfidence,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _RuleValueTile(
                          icon: Icons.timelapse_rounded,
                          title: _t('Debounce (ms)'),
                          subtitle:
                              _t('Avoid repeated triggers in a short window'),
                          value: '$debounceMs',
                          onTap: () => _editNumber(
                            'business_rules/rules_001/debounce_ms',
                            debounceMs,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _RuleValueTile(
                          icon: Icons.swap_horiz_rounded,
                          title: _t('Fallback mode'),
                          subtitle:
                              _t('Strategy used when signals are uncertain'),
                          value: fallbackMode.isEmpty ? '—' : fallbackMode,
                          onTap: () => _editText(
                            'business_rules/rules_001/fallback_mode',
                            fallbackMode,
                            title: _t('Edit fallback mode'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _RuleSectionCard(
                    title: _t('Alert Policies'),
                    subtitle: _t('Control when notifications are triggered'),
                    icon: Icons.notifications_active_outlined,
                    trailing: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _bulkUpdate(
                            'business_rules/rules_001',
                            <String, dynamic>{
                              'alert_policies/nearby_spot_open': true,
                            },
                          ),
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: Text(_t('Enable')),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _bulkUpdate(
                            'business_rules/rules_001',
                            <String, dynamic>{
                              'alert_policies/nearby_spot_open': false,
                            },
                          ),
                          icon: const Icon(Icons.notifications_off_outlined),
                          label: Text(_t('Disable')),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _RuleToggleTile(
                          icon: Icons.near_me_outlined,
                          title: _t('Nearby spot open'),
                          subtitle:
                              _t('Notify when a nearby spot becomes available'),
                          value: toBool(alert['nearby_spot_open']),
                          onChanged: (v) => _setNoDialog(
                            'business_rules/rules_001/alert_policies/nearby_spot_open',
                            v,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _RuleValueTile(
                          icon: Icons.timer_outlined,
                          title: _t('Time expire before (min)'),
                          subtitle:
                              _t('Notify before a parking window expires'),
                          value: '${toInt(alert['time_expire_before_min'])}',
                          onTap: () => _editNumber(
                            'business_rules/rules_001/alert_policies/time_expire_before_min',
                            toInt(alert['time_expire_before_min']),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _RuleValueTile(
                          icon: Icons.videocam_off_outlined,
                          title: _t('Camera offline after (sec)'),
                          subtitle:
                              _t('Mark camera as offline after no heartbeat'),
                          value: '${toInt(alert['camera_offline_after_sec'])}',
                          onTap: () => _editNumber(
                            'business_rules/rules_001/alert_policies/camera_offline_after_sec',
                            toInt(alert['camera_offline_after_sec']),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _RuleSectionCard(
                    title: _t('Privacy Redaction'),
                    subtitle: _t('Apply blur policies to protect user privacy'),
                    icon: Icons.privacy_tip_outlined,
                    trailing: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _bulkUpdate(
                            'business_rules/rules_001',
                            <String, dynamic>{
                              'privacy_redaction/blur_faces': true,
                              'privacy_redaction/blur_plates': true,
                            },
                          ),
                          icon: const Icon(Icons.visibility_off_outlined),
                          label: Text(_t('Max')),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _bulkUpdate(
                            'business_rules/rules_001',
                            <String, dynamic>{
                              'privacy_redaction/blur_faces': false,
                              'privacy_redaction/blur_plates': false,
                            },
                          ),
                          icon: const Icon(Icons.visibility_outlined),
                          label: Text(_t('Off')),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _RuleToggleTile(
                          icon: Icons.face_retouching_off_outlined,
                          title: _t('Blur faces'),
                          subtitle: _t('Mask faces in captured frames'),
                          value: toBool(privacy['blur_faces']),
                          onChanged: (v) => _setNoDialog(
                            'business_rules/rules_001/privacy_redaction/blur_faces',
                            v,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _RuleToggleTile(
                          icon: Icons.directions_car_outlined,
                          title: _t('Blur plates'),
                          subtitle:
                              _t('Mask license plates in captured frames'),
                          value: toBool(privacy['blur_plates']),
                          onChanged: (v) => _setNoDialog(
                            'business_rules/rules_001/privacy_redaction/blur_plates',
                            v,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _RuleSectionCard(
                    title: _t('Retention Windows'),
                    subtitle: _t('Define how long logs and telemetry are kept'),
                    icon: Icons.schedule_outlined,
                    child: Column(
                      children: [
                        _RuleValueTile(
                          icon: Icons.fact_check_outlined,
                          title: _t('Audit logs (days)'),
                          subtitle: _t('How long admin actions are stored'),
                          value: '${toInt(retention['audit_logs_days'])}',
                          onTap: () => _editNumber(
                            'business_rules/rules_001/retention_windows/audit_logs_days',
                            toInt(retention['audit_logs_days']),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _RuleValueTile(
                          icon: Icons.monitor_heart_outlined,
                          title: _t('Camera health (days)'),
                          subtitle: _t('How long health metrics are stored'),
                          value: '${toInt(retention['camera_health_days'])}',
                          onTap: () => _editNumber(
                            'business_rules/rules_001/retention_windows/camera_health_days',
                            toInt(retention['camera_health_days']),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _RuleValueTile(
                          icon: Icons.local_parking_outlined,
                          title: _t('Stall history (days)'),
                          subtitle:
                              _t('How long stall occupancy history is stored'),
                          value: '${toInt(retention['stall_history_days'])}',
                          onTap: () => _editNumber(
                            'business_rules/rules_001/retention_windows/stall_history_days',
                            toInt(retention['stall_history_days']),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _RuleSectionCard(
                    title: _t('Utilities'),
                    subtitle: _t('Quick actions for admins'),
                    icon: Icons.build_outlined,
                    child: Column(
                      children: [
                        _RuleActionTile(
                          icon: Icons.copy_all_rounded,
                          title: _t('Copy rules (JSON)'),
                          subtitle: _t('Share or store current configuration'),
                          onTap: () => _copyRulesJson(
                            rules: m,
                            alert: alert,
                            privacy: privacy,
                            retention: retention,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _RuleActionTile(
                          icon: Icons.refresh_rounded,
                          title: _t('Refresh from Firebase'),
                          subtitle:
                              _t('Reload and re-render the latest values'),
                          onTap: _reload,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  void _openOpsSheet({
    required Map<String, dynamic> rules,
    required Map<String, dynamic> alert,
    required Map<String, dynamic> privacy,
    required Map<String, dynamic> retention,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final minConfidence = toDouble(rules['min_confidence']);
            final debounceMs = toInt(rules['debounce_ms']);
            final fallbackMode = s(rules['fallback_mode']);

            final nearbyOpen = toBool(alert['nearby_spot_open']);
            final expireMin = toInt(alert['time_expire_before_min']);
            final cameraOffSec = toInt(alert['camera_offline_after_sec']);

            final blurFaces = toBool(privacy['blur_faces']);
            final blurPlates = toBool(privacy['blur_plates']);

            final auditDays = toInt(retention['audit_logs_days']);
            final healthDays = toInt(retention['camera_health_days']);
            final stallDays = toInt(retention['stall_history_days']);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: (dark ? AdminColors.darkCard2 : Colors.white)
                            .withOpacity(dark ? .84 : .98),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: uiBorder(context).withOpacity(.85)),
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
                            padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                            child: Row(
                              children: [
                                Text(
                                  _t('Admin Operations'),
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
                          Flexible(
                            child: ListView(
                              shrinkWrap: true,
                              padding:
                                  const EdgeInsets.fromLTRB(12, 12, 12, 14),
                              children: [
                                _opsSectionTitle(_t('Quick')),
                                _opsTile(
                                  icon: Icons.refresh_rounded,
                                  title: _t('Refresh data'),
                                  subtitle:
                                      _t('Reload business rules from Firebase'),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    _reload();
                                  },
                                ),
                                _opsTile(
                                  icon: Icons.copy_all_rounded,
                                  title: _t('Copy rules (JSON)'),
                                  subtitle:
                                      _t('Copy current rules to clipboard'),
                                  onTap: () async {
                                    Navigator.of(ctx).pop();
                                    await _copyRulesJson(
                                      rules: rules,
                                      alert: alert,
                                      privacy: privacy,
                                      retention: retention,
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                _opsSectionTitle(_t('Core rules')),
                                _opsValueTile(
                                  icon: Icons.verified_outlined,
                                  label: _t('Min confidence'),
                                  value: minConfidence.isFinite
                                      ? minConfidence.toStringAsFixed(2)
                                      : '—',
                                  onTap: () async {
                                    Navigator.of(ctx).pop();
                                    await _editDouble(
                                        'business_rules/rules_001/min_confidence',
                                        minConfidence);
                                  },
                                ),
                                _opsValueTile(
                                  icon: Icons.timelapse_rounded,
                                  label: _t('Debounce (ms)'),
                                  value: '$debounceMs',
                                  onTap: () async {
                                    Navigator.of(ctx).pop();
                                    await _editNumber(
                                        'business_rules/rules_001/debounce_ms',
                                        debounceMs);
                                  },
                                ),
                                _opsValueTile(
                                  icon: Icons.swap_horiz_rounded,
                                  label: _t('Fallback mode'),
                                  value:
                                      fallbackMode.isEmpty ? '—' : fallbackMode,
                                  onTap: () async {
                                    Navigator.of(ctx).pop();
                                    await _editText(
                                      'business_rules/rules_001/fallback_mode',
                                      fallbackMode,
                                      title: _t('Edit fallback mode'),
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                _opsSectionTitle(_t('Alert policies')),
                                _opsSwitch(
                                  icon: Icons.notifications_active_outlined,
                                  label: _t('Nearby spot open'),
                                  value: nearbyOpen,
                                  onChanged: (v) async {
                                    setLocal(
                                        () => alert['nearby_spot_open'] = v);
                                    await _setNoDialog(
                                      'business_rules/rules_001/alert_policies/nearby_spot_open',
                                      v,
                                    );
                                  },
                                ),
                                _opsValueTile(
                                  icon: Icons.timer_outlined,
                                  label: _t('Expire before (min)'),
                                  value: '$expireMin',
                                  onTap: () async {
                                    Navigator.of(ctx).pop();
                                    await _editNumber(
                                      'business_rules/rules_001/alert_policies/time_expire_before_min',
                                      expireMin,
                                    );
                                  },
                                ),
                                _opsValueTile(
                                  icon: Icons.videocam_off_outlined,
                                  label: _t('Camera offline after (sec)'),
                                  value: '$cameraOffSec',
                                  onTap: () async {
                                    Navigator.of(ctx).pop();
                                    await _editNumber(
                                      'business_rules/rules_001/alert_policies/camera_offline_after_sec',
                                      cameraOffSec,
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                _opsSectionTitle(_t('Privacy')),
                                _opsSwitch(
                                  icon: Icons.face_retouching_off_outlined,
                                  label: _t('Blur faces'),
                                  value: blurFaces,
                                  onChanged: (v) async {
                                    setLocal(() => privacy['blur_faces'] = v);
                                    await _setNoDialog(
                                      'business_rules/rules_001/privacy_redaction/blur_faces',
                                      v,
                                    );
                                  },
                                ),
                                _opsSwitch(
                                  icon: Icons.directions_car_outlined,
                                  label: _t('Blur plates'),
                                  value: blurPlates,
                                  onChanged: (v) async {
                                    setLocal(() => privacy['blur_plates'] = v);
                                    await _setNoDialog(
                                      'business_rules/rules_001/privacy_redaction/blur_plates',
                                      v,
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                _opsSectionTitle(_t('Retention')),
                                _opsValueTile(
                                  icon: Icons.fact_check_outlined,
                                  label: _t('Audit logs (days)'),
                                  value: '$auditDays',
                                  onTap: () async {
                                    Navigator.of(ctx).pop();
                                    await _editNumber(
                                      'business_rules/rules_001/retention_windows/audit_logs_days',
                                      auditDays,
                                    );
                                  },
                                ),
                                _opsValueTile(
                                  icon: Icons.monitor_heart_outlined,
                                  label: _t('Camera health (days)'),
                                  value: '$healthDays',
                                  onTap: () async {
                                    Navigator.of(ctx).pop();
                                    await _editNumber(
                                      'business_rules/rules_001/retention_windows/camera_health_days',
                                      healthDays,
                                    );
                                  },
                                ),
                                _opsValueTile(
                                  icon: Icons.local_parking_outlined,
                                  label: _t('Stall history (days)'),
                                  value: '$stallDays',
                                  onTap: () async {
                                    Navigator.of(ctx).pop();
                                    await _editNumber(
                                      'business_rules/rules_001/retention_windows/stall_history_days',
                                      stallDays,
                                    );
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
      },
    );
  }

  Future<void> _set(String path, dynamic value) async {
    try {
      await _db.ref(path).set(value);
      if (!mounted) return;
      await showOk(
        context,
        _t('Saved'),
        AppText.of(
          context,
          ar: 'تم تحديث قاعدة العمل',
          en: 'Business rule updated',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _setNoDialog(String path, dynamic value) async {
    try {
      await _db.ref(path).set(value);
      if (!mounted) return;
      _snack(_t('Saved'));
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _bulkUpdate(
      String basePath, Map<String, dynamic> updates) async {
    try {
      await _db.ref(basePath).update(updates);
      if (!mounted) return;
      _snack(_t('Saved'));
      _reload();
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  Future<void> _editNumber(String path, int current) async {
    final c = TextEditingController(text: '$current');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: uiCard(context),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.edit_outlined, color: AdminColors.primaryGlow),
            const SizedBox(width: 8),
            Text(AppText.of(context, ar: 'تعديل القيمة', en: 'Edit value'),
                style: TextStyle(
                    color: uiText(context), fontWeight: FontWeight.w900)),
          ],
        ),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: _t('Number')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppText.of(context, ar: 'إلغاء', en: 'Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppText.of(context, ar: 'حفظ', en: 'Save'))),
        ],
      ),
    );
    if (ok != true) return;
    await _set(path, int.tryParse(c.text.trim()) ?? current);
    _reload();
  }

  Future<void> _editDouble(String path, double current) async {
    final c = TextEditingController(text: current.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: uiCard(context),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.verified_outlined, color: AdminColors.primaryGlow),
            const SizedBox(width: 8),
            Text(
                AppText.of(context,
                    ar: 'تعديل أقل ثقة', en: 'Edit min confidence'),
                style: TextStyle(
                    color: uiText(context), fontWeight: FontWeight.w900)),
          ],
        ),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText:
                AppText.of(context, ar: 'القيمة (0-1)', en: 'Value (0-1)'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppText.of(context, ar: 'إلغاء', en: 'Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppText.of(context, ar: 'حفظ', en: 'Save'))),
        ],
      ),
    );
    if (ok != true) return;
    var v = double.tryParse(c.text.trim()) ?? current;
    if (v < 0) v = 0;
    if (v > 1) v = 1;
    await _set(path, v);
    _reload();
  }

  Future<void> _editText(String path, String current,
      {required String title}) async {
    final c = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: uiCard(context),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.swap_horiz_rounded,
                color: AdminColors.primaryGlow),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: uiText(context), fontWeight: FontWeight.w900))),
          ],
        ),
        content: TextField(
          controller: c,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: _t('Value')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppText.of(context, ar: 'إلغاء', en: 'Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppText.of(context, ar: 'حفظ', en: 'Save'))),
        ],
      ),
    );
    if (ok != true) return;
    await _set(path, c.text.trim());
    _reload();
  }

  Future<void> _copyRulesJson({
    required Map<String, dynamic> rules,
    required Map<String, dynamic> alert,
    required Map<String, dynamic> privacy,
    required Map<String, dynamic> retention,
  }) async {
    final txt = _prettyRules(
        rules: rules, alert: alert, privacy: privacy, retention: retention);
    await Clipboard.setData(ClipboardData(text: txt));
    if (!mounted) return;
    _snack(AppText.of(context, ar: 'تم النسخ', en: 'Copied'));
  }

  String _prettyRules({
    required Map<String, dynamic> rules,
    required Map<String, dynamic> alert,
    required Map<String, dynamic> privacy,
    required Map<String, dynamic> retention,
  }) {
    final mc = toDouble(rules['min_confidence']);
    final db = toInt(rules['debounce_ms']);
    final fb = s(rules['fallback_mode']);

    final n = toBool(alert['nearby_spot_open']);
    final e = toInt(alert['time_expire_before_min']);
    final o = toInt(alert['camera_offline_after_sec']);

    final bf = toBool(privacy['blur_faces']);
    final bp = toBool(privacy['blur_plates']);

    final ad = toInt(retention['audit_logs_days']);
    final hd = toInt(retention['camera_health_days']);
    final sd = toInt(retention['stall_history_days']);

    return '{\n'
        '  "min_confidence": ${mc.toStringAsFixed(6)},\n'
        '  "debounce_ms": $db,\n'
        '  "fallback_mode": "${fb.replaceAll('"', '\\"')}",\n'
        '  "alert_policies": {\n'
        '    "nearby_spot_open": $n,\n'
        '    "time_expire_before_min": $e,\n'
        '    "camera_offline_after_sec": $o\n'
        '  },\n'
        '  "privacy_redaction": {\n'
        '    "blur_faces": $bf,\n'
        '    "blur_plates": $bp\n'
        '  },\n'
        '  "retention_windows": {\n'
        '    "audit_logs_days": $ad,\n'
        '    "camera_health_days": $hd,\n'
        '    "stall_history_days": $sd\n'
        '  }\n'
        '}';
  }

  Widget _opsSectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        t,
        style: TextStyle(
          color: uiSub(context),
          fontWeight: FontWeight.w900,
          fontSize: 12.5,
          letterSpacing: .2,
        ),
      ),
    );
  }

  Widget _opsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.fromLTRB(2, 6, 2, 6),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: (dark ? AdminColors.darkCard : Colors.white)
              .withOpacity(dark ? .82 : 1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: uiBorder(context)),
        ),
        child: Row(
          children: [
            _IconOrb(icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: uiText(context),
                          fontWeight: FontWeight.w900,
                          fontSize: 13.6)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: uiSub(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: uiSub(context)),
          ],
        ),
      ),
    );
  }

  Widget _opsValueTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.fromLTRB(2, 6, 2, 6),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: (dark ? AdminColors.darkCard : Colors.white)
              .withOpacity(dark ? .82 : 1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: uiBorder(context)),
        ),
        child: Row(
          children: [
            _IconOrb(icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: uiText(context),
                          fontWeight: FontWeight.w900,
                          fontSize: 13.2)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          color: uiSub(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.edit_outlined, color: uiSub(context)),
          ],
        ),
      ),
    );
  }

  Widget _opsSwitch({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 6, 2, 6),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: (dark ? AdminColors.darkCard : Colors.white)
            .withOpacity(dark ? .82 : 1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: uiBorder(context)),
      ),
      child: Row(
        children: [
          _IconOrb(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  color: uiText(context),
                  fontWeight: FontWeight.w900,
                  fontSize: 13.2),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _RulesBackdrop extends StatelessWidget {
  const _RulesBackdrop();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AdminColors.primary.withOpacity(dark ? .10 : .08),
                    Colors.transparent,
                    AdminColors.primaryGlow.withOpacity(dark ? .10 : .07),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -40,
            right: -30,
            child: _GlowBlob(
              size: 180,
              color: AdminColors.primaryGlow.withOpacity(dark ? .20 : .16),
            ),
          ),
          Positioned(
            bottom: 60,
            left: -40,
            child: _GlowBlob(
              size: 220,
              color: AdminColors.primary.withOpacity(dark ? .16 : .12),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color),
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.minConfidence,
    required this.debounceMs,
    required this.fallbackMode,
  });

  final double minConfidence;
  final int debounceMs;
  final String fallbackMode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final isNarrow = c.maxWidth < 720;

        final cards = [
          StatCard(
            title: adminL10n(context, 'Min confidence'),
            value:
                minConfidence.isFinite ? minConfidence.toStringAsFixed(2) : '—',
            icon: Icons.verified_outlined,
            color: AdminColors.primary,
          ),
          StatCard(
            title: adminL10n(context, 'Debounce (ms)'),
            value: '$debounceMs ms',
            icon: Icons.timelapse_rounded,
            color: AdminColors.warning,
          ),
          StatCard(
            title: adminL10n(context, 'Fallback mode'),
            value: fallbackMode.isEmpty ? '—' : fallbackMode,
            icon: Icons.swap_horiz_rounded,
            color: AdminColors.success,
          ),
        ];

        if (!isNarrow) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 10),
              Expanded(child: cards[1]),
              const SizedBox(width: 10),
              Expanded(child: cards[2]),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cards[0],
            const SizedBox(height: 10),
            cards[1],
            const SizedBox(height: 10),
            cards[2],
          ],
        );
      },
    );
  }
}

class _RuleSectionCard extends StatelessWidget {
  const _RuleSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            color: (dark ? AdminColors.darkCard2 : Colors.white)
                .withOpacity(dark ? .72 : .96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: uiBorder(context).withOpacity(.9)),
            boxShadow: [
              BoxShadow(
                blurRadius: 22,
                offset: const Offset(0, 12),
                color: Colors.black.withOpacity(dark ? .26 : .08),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _IconOrb(icon: icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(adminL10n(context, title),
                            style: TextStyle(
                                color: uiText(context),
                                fontWeight: FontWeight.w900,
                                fontSize: 14.8)),
                        const SizedBox(height: 2),
                        Text(adminL10n(context, subtitle),
                            style: TextStyle(
                                color: uiSub(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              if (trailing != null) ...[
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: trailing!),
              ],
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleToggleTile extends StatelessWidget {
  const _RuleToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: uiCard(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: uiBorder(context)),
      ),
      child: Row(
        children: [
          _IconOrb(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(adminL10n(context, title),
                    style: TextStyle(
                        color: uiText(context),
                        fontWeight: FontWeight.w900,
                        fontSize: 13.6)),
                const SizedBox(height: 2),
                Text(adminL10n(context, subtitle),
                    style: TextStyle(
                        color: uiSub(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _RuleValueTile extends StatelessWidget {
  const _RuleValueTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: uiCard(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: uiBorder(context)),
        ),
        child: Row(
          children: [
            _IconOrb(icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(adminL10n(context, title),
                      style: TextStyle(
                          color: uiText(context),
                          fontWeight: FontWeight.w900,
                          fontSize: 13.6)),
                  const SizedBox(height: 2),
                  Text(adminL10n(context, subtitle),
                      style: TextStyle(
                          color: uiSub(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _ValuePill(value: value),
            const SizedBox(width: 8),
            Icon(Icons.edit_outlined, color: uiSub(context)),
          ],
        ),
      ),
    );
  }
}

class _RuleActionTile extends StatelessWidget {
  const _RuleActionTile({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: uiCard(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: uiBorder(context)),
        ),
        child: Row(
          children: [
            _IconOrb(icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(adminL10n(context, title),
                      style: TextStyle(
                          color: uiText(context),
                          fontWeight: FontWeight.w900,
                          fontSize: 13.6)),
                  const SizedBox(height: 2),
                  Text(adminL10n(context, subtitle),
                      style: TextStyle(
                          color: uiSub(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
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

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: (dark ? AdminColors.darkCard2 : const Color(0xFFF2F7FE)),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: uiBorder(context)),
      ),
      child: Text(
        value.isEmpty ? '—' : value,
        style: TextStyle(
          color: uiText(context),
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _IconOrb extends StatelessWidget {
  const _IconOrb({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AdminColors.primary.withOpacity(dark ? .14 : .10),
        border: Border.all(
            color: AdminColors.primary.withOpacity(dark ? .26 : .20)),
      ),
      child: Icon(icon,
          size: 20,
          color: dark ? AdminColors.primaryGlow : AdminColors.primary),
    );
  }
}

class _OpsHeaderCard extends StatelessWidget {
  const _OpsHeaderCard({
    required this.onOpenOps,
    required this.onRefresh,
    required this.onToggleTheme,
    required this.onGoAnalytics,
    required this.onGoAlerts,
    required this.onGoAudit,
    required this.onGoAnnouncements,
  });

  final VoidCallback onOpenOps;
  final VoidCallback onRefresh;
  final VoidCallback onToggleTheme;
  final VoidCallback onGoAnalytics;
  final VoidCallback onGoAlerts;
  final VoidCallback onGoAudit;
  final VoidCallback onGoAnnouncements;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: (dark ? AdminColors.darkCard2 : Colors.white)
                .withOpacity(dark ? .72 : .95),
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
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AdminColors.primary.withOpacity(.12),
                      border: Border.all(
                          color: AdminColors.primary.withOpacity(.22)),
                    ),
                    child: Icon(Icons.tune_rounded,
                        color: dark
                            ? AdminColors.primaryGlow
                            : AdminColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adminL10n(context, 'Admin Operations'),
                          style: TextStyle(
                            color: uiText(context),
                            fontWeight: FontWeight.w900,
                            fontSize: 15.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppText.of(
                            context,
                            ar: 'إدارة القواعد والخصوصية والتنبيهات وفترات الاحتفاظ',
                            en: 'Manage rules, privacy, alerts, and retention',
                          ),
                          style: TextStyle(
                            color: uiSub(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SmallIcon(icon: Icons.refresh_rounded, onTap: onRefresh),
                  const SizedBox(width: 8),
                  _SmallIcon(icon: Icons.menu_rounded, onTap: onOpenOps),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _ChipBtn(
                          icon: Icons.analytics_outlined,
                          label: adminL10n(context, 'Analytics'),
                          onTap: onGoAnalytics)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _ChipBtn(
                          icon: Icons.notifications_active_outlined,
                          label: adminL10n(context, 'Alert Policies'),
                          onTap: onGoAlerts)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _ChipBtn(
                          icon: Icons.fact_check_outlined,
                          label:
                              AppText.of(context, ar: 'التدقيق', en: 'Audit'),
                          onTap: onGoAudit)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _ChipBtn(
                          icon: Icons.campaign_outlined,
                          label: AppText.of(context,
                              ar: 'الإعلانات', en: 'Announce'),
                          onTap: onGoAnnouncements)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallIcon extends StatelessWidget {
  const _SmallIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(dark ? .06 : .10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: uiBorder(context).withOpacity(.85)),
        ),
        child: Icon(icon, color: uiSub(context)),
      ),
    );
  }
}

class _ChipBtn extends StatelessWidget {
  const _ChipBtn(
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: dark ? AdminColors.primaryGlow : AdminColors.primary),
            const SizedBox(width: 8),
            Text(
              adminL10n(context, label),
              style: TextStyle(
                color: uiText(context),
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
