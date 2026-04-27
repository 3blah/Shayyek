import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'checknumberpin.dart';

class ForgetPage extends StatefulWidget {
  const ForgetPage({super.key});

  @override
  State<ForgetPage> createState() => _ForgetPageState();
}

class _ForgetPageState extends State<ForgetPage> {
  static const MethodChannel _platform = MethodChannel('email_channel');
  static const String _logoAsset = 'assets/logo.png';

  final TextEditingController _emailController = TextEditingController();
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isSending = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
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

  String _generateCode() {
    final r = Random.secure();
    return (100000 + r.nextInt(900000)).toString();
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>?> _findUserByEmail(String email) async {
    final snap = await _db.child('User').get();
    if (!snap.exists || snap.value == null) return null;

    final normalizedEmail = _normalizeEmail(email);

    for (final child in snap.children) {
      final row = _toMap(child.value);
      final rowEmail = _normalizeEmail((row['email'] ?? '').toString());

      if (rowEmail == normalizedEmail) {
        return {
          'key': child.key ?? '',
          'data': row,
        };
      }
    }

    return null;
  }

  Future<void> _sendResetEmail({
    required String email,
    required String code,
  }) async {
    final body = '''
<p style="margin:0 0 10px 0;">Hello,</p>
<p style="margin:0 0 12px 0;">You requested to reset your password.</p>
<p style="margin:0 0 10px 0;">Use this verification code:</p>
<div style="margin:12px 0 16px 0; padding:14px 18px; border-radius:14px; background:#f3fbff; border:1px solid #d9eef7; text-align:center;">
  <span style="font-size:30px; font-weight:800; letter-spacing:6px; color:#0B3C7A;">$code</span>
</div>
<p style="margin:0 0 10px 0;">This code will expire in 10 minutes.</p>
<p style="margin:0;">If you did not request this, you can ignore this email.</p>
''';

    try {
      await _platform.invokeMethod('sendEmail', {
        'email': email,
        'subject': 'Password reset code',
        'message': body,
      });
    } on PlatformException catch (e) {
      throw FirebaseException(
        plugin: 'email_channel',
        code: e.code,
        message: e.message ?? 'Failed to send reset email.',
      );
    }
  }

  Future<bool> _showSentDialog(String email) async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = _ForgetPalette.of(dark);

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
                    color: p.secondary.withOpacity(.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.secondary.withOpacity(.22)),
                  ),
                  child: Icon(
                    Icons.mark_email_read_rounded,
                    size: 30,
                    color: p.secondary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Code sent',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'A verification code was sent to\n$email',
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
                        'Continue',
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

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();

    final email = _normalizeEmail(_emailController.text);

    if (email.isEmpty) {
      setState(() {
        _errorText = 'Please enter your email.';
      });
      return;
    }

    final emailOk = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    if (!emailOk) {
      setState(() {
        _errorText = 'Please enter a valid email address.';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorText = null;
    });

    try {
      final found = await _findUserByEmail(email);

      if (found == null) {
        throw FirebaseException(
          plugin: 'app',
          code: 'user-not-found',
          message: 'No account found for this email.',
        );
      }

      final userId = (found['key'] ?? '').toString();
      final userRow = _toMap(found['data']);

      if (userId.isEmpty) {
        throw FirebaseException(
          plugin: 'app',
          code: 'user-not-found',
          message: 'No account found for this email.',
        );
      }

      final status = (userRow['status'] ?? 'active').toString().toLowerCase();
      if (status.isNotEmpty && status != 'active') {
        throw FirebaseException(
          plugin: 'app',
          code: 'user-disabled',
          message: 'This account is inactive.',
        );
      }

      final code = _generateCode();
      final now = DateTime.now().toUtc();
      final expiresAt = now.add(const Duration(minutes: 10));

      final resetRef = _db.child('password_resets').push();
      await resetRef.set({
        'reset_id': resetRef.key ?? '',
        'user_id': userId,
        'email': email,
        'code': code,
        'used': false,
        'created_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      });

      await _db.child('User/$userId').update({
        'last_password_reset_request_at': now.toIso8601String(),
      });

      final auditRef = _db.child('auditLogs').push();
      await auditRef.set({
        'id': auditRef.key ?? '',
        'user_id': userId,
        'action': 'password_reset_request',
        'target_type': 'auth',
        'target_id': userId,
        'ts': now.toIso8601String(),
        'device': 'android_app',
        'source': 'User',
      });

      await Future.wait([
        _sendResetEmail(email: email, code: code),
        _auth.sendPasswordResetEmail(email: email),
      ]);

      if (!mounted) return;

      setState(() {
        _isSending = false;
      });

      final goNext = await _showSentDialog(email);
      if (!mounted) return;

      if (goNext) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CheckNumberPinPage(
              email: email,
              code: code,
            ),
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = _mapError(e);
        _isSending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Something went wrong. Please try again.';
        _isSending = false;
      });
    }
  }

  String _mapError(FirebaseException e) {
    switch (e.code) {
      case 'user-not-found':
        return e.message ?? 'No account found for this email.';
      case 'user-disabled':
        return e.message ?? 'This account is inactive.';
      case 'network-error':
        return 'Network error. Check your internet connection.';
      case 'channel-error':
        return 'Email service is not available right now.';
      default:
        return e.message ?? 'Failed to send reset code.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = _ForgetPalette.of(dark);

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
                                  onPressed: () => Navigator.pop(context),
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
                                    'Forgot Password',
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
                                                    'Reset password',
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
                                                    'Get your code by email',
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
                                    'Forgot your password?',
                                    style: TextStyle(
                                      color: p.textPrimary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Enter your account email and we will send you a verification code.',
                                    style: TextStyle(
                                      color: p.textSecondary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 18),
                                  _InputField(
                                    hint: 'Email',
                                    prefix: Icons.mail_outline_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    palette: p,
                                    controller: _emailController,
                                    enabled: !_isSending,
                                    textDirection: TextDirection.ltr,
                                    enableSuggestions: false,
                                    autocorrect: false,
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
                                            _isSending ? null : _sendCode,
                                        style: TextButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        icon: _isSending
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
                                                Icons.send_rounded,
                                                size: 19,
                                                color: dark
                                                    ? const Color(0xFF04111D)
                                                    : Colors.white,
                                              ),
                                        label: Text(
                                          _isSending
                                              ? 'Sending...'
                                              : 'Send code',
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
                                      onPressed: _isSending
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
                                        'Back to login',
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
    this.keyboardType,
    this.controller,
    this.enabled = true,
    this.textDirection,
    this.enableSuggestions = true,
    this.autocorrect = true,
  });

  final String hint;
  final IconData prefix;
  final _ForgetPalette palette;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final bool enabled;
  final TextDirection? textDirection;
  final bool enableSuggestions;
  final bool autocorrect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
        textDirection: textDirection,
        enableSuggestions: enableSuggestions,
        autocorrect: autocorrect,
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
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

  final _ForgetPalette palette;

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
              'The code is sent to your registered email and expires after 10 minutes.',
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

  final _ForgetPalette palette;
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

class _ForgetPalette {
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

  const _ForgetPalette({
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

  factory _ForgetPalette.of(bool dark) {
    if (dark) {
      return const _ForgetPalette(
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

    return const _ForgetPalette(
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
