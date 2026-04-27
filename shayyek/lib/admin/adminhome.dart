// ignore_for_file: unused_element, prefer_const_constructors, prefer_const_declarations

import 'dart:math';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_text.dart';
import '../theme_controller.dart';
import '../welcome.dart';
import 'admin_theme.dart';
import 'admin_utils.dart';
import 'admin_widgets.dart';
import 'editprofile.dart';
import 'admin_users_page.dart';
import 'admin_lots_page.dart';
import 'admin_stalls_page.dart';
import 'admin_cameras_page.dart';
import 'admin_notifications_page.dart';
import 'admin_announcements_page.dart';
import 'admin_audit_logs_page.dart';
import 'admin_analytics_page.dart';
import 'admin_business_rules_page.dart';

String _adminText(BuildContext context, String ar, String en) {
  return AppText.of(context, ar: ar, en: en);
}

String _adminNavLabel(BuildContext context, String id) {
  switch (id) {
    case 'home':
      return _adminText(context, 'الرئيسية', 'Home');
    case 'users':
      return _adminText(context, 'المستخدمون', 'Users');
    case 'lots':
      return _adminText(context, 'المواقف', 'Lots');
    case 'stalls':
      return _adminText(context, 'الفراغات', 'Stalls');
    case 'cameras':
      return _adminText(context, 'الكاميرات', 'Cameras');
    case 'notifications':
      return _adminText(context, 'الإشعارات', 'Notifications');
    case 'announcements':
      return _adminText(context, 'الإعلانات', 'Announcements');
    case 'audit':
      return _adminText(context, 'سجل التدقيق', 'Audit Logs');
    case 'analytics':
      return _adminText(context, 'التحليلات', 'Analytics');
    case 'rules':
      return _adminText(context, 'القواعد', 'Business Rules');
    default:
      return id;
  }
}

String _adminNavSubtitle(BuildContext context, String id) {
  switch (id) {
    case 'home':
      return _adminText(
          context, 'نظرة عامة ومؤشرات حية', 'Overview and live KPIs');
    case 'users':
      return _adminText(
          context, 'إدارة الحسابات والأدوار', 'Manage accounts and roles');
    case 'lots':
      return _adminText(context, 'المواقف والمواقع والعناوين',
          'Lots, locations, and addresses');
    case 'stalls':
      return _adminText(
          context, 'حالات الفراغات والتوفر', 'Stall status and availability');
    case 'cameras':
      return _adminText(
          context, 'البث والحالة والأداء', 'Feeds, health, and performance');
    case 'notifications':
      return _adminText(
          context, 'التنبيهات ورسائل المستخدمين', 'Alerts and user messages');
    case 'announcements':
      return _adminText(
          context, 'الإعلانات العامة الموجهة', 'Broadcast announcements');
    case 'audit':
      return _adminText(
          context, 'تتبع الأنشطة والسجل', 'Activity tracking and logs');
    case 'analytics':
      return _adminText(context, 'الرسوم والتقارير', 'Charts and reports');
    case 'rules':
      return _adminText(
          context, 'السياسات والإعدادات', 'Policies and settings');
    default:
      return id;
  }
}

IconData _adminForwardIcon(BuildContext context) {
  return Directionality.of(context) == TextDirection.rtl
      ? Icons.chevron_left_rounded
      : Icons.chevron_right_rounded;
}

class AdminDashboardApp extends StatefulWidget {
  const AdminDashboardApp({super.key});

  @override
  State<AdminDashboardApp> createState() => _AdminDashboardAppState();
}

