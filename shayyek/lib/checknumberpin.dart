import 'dart:async';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'restpassword.dart';

class CheckNumberPinPage extends StatefulWidget {
  const CheckNumberPinPage({
    super.key,
    required this.email,
    this.code,
  });

  final String email;
  final String? code;

  @override
  State<CheckNumberPinPage> createState() => _CheckNumberPinPageState();
}

class _CheckNumberPinPageState extends State<CheckNumberPinPage> {
  static const MethodChannel _platform = MethodChannel('email_channel');
  static const String _logoAsset = 'assets/logo.png';

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorText;

  Timer? _timer;
  int _secondsLeft = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
        });
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
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

  String get _enteredCode => _controllers.map((e) => e.text).join();

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

  void _clearCode() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
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

  Future<Map<String, dynamic>?> _findLatestValidReset({
    required String email,
    required String code,
  }) async {
    final snap = await _db.child('password_resets').get();
    if (!snap.exists || snap.value == null) return null;

    final normalizedEmail = _normalizeEmail(email);
    final now = DateTime.now().toUtc();

    Map<String, dynamic>? best;
    DateTime? bestCreatedAt;

    for (final child in snap.children) {
      final row = _toMap(child.value);
      final rowEmail = _normalizeEmail((row['email'] ?? '').toString());
      final rowCode = (row['code'] ?? '').toString().trim();
      final used = (row['used'] ?? false) == true;
      final expiresAt = _parseDate(row['expires_at'])?.toUtc();
      final createdAt = _parseDate(row['created_at'])?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0);

      if (rowEmail != normalizedEmail) continue;
      if (rowCode != code) continue;
      if (used) continue;
      if (expiresAt == null || expiresAt.isBefore(now)) continue;

      if (best == null || createdAt.isAfter(bestCreatedAt!)) {
        best = {
          'key': child.key ?? '',
          'data': row,
        };
        bestCreatedAt = createdAt;
      }
    }

    return best;
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

    await _platform.invokeMethod('sendEmail', {
      'email': email,
      'subject': 'Password reset code',
      'message': body,
    });
  }

  Future<void> _resendCode() async {
    if (_secondsLeft > 0 || _isResending || _isVerifying) return;

    setState(() {
      _isResending = true;
      _errorText = null;
    });

    try {
      final email = _normalizeEmail(widget.email);
      final user = await _findUserByEmail(email);

      if (user == null) {
        throw FirebaseException(
          plugin: 'app',
          code: 'user-not-found',
          message: 'No account found for this email.',
        );
      }

      final userId = (user['key'] ?? '').toString();
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
        'action': 'password_reset_resend',
        'target_type': 'auth',
        'target_id': userId,
        'ts': now.toIso8601String(),
        'device': 'android_app',
        'source': 'User',
      });

      await _sendResetEmail(email: email, code: code);

      _clearCode();
      _startTimer();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new code has been sent to your email.'),
        ),
      );

      setState(() {
        _isResending = false;
      });
    } on PlatformException catch (_) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _errorText = 'Failed to send email. Please try again.';
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _errorText = e.message ?? 'Failed to resend the code.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _errorText = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _verifyCode() async {
    FocusScope.of(context).unfocus();

    final code = _enteredCode.trim();

    if (code.length != 6) {
      setState(() {
        _errorText = 'Please enter the 6-digit code.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    try {
      final result = await _findLatestValidReset(
        email: widget.email,
        code: code,
      );

      if (result == null) {
        throw FirebaseException(
          plugin: 'app',
          code: 'invalid-code',
          message: 'The code is invalid or expired.',
        );
      }

      final resetId = (result['key'] ?? '').toString();
      final row = _toMap(result['data']);
      final userId = (row['user_id'] ?? '').toString();

      final now = DateTime.now().toUtc();

      await _db.child('password_resets/$resetId').update({
        'used': true,
        'verified_at': now.toIso8601String(),
      });

      final auditRef = _db.child('auditLogs').push();
      await auditRef.set({
        'id': auditRef.key ?? '',
        'user_id': userId,
        'action': 'password_reset_verify_code',
        'target_type': 'auth',
        'target_id': resetId,
        'ts': now.toIso8601String(),
        'device': 'android_app',
        'source': 'password_resets',
      });

      if (!mounted) return;

      setState(() {
        _isVerifying = false;
      });

      final goNext = await _showVerifiedDialog();
      if (!mounted) return;

      if (goNext) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RestPasswordPage(
              email: widget.email,
              resetId: resetId,
            ),
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorText = e.message ?? 'Verification failed.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorText = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<bool> _showVerifiedDialog() async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = _CheckPinPalette.of(dark);

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
                    Icons.verified_rounded,
                    size: 30,
                    color: p.available,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Code verified',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You can now create a new password.',
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

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      final chars = value.replaceAll(RegExp(r'[^0-9]'), '').split('');
      for (int i = 0; i < 6; i++) {
        _controllers[i].text = i < chars.length ? chars[i] : '';
      }
      if (chars.length >= 6) {
        _focusNodes[5].requestFocus();
      } else if (chars.isNotEmpty) {
        _focusNodes[min(chars.length, 5)].requestFocus();
      }
      setState(() {});
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    if (_enteredCode.length == 6) {
      FocusScope.of(context).unfocus();
    }

    setState(() {});
  }

  void _onBackspace(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey != LogicalKeyboardKey.backspace) return;

    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = _CheckPinPalette.of(dark);

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
                                    'Verification Code',
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
                                                              .password_rounded,
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
                                                    'Enter code',
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
                                                    'Check your email inbox',
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
                                    'Verify your code',
                                    style: TextStyle(
                                      color: p.textPrimary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'We sent a 6-digit code to\n${widget.email}',
                                    style: TextStyle(
                                      color: p.textSecondary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: List.generate(
                                      6,
                                      (index) => _OtpBox(
                                        controller: _controllers[index],
                                        focusNode: _focusNodes[index],
                                        palette: p,
                                        onChanged: (value) =>
                                            _onDigitChanged(index, value),
                                        onKeyEvent: (event) =>
                                            _onBackspace(index, event),
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
                                            _isVerifying ? null : _verifyCode,
                                        style: TextButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        icon: _isVerifying
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
                                                Icons.verified_user_rounded,
                                                size: 19,
                                                color: dark
                                                    ? const Color(0xFF04111D)
                                                    : Colors.white,
                                              ),
                                        label: Text(
                                          _isVerifying
                                              ? 'Verifying...'
                                              : 'Verify code',
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
                                      onPressed:
                                          (_secondsLeft > 0 || _isResending)
                                              ? null
                                              : _resendCode,
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: p.borderStrong),
                                        backgroundColor: p.surfaceAlt,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      icon: _isResending
                                          ? SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  p.primary,
                                                ),
                                              ),
                                            )
                                          : Icon(
                                              Icons.refresh_rounded,
                                              size: 19,
                                              color: p.primary,
                                            ),
                                      label: Text(
                                        _secondsLeft > 0
                                            ? 'Resend code in ${_secondsLeft}s'
                                            : 'Resend code',
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

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.palette,
    required this.onChanged,
    required this.onKeyEvent,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final _CheckPinPalette palette;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 58,
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: onKeyEvent,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: palette.surfaceAlt,
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: palette.secondary, width: 1.2),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _InfoNotice extends StatelessWidget {
  const _InfoNotice({required this.palette});

  final _CheckPinPalette palette;

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
              'Enter the latest code from your email. The code expires after 10 minutes.',
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

  final _CheckPinPalette palette;
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

class _CheckPinPalette {
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

  const _CheckPinPalette({
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

  factory _CheckPinPalette.of(bool dark) {
    if (dark) {
      return const _CheckPinPalette(
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

    return const _CheckPinPalette(
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
