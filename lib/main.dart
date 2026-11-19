import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/persona_positioning_engine.dart';
import 'core/taiwan_report_repository.dart';
import 'core/video_compression_engine.dart';
import 'core/watermark_location_engine.dart';
import 'ui/tabs/camera_evidence_tab.dart';
import 'ui/tabs/report_portal_tab.dart';
import 'ui/tabs/video_compressor_tab.dart';
import 'ui/widgets/conversion_hook_banner.dart';
import 'ui/widgets/paywall_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  runApp(const TimeCamProApp());
}

class TimeCamProApp extends StatelessWidget {
  const TimeCamProApp({
    super.key,
    this.isTestMode = false,
    this.initialZh = true,
  });

  final bool isTestMode;
  final bool initialZh;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '時間相機 Pro - 違規蒐證與水印錄影',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF59E0B),
          secondary: Color(0xFF0284C7),
          surface: Color(0xFF1E293B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: TimeCamHomeShell(
        isTestMode: isTestMode,
        initialZh: initialZh,
      ),
    );
  }
}

class TimeCamHomeShell extends StatefulWidget {
  const TimeCamHomeShell({
    super.key,
    required this.isTestMode,
    required this.initialZh,
  });

  final bool isTestMode;
  final bool initialZh;

  @override
  State<TimeCamHomeShell> createState() => _TimeCamHomeShellState();
}

class _TimeCamHomeShellState extends State<TimeCamHomeShell> {
  int _currentTabIndex = 0;
  int _duoRightPaneIndex = 0;
  UserPersonaMode _activePersona = UserPersonaMode.trafficEvidence;
  late bool _isZh;
  bool _isProUnlocked = false;
  late List<EvidenceCaseRecord> _cases;

  @override
  void initState() {
    super.initState();
    _isZh = widget.initialZh;
    _cases = TaiwanReportRepository.createInitialCases(DateTime.now().toUtc());
  }

  void _openPaywall(String triggerReason) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return PaywallSheet(
          isZh: _isZh,
          triggerReasonZh: triggerReason,
          triggerReasonEn: triggerReason,
          onUnlockSuccess: (ProPlanTier tier) {
            Navigator.of(sheetContext).pop();
            if (!mounted) return;
            setState(() {
              _isProUnlocked = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF10B981),
                content: Text(
                  _isZh
                      ? '🎉 已成功解鎖「${tier.localizedTitle(isZh: true)}」全部專業權限！'
                      : '🎉 Unlocked "${tier.localizedTitle(isZh: false)}" all Pro features!',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleCaptureEvidence(WatermarkSnapshot snap) {
    final EvidenceCaseRecord newRecord = EvidenceCaseRecord(
      id: 'CASE-${DateTime.now().millisecondsSinceEpoch}',
      capturedAtUtc: DateTime.now().toUtc(),
      formattedTimeUtc8: snap.utcPlus8FormattedTime,
      address: snap.fullAddress,
      plateOrNote: snap.plateOrProjectNote.isEmpty
          ? (_isZh ? '現場水印存證紀錄' : 'Field Watermark Record')
          : snap.plateOrProjectNote,
      statuteCode: 'ART_42_SIGNAL',
      compressedSizeMB: 18.5,
      status: CaseSubmissionStatus.pending,
    );
    setState(() {
      _cases = <EvidenceCaseRecord>[newRecord, ..._cases];
    });
  }

  void _handleExportCompleted({
    required CompressionPlan plan,
    required String plateNumber,
    required String address,
  }) {
    final String nowFormatted =
        WatermarkLocationEngine.formatTaiwanTimestamp(DateTime.now());
    final EvidenceCaseRecord newRecord = EvidenceCaseRecord(
      id: 'CASE-${DateTime.now().millisecondsSinceEpoch}',
      capturedAtUtc: DateTime.now().toUtc(),
      formattedTimeUtc8: nowFormatted,
      address: address,
      plateOrNote: '$plateNumber (${plan.formattedEstimatedSize})',
      statuteCode: 'ART_44_PEDESTRIAN',
      compressedSizeMB: plan.estimatedOutputMB,
      status: CaseSubmissionStatus.pending,
    );
    setState(() {
      _cases = <EvidenceCaseRecord>[newRecord, ..._cases];
      _currentTabIndex = 2;
      _duoRightPaneIndex = 1;
    });
  }

  void _handleUpdateCaseStatus(
    String caseId,
    CaseSubmissionStatus nextStatus,
  ) {
    setState(() {
      _cases = _cases.map((EvidenceCaseRecord item) {
        if (item.id == caseId) {
          return item.copyWith(status: nextStatus);
        }
        return item;
      }).toList(growable: false);
    });
  }

    PreferredSizeWidget _buildTopAppBar({required bool isDuoExpanded}) => AppBar(title: Text(_isZh ? '時間相機 Pro' : 'TimeCam Pro'));
  @override
  Widget build(BuildContext context) => Scaffold(appBar: _buildTopAppBar(isDuoExpanded: false), body: Column(children: [ConversionHookBanner(isZh: _isZh, isProUnlocked: _isProUnlocked, activePersona: _activePersona, cases: _cases, onPersonaChanged: (m)=>setState(()=>_activePersona=m), onRequestPaywall: _openPaywall), Expanded(child: IndexedStack(index: _currentTabIndex, children: [CameraEvidenceTab(isZh: _isZh, isProUnlocked: _isProUnlocked, onCaptureEvidence: _handleCaptureEvidence, onRequestPaywall: _openPaywall), VideoCompressorTab(isZh: _isZh, isProUnlocked: _isProUnlocked, onRequestPaywall: _openPaywall, onExportCompleted: _handleExportCompleted), ReportPortalTab(isZh: _isZh, isProUnlocked: _isProUnlocked, cases: _cases, onUpdateCaseStatus: _handleUpdateCaseStatus, onRequestPaywall: _openPaywall)]))]));
}