class _AdminDashboardAppState extends State<AdminDashboardApp> {
  ThemeMode _themeMode = ThemeMode.system;

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

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: uiCard(ctx),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            _adminText(ctx, 'تسجيل الخروج؟', 'Sign out?'),
            style: TextStyle(color: uiText(ctx), fontWeight: FontWeight.w900),
          ),
          content: Text(
            _adminText(
              ctx,
              'سيتم إنهاء جلسة الأدمن والعودة إلى صفحة البداية.',
              'This will end the admin session and return to the welcome page.',
            ),
            style: TextStyle(color: uiSub(ctx), fontWeight: FontWeight.w700),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(_adminText(ctx, 'إلغاء', 'Cancel')),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              style:
                  FilledButton.styleFrom(backgroundColor: AdminColors.danger),
              icon: const Icon(Icons.logout_rounded),
              label: Text(_adminText(ctx, 'تسجيل الخروج', 'Sign out')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', false);
    await prefs.remove('is_logged_in');
    await prefs.remove('user_role');
    await prefs.remove('user_id');
    await prefs.remove('user_primary_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('login_mode');

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    );
  }

  void _switchTab(int i) {
    if (i < 0) return;
    if (i >= _items.length) return;
    if (!mounted) return;

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
        onOpenSettings: () => _openSettings(context),
        onSignOut: () => _signOut(context),
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
              _openSettings(context);
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
    return null;
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
                    child: Icon(Icons.admin_panel_settings_outlined,
                        color: AdminColors.primaryGlow),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_adminText(context, 'لوحة الإدارة', 'Admin Panel'),
                            style: TextStyle(
                                color: uiText(context),
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(
                            _adminText(
                                context,
                                'Ctrl+K للبحث • Ctrl+J للإجراءات السريعة',
                                'Ctrl+K search • Ctrl+J quick'),
                            style: TextStyle(
                                color: uiSub(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
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
                        Text(_adminText(context, 'العمليات', 'Operations'),
                            style: TextStyle(
                                color: uiText(context),
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        _miniAction(
                            context,
                            Icons.person_outline_rounded,
                            _adminText(context, 'الحساب والإعدادات',
                                'Account & settings'),
                            () => _openSettings(context)),
                        const SizedBox(height: 8),
                        _miniAction(
                          context,
                          Icons.logout_rounded,
                          _adminText(context, 'تسجيل الخروج', 'Sign out'),
                          () => _signOut(context),
                        ),
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
        hintText: _adminText(
            context, 'ابحث في الأقسام (Ctrl+K)', 'Search modules (Ctrl+K)'),
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
                  _adminNavLabel(context, it.id),
                  style: TextStyle(
                      color: uiText(context),
                      fontWeight: active ? FontWeight.w900 : FontWeight.w800),
                ),
              ),
              if (active)
                Icon(_adminForwardIcon(context),
                    size: 14, color: AdminColors.primaryGlow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNav(BuildContext context) {
    final primaryCount = 5;
    final moreIndex = primaryCount;
    final bottomIndex = _activeIndex < primaryCount ? _activeIndex : moreIndex;

    final entries = [
      _AdminBottomEntry(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: _adminText(context, 'الرئيسية', 'Home'),
        onTap: () => _switchTab(0),
      ),
      _AdminBottomEntry(
        icon: Icons.people_alt_outlined,
        activeIcon: Icons.people_alt_rounded,
        label: _adminText(context, 'المستخدمون', 'Users'),
        onTap: () => _switchTab(1),
      ),
      _AdminBottomEntry(
        icon: Icons.map_outlined,
        activeIcon: Icons.map_rounded,
        label: _adminText(context, 'المواقف', 'Lots'),
        onTap: () => _switchTab(2),
      ),
      _AdminBottomEntry(
        icon: Icons.local_parking_outlined,
        activeIcon: Icons.local_parking_rounded,
        label: _adminText(context, 'الفراغات', 'Stalls'),
        onTap: () => _switchTab(3),
      ),
      _AdminBottomEntry(
        icon: Icons.videocam_outlined,
        activeIcon: Icons.videocam_rounded,
        label: _adminText(context, 'الكاميرات', 'Cameras'),
        onTap: () => _switchTab(4),
      ),
      _AdminBottomEntry(
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded,
        label: _adminText(context, 'المزيد', 'More'),
        onTap: () => _openMore(context),
        badge: _queuedBadge(context),
      ),
    ];

    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? .28 : .08),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: (dark ? AdminColors.darkCard : Colors.white)
                .withOpacity(dark ? .96 : .98),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: uiBorder(context)),
          ),
          child: Row(
            children: List.generate(entries.length, (i) {
              return Expanded(
                child: _AdminBottomButton(
                  entry: entries[i],
                  selected: i == bottomIndex,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Future<void> _openMore(BuildContext context) async {
    final primaryCount = 5;
    final extra = _items.sublist(primaryCount);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      showDragHandle: true,
      backgroundColor: uiCard(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.grid_view_rounded,
                        color: AdminColors.primaryGlow),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          _adminText(
                              context, 'مزيد من الأقسام', 'More modules'),
                          style: TextStyle(
                              color: uiText(ctx), fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    tileColor: Theme.of(ctx).brightness == Brightness.dark
                        ? AdminColors.darkCard2
                        : const Color(0xFFF2F7FE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: uiBorder(ctx)),
                    ),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: AdminColors.success.withOpacity(.14),
                      child: Icon(Icons.person_outline_rounded,
                          color: AdminColors.success),
                    ),
                    title: Text(
                      _adminText(ctx, 'الملف والإعدادات', 'Profile & settings'),
                      style: TextStyle(
                        color: uiText(ctx),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: Text(
                      _adminText(
                        ctx,
                        'تعديل الملف، اللغة، الثيم، وكلمة المرور',
                        'Edit profile, language, theme, and password',
                      ),
                      style: TextStyle(
                        color: uiSub(ctx),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Icon(_adminForwardIcon(ctx),
                        size: 16, color: uiSub(ctx)),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _openSettings(context);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    tileColor: Theme.of(ctx).brightness == Brightness.dark
                        ? AdminColors.darkCard2
                        : const Color(0xFFF2F7FE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: AdminColors.danger.withOpacity(.22),
                      ),
                    ),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: AdminColors.danger.withOpacity(.12),
                      child: const Icon(Icons.logout_rounded,
                          color: AdminColors.danger),
                    ),
                    title: Text(
                      _adminText(ctx, 'تسجيل الخروج', 'Sign out'),
                      style: TextStyle(
                        color: uiText(ctx),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: Text(
                      _adminText(
                        ctx,
                        'إنهاء جلسة الأدمن والعودة للبداية',
                        'End the admin session and return to welcome',
                      ),
                      style: TextStyle(
                        color: uiSub(ctx),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(Icons.logout_rounded,
                        size: 16, color: AdminColors.danger),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _signOut(context);
                    },
                  ),
                ),
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
                      title: Text(_adminNavLabel(ctx, it.id),
                          style: TextStyle(
                              color: uiText(ctx), fontWeight: FontWeight.w900)),
                      subtitle: Text(
                        _adminNavSubtitle(ctx, it.id),
                        style: TextStyle(
                            color: uiSub(ctx),
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                      trailing: Icon(_adminForwardIcon(ctx),
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
              final hay = '${_adminNavLabel(context, it.id)} '
                      '${_adminNavSubtitle(context, it.id)} '
                      '${it.label} ${it.id} ${it.keywords.join(' ')}'
                  .toLowerCase();
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
                        Icon(Icons.search_rounded,
                            color: AdminColors.primaryGlow),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              _adminText(
                                  context, 'بحث وانتقال', 'Search & jump'),
                              style: TextStyle(
                                  color: uiText(ctx),
                                  fontWeight: FontWeight.w900)),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _openSettings(context);
                          },
                          icon: const Icon(Icons.settings_rounded),
                          label: Text(
                              _adminText(context, 'الإعدادات', 'Settings')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: qCtrl,
                      autofocus: true,
                      onChanged: (_) => setLocal(() {}),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: _adminText(context, 'اكتب للبحث في الأقسام…',
                            'Type to search modules…'),
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
                            title: _adminText(
                                context, 'إجراءات سريعة', 'Quick actions'),
                            subtitle: _adminText(context, 'تنفيذ سريع للأقسام',
                                'Create / manage fast'),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _openQuickActions(context);
                            },
                          ),
                          _paletteAction(
                            ctx,
                            icon: Icons.settings_rounded,
                            title: _adminText(context, 'الإعدادات', 'Settings'),
                            subtitle: _adminText(
                                context,
                                'الملف الشخصي واللغة والمظهر',
                                'Profile, language and appearance'),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _openSettings(context);
                            },
                          ),
                          const SizedBox(height: 8),
                          ...list.map((it) {
                            final idx = _items.indexOf(it);
                            return _paletteAction(
                              ctx,
                              icon: it.icon,
                              title: _adminNavLabel(ctx, it.id),
                              subtitle: _adminNavSubtitle(ctx, it.id),
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
                                  child: Text(
                                      _adminText(context, 'لا توجد نتائج',
                                          'No results'),
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
            Icon(_adminForwardIcon(context), size: 16, color: uiSub(context)),
        onTap: onTap,
      ),
    );
  }

  Future<void> _openQuickActions(BuildContext context) async {
    final actions = <_QuickAction>[
      _QuickAction(_adminText(context, 'إنشاء إشعار', 'Create notification'),
          Icons.add_alert_rounded, () => _jumpTo('notifications')),
      _QuickAction(_adminText(context, 'إنشاء إعلان', 'Create announcement'),
          Icons.campaign_outlined, () => _jumpTo('announcements')),
      _QuickAction(
          _adminText(context, 'مراجعة سجل التدقيق', 'Review audit logs'),
          Icons.fact_check_outlined,
          () => _jumpTo('audit')),
      _QuickAction(_adminText(context, 'فتح التحليلات', 'Open analytics'),
          Icons.query_stats_outlined, () => _jumpTo('analytics')),
      _QuickAction(_adminText(context, 'قواعد العمل', 'Business rules'),
          Icons.rule_folder_outlined, () => _jumpTo('rules')),
      _QuickAction(_adminText(context, 'إدارة المستخدمين', 'Manage users'),
          Icons.people_alt_outlined, () => _jumpTo('users')),
      _QuickAction(_adminText(context, 'إدارة المواقف', 'Manage lots'),
          Icons.map_outlined, () => _jumpTo('lots')),
      _QuickAction(_adminText(context, 'إدارة الفراغات', 'Manage stalls'),
          Icons.local_parking_outlined, () => _jumpTo('stalls')),
      _QuickAction(_adminText(context, 'إدارة الكاميرات', 'Manage cameras'),
          Icons.videocam_outlined, () => _jumpTo('cameras')),
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
                    Icon(Icons.bolt_rounded, color: AdminColors.primaryGlow),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          _adminText(context, 'إجراءات سريعة', 'Quick actions'),
                          style: TextStyle(
                              color: uiText(ctx), fontWeight: FontWeight.w900)),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _openSettings(context);
                      },
                      icon: const Icon(Icons.settings_rounded),
                      label: Text(_adminText(context, 'الإعدادات', 'Settings')),
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
                      trailing: Icon(_adminForwardIcon(ctx),
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
              Icon(Icons.logout_rounded, color: AdminColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    _adminText(context, 'الخروج من لوحة الإدارة؟',
                        'Exit admin panel?'),
                    style: TextStyle(
                        color: uiText(ctx), fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          content: Text(
              _adminText(context, 'هل تريد إغلاق لوحة الإدارة؟',
                  'Do you want to close the admin dashboard?'),
              style: TextStyle(color: uiSub(ctx), fontWeight: FontWeight.w700)),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(_adminText(context, 'إلغاء', 'Cancel'))),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style:
                  FilledButton.styleFrom(backgroundColor: AdminColors.danger),
              child: Text(_adminText(context, 'خروج', 'Exit')),
            ),
          ],
        );
      },
    );
  }
}

class _AdminBottomEntry {
  const _AdminBottomEntry({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;
  final Widget? badge;
}

class _AdminBottomButton extends StatelessWidget {
  const _AdminBottomButton({
    required this.entry,
    required this.selected,
  });

  final _AdminBottomEntry entry;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = dark ? AdminColors.primaryGlow : AdminColors.primary;
    final inactiveColor = uiSub(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: entry.onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AdminColors.primary.withOpacity(dark ? .18 : .10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AdminColors.primary.withOpacity(.24)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    selected ? entry.activeIcon : entry.icon,
                    color: selected ? activeColor : inactiveColor,
                    size: 21,
                  ),
                  if (entry.badge != null)
                    PositionedDirectional(
                      top: -8,
                      end: -10,
                      child: entry.badge!,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? activeColor : inactiveColor,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    fontSize: 10.5,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onOpenTab,
    required this.onOpenSettings,
    required this.onSignOut,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final void Function(int) onOpenTab;
  final VoidCallback onOpenSettings;
  final VoidCallback onSignOut;

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  Key _reloadKey = UniqueKey();

  void _reload() => setState(() => _reloadKey = UniqueKey());

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Stream<DatabaseEvent> _defaultLotStream() =>
      _db.ref('LOTs').limitToFirst(1).onValue;

  Stream<DatabaseEvent> _lotsStream() =>
      _db.ref('LOTs').limitToFirst(1).onValue;

  Stream<DatabaseEvent> _lotStream(String lotId) =>
      _db.ref('live_map/$lotId').onValue;

  Stream<DatabaseEvent> _rollupsStream() =>
      _db.ref('analytics_rollups').limitToLast(250).onValue;

  Stream<DatabaseEvent> _healthStream() =>
      _db.ref('CameraHealth').limitToLast(1).onValue;

  Stream<DatabaseEvent> _healthSeriesStream() =>
      _db.ref('CameraHealth').limitToLast(20).onValue;

  Stream<DatabaseEvent> _sessionsStream() =>
      _db.ref('Sessions').orderByChild('status').equalTo('active').onValue;

  Stream<DatabaseEvent> _camerasStream(String lotId) =>
      _db.ref('cameras').orderByChild('lot_id').equalTo(lotId).onValue;

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  String _firstKey(dynamic v) {
    final m = _asMap(v);
    if (m.isEmpty) return '';
    final k = m.keys.first;
    return k.toString();
  }

  Map<String, dynamic> _firstObjectFromMap(dynamic v) {
    final m = _asMap(v);
    if (m.isEmpty) return <String, dynamic>{};
    return _asMap(m.values.first);
  }

  Map<String, dynamic> _lastObjectFromMap(dynamic v) {
    final m = _asMap(v);
    if (m.isEmpty) return <String, dynamic>{};
    return _asMap(m.values.last);
  }

  Map<String, dynamic> _findObjectById(dynamic value, String wantedId) {
    final wanted = wantedId.trim().toLowerCase();
    if (wanted.isEmpty) {
      return <String, dynamic>{};
    }
    final m = _asMap(value);
    for (final entry in m.entries) {
      final row = _asMap(entry.value);
      final rowId = s(row['id'], entry.key).trim().toLowerCase();
      if (rowId == wanted) {
        return row;
      }
    }
    return <String, dynamic>{};
  }

  int _countKeys(dynamic v) {
    final m = _asMap(v);
    return m.length;
  }

  List<Map<String, dynamic>> _valuesAsList(dynamic v) {
    final m = _asMap(v);
    if (m.isEmpty) return <Map<String, dynamic>>[];
    final out = <Map<String, dynamic>>[];
    for (final e in m.values) {
      final mm = _asMap(e);
      if (mm.isNotEmpty) out.add(mm);
    }
    return out;
  }

  List<Map<String, dynamic>> _rollupsForLotSorted(dynamic v, String lotId) {
    final list = _valuesAsList(v);
    final out = <Map<String, dynamic>>[];
    for (final r in list) {
      if (s(r['lot_id']) == lotId) out.add(r);
    }
    out.sort((a, b) => s(a['day']).compareTo(s(b['day'])));
    return out;
  }

  Map<String, dynamic> _latestRollupForLot(dynamic v, String lotId) {
    final list = _rollupsForLotSorted(v, lotId);
    if (list.isEmpty) return <String, dynamic>{};
    return list.last;
  }

  void _openMenuSheet(
    BuildContext context, {
    required String orgName,
    required String lotId,
    required String lotName,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
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
                        .withOpacity(dark ? .78 : .96),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _adminText(context, 'الحساب والإعدادات',
                                        'Account & settings'),
                                    style: TextStyle(
                                      color: uiText(context),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    lotName.isEmpty
                                        ? (orgName.isEmpty ? lotId : orgName)
                                        : '${orgName.isEmpty ? 'Admin' : orgName} • $lotName',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: uiSub(context),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                          padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                          children: [
                            _MenuTile(
                              icon: Icons.person_outline_rounded,
                              title: _adminText(context, 'تعديل الملف الشخصي',
                                  'Edit Profile'),
                              subtitle: _adminText(
                                  context,
                                  'بيانات الحساب والتفضيلات',
                                  'Account info & preferences'),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                widget.onOpenSettings();
                              },
                            ),
                            const SizedBox(height: 6),
                            _MenuTile(
                              icon: Icons.logout_rounded,
                              title: _adminText(
                                  context, 'تفضيلات الواجهة', 'Sign out'),
                              subtitle: _adminText(
                                  context,
                                  'الثيم، اللغة، وكلمة المرور',
                                  'End session and return to welcome'),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                widget.onSignOut();
                              },
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  _adminText(
                                    context,
                                    'تم تبسيط التنقل. استخدم تبويبات الأدمن الرئيسية لفتح الأقسام.',
                                    'Navigation was simplified. Use the main admin tabs to open sections.',
                                  ),
                                  style: TextStyle(
                                    color: uiSub(context),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DatabaseEvent>(
      stream: _defaultLotStream(),
      builder: (context, defaultLotSnap) {
        final defaultLot = defaultLotSnap.hasData
            ? _firstObjectFromMap(defaultLotSnap.data!.snapshot.value)
            : <String, dynamic>{};

        final orgName = _adminText(context, 'الإدارة', 'Admin');
        final address = displayText(defaultLot['address'], '');
        final currentLotId = s(defaultLot['id'], '');

        return StreamBuilder<DatabaseEvent>(
          key: _reloadKey,
          stream: _lotsStream(),
          builder: (context, lotsSnap) {
            final lotsValue = lotsSnap.data?.snapshot.value;
            final preferredLot = lotsSnap.hasData
                ? _findObjectById(lotsValue, currentLotId)
                : <String, dynamic>{};
            final lotObj = preferredLot.isNotEmpty
                ? preferredLot
                : lotsSnap.hasData
                    ? _firstObjectFromMap(lotsValue)
                    : <String, dynamic>{};

            final lotId =
                s(lotObj['id'], _firstKey(lotsSnap.data?.snapshot.value));
            final lotName = displayText(lotObj['name'], lotId);

            return AdminPageFrame(
              title: orgName.isEmpty
                  ? _adminText(context, 'الإدارة', 'Admin')
                  : orgName,
              isDarkMode: widget.isDarkMode,
              onToggleTheme: widget.onToggleTheme,
              child: RefreshIndicator(
                onRefresh: () async => _reload(),
                child: StreamBuilder<DatabaseEvent>(
                  stream: lotId.trim().isEmpty
                      ? const Stream<DatabaseEvent>.empty()
                      : _lotStream(lotId),
                  builder: (context, snapLot) {
                    if (lotId.trim().isEmpty) {
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        children: [
                          errorBox(context, _reload),
                        ],
                      );
                    }

                    if (snapLot.hasError) {
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        children: [errorBox(context, _reload)],
                      );
                    }
                    if (!snapLot.hasData) {
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        children: [loadingBox(context)],
                      );
                    }

                    final lotLive = mapOf(snapLot.data!.snapshot.value);
                    final free = toInt(lotLive['free']);
                    final occupied = toInt(lotLive['occupied']);
                    final total = toInt(lotLive['total']);
                    final ts = dateShort(lotLive['ts']);
                    final degraded = toBool(lotLive['degraded_mode']);

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        _HeroGlass(
                          dark: dark,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _GlassIconButton(
                                      dark: dark,
                                      icon: Icons.refresh_rounded,
                                      onTap: _reload,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            orgName.isEmpty
                                                ? _adminText(
                                                    context,
                                                    'لوحة الإدارة',
                                                    'Admin Dashboard')
                                                : _adminText(
                                                    context,
                                                    'لوحة $orgName',
                                                    '$orgName Dashboard'),
                                            style: TextStyle(
                                              color:
                                                  Colors.white.withOpacity(.95),
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: .2,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            (address.trim().isEmpty)
                                                ? _adminText(
                                                    context,
                                                    '${lotName.isEmpty ? lotId : lotName} • محدث: $ts',
                                                    '${lotName.isEmpty ? lotId : lotName} • Updated: $ts',
                                                  )
                                                : _adminText(
                                                    context,
                                                    '${lotName.isEmpty ? lotId : lotName} • $address • محدث: $ts',
                                                    '${lotName.isEmpty ? lotId : lotName} • $address • Updated: $ts',
                                                  ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color:
                                                  Colors.white.withOpacity(.72),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            total <= 0
                                                ? '—'
                                                : _adminText(
                                                    context,
                                                    'فارغ $free / مشغول $occupied / الإجمالي $total',
                                                    'Free $free / Occupied $occupied / Total $total',
                                                  ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color:
                                                  Colors.white.withOpacity(.78),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _GlassPill(
                                      dark: dark,
                                      icon: degraded
                                          ? Icons.warning_amber_rounded
                                          : Icons.wifi_rounded,
                                      text: degraded
                                          ? _adminText(
                                              context, 'وضع محدود', 'Degraded')
                                          : _adminText(
                                              context, 'مباشر', 'Live'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _StatsStrip(
                                  dark: dark,
                                  lotId: lotId,
                                  rollupsStream: _rollupsStream(),
                                  healthStream: _healthStream(),
                                  sessionsStream: _sessionsStream(),
                                  camerasStream: _camerasStream(lotId),
                                  lastObjectFromMap: _lastObjectFromMap,
                                  latestRollupForLot: _latestRollupForLot,
                                  countKeys: _countKeys,
                                ),
                                const SizedBox(height: 12),
                                _ChartsSection(
                                  dark: dark,
                                  lotId: lotId,
                                  rollupsStream: _rollupsStream(),
                                  healthSeriesStream: _healthSeriesStream(),
                                  rollupsForLotSorted: _rollupsForLotSorted,
                                  valuesAsList: _valuesAsList,
                                ),
                                const SizedBox(height: 12),
                                _DatePills(dark: dark),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: uiCard(context),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: uiBorder(context)),
                          ),
                          child: Text(
                            _adminText(
                              context,
                              'تم تبسيط الواجهة. استخدم شريط التنقل السفلي أو زر المزيد فقط لفتح الأقسام.',
                              'The interface was simplified. Use the bottom navigation or the More tab to open sections.',
                            ),
                            style: TextStyle(
                              color: uiSub(context),
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _OperationsCard extends StatelessWidget {
  const _OperationsCard({
    required this.onDashboard,
    required this.onUsers,
    required this.onLots,
    required this.onStalls,
    required this.onCameras,
    required this.onAnalytics,
    required this.onAlerts,
    required this.onAnnouncements,
    required this.onAudit,
    required this.onRules,
  });

  final VoidCallback onDashboard;
  final VoidCallback onUsers;
  final VoidCallback onLots;
  final VoidCallback onStalls;
  final VoidCallback onCameras;
  final VoidCallback onAnalytics;
  final VoidCallback onAlerts;
  final VoidCallback onAnnouncements;
  final VoidCallback onAudit;
  final VoidCallback onRules;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: uiCard(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: uiBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.apps_rounded, color: uiSub(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _adminText(context, 'العمليات', 'Operations'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: uiText(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              InkWell(
                onTap: onDashboard,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: uiBorder(context)),
                    color: AdminColors.primary.withOpacity(.08),
                  ),
                  child: Text(
                    _adminText(context, 'لوحة التحكم', 'Dashboard'),
                    style: TextStyle(
                      color: uiText(context),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _OpChip(
                  icon: Icons.people_alt_outlined,
                  label: _adminText(context, 'المستخدمون', 'Users'),
                  onTap: onUsers),
              _OpChip(
                  icon: Icons.map_outlined,
                  label: _adminText(context, 'المواقف', 'Lots'),
                  onTap: onLots),
              _OpChip(
                  icon: Icons.local_parking_outlined,
                  label: _adminText(context, 'الفراغات', 'Stalls'),
                  onTap: onStalls),
              _OpChip(
                  icon: Icons.videocam_outlined,
                  label: _adminText(context, 'الكاميرات', 'Cameras'),
                  onTap: onCameras),
              _OpChip(
                  icon: Icons.analytics_outlined,
                  label: _adminText(context, 'التحليلات', 'Analytics'),
                  onTap: onAnalytics),
              _OpChip(
                  icon: Icons.notifications_active_outlined,
                  label: _adminText(context, 'التنبيهات', 'Alerts'),
                  onTap: onAlerts),
              _OpChip(
                  icon: Icons.campaign_outlined,
                  label: _adminText(context, 'الإعلانات', 'Announcements'),
                  onTap: onAnnouncements),
              _OpChip(
                  icon: Icons.fact_check_outlined,
                  label: _adminText(context, 'التدقيق', 'Audit'),
                  onTap: onAudit),
              _OpChip(
                  icon: Icons.tune_rounded,
                  label: _adminText(context, 'القواعد', 'Rules'),
                  onTap: onRules),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpChip extends StatelessWidget {
  const _OpChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  String get title => label;
  String get subtitle => label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isLogoutTile = icon == Icons.logout_rounded;
    final displayTitle =
        isLogoutTile ? _adminText(context, 'تسجيل الخروج', 'Sign out') : title;
    final displaySubtitle = isLogoutTile
        ? _adminText(
            context,
            'إنهاء الجلسة والعودة للبداية',
            'End session and return to welcome',
          )
        : subtitle;
    return Tooltip(
      message: displaySubtitle,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: (dark ? AdminColors.darkCard : Colors.white)
                .withOpacity(dark ? .70 : 1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: uiBorder(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: dark ? AdminColors.primaryGlow : AdminColors.primary),
              const SizedBox(width: 8),
              Text(
                displayTitle,
                style: TextStyle(
                  color: uiText(context),
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.dark,
    required this.degraded,
    required this.title,
    required this.subtitle,
    required this.onProfile,
    required this.onTheme,
    required this.onMenu,
  });

  final bool dark;
  final bool degraded;
  final String title;
  final String subtitle;
  final VoidCallback onProfile;
  final VoidCallback onTheme;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: (dark ? AdminColors.darkCard2 : Colors.white)
                .withOpacity(dark ? .62 : .92),
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
              _IconChip(
                icon: Icons.menu_rounded,
                onTap: onMenu,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: uiText(context),
                        fontWeight: FontWeight.w900,
                        fontSize: 14.8,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Icon(
                          degraded
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 14,
                          color: degraded
                              ? AdminColors.danger
                              : AdminColors.success,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: uiSub(context),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _IconChip(
                icon: Icons.person_outline_rounded,
                onTap: onProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;
  String get title => '';
  String get subtitle => '';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isLogoutTile = icon == Icons.logout_rounded;
    final displayTitle =
        isLogoutTile ? _adminText(context, 'تسجيل الخروج', 'Sign out') : title;
    final displaySubtitle = isLogoutTile
        ? _adminText(
            context,
            'إنهاء الجلسة والعودة للبداية',
            'End session and return to welcome',
          )
        : subtitle;
    final _ = '$displayTitle$displaySubtitle';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: (dark ? Colors.white : AdminColors.primary)
              .withOpacity(dark ? .06 : .08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: uiBorder(context).withOpacity(.85)),
        ),
        child: Icon(icon, color: uiSub(context)),
      ),
    );
  }
}

class _GlassSearch extends StatelessWidget {
  const _GlassSearch({required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: (dark ? AdminColors.darkCard2 : Colors.white)
                  .withOpacity(dark ? .62 : .92),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: uiBorder(context).withOpacity(.85)),
              boxShadow: [
                BoxShadow(
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                  color: Colors.black.withOpacity(dark ? .30 : .08),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: uiSub(context)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: uiSub(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                Icon(Icons.tune_rounded, color: uiSub(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroGlass extends StatelessWidget {
  const _HeroGlass({required this.dark, required this.child});

  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = dark
        ? const [
            AdminColors.primaryDeep,
            Color(0xFF0B1E3A),
            AdminColors.primaryGlow
          ]
        : const [Color(0xFF2052A3), Color(0xFF00B7E8), Color(0xFFEAF6FF)];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
          stops: const [0, .60, 1],
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 28,
            offset: const Offset(0, 16),
            color: AdminColors.primary.withOpacity(dark ? .34 : .18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              left: -50,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(dark ? .06 : .18),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: -70,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(dark ? .05 : .14),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton(
      {required this.dark, required this.icon, required this.onTap});

  final bool dark;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(dark ? .08 : .16),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white.withOpacity(dark ? .12 : .18)),
            ),
            child: Icon(icon, color: Colors.white.withOpacity(.92)),
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill(
      {required this.dark, required this.icon, required this.text});

  final bool dark;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(dark ? .08 : .16),
            borderRadius: BorderRadius.circular(999),
            border:
                Border.all(color: Colors.white.withOpacity(dark ? .12 : .18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white.withOpacity(.95)),
              const SizedBox(width: 7),
              Text(
                text,
                style: TextStyle(
                  color: Colors.white.withOpacity(.92),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.dark,
    required this.lotId,
    required this.rollupsStream,
    required this.healthStream,
    required this.sessionsStream,
    required this.camerasStream,
    required this.lastObjectFromMap,
    required this.latestRollupForLot,
    required this.countKeys,
  });

  final bool dark;
  final String lotId;

  final Stream<DatabaseEvent> rollupsStream;
  final Stream<DatabaseEvent> healthStream;
  final Stream<DatabaseEvent> sessionsStream;
  final Stream<DatabaseEvent> camerasStream;

  final Map<String, dynamic> Function(dynamic) lastObjectFromMap;
  final Map<String, dynamic> Function(dynamic, String lotId) latestRollupForLot;
  final int Function(dynamic) countKeys;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final gap = 10.0;
        final twoCols = c.maxWidth < 520;
        final perRow = twoCols ? 2 : 4;
        final itemW = (c.maxWidth - gap * (perRow - 1)) / perRow;

        Widget box(Widget child) => SizedBox(width: itemW, child: child);

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            box(
              StreamBuilder<DatabaseEvent>(
                stream: sessionsStream,
                builder: (context, s) {
                  final c = s.hasData ? countKeys(s.data!.snapshot.value) : 0;
                  return _TinyStat(
                    dark: dark,
                    label: _adminText(context, 'النشطة', 'Active'),
                    value: '$c',
                    icon: Icons.timelapse_rounded,
                  );
                },
              ),
            ),
            box(
              StreamBuilder<DatabaseEvent>(
                stream: camerasStream,
                builder: (context, s) {
                  final c = s.hasData ? countKeys(s.data!.snapshot.value) : 0;
                  return _TinyStat(
                    dark: dark,
                    label: _adminText(context, 'الكاميرات', 'Cameras'),
                    value: '$c',
                    icon: Icons.videocam_rounded,
                  );
                },
              ),
            ),
            box(
              StreamBuilder<DatabaseEvent>(
                stream: healthStream,
                builder: (context, s) {
                  double fps = 0;
                  if (s.hasData) {
                    final last = lastObjectFromMap(s.data!.snapshot.value);
                    fps = toDouble(last['fps']);
                  }
                  return _TinyStat(
                    dark: dark,
                    label: 'FPS',
                    value: fps <= 0 ? '—' : fps.toStringAsFixed(1),
                    icon: Icons.speed_rounded,
                  );
                },
              ),
            ),
            box(
              StreamBuilder<DatabaseEvent>(
                stream: rollupsStream,
                builder: (context, s) {
                  int turnover = 0;
                  if (s.hasData) {
                    final last =
                        latestRollupForLot(s.data!.snapshot.value, lotId);
                    turnover = toInt(last['turnover']);
                  }
                  return _TinyStat(
                    dark: dark,
                    label: _adminText(context, 'التدوير', 'Turnover'),
                    value: turnover <= 0 ? '—' : '$turnover',
                    icon: Icons.swap_horiz_rounded,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TinyStat extends StatelessWidget {
  const _TinyStat({
    required this.dark,
    required this.label,
    required this.value,
    required this.icon,
  });

  final bool dark;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final bg = (dark ? AdminColors.darkCard : Colors.white)
        .withOpacity(dark ? .92 : 1);

    return Container(
      height: 78,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: uiBorder(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AdminColors.primary.withOpacity(.12),
              border: Border.all(color: AdminColors.primary.withOpacity(.20)),
            ),
            child: Icon(
              icon,
              size: 20,
              color: dark ? AdminColors.primaryGlow : AdminColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: uiSub(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 12.6,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: uiText(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    height: 1.05,
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

class _ChartsSection extends StatelessWidget {
  const _ChartsSection({
    required this.dark,
    required this.lotId,
    required this.rollupsStream,
    required this.healthSeriesStream,
    required this.rollupsForLotSorted,
    required this.valuesAsList,
  });

  final bool dark;
  final String lotId;

  final Stream<DatabaseEvent> rollupsStream;
  final Stream<DatabaseEvent> healthSeriesStream;

  final List<Map<String, dynamic>> Function(dynamic, String lotId)
      rollupsForLotSorted;
  final List<Map<String, dynamic>> Function(dynamic) valuesAsList;

  List<double> _takeLast(List<double> v, int n) {
    if (v.length <= n) return v;
    return v.sublist(v.length - n);
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = (dark ? AdminColors.darkCard : Colors.white)
        .withOpacity(dark ? .92 : 1);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 138,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: uiBorder(context)),
            ),
            child: StreamBuilder<DatabaseEvent>(
              stream: rollupsStream,
              builder: (context, s) {
                final vals = <double>[];
                if (s.hasData) {
                  final list =
                      rollupsForLotSorted(s.data!.snapshot.value, lotId);
                  for (final r in list) {
                    final occAvg = toDouble(r['occ_avg']);
                    vals.add(occAvg.clamp(0.0, 1.0));
                  }
                }
                final data = _takeLast(vals, 10);
                final latest = data.isEmpty ? 0.0 : data.last;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.stacked_bar_chart_rounded,
                            size: 16,
                            color: dark
                                ? AdminColors.primaryGlow
                                : AdminColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _adminText(
                                context, 'اتجاه الإشغال', 'Occupancy Trend'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: uiText(context),
                              fontWeight: FontWeight.w900,
                              fontSize: 12.8,
                            ),
                          ),
                        ),
                        Text(
                          data.isEmpty
                              ? '—'
                              : '${(latest * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: uiSub(context),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _SparkBars(values: data, dark: dark),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _adminText(context, 'من analytics_rollups',
                          'From analytics_rollups'),
                      style: TextStyle(
                        color: uiSub(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 138,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: uiBorder(context)),
            ),
            child: StreamBuilder<DatabaseEvent>(
              stream: healthSeriesStream,
              builder: (context, s) {
                final vals = <double>[];
                if (s.hasData) {
                  final list = valuesAsList(s.data!.snapshot.value);
                  for (final r in list) {
                    vals.add(toDouble(r['fps']));
                  }
                }
                final data = _takeLast(
                    vals.where((e) => e.isFinite && e >= 0).toList(), 12);
                final latest = data.isEmpty ? 0.0 : data.last;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.show_chart_rounded,
                            size: 16,
                            color: dark
                                ? AdminColors.primaryGlow
                                : AdminColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _adminText(
                                context, 'معدل FPS للكاميرا', 'Camera FPS'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: uiText(context),
                              fontWeight: FontWeight.w900,
                              fontSize: 12.8,
                            ),
                          ),
                        ),
                        Text(
                          data.isEmpty ? '—' : latest.toStringAsFixed(1),
                          style: TextStyle(
                            color: uiSub(context),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _SparkLine(values: data, dark: dark),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _adminText(
                          context, 'من CameraHealth', 'From CameraHealth'),
                      style: TextStyle(
                        color: uiSub(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
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

    final r =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    canvas.drawRRect(r, bgPaint);

    if (values.isEmpty) return;

    final n = values.length;
    final gap = 4.0;
    final barW = max(2.0, (size.width - gap * (n - 1)) / n);
    final maxH = size.height;

    for (int i = 0; i < n; i++) {
      final v = values[i].clamp(0.0, 1.0);
      final h = max(2.0, maxH * v);
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

    final r =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    canvas.drawRRect(r, bgPaint);

    if (values.length < 2) return;

    final clean = values.where((e) => e.isFinite).toList();
    if (clean.length < 2) return;

    double mn = clean.reduce(min);
    double mx = clean.reduce(max);
    if ((mx - mn).abs() < 1e-6) {
      mx = mn + 1.0;
    }

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

class _DatePills extends StatelessWidget {
  const _DatePills({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: i)))
        .reversed
        .toList();
    final selected = now.day;

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final d in days) ...[
                  _DayPill(day: d.day, selected: d.day == selected, dark: dark),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.calendar_month_rounded,
            color: Colors.white.withOpacity(.85)),
      ],
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill(
      {required this.day, required this.selected, required this.dark});

  final int day;
  final bool selected;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AdminColors.primary.withOpacity(dark ? .30 : .16)
        : Colors.white.withOpacity(dark ? .10 : .16);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(dark ? .14 : .18)),
        boxShadow: selected
            ? [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                  color: Colors.black.withOpacity(dark ? .25 : .10),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            color: Colors.white.withOpacity(selected ? .95 : .86),
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow(
      {required this.dark,
      required this.left,
      required this.mid,
      required this.right});

  final bool dark;
  final Widget left;
  final Widget mid;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: mid),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }
}

class _PillAction extends StatelessWidget {
  const _PillAction(
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
        decoration: BoxDecoration(
          color: (dark ? AdminColors.darkCard : Colors.white)
              .withOpacity(dark ? .92 : 1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: uiBorder(context)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon,
                color: dark ? AdminColors.primaryGlow : AdminColors.primary,
                size: 18),
            const SizedBox(width: 8),
            Expanded(
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
            Icon(_adminForwardIcon(context), color: uiSub(context)),
          ],
        ),
      ),
    );
  }
}

class _BottomDock extends StatelessWidget {
  const _BottomDock({
    required this.onHome,
    required this.onAnalytics,
    required this.onAlerts,
    required this.onSettings,
    required this.onMenu,
  });

  final VoidCallback onHome;
  final VoidCallback onAnalytics;
  final VoidCallback onAlerts;
  final VoidCallback onSettings;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: (dark ? AdminColors.darkCard2 : Colors.white)
                .withOpacity(dark ? .70 : .92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: uiBorder(context).withOpacity(.85)),
            boxShadow: [
              BoxShadow(
                blurRadius: 30,
                offset: const Offset(0, 16),
                color: Colors.black.withOpacity(dark ? .40 : .10),
              ),
            ],
          ),
          child: Row(
            children: [
              _DockIcon(icon: Icons.home_rounded, onTap: onHome),
              _DockIcon(icon: Icons.analytics_outlined, onTap: onAnalytics),
              const Spacer(),
              _DockCenter(onTap: onMenu),
              const Spacer(),
              _DockIcon(
                  icon: Icons.notifications_active_outlined, onTap: onAlerts),
              _DockIcon(icon: Icons.settings_outlined, onTap: onSettings),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockIcon extends StatelessWidget {
  const _DockIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      splashRadius: 22,
      icon: Icon(icon, color: uiSub(context)),
    );
  }
}

class _DockCenter extends StatelessWidget {
  const _DockCenter({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [AdminColors.primaryGlow, AdminColors.primary]
                : [AdminColors.primary, AdminColors.primaryGlow],
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 22,
              offset: const Offset(0, 12),
              color: AdminColors.primary.withOpacity(dark ? .34 : .18),
            ),
          ],
        ),
        child: const Icon(Icons.apps_rounded, color: Colors.white),
      ),
    );
  }
}

class _GuestModeInfoCard extends StatelessWidget {
  const _GuestModeInfoCard({
    required this.orgName,
    required this.address,
    required this.contactEmail,
    required this.contactPhone,
    required this.appSettings,
  });

  final String orgName;
  final String address;
  final String contactEmail;
  final String contactPhone;
  final Map<String, dynamic> appSettings;

  @override
  Widget build(BuildContext context) {
    final multi = toBool(appSettings['multi_language_ui']);
    final offline = toBool(appSettings['offline_cache']);
    final retry = toBool(appSettings['retry_queue']);
    final defLang = s(appSettings['default_language'], '-');
    final supported = mapOf(appSettings['supported_languages']);
    final arOn = toBool(supported['ar']);
    final enOn = toBool(supported['en']);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: uiCard(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: uiBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined,
                  color: AdminColors.primaryGlow),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  orgName.isEmpty
                      ? _adminText(context, 'الجهة', 'Organization')
                      : orgName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: uiText(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (address.trim().isNotEmpty)
            Text(
              address,
              style: TextStyle(
                color: uiSub(context),
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          if (contactEmail.trim().isNotEmpty || contactPhone.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                [
                  if (contactEmail.trim().isNotEmpty) contactEmail.trim(),
                  if (contactPhone.trim().isNotEmpty) contactPhone.trim(),
                ].join(' • '),
                style: TextStyle(
                  color: uiSub(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(_adminText(
                  context,
                  'تعدد اللغات: ${multi ? 'مفعل' : 'معطل'}',
                  'Multi-language: ${multi ? 'enabled' : 'disabled'}')),
              StatusPill(_adminText(
                  context,
                  'التخزين دون اتصال: ${offline ? 'مفعل' : 'معطل'}',
                  'Offline cache: ${offline ? 'on' : 'off'}')),
              StatusPill(_adminText(
                  context,
                  'إعادة المحاولة: ${retry ? 'مفعل' : 'معطل'}',
                  'Retry queue: ${retry ? 'on' : 'off'}')),
              StatusPill(_adminText(context, 'اللغة الافتراضية: $defLang',
                  'Default lang: $defLang')),
              StatusPill(_adminText(
                  context,
                  'العربية: ${arOn ? 'مفعلة' : 'متوقفة'}',
                  'AR: ${arOn ? 'on' : 'off'}')),
              StatusPill(_adminText(
                  context,
                  'الإنجليزية: ${enOn ? 'مفعلة' : 'متوقفة'}',
                  'EN: ${enOn ? 'on' : 'off'}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
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
    final isLogoutTile = icon == Icons.logout_rounded;
    final displayTitle =
        isLogoutTile ? _adminText(context, 'تسجيل الخروج', 'Sign out') : title;
    final displaySubtitle = isLogoutTile
        ? _adminText(
            context,
            'إنهاء الجلسة والعودة للبداية',
            'End session and return to welcome',
          )
        : subtitle;
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
              child: Icon(icon,
                  color: dark ? AdminColors.primaryGlow : AdminColors.primary,
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: uiText(context),
                      fontWeight: FontWeight.w900,
                      fontSize: 13.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displaySubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: uiSub(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(_adminForwardIcon(context), color: uiSub(context)),
          ],
        ),
      ),
    );
  }
}
