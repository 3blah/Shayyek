import 'package:flutter/material.dart';

import '../app_text.dart';
import 'admin_l10n.dart';
import 'admin_theme.dart';
import 'admin_utils.dart';

class AdminPageFrame extends StatelessWidget {
  const AdminPageFrame({
    super.key,
    required this.title,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.child,
    this.actions = const [],
    this.bottom,
    this.subtitle,
    this.header,
    this.onRefresh,
    this.onCreate,
    this.onExport,
    this.onOpenFilters,
    this.onOpenSearch,
    this.onHelp,
    this.onBulk,
    this.showToolbar = true,
    this.primaryActionLabel = 'Create',
    this.exportLabel = 'Export',
  });

  final String title;
  final String? subtitle;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final Widget child;
  final List<Widget> actions;
  final Widget? bottom;

  final Widget? header;

  final VoidCallback? onRefresh;
  final VoidCallback? onCreate;
  final VoidCallback? onExport;
  final VoidCallback? onOpenFilters;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onHelp;
  final VoidCallback? onBulk;

  final bool showToolbar;
  final String primaryActionLabel;
  final String exportLabel;

  bool get _hasToolbar =>
      showToolbar &&
      (subtitle != null ||
          header != null ||
          onRefresh != null ||
          onCreate != null ||
          onExport != null ||
          onOpenFilters != null ||
          onOpenSearch != null ||
          onHelp != null ||
          onBulk != null);

  @override
  Widget build(BuildContext context) {
    final _ = onToggleTheme;
    final searchLabel = AppText.of(context, ar: 'بحث', en: 'Search');
    final filtersLabel = AppText.of(context, ar: 'فلاتر', en: 'Filters');
    final refreshLabel = AppText.of(context, ar: 'تحديث', en: 'Refresh');
    final createLabel = primaryActionLabel == 'Create'
        ? AppText.of(context, ar: 'إنشاء', en: 'Create')
        : primaryActionLabel;
    final resolvedExportLabel = exportLabel == 'Export'
        ? AppText.of(context, ar: 'تصدير', en: 'Export')
        : exportLabel;
    final appbarActions = <Widget>[
      if (onOpenSearch != null)
        IconButton(
          tooltip: searchLabel,
          onPressed: onOpenSearch,
          icon: const Icon(Icons.search_rounded),
        ),
      if (onOpenFilters != null)
        IconButton(
          tooltip: filtersLabel,
          onPressed: onOpenFilters,
          icon: const Icon(Icons.tune_rounded),
        ),
      if (onRefresh != null)
        IconButton(
          tooltip: refreshLabel,
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      if (onCreate != null)
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: Text(createLabel),
          ),
        ),
      ...actions,
      if (_hasOverflow)
        _OverflowMenu(
          onRefresh: onRefresh,
          onCreate: onCreate,
          onExport: onExport,
          onOpenFilters: onOpenFilters,
          onOpenSearch: onOpenSearch,
          onHelp: onHelp,
          onBulk: onBulk,
          createLabel: createLabel,
          exportLabel: resolvedExportLabel,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(adminL10n(context, title)),
        actions: appbarActions,
      ),
      body: SafeArea(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_hasToolbar) ...[
                AdminToolbar(
                  title: title,
                  subtitle: subtitle,
                  header: header,
                  onCreate: onCreate,
                  onExport: onExport,
                  onRefresh: onRefresh,
                  onOpenFilters: onOpenFilters,
                  onOpenSearch: onOpenSearch,
                  onHelp: onHelp,
                  onBulk: onBulk,
                  createLabel: createLabel,
                  exportLabel: resolvedExportLabel,
                ),
                const SizedBox(height: 12),
              ],
              Expanded(child: child),
            ],
          ),
        ),
      ),
      bottomNavigationBar: bottom,
    );
  }

  bool get _hasOverflow {
    final topIconsCount = (onOpenSearch != null ? 1 : 0) +
        (onOpenFilters != null ? 1 : 0) +
        (onRefresh != null ? 1 : 0);
    return (onExport != null) ||
        (onHelp != null) ||
        (onBulk != null) ||
        (topIconsCount > 0);
  }
}

