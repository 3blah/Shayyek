import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'login.dart';
import 'theme_controller.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  static const String _logoAsset = 'assets/logo.png';

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _password1Controller = TextEditingController();
  final TextEditingController _password2Controller = TextEditingController();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseDatabase get _db => FirebaseDatabase.instance;

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _agree = true;
  bool _isLoading = false;
  String? _errorText;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _password1Controller.dispose();
    _password2Controller.dispose();
    super.dispose();
  }

  String? _validate() {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final email = _normalizeEmail(_emailController.text);
    final phone = _phoneController.text.trim();
    final p1 = _password1Controller.text;
    final p2 = _password2Controller.text;

    if (first.isEmpty || last.isEmpty) {
      return 'Please enter first and last name.';
    }
    if (first.length < 2 || last.length < 2) return 'Name is too short.';
    if (email.isEmpty) return 'Please enter your email.';
    final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!emailOk) return 'Invalid email format.';
    if (phone.isEmpty) return 'Please enter your phone number.';
    final phoneClean = phone.replaceAll(RegExp(r'[\s\-]'), '');
    final phoneOk = RegExp(r'^\+?\d{7,15}$').hasMatch(phoneClean);
    if (!phoneOk) return 'Invalid phone number.';
    if (p1.isEmpty || p2.isEmpty) {
      return 'Please enter password and confirm it.';
    }
    if (p1.length < 6) return 'Password must be at least 6 characters.';
    if (p1 != p2) return 'Passwords do not match.';
    if (!_agree) return 'You must agree to the terms to create an account.';
    return null;
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Invalid email format.';
      case 'weak-password':
        return 'Weak password. Please use a stronger one.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        return e.message ?? 'Registration failed. Please try again.';
    }
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
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return <String, dynamic>{};
  }

  Future<bool> _emailExistsInDatabase(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    final snap = await _db.ref('User').get();
    if (!snap.exists || snap.value == null) {
      return false;
    }

    for (final child in snap.children) {
      final row = _toMap(child.value);
      final rowEmail = _normalizeEmail((row['email'] ?? '').toString());
      if (rowEmail == normalizedEmail) {
        return true;
      }
    }
    return false;
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();
    final appController = ThemeScope.of(context);

    final v = _validate();
    if (v != null) {
      setState(() => _errorText = v);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _password1Controller.text;

    UserCredential? cred;

    try {
      if (await _emailExistsInDatabase(email)) {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'This email is already registered.',
        );
      }

      cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user?.uid ?? '';
      if (uid.isEmpty) {
        throw Exception('Missing auth uid');
      }

      final tsMs = DateTime.now().millisecondsSinceEpoch;
      final now = DateTime.now().toUtc().toIso8601String();
      final languageCode = appController.effectiveLanguageCode;

      final appUserId = 'user_$tsMs';
      const roleId = 'role_003';

      final auditKey = _db.ref('auditLogs').push().key ?? 'audit_$tsMs';
      final userRoleId = 'user_role_$tsMs';

      final updates = <String, dynamic>{
        'User/$uid': {
          'id': appUserId,
          'auth_uid': uid,
          'email': email,
          'name': ('$first $last').trim(),
          'phone': phone,
          'status': 'active',
          'create': now,
          'login': null,
          'role_id': roleId,
        },
        'user_role/$userRoleId': {
          'id': userRoleId,
          'user_id': uid,
          'role_id': roleId,
          'date_at': now,
        },
        'UserPreferences/$uid': {
          'user_id': uid,
          'default_distance_km': 2,
          'filter_accessible': false,
          'filter_ev': false,
          'filter_max_stay_min': 180,
          'filter_price_max': 6,
          'language': languageCode,
          'notify_email': false,
          'notify_push': true,
          'updated_at': now,
        },
        'auditLogs/$auditKey': {
          'id': 'audit_$tsMs',
          'user_id': uid,
          'action': 'register',
          'target_type': 'auth',
          'target_id': uid,
          'ts': now,
          'ip': null,
          'device': 'android_app',
        },
      };

      await _db.ref().update(updates);

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final dark = Theme.of(context).brightness == Brightness.dark;
          final p = _RegisterPalette.of(dark);
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
                    color: p.shadow.withOpacity(dark ? .25 : .08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
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
                      border: Border.all(color: p.available.withOpacity(.24)),
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: p.available,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Account created',
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You can log in now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient:
                            LinearGradient(colors: [p.primary, p.secondary]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Continue',
                          style: TextStyle(
                            color:
                                dark ? const Color(0xFF04111D) : Colors.white,
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

      await _auth.signOut();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = _mapAuthError(e));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final msg = (e.message ?? '').trim();
      setState(() {
        _errorText =
            msg.isEmpty ? 'Database error (${e.code}).' : '$msg (${e.code})';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = 'Registration failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = _RegisterPalette.of(dark);

    return Scaffold(
      backgroundColor: p.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final g = 0.08 + (_pulse.value * 0.08);
                  return Container(
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
                        BoxShadow(
                          color: p.secondary.withOpacity(g),
                          blurRadius: 22,
                          spreadRadius: -8,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _RegisterGridPainter(
                                lineColor:
                                    p.gridLine.withOpacity(dark ? 0.12 : 0.08),
                              ),
                            ),
                          ),
                          Positioned(
                            right: -50,
                            top: -40,
                            child: Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    p.secondary.withOpacity(dark ? .10 : .06),
                              ),
                            ),
                          ),
                          Positioned(
                            left: -40,
                            top: 80,
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: p.primary.withOpacity(dark ? .12 : .06),
                              ),
                            ),
                          ),
                          Column(
                            children: [
                              _RegisterHeader(
                                palette: p,
                                dark: dark,
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding:
                                      const EdgeInsets.fromLTRB(18, 14, 18, 18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _BrandCard(
                                          palette: p, assetPath: _logoAsset),
                                      const SizedBox(height: 14),
                                      Text(
                                        'Create Account',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: p.textPrimary,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Join Shayyek and access smart parking guidance',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: p.textSecondary,
                                          fontSize: 13.2,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _RegisterField(
                                              hint: 'First name',
                                              prefix:
                                                  Icons.person_outline_rounded,
                                              palette: p,
                                              controller: _firstNameController,
                                              enabled: !_isLoading,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _RegisterField(
                                              hint: 'Last name',
                                              prefix:
                                                  Icons.person_outline_rounded,
                                              palette: p,
                                              controller: _lastNameController,
                                              enabled: !_isLoading,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _RegisterField(
                                        hint: 'Email',
                                        prefix: Icons.mail_outline_rounded,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        palette: p,
                                        controller: _emailController,
                                        enabled: !_isLoading,
                                      ),
                                      const SizedBox(height: 12),
                                      _RegisterField(
                                        hint: 'Phone',
                                        prefix: Icons.phone_outlined,
                                        keyboardType: TextInputType.phone,
                                        palette: p,
                                        controller: _phoneController,
                                        enabled: !_isLoading,
                                      ),
                                      const SizedBox(height: 12),
                                      _RegisterField(
                                        hint: 'Password',
                                        prefix: Icons.lock_outline_rounded,
                                        obscure: _obscure1,
                                        palette: p,
                                        controller: _password1Controller,
                                        enabled: !_isLoading,
                                        suffix: IconButton(
                                          onPressed: _isLoading
                                              ? null
                                              : () => setState(
                                                  () => _obscure1 = !_obscure1),
                                          splashRadius: 20,
                                          icon: Icon(
                                            _obscure1
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: p.iconMuted,
                                            size: 19,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _RegisterField(
                                        hint: 'Confirm password',
                                        prefix: Icons.lock_outline_rounded,
                                        obscure: _obscure2,
                                        palette: p,
                                        controller: _password2Controller,
                                        enabled: !_isLoading,
                                        suffix: IconButton(
                                          onPressed: _isLoading
                                              ? null
                                              : () => setState(
                                                  () => _obscure2 = !_obscure2),
                                          splashRadius: 20,
                                          icon: Icon(
                                            _obscure2
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: p.iconMuted,
                                            size: 19,
                                          ),
                                        ),
                                      ),
                                      if (_errorText != null) ...[
                                        const SizedBox(height: 12),
                                        _RegisterErrorNotice(
                                            palette: p, text: _errorText!),
                                      ],
                                      const SizedBox(height: 12),
                                      _RegisterInfoCard(palette: p),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          _LegendChip(
                                            label: 'Available',
                                            color: p.available,
                                            icon: Icons.local_parking_rounded,
                                            palette: p,
                                          ),
                                          const SizedBox(width: 8),
                                          _LegendChip(
                                            label: 'Occupied',
                                            color: p.occupied,
                                            icon: Icons.block_rounded,
                                            palette: p,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: _isLoading
                                            ? null
                                            : () => setState(
                                                () => _agree = !_agree),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4, horizontal: 2),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 180),
                                                margin: const EdgeInsets.only(
                                                    top: 1.5),
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  color: _agree
                                                      ? p.secondary
                                                          .withOpacity(.15)
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: _agree
                                                        ? p.secondary
                                                        : p.borderStrong,
                                                  ),
                                                ),
                                                child: _agree
                                                    ? Icon(Icons.check_rounded,
                                                        size: 14,
                                                        color: p.secondary)
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'I agree to the terms and privacy policy.',
                                                  style: TextStyle(
                                                    color: p.textSecondary,
                                                    fontSize: 12.2,
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.25,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      SizedBox(
                                        height: 52,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(colors: [
                                              p.primary,
                                              p.secondary
                                            ]),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: p.secondary.withOpacity(
                                                    dark ? .22 : .10),
                                                blurRadius: 16,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: TextButton.icon(
                                            onPressed: _isLoading
                                                ? null
                                                : _createAccount,
                                            style: TextButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                            icon: _isLoading
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
                                                    Icons
                                                        .person_add_alt_1_rounded,
                                                    size: 19,
                                                    color: dark
                                                        ? const Color(
                                                            0xFF04111D)
                                                        : Colors.white,
                                                  ),
                                            label: Text(
                                              _isLoading
                                                  ? 'Creating...'
                                                  : 'Create account',
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
                                      const SizedBox(height: 14),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Already have an account? ',
                                            style: TextStyle(
                                              color: p.textSecondary,
                                              fontSize: 12.6,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap:
                                                _isLoading ? null : _goToLogin,
                                            child: Text(
                                              'Log in',
                                              style: TextStyle(
                                                color: p.primary,
                                                fontSize: 12.9,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterHeader extends StatelessWidget {
  const _RegisterHeader({
    required this.palette,
    required this.dark,
  });

  final _RegisterPalette palette;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.primary, palette.primary2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: palette.border.withOpacity(.55)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(.10),
              side: BorderSide(color: Colors.white.withOpacity(.12)),
            ),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          _HeaderChip(
            icon: Icons.wifi_tethering_rounded,
            label: 'Smart Parking',
            dotColor: palette.available,
          ),
        ],
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({
    required this.palette,
    required this.assetPath,
  });

  final _RegisterPalette palette;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -12,
            right: -10,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: palette.secondary.withOpacity(.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -10,
            left: -8,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: palette.primary.withOpacity(.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [palette.primary, palette.secondary],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: palette.secondary.withOpacity(.18),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.local_parking_rounded,
                        color: palette.accent,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'shayyek',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Smart Parking & AI Guidance',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: palette.available,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Live availability enabled',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }
}

class _RegisterField extends StatelessWidget {
  const _RegisterField({
    required this.hint,
    required this.prefix,
    required this.palette,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.controller,
    this.enabled = true,
  });

  final String hint;
  final IconData prefix;
  final _RegisterPalette palette;
  final TextInputType? keyboardType;
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
        keyboardType: keyboardType,
        obscureText: obscure,
        enabled: enabled,
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
            fontSize: 13.4,
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

class _RegisterInfoCard extends StatelessWidget {
  const _RegisterInfoCard({required this.palette});

  final _RegisterPalette palette;

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
              'Guest mode is allowed. Sign in becomes required when reserving a parking spot.',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11.8,
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

class _RegisterErrorNotice extends StatelessWidget {
  const _RegisterErrorNotice({
    required this.palette,
    required this.text,
  });

  final _RegisterPalette palette;
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

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.palette,
  });

  final String label;
  final Color color;
  final IconData icon;
  final _RegisterPalette palette;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: palette.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(.24)),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.dotColor,
  });

  final IconData icon;
  final String label;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterGridPainter extends CustomPainter {
  const _RegisterGridPainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    const step = 22.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RegisterGridPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}

class _RegisterPalette {
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

  const _RegisterPalette({
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

  factory _RegisterPalette.of(bool dark) {
    if (dark) {
      return const _RegisterPalette(
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
    return const _RegisterPalette(
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
