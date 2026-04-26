import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quickchat/features/auth/presentation/screens/onboarding_screen.dart';

void main() {
  testWidgets('Onboarding screen renders Get Started button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OnboardingScreen()),
      ),
    );

    expect(find.text('Get Started'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('Quick Chat'),
      ),
      findsOneWidget,
    );
  });
}
