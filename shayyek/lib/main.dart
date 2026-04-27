import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config.dart';
import 'splash.dart';
import 'theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseConfig.initializeFirebase();

  final controller = ThemeController();
  await controller.load();
  runApp(ThemeScope(
      controller: controller, child: ShayyekApp(controller: controller)));
}

class ShayyekApp extends StatelessWidget {
  const ShayyekApp({super.key, required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        controller.themeMode,
        controller.locale,
      ]),
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Shayyek',
          themeMode: controller.themeMode.value,
          locale: controller.locale.value,
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
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            fontFamily: 'Poppins',
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            fontFamily: 'Poppins',
            scaffoldBackgroundColor: const Color(0xFF07111F),
          ),
          builder: (context, child) {
            final isArabic =
                controller.effectiveLanguageCode.toLowerCase() == 'ar';
            return Directionality(
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const SplashPage(),
        );
      },
    );
  }
}
