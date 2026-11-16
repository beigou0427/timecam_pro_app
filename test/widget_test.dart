import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timecam_pro_app/core/epa_reward_calculator_engine.dart';
import 'package:timecam_pro_app/core/video_compression_engine.dart';
import 'package:timecam_pro_app/core/watermark_location_engine.dart';
import 'package:timecam_pro_app/main.dart';

void main() {
  test('Core & PM Engines Verification', () {
    final CompressionPlan p = VideoCompressionEngine.createPlan(sourceSizeMB: 142.8, clipDurationSeconds: 15.0);
    expect(p.isValid, isTrue);
    expect(p.estimatedOutputMB, lessThanOrEqualTo(19.0));
    final DateTime t = DateTime.utc(2026, 11, 16, 6, 30, 0);
    expect(WatermarkLocationEngine.formatTaiwanTimestamp(t), equals('2026/11/16 14:30:00'));
    final EpaRewardEstimate est = EpaRewardCalculatorEngine.calculateReward(cityId: 'taipei_city', item: EpaViolationItem.cigaretteButt);
    expect(est.casesToBreakEvenPro, equals(1));
  });

  testWidgets('TimeCamProApp UI & iPhone Duo Smoke Test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TimeCamProApp(isTestMode: true));
    expect(find.text('時間相機 Pro'), findsOneWidget);
    expect(find.byKey(const Key('camera_main_shutter_btn')), findsOneWidget);
  });
}
