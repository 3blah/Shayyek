import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'app_text.dart';
import 'admin/adminhome.dart';
import 'driver/driverhome.dart';
import 'driver/services/driver_task_service.dart';
import 'forget.dart';
import 'register.dart';
import 'theme_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.onThemeToggle});

  final VoidCallback? onThemeToggle;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final DriverTaskService _service =
      DriverTaskService(FirebaseDatabase.instance);

  bool _obscure = true;
  bool _rememberMe = true;
  bool _checkingLaunch = true;
  bool _submitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final decision = await _service.resolveLaunchDecision();
    if (!mounted) {
      return;
    }

    if (decision.shouldRoute && decision.user != null) {
      _openHome(
        role: decision.role,
        openSessionTab: decision.hasWorkingSession,
      );
      return;
    }

    setState(() {
      _checkingLaunch = false;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final outcome = await _service.signIn(
      email: _emailController.text,
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (!mounted) {
      return;
    }

    if (!outcome.success || outcome.user == null) {
      setState(() {
        _submitting = false;
        _errorText = outcome.message ??
            AppText.of(
              context,
              ar: 'تعذر تسجيل الدخول.',
              en: 'Unable to sign in.',
            );
      });
      return;
    }

    _openHome(
      role: outcome.role,
      openSessionTab: outcome.hasWorkingSession,
    );
  }

  void _openHome({
    required AppRole role,
    required bool openSessionTab,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final onToggle = widget.onThemeToggle ?? ThemeScope.of(context).toggle;

    final Widget page;
    if (role == AppRole.admin) {
      page = AdminDashboardShell(
        isDarkMode: isDarkMode,
        onToggleTheme: onToggle,
      );
    } else {
      page = DriverHomePage(
        initialTab: openSessionTab ? 2 : 0,
      );
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => page),
      (route) => false,
    );
  }

  void _continueAsGuest() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const DriverHomePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _LoginPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );

    if (_checkingLaunch) {
      return Scaffold(
        backgroundColor: palette.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: palette.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      palette: palette,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      AppText.of(
                        context,
                        ar: 'تسجيل الدخول',
                        en: 'Sign In',
                      ),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppText.of(
                        context,
                        ar: 'يتم تحديد الدور تلقائياً ثم فتح الصفحة الصحيحة مباشرة.',
                        en: 'Your role is detected automatically and the correct page opens right away.',
                      ),
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _FormField(
                      controller: _emailController,
                      label: AppText.of(
                        context,
                        ar: 'البريد الإلكتروني',
                        en: 'Email',
                      ),
                      hint: 'name@example.com',
                      icon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _FormField(
                      controller: _passwordController,
                      label: AppText.of(
                        context,
                        ar: 'كلمة المرور',
                        en: 'Password',
                      ),
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscure,
                      suffix: IconButton(
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: _submitting
                              ? null
                              : (value) => setState(
                                    () => _rememberMe = value ?? true,
                                  ),
                        ),
                        Expanded(
                          child: Text(
                            AppText.of(
                              context,
                              ar: 'تذكرني على هذا الجهاز',
                              en: 'Remember me on this device',
                            ),
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _submitting
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const ForgetPage(),
                                    ),
                                  );
                                },
                          child: Text(
                            AppText.of(
                              context,
                              ar: 'نسيت كلمة المرور؟',
                              en: 'Forgot password?',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 8),
                      _ErrorBox(text: _errorText!),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login_rounded),
                        label: Text(
                          _submitting
                              ? AppText.of(
                                  context,
                                  ar: 'جارٍ التحقق...',
                                  en: 'Checking...',
                                )
                              : AppText.of(
                                  context,
                                  ar: 'دخول',
                                  en: 'Sign In',
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _continueAsGuest,
                        icon: const Icon(Icons.travel_explore_rounded),
                        label: Text(
                          AppText.of(
                            context,
                            ar: 'متابعة كضيف',
                            en: 'Continue as Guest',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: palette.soft,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppText.of(
                              context,
                              ar: 'ملاحظات الاتصال',
                              en: 'Connection Notes',
                            ),
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppText.of(
                              context,
                              ar: 'السائق يستخدم Firebase Auth مع دعم السجلات القديمة بشكل آمن.',
                              en: 'Drivers use Firebase Auth with a safe fallback for older records.',
                            ),
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppText.of(
                              context,
                              ar: 'مسار الإدارة يبقى كما هو مع تبسيط الواجهة بدون كسر الميزات الحالية.',
                              en: 'Admin routing stays intact while the interface is simplified without breaking current features.',
                            ),
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppText.of(
                            context,
                            ar: 'ليس لديك حساب؟',
                            en: 'Don\'t have an account?',
                          ),
                          style: TextStyle(color: palette.textSecondary),
                        ),
                        TextButton(
                          onPressed: _submitting
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterPage(),
                                    ),
                                  );
                                },
                          child: Text(
                            AppText.of(
                              context,
                              ar: 'إنشاء حساب',
                              en: 'Create Account',
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.palette,
  });

  final _LoginPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [palette.primary, palette.secondary],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.local_parking_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shayyek',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Realtime driver flow on Firebase RTDB',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            suffixIcon: suffix,
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            filled: true,
          ),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LoginPalette {
  const _LoginPalette({
    required this.background,
    required this.surface,
    required this.soft,
    required this.border,
    required this.primary,
    required this.secondary,
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color background;
  final Color surface;
  final Color soft;
  final Color border;
  final Color primary;
  final Color secondary;
  final Color textPrimary;
  final Color textSecondary;

  factory _LoginPalette.of(bool dark) {
    if (dark) {
      return const _LoginPalette(
        background: Color(0xFF08101C),
        surface: Color(0xFF111B2A),
        soft: Color(0xFF142133),
        border: Color(0xFF24344C),
        primary: Color(0xFF0B3C7A),
        secondary: Color(0xFF19D3FF),
        textPrimary: Color(0xFFEAF4FF),
        textSecondary: Color(0xFFA8BED5),
      );
    }
    return const _LoginPalette(
      background: Color(0xFFF4F8FD),
      surface: Colors.white,
      soft: Color(0xFFF6FAFF),
      border: Color(0xFFD8E4F2),
      primary: Color(0xFF0B3C7A),
      secondary: Color(0xFF19B8F0),
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF5A6B82),
    );
  }
}
