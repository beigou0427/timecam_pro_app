import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timecam_pro_app/core/activation_quota_engine.dart';
import 'package:timecam_pro_app/core/ariely_decoy_pricing_engine.dart';
import 'package:timecam_pro_app/core/aso_master_metadata_engine.dart';
import 'package:timecam_pro_app/core/aso_nuclear_10locale_engine.dart';
import 'package:timecam_pro_app/core/campbell_b2b_seat_pricing_engine.dart';
import 'package:timecam_pro_app/core/chamath_north_star_engine.dart';
import 'package:timecam_pro_app/core/chen_referral_viral_engine.dart';
import 'package:timecam_pro_app/core/epa_reward_calculator_engine.dart';
import 'package:timecam_pro_app/core/evidence_integrity_engine.dart';
import 'package:timecam_pro_app/core/eyal_habit_loop_engine.dart';
import 'package:timecam_pro_app/core/hormozi_grand_slam_offer_engine.dart';
import 'package:timecam_pro_app/core/lemkin_expense_receipt_engine.dart';
import 'package:timecam_pro_app/core/naval_pdf_leverage_engine.dart';
import 'package:timecam_pro_app/core/night_plate_enhancer_engine.dart';
import 'package:timecam_pro_app/core/persona_positioning_engine.dart';
import 'package:timecam_pro_app/core/revenue_accelerator_engine.dart';
import 'package:timecam_pro_app/core/statutory_urgency_engine.dart';
import 'package:timecam_pro_app/core/taiwan_report_repository.dart';
import 'package:timecam_pro_app/core/tunguz_intent_routing_engine.dart';
import 'package:timecam_pro_app/core/verna_flash_offer_engine.dart';
import 'package:timecam_pro_app/core/video_compression_engine.dart';
import 'package:timecam_pro_app/core/watermark_location_engine.dart';
import 'package:timecam_pro_app/main.dart';
import 'package:timecam_pro_app/ui/widgets/export_handoff_banner.dart';
import 'package:timecam_pro_app/ui/widgets/paywall_sheet.dart';
import 'package:timecam_pro_app/ui/widgets/taiwan_plate_quick_pad.dart';
import 'package:timecam_pro_app/ui/widgets/viral_share_card_sheet.dart';

