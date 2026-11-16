import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timecam_pro_app/core/taiwan_report_repository.dart';
import 'package:timecam_pro_app/core/activation_quota_engine.dart';
import 'package:timecam_pro_app/core/video_compression_engine.dart';
import 'package:timecam_pro_app/core/watermark_location_engine.dart';
import 'package:timecam_pro_app/main.dart';
import 'package:timecam_pro_app/ui/widgets/paywall_sheet.dart';
import 'package:timecam_pro_app/ui/widgets/taiwan_plate_quick_pad.dart';

void main() {
  test('Core Engines: 20MB bitrate lock, NaN guard, UTC+8 & 7-day limit', () {
    final CompressionPlan validPlan = VideoCompressionEngine.createPlan(
      sourceSizeMB: 142.8,
      clipDurationSeconds: 15.0,
      preset: ReportTargetPreset.trafficPolice20MB,
    );
    expect(validPlan.isValid, isTrue);
    expect(validPlan.estimatedOutputMB, lessThanOrEqualTo(19.0));
    expect(validPlan.savedPercentage, greaterThan(80.0));

    final CompressionPlan invalidPlan = VideoCompressionEngine.createPlan(
      sourceSizeMB: double.nan,
      clipDurationSeconds: 0.0,
    );
    expect(invalidPlan.isValid, isFalse);
    expect(invalidPlan.savedPercentage, equals(0.0));

    final DateTime utcTime = DateTime.utc(2026, 11, 16, 6, 30, 0);
    expect(
      WatermarkLocationEngine.formatTaiwanTimestamp(utcTime),
      equals('2026/11/16 14:30:00'),
    );
    expect(
      WatermarkLocationEngine.resolve110SmsRecipient('台北市信義區'),
      equals('0911510914'),
    );

    final int remHours = TaiwanReportRepository.remainingHoursToReport(
      capturedAtUtc: utcTime.subtract(const Duration(days: 2)),
      nowUtc: utcTime,
    );
    expect(remHours, equals(120));
    expect(TaiwanPlateQuickPad.sanitizeTaiwanPlate('rcdO88I'), equals('RCD-0881'));
    final QuotaStatusSnapshot q1 = ActivationQuotaEngine.evaluateGate(
      isProUnlocked: false,
      usedFreeExports: 0,
      totalSavedMB: 0.0,
    );
    expect(q1.decision, equals(ExportGateDecision.allowFreeGoldenPass));
    final QuotaStatusSnapshot q2 = ActivationQuotaEngine.recordSuccessfulExport(
      current: q1,
      sourceSizeMB: 142.8,
      estimatedOutputMB: 18.6,
    );
    expect(q2.decision, equals(ExportGateDecision.interceptWithPaywall));
    expect(q2.remainingFreeExports, equals(0));
    expect(
      TaiwanReportRepository.filterPortals(query: 'tainan').length,
      equals(1),
    );
  });

  testWidgets('UI Flow: Tab navigation, 110 SMS sheet & Bilingual switch',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TimeCamProApp(isTestMode: true));
    expect(find.text('時間相機 Pro'), findsOneWidget);
    expect(find.text('UTC+8 國家標準校時'), findsOneWidget);

    await tester.tap(find.byKey(const Key('appbar_lang_toggle_btn')));
    await tester.pump();
    expect(find.text('TimeCam Pro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open_110_sms_sheet_btn')));
    await tester.pumpAndSettle();
    expect(find.textContaining('0911510914'), findsWidgets);

    await tester.tap(find.byKey(const Key('copy_110_sms_btn')));
    await tester.pumpAndSettle();
  });

  testWidgets('Paywall E2E: 20MB export intercept, PulsingCtaButton & Restore',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TimeCamProApp(isTestMode: true));

    await tester.tap(find.byKey(const Key('appbar_pro_badge_btn')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 625));

    final Finder pulsingScaleFinder = find.descendant(
      of: find.byType(PulsingCtaButton),
      matching: find.byType(ScaleTransition),
    );
    expect(pulsingScaleFinder, findsOneWidget);

    final Finder restoreFinder = find.byKey(const Key('paywall_restore_btn'));
    await tester.ensureVisible(restoreFinder);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(restoreFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('PRO 已解鎖'), findsOneWidget);
  });

  testWidgets(
      'iPhone Duo Dual-Screen Expanded Mode: simultaneous Camera + 20MB Compressor',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TimeCamProApp(isTestMode: true));
    expect(find.text('iPhone Duo 雙屏協作'), findsOneWidget);
    expect(find.byKey(const Key('camera_main_shutter_btn')), findsOneWidget);
    expect(find.byKey(const Key('compressor_export_cta_btn')), findsOneWidget);
  });
}
