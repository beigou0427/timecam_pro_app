import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timecam_pro_app/core/activation_quota_engine.dart';
import 'package:timecam_pro_app/core/evidence_integrity_engine.dart';
import 'package:timecam_pro_app/core/naval_pdf_leverage_engine.dart';
import 'package:timecam_pro_app/core/persona_positioning_engine.dart';
import 'package:timecam_pro_app/core/statutory_urgency_engine.dart';
import 'package:timecam_pro_app/core/taiwan_report_repository.dart';
import 'package:timecam_pro_app/core/user_preferences_state.dart';
import 'package:timecam_pro_app/core/video_compression_engine.dart';
import 'package:timecam_pro_app/core/watermark_location_engine.dart';
import 'package:timecam_pro_app/main.dart';
import 'package:timecam_pro_app/ui/widgets/export_handoff_banner.dart';
import 'package:timecam_pro_app/ui/widgets/taiwan_plate_quick_pad.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Build 13 Core Engines Unit Tests', () {
    test('VideoCompressionEngine creates accurate plans and handles edge cases', () {
      final CompressionPlan plan20 = VideoCompressionEngine.createPlan(
        sourceSizeMB: 142.8,
        clipDurationSeconds: 15.0,
        preset: ReportTargetPreset.trafficPolice20MB,
      );
      expect(plan20.isValid, isTrue);
      expect(plan20.estimatedOutputMB, lessThanOrEqualTo(19.0));
      expect(plan20.clarityGrade, equals(PlateClarityGrade.ultraSharp));

      final CompressionPlan plan10 = VideoCompressionEngine.createPlan(
        sourceSizeMB: 142.8,
        clipDurationSeconds: 15.0,
        preset: ReportTargetPreset.epa10MB,
      );
      expect(plan10.isValid, isTrue);
      expect(plan10.estimatedOutputMB, lessThanOrEqualTo(9.5));

      final CompressionPlan invalidPlan = VideoCompressionEngine.createPlan(
        sourceSizeMB: double.nan,
        clipDurationSeconds: 0.0,
      );
      expect(invalidPlan.isValid, isFalse);
      expect(VideoCompressionEngine.quickTrimPresets, equals(<int>[10, 15, 30, 45]));
    });

    test('WatermarkLocationEngine timestamping and missing GPS handling', () {
      final DateTime sampleUtc = DateTime.utc(2026, 11, 25, 6, 30, 0);
      expect(
        WatermarkLocationEngine.formatTaiwanTimestamp(sampleUtc),
        equals('2026/11/25 14:30:00'),
      );
      expect(
        WatermarkLocationEngine.formatLocalTimestamp(sampleUtc),
        isNotEmpty,
      );
      expect(
        WatermarkLocationEngine.formatLocalTimezoneLabel(sampleUtc),
        isNotEmpty,
      );

      final WatermarkSnapshot noGpsSnapshot = WatermarkLocationEngine.createSnapshot(
        timestamp: sampleUtc,
        plateOrProjectNote: 'ABC-1234',
        isProUnlocked: false,
      );
      expect(noGpsSnapshot.hasValidGps, isFalse);
      expect(noGpsSnapshot.formattedCoordinates(isZh: true), equals('尚未取得 GPS 定位'));
      expect(noGpsSnapshot.formattedCoordinates(isZh: false), equals('No GPS Fix'));

      final String summary = WatermarkLocationEngine.buildLocationSummaryForShare(
        snapshot: noGpsSnapshot,
        incidentType: EmergencyIncidentType.laneHazard,
        isZh: true,
      );
      expect(summary.contains('現場時間地點摘要'), isTrue);
      expect(summary.contains('ABC-1234'), isTrue);
    });

    test('EvidenceIntegrityEngine FIPS 180-4 SHA-256 and seal verification', () {
      // Standard NIST test vector: SHA-256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
      final String nistHex = EvidenceIntegrityEngine.computeSha256Hex(utf8.encode('abc'));
      expect(nistHex, equals('BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD'));

      final DateTime now = DateTime.utc(2026, 11, 25, 12, 0, 0);
      final WatermarkSnapshot snap = WatermarkLocationEngine.createSnapshot(
        timestamp: now,
        plateOrProjectNote: 'KLS-8899',
        isProUnlocked: true,
      );
      final EvidenceIntegrityCertificate cert = EvidenceIntegrityEngine.generateCertificate(
        snapshot: snap,
        isProUnlocked: true,
      );
      expect(cert.sealCode.startsWith('SHA-'), isTrue);
      expect(cert.sealCode.length, equals(18));
      expect(EvidenceIntegrityEngine.verifySealIntegrity(
        snapshot: snap,
        expectedSealCode: cert.sealCode,
      ), isTrue);

      final WatermarkSnapshot tamperedSnap = snap.copyWith(plateOrProjectNote: 'XYZ-9999');
      expect(EvidenceIntegrityEngine.verifySealIntegrity(
        snapshot: tamperedSnap,
        expectedSealCode: cert.sealCode,
      ), isFalse);
    });

    test('EvidenceCaseRecord immutability on note edit', () {
      final DateTime captureTime = DateTime.utc(2026, 11, 25, 8, 30, 0);
      const String originalHash = 'SHA-9A8B-7C6D-5E4F';
      final EvidenceCaseRecord record = EvidenceCaseRecord(
        id: 'CASE-001',
        capturedAtUtc: captureTime,
        formattedTimeUtc8: '2026/11/25 16:30:00',
        address: '台中市西屯區台灣大道三段99號',
        plateOrNote: 'SITE-04 原案場',
        statuteCode: 'SITE_INSPECTION',
        compressedSizeMB: 18.6,
        status: CaseSubmissionStatus.pending,
        latitude: 24.16184,
        longitude: 120.64685,
        altitudeMeters: 45.2,
        evidenceHash: originalHash,
        personaMode: UserPersonaMode.fieldEngineering.name,
      );

      final EvidenceCaseRecord updated = record.copyWith(
        plateOrNote: 'SITE-04 已複驗合格',
        status: CaseSubmissionStatus.submitted,
      );

      expect(updated.plateOrNote, equals('SITE-04 已複驗合格'));
      expect(updated.status, equals(CaseSubmissionStatus.submitted));
      expect(updated.capturedAtUtc, equals(captureTime));
      expect(updated.latitude, equals(24.16184));
      expect(updated.longitude, equals(120.64685));
      expect(updated.altitudeMeters, equals(45.2));
      expect(updated.evidenceHash, equals(originalHash));
    });

    test('TaiwanReportRepository has 25 portals and honest disclaimers', () {
      expect(TaiwanReportRepository.allCityPortals.length, equals(25));
      final Set<String> portalIds = TaiwanReportRepository.allCityPortals.map((p) => p.id).toSet();
      expect(portalIds.length, equals(25));

      final nationalPortals = TaiwanReportRepository.allCityPortals
          .where((p) => p.region == PortalRegion.national)
          .toList();
      expect(nationalPortals.length, equals(3));

      final disclaimerZh = TaiwanReportRepository.officialDisclaimer(isZh: true);
      final disclaimerEn = TaiwanReportRepository.officialDisclaimer(isZh: false);
      expect(disclaimerZh.contains('非任何政府機關'), isTrue);
      expect(disclaimerEn.contains('not affiliated with any government agency'), isTrue);

      final initialCasesEn = TaiwanReportRepository.createInitialCases(
        DateTime.utc(2026, 11, 25),
        isZh: false,
      );
      expect(initialCasesEn, isNotEmpty);
      expect(initialCasesEn.first.address, isNot(matches(RegExp(r'[\u4e00-\u9fff]'))));
    });

    test('StatutoryUrgencyEngine handles expired and critical urgency states', () {
      final DateTime now = DateTime.utc(2026, 11, 25, 12, 0, 0);
      final EvidenceCaseRecord expiredCase = EvidenceCaseRecord(
        id: 'CASE-EXP',
        capturedAtUtc: now.subtract(const Duration(days: 8)),
        formattedTimeUtc8: '2026/11/17 20:00:00',
        address: '台北市信義區忠孝東路',
        plateOrNote: 'ABC-1234',
        statuteCode: 'ROAD_HAZARD',
        compressedSizeMB: 15.0,
        status: CaseSubmissionStatus.pending,
      );

      final UrgencyRadarSummary summary = StatutoryUrgencyEngine.scanCases([expiredCase], now);
      expect(summary.highestLevel, equals(UrgencyLevel.expired));
      final String bannerTextZh = StatutoryUrgencyEngine.buildAlertBannerText(summary, isZh: true);
      expect(bannerTextZh.contains('已逾 7 日舉發參考期'), isTrue);
    });

    test('UserPreferencesState JSON serialization ignores legacy camera note', () {
      final UserPreferencesState state = UserPreferencesState(
        preferredIsZh: true,
        isVideoMode: false,
        lastCameraNote: 'LEAKED_PLATE_123',
        hasCustomCameraNote: true,
        selectedSpotIndex: 2,
        watermarkOpacity: 0.8,
      );

      final Map<String, dynamic> json = state.toJson();
      expect(json.containsKey('lastCameraNote'), isFalse);
      expect(json.containsKey('hasCustomCameraNote'), isFalse);

      final UserPreferencesState restored = UserPreferencesState.fromJson(json);
      expect(restored.lastCameraNote, isEmpty);
      expect(restored.hasCustomCameraNote, isFalse);
      expect(restored.selectedSpotIndex, equals(2));
      expect(restored.watermarkOpacity, equals(0.8));
    });

    test('ActivationQuotaEngine evaluates free golden pass and paywall trigger', () {
      final QuotaStatusSnapshot q0 = ActivationQuotaEngine.evaluateGate(
        isProUnlocked: false,
        usedFreeExports: 0,
        totalSavedMB: 0.0,
      );
      expect(q0.decision, equals(ExportGateDecision.allowFreeGoldenPass));
      expect(q0.hasFreeGoldenPass, isTrue);

      final QuotaStatusSnapshot q1 = ActivationQuotaEngine.recordSuccessfulExport(
        current: q0,
        sourceSizeMB: 142.8,
        estimatedOutputMB: 18.6,
      );
      expect(q1.decision, equals(ExportGateDecision.interceptWithPaywall));
      expect(q1.hasFreeGoldenPass, isFalse);
      expect(q1.totalSavedMB, closeTo(124.2, 0.1));

      final QuotaStatusSnapshot qPro = ActivationQuotaEngine.evaluateGate(
        isProUnlocked: true,
        usedFreeExports: 5,
        totalSavedMB: 500.0,
      );
      expect(qPro.decision, equals(ExportGateDecision.allowProUnlimited));
    });

    test('NavalPdfLeverageEngine HTML escaping and A4 rendering', () {
      expect(NavalPdfLeverageEngine.escapeHtml('<script>alert("xss")</script>'), equals('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;'));
      final String html = NavalPdfLeverageEngine.renderPrintableA4Html(
        theme: ReportDossierTheme.solarEngineering,
        companyHeader: '宏泰機電工程',
        entries: const <DossierEntry>[
          DossierEntry(
            sequenceNo: 1,
            utcPlus8Time: '2026/11/25 14:32:18',
            address: '台中市西屯區台灣大道三段99號',
            gpsText: '24.16184° N, 120.64685° E',
            integritySealCode: 'SHA-A9F2-C481',
            siteOrPlateNote: 'SITE-04 太陽能案場查驗合格',
          ),
        ],
        isProUnlocked: true,
        isZh: true,
      );
      expect(html.contains('宏泰機電工程'), isTrue);
      expect(html.contains('SHA-A9F2-C481'), isTrue);
      expect(html.toLowerCase().contains('#090c12'), isTrue);
    });

    test('TaiwanPlateQuickPad sanitize plate formatting and non-plate fallback', () {
      expect(TaiwanPlateQuickPad.sanitizeTaiwanPlate('rcdO88I'), equals('RCD-0881'));
      expect(TaiwanPlateQuickPad.sanitizeTaiwanPlate('abc1234'), equals('ABC-1234'));
      expect(TaiwanPlateQuickPad.sanitizeTaiwanPlate('路口行車影像紀錄'), equals(''));
      expect(TaiwanPlateQuickPad.sanitizeTaiwanPlate(''), equals(''));
    });

    test('ExportHandoffBanner resolves Taiwan counties without city collision', () {
      expect(ExportHandoffBanner.resolvePortalByAddress('新竹縣竹北市光明六路10號')?.id, equals('hsinchu_county'));
      expect(ExportHandoffBanner.resolvePortalByAddress('新竹市東區光復路一段')?.id, equals('hsinchu_city'));
      expect(ExportHandoffBanner.resolvePortalByAddress('嘉義縣太保市祥和一路')?.id, equals('chiayi_county'));
      expect(ExportHandoffBanner.resolvePortalByAddress('嘉義市西區中山路')?.id, equals('chiayi_city'));
      expect(ExportHandoffBanner.resolvePortalByAddress('新北市板橋區中山路')?.id, equals('new_taipei'));
      expect(ExportHandoffBanner.resolvePortalByAddress('New Taipei City, Banqiao')?.id, equals('new_taipei'));
      expect(ExportHandoffBanner.resolvePortalByAddress('連江縣馬祖南竿')?.id, equals('lienchiang'));
      expect(ExportHandoffBanner.resolvePortalByAddress('Tokyo, Japan'), isNull);
    });
  });

  group('Build 14 Widget & Responsive E2E Tests', () {
    testWidgets('Persona isolation hides OCR and 110 sheet in engineering mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TimeCamProApp(isTestMode: true));
      await tester.pumpAndSettle();

      // By default in fieldEngineering persona, OCR plate button and 110 SMS button should NOT be visible
      expect(find.byKey(const Key('camera_ocr_plate_btn')), findsNothing);
      expect(find.byKey(const Key('open_110_sms_sheet_btn')), findsNothing);

      // Cycle persona to trafficEvidence
      await tester.tap(find.byKey(const Key('camera_persona_cycle_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('camera_persona_cycle_btn')));
      await tester.pumpAndSettle();

      // In trafficEvidence mode, OCR and 110 sheet are revealed
      expect(find.byKey(const Key('camera_ocr_plate_btn')), findsOneWidget);
      expect(find.byKey(const Key('open_110_sms_sheet_btn')), findsOneWidget);
      expect(find.byKey(const Key('open_plate_quick_pad_btn')), findsOneWidget);

      // Open quick pad on default Chinese note -> must NOT inject fake ABC-1234
      await tester.tap(find.byKey(const Key('open_plate_quick_pad_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('plate_digit_btn_0')), findsOneWidget);
      expect(find.byKey(const Key('plate_digit_btn_9')), findsOneWidget);
      expect(find.byKey(const Key('apply_plate_quick_pad_btn')), findsOneWidget);
      expect(find.text('ABC-1234'), findsNothing);

      await tester.tap(find.byKey(const Key('apply_plate_quick_pad_btn')));
      await tester.pumpAndSettle();
    });

    testWidgets('Video compressor sample preview does not deduct free quota', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TimeCamProApp(isTestMode: true));
      await tester.pumpAndSettle();

      // Switch to Tab 2: 20MB Compression
      await tester.tap(find.text('20MB壓縮'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('compressor_export_cta_btn')), findsOneWidget);
      expect(find.textContaining('內建範例試算'), findsOneWidget);

      // Tapping export CTA on sample clip should trigger demo export handoff, NOT paywall
      await tester.tap(find.byKey(const Key('compressor_export_cta_btn')));
      await tester.pumpAndSettle();

      // Paywall sheet should NOT be displayed
      expect(find.byKey(const Key('paywall_primary_cta_btn')), findsNothing);
    });

    testWidgets('Cases dismissible delete confirmation guard cancels and confirms deletion', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TimeCamProApp(isTestMode: true));
      await tester.pumpAndSettle();

      // Switch to Tab 3: Cases & Reports
      await tester.tap(find.text('案件與報告'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('export_pdf_report_btn')), findsOneWidget);
      expect(find.byKey(const Key('backup_cases_json_btn')), findsOneWidget);

      final dismissibleFinder = find.byType(Dismissible);
      final int initialCount = dismissibleFinder.evaluate().length;
      expect(initialCount, greaterThan(0));

      // Cancel swipe delete -> count unchanged
      await tester.drag(dismissibleFinder.first, const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cancel_delete_case_btn')), findsOneWidget);
      expect(find.byKey(const Key('confirm_delete_case_btn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('cancel_delete_case_btn')));
      await tester.pumpAndSettle();
      expect(find.byType(Dismissible), findsNWidgets(initialCount));

      // Confirm swipe delete -> count decremented by 1
      await tester.drag(find.byType(Dismissible).first, const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_delete_case_btn')));
      await tester.pumpAndSettle();
      expect(find.byType(Dismissible), findsNWidgets(initialCount - 1));
    });

    testWidgets('Paywall sheet compliance: no b2bCrew, honest English copy, manage subs link', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TimeCamProApp(isTestMode: true, initialZh: false));
      await tester.pumpAndSettle();

      // Tap PRO badge in AppBar
      await tester.tap(find.byKey(const Key('appbar_pro_badge_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('paywall_primary_cta_btn')), findsOneWidget);
      expect(find.byKey(const Key('paywall_restore_btn')), findsOneWidget);
      expect(find.byKey(const Key('paywall_manage_subs_btn')), findsOneWidget);
      expect(find.textContaining('statement templates'), findsNothing);
      expect(find.textContaining('JSON record backup'), findsOneWidget);

      // Verify commercial crew bundle is never offered for sale
      expect(find.text('商用買斷版'), findsNothing);
      expect(find.textContaining('crew1990'), findsNothing);

      // Close paywall
      await tester.tap(find.byKey(const Key('paywall_close_btn')));
      await tester.pumpAndSettle();
    });

    testWidgets('Responsive & Accessibility: iPhone SE (375x667) all 3 tabs + Settings zero overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TimeCamProApp(isTestMode: true));
      await tester.pumpAndSettle();

      // Open camera settings sheet
      await tester.tap(find.byKey(const Key('camera_settings_btn')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(180, 40));
      await tester.pumpAndSettle();

      // Switch to Tab 2 Compressor
      await tester.tap(find.text('20MB壓縮'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch to Tab 3 Cases
      await tester.tap(find.text('案件與報告'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Responsive & Accessibility: Dynamic Type 2.0x all 3 tabs zero overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(const TimeCamProApp(isTestMode: true));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch to Tab 2 Compressor under 2.0x text scaling
      await tester.tap(find.text('20MB壓縮'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch to Tab 3 Cases under 2.0x text scaling
      await tester.tap(find.text('案件與報告'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Responsive & Accessibility: iPad dual-pane 1366x1024 layout', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2732, 2048);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TimeCamProApp(isTestMode: true));
      await tester.pumpAndSettle();

      // In iPad landscape width (>720px), both Camera and Side Pane are rendered
      expect(find.byKey(const Key('camera_main_shutter_btn')), findsOneWidget);
      expect(find.byKey(const Key('compressor_export_cta_btn')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Collapse to Split View width (700pt < 720 breakpoint) -> single pane + bottom tabs
      tester.view.physicalSize = const Size(1400, 2048);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('camera_main_shutter_btn')), findsOneWidget);
      expect(find.byKey(const Key('compressor_export_cta_btn')), findsNothing);
      expect(tester.takeException(), isNull);

      // Expand back to full landscape -> dual pane restored without exceptions
      tester.view.physicalSize = const Size(2732, 2048);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('compressor_export_cta_btn')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
