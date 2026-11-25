import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/native_hardware_bridge.dart';
import 'core/persona_positioning_engine.dart';
import 'core/statutory_urgency_engine.dart';
import 'core/storekit_iap_service.dart';
import 'core/taiwan_report_repository.dart';
import 'core/user_preferences_state.dart';
import 'core/video_compression_engine.dart';
import 'core/watermark_location_engine.dart';
import 'ui/tabs/camera_evidence_tab.dart';
import 'ui/tabs/report_portal_tab.dart';
import 'ui/tabs/video_compressor_tab.dart';
import 'ui/widgets/export_handoff_banner.dart';
import 'ui/widgets/paywall_sheet.dart';
import 'ui/widgets/quick_start_guide_sheet.dart';

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
    this.initialZh,
    this.initialStateJsonForTest,
    this.onStateSavedForTest,
  });

  final bool isTestMode;
  final bool? initialZh;
  final String? initialStateJsonForTest;
  final ValueChanged<String>? onStateSavedForTest;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TimeCam Pro',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('zh', 'TW'),
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF5B73B),
          secondary: Color(0xFF34C759),
          surface: Color(0xFF161618),
          onSurface: Color(0xFFF5F5F7),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF000000),
          foregroundColor: Color(0xFFF5F5F7),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
        dividerColor: const Color(0x12FFFFFF),
        sliderTheme: SliderThemeData(
          activeTrackColor: const Color(0xFFF5B73B),
          inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
          thumbColor: const Color(0xFFF5F5F7),
          overlayColor: const Color(0xFFF5B73B).withValues(alpha: 0.16),
          trackHeight: 3,
        ),
      ),
      home: TimeCamHomeShell(
        isTestMode: isTestMode,
        initialZh: initialZh,
        initialStateJsonForTest: initialStateJsonForTest,
        onStateSavedForTest: onStateSavedForTest,
      ),
    );
  }
}

class TimeCamHomeShell extends StatefulWidget {
  const TimeCamHomeShell({
    super.key,
    required this.isTestMode,
    required this.initialZh,
    this.initialStateJsonForTest,
    this.onStateSavedForTest,
  });

  final bool isTestMode;
  final bool? initialZh;
  final String? initialStateJsonForTest;
  final ValueChanged<String>? onStateSavedForTest;

  @override
  State<TimeCamHomeShell> createState() => _TimeCamHomeShellState();
}

