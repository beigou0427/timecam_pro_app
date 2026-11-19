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

  PreferredSizeWidget _buildTopAppBar({required bool isDuoExpanded}) {
    return AppBar(
      title: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFF59E0B),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: const Icon(
              Icons.camera_enhance_rounded,
              color: Color(0xFF121212),
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _isZh ? '時間相機 Pro' : 'TimeCam Pro',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          if (isDuoExpanded) ...<Widget>[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
                border: Border.all(color: const Color(0xFF38BDF8)),
              ),
              child: Text(
                _isZh ? 'iPhone Duo 雙屏協作' : 'iPhone Duo Dual-Pane',
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('appbar_lang_toggle_btn'),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() {
              _isZh = !_isZh;
            });
          },
          child: Text(
            _isZh ? 'EN' : '繁中',
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ActionChip(
            key: const Key('appbar_pro_badge_btn'),
            backgroundColor: _isProUnlocked
                ? const Color(0xFF10B981).withValues(alpha: 0.2)
                : const Color(0xFFF59E0B),
            side: BorderSide.none,
            avatar: Icon(
              _isProUnlocked
                  ? Icons.verified_rounded
                  : Icons.workspace_premium_rounded,
              size: 16,
              color: _isProUnlocked
                  ? const Color(0xFF34D399)
                  : const Color(0xFF121212),
            ),
            label: Text(
              _isProUnlocked
                  ? (_isZh ? 'PRO 已解鎖' : 'PRO ACTIVE')
                  : (_isZh ? '升級 Pro' : 'GET PRO'),
              style: TextStyle(
                color: _isProUnlocked
                    ? const Color(0xFF34D399)
                    : const Color(0xFF121212),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            onPressed: () {
              if (!_isProUnlocked) {
                _openPaywall(
                  _isZh
                      ? r'立即升級旗艦終身版 (NT$590) 或 5人工程班組包 (NT$1,990)，永久解鎖 20MB 壓縮、A4 驗收 PDF 與全套法條！'
                      : r'Upgrade to Lifetime ($19.99) or 5-Seat Crew Pack ($59.99) for unlimited 20MB compression & A4 PDFs!',
                );
              }
            },
          ),
        ),
      ],
    );
  }
  Widget _buildBanner() => ConversionHookBanner(isZh: _isZh, isProUnlocked: _isProUnlocked, activePersona: _activePersona, cases: _cases, onPersonaChanged: (UserPersonaMode m) => setState(() => _activePersona = m), onRequestPaywall: _openPaywall);
  Widget _buildDuoToggle() => Padding(padding: const EdgeInsets.all(8), child: Row(children: <Widget>[
    Expanded(child: ChoiceChip(label: Center(child: Text(_isZh ? '⚡ 20MB壓縮' : '⚡ Compress')), selected: _duoRightPaneIndex == 0, onSelected: (_) => setState(() => _duoRightPaneIndex = 0))),
    const SizedBox(width: 8),
    Expanded(child: ChoiceChip(label: Center(child: Text(_isZh ? '🏛️ 通報 (${_cases.length})' : '🏛️ Portals (${_cases.length})')), selected: _duoRightPaneIndex == 1, onSelected: (_) => setState(() => _duoRightPaneIndex = 1))),
  ]));

  Widget _tabCam() => CameraEvidenceTab(isZh: _isZh, isProUnlocked: _isProUnlocked, enableLiveClock: !widget.isTestMode, onCaptureEvidence: _handleCaptureEvidence, onRequestPaywall: _openPaywall);
  Widget _tabComp() => VideoCompressorTab(isZh: _isZh, isProUnlocked: _isProUnlocked, isTestMode: widget.isTestMode, onRequestPaywall: _openPaywall, onExportCompleted: _handleExportCompleted);
  Widget _tabPort() => ReportPortalTab(isZh: _isZh, isProUnlocked: _isProUnlocked, cases: _cases, onUpdateCaseStatus: _handleUpdateCaseStatus, onRequestPaywall: _openPaywall);
  Widget _buildDuoBody() => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    Expanded(flex: 5, child: _tabCam()),
    Container(width: 16, color: const Color(0xFF090D16)),
    Expanded(flex: 6, child: Column(children: <Widget>[_buildDuoToggle(), Expanded(child: IndexedStack(index: _duoRightPaneIndex, children: <Widget>[_tabComp(), _tabPort()]))])),
  ]);
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (BuildContext ctx, BoxConstraints c) {
    final bool isDuo = c.maxWidth >= 720;
    return Scaffold(
      appBar: _buildTopAppBar(isDuoExpanded: isDuo),
      body: Column(children: <Widget>[_buildBanner(), Expanded(child: isDuo ? _buildDuoBody() : IndexedStack(index: _currentTabIndex, children: <Widget>[_tabCam(), _tabComp(), _tabPort()]))]),
      bottomNavigationBar: isDuo ? null : NavigationBar(selectedIndex: _currentTabIndex, onDestinationSelected: (int i) => setState(() => _currentTabIndex = i), destinations: <NavigationDestination>[
        NavigationDestination(icon: const Icon(Icons.camera_alt_rounded), label: _isZh ? '蒐證相機' : 'Camera'),
        NavigationDestination(icon: const Icon(Icons.compress_rounded), label: _isZh ? '20MB壓縮' : 'Compress'),
        NavigationDestination(icon: const Icon(Icons.policy_rounded), label: _isZh ? '通報案件' : 'Portals'),
      ]),
    );
  });
}
