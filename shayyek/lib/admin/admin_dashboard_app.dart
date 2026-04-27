import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import '../theme_controller.dart';
import 'admin_theme.dart';
import 'admin_utils.dart';
import 'adminhome.dart';
import 'admin_users_page.dart';
import 'admin_lots_page.dart';
import 'admin_stalls_page.dart';
import 'admin_cameras_page.dart';
import 'admin_notifications_page.dart';
import 'admin_announcements_page.dart';
import 'admin_audit_logs_page.dart';
import 'admin_analytics_page.dart';
import 'admin_business_rules_page.dart';

class AdminDashboardApp extends StatefulWidget {
  const AdminDashboardApp({super.key});

  @override
  State<AdminDashboardApp> createState() => _AdminDashboardAppState();
}

class _AdminDashboardAppState extends State<AdminDashboardApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.maybeOf(context);
    final animation = controller == null
        ? null
        : Listenable.merge([controller.themeMode, controller.locale]);

    Widget buildApp() {
      final themeMode = controller?.themeMode.value ?? _themeMode;
      final platformBrightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final isDarkMode = themeMode == ThemeMode.dark ||
          (themeMode == ThemeMode.system &&
              platformBrightness == Brightness.dark);

      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AdminTheme.light(),
        darkTheme: AdminTheme.dark(),
        themeMode: themeMode,
        locale: controller?.locale.value,
        supportedLocales: const [
          Locale('ar'),
          Locale('en'),
        ],
        localeResolutionCallback: (deviceLocale, supportedLocales) {
          final code = ThemeController.supportedLanguageCode(
            deviceLocale?.languageCode,
          );
          return Locale(code);
        },
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          final isArabic = (controller?.effectiveLanguageCode ??
                  ThemeController.supportedLanguageCodeForPlatform()) ==
              'ar';
          return Directionality(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: AdminDashboardShell(
          isDarkMode: isDarkMode,
          onToggleTheme: controller?.toggle ?? _toggleTheme,
        ),
      );
    }

    if (animation == null) {
      return buildApp();
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => buildApp(),
    );
  }
}