class AdminToolbar extends StatelessWidget {
  const AdminToolbar({
    super.key,
    required this.title,
    this.subtitle,
    this.header,
    this.onRefresh,
    this.onCreate,
    this.onExport,
    this.onOpenFilters,
    this.onOpenSearch,
    this.onHelp,
    this.onBulk,
    this.createLabel = 'Create',
    this.exportLabel = 'Export',
  });

  final String title;
  final String? subtitle;
  final Widget? header;

  final VoidCallback? onRefresh;
  final VoidCallback? onCreate;
  final VoidCallback? onExport;
  final VoidCallback? onOpenFilters;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onHelp;
  final VoidCallback? onBulk;

  final String createLabel;
  final String exportLabel;

  @override
  Widget build(BuildContext context) {
    final searchLabel = AppText.of(context, ar: 'بحث', en: 'Search');
    final filtersLabel = AppText.of(context, ar: 'فلاتر', en: 'Filters');
    final refreshLabel = AppText.of(context, ar: 'تحديث', en: 'Refresh');
    final bulkLabel = AppText.of(context, ar: 'تجميعي', en: 'Bulk');
    final helpLabel = AppText.of(context, ar: 'مساعدة', en: 'Help');
    final buttons = <Widget>[
      if (onOpenSearch != null)
        _ToolbarPill(
          icon: Icons.search_rounded,
          text: searchLabel,
          onTap: onOpenSearch!,
        ),
      if (onOpenFilters != null)
        _ToolbarPill(
          icon: Icons.tune_rounded,
          text: filtersLabel,
          onTap: onOpenFilters!,
        ),
      if (onRefresh != null)
        _ToolbarPill(
          icon: Icons.refresh_rounded,
          text: refreshLabel,
          onTap: onRefresh!,
        ),
      if (onBulk != null)
        _ToolbarPill(
          icon: Icons.checklist_rounded,
          text: bulkLabel,
          onTap: onBulk!,
        ),
      if (onExport != null)
        _ToolbarPill(
          icon: Icons.ios_share_rounded,
          text: exportLabel,
          onTap: onExport!,
        ),
      if (onHelp != null)
        _ToolbarPill(
          icon: Icons.help_outline_rounded,
          text: helpLabel,
          onTap: onHelp!,
        ),
    ];

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
              CircleAvatar(
                radius: 18,
                backgroundColor: AdminColors.primary.withOpacity(.14),
                child: const Icon(Icons.widgets_rounded,
                    color: AdminColors.primaryGlow),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adminL10n(context, title),
                      style: TextStyle(
                        color: uiText(context),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        adminL10n(context, subtitle!),
                        style: TextStyle(
                          color: uiSub(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onCreate != null)
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(createLabel),
                ),
            ],
          ),
          if (header != null) ...[
            const SizedBox(height: 10),
            header!,
          ],
          if (buttons.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: buttons),
          ],
        ],
      ),
    );
  }
}

class _ToolbarPill extends StatelessWidget {
  const _ToolbarPill({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AdminColors.darkCard2
              : const Color(0xFFF2F7FE),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: uiBorder(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AdminColors.primaryGlow),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: uiText(context),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.onRefresh,
    required this.onCreate,
    required this.onExport,
    required this.onOpenFilters,
    required this.onOpenSearch,
    required this.onHelp,
    required this.onBulk,
    required this.createLabel,
    required this.exportLabel,
  });

  final VoidCallback? onRefresh;
  final VoidCallback? onCreate;
  final VoidCallback? onExport;
  final VoidCallback? onOpenFilters;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onHelp;
  final VoidCallback? onBulk;

  final String createLabel;
  final String exportLabel;

