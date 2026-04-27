import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'admin/adminhome.dart';
import 'app_text.dart';
import 'driver/driverhome.dart';
import 'driver/services/driver_task_service.dart';
import 'welcome.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final PageController _controller = PageController();
  final DriverTaskService _service =
      DriverTaskService(FirebaseDatabase.instance);

  int _index = 0;
  bool _checkingLaunch = true;

  final List<_SlideData> _slides = const [
    _SlideData(
      titleAr: 'اكتشف المواقف المتاحة مباشرة',
      titleEn: 'Find available parking instantly',
      bodyAr:
          'يعرض شايّك حالة المواقف والفراغات مباشرة حتى تعرف أين توجد الأماكن المتاحة قبل أن تتحرك.',
      bodyEn:
          'Shayyek shows live parking availability so you can see open and occupied spaces before you start driving.',
      icon: Icons.local_parking_rounded,
    ),
    _SlideData(
      titleAr: 'احجز موقفك بخطوات واضحة',
      titleEn: 'Reserve your spot with confidence',
      bodyAr:
          'اختر الموقف المناسب، ابدأ الجلسة، وتابع الوقت والتنبيهات من داخل التطبيق بدون تعقيد.',
      bodyEn:
          'Choose a suitable space, start your parking session, and track timing and alerts from one simple flow.',
      icon: Icons.route_rounded,
    ),
    _SlideData(
      titleAr: 'يرجعك التطبيق تلقائياً',
      titleEn: 'Pick up where you left off',
      bodyAr:
          'إذا كنت مسجل الدخول أو لديك جلسة نشطة، يفتح شايّك الصفحة المناسبة مباشرة بدون إعادة تسجيل الدخول كل مرة.',
      bodyEn:
          'If you are already signed in or have an active session, Shayyek opens the right screen automatically.',
      icon: Icons.verified_user_rounded,
    ),
  ];

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
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      final Widget page = (decision.role == AppRole.admin)
          ? AdminDashboardShell(
              isDarkMode: isDarkMode,
              onToggleTheme: () {},
            )
          : DriverHomePage(
              initialTab: decision.hasWorkingSession ? 2 : 0,
            );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => page),
      );
      return;
    }

    setState(() {
      _checkingLaunch = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _slides.length - 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomePage()),
      );
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = _InfoPalette.of(dark);
    final isLastSlide = _index == _slides.length - 1;

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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [palette.primary, palette.secondary],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.local_parking_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Shayyek',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const WelcomePage()),
                      );
                    },
                    child: Text(AppText.of(context, ar: 'تخطي', en: 'Skip')),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: palette.soft,
                              shape: BoxShape.circle,
                              border: Border.all(color: palette.border),
                            ),
                            child: Icon(
                              slide.icon,
                              size: 44,
                              color: palette.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            slide.title(context),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 26,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            slide.body(context),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 14,
                              height: 1.7,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: List.generate(
                  _slides.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsetsDirectional.only(end: 8),
                    width: _index == index ? 26 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _index == index ? palette.primary : palette.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _next,
                  icon: Icon(
                    isLastSlide
                        ? Icons.arrow_forward_rounded
                        : Icons.keyboard_double_arrow_right_rounded,
                  ),
                  label: Text(
                    isLastSlide
                        ? AppText.of(
                            context,
                            ar: 'ابدأ الآن',
                            en: 'Get started',
                          )
                        : AppText.of(context, ar: 'التالي', en: 'Next'),
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

class _SlideData {
  const _SlideData({
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    required this.icon,
  });

  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final IconData icon;

  String title(BuildContext context) =>
      AppText.of(context, ar: titleAr, en: titleEn);

  String body(BuildContext context) =>
      AppText.of(context, ar: bodyAr, en: bodyEn);
}

class _InfoPalette {
  const _InfoPalette({
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

  factory _InfoPalette.of(bool dark) {
    if (dark) {
      return const _InfoPalette(
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
    return const _InfoPalette(
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
