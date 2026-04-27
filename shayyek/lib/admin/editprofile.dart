// ignore_for_file: prefer_const_constructors

import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_text.dart';
import '../theme_controller.dart';
import '../welcome.dart';
import 'admin_theme.dart';
import 'admin_utils.dart';
import 'admin_widgets.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _uid = 'local_admin';
  late DatabaseReference _userRef;

  SharedPreferences? _prefs;
  bool _hasSession = false;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _role = TextEditingController();

  final FocusNode _fnName = FocusNode();
  final FocusNode _fnEmail = FocusNode();
  final FocusNode _fnPhone = FocusNode();
  final FocusNode _fnRole = FocusNode();

  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;
  bool _changingPassword = false;
  bool _settingsReady = false;

  String _themePreference = 'system';
  String _localePreference = 'system';

  String _t(String ar, String en) => AppText.of(context, ar: ar, en: en);

  @override
  void initState() {
    super.initState();
    _userRef = _db.ref('User/$_uid');

    _name.addListener(() {
      if (mounted) setState(() {});
    });
    _role.addListener(() {
      if (mounted) setState(() {});
    });

    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_settingsReady) {
      return;
    }

    final controller = ThemeScope.of(context);
    _themePreference = controller.themePreference;
    _localePreference = controller.localePreference;
    _settingsReady = true;
  }

  Future<void> _bootstrap() async {
    _prefs = await SharedPreferences.getInstance();

    final isLoggedIn = _prefs?.getBool('is_logged_in') ?? false;
    final sessionUserId = (_prefs?.getString('user_id') ?? '').trim();
    final sessionRole = (_prefs?.getString('user_role') ?? '').trim();
    final sessionName = (_prefs?.getString('user_name') ?? '').trim();
    final sessionEmail = (_prefs?.getString('user_email') ?? '').trim();

    final u = _auth.currentUser;
    final fallbackUid = (u?.uid ?? '').trim();

    _hasSession = isLoggedIn && sessionUserId.isNotEmpty;

    _uid = _hasSession
        ? sessionUserId
        : (fallbackUid.isNotEmpty ? fallbackUid : 'local_admin');

    _userRef = _db.ref('User/$_uid');

    if (sessionName.isNotEmpty) _name.text = sessionName;
    if (sessionEmail.isNotEmpty) _email.text = sessionEmail;
    if (sessionRole.isNotEmpty) _role.text = sessionRole;

    await _load();

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<String> _resolveRoleName({
    required String uid,
    required Map<String, dynamic> userRow,
  }) async {
    final directRoleId = (userRow['role_id'] ?? '').toString().trim();
    if (directRoleId.isNotEmpty) {
      final roleSnap = await _db.ref('roles/$directRoleId').get();
      final roleData = _toMap(roleSnap.value);
      final name = (roleData['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }

    try {
      final userRoleSnap = await _db.ref('user_role').get();
      if (userRoleSnap.exists && userRoleSnap.value != null) {
        String? foundRoleId;

        for (final child in userRoleSnap.children) {
          final row = _toMap(child.value);
          final rowUid = (row['user_id'] ?? '').toString().trim();
          if (rowUid == uid) {
            foundRoleId = (row['role_id'] ?? '').toString().trim();
            break;
          }
        }

        if (foundRoleId != null && foundRoleId.isNotEmpty) {
          final roleSnap = await _db.ref('roles/$foundRoleId').get();
          final roleData = _toMap(roleSnap.value);
          final name = (roleData['name'] ?? '').toString().trim();
          if (name.isNotEmpty) return name;
        }
      }
    } catch (_) {}

    final email = (userRow['email'] ?? '').toString().toLowerCase();
    if (email.contains('admin')) return 'admin';
    return 'driver';
  }

  Future<void> _load() async {
    try {
      final snap = await _userRef.get();
      if (snap.exists && snap.value != null) {
        final m = _toMap(snap.value);

        _name.text = (m['name'] ?? _name.text).toString();
        _email.text = (m['email'] ?? _email.text).toString();
        _phone.text = (m['phone'] ?? '').toString();

        final sessionRole = (_prefs?.getString('user_role') ?? '').trim();
        if (sessionRole.isNotEmpty) {
          _role.text = sessionRole;
        } else {
          final roleName = await _resolveRoleName(uid: _uid, userRow: m);
          _role.text = roleName;
          await _prefs?.setString('user_role', roleName);
        }

        if (_prefs != null) {
          await _prefs!.setString('user_id', _uid);
          await _prefs!.setString('user_name', _name.text.trim());
          await _prefs!.setString('user_email', _email.text.trim());
        }
        return;
      }

      final u = _auth.currentUser;
      if (u != null) {
        _name.text = _name.text.isNotEmpty ? _name.text : (u.displayName ?? '');
        _email.text = _email.text.isNotEmpty ? _email.text : (u.email ?? '');
        _phone.text =
            _phone.text.isNotEmpty ? _phone.text : (u.phoneNumber ?? '');
      }

      if (_role.text.trim().isEmpty) _role.text = 'driver';
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_saving || _deleting || _changingPassword) return;

    if (!_hasSession) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('تسجيل الدخول مطلوب', 'Login required'))),
        );
      }
      return;
    }

    setState(() => _saving = true);

    try {
      final controller = ThemeScope.of(context);
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final newName = _name.text.trim();
      final newEmail = _email.text.trim();
      final newPhone = _phone.text.trim();
      final payload = <String, dynamic>{
        'id': _uid,
        'name': newName,
        'phone': newPhone,
        'updated_at': nowIso,
      };

      await _userRef.update(payload);

      await _prefs?.setString('user_name', newName);
      if (_role.text.trim().isNotEmpty) {
        await _prefs?.setString('user_role', _role.text.trim());
      }

      final u = _auth.currentUser;
      String message = _t('تم حفظ الملف الشخصي', 'Profile saved');
      if (u != null) {
        if (newName.isNotEmpty && newName != (u.displayName ?? '')) {
          try {
            await u.updateDisplayName(newName);
          } catch (_) {}
        }

        final currentAuthEmail = (u.email ?? '').trim();
        if (newEmail.isNotEmpty && newEmail != currentAuthEmail) {
          try {
            await u.verifyBeforeUpdateEmail(newEmail);
            await _userRef.update({
              'email': newEmail,
              'updated_at': nowIso,
            });
            await _prefs?.setString('user_email', newEmail);
            message = _t(
              'تم حفظ الملف الشخصي. تحقق من بريدك لتأكيد بريد الدخول الجديد.',
              'Profile saved. Check your email to confirm the new login email.',
            );
          } on FirebaseAuthException catch (e) {
            message = _t(
              'تم حفظ الملف الشخصي لكن لم يتم تغيير بريد الدخول: ${_mapAuthError(e)}',
              'Profile saved, but the sign-in email was not changed: ${_mapAuthError(e)}',
            );
          }
        } else {
          await _userRef.update({
            'email': newEmail,
            'updated_at': nowIso,
          });
          await _prefs?.setString('user_email', newEmail);
        }
      } else {
        await _userRef.update({
          'email': newEmail,
          'updated_at': nowIso,
        });
        await _prefs?.setString('user_email', newEmail);
      }

      await controller.setThemePreference(_themePreference);
      await controller.setLocalePreference(_localePreference);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('فشل الحفظ', 'Save failed'))),
        );
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'requires-recent-login':
        return _t(
          'يرجى تسجيل الدخول مرة أخرى ثم إعادة المحاولة.',
          'Please sign in again, then retry.',
        );
      case 'invalid-email':
        return _t('تنسيق البريد الإلكتروني غير صحيح.', 'Invalid email format.');
      case 'email-already-in-use':
        return _t('هذا البريد مستخدم بالفعل.', 'This email is already in use.');
      case 'network-request-failed':
        return _t(
          'هناك مشكلة في الشبكة. تحقق من الاتصال.',
          'Network issue. Check your connection.',
        );
      default:
        return e.message?.trim().isNotEmpty == true
            ? e.message!.trim()
            : _t('خطأ مصادقة غير معروف.', 'Unknown auth error.');
    }
  }

  Future<_PassChangeData?> _showChangePasswordSheet() async {
    if (!_hasSession) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('تسجيل الدخول مطلوب', 'Login required'))),
        );
      }
      return null;
    }

    final email = _email.text.trim().isNotEmpty
        ? _email.text.trim()
        : (_prefs?.getString('user_email') ?? '').trim();

    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final formKey = GlobalKey<FormState>();

    _PassChangeData? result;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.55),
      builder: (ctx) {
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        bool oc1 = true;
        bool oc2 = true;
        bool oc3 = true;

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  14,
                  14,
                  14 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: (dark ? AdminColors.darkCard2 : Colors.white)
                            .withOpacity(dark ? .78 : .96),
                        borderRadius: BorderRadius.circular(26),
                        border:
                            Border.all(color: uiBorder(ctx).withOpacity(.90)),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 34,
                            offset: const Offset(0, 18),
                            color: Colors.black.withOpacity(dark ? .50 : .14),
                          ),
                        ],
                      ),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
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
                                        color: AdminColors.primary
                                            .withOpacity(.22)),
                                  ),
                                  child: Icon(
                                    Icons.lock_reset_rounded,
                                    color: dark
                                        ? AdminColors.primaryGlow
                                        : AdminColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _t('تغيير كلمة المرور',
                                            'Change password'),
                                        style: TextStyle(
                                          color: uiText(ctx),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14.8,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        email.isEmpty
                                            ? _t('الحساب', 'Account')
                                            : email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: uiSub(ctx),
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
                                      color: uiSub(ctx)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _GlassField(
                              label:
                                  _t('كلمة المرور الحالية', 'Current password'),
                              controller: current,
                              icon: Icons.password_rounded,
                              keyboardType: TextInputType.visiblePassword,
                              focusNode: FocusNode(),
                              obscureText: oc1,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? _t('مطلوب', 'Required')
                                  : null,
                              trailing: oc1
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              autofillHints: const [AutofillHints.password],
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: TextButton(
                                onPressed: () => setLocal(() => oc1 = !oc1),
                                child: Text(
                                  oc1
                                      ? _t('إظهار', 'Show')
                                      : _t('إخفاء', 'Hide'),
                                  style: TextStyle(
                                    color: dark
                                        ? AdminColors.primaryGlow
                                        : AdminColors.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            _GlassField(
                              label: _t('كلمة المرور الجديدة', 'New password'),
                              controller: next,
                              icon: Icons.lock_outline_rounded,
                              keyboardType: TextInputType.visiblePassword,
                              focusNode: FocusNode(),
                              obscureText: oc2,
                              validator: (v) {
                                final s = (v ?? '').trim();
                                if (s.isEmpty) return _t('مطلوب', 'Required');
                                if (s.length < 4) {
                                  return _t('الحد الأدنى 4 أحرف',
                                      'Minimum 4 characters');
                                }
                                return null;
                              },
                              trailing: oc2
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              autofillHints: const [AutofillHints.newPassword],
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: TextButton(
                                onPressed: () => setLocal(() => oc2 = !oc2),
                                child: Text(
                                  oc2
                                      ? _t('إظهار', 'Show')
                                      : _t('إخفاء', 'Hide'),
                                  style: TextStyle(
                                    color: dark
                                        ? AdminColors.primaryGlow
                                        : AdminColors.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            _GlassField(
                              label: _t('تأكيد كلمة المرور الجديدة',
                                  'Confirm new password'),
                              controller: confirm,
                              icon: Icons.verified_user_outlined,
                              keyboardType: TextInputType.visiblePassword,
                              focusNode: FocusNode(),
                              obscureText: oc3,
                              validator: (v) {
                                final s = (v ?? '').trim();
                                if (s.isEmpty) return _t('مطلوب', 'Required');
                                if (s != next.text.trim()) {
                                  return _t('كلمتا المرور غير متطابقتين',
                                      'Passwords do not match');
                                }
                                return null;
                              },
                              trailing: oc3
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              autofillHints: const [AutofillHints.newPassword],
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: TextButton(
                                onPressed: () => setLocal(() => oc3 = !oc3),
                                child: Text(
                                  oc3
                                      ? _t('إظهار', 'Show')
                                      : _t('إخفاء', 'Hide'),
                                  style: TextStyle(
                                    color: dark
                                        ? AdminColors.primaryGlow
                                        : AdminColors.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: _SoftButton(
                                    text: _t('إلغاء', 'Cancel'),
                                    icon: Icons.close_rounded,
                                    onTap: () => Navigator.of(ctx).pop(),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _PrimaryButton(
                                    text: _t('تحديث', 'Update'),
                                    icon: Icons.check_rounded,
                                    loading: false,
                                    onTap: () {
                                      if (!(formKey.currentState?.validate() ??
                                          false)) return;
                                      result = _PassChangeData(
                                        current: current.text.trim(),
                                        next: next.text.trim(),
                                      );
                                      Navigator.of(ctx).pop();
                                    },
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
              ),
            );
          },
        );
      },
    );

    current.dispose();
    next.dispose();
    confirm.dispose();
    return result;
  }

  Future<void> _changePassword() async {
    if (_changingPassword || _saving || _deleting) return;

    if (!_hasSession) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('تسجيل الدخول مطلوب', 'Login required'))),
        );
      }
      return;
    }

    final data = await _showChangePasswordSheet();
    if (data == null) return;

    setState(() => _changingPassword = true);

    try {
      final u = _auth.currentUser;
      final email = (u?.email ?? _email.text.trim()).trim();

      if (u == null || email.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _t(
                  'تعذر التحقق من الحساب الحالي. سجّل الدخول مرة أخرى ثم أعد المحاولة.',
                  'Unable to verify the current account. Please sign in again and try once more.',
                ),
              ),
            ),
          );
        }
        return;
      }

      final cred = EmailAuthProvider.credential(
        email: email,
        password: data.current.trim(),
      );
      await u.reauthenticateWithCredential(cred);
      await u.updatePassword(data.next.trim());
      await _userRef.update({
        'password': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_t('تم تحديث كلمة المرور', 'Password updated'))),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_mapAuthError(e))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(_t('فشل تحديث كلمة المرور', 'Password update failed'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _changingPassword = false);
      }
    }
  }

  Future<void> _clearLoginSession() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', false);
    await prefs.remove('is_logged_in');
    await prefs.remove('user_role');
    await prefs.remove('user_id');
    await prefs.remove('user_primary_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('login_mode');
  }

  Future<void> _signOut() async {
    try {
      await _clearLoginSession();
    } catch (_) {}
    try {
      await _auth.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount() async {
    if (_deleting || _saving || _changingPassword) return;

    if (!_hasSession) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('تسجيل الدخول مطلوب', 'Login required'))),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                decoration: BoxDecoration(
                  color: (dark ? AdminColors.darkCard2 : Colors.white)
                      .withOpacity(dark ? .78 : .96),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: uiBorder(ctx).withOpacity(.90)),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 34,
                      offset: const Offset(0, 18),
                      color: Colors.black.withOpacity(dark ? .50 : .14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AdminColors.danger.withOpacity(.16),
                            border: Border.all(
                                color: AdminColors.danger.withOpacity(.26)),
                          ),
                          child: const Icon(Icons.delete_forever_rounded,
                              color: AdminColors.danger),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _t('حذف الحساب؟', 'Delete account?'),
                            style: TextStyle(
                              color: uiText(ctx),
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _t(
                        'سيؤدي هذا إلى حذف الحساب وروابط الأدوار المرتبطة به نهائياً.',
                        'This will permanently remove this account and related role links.',
                      ),
                      style: TextStyle(
                        color: uiSub(ctx),
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _SoftButton(
                            text: _t('إلغاء', 'Cancel'),
                            icon: Icons.close_rounded,
                            onTap: () => Navigator.of(ctx).pop(false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DangerButton(
                            text: _t('حذف', 'Delete'),
                            icon: Icons.delete_forever_rounded,
                            loading: false,
                            onTap: () => Navigator.of(ctx).pop(true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _deleting = true);

    try {
      await _userRef.remove();
    } catch (_) {}

    try {
      final userRoleSnap = await _db.ref('user_role').get();
      if (userRoleSnap.exists && userRoleSnap.value != null) {
        for (final child in userRoleSnap.children) {
          final row = _toMap(child.value);
          final rowUid = (row['user_id'] ?? '').toString().trim();
          if (rowUid == _uid) {
            try {
              await child.ref.remove();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    try {
      await _clearLoginSession();
    } catch (_) {}

    try {
      await _auth.signOut();
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _role.dispose();
    _fnName.dispose();
    _fnEmail.dispose();
    _fnPhone.dispose();
    _fnRole.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final displayName =
        _name.text.trim().isEmpty ? _t('المستخدم', 'User') : _name.text.trim();
    final initial = displayName.substring(0, 1).toUpperCase();
    final pillText = _role.text.trim().isEmpty ? 'driver' : _role.text.trim();

    return AdminPageFrame(
      title: _t('تعديل الملف الشخصي', 'Edit Profile'),
      isDarkMode: widget.isDarkMode,
      onToggleTheme: widget.onToggleTheme,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? const [
                          Color(0xFF06121F),
                          Color(0xFF041019),
                          Color(0xFF030A10),
                        ]
                      : const [
                          Color(0xFFF4FBFF),
                          Color(0xFFF6FAFF),
                          Color(0xFFFFFFFF),
                        ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -90,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (dark ? AdminColors.primaryGlow : AdminColors.primary)
                    .withOpacity(dark ? .10 : .10),
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: -110,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    (dark ? AdminColors.primaryDeep : AdminColors.primaryGlow)
                        .withOpacity(dark ? .10 : .10),
              ),
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _ProfileHeroHeader(
                  dark: dark,
                  title: displayName,
                  subtitle: 'ID: $_uid',
                  initial: initial,
                  pillText: pillText,
                ),
                const SizedBox(height: 14),
                if (_loading) loadingBox(context),
                if (!_loading) ...[
                  if (!_hasSession)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: uiCard(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: uiBorder(context)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: uiSub(context)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _t(
                                'هذه الصفحة تعتمد على جلسة الدخول المحفوظة. يرجى تسجيل الدخول أولاً.',
                                'This page uses the saved login session. Please log in first.',
                              ),
                              style: TextStyle(
                                color: uiText(context),
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _GlassField(
                    label: _t('الاسم', 'Name'),
                    controller: _name,
                    icon: Icons.badge_outlined,
                    keyboardType: TextInputType.name,
                    focusNode: _fnName,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? _t('مطلوب', 'Required')
                        : null,
                    autofillHints: const [AutofillHints.name],
                  ),
                  _GlassField(
                    label: _t('البريد الإلكتروني', 'Email'),
                    controller: _email,
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    focusNode: _fnEmail,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? _t('مطلوب', 'Required')
                        : null,
                    autofillHints: const [AutofillHints.email],
                  ),
                  _GlassField(
                    label: _t('الهاتف', 'Phone'),
                    controller: _phone,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    focusNode: _fnPhone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                  ),
                  _GlassField(
                    label: _t('الدور', 'Role'),
                    controller: _role,
                    icon: Icons.shield_outlined,
                    keyboardType: TextInputType.text,
                    focusNode: _fnRole,
                    readOnly: true,
                    trailing: Icons.verified_user_outlined,
                    onTap: () => FocusScope.of(context).unfocus(),
                  ),
                  const SizedBox(height: 12),
                  _SectionTitle(text: _t('إعدادات التطبيق', 'App settings')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _themePreference,
                    decoration: InputDecoration(
                      labelText: _t('الثيم', 'Theme'),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'system',
                        child: Text(_t('حسب النظام', 'Follow system')),
                      ),
                      DropdownMenuItem(
                        value: 'light',
                        child: Text(_t('فاتح', 'Light')),
                      ),
                      DropdownMenuItem(
                        value: 'dark',
                        child: Text(_t('داكن', 'Dark')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _themePreference = value);
                      ThemeScope.of(context).setThemePreference(value);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _localePreference,
                    decoration: InputDecoration(
                      labelText: _t('اللغة', 'Language'),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'system',
                        child: Text(_t('لغة الجهاز', 'Device language')),
                      ),
                      DropdownMenuItem(
                        value: 'ar',
                        child: Text(_t('العربية', 'Arabic')),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(_t('الإنجليزية', 'English')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _localePreference = value);
                      ThemeScope.of(context).setLocalePreference(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _PrimaryButton(
                    text: _saving
                        ? _t('جارٍ الحفظ...', 'Saving...')
                        : _t('حفظ', 'Save'),
                    icon: Icons.save_rounded,
                    loading: _saving,
                    onTap: (!_hasSession ||
                            _saving ||
                            _deleting ||
                            _changingPassword)
                        ? null
                        : _save,
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle(text: _t('الأمان', 'Security')),
                  const SizedBox(height: 10),
                  _ActionTile(
                    title: _t('تغيير كلمة المرور', 'Change password'),
                    subtitle: _t(
                      'حدّث كلمة مرور الدخول بأمان',
                      'Update your login password securely',
                    ),
                    icon: Icons.lock_reset_rounded,
                    onTap: (!_hasSession ||
                            _saving ||
                            _deleting ||
                            _changingPassword)
                        ? null
                        : _changePassword,
                    trailing: _changingPassword
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle(text: _t('الحساب', 'Account')),
                  const SizedBox(height: 10),
                  _OutlinedAction(
                    text: _t('تسجيل الخروج', 'Sign out'),
                    icon: Icons.logout_rounded,
                    onTap: (_saving || _deleting || _changingPassword)
                        ? null
                        : _signOut,
                  ),
                  const SizedBox(height: 10),
                  _DangerButton(
                    text: _deleting
                        ? _t('جارٍ الحذف...', 'Deleting...')
                        : _t('حذف الحساب', 'Delete account'),
                    icon: Icons.delete_forever_rounded,
                    loading: _deleting,
                    onTap: (!_hasSession ||
                            _saving ||
                            _deleting ||
                            _changingPassword)
                        ? null
                        : _deleteAccount,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PassChangeData {
  const _PassChangeData({required this.current, required this.next});
  final String current;
  final String next;
}

class _ProfileHeroHeader extends StatelessWidget {
  const _ProfileHeroHeader({
    required this.dark,
    required this.title,
    required this.subtitle,
    required this.initial,
    required this.pillText,
  });

  final bool dark;
  final String title;
  final String subtitle;
  final String initial;
  final String pillText;

  @override
  Widget build(BuildContext context) {
    final colors = dark
        ? const [
            AdminColors.primaryDeep,
            Color(0xFF0B1E3A),
            AdminColors.primaryGlow,
          ]
        : const [
            Color(0xFF2052A3),
            Color(0xFF00B7E8),
            Color(0xFFEAF6FF),
          ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
          stops: const [0, .62, 1],
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 30,
            offset: const Offset(0, 16),
            color: AdminColors.primary.withOpacity(dark ? .40 : .16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              top: -46,
              left: -56,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(dark ? .06 : .18),
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: -78,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(dark ? .05 : .14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(dark ? .10 : .18),
                      border: Border.all(
                        color: Colors.white.withOpacity(dark ? .18 : .22),
                      ),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                          color: Colors.black.withOpacity(dark ? .22 : .10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.95),
                          fontWeight: FontWeight.w900,
                          fontSize: 18.5,
                          letterSpacing: .3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(.96),
                            fontWeight: FontWeight.w900,
                            fontSize: 16.2,
                            letterSpacing: .2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(.76),
                            fontWeight: FontWeight.w700,
                            fontSize: 11.6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _HeroPill(
                              icon: Icons.verified_user_outlined,
                              text: pillText,
                            ),
                          ],
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
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(dark ? .10 : .18),
            borderRadius: BorderRadius.circular(999),
            border:
                Border.all(color: Colors.white.withOpacity(dark ? .16 : .18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white.withOpacity(.96)),
              const SizedBox(width: 7),
              Text(
                text,
                style: TextStyle(
                  color: Colors.white.withOpacity(.94),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: uiText(context),
        fontWeight: FontWeight.w900,
        fontSize: 13.5,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : .55,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: (dark ? AdminColors.darkCard : Colors.white)
                .withOpacity(dark ? .86 : 1),
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
                  border:
                      Border.all(color: AdminColors.primary.withOpacity(.20)),
                ),
                child: Icon(
                  icon,
                  color: dark ? AdminColors.primaryGlow : AdminColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
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
                      subtitle,
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
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ] else ...[
                Icon(Icons.chevron_right_rounded, color: uiSub(context)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.keyboardType,
    required this.focusNode,
    this.readOnly = false,
    this.onTap,
    this.trailing,
    this.obscureText = false,
    this.validator,
    this.autofillHints,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType keyboardType;
  final FocusNode focusNode;

  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? trailing;
  final bool obscureText;
  final String? Function(String?)? validator;
  final List<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = (dark ? AdminColors.darkCard : Colors.white)
        .withOpacity(dark ? .86 : 1);

    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        final border = focused
            ? (dark ? AdminColors.primaryGlow : AdminColors.primary)
                .withOpacity(.70)
            : uiBorder(context);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                  boxShadow: focused
                      ? [
                          BoxShadow(
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                            color: (dark
                                    ? AdminColors.primaryGlow
                                    : AdminColors.primary)
                                .withOpacity(.18),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AdminColors.primary.withOpacity(.12),
                        border: Border.all(
                            color: AdminColors.primary.withOpacity(.20)),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: dark
                            ? AdminColors.primaryGlow
                            : AdminColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        readOnly: readOnly,
                        onTap: onTap,
                        obscureText: obscureText,
                        keyboardType: keyboardType,
                        autofillHints: autofillHints,
                        validator: validator,
                        style: TextStyle(
                          color: uiText(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: label,
                          hintStyle: TextStyle(
                            color: uiSub(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 13.2,
                          ),
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      Icon(trailing, color: uiSub(context), size: 18),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.text,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : .55,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [AdminColors.primaryGlow, AdminColors.primaryDeep]
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
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : .55,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: uiCard(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: uiBorder(context)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: uiText(context), size: 18),
              const SizedBox(width: 10),
              Text(
                text,
                style: TextStyle(
                  color: uiText(context),
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({
    required this.text,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : .55,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AdminColors.danger.withOpacity(.95),
                AdminColors.danger.withOpacity(.78),
              ],
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 22,
                offset: const Offset(0, 12),
                color: AdminColors.danger.withOpacity(.22),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: (dark ? AdminColors.darkCard : Colors.white)
                  .withOpacity(dark ? .70 : 1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: uiBorder(context)),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: uiText(context)),
                  const SizedBox(width: 10),
                  Text(
                    text,
                    style: TextStyle(
                      color: uiText(context),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
