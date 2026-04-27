import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shayyek/admin/admin_l10n.dart';
import 'package:shayyek/app_text.dart';
import 'package:shayyek/theme_controller.dart';

void main() {
  testWidgets('App text and admin translations follow ThemeScope locale',
      (tester) async {
    final controller = ThemeController();
    controller.locale.value = const Locale('ar');

    await tester.pumpWidget(
      ThemeScope(
        controller: controller,
        child: AnimatedBuilder(
          animation: controller.locale,
          builder: (context, _) {
            return MaterialApp(
              home: Builder(
                builder: (context) {
                  return Column(
                    children: [
                      Text(AppText.of(context, ar: 'مرحبا', en: 'Hello')),
                      Text(adminL10n(context, 'Users')),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('مرحبا'), findsOneWidget);
    expect(find.text('المستخدمون'), findsOneWidget);

    controller.locale.value = const Locale('en');
    await tester.pump();

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Users'), findsOneWidget);
  });
}
