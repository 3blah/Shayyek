import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'login.dart';

class RestPasswordPage extends StatefulWidget {
  const RestPasswordPage({
    super.key,
    required this.email,
    required this.resetId,
  });

  final String email;
  final String resetId;

  @override
  State<RestPasswordPage> createState() => _RestPasswordPageState();
}

class _RestPasswordPageState extends State<RestPasswordPage> {
  static const String _logoAsset = 'assets/logo.png';

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _normalizeEmail(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E\u2066-\u2069]'), '')
        .replaceAll('\u00A0', ' ')
        .replaceAll(' ', '')
        .toLowerCase();
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  Future<Map<String, dynamic>?> _findUserByEmail(String email) async {
    final snap = await _db.child('User').get();
    if (!snap.exists || snap.value == null) return null;

    final normalizedEmail = _normalizeEmail(email);
    Map<String, dynamic>? best;
    var bestScore = -1;

    for (final child in snap.children) {
      final row = _toMap(child.value);
      final rowEmail = _normalizeEmail((row['email'] ?? '').toString());

      if (rowEmail == normalizedEmail) {
        var score = 0;
        if ((row['status'] ?? 'active').toString().toLowerCase() == 'active') {
          score += 10;
        }
        if ((row['auth_uid'] ?? '').toString().trim().isNotEmpty) {
          score += 20;
        }
        if ((child.key ?? '').startsWith('user_')) {
          score -= 5;
        }
        final candidate = {
          'key': child.key ?? '',
          'data': row,
        };
        if (score > bestScore) {
          bestScore = score;
          best = candidate;
        }
      }
    }

    return best;
  }

  String? _validatePassword(String password, String confirmPassword) {
    if (password.isEmpty || confirmPassword.isEmpty) {
      return 'Please enter the new password.';
    }

    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    if (password != confirmPassword) {
      return 'Passwords do not match.';
    }

    return null;
  }

