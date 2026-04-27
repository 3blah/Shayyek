import 'package:flutter/material.dart';
import 'app_text.dart';
import 'driver/driverhome.dart';
import 'login.dart';
import 'register.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = _Palette.of(dark);

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: p.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(dark ? 0.22 : 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          Text(
                            AppText.of(
                              context,
                              ar: 'مرحباً',
                              en: 'Welcome',
                            ),
                            style: TextStyle(
                              color: p.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppText.of(
                              context,
                              ar: 'ادخل أو استكشف التطبيق كضيف',
                              en: 'Sign in or explore the app as a guest',
                            ),
                            style: TextStyle(
                              color: p.textSecondary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              final y = (_controller.value - 0.5) * 10;
                              return Transform.translate(
                                offset: Offset(0, y),
                                child: _WelcomeIllustration(palette: p),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: p.outlineButtonBorder),
                                backgroundColor: p.outlineButtonBg,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginPage(),
                                  ),
                                );
                              },
                              child: Text(
                                AppText.of(
                                  context,
                                  ar: 'تسجيل الدخول',
                                  en: 'Log in',
                                ),
                                style: TextStyle(
                                  color: p.outlineButtonText,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: dark
                                      ? [p.primary, p.secondary]
                                      : [p.secondarySoft, p.secondarySoft],
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: p.secondaryBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: p.secondary
                                        .withOpacity(dark ? 0.22 : 0.08),
                                    blurRadius: 14,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                onPressed: () {
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
                                    en: 'Sign Up',
                                  ),
                                  style: TextStyle(
                                    color: dark
                                        ? const Color(0xFF04111D)
                                        : p.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const DriverHomePage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.travel_explore_rounded),
                            label: Text(
                              AppText.of(
                                context,
                                ar: 'متابعة كضيف',
                                en: 'Continue as Guest',
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
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

class _WelcomeIllustration extends StatelessWidget {
  final _Palette palette;

  const _WelcomeIllustration({required this.palette});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      width: 290,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 18,
            left: 26,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: palette.secondary.withOpacity(0.22),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 58,
            right: 38,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border:
                    Border.all(color: palette.textSecondary.withOpacity(0.45)),
              ),
            ),
          ),
          Positioned(
            top: 72,
            right: 22,
            child: Transform.rotate(
              angle: 0.25,
              child: Icon(
                Icons.change_history_rounded,
                size: 18,
                color: palette.secondary.withOpacity(0.55),
              ),
            ),
          ),
          Positioned(
            left: 34,
            right: 34,
            top: 40,
            child: Container(
              height: 128,
              decoration: BoxDecoration(
                color: palette.illustrationBlob,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(90),
                  topRight: Radius.circular(90),
                  bottomLeft: Radius.circular(90),
                  bottomRight: Radius.circular(26),
                ),
              ),
            ),
          ),
          Positioned(
            left: 52,
            right: 52,
            bottom: 62,
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: palette.sofa,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: palette.secondary.withOpacity(0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 36,
            bottom: 62,
            child: Container(
              width: 20,
              height: 52,
              decoration: BoxDecoration(
                color: palette.sofa,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            right: 42,
            bottom: 62,
            child: Container(
              width: 20,
              height: 52,
              decoration: BoxDecoration(
                color: palette.sofa,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            left: 56,
            bottom: 106,
            child: Container(
              width: 90,
              height: 64,
              decoration: BoxDecoration(
                color: palette.background.withOpacity(0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Row(
                      children: [
                        Icon(Icons.wifi_rounded,
                            size: 14, color: palette.secondary),
                        const SizedBox(width: 4),
                        Text(
                          'Live',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: palette.available,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Spot Free',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 112,
            top: 68,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [palette.primary, palette.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: palette.secondary.withOpacity(0.20),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.local_parking_rounded,
                color: palette.accent,
                size: 34,
              ),
            ),
          ),
          Positioned(
            right: 66,
            top: 94,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: palette.surface,
                shape: BoxShape.circle,
                border: Border.all(color: palette.border),
              ),
              child: Icon(
                Icons.videocam_outlined,
                size: 20,
                color: palette.primary,
              ),
            ),
          ),
          Positioned(
            bottom: 76,
            left: 84,
            child: Icon(
              Icons.person_rounded,
              size: 64,
              color: palette.person,
            ),
          ),
          Positioned(
            bottom: 66,
            left: 108,
            child: Transform.rotate(
              angle: -0.20,
              child: Icon(
                Icons.route_rounded,
                size: 30,
                color: palette.secondary,
              ),
            ),
          ),
          Positioned(
            bottom: 52,
            left: 86,
            child: Container(
              width: 100,
              height: 8,
              decoration: BoxDecoration(
                color: palette.shadowStrip,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            left: 26,
            bottom: 72,
            child: Transform.rotate(
              angle: -0.40,
              child: Container(
                width: 14,
                height: 34,
                decoration: BoxDecoration(
                  color: palette.plantStem,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: 62,
            child: SizedBox(
              width: 30,
              height: 64,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    width: 8,
                    height: 56,
                    decoration: BoxDecoration(
                      color: palette.plantStem,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 2,
                    child: Icon(Icons.eco_rounded,
                        size: 16, color: palette.plantLeaf),
                  ),
                  Positioned(
                    top: 22,
                    right: 0,
                    child: Icon(Icons.eco_rounded,
                        size: 14, color: palette.plantLeaf),
                  ),
                  Positioned(
                    top: 38,
                    left: 0,
                    child: Icon(Icons.eco_rounded,
                        size: 14, color: palette.plantLeaf),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Palette {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color available;
  final Color occupied;
  final Color background;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color secondarySoft;
  final Color secondaryBorder;
  final Color outlineButtonBg;
  final Color outlineButtonBorder;
  final Color outlineButtonText;
  final Color illustrationBlob;
  final Color sofa;
  final Color person;
  final Color shadowStrip;
  final Color plantStem;
  final Color plantLeaf;

  const _Palette({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.available,
    required this.occupied,
    required this.background,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.secondarySoft,
    required this.secondaryBorder,
    required this.outlineButtonBg,
    required this.outlineButtonBorder,
    required this.outlineButtonText,
    required this.illustrationBlob,
    required this.sofa,
    required this.person,
    required this.shadowStrip,
    required this.plantStem,
    required this.plantLeaf,
  });

  factory _Palette.of(bool dark) {
    if (dark) {
      return const _Palette(
        primary: Color(0xFF0B3C7A),
        secondary: Color(0xFF19D3FF),
        accent: Color(0xFF8BEF3F),
        available: Color(0xFF22C55E),
        occupied: Color(0xFFEF4444),
        background: Color(0xFF07111F),
        surface: Color(0xFF0E1C2F),
        border: Color(0xFF1E3550),
        textPrimary: Color(0xFFEAF4FF),
        textSecondary: Color(0xFF9FB3C8),
        secondarySoft: Color(0xFF19D3FF),
        secondaryBorder: Color(0x3326D9FF),
        outlineButtonBg: Color(0x00000000),
        outlineButtonBorder: Color(0xFF365271),
        outlineButtonText: Color(0xFFEAF4FF),
        illustrationBlob: Color(0x1A19D3FF),
        sofa: Color(0xFF14304C),
        person: Color(0xFFBFE9FF),
        shadowStrip: Color(0x1A000000),
        plantStem: Color(0xFF2A4C6E),
        plantLeaf: Color(0xFF8BEF3F),
      );
    }
    return const _Palette(
      primary: Color(0xFF0B3C7A),
      secondary: Color(0xFF00B7E8),
      accent: Color(0xFF65C92F),
      available: Color(0xFF16A34A),
      occupied: Color(0xFFDC2626),
      background: Color(0xFFF6FAFF),
      surface: Color(0xFFFFFFFF),
      border: Color(0xFFD7E4F2),
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF6B7280),
      secondarySoft: Color(0xFFBFEFFF),
      secondaryBorder: Color(0xFF93DFFF),
      outlineButtonBg: Color(0xFFFFFFFF),
      outlineButtonBorder: Color(0xFFBAC7D5),
      outlineButtonText: Color(0xFF243447),
      illustrationBlob: Color(0xFFD9ECFF),
      sofa: Color(0xFFBEEBFF),
      person: Color(0xFF2E3A4A),
      shadowStrip: Color(0x16000000),
      plantStem: Color(0xFFC4D1DA),
      plantLeaf: Color(0xFFAED9B5),
    );
  }
}