class AdminDashboardShell extends StatefulWidget {
  const AdminDashboardShell({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<AdminDashboardShell> createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State<AdminDashboardShell> {
  final _db = FirebaseDatabase.instance;

  int _activeIndex = 0;

  void _switchTab(int i) {
    if (i < 0) return;
    if (i >= _items.length) return;
    if (!mounted) return;

    final rootNav = Navigator.of(context, rootNavigator: true);
    if (rootNav.canPop()) {
      rootNav.popUntil((r) => r.isFirst);
    }

    setState(() => _activeIndex = i);
  }

  void goToTab(int i) => _switchTab(i);

  late final List<_AdminNavItem> _items = [
    _AdminNavItem(
      id: 'home',
      label: 'Home',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      keywords: const ['home', 'dashboard', 'overview', 'analytics'],
      builder: () => AdminHomePage(
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
        onOpenTab: goToTab,
        onOpenSettings: () {},
        onSignOut: () {},
      ),
    ),
    _AdminNavItem(
      id: 'users',
      label: 'Users',
      icon: Icons.people_alt_outlined,
      activeIcon: Icons.people_alt_rounded,
      keywords: const [
        'users',
        'accounts',
        'roles',
        'permissions',
        'admins',
        'drivers'
      ],
      builder: () => AdminUsersPage(
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      ),
    ),
    _AdminNavItem(
      id: 'lots',
      label: 'Lots',
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
      keywords: const ['lots', 'locations', 'maps', 'parking lots'],
      builder: () => AdminLotsPage(
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      ),
    ),
    _AdminNavItem(
      id: 'stalls',
      label: 'Stalls',
      icon: Icons.local_parking_outlined,
      activeIcon: Icons.local_parking_rounded,
      keywords: const ['stalls', 'spots', 'spaces', 'availability'],
      builder: () => AdminStallsPage(
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      ),
    ),
    _AdminNavItem(
      id: 'cameras',
      label: 'Cameras',
      icon: Icons.videocam_outlined,
      activeIcon: Icons.videocam_rounded,
      keywords: const ['cameras', 'streams', 'health', 'fps', 'latency'],
      builder: () => AdminCamerasPage(
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      ),
    ),
    _AdminNavItem(
      id: 'notifications',
      label: 'Notifications',
      icon: Icons.notifications_active_outlined,
      activeIcon: Icons.notifications_rounded,
      keywords: const ['notifications', 'push', 'email', 'in_app', 'alerts'],
      builder: () => AdminNotificationsPage(
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      ),
    ),
    _AdminNavItem(
      id: 'announcements',
      label: 'Announcements',
      icon: Icons.campaign_outlined,
      activeIcon: Icons.campaign_rounded,
      keywords: const ['announcements', 'broadcast', 'news', 'lot'],
      builder: () => AdminAnnouncementsPage(
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      ),
    ),
    _AdminNavItem(
      id: 'audit',
      label: 'Audit Logs',
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check_rounded,
      keywords: const ['audit', 'logs', 'events', 'security', 'tracking'],
      builder: () => AdminAuditLogsPage(
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      ),
    ),
    _AdminNavItem(
      id: 'analytics',
      label: 'Analytics',
      icon: Icons.query_stats_outlined,
      activeIcon: Icons.query_stats_rounded,
      keywords: const ['analytics', 'stats', 'charts', 'reports'],
      builder: () => AdminAnalyticsPage(
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      ),
    ),
    _AdminNavItem(
      id: 'rules',
      label: 'Business Rules',
      icon: Icons.rule_folder_outlined,
      activeIcon: Icons.rule_folder_rounded,
      keywords: const ['rules', 'business', 'policies', 'constraints'],
      builder: () => AdminBusinessRulesPage(
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 980;

    final body = KeyedSubtree(
      key: ValueKey<String>(_items[_activeIndex].id),
      child: _items[_activeIndex].builder(),
    );

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
            const _OpenCommandPaletteIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyT):
            const _ToggleThemeIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyJ):
            const _OpenQuickActionsIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const _CloseOverlaysIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenCommandPaletteIntent: CallbackAction<_OpenCommandPaletteIntent>(
            onInvoke: (intent) {
              _openCommandPalette(context);
              return null;
            },
          ),
          _ToggleThemeIntent: CallbackAction<_ToggleThemeIntent>(
            onInvoke: (intent) {
              widget.onToggleTheme();
              return null;
            },
          ),
          _OpenQuickActionsIntent: CallbackAction<_OpenQuickActionsIntent>(
            onInvoke: (intent) {
              _openQuickActions(context);
              return null;
            },
          ),
          _CloseOverlaysIntent: CallbackAction<_CloseOverlaysIntent>(
            onInvoke: (intent) {
              final rootNav = Navigator.of(context, rootNavigator: true);
              if (rootNav.canPop()) {
                rootNav.maybePop();
                return null;
              }
              if (_activeIndex != 0) {
                _switchTab(0);
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: PopScope(
            canPop: false,
            onPopInvoked: (didPop) async {
              if (didPop) return;
              final rootNav = Navigator.of(context, rootNavigator: true);
              if (rootNav.canPop()) {
                rootNav.maybePop();
                return;
              }

              if (_activeIndex != 0) {
                _switchTab(0);
                return;
              }

              final ok = await _confirmExit(context);
              if (ok == true && mounted) {
                Navigator.of(context).maybePop();
              }
            },
            child: Scaffold(
              body: wide
                  ? Row(
                      children: [
                        _sideNav(context),
                        Expanded(child: body),
                      ],
                    )
                  : body,
              bottomNavigationBar: wide ? null : _bottomNav(context),
              floatingActionButton: _fab(context, wide),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _fab(BuildContext context, bool wide) {
    return FloatingActionButton.extended(
      onPressed: () => _openQuickActions(context),
      icon: const Icon(Icons.bolt_rounded),
      label: const Text('Quick'),
    );
  }

  Widget _sideNav(BuildContext context) {
    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: uiCard(context),
        border: Border(right: BorderSide(color: uiBorder(context))),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AdminColors.primary.withOpacity(.14),
                    child: const Icon(Icons.admin_panel_settings_outlined,
                        color: AdminColors.primaryGlow),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Admin Panel',
                            style: TextStyle(
                                color: uiText(context),
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text('Ctrl+K search • Ctrl+J quick',
                            style: TextStyle(
                                color: uiSub(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onToggleTheme,
                    icon: Icon(widget.isDarkMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined),
                    tooltip: 'Toggle theme',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: _navSearchBox(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                children: [
                  ...List.generate(_items.length, (i) => _railTile(context, i)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AdminColors.darkCard2
                          : const Color(0xFFF2F7FE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: uiBorder(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Operations',
                            style: TextStyle(
                                color: uiText(context),
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        _miniAction(
                            context,
                            Icons.search_rounded,
                            'Command palette (Ctrl+K)',
                            () => _openCommandPalette(context)),
                        _miniAction(
                            context,
                            Icons.bolt_rounded,
                            'Quick actions (Ctrl+J)',
                            () => _openQuickActions(context)),
                        _miniAction(context, Icons.color_lens_outlined,
                            'Toggle theme (Ctrl+T)', widget.onToggleTheme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navSearchBox(BuildContext context) {
    return TextField(
      readOnly: true,
      onTap: () => _openCommandPalette(context),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: 'Search modules (Ctrl+K)',
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AdminColors.darkCard2
                    : const Color(0xFFF2F7FE),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: uiBorder(context)),
              ),
              child: Text('Ctrl+K',
                  style: TextStyle(
                      color: uiSub(context),
                      fontWeight: FontWeight.w800,
                      fontSize: 11)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _railTile(BuildContext context, int i) {
    final it = _items[i];
    final active = i == _activeIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _switchTab(i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color:
                active ? AdminColors.primary.withOpacity(.10) : uiCard(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: active
                    ? AdminColors.primary.withOpacity(.25)
                    : uiBorder(context)),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(active ? it.activeIcon : it.icon,
                      color: active ? AdminColors.primaryGlow : uiSub(context)),
                  if (it.id == 'notifications')
                    Positioned(
                        right: -6, top: -6, child: _queuedBadge(context)),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  it.label,
                  style: TextStyle(
                      color: uiText(context),
                      fontWeight: active ? FontWeight.w900 : FontWeight.w800),
                ),
              ),
              if (active)
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AdminColors.primaryGlow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNav(BuildContext context) {
    const primaryCount = 5;
    const moreIndex = primaryCount;
    final bottomIndex = _activeIndex < primaryCount ? _activeIndex : moreIndex;

    return BottomNavigationBar(
      currentIndex: bottomIndex,
      onTap: (v) async {
        if (v < primaryCount) {
          _switchTab(v);
          return;
        }
        await _openMore(context);
      },
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard_rounded),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.people_alt_outlined),
          activeIcon: Icon(Icons.people_alt_rounded),
          label: 'Users',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.map_outlined),
          activeIcon: Icon(Icons.map_rounded),
          label: 'Lots',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.local_parking_outlined),
          activeIcon: Icon(Icons.local_parking_rounded),
          label: 'Stalls',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.videocam_outlined),
          activeIcon: Icon(Icons.videocam_rounded),
          label: 'Cameras',
        ),
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.grid_view_outlined),
              Positioned(right: -6, top: -6, child: _queuedBadge(context)),
            ],
          ),
          activeIcon: const Icon(Icons.grid_view_rounded),
          label: 'More',
        ),
      ],
    );
  }

  Future<void> _openMore(BuildContext context) async {
    const primaryCount = 5;
    final extra = _items.sublist(primaryCount);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: uiCard(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.grid_view_rounded,
                        color: AdminColors.primaryGlow),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('More modules',
                          style: TextStyle(
                              color: uiText(ctx), fontWeight: FontWeight.w900)),
                    ),
                    IconButton(
                      onPressed: widget.onToggleTheme,
                      icon: Icon(widget.isDarkMode
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined),
                      tooltip: 'Toggle theme',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...extra.map((it) {
                  final idx = _items.indexOf(it);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      tileColor: Theme.of(ctx).brightness == Brightness.dark
                          ? AdminColors.darkCard2
                          : const Color(0xFFF2F7FE),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: uiBorder(ctx))),
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                AdminColors.primary.withOpacity(.14),
                            child:
                                Icon(it.icon, color: AdminColors.primaryGlow),
                          ),
                          if (it.id == 'notifications')
                            Positioned(
                                right: -6, top: -6, child: _queuedBadge(ctx)),
                        ],
                      ),
                      title: Text(it.label,
                          style: TextStyle(
                              color: uiText(ctx), fontWeight: FontWeight.w900)),
                      subtitle: Text(
                        it.keywords.take(3).join(' • '),
                        style: TextStyle(
                            color: uiSub(ctx),
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: uiSub(ctx)),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _switchTab(idx);
                      },
                    ),
                  );
                }),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCommandPalette(BuildContext context) async {
    final qCtrl = TextEditingController();
    List<_AdminNavItem> list = List.of(_items);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: uiCard(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final query = qCtrl.text.trim().toLowerCase();
            list = _items.where((it) {
              if (query.isEmpty) return true;
              final hay =
                  '${it.label} ${it.id} ${it.keywords.join(' ')}'.toLowerCase();
              return hay.contains(query);
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 14,
                  right: 14,
                  top: 6,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 14,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.search_rounded,
                            color: AdminColors.primaryGlow),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Search & jump',
                              style: TextStyle(
                                  color: uiText(ctx),
                                  fontWeight: FontWeight.w900)),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            widget.onToggleTheme();
                            Navigator.of(ctx).pop();
                          },
                          icon: Icon(widget.isDarkMode
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined),
                          label: const Text('Theme'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: qCtrl,
                      autofocus: true,
                      onChanged: (_) => setLocal(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Type to search modules…',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 520),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          _paletteAction(
                            ctx,
                            icon: Icons.bolt_rounded,
                            title: 'Quick actions',
                            subtitle: 'Create / manage fast',
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _openQuickActions(context);
                            },
                          ),
                          _paletteAction(
                            ctx,
                            icon: Icons.color_lens_outlined,
                            title: 'Toggle theme',
                            subtitle: widget.isDarkMode
                                ? 'Switch to light'
                                : 'Switch to dark',
                            onTap: () {
                              widget.onToggleTheme();
                              Navigator.of(ctx).pop();
                            },
                          ),
                          const SizedBox(height: 8),
                          ...list.map((it) {
                            final idx = _items.indexOf(it);
                            return _paletteAction(
                              ctx,
                              icon: it.icon,
                              title: it.label,
                              subtitle: it.keywords.take(4).join(' • '),
                              trailing: it.id == 'notifications'
                                  ? _queuedBadge(ctx)
                                  : null,
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _switchTab(idx);
                              },
                            );
                          }),
                          if (list.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: Center(
                                  child: Text('No results',
                                      style: TextStyle(
                                          color: uiSub(ctx),
                                          fontWeight: FontWeight.w700))),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _paletteAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        tileColor: Theme.of(context).brightness == Brightness.dark
            ? AdminColors.darkCard2
            : const Color(0xFFF2F7FE),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: uiBorder(context))),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: AdminColors.primary.withOpacity(.14),
          child: Icon(icon, color: AdminColors.primaryGlow),
        ),
        title: Text(title,
            style:
                TextStyle(color: uiText(context), fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle,
            style: TextStyle(
                color: uiSub(context),
                fontWeight: FontWeight.w700,
                fontSize: 12)),
        trailing: trailing ??
            Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: uiSub(context)),
        onTap: onTap,
      ),
    );
  }