class _TimeCamHomeShellState extends State<TimeCamHomeShell>
    with WidgetsBindingObserver {
  final GlobalKey _camTabKey = GlobalKey();
  final GlobalKey _compTabKey = GlobalKey();
  final GlobalKey _portTabKey = GlobalKey();

  static const String _supportEmail = 'bagelj04a09@gmail.com';
  static const String _manageSubsUrl =
      'https://apps.apple.com/account/subscriptions';

  int _currentTabIndex = 0;
  int _duoRightPaneIndex = 0;
  UserPersonaMode _activePersona = UserPersonaMode.fieldEngineering;
  UserPreferencesState _prefs = const UserPreferencesState();
  late bool _isZh;
  bool _isProUnlocked = false;
  bool _isPaywallOpen = false;
  int _usedFreeExports = 0;
  double _totalSavedMB = 0.0;
  int _captureSuccessCount = 0;
  bool _hasRequestedReview = false;
  String _companyHeader = '';
  bool _dismissedCameraTip = false;
  bool _dismissedCompressTip = false;
  bool _dismissedPortalTip = false;
  Map<String, dynamic>? _recordedVideoForCompressor;
  ExportHandoffContext? _activeHandoff;
  late List<EvidenceCaseRecord> _cases;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isZh = widget.initialZh ??
        (widget.isTestMode
            ? true
            : WidgetsBinding.instance.platformDispatcher.locale.languageCode
                .toLowerCase()
                .startsWith('zh'));
    _cases = TaiwanReportRepository.createInitialCases(
      DateTime.now().toUtc(),
      isZh: _isZh,
    );
    if (widget.isTestMode &&
        widget.initialStateJsonForTest != null &&
        widget.initialStateJsonForTest!.isNotEmpty) {
      _applyPersistedJson(widget.initialStateJsonForTest!, useSetState: false);
    }
    _initPersistenceAndStoreKit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verifyLiveStoreKitEntitlements();
    }
  }

  void _updatePreferences(UserPreferencesState next) {
    if (next == _prefs) return;
    setState(() {
      _prefs = next;
    });
    _persistState();
  }

  void _applyVerifiedProductIds(
    List<String> activeIds, {
    bool showSuccessToast = false,
  }) {
    if (!mounted) return;
    final Set<String> knownIds =
        ProPlanTier.values.map((ProPlanTier t) => t.productId).toSet();
    final String? matchedId = activeIds.cast<String?>().firstWhere(
          (String? id) => id != null && knownIds.contains(id),
          orElse: () => null,
        );
    final bool hasActive = matchedId != null;
    if (hasActive != _isProUnlocked) {
      if (hasActive && showSuccessToast) {
        _applyProUnlock(ProPlanTier.fromProductId(matchedId));
      } else {
        setState(() => _isProUnlocked = hasActive);
        _persistState();
      }
    }
  }

  Future<void> _verifyLiveStoreKitEntitlements({
    bool showSuccessToast = false,
  }) async {
    if (widget.isTestMode || !NativeHardwareBridge.isLiveIosRuntime) return;
    final List<String>? activeIds =
        await NativeHardwareBridge.fetchActiveStoreKitEntitlements(
      isTestMode: widget.isTestMode,
    );
    if (!mounted || activeIds == null) return;
    _applyVerifiedProductIds(activeIds, showSuccessToast: showSuccessToast);
  }

  Future<void> _initPersistenceAndStoreKit() async {
    NativeHardwareBridge.setNativeEventHandlers(
      onStoreKitEntitlementsChanged: (List<String> activeIds) {
        _applyVerifiedProductIds(activeIds, showSuccessToast: true);
      },
    );

    if (!NativeHardwareBridge.isLiveIosRuntime) {
      StorekitIapService.initialize(
        onPurchaseEvent: (String productId, bool isRestore) async {
          if (!mounted) return;
          _applyProUnlock(ProPlanTier.fromProductId(productId));
        },
      );
    }

    if (widget.isTestMode) return;
    final String? raw = await NativeHardwareBridge.loadPersistedState(
      isTestMode: widget.isTestMode,
    );
    final int keychainQuota = await NativeHardwareBridge.loadKeychainQuota(
      isTestMode: widget.isTestMode,
    );
    if (!mounted) return;

    if (raw != null && raw.isNotEmpty) {
      _applyPersistedJson(raw, useSetState: true);
    }
    if (keychainQuota > _usedFreeExports) {
      setState(() => _usedFreeExports = keychainQuota);
    }
    await _verifyLiveStoreKitEntitlements();
  }

  void _applyPersistedJson(String raw, {required bool useSetState}) {
    try {
      final Map<String, dynamic> data =
          jsonDecode(raw) as Map<String, dynamic>;
      final bool restoredPro = data['isProUnlocked'] == true;
      final int restoredUsed = (data['usedFreeExports'] as num?)?.toInt() ?? 0;
      final double restoredSaved =
          (data['totalSavedMB'] as num?)?.toDouble() ?? 0.0;
      final int restoredCaptures =
          (data['captureSuccessCount'] as num?)?.toInt() ?? 0;
      final bool restoredReviewed = data['hasRequestedReview'] == true;
      final String restoredCompanyHeader =
          data['companyHeader']?.toString() ?? '';
      final bool restoredCamTip = data['dismissedCameraTip'] == true;
      final bool restoredCompTip = data['dismissedCompressTip'] == true;
      final bool restoredPortTip = data['dismissedPortalTip'] == true;
      final String? personaName = data['activePersona']?.toString();
      final UserPersonaMode restoredPersona = UserPersonaMode.values.firstWhere(
        (UserPersonaMode m) => m.name == personaName,
        orElse: () => UserPersonaMode.fieldEngineering,
      );
      final UserPreferencesState restoredPrefs =
          UserPreferencesState.fromJson(data['preferences']);
      final List<dynamic>? rawCases = data['cases'] as List<dynamic>?;
      final List<EvidenceCaseRecord> restoredCases = <EvidenceCaseRecord>[];
      if (rawCases != null) {
        for (final dynamic item in rawCases) {
          if (item is Map<String, dynamic>) {
            final String statusName =
                item['status']?.toString() ?? CaseSubmissionStatus.pending.name;
            final CaseSubmissionStatus status = CaseSubmissionStatus.values
                .firstWhere(
              (CaseSubmissionStatus s) => s.name == statusName,
              orElse: () => CaseSubmissionStatus.pending,
            );
            restoredCases.add(
              EvidenceCaseRecord(
                id: item['id']?.toString() ?? 'CASE-RESTORED',
                capturedAtUtc: DateTime.tryParse(
                      item['capturedAtUtc']?.toString() ?? '',
                    )?.toUtc() ??
                    DateTime.now().toUtc(),
                formattedTimeUtc8: item['formattedTimeUtc8']?.toString() ?? '',
                address: item['address']?.toString() ?? '',
                plateOrNote: item['plateOrNote']?.toString() ?? '',
                statuteCode: item['statuteCode']?.toString() ?? 'FIELD_AUDIT',
                compressedSizeMB:
                    (item['compressedSizeMB'] as num?)?.toDouble() ?? 18.0,
                status: status,
                thumbnailPath: item['thumbnailPath']?.toString(),
                isSample: item['isSample'] == true,
                latitude: (item['latitude'] as num?)?.toDouble(),
                longitude: (item['longitude'] as num?)?.toDouble(),
                altitudeMeters: (item['altitudeMeters'] as num?)?.toDouble(),
                evidenceHash: item['evidenceHash']?.toString(),
                personaMode: item['personaMode']?.toString(),
              ),
            );
          }
        }
      }

      void assignState() {
        _isProUnlocked = restoredPro;
        _usedFreeExports = restoredUsed;
        _totalSavedMB = restoredSaved;
        _captureSuccessCount = restoredCaptures;
        _hasRequestedReview = restoredReviewed;
        _companyHeader = restoredCompanyHeader;
        _dismissedCameraTip = restoredCamTip;
        _dismissedCompressTip = restoredCompTip;
        _dismissedPortalTip = restoredPortTip;
        _activePersona = restoredPersona;
        _prefs = restoredPrefs;
        if (widget.initialZh == null && restoredPrefs.preferredIsZh != null) {
          _isZh = restoredPrefs.preferredIsZh!;
        }
        if (restoredCases.isNotEmpty) {
          _cases = restoredCases;
        }
      }

      if (useSetState) {
        setState(assignState);
      } else {
        assignState();
      }
    } catch (e) {
      debugPrint('[TimeCamHomeShell] Failed to decode persisted state: $e');
    }
  }

  Future<void> _persistState() async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'isProUnlocked': _isProUnlocked,
      'usedFreeExports': _usedFreeExports,
      'totalSavedMB': _totalSavedMB,
      'captureSuccessCount': _captureSuccessCount,
      'hasRequestedReview': _hasRequestedReview,
      'companyHeader': _companyHeader,
      'dismissedCameraTip': _dismissedCameraTip,
      'dismissedCompressTip': _dismissedCompressTip,
      'dismissedPortalTip': _dismissedPortalTip,
      'activePersona': _activePersona.name,
      'preferences': _prefs.toJson(),
      'cases': _cases
          .map(
            (EvidenceCaseRecord c) => <String, dynamic>{
              'id': c.id,
              'capturedAtUtc': c.capturedAtUtc.toIso8601String(),
              'formattedTimeUtc8': c.formattedTimeUtc8,
              'address': c.address,
              'plateOrNote': c.plateOrNote,
              'statuteCode': c.statuteCode,
              'compressedSizeMB': c.compressedSizeMB,
              'status': c.status.name,
              'thumbnailPath': c.thumbnailPath,
              'isSample': c.isSample,
              'latitude': c.latitude,
              'longitude': c.longitude,
              'altitudeMeters': c.altitudeMeters,
              'evidenceHash': c.evidenceHash,
              'personaMode': c.personaMode,
            },
          )
          .toList(growable: false),
    };
    final String encoded = jsonEncode(payload);
    widget.onStateSavedForTest?.call(encoded);
    if (widget.isTestMode) return;
    await NativeHardwareBridge.savePersistedState(
      encoded,
      isTestMode: false,
    );
  }

  void _applyProUnlock(ProPlanTier tier) {
    final bool wasUnlocked = _isProUnlocked;
    if (_isPaywallOpen && Navigator.of(context).canPop()) {
      _isPaywallOpen = false;
      Navigator.of(context).pop();
    }
    setState(() {
      _isProUnlocked = true;
    });
    _persistState();

    if (!wasUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1F1F23),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          content: Text(
            _isZh
                ? '已解鎖「${tier.localizedTitle(isZh: true)}」'
                : 'Unlocked "${tier.localizedTitle(isZh: false)}"',
            style: const TextStyle(
              color: Color(0xFF34C759),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _openProMemberSheet() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161618),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(99)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _isZh ? '時間相機 Pro 會員已啟用' : 'TimeCam Pro Active',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isZh
                        ? '已解鎖完整企業抬頭浮水印、批次多筆 A4 PDF 報告與無限影片壓縮匯出。'
                        : 'Unlocked custom company watermarks, batch A4 PDF exports & unlimited video compression.',
                    style: const TextStyle(
                      color: Color(0xFFA1A1AA),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      key: const Key('pro_member_manage_subs_btn'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF5B73B),
                        side: const BorderSide(color: Color(0xFFF5B73B)),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        NativeHardwareBridge.openExternalUrl(
                          _manageSubsUrl,
                          isTestMode: widget.isTestMode,
                        );
                      },
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: Text(
                        _isZh
                            ? '前往 Apple ID 管理或取消訂閱'
                            : 'Manage Subscription in Apple ID',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openQuickGuide() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return QuickStartGuideSheet(
          isZh: _isZh,
          isTestMode: widget.isTestMode,
          onJumpToTab: (int tabIdx) {
            setState(() {
              _currentTabIndex = tabIdx;
              if (tabIdx == 1) _duoRightPaneIndex = 0;
              if (tabIdx == 2) _duoRightPaneIndex = 1;
            });
          },
          onOpenSettings: () {
            NativeHardwareBridge.openAppSettings(
              isTestMode: widget.isTestMode,
            );
          },
          onContactSupport: () async {
            final ScaffoldMessengerState messenger =
                ScaffoldMessenger.of(context);
            await Clipboard.setData(
              const ClipboardData(text: _supportEmail),
            );
            final String body = Uri.encodeComponent(
              'App: TimeCam Pro 1.0.0+15\n'
              'Mode: ${_activePersona.name}\n'
              'Pro: $_isProUnlocked\n'
              'Description / Issue:\n',
            );
            final bool opened = await NativeHardwareBridge.openExternalUrl(
              'mailto:$_supportEmail?subject=TimeCam%20Pro%20Support%20(v1.0.0%2B15)&body=$body',
              isTestMode: widget.isTestMode,
            );
            if (!mounted) return;
            messenger.showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF1F1F23),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                content: Text(
                  opened
                      ? (_isZh
                          ? '已開啟郵件客服 ($_supportEmail)'
                          : 'Opened mail support ($_supportEmail)')
                      : (_isZh
                          ? '已複製客服信箱：$_supportEmail'
                          : 'Copied support email: $_supportEmail'),
                  style: const TextStyle(
                    color: Color(0xFF34C759),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openPaywall(String triggerReason) async {
    if (_isPaywallOpen) return;
    _isPaywallOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return PaywallSheet(
          isZh: _isZh,
          triggerReasonZh: triggerReason,
          triggerReasonEn: triggerReason,
          onUnlockSuccess: (ProPlanTier tier) {
            if (!mounted) return;
            _applyProUnlock(tier);
          },
        );
      },
    );
    _isPaywallOpen = false;
  }

  void _maybeTriggerJoyMomentReview() {
    if (_hasRequestedReview || widget.isTestMode) return;
    _hasRequestedReview = true;
    _persistState();
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      NativeHardwareBridge.requestInAppReview(isTestMode: widget.isTestMode);
    });
  }

  void _handleCaptureEvidence(
    WatermarkSnapshot snap, {
    String? thumbnailPath,
    String? evidenceHash,
  }) {
    final EvidenceCaseRecord newRecord = EvidenceCaseRecord(
      id: 'CASE-${DateTime.now().millisecondsSinceEpoch}',
      capturedAtUtc: DateTime.now().toUtc(),
      formattedTimeUtc8: snap.utcPlus8FormattedTime,
      address: snap.fullAddress,
      plateOrNote: snap.plateOrProjectNote.isEmpty
          ? (_isZh ? '現場時間存證' : 'Timestamp Record')
          : snap.plateOrProjectNote,
      statuteCode: 'FIELD_AUDIT',
      compressedSizeMB: 3.2,
      status: CaseSubmissionStatus.pending,
      thumbnailPath: thumbnailPath,
      isSample: false,
      latitude: snap.hasValidGps ? snap.latitude : null,
      longitude: snap.hasValidGps ? snap.longitude : null,
      altitudeMeters: snap.hasValidGps ? snap.altitudeMeters : null,
      evidenceHash: evidenceHash,
      personaMode: _activePersona.name,
    );
    setState(() {
      final List<EvidenceCaseRecord> realCases = _cases
          .where((EvidenceCaseRecord c) => !c.isSample)
          .toList(growable: false);
      _cases = <EvidenceCaseRecord>[newRecord, ...realCases];
      _captureSuccessCount += 1;
    });
    _persistState();
    if (_captureSuccessCount >= 2) {
      _maybeTriggerJoyMomentReview();
    }
  }

  void _handleRecordedVideo(Map<String, dynamic> videoMeta) {
    setState(() {
      _recordedVideoForCompressor = videoMeta;
      _currentTabIndex = 1;
      _duoRightPaneIndex = 0;
    });
  }

  void _handleExportCompleted({
    required CompressionPlan plan,
    required String plateNumber,
    required String address,
    required double actualOutputMB,
    required String clipboardSummary,
  }) {
    final String nowFormatted =
        WatermarkLocationEngine.formatLocalTimestamp(DateTime.now());
    final EvidenceCaseRecord newRecord = EvidenceCaseRecord(
      id: 'CASE-${DateTime.now().millisecondsSinceEpoch}',
      capturedAtUtc: DateTime.now().toUtc(),
      formattedTimeUtc8: nowFormatted,
      address: address,
      plateOrNote: '$plateNumber (${actualOutputMB.toStringAsFixed(1)} MB)',
      statuteCode: 'VIDEO_COMPRESSED',
      compressedSizeMB: actualOutputMB,
      status: CaseSubmissionStatus.archived,
      isSample: false,
      personaMode: _activePersona.name,
    );
    setState(() {
      final List<EvidenceCaseRecord> realCases = _cases
          .where((EvidenceCaseRecord c) => !c.isSample)
          .toList(growable: false);
      _cases = <EvidenceCaseRecord>[newRecord, ...realCases];
      _activeHandoff = ExportHandoffBanner.createContext(
        plateNumber: plateNumber,
        address: address,
        outputSizeMB: actualOutputMB,
        clipboardSummary: clipboardSummary,
      );
      _currentTabIndex = 2;
      _duoRightPaneIndex = 1;
    });
    _persistState();
    _maybeTriggerJoyMomentReview();
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
    _persistState();
  }

  void _handleDeleteCase(String caseId) {
    String? thumbPath;
    for (final EvidenceCaseRecord item in _cases) {
      if (item.id == caseId) {
        thumbPath = item.thumbnailPath;
        break;
      }
    }
    if (thumbPath != null && thumbPath.isNotEmpty) {
      NativeHardwareBridge.deleteCaseThumbnail(
        thumbPath,
        isTestMode: widget.isTestMode,
      );
    }
    setState(() {
      _cases = _cases
          .where((EvidenceCaseRecord item) => item.id != caseId)
          .toList(growable: false);
    });
    _persistState();
  }

  void _handleEditCaseNote(String caseId, String nextNote) {
    final String trimmed = nextNote.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _cases = _cases.map((EvidenceCaseRecord item) {
        if (item.id == caseId) {
          return item.copyWith(plateOrNote: trimmed);
        }
        return item;
      }).toList(growable: false);
    });
    _persistState();
  }

  PreferredSizeWidget _buildTopAppBar({required bool isDuoExpanded}) {
    return AppBar(
      toolbarHeight: 42,
      titleSpacing: 16,
      title: Row(
        children: <Widget>[
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _isZh ? '時間相機 Pro' : 'TimeCam Pro',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: -0.3,
                  color: Color(0xFFF5F5F7),
                ),
              ),
            ),
          ),
          if (isDuoExpanded) ...<Widget>[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.all(Radius.circular(999)),
              ),
              child: Text(
                _isZh ? '雙屏協作' : 'Dual-Pane',
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        GestureDetector(
          key: const Key('appbar_help_guide_btn'),
          onTap: _openQuickGuide,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.help_outline_rounded,
              size: 18,
              color: Color(0xFFA1A1AA),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          key: const Key('appbar_lang_toggle_btn'),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _isZh = !_isZh;
              _prefs = _prefs.copyWith(preferredIsZh: _isZh);
              if (_cases.every((EvidenceCaseRecord c) => c.isSample)) {
                _cases = TaiwanReportRepository.createInitialCases(
                  DateTime.now().toUtc(),
                  isZh: _isZh,
                );
              }
            });
            _persistState();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.all(Radius.circular(999)),
            ),
            child: Text(
              _isZh ? 'EN' : '繁中',
              style: const TextStyle(
                color: Color(0xFF8E8E93),
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            key: const Key('appbar_pro_badge_btn'),
            onTap: () {
              if (_isProUnlocked) {
                _openProMemberSheet();
              } else {
                HapticFeedback.selectionClick();
                _openPaywall(
                  _isZh
                      ? '無限次 20MB 壓縮、自訂企業抬頭浮水印與完整批次 A4 PDF 報告'
                      : 'Unlimited 20MB exports, custom company headers & batch A4 PDF reports',
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isProUnlocked
                    ? const Color(0xFF34C759).withValues(alpha: 0.16)
                    : const Color(0xFFF5B73B),
                borderRadius: const BorderRadius.all(Radius.circular(999)),
              ),
              child: Text(
                _isProUnlocked
                    ? (_isZh ? 'PRO 已解鎖' : 'PRO')
                    : 'Pro',
                style: TextStyle(
                  color: _isProUnlocked
                      ? const Color(0xFF34C759)
                      : const Color(0xFF09090B),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDuoToggle() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            color: Color(0xFF161618),
            borderRadius: BorderRadius.all(Radius.circular(11)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _SegmentedPillItem(
                  label: _isZh ? '20MB 壓縮' : 'Compress',
                  selected: _duoRightPaneIndex == 0,
                  onTap: () => setState(() => _duoRightPaneIndex = 0),
                ),
              ),
              Expanded(
                child: _SegmentedPillItem(
                  label: _isZh
                      ? '案件與報告 (${_cases.length})'
                      : 'Cases (${_cases.length})',
                  selected: _duoRightPaneIndex == 1,
                  onTap: () => setState(() => _duoRightPaneIndex = 1),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _tabCam() => CameraEvidenceTab(
        key: _camTabKey,
        isZh: _isZh,
        isProUnlocked: _isProUnlocked,
        activePersona: _activePersona,
        companyHeader: _companyHeader,
        enableLiveClock: !widget.isTestMode,
        permissionsReady: true,
        showFirstTimeTip: !_dismissedCameraTip,
        preferences: _prefs,
        onPreferencesChanged: _updatePreferences,
        onDismissFirstTimeTip: () {
          if (_dismissedCameraTip) return;
          setState(() => _dismissedCameraTip = true);
          _persistState();
        },
        onPersonaChanged: (UserPersonaMode m) {
          setState(() => _activePersona = m);
          _persistState();
        },
        onCompanyHeaderChanged: (String v) {
          setState(() => _companyHeader = v);
          _persistState();
        },
        onCaptureEvidence: _handleCaptureEvidence,
        onRecordedVideo: _handleRecordedVideo,
        onRequestPaywall: _openPaywall,
      );

  Widget _tabComp() => VideoCompressorTab(
        key: _compTabKey,
        isZh: _isZh,
        isProUnlocked: _isProUnlocked,
        isTestMode: widget.isTestMode,
        externalRealVideo: _recordedVideoForCompressor,
        usedFreeExports: _usedFreeExports,
        totalSavedMB: _totalSavedMB,
        showFirstTimeTip: !_dismissedCompressTip,
        preferences: _prefs,
        onPreferencesChanged: _updatePreferences,
        onDismissFirstTimeTip: () {
          if (_dismissedCompressTip) return;
          setState(() => _dismissedCompressTip = true);
          _persistState();
        },
        onQuotaUpdated: (int used, double saved) {
          setState(() {
            _usedFreeExports = used;
            _totalSavedMB = saved;
          });
          NativeHardwareBridge.saveKeychainQuota(
            used,
            isTestMode: widget.isTestMode,
          );
          _persistState();
        },
        onRequestPaywall: _openPaywall,
        onExportCompleted: _handleExportCompleted,
      );

  Widget _tabPort() => ReportPortalTab(
        key: _portTabKey,
        isZh: _isZh,
        isProUnlocked: _isProUnlocked,
        isTestMode: widget.isTestMode,
        activePersona: _activePersona,
        companyHeader: _companyHeader,
        cases: _cases,
        activeHandoff: _activeHandoff,
        showFirstTimeTip: !_dismissedPortalTip,
        preferences: _prefs,
        onPreferencesChanged: _updatePreferences,
        onDismissFirstTimeTip: () {
          if (_dismissedPortalTip) return;
          setState(() => _dismissedPortalTip = true);
          _persistState();
        },
        onDismissHandoff: () => setState(() => _activeHandoff = null),
        onUpdateCaseStatus: _handleUpdateCaseStatus,
        onDeleteCase: _handleDeleteCase,
        onEditCaseNote: _handleEditCaseNote,
        onRequestPaywall: _openPaywall,
      );

  Widget _buildDuoBody() => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(flex: 5, child: _tabCam()),
          Container(width: 1, color: Colors.white.withValues(alpha: 0.08)),
          Expanded(
            flex: 6,
            child: Column(
              children: <Widget>[
                _buildDuoToggle(),
                Expanded(
                  child: IndexedStack(
                    index: _duoRightPaneIndex,
                    children: <Widget>[_tabComp(), _tabPort()],
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildBottomTabBar() {
    final bool hasUrgentCase = _isZh &&
        _activePersona == UserPersonaMode.trafficEvidence &&
        StatutoryUrgencyEngine.scanCases(
          _cases,
          DateTime.now().toUtc(),
        ).hasUrgentAlert;

    final List<({IconData icon, IconData activeIcon, String label, bool badge})>
        items = <({IconData icon, IconData activeIcon, String label, bool badge})>[
      (
        icon: Icons.camera_alt_outlined,
        activeIcon: Icons.camera_alt_rounded,
        label: _isZh ? '相機' : 'Camera',
        badge: false,
      ),
      (
        icon: Icons.compress_rounded,
        activeIcon: Icons.compress_rounded,
        label: _isZh ? '20MB壓縮' : 'Compress',
        badge: false,
      ),
      (
        icon: Icons.folder_outlined,
        activeIcon: Icons.folder_rounded,
        label: _isZh ? '案件與報告' : 'Cases',
        badge: hasUrgentCase,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: List<Widget>.generate(items.length, (int i) {
              final bool selected = _currentTabIndex == i;
              final item = items[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_currentTabIndex == i) return;
                    HapticFeedback.selectionClick();
                    setState(() => _currentTabIndex = i);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Icon(
                            selected ? item.activeIcon : item.icon,
                            size: 22,
                            color: selected
                                ? const Color(0xFFF5F5F7)
                                : const Color(0xFF636366),
                          ),
                          if (item.badge)
                            Positioned(
                              right: -4,
                              top: -2,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF5B73B),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected
                              ? const Color(0xFFF5F5F7)
                              : const Color(0xFF636366),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (BuildContext ctx, BoxConstraints c) {
          final bool isDuo = c.maxWidth >= 720;
          return Scaffold(
            backgroundColor: const Color(0xFF000000),
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(42),
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.2,
                child: _buildTopAppBar(isDuoExpanded: isDuo),
              ),
            ),
            body: isDuo
                ? _buildDuoBody()
                : IndexedStack(
                    index: _currentTabIndex,
                    children: <Widget>[
                      _tabCam(),
                      _tabComp(),
                      _tabPort(),
                    ],
                  ),
            bottomNavigationBar: isDuo
                ? null
                : MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.2,
                    child: _buildBottomTabBar(),
                  ),
          );
        },
      );
}

class _SegmentedPillItem extends StatelessWidget {
  const _SegmentedPillItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2C2C2E) : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.white : const Color(0xFF8E8E93),
            ),
          ),
        ),
      ),
    );
  }
}
