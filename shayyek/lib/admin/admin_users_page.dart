import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../app_text.dart';
import 'admin_l10n.dart';
import 'admin_theme.dart';
import 'admin_utils.dart';
import 'admin_widgets.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  static Route<void> route({
    required bool isDarkMode,
    required VoidCallback onToggleTheme,
  }) {
    return MaterialPageRoute(
      builder: (_) => AdminUsersPage(
        isDarkMode: isDarkMode,
        onToggleTheme: onToggleTheme,
      ),
    );
  }

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  static const String _dbUrl = 'https://smartpasrk-default-rtdb.firebaseio.com';

  late final FirebaseDatabase _db;
  late final Stream<DatabaseEvent> _usersStream;
  late final Stream<DatabaseEvent> _userRolesStream;
  late final Stream<DatabaseEvent> _rolesStream;

  String _q = '';

  @override
  void initState() {
    super.initState();
    try {
      _db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _dbUrl,
      );
    } catch (_) {
      _db = FirebaseDatabase.instance;
    }

    _usersStream = _db.ref('User').onValue;
    _userRolesStream = _db.ref('user_role').onValue;
    _rolesStream = _db.ref('roles').onValue;
  }

  String _s(dynamic v, [String def = '']) => v?.toString() ?? def;
  String _t(String text) => adminL10n(context, text);

  String _roleLabel(String roleName) => adminL10n(context, roleName);

  String? _defaultAdminRoleId(List<_RoleItem> roles) {
    for (final role in roles) {
      final normalized = role.name.trim().toLowerCase();
      if (role.id == 'role_001' || normalized == 'admin') {
        return role.id;
      }
    }
    return roles.isEmpty ? null : roles.first.id;
  }

  String _statusLabel(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'active' || normalized == 'inactive') {
      return _t(normalized);
    }
    return _t(status);
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      title: _t('Users'),
      isDarkMode: widget.isDarkMode,
      onToggleTheme: widget.onToggleTheme,
      child: StreamBuilder<DatabaseEvent>(
        stream: _usersStream,
        builder: (context, usersSnap) {
          if (usersSnap.hasError) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [errorBox(context, () => setState(() {}))],
            );
          }
          if (!usersSnap.hasData) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [loadingBox(context)],
            );
          }

          return StreamBuilder<DatabaseEvent>(
            stream: _userRolesStream,
            builder: (context, urSnap) {
              if (urSnap.hasError) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  children: [errorBox(context, () => setState(() {}))],
                );
              }
              if (!urSnap.hasData) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  children: [loadingBox(context)],
                );
              }

              return StreamBuilder<DatabaseEvent>(
                stream: _rolesStream,
                builder: (context, roleSnap) {
                  if (roleSnap.hasError) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      children: [errorBox(context, () => setState(() {}))],
                    );
                  }
                  if (!roleSnap.hasData) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      children: [loadingBox(context)],
                    );
                  }

                  final List<MapEntry<String, dynamic>> users =
                      childEntries(usersSnap.data!.snapshot.value);
                  final List<MapEntry<String, dynamic>> userRoles =
                      childEntries(urSnap.data!.snapshot.value);
                  final List<MapEntry<String, dynamic>> roles =
                      childEntries(roleSnap.data!.snapshot.value);

                  final rolesList = roles
                      .map((e) {
                        final m = mapOf(e.value);
                        return _RoleItem(
                          key: _s(e.key),
                          id: _s(m['id'], _s(e.key)),
                          name: _s(m['name'], '-'),
                        );
                      })
                      .where((r) => r.id.isNotEmpty)
                      .toList()
                    ..sort((a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                  final roleNameById = <String, String>{};
                  for (final r in rolesList) {
                    roleNameById[r.id] = r.name;
                  }

                  final roleIdForUser = <String, String>{};
                  for (final e in userRoles) {
                    final m = mapOf(e.value);
                    final uid = _s(m['user_id']);
                    final rid = _s(m['role_id']);
                    if (uid.isEmpty) continue;
                    roleIdForUser[uid] = rid;
                  }

                  final roleNameForUser = <String, String>{};
                  for (final uid in roleIdForUser.keys) {
                    final rid = roleIdForUser[uid] ?? '';
                    final rn = roleNameById[rid];
                    final resolvedRoleName = rn == null || rn.trim().isEmpty
                        ? (rid.isEmpty ? '-' : rid)
                        : rn;
                    roleNameForUser[uid] = resolvedRoleName;
                  }

                  int admins = 0;
                  int drivers = 0;
                  for (final rn in roleNameForUser.values) {
                    final x = rn.toLowerCase().trim();
                    if (x == 'admin') admins++;
                    if (x == 'driver') drivers++;
                  }

                  final filtered = users.where((e) {
                    final m = mapOf(e.value);
                    final uid = _s(m['id'], e.key);
                    final roleName = (roleNameForUser[uid] ?? '-');
                    final text =
                        '${_s(m['name'])} ${_s(m['email'])} ${_s(m['phone'])} $roleName'
                            .toLowerCase();
                    return _q.isEmpty || text.contains(_q);
                  }).toList()
                    ..sort((a, b) {
                      final am = mapOf(a.value);
                      final bm = mapOf(b.value);
                      final an = _s(am['name']).toLowerCase();
                      final bn = _s(bm['name']).toLowerCase();
                      return an.compareTo(bn);
                    });

                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    onChanged: (v) => setState(
                                        () => _q = v.trim().toLowerCase()),
                                    decoration: InputDecoration(
                                      prefixIcon:
                                          const Icon(Icons.search_rounded),
                                      hintText: _t(
                                          'Search by name, email, phone, or role'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _AdminGradientButton(
                                  onPressed: () => _openUserEditor(
                                    context,
                                    rolesList: rolesList,
                                    allUsers: users,
                                  ),
                                  radius: 14,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  colors: const [
                                    AdminColors.primary,
                                    AdminColors.primaryGlow,
                                  ],
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.person_add_alt_1_rounded,
                                          size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        adminL10n(context, 'Add'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: StatCard(
                                    title: _t('Users'),
                                    value: '${users.length}',
                                    icon: Icons.people_alt_rounded,
                                    color: AdminColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: StatCard(
                                    title: _t('Admins'),
                                    value: '$admins',
                                    icon: Icons.admin_panel_settings_outlined,
                                    color: AdminColors.primaryGlow,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: StatCard(
                                    title: _t('Drivers'),
                                    value: '$drivers',
                                    icon: Icons.directions_car_outlined,
                                    color: AdminColors.success,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                      if (filtered.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: Center(
                              child: Text(
                                _t('No users found'),
                                style: TextStyle(color: uiSub(context)),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final e = filtered[i];
                              final m = mapOf(e.value);
                              final uid = _s(m['id'], e.key);
                              final status = _s(m['status'], 'active');
                              final roleName = roleNameForUser[uid] ?? '-';
                              final roleId = roleIdForUser[uid] ?? '';
                              final isActive = status == 'active';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: uiCard(context),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isActive
                                          ? AdminColors.success.withOpacity(.20)
                                          : uiBorder(context),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: AdminColors.primary
                                                .withOpacity(.14),
                                            child: const Icon(
                                              Icons.person_outline_rounded,
                                              color: AdminColors.primaryGlow,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _s(m['name'], '-'),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    color: uiText(context),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _s(m['email'], '-'),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: uiSub(context),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          StatusPill(_statusLabel(status)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _miniChip(
                                            context,
                                            '${_t('Role')}: ${_roleLabel(roleName)}',
                                            Icons.badge_outlined,
                                          ),
                                          if (_s(m['phone']).isNotEmpty)
                                            _miniChip(
                                              context,
                                              '${_t('Phone')}: ${_s(m['phone'])}',
                                              Icons.phone_rounded,
                                            ),
                                          _miniChip(
                                            context,
                                            '${_t('Created')}: ${dateShort(m['create'])}',
                                            Icons.calendar_today_outlined,
                                          ),
                                          _miniChip(
                                            context,
                                            '${_t('Last login')}: ${dateShort(m['login'])}',
                                            Icons.login_rounded,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: FilledButton.icon(
                                              onPressed: () =>
                                                  _toggleUser(uid, status),
                                              icon: Icon(
                                                isActive
                                                    ? Icons.block_outlined
                                                    : Icons
                                                        .check_circle_outline_rounded,
                                              ),
                                              label: Text(
                                                isActive
                                                    ? _t('Deactivate')
                                                    : _t('Activate'),
                                              ),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: isActive
                                                    ? AdminColors.danger
                                                    : AdminColors.success,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          IconButton(
                                            tooltip: _t('Edit'),
                                            onPressed: () => _openUserEditor(
                                              context,
                                              existingUid: uid,
                                              existing: m,
                                              existingRoleId: roleId,
                                              rolesList: rolesList,
                                              allUsers: users,
                                            ),
                                            icon: const Icon(
                                              Icons.edit_rounded,
                                              color: AdminColors.primaryGlow,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: _t('Delete'),
                                            onPressed: () => _deleteUser(
                                              context,
                                              uid: uid,
                                              name: _s(m['name'], uid),
                                              userRoles: userRoles,
                                            ),
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: AdminColors.danger,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: filtered.length,
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _miniChip(BuildContext context, String text, IconData icon) {
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
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: uiText(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUser(String uid, String status) async {
    final next = status == 'active' ? 'inactive' : 'active';
    try {
      await _db.ref('User/$uid/status').set(next);
      if (!mounted) return;
      await showOk(
        context,
        _t('Saved'),
        '${_t('User status updated to')} ${_statusLabel(next)}',
      );
    } catch (e) {
      if (!mounted) return;
      await showError(context, e.toString());
    }
  }

  InputDecoration _uDeco(
    BuildContext ctx, {
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final b = uiBorder(ctx);
    return InputDecoration(
      prefixIcon: Icon(icon),
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      border: UnderlineInputBorder(borderSide: BorderSide(color: b)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: b)),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AdminColors.primaryGlow, width: 2),
      ),
    );
  }

  Future<void> _openUserEditor(
    BuildContext context, {
    String? existingUid,
    Map<String, dynamic>? existing,
    String? existingRoleId,
    List<_RoleItem>? rolesList,
    List<MapEntry<String, dynamic>>? allUsers,
  }) async {
    final isEdit = existingUid != null;

    final nameCtrl =
        TextEditingController(text: isEdit ? _s(existing?['name']) : '');
    final emailCtrl =
        TextEditingController(text: isEdit ? _s(existing?['email']) : '');
    final phoneCtrl =
        TextEditingController(text: isEdit ? _s(existing?['phone']) : '');
    String status = isEdit ? _s(existing?['status'], 'active') : 'active';

    final roles = rolesList ?? <_RoleItem>[];
    String? roleId = isEdit
        ? (existingRoleId?.trim().isEmpty == true ? null : existingRoleId)
        : null;
    final defaultAdminRoleId = _defaultAdminRoleId(roles);

    if (roles.isNotEmpty) {
      final exists = roleId != null && roles.any((r) => r.id == roleId);
      if (exists) {
        roleId = roleId;
      } else {
        roleId = defaultAdminRoleId;
      }
    } else {
      roleId = null;
    }

    final formKey = GlobalKey<FormState>();

    Future<bool> isEmailUnique(String email, {String? ignoreUid}) async {
      final x = email.trim().toLowerCase();
      if (x.isEmpty) return true;
      final users = allUsers ?? [];
      for (final e in users) {
        final m = mapOf(e.value);
        final uid = _s(m['id'], e.key);
        if (ignoreUid != null && uid == ignoreUid) continue;
        if (_s(m['email']).trim().toLowerCase() == x) return false;
      }
      return true;
    }

    String? validateName(String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return 'Name is required';
      if (t.length < 2) return 'Name is too short';
      return null;
    }

    String? validateEmail(String? v) {
      final t = (v ?? '').trim().toLowerCase();
      if (t.isEmpty) return 'Email is required';
      final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t);
      if (!ok) return 'Invalid email format';
      return null;
    }

    String? validatePhone(String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return null;
      final ok = RegExp(r'^\+?[0-9]{7,15}$').hasMatch(t);
      if (!ok) return 'Invalid phone (use digits, optional +)';
      return null;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final dangerBg = Theme.of(ctx).brightness == Brightness.dark
            ? Colors.black.withOpacity(.55)
            : Colors.black.withOpacity(.35);

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {},
                child: Container(color: dangerBg),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Dialog(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  insetPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: uiCard(ctx),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: uiBorder(ctx)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.18),
                          blurRadius: 26,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AdminColors.primary.withOpacity(.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                isEdit
                                    ? Icons.manage_accounts_rounded
                                    : Icons.person_add_alt_1_rounded,
                                color: AdminColors.primaryGlow,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isEdit ? 'Edit User' : 'Add User',
                                style: TextStyle(
                                  color: uiText(ctx),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: _t('Close'),
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon:
                                  Icon(Icons.close_rounded, color: uiSub(ctx)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Form(
                          key: formKey,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFormField(
                                  controller: nameCtrl,
                                  validator: validateName,
                                  textInputAction: TextInputAction.next,
                                  decoration: _uDeco(
                                    ctx,
                                    label: _t('Name'),
                                    hint: AppText.of(
                                      context,
                                      ar: 'الاسم الكامل',
                                      en: 'Full name',
                                    ),
                                    icon: Icons.person_outline_rounded,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: emailCtrl,
                                  validator: validateEmail,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: _uDeco(
                                    ctx,
                                    label: _t('Email'),
                                    hint: 'name@example.com',
                                    icon: Icons.alternate_email_rounded,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: phoneCtrl,
                                  validator: validatePhone,
                                  keyboardType: TextInputType.phone,
                                  decoration: _uDeco(
                                    ctx,
                                    label: AppText.of(
                                      context,
                                      ar: 'الهاتف (اختياري)',
                                      en: 'Phone (optional)',
                                    ),
                                    hint: '+9665XXXXXXXX',
                                    icon: Icons.phone_rounded,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  value: roleId,
                                  items: roles.isEmpty
                                      ? [
                                          DropdownMenuItem<String>(
                                            value: null,
                                            child: Text(
                                              AppText.of(
                                                context,
                                                ar: 'لا توجد أدوار',
                                                en: 'No roles found',
                                              ),
                                            ),
                                          )
                                        ]
                                      : roles
                                          .map(
                                            (r) => DropdownMenuItem<String>(
                                              value: r.id,
                                              child: Text(_roleLabel(r.name)),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      roles.isEmpty ? null : (v) => roleId = v,
                                  decoration: _uDeco(
                                    ctx,
                                    label: _t('Role'),
                                    hint: AppText.of(
                                      context,
                                      ar: 'اختر الدور',
                                      en: 'Select role',
                                    ),
                                    icon: Icons.badge_outlined,
                                  ),
                                  validator: (v) {
                                    if (roles.isEmpty) {
                                      return AppText.of(
                                        context,
                                        ar: 'لا توجد أدوار في قاعدة البيانات',
                                        en: 'No roles found in database',
                                      );
                                    }
                                    if (v == null || v.trim().isEmpty) {
                                      return AppText.of(
                                        context,
                                        ar: 'الدور مطلوب',
                                        en: 'Role is required',
                                      );
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  value: status,
                                  items: [
                                    DropdownMenuItem(
                                      value: 'active',
                                      child: Text(_t('active')),
                                    ),
                                    DropdownMenuItem(
                                      value: 'inactive',
                                      child: Text(_t('inactive')),
                                    ),
                                  ],
                                  onChanged: (v) => status = v ?? 'active',
                                  decoration: _uDeco(
                                    ctx,
                                    label: _t('Status'),
                                    hint: AppText.of(
                                      context,
                                      ar: 'اختر الحالة',
                                      en: 'Select status',
                                    ),
                                    icon: Icons.verified_user_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: uiText(ctx),
                                  side: BorderSide(color: uiBorder(ctx)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  AppText.of(context,
                                      ar: 'إلغاء', en: 'Cancel'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _AdminGradientButton(
                                onPressed: () async {
                                  final ok =
                                      formKey.currentState?.validate() ?? false;
                                  if (!ok) return;

                                  final email =
                                      emailCtrl.text.trim().toLowerCase();
                                  final unique = await isEmailUnique(
                                    email,
                                    ignoreUid: existingUid,
                                  );
                                  if (!unique) {
                                    if (!ctx.mounted) return;
                                    await showError(
                                      ctx,
                                      AppText.of(
                                        context,
                                        ar: 'هذا البريد مستخدم بالفعل من مستخدم آخر.',
                                        en: 'This email is already used by another user.',
                                      ),
                                    );
                                    return;
                                  }

                                  final name = nameCtrl.text.trim();
                                  final phone = phoneCtrl.text.trim();

                                  final now =
                                      DateTime.now().toUtc().toIso8601String();
                                  final uid =
                                      existingUid ?? _db.ref('User').push().key;

                                  if (uid == null || uid.isEmpty) {
                                    if (!ctx.mounted) return;
                                    await showError(
                                      ctx,
                                      AppText.of(
                                        context,
                                        ar: 'تعذر إنشاء معرف المستخدم.',
                                        en: 'Failed to generate user id.',
                                      ),
                                    );
                                    return;
                                  }

                                  final payload = <String, dynamic>{
                                    'id': uid,
                                    'name': name,
                                    'email': email,
                                    'phone': phone,
                                    'status': status,
                                    'create': isEdit
                                        ? _s(existing?['create'], now)
                                        : now,
                                    'login': isEdit
                                        ? _s(existing?['login'], '')
                                        : '',
                                  };

                                  try {
                                    await _db.ref('User/$uid').update(payload);
                                    final rid = (roleId ?? '').trim();
                                    if (rid.isNotEmpty) {
                                      await _upsertUserRole(
                                          uid: uid, roleId: rid);
                                    }
                                    if (!ctx.mounted) return;
                                    Navigator.of(ctx).pop();
                                    if (!mounted) return;
                                    await showOk(
                                      context,
                                      _t('Saved'),
                                      isEdit
                                          ? AppText.of(
                                              context,
                                              ar: 'تم تحديث المستخدم بنجاح.',
                                              en: 'User updated successfully.',
                                            )
                                          : AppText.of(
                                              context,
                                              ar: 'تمت إضافة المستخدم بنجاح.',
                                              en: 'User added successfully.',
                                            ),
                                    );
                                  } catch (e) {
                                    if (!ctx.mounted) return;
                                    await showError(ctx, e.toString());
                                  }
                                },
                                radius: 14,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                colors: const [
                                  AdminColors.primary,
                                  AdminColors.primaryGlow,
                                ],
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.save_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppText.of(
                                        context,
                                        ar: 'حفظ',
                                        en: 'Save',
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _upsertUserRole(
      {required String uid, required String roleId}) async {
    final snap = await _db.ref('user_role').get();
    final list = childEntries(snap.value);

    String? existingKey;
    for (final e in list) {
      final m = mapOf(e.value);
      if (_s(m['user_id']) == uid) {
        existingKey = _s(e.key);
        break;
      }
    }

    if (existingKey != null && existingKey.isNotEmpty) {
      await _db.ref('user_role/$existingKey').update({
        'user_id': uid,
        'role_id': roleId,
      });
      return;
    }

    final k = _db.ref('user_role').push().key;
    if (k == null || k.isEmpty) return;
    await _db.ref('user_role/$k').set({
      'user_id': uid,
      'role_id': roleId,
    });
  }

  Future<void> _deleteUser(
    BuildContext context, {
    required String uid,
    required String name,
    required List<MapEntry<String, dynamic>> userRoles,
  }) async {
    final ok = await _confirm(
      context,
      title: _t('Delete user?'),
      message: AppText.of(
        context,
        ar: 'سيتم حذف "$name" نهائياً مع ربط الدور الخاص به.',
        en: 'This will permanently delete "$name" and its role mapping.',
      ),
      danger: true,
      okText: _t('Delete'),
    );
    if (ok != true) return;

    final updates = <String, dynamic>{};
    updates['User/$uid'] = null;

    for (final e in userRoles) {
      final m = mapOf(e.value);
      if (_s(m['user_id']) == uid) {
        final k = _s(e.key);
        if (k.isNotEmpty) updates['user_role/$k'] = null;
      }
    }

    try {
      await _db.ref().update(updates);
      if (!mounted) return;
      await showOk(
        context,
        _t('Deleted'),
        AppText.of(
          context,
          ar: 'تم حذف المستخدم بنجاح.',
          en: 'User deleted successfully.',
        ),
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
      barrierDismissible: false,
      builder: (ctx) {
        final overlay = Theme.of(ctx).brightness == Brightness.dark
            ? Colors.black.withOpacity(.55)
            : Colors.black.withOpacity(.35);

        final colors = danger
            ? [
                AdminColors.danger,
                AdminColors.danger.withOpacity(.85),
              ]
            : const [
                AdminColors.primary,
                AdminColors.primaryGlow,
              ];

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {},
                child: Container(color: overlay),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Dialog(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  insetPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: uiCard(ctx),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: uiBorder(ctx)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.18),
                          blurRadius: 26,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: (danger
                                        ? AdminColors.danger
                                        : AdminColors.primary)
                                    .withOpacity(.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                danger
                                    ? Icons.warning_amber_rounded
                                    : Icons.help_outline_rounded,
                                color: danger
                                    ? AdminColors.danger
                                    : AdminColors.primaryGlow,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  color: uiText(ctx),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: _t('Close'),
                              onPressed: () => Navigator.of(ctx).pop(false),
                              icon:
                                  Icon(Icons.close_rounded, color: uiSub(ctx)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            message,
                            style: TextStyle(color: uiSub(ctx)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: uiText(ctx),
                                  side: BorderSide(color: uiBorder(ctx)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  _t('Cancel'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _AdminGradientButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                radius: 14,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                colors: colors,
                                child: Text(
                                  okText,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RoleItem {
  final String key;
  final String id;
  final String name;
  const _RoleItem({required this.key, required this.id, required this.name});
}

class _AdminGradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final List<Color> colors;
  final double radius;
  final EdgeInsets padding;

  const _AdminGradientButton({
    required this.onPressed,
    required this.child,
    required this.colors,
    this.radius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? .55 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: colors,
              ),
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withOpacity(.28),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: padding,
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                child: IconTheme(
                  data: const IconThemeData(color: Colors.white),
                  child: Center(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
