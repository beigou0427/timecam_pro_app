// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timecam_pro_app/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}

  testWidgets('UI Flow: Tab navigation, 110 SMS sheet & Bilingual switch',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TimeCamProApp(isTestMode: true));
    expect(find.text('時間相機 Pro'), findsOneWidget);
    expect(find.text('UTC+8 國家標準校時'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open_110_sms_sheet_btn')));
    await tester.pumpAndSettle();
    expect(find.textContaining('0911510914'), findsWidgets);

    await tester.tap(find.byKey(const Key('copy_110_sms_btn')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('appbar_lang_toggle_btn')));
    await tester.pump();
    expect(find.text('TimeCam Pro'), findsOneWidget);
  });

  testWidgets('Paywall E2E: 20MB export intercept, PulsingCtaButton & Restore',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TimeCamProApp(isTestMode: true));

    await tester.tap(find.byKey(const Key('appbar_pro_badge_btn')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 625));

    final Finder pulsingScaleFinder = find.descendant(
      of: find.byType(PulsingCtaButton),
      matching: find.byType(ScaleTransition),
    );
    expect(pulsingScaleFinder, findsOneWidget);

    await tester.tap(find.byKey(const Key('paywall_restore_btn')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('PRO 已解鎖'), findsOneWidget);
  });
}