void main() {
  test('Stack 1: Core + 10 World-Class PM Engines Verification', () {
    final CompressionPlan p = VideoCompressionEngine.createPlan(sourceSizeMB: 142.8, clipDurationSeconds: 15.0);
    expect(p.isValid, isTrue);
    expect(p.estimatedOutputMB, lessThanOrEqualTo(19.0));
    expect(VideoCompressionEngine.createPlan(sourceSizeMB: double.nan, clipDurationSeconds: 0.0).isValid, isFalse);

    final DateTime t = DateTime.utc(2026, 11, 16, 6, 30, 0);
    expect(WatermarkLocationEngine.formatTaiwanTimestamp(t), equals('2026/11/16 14:30:00'));
    expect(WatermarkLocationEngine.resolve110SmsRecipient('台北市信義區'), equals('0911510914'));
    expect(TaiwanReportRepository.remainingHoursToReport(capturedAtUtc: t.subtract(const Duration(days: 2)), nowUtc: t), equals(120));
    expect(TaiwanPlateQuickPad.sanitizeTaiwanPlate('rcdO88I'), equals('RCD-0881'));
    expect(ExportHandoffBanner.resolvePortalByAddress('臺南市東區中華東路').id, equals('tainan'));

    final QuotaStatusSnapshot q1 = ActivationQuotaEngine.evaluateGate(isProUnlocked: false, usedFreeExports: 0, totalSavedMB: 0.0);
    expect(q1.decision, equals(ExportGateDecision.allowFreeGoldenPass));
    expect(ActivationQuotaEngine.recordSuccessfulExport(current: q1, sourceSizeMB: 142.8, estimatedOutputMB: 18.6).decision, equals(ExportGateDecision.interceptWithPaywall));

    final WatermarkSnapshot s1 = WatermarkLocationEngine.createSnapshot(timestamp: t, plateOrProjectNote: 'ABC-8899', isProUnlocked: true);
    final EvidenceIntegrityCertificate cert = EvidenceIntegrityEngine.generateCertificate(snapshot: s1, isProUnlocked: true);
    expect(EvidenceIntegrityEngine.verifySealIntegrity(snapshot: s1, expectedSealCode: cert.sealCode), isTrue);
    expect(EvidenceIntegrityEngine.verifySealIntegrity(snapshot: s1.copyWith(plateOrProjectNote: 'XYZ-9999'), expectedSealCode: cert.sealCode), isFalse);

    expect(ViralShareCardSheet.maskPlateText('ABC-8899 違停', SharePrivacyMaskMode.maskMiddlePlate), equals('ABC-**99 違停'));
    expect(EpaRewardCalculatorEngine.calculateReward(cityId: 'taipei_city', item: EpaViolationItem.cigaretteButt).casesToBreakEvenPro, equals(1));
    expect(StatutoryUrgencyEngine.scanCases(TaiwanReportRepository.createInitialCases(t), t).hasUrgentAlert, isTrue);
    expect(NightPlateEnhancerEngine.isValidColorMatrix(OpticalEnhanceMode.nightGlareGuard), isTrue);
    expect(PersonaPositioningEngine.buildWatermarkHeader(UserPersonaMode.fieldEngineering, isZh: true), equals('UTC+8 工程巡檢'));
  });

  test(r'Stack 2 & 3: 10 Advisors (NT$30k+) + 10-Locale ASO 100 Score', () {
    expect(RevenueAcceleratorEngine.estimateMonthlyNetProfitNtd(annualCount: 35, personalLifetimeCount: 15, b2bContractorCount: 15), equals(31748));
    expect(HormoziGrandSlamOfferEngine.totalPerceivedValueNtd, equals(4500));
    expect(CampbellB2bSeatPricingEngine.pricePerSeatNtd(B2bTeamBundleTier.crew5Seats), equals(398));
    expect(VernaFlashOfferEngine.formatMmSs(900), equals('15:00'));
    expect(LemkinExpenseReceiptEngine.isValidTaiwanTaxId('04595252'), isTrue);
    expect(LemkinExpenseReceiptEngine.isValidTaiwanTaxId('00000000'), isFalse);
    expect(TunguzIntentRoutingEngine.detectIntent(rawNote: '太陽能案場', isEpa10MbPreset: false, hasExpiringUrgentCase: false), equals(UserAcquisitionIntent.engineeringCompliance));
    expect(ArielyDecoyPricingEngine.isDecoySpreadValid(), isTrue);
    expect(EyalHabitLoopEngine.resolveRank(10), equals(HabitMilestoneRank.goldAuditor));

    final ReferralStatusSnapshot ref0 = ChenReferralViralEngine.initialSnapshot(88);
    expect(ChenReferralViralEngine.isValidInviteCode(ref0.myInviteCode), isTrue);
    expect(ChenReferralViralEngine.redeemFriendCode(current: ref0, friendCode: ref0.myInviteCode).redeemedFriendCount, equals(0));
    expect(NavalPdfLeverageEngine.escapeHtml('<script>'), equals('&lt;script&gt;'));
    expect(ChamathNorthStarEngine.evaluateStatus(installedAtUtc: DateTime.utc(2026, 11, 1), nowUtc: DateTime.utc(2026, 11, 3), capturesCount: 2, exportsCount: 0).stage, equals(NorthStarStage.magicMomentReached));

    expect(AsoMasterMetadataEngine.hasZeroKeywordOverlapBetweenTaiwanLocales(), isTrue);
    expect(AsoNuclear10LocaleEngine.computeAcademicAsoScore(), equals(100));
  });

  testWidgets('Mobile E2E 1: ConversionBanner Persona, QuickPad & 110 SMS', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TimeCamProApp(isTestMode: true));
    await tester.tap(find.byKey(const Key('persona_chip_fieldEngineering')));
    await tester.pump();
    expect(find.textContaining('A4 驗收 PDF'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('open_plate_quick_pad_btn')));
    await tester.tap(find.byKey(const Key('open_plate_quick_pad_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plate_digit_btn_8')));
    await tester.ensureVisible(find.byKey(const Key('apply_plate_quick_pad_btn')));
    await tester.tap(find.byKey(const Key('apply_plate_quick_pad_btn')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('open_110_sms_sheet_btn')));
    await tester.tap(find.byKey(const Key('open_110_sms_sheet_btn')));
    await tester.pumpAndSettle();
    expect(find.textContaining('0911510914'), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('copy_110_sms_btn')));
    await tester.tap(find.byKey(const Key('copy_110_sms_btn')));
    await tester.pumpAndSettle();
  });

  testWidgets('Mobile E2E 2: Tab2 Free Golden Pass, Tab3 Search & Bilingual', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TimeCamProApp(isTestMode: true));
    await tester.tap(find.text('20MB壓縮'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('compressor_export_cta_btn')));
    await tester.tap(find.byKey(const Key('compressor_export_cta_btn')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('portal_city_search_input')));
    await tester.enterText(find.byKey(const Key('portal_city_search_input')), 'tainan');
    await tester.pump();
    expect(find.text('台南市'), findsOneWidget);

    await tester.tap(find.byKey(const Key('appbar_lang_toggle_btn')));
    await tester.pump();
    expect(find.text('TimeCam Pro'), findsOneWidget);
  });

  testWidgets('Paywall Nuclear E2E: Hormozi Stack, PulsingBtn & Restore', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TimeCamProApp(isTestMode: true));
    await tester.tap(find.byKey(const Key('conversion_hook_cta_row')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 625));
    expect(find.textContaining('4500'), findsOneWidget);
    expect(find.textContaining('864'), findsOneWidget);
    expect(find.descendant(of: find.byType(PulsingCtaButton), matching: find.byType(ScaleTransition)), findsOneWidget);
    final Finder restoreBtn = find.byKey(const Key('paywall_restore_btn'));
    await tester.ensureVisible(restoreBtn);
    await tester.tap(restoreBtn);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('PRO 已解鎖'), findsOneWidget);
  });

  testWidgets('iPhone Duo Dual-Screen E2E: Simultaneous Camera + Toggle', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TimeCamProApp(isTestMode: true));
    expect(find.text('iPhone Duo 雙屏協作'), findsOneWidget);
    expect(find.byKey(const Key('camera_main_shutter_btn')), findsOneWidget);
    expect(find.byKey(const Key('compressor_export_cta_btn')), findsOneWidget);
    await tester.tap(find.textContaining('🏛️ 通報'));
    await tester.pump();
    expect(find.byKey(const Key('portal_city_search_input')), findsOneWidget);
  });
}