  @override
  Widget build(BuildContext context) {
    final moreLabel = AppText.of(context, ar: 'المزيد', en: 'More');
    final searchLabel = AppText.of(context, ar: 'بحث', en: 'Search');
    final filtersLabel = AppText.of(context, ar: 'فلاتر', en: 'Filters');
    final refreshLabel = AppText.of(context, ar: 'تحديث', en: 'Refresh');
    final bulkLabel =
        AppText.of(context, ar: 'إجراءات جماعية', en: 'Bulk actions');
    final helpLabel = AppText.of(context, ar: 'مساعدة', en: 'Help');

    return PopupMenuButton<String>(
      tooltip: moreLabel,
      onSelected: (v) {
        if (v == 'search') onOpenSearch?.call();
        if (v == 'filters') onOpenFilters?.call();
        if (v == 'refresh') onRefresh?.call();
        if (v == 'create') onCreate?.call();
        if (v == 'export') onExport?.call();
        if (v == 'bulk') onBulk?.call();
        if (v == 'help') onHelp?.call();
      },
      itemBuilder: (ctx) => [
        if (onOpenSearch != null)
          PopupMenuItem(value: 'search', child: Text(searchLabel)),
        if (onOpenFilters != null)
          PopupMenuItem(value: 'filters', child: Text(filtersLabel)),
        if (onRefresh != null)
          PopupMenuItem(value: 'refresh', child: Text(refreshLabel)),
        if (onBulk != null)
          PopupMenuItem(value: 'bulk', child: Text(bulkLabel)),
        if (onCreate != null)
          PopupMenuItem(value: 'create', child: Text(createLabel)),
        if (onExport != null)
          PopupMenuItem(value: 'export', child: Text(exportLabel)),
        if (onHelp != null)
          PopupMenuItem(value: 'help', child: Text(helpLabel)),
      ],
      icon: const Icon(Icons.more_vert_rounded),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            adminL10n(context, text),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: uiText(context),
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: uiCard(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: uiBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            adminL10n(context, title),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: uiSub(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: uiText(context),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              adminL10n(context, subtitle!),
              style: TextStyle(
                  fontSize: 11,
                  color: uiSub(context),
                  fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: card,
    );
  }
}

class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.color = AdminColors.primaryGlow,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
                Icon(icon, size: 22, color: color),
                const Spacer(),
                if (badge != null) badge!,
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: uiText(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                color: uiSub(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WideActionButton extends StatelessWidget {
  const WideActionButton({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: uiCard(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: uiBorder(context)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color ?? AdminColors.primaryGlow),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                adminL10n(context, title),
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: uiText(context)),
              ),
            ),
            trailing ??
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: uiSub(context),
                ),
          ],
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.overrideColor});

  final String text;
  final Color? overrideColor;

  @override
  Widget build(BuildContext context) {
    final c = overrideColor ?? statusColor(text);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(.25)),
      ),
      child: Text(
        adminL10n(context, text),
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.mono = false,
  });

  final String label;
  final String value;
  final Widget? trailing;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              adminL10n(context, label),
              style: TextStyle(
                  color: uiSub(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: uiText(context),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: uiCard(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: uiBorder(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AdminColors.primary.withOpacity(.14),
              child: Icon(icon, color: AdminColors.primaryGlow, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                  color: uiText(context),
                  fontWeight: FontWeight.w900,
                  fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style:
                  TextStyle(color: uiSub(context), fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool?> adminConfirm(
  BuildContext context, {
  required String title,
  required String message,
  bool danger = false,
  String? okText,
  String? cancelText,
}) {
  final resolvedOkText = okText ?? AppText.of(context, ar: 'موافق', en: 'OK');
  final resolvedCancelText =
      cancelText ?? AppText.of(context, ar: 'إلغاء', en: 'Cancel');
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: uiCard(ctx),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
              child: Text(resolvedCancelText)),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor:
                    danger ? AdminColors.danger : AdminColors.primary),
            child: Text(resolvedOkText),
          ),
        ],
      );
    },
  );
}