  Future<void> _openQuickActions(BuildContext context) async {
    final actions = <_QuickAction>[
      _QuickAction('Create notification', Icons.add_alert_rounded,
          () => _jumpTo('notifications')),
      _QuickAction('Create announcement', Icons.campaign_outlined,
          () => _jumpTo('announcements')),
      _QuickAction('Review audit logs', Icons.fact_check_outlined,
          () => _jumpTo('audit')),
      _QuickAction('Open analytics', Icons.query_stats_outlined,
          () => _jumpTo('analytics')),
      _QuickAction(
          'Business rules', Icons.rule_folder_outlined, () => _jumpTo('rules')),
      _QuickAction(
          'Manage users', Icons.people_alt_outlined, () => _jumpTo('users')),
      _QuickAction('Manage lots', Icons.map_outlined, () => _jumpTo('lots')),
      _QuickAction('Manage stalls', Icons.local_parking_outlined,
          () => _jumpTo('stalls')),
      _QuickAction(
          'Manage cameras', Icons.videocam_outlined, () => _jumpTo('cameras')),
    ];

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: uiCard(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: AdminColors.primaryGlow),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Quick actions',
                          style: TextStyle(
                              color: uiText(ctx), fontWeight: FontWeight.w900)),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        widget.onToggleTheme();
                        Navigator.of(ctx).pop();
                      },
                      icon: Icon(widget.isDarkMode
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined),
                      label: const Text('Theme'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...actions.map((a) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      tileColor: Theme.of(ctx).brightness == Brightness.dark
                          ? AdminColors.darkCard2
                          : const Color(0xFFF2F7FE),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: uiBorder(ctx))),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: AdminColors.primary.withOpacity(.14),
                        child: Icon(a.icon, color: AdminColors.primaryGlow),
                      ),
                      title: Text(a.title,
                          style: TextStyle(
                              color: uiText(ctx), fontWeight: FontWeight.w900)),
                      trailing: Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: uiSub(ctx)),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        a.onTap();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _jumpTo(String id) {
    final idx = _items.indexWhere((x) => x.id == id);
    if (idx >= 0) _switchTab(idx);
  }

  Widget _miniAction(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: uiCard(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: uiBorder(context)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AdminColors.primaryGlow),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: uiText(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _queuedBadge(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _db.ref('Notification').onValue,
      builder: (context, snap) {
        int c = 0;
        if (snap.hasData) {
          final items = childEntries(snap.data!.snapshot.value);
          for (final e in items) {
            final m = mapOf(e.value);
            final st = s(m['status'], '').toLowerCase().trim();
            if (st == 'queued') c++;
          }
        }
        if (c <= 0) return const SizedBox.shrink();
        final t = c > 99 ? '99+' : '$c';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AdminColors.danger,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: uiCard(context)),
          ),
          child: Text(
            t,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        );
      },
    );
  }

  Future<bool?> _confirmExit(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: uiCard(ctx),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.logout_rounded, color: AdminColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Exit admin panel?',
                    style: TextStyle(
                        color: uiText(ctx), fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          content: Text('Do you want to close the admin dashboard?',
              style: TextStyle(color: uiSub(ctx), fontWeight: FontWeight.w700)),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style:
                  FilledButton.styleFrom(backgroundColor: AdminColors.danger),
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }
}

class _AdminNavItem {
  final String id;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final List<String> keywords;
  final Widget Function() builder;

  const _AdminNavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.keywords,
    required this.builder,
  });
}

class _QuickAction {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAction(this.title, this.icon, this.onTap);
}

class _OpenCommandPaletteIntent extends Intent {
  const _OpenCommandPaletteIntent();
}

class _ToggleThemeIntent extends Intent {
  const _ToggleThemeIntent();
}

class _OpenQuickActionsIntent extends Intent {
  const _OpenQuickActionsIntent();
}

class _CloseOverlaysIntent extends Intent {
  const _CloseOverlaysIntent();
}
