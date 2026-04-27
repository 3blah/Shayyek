import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shayyek/welcome.dart';

void main() {
  testWidgets('Welcome page renders primary entry actions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomePage(),
      ),
    );

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
  });
}