  Future<bool> _showSuccessDialog({required bool passwordUpdated}) async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = _RestPasswordPalette.of(dark);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.border),
              boxShadow: [
                BoxShadow(
                  color: p.shadow.withOpacity(dark ? .24 : .08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: p.available.withOpacity(.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.available.withOpacity(.22)),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 30,
                    color: p.available,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  passwordUpdated ? 'Password updated' : 'Reset link sent',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  passwordUpdated
                      ? 'Your password has been changed successfully.'
                      : 'For security, Firebase sent an official password reset link to your email. Use that link to set the new password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.textSecondary,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [p.primary, p.secondary],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        'Go to login',
                        style: TextStyle(
                          color: dark ? const Color(0xFF04111D) : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return result == true;
  }

  Future<void> _savePassword() async {
    FocusScope.of(context).unfocus();

    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final validation = _validatePassword(password, confirmPassword);

    if (validation != null) {
      setState(() {
        _errorText = validation;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final resetSnap =
          await _db.child('password_resets/${widget.resetId}').get();

      if (!resetSnap.exists || resetSnap.value == null) {
        throw FirebaseException(
          plugin: 'app',
          code: 'reset-not-found',
          message: 'Reset request not found.',
        );
      }

      final resetRow = _toMap(resetSnap.value);
      final resetEmail = _normalizeEmail((resetRow['email'] ?? '').toString());
      final requestEmail = _normalizeEmail(widget.email);
      final verifiedAt = _parseDate(resetRow['verified_at']);
      final expiresAt = _parseDate(resetRow['expires_at'])?.toUtc();
      final completedAt = _parseDate(resetRow['completed_at']);
      final used = (resetRow['used'] ?? false) == true;

      if (resetEmail != requestEmail) {
        throw FirebaseException(
          plugin: 'app',
          code: 'invalid-reset',
          message: 'This reset request does not belong to this email.',
        );
      }

      if (!used || verifiedAt == null) {
        throw FirebaseException(
          plugin: 'app',
          code: 'not-verified',
          message: 'Please verify the code first.',
        );
      }

      if (completedAt != null) {
        throw FirebaseException(
          plugin: 'app',
          code: 'already-completed',
          message: 'This reset request has already been used.',
        );
      }

      if (expiresAt == null || expiresAt.isBefore(DateTime.now().toUtc())) {
        throw FirebaseException(
          plugin: 'app',
          code: 'expired',
          message: 'This reset request has expired.',
        );
      }

      String userId = (resetRow['user_id'] ?? '').toString();

      if (userId.isEmpty) {
        final foundUser = await _findUserByEmail(widget.email);
        if (foundUser == null) {
          throw FirebaseException(
            plugin: 'app',
            code: 'user-not-found',
            message: 'No account found for this email.',
          );
        }
        userId = (foundUser['key'] ?? '').toString();
      }

      final userSnap = await _db.child('User/$userId').get();

      if (!userSnap.exists || userSnap.value == null) {
        throw FirebaseException(
          plugin: 'app',
          code: 'user-not-found',
          message: 'No account found for this email.',
        );
      }

      final userRow = _toMap(userSnap.value);
      final userStatus =
          (userRow['status'] ?? 'active').toString().toLowerCase();

      if (userStatus.isNotEmpty && userStatus != 'active') {
        throw FirebaseException(
          plugin: 'app',
          code: 'user-disabled',
          message: 'This account is inactive.',
        );
      }

      final now = DateTime.now().toUtc();
      var firebasePasswordUpdated = false;
      var firebaseResetEmailSent = false;

      final currentAuthUser = _auth.currentUser;
      final currentAuthEmail =
          _normalizeEmail(currentAuthUser?.email?.toString() ?? '');
      if (currentAuthUser != null && currentAuthEmail == requestEmail) {
        try {
          await currentAuthUser.updatePassword(password);
          await currentAuthUser.reload();
          firebasePasswordUpdated = true;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login' ||
              e.code == 'user-token-expired') {
            await _auth.sendPasswordResetEmail(email: requestEmail);
            firebaseResetEmailSent = true;
          } else {
            rethrow;
          }
        }
      } else {
        await _auth.sendPasswordResetEmail(email: requestEmail);
        firebaseResetEmailSent = true;
      }

      final userUpdate = <String, dynamic>{
        'password': null,
      };
      if (firebasePasswordUpdated) {
        userUpdate['password_updated_at'] = now.toIso8601String();
      } else {
        userUpdate['password_reset_link_sent_at'] = now.toIso8601String();
      }

      await _db.child('User/$userId').update(userUpdate);

      await _db.child('password_resets/${widget.resetId}').update({
        'completed_at': now.toIso8601String(),
        'password_changed': firebasePasswordUpdated,
        'firebase_reset_email_sent': firebaseResetEmailSent,
      });

      final auditRef = _db.child('auditLogs').push();
      await auditRef.set({
        'id': auditRef.key ?? '',
        'user_id': userId,
        'action': 'password_reset_complete',
        'target_type': 'auth',
        'target_id': widget.resetId,
        'ts': now.toIso8601String(),
        'device': 'android_app',
        'source': 'password_resets',
      });

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      if (firebasePasswordUpdated && _auth.currentUser != null) {
        await _auth.signOut();
      }

      final goLogin =
          await _showSuccessDialog(passwordUpdated: firebasePasswordUpdated);
      if (!mounted) return;

      if (goLogin) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorText = e.message ?? 'Failed to update password.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorText = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = _RestPasswordPalette.of(dark);

    return Scaffold(
      backgroundColor: p.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: p.border),
                  boxShadow: [
                    BoxShadow(
                      color: p.shadow.withOpacity(dark ? 0.22 : 0.08),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _GridBgPainter(
                            lineColor:
                                p.gridLine.withOpacity(dark ? 0.12 : 0.08),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -70,
                        right: -40,
                        child: Container(
                          width: 210,
                          height: 210,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.secondary.withOpacity(dark ? 0.12 : 0.08),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -20,
                        left: -40,
                        child: Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.primary.withOpacity(dark ? 0.14 : 0.07),
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            height: 96,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [p.primary, p.primary2],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: p.border.withOpacity(.55),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: _isSaving
                                      ? null
                                      : () => Navigator.pop(context),
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        Colors.white.withOpacity(.10),
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(.12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(.10),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(.12),
                                    ),
                                  ),
                                  child: const Text(
                                    'New Password',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 10, 18, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    height: 124,
                                    decoration: BoxDecoration(
                                      color: p.surfaceAlt,
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(color: p.border),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          right: -18,
                                          top: -10,
                                          child: Container(
                                            width: 82,
                                            height: 82,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color:
                                                  p.secondary.withOpacity(0.09),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: -16,
                                          bottom: -12,
                                          child: Container(
                                            width: 72,
                                            height: 72,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color:
                                                  p.primary.withOpacity(0.07),
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 72,
                                                height: 72,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      p.primary,
                                                      p.secondary
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: p.secondary
                                                          .withOpacity(.18),
                                                      blurRadius: 14,
                                                      offset:
                                                          const Offset(0, 8),
                                                    ),
                                                  ],
                                                ),
                                                padding:
                                                    const EdgeInsets.all(8),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Image.asset(
                                                    _logoAsset,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (_, __, ___) {
                                                      return Container(
                                                        color: Colors.white
                                                            .withOpacity(.08),
                                                        child: Icon(
                                                          Icons
                                                              .lock_reset_rounded,
                                                          color: p.accent,
                                                          size: 34,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Create password',
                                                    style: TextStyle(
                                                      color: p.textPrimary,
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: .2,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Secure your account',
                                                    style: TextStyle(
                                                      color: p.textSecondary,
                                                      fontSize: 11.7,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Set a new password',
                                    style: TextStyle(
                                      color: p.textPrimary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.email,
                                    style: TextStyle(
                                      color: p.textSecondary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 18),
                                  _InputField(
                                    hint: 'New password',
                                    prefix: Icons.lock_outline_rounded,
                                    obscure: _obscurePassword,
                                    palette: p,
                                    controller: _passwordController,
                                    enabled: !_isSaving,
                                    suffix: IconButton(
                                      onPressed: _isSaving
                                          ? null
                                          : () {
                                              setState(() {
                                                _obscurePassword =
                                                    !_obscurePassword;
                                              });
                                            },
                                      splashRadius: 20,
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: p.iconMuted,
                                        size: 19,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _InputField(
                                    hint: 'Confirm password',
                                    prefix: Icons.verified_user_outlined,
                                    obscure: _obscureConfirmPassword,
                                    palette: p,
                                    controller: _confirmPasswordController,
                                    enabled: !_isSaving,
                                    suffix: IconButton(
                                      onPressed: _isSaving
                                          ? null
                                          : () {
                                              setState(() {
                                                _obscureConfirmPassword =
                                                    !_obscureConfirmPassword;
                                              });
                                            },
                                      splashRadius: 20,
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: p.iconMuted,
                                        size: 19,
                                      ),
                                    ),
                                  ),
                                  if (_errorText != null) ...[
                                    const SizedBox(height: 12),
                                    _ErrorNotice(
                                      palette: p,
                                      text: _errorText!,
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    height: 52,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [p.primary, p.secondary],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: p.secondary.withOpacity(
                                              dark ? .22 : .10,
                                            ),
                                            blurRadius: 16,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: TextButton.icon(
                                        onPressed:
                                            _isSaving ? null : _savePassword,
                                        style: TextButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        icon: _isSaving
                                            ? SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    dark
                                                        ? const Color(
                                                            0xFF04111D)
                                                        : Colors.white,
                                                  ),
                                                ),
                                              )
                                            : Icon(
                                                Icons.save_rounded,
                                                size: 19,
                                                color: dark
                                                    ? const Color(0xFF04111D)
                                                    : Colors.white,
                                              ),
                                        label: Text(
                                          _isSaving
                                              ? 'Saving...'
                                              : 'Update password',
                                          style: TextStyle(
                                            color: dark
                                                ? const Color(0xFF04111D)
                                                : Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 50,
                                    child: OutlinedButton.icon(
                                      onPressed: _isSaving
                                          ? null
                                          : () => Navigator.pop(context),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: p.borderStrong),
                                        backgroundColor: p.surfaceAlt,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      icon: Icon(
                                        Icons.arrow_back_rounded,
                                        size: 19,
                                        color: p.primary,
                                      ),
                                      label: Text(
                                        'Back',
                                        style: TextStyle(
                                          color: p.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _InfoNotice(palette: p),
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
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.hint,
    required this.prefix,
    required this.palette,
    this.obscure = false,
    this.suffix,
    this.controller,
    this.enabled = true,
  });

  final String hint;
  final IconData prefix;
  final _RestPasswordPalette palette;
  final bool obscure;
  final Widget? suffix;
  final TextEditingController? controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        enabled: enabled,
        enableSuggestions: false,
        autocorrect: false,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: palette.surfaceAlt,
          hintText: hint,
          hintStyle: TextStyle(
            color: palette.textSecondary.withOpacity(.92),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(prefix, color: palette.primary, size: 19),
          suffixIcon: suffix,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: palette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: palette.secondary, width: 1.2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: palette.border),
          ),
        ),
      ),
    );
  }
}

class _InfoNotice extends StatelessWidget {
  const _InfoNotice({required this.palette});

  final _RestPasswordPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.primary.withOpacity(.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.primary.withOpacity(.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: palette.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Use a strong password with at least 6 characters.',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11.8,
                fontWeight: FontWeight.w600,
                height: 1.28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({
    required this.palette,
    required this.text,
  });

  final _RestPasswordPalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.occupied.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.occupied.withOpacity(.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: palette.occupied),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 12.1,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridBgPainter extends CustomPainter {
  const _GridBgPainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    const step = 22.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _GridBgPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}

class _RestPasswordPalette {
  final Color pageBg;
  final Color card;
  final Color surfaceAlt;
  final Color border;
  final Color borderStrong;
  final Color shadow;
  final Color primary;
  final Color primary2;
  final Color secondary;
  final Color accent;
  final Color available;
  final Color occupied;
  final Color textPrimary;
  final Color textSecondary;
  final Color iconMuted;
  final Color gridLine;

  const _RestPasswordPalette({
    required this.pageBg,
    required this.card,
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.shadow,
    required this.primary,
    required this.primary2,
    required this.secondary,
    required this.accent,
    required this.available,
    required this.occupied,
    required this.textPrimary,
    required this.textSecondary,
    required this.iconMuted,
    required this.gridLine,
  });

  factory _RestPasswordPalette.of(bool dark) {
    if (dark) {
      return const _RestPasswordPalette(
        pageBg: Color(0xFF07111F),
        card: Color(0xFF0E1C2F),
        surfaceAlt: Color(0xFF12243A),
        border: Color(0xFF1E3550),
        borderStrong: Color(0xFF2A4A6F),
        shadow: Color(0xFF000000),
        primary: Color(0xFF0B3C7A),
        primary2: Color(0xFF123A6E),
        secondary: Color(0xFF19D3FF),
        accent: Color(0xFF8BEF3F),
        available: Color(0xFF22C55E),
        occupied: Color(0xFFEF4444),
        textPrimary: Color(0xFFEAF4FF),
        textSecondary: Color(0xFF9FB3C8),
        iconMuted: Color(0xFFB8CAE0),
        gridLine: Color(0xFF2A4360),
      );
    }

    return const _RestPasswordPalette(
      pageBg: Color(0xFFF6FAFF),
      card: Color(0xFFFFFFFF),
      surfaceAlt: Color(0xFFF8FBFF),
      border: Color(0xFFD7E4F2),
      borderStrong: Color(0xFFBFD2E6),
      shadow: Color(0xFF0F172A),
      primary: Color(0xFF0B3C7A),
      primary2: Color(0xFF2052A3),
      secondary: Color(0xFF00B7E8),
      accent: Color(0xFF65C92F),
      available: Color(0xFF16A34A),
      occupied: Color(0xFFDC2626),
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF475569),
      iconMuted: Color(0xFF64748B),
      gridLine: Color(0xFFDCE8F6),
    );
  }
}
