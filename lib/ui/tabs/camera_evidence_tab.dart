import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/evidence_integrity_engine.dart';
import '../../core/native_hardware_bridge.dart';
import '../../core/persona_positioning_engine.dart';
import '../../core/user_preferences_state.dart';
import '../../core/watermark_location_engine.dart';
import '../widgets/quick_start_guide_sheet.dart';
import '../widgets/taiwan_plate_quick_pad.dart';

/// Tab 1：原生全解析度時間與 GPS 存證相機
class CameraEvidenceTab extends StatefulWidget {
  const CameraEvidenceTab({
    super.key,
    required this.isZh,
    required this.isProUnlocked,
    required this.onCaptureEvidence,
    required this.onRequestPaywall,
    this.activePersona = UserPersonaMode.fieldEngineering,
    this.companyHeader = '',
    this.onCompanyHeaderChanged,
    this.onPersonaChanged,
    this.onRecordedVideo,
    this.enableLiveClock = true,
    this.permissionsReady = true,
    this.showFirstTimeTip = false,
    this.onDismissFirstTimeTip,
    this.preferences = const UserPreferencesState(),
    this.onPreferencesChanged,
  });

  final bool isZh;
  final bool isProUnlocked;
  final void Function(
    WatermarkSnapshot snapshot, {
    String? thumbnailPath,
    String? evidenceHash,
  }) onCaptureEvidence;
  final ValueChanged<String> onRequestPaywall;
  final UserPersonaMode activePersona;
  final String companyHeader;
  final ValueChanged<String>? onCompanyHeaderChanged;
  final ValueChanged<UserPersonaMode>? onPersonaChanged;
  final ValueChanged<Map<String, dynamic>>? onRecordedVideo;
  final bool enableLiveClock;
  final bool permissionsReady;
  final bool showFirstTimeTip;
  final VoidCallback? onDismissFirstTimeTip;
  final UserPreferencesState preferences;
  final ValueChanged<UserPreferencesState>? onPreferencesChanged;

  @override
  State<CameraEvidenceTab> createState() => _CameraEvidenceTabState();
}

class _CameraEvidenceTabState extends State<CameraEvidenceTab>
    with WidgetsBindingObserver {
  late final TextEditingController _noteController;
  late final TextEditingController _companyController;
  bool _hasCustomNote = false;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  bool _useLiveDeviceGps = false;
  bool _isSyncingGps = false;
  bool _isCapturing = false;
  bool _isScanningPlate = false;
  bool _shutterFlash = false;
  bool _shutterPressed = false;
  String? _gpsErrorCode;
  String? _liveCity;
  String? _liveStreet;
  double? _liveLat;
  double? _liveLng;
  double? _liveAlt;
  DateTime? _lastGpsSyncAt;
  bool _isVideoMode = false;
  bool _showGridLines = false;
  Uint8List? _cameraPhotoBytes;
  Uint8List? _lastCapturedWatermarkPng;
  String? _lastCapturedSummary;
  double _watermarkOpacity = 0.72;
  double _zoomFactor = 1.0;
  double _pinchBaseZoom = 1.0;
  bool _torchEnabled = false;
  Offset? _focusTapLocalOffset;
  Timer? _focusHideTimer;
  Timer? _shutterFlashTimer;
  EmergencyIncidentType _emergencyIncidentType =
      EmergencyIncidentType.laneHazard;

  static String _defaultNoteFor(UserPersonaMode mode, {required bool isZh}) {
    switch (mode) {
      case UserPersonaMode.fieldEngineering:
        return isZh ? '案場施工查驗紀錄' : 'Site Inspection Log';
      case UserPersonaMode.logisticsProof:
        return isZh ? '配送貨物簽收存證' : 'Delivery Handoff Proof';
      case UserPersonaMode.trafficEvidence:
        return isZh ? '路口行車影像紀錄' : 'Traffic Incident Log';
    }
  }

  void _syncCameraPrefs() {
    widget.onPreferencesChanged?.call(
      widget.preferences.copyWith(
        isVideoMode: _isVideoMode,
        watermarkOpacity: _watermarkOpacity,
        showGridLines: _showGridLines,
        emergencyIncidentType: _emergencyIncidentType,
        cameraZoomFactor: _zoomFactor,
      ),
    );
  }

  void _activateCameraAndGps() {
    NativeHardwareBridge.startLiveCameraSession(
      isTestMode: !widget.enableLiveClock,
    );
    if (_zoomFactor > 1.0) {
      NativeHardwareBridge.setCameraZoom(
        _zoomFactor,
        isTestMode: !widget.enableLiveClock,
      );
    }
    unawaited(_syncRealDeviceGps(silent: true));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watermarkOpacity = widget.preferences.watermarkOpacity;
    _showGridLines = widget.preferences.showGridLines;
    _isVideoMode = widget.preferences.isVideoMode;
    _emergencyIncidentType = widget.preferences.emergencyIncidentType;
    _zoomFactor = widget.preferences.cameraZoomFactor;
    _noteController = TextEditingController(
      text: _defaultNoteFor(widget.activePersona, isZh: widget.isZh),
    );
    _companyController = TextEditingController(text: widget.companyHeader);
    if (widget.enableLiveClock) {
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _now = DateTime.now();
        });
      });
      if (NativeHardwareBridge.isLiveIosRuntime && widget.permissionsReady) {
        _activateCameraAndGps();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!NativeHardwareBridge.isLiveIosRuntime || !widget.enableLiveClock) {
      return;
    }
    if (state == AppLifecycleState.resumed && mounted && widget.permissionsReady) {
      NativeHardwareBridge.startLiveCameraSession(isTestMode: false);
      final DateTime now = DateTime.now();
      if (_lastGpsSyncAt == null ||
          now.difference(_lastGpsSyncAt!) > const Duration(seconds: 60)) {
        unawaited(_syncRealDeviceGps(silent: true));
      }
    } else if (state == AppLifecycleState.paused) {
      NativeHardwareBridge.stopLiveCameraSession(isTestMode: false);
    }
  }

  @override
  void didUpdateWidget(covariant CameraEvidenceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.preferences != oldWidget.preferences) {
      _watermarkOpacity = widget.preferences.watermarkOpacity;
      _showGridLines = widget.preferences.showGridLines;
      _isVideoMode = widget.preferences.isVideoMode;
      _emergencyIncidentType = widget.preferences.emergencyIncidentType;
      _zoomFactor = widget.preferences.cameraZoomFactor;
    }
    if (!oldWidget.permissionsReady &&
        widget.permissionsReady &&
        widget.enableLiveClock &&
        NativeHardwareBridge.isLiveIosRuntime) {
      _activateCameraAndGps();
    }
    if (widget.isZh != oldWidget.isZh &&
        _useLiveDeviceGps &&
        widget.permissionsReady &&
        widget.enableLiveClock &&
        NativeHardwareBridge.isLiveIosRuntime) {
      unawaited(_syncRealDeviceGps(silent: true));
    }
    if (!_hasCustomNote &&
        (widget.activePersona != oldWidget.activePersona ||
            widget.isZh != oldWidget.isZh)) {
      _noteController.text =
          _defaultNoteFor(widget.activePersona, isZh: widget.isZh);
    }
    if (widget.companyHeader != oldWidget.companyHeader &&
        widget.companyHeader != _companyController.text) {
      _companyController.text = widget.companyHeader;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusHideTimer?.cancel();
    _shutterFlashTimer?.cancel();
    _clockTimer?.cancel();
    _noteController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  String _shortPersonaLabel(UserPersonaMode mode) {
    switch (mode) {
      case UserPersonaMode.fieldEngineering:
        return widget.isZh ? '工程巡檢' : 'Field';
      case UserPersonaMode.logisticsProof:
        return widget.isZh ? '配送存證' : 'Delivery';
      case UserPersonaMode.trafficEvidence:
        return widget.isZh ? '行車存證' : 'Traffic';
    }
  }

  void _cyclePersona() {
    HapticFeedback.selectionClick();
    const List<UserPersonaMode> modes = UserPersonaMode.values;
    final int next = (modes.indexOf(widget.activePersona) + 1) % modes.length;
    widget.onPersonaChanged?.call(modes[next]);
  }

  WatermarkSnapshot _currentSnapshot() {
    final bool hasRealGps =
        _useLiveDeviceGps && _liveLat != null && _liveLng != null;
    if (!hasRealGps) {
      final String noGpsText = _gpsErrorCode == 'LOCATION_DENIED'
          ? (widget.isZh
              ? '尚未授權定位（請於系統設定開啟定位）'
              : 'Location denied — enable in Settings')
          : (widget.isZh ? '尚未取得 GPS 定位' : 'No GPS Fix');
      return WatermarkLocationEngine.createSnapshot(
        timestamp: _now,
        cityAndDistrict: '',
        streetAddress: noGpsText,
        latitude: double.nan,
        longitude: double.nan,
        altitudeMeters: double.nan,
        plateOrProjectNote: _noteController.text,
        isTimeVerified: false,
        isProUnlocked: widget.isProUnlocked,
        isZh: widget.isZh,
      );
    }

    return WatermarkLocationEngine.createSnapshot(
      timestamp: _now,
      cityAndDistrict: _liveCity ?? '',
      streetAddress: _liveStreet ?? '',
      latitude: _liveLat!,
      longitude: _liveLng!,
      altitudeMeters: _liveAlt ?? 0.0,
      plateOrProjectNote: _noteController.text,
      isTimeVerified: true,
      isProUnlocked: widget.isProUnlocked,
      isZh: widget.isZh,
    );
  }

  Future<void> _syncRealDeviceGps({bool silent = false}) async {
    if (_isSyncingGps) return;
    if (!silent) HapticFeedback.lightImpact();
    final ScaffoldMessengerState? messenger =
        silent ? null : ScaffoldMessenger.of(context);
    setState(() => _isSyncingGps = true);

    final Map<String, dynamic>? gps =
        await NativeHardwareBridge.fetchLiveGpsAddress(
      isZh: widget.isZh,
      isTestMode: !widget.enableLiveClock,
    );
    if (!mounted) return;

    final String? errCode = gps?['errorCode']?.toString();
    final bool hasCoords = gps != null &&
        gps['latitude'] is num &&
        gps['longitude'] is num &&
        errCode == null;

    setState(() {
      _isSyncingGps = false;
      if (hasCoords) {
        _useLiveDeviceGps = true;
        _gpsErrorCode = null;
        _liveCity = gps['city']?.toString();
        _liveStreet = gps['street']?.toString();
        _liveLat = (gps['latitude'] as num).toDouble();
        _liveLng = (gps['longitude'] as num).toDouble();
        _liveAlt = (gps['altitude'] as num?)?.toDouble();
        _lastGpsSyncAt = DateTime.now();
      } else {
        _gpsErrorCode = errCode ?? 'LOCATION_UNAVAILABLE';
      }
    });

    if (messenger != null) {
      final bool isDenied = _gpsErrorCode == 'LOCATION_DENIED';
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1F1F23),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          content: Text(
            hasCoords
                ? (widget.isZh ? '已更新即時 GPS 門牌' : 'Live GPS updated')
                : (isDenied
                    ? (widget.isZh
                        ? '尚未授權定位權限，請前往設定開啟'
                        : 'Location permission denied. Enable in Settings.')
                    : (widget.isZh
                        ? '暫無法取得衛星定位（請移至戶外後再試）'
                        : 'GPS signal unavailable indoors. Try outdoors.')),
            style: TextStyle(
              color: hasCoords
                  ? const Color(0xFF34C759)
                  : const Color(0xFFF5B73B),
              fontWeight: FontWeight.w600,
            ),
          ),
          action: !hasCoords
              ? SnackBarAction(
                  label: widget.isZh ? '前往設定' : 'Settings',
                  textColor: const Color(0xFFF5B73B),
                  onPressed: () {
                    NativeHardwareBridge.openAppSettings(
                      isTestMode: !widget.enableLiveClock,
                    );
                  },
                )
              : null,
        ),
      );
    }
  }

  void _openSettingsSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final double bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            final double maxH = MediaQuery.of(ctx).size.height * 0.85;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF161618),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
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
                        const SizedBox(height: 16),
                        Text(
                          widget.isZh ? '拍攝與浮水印設定' : 'Camera & Watermark',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.isZh ? '使用場景' : 'Mode',
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: UserPersonaMode.values
                              .map((UserPersonaMode mode) {
                            final bool selected = widget.activePersona == mode;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: GestureDetector(
                                  key: Key('persona_chip_${mode.name}'),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    widget.onPersonaChanged?.call(mode);
                                    setSheetState(() {});
                                  },
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(0xFFF5B73B)
                                          : const Color(0xFF232326),
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(10),
                                      ),
                                    ),
                                    child: Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _shortPersonaLabel(mode),
                                          style: TextStyle(
                                            color: selected
                                                ? const Color(0xFF09090B)
                                                : const Color(0xFFE4E4E7),
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                widget.isZh
                                    ? '公司抬頭 / 案場名稱'
                                    : 'Company / Project Header',
                                style: const TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!widget.isProUnlocked)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5B73B)
                                      .withValues(alpha: 0.18),
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(5),
                                  ),
                                ),
                                child: const Text(
                                  'Pro',
                                  style: TextStyle(
                                    color: Color(0xFFF5B73B),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (widget.isProUnlocked)
                          Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFF232326),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(11)),
                            ),
                            child: TextField(
                              key: const Key('company_header_input'),
                              controller: _companyController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 11),
                                hintText: widget.isZh
                                    ? '例：宏泰機電工程股份有限公司'
                                    : 'e.g. Apex Solar Engineering Co.',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF636366),
                                  fontSize: 13,
                                ),
                              ),
                              onChanged: (String val) {
                                widget.onCompanyHeaderChanged?.call(val);
                                setSheetState(() {});
                              },
                            ),
                          )
                        else
                          GestureDetector(
                            key: const Key('company_header_locked_btn'),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              widget.onRequestPaywall(
                                widget.isZh
                                    ? '升級 Pro 即可自訂專屬公司名稱抬頭與隱藏預設品牌標章'
                                    : 'Upgrade to Pro for custom company header watermarks',
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              height: 44,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: const BoxDecoration(
                                color: Color(0xFF232326),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(11)),
                              ),
                              child: Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 16,
                                    color: Color(0xFFF5B73B),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.isZh
                                          ? '升級 Pro 解鎖自訂公司抬頭'
                                          : 'Unlock custom company header with Pro',
                                      style: const TextStyle(
                                        color: Color(0xFFA1A1AA),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF636366),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          widget.isZh ? '實機衛星定位狀態' : 'GPS Status',
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFF232326),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                _useLiveDeviceGps && _liveLat != null
                                    ? Icons.gps_fixed_rounded
                                    : Icons.gps_not_fixed_rounded,
                                size: 18,
                                color: _useLiveDeviceGps && _liveLat != null
                                    ? const Color(0xFF34C759)
                                    : const Color(0xFFF5B73B),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _useLiveDeviceGps && _liveLat != null
                                      ? '${_liveCity ?? ''}${_liveStreet ?? ''}'
                                      : (widget.isZh
                                          ? '僅使用真實裝置 GPS（不以假座標代替）'
                                          : 'Real GPS only (no simulated location)'),
                                  style: const TextStyle(
                                    color: Color(0xFFE4E4E7),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                key: const Key('settings_resync_gps_btn'),
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  _syncRealDeviceGps(silent: false);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF5B73B),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(8)),
                                  ),
                                  child: Text(
                                    widget.isZh ? '立即定位' : 'Sync',
                                    style: const TextStyle(
                                      color: Color(0xFF09090B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: <Widget>[
                            Text(
                              widget.isZh ? '浮水印濃度' : 'Watermark Contrast',
                              style: const TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                key: const Key('camera_watermark_opacity_slider'),
                                value: _watermarkOpacity,
                                min: 0.35,
                                max: 0.95,
                                onChanged: (double val) {
                                  setState(() => _watermarkOpacity = val);
                                  setSheetState(() {});
                                },
                                onChangeEnd: (_) => _syncCameraPrefs(),
                              ),
                            ),
                            Text(
                              '${(_watermarkOpacity * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              widget.isZh ? '九宮格輔助線' : 'Composition Grid',
                              style: const TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Switch.adaptive(
                              key: const Key('camera_settings_grid_switch'),
                              activeTrackColor: const Color(0xFFF5B73B),
                              value: _showGridLines,
                              onChanged: (bool val) {
                                setState(() => _showGridLines = val);
                                setSheetState(() {});
                                _syncCameraPrefs();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _setZoom(double factor, {bool persist = true}) async {
    final double next = factor.isFinite ? factor.clamp(1.0, 6.0) : 1.0;
    if ((next - _zoomFactor).abs() < 0.01 && !persist) return;
    setState(() => _zoomFactor = next);
    if (persist) {
      HapticFeedback.selectionClick();
      _syncCameraPrefs();
    }
    if (NativeHardwareBridge.isLiveIosRuntime && widget.enableLiveClock) {
      await NativeHardwareBridge.setCameraZoom(
        next,
        isTestMode: !widget.enableLiveClock,
      );
    }
  }

  Future<void> _toggleTorch() async {
    HapticFeedback.selectionClick();
    final bool target = !_torchEnabled;
    final bool applied = await NativeHardwareBridge.setCameraTorch(
      target,
      isTestMode: !widget.enableLiveClock,
    );
    if (!mounted) return;
    setState(() => _torchEnabled = applied);
  }

  void _handleTapFocus(TapUpDetails details, double boxWidth, double boxHeight) {
    if (boxWidth <= 1 || boxHeight <= 1) return;
    final double clampedX = details.localPosition.dx.clamp(28.0, boxWidth - 28.0);
    final double clampedY = details.localPosition.dy.clamp(28.0, boxHeight - 28.0);
    setState(() {
      _focusTapLocalOffset = Offset(clampedX, clampedY);
    });
    _focusHideTimer?.cancel();
    _focusHideTimer = Timer(const Duration(milliseconds: 850), () {
      if (mounted) {
        setState(() => _focusTapLocalOffset = null);
      }
    });
    if (NativeHardwareBridge.isLiveIosRuntime && widget.enableLiveClock) {
      unawaited(
        NativeHardwareBridge.focusCameraAt(
          normalizedX: details.localPosition.dx / boxWidth,
          normalizedY: details.localPosition.dy / boxHeight,
          isTestMode: !widget.enableLiveClock,
        ),
      );
    }
  }

  Future<void> _openRealCameraPicker() async {
    if (_isCapturing) return;
    HapticFeedback.mediumImpact();
    setState(() => _isCapturing = true);
    final Uint8List? bytes = await NativeHardwareBridge.captureRealCameraPhoto(
      preferLiveSession: false,
      isTestMode: !widget.enableLiveClock,
    );
    if (!mounted) return;
    setState(() {
      _isCapturing = false;
      if (bytes != null) {
        _cameraPhotoBytes = bytes;
      }
    });
  }

  Future<void> _openLastShotPreviewSheet() async {
    final Uint8List? png = _lastCapturedWatermarkPng;
    if (png == null) {
      await _openRealCameraPicker();
      return;
    }
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(99)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          widget.isZh ? '最新存證照片' : 'Latest Capture',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: Image.memory(png, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      key: const Key('camera_share_last_photo_btn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5B73B),
                        foregroundColor: const Color(0xFF09090B),
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        NativeHardwareBridge.shareImageBytes(
                          png,
                          text: _lastCapturedSummary ?? '',
                          isTestMode: !widget.enableLiveClock,
                        );
                      },
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: Text(
                        widget.isZh
                            ? '立即分享影像'
                            : 'Share / Send Photo',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _openRealCameraPicker();
                    },
                    child: Text(
                      widget.isZh ? '改用系統相機預覽' : 'Use System Camera',
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
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

  Future<void> _handleTriggerCapture() async {
    if (_isCapturing) return;
    HapticFeedback.heavyImpact();
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onDismissFirstTimeTip?.call();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final WatermarkSnapshot snap = _currentSnapshot();

    if (_isVideoMode) {
      if (NativeHardwareBridge.isLiveIosRuntime && widget.enableLiveClock) {
        setState(() => _isCapturing = true);
        final Map<String, dynamic>? recorded =
            await NativeHardwareBridge.recordRealCameraVideo(
          isTestMode: !widget.enableLiveClock,
        );
        if (!mounted) return;
        setState(() => _isCapturing = false);
        if (recorded == null) return;
        widget.onCaptureEvidence(snap);
        widget.onRecordedVideo?.call(recorded);
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1F1F23),
            content: Text(
              widget.isZh
                  ? '錄影完成，已載入 20MB 壓縮器'
                  : 'Recorded and loaded into 20MB Compressor',
              style: const TextStyle(
                color: Color(0xFF34C759),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
        return;
      }

      widget.onCaptureEvidence(snap);
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1F1F23),
          content: Text(
            widget.isZh ? '已儲存錄影紀錄' : 'Video record saved',
            style: const TextStyle(
              color: Color(0xFF34C759),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isCapturing = true;
      _shutterFlash = true;
    });
    _shutterFlashTimer?.cancel();
    _shutterFlashTimer = Timer(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => _shutterFlash = false);
    });

    bool savedToPhotos = false;
    String? errorCode;
    String? savedThumbPath;
    String? nativeSha256Hex;
    Uint8List? previewJpeg;
    String? captureSummary;
    WatermarkSnapshot finalSnap = snap;

    try {
      final int captureMs = _now.millisecondsSinceEpoch;
      final String tzLabel =
          WatermarkLocationEngine.formatLocalTimezoneLabel(_now);
      final String headerText = (widget.isProUnlocked &&
              widget.companyHeader.trim().isNotEmpty)
          ? widget.companyHeader.trim()
          : PersonaPositioningEngine.buildWatermarkHeader(
              widget.activePersona,
              isZh: widget.isZh,
              tzLabel: tzLabel,
            );

      if (NativeHardwareBridge.isLiveIosRuntime && widget.enableLiveClock) {
        final String caseId = 'CASE-$captureMs';
        final bool shouldAutoOcr =
            widget.activePersona == UserPersonaMode.trafficEvidence &&
                !_hasCustomNote;
        final String rawNoteForCapture =
            _hasCustomNote ? _noteController.text.trim() : '';

        final Map<String, dynamic>? nativeRes =
            await NativeHardwareBridge.captureAndRenderWatermarkPhoto(
          timestampText: snap.utcPlus8FormattedTime,
          headerText: headerText,
          addressText: snap.fullAddress,
          coordsText: snap.formattedCoordinates(isZh: widget.isZh),
          noteText: shouldAutoOcr
              ? ''
              : (rawNoteForCapture.isNotEmpty
                  ? rawNoteForCapture
                  : _noteController.text.trim()),
          showBrandBadge: !widget.isProUnlocked,
          watermarkOpacity: _watermarkOpacity,
          latitude: snap.hasValidGps ? snap.latitude : null,
          longitude: snap.hasValidGps ? snap.longitude : null,
          altitude: snap.hasValidGps ? snap.altitudeMeters : null,
          timestampMs: captureMs,
          caseId: caseId,
          autoDetectPlate: shouldAutoOcr,
          isZh: widget.isZh,
        );
        if (!mounted) return;

        if (nativeRes == null || nativeRes['ok'] != true) {
          errorCode = nativeRes?['errorCode']?.toString() ?? 'CAPTURE_FAILED';
          setState(() => _isCapturing = false);
          final bool isCamDenied = errorCode == 'CAMERA_PERMISSION_DENIED';
          messenger.showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1F1F23),
              content: Text(
                isCamDenied
                    ? (widget.isZh
                        ? '尚未授權相機權限，無法拍攝'
                        : 'Camera permission denied')
                    : (widget.isZh
                        ? '相機擷取失敗，請重試'
                        : 'Capture failed. Please retry.'),
                style: const TextStyle(
                  color: Color(0xFFFF453A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              action: isCamDenied
                  ? SnackBarAction(
                      label: widget.isZh ? '前往設定' : 'Settings',
                      textColor: const Color(0xFFF5B73B),
                      onPressed: () {
                        NativeHardwareBridge.openAppSettings(isTestMode: false);
                      },
                    )
                  : null,
            ),
          );
          return;
        }

        savedToPhotos = nativeRes['savedToPhotos'] == true;
        errorCode = nativeRes['errorCode']?.toString();
        savedThumbPath = nativeRes['thumbnailPath']?.toString();
        nativeSha256Hex = nativeRes['sha256Hex']?.toString();
        final Object? rawPreview = nativeRes['previewJpeg'];
        if (rawPreview is Uint8List) {
          previewJpeg = rawPreview;
        }
        final String? detectedPlate =
            nativeRes['recognizedPlate']?.toString();
        if (detectedPlate != null && detectedPlate.isNotEmpty) {
          _applyRecognizedPlate(detectedPlate, lockAsCustomNote: false);
          finalSnap = _currentSnapshot();
        }
      } else {
        final EvidenceIntegrityCertificate localCert =
            EvidenceIntegrityEngine.generateCertificate(
          snapshot: snap,
          isProUnlocked: widget.isProUnlocked,
        );
        nativeSha256Hex = localCert.sha256Hex;
      }

      captureSummary =
          '${finalSnap.utcPlus8FormattedTime} | ${finalSnap.fullAddress} | ${finalSnap.plateOrProjectNote}';

      widget.onCaptureEvidence(
        finalSnap,
        thumbnailPath: savedThumbPath,
        evidenceHash: nativeSha256Hex,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _cameraPhotoBytes = null;
          if (previewJpeg != null) {
            _lastCapturedWatermarkPng = previewJpeg;
            _lastCapturedSummary = captureSummary;
          }
        });
      }
    }

    if (!mounted) return;
    final bool photoPermDenied = errorCode == 'PHOTO_PERMISSION_DENIED';
    final bool photoSaveFailed =
        !savedToPhotos && errorCode == 'PHOTO_SAVE_FAILED';
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1F1F23),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        content: Text(
          savedToPhotos
              ? (widget.isZh ? '已全解析度存至相簿，可繼續連拍' : 'Saved to Photos! Ready.')
              : (photoPermDenied
                  ? (widget.isZh
                      ? '已寫入案件夾，但無相簿權限無法存入系統照片'
                      : 'Logged locally, but Photos permission denied.')
                  : (photoSaveFailed
                      ? (widget.isZh
                          ? '已寫入案件夾，但相簿儲存失敗，請確認儲存空間'
                          : 'Logged locally, but saving to Photos failed.')
                      : (widget.isZh ? '已寫入案件夾' : 'Logged to Cases'))),
          style: TextStyle(
            color: (photoPermDenied || photoSaveFailed)
                ? const Color(0xFFF5B73B)
                : const Color(0xFF34C759),
            fontWeight: FontWeight.w600,
          ),
        ),
        action: (savedToPhotos && previewJpeg != null)
            ? SnackBarAction(
                label: widget.isZh ? '分享' : 'Share',
                textColor: const Color(0xFFF5B73B),
                onPressed: () {
                  NativeHardwareBridge.shareImageBytes(
                    previewJpeg!,
                    text: captureSummary ?? '',
                    isTestMode: !widget.enableLiveClock,
                  );
                },
              )
            : ((photoPermDenied && NativeHardwareBridge.isLiveIosRuntime)
                ? SnackBarAction(
                    label: widget.isZh ? '前往設定' : 'Settings',
                    textColor: const Color(0xFFF5B73B),
                    onPressed: () {
                      NativeHardwareBridge.openAppSettings(
                        isTestMode: !widget.enableLiveClock,
                      );
                    },
                  )
                : null),
      ),
    );
  }

  void _applyRecognizedPlate(String plate, {bool lockAsCustomNote = true}) {
    final String cleanPlate = TaiwanPlateQuickPad.sanitizeTaiwanPlate(plate);
    if (lockAsCustomNote) {
      _hasCustomNote = true;
    }
    _noteController.text = cleanPlate;
  }

  Future<String?> _scanPlateWithVision() async {
    if (_isScanningPlate) return null;
    HapticFeedback.mediumImpact();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _isScanningPlate = true);
    final String? recognized = _cameraPhotoBytes != null
        ? await NativeHardwareBridge.recognizeLicensePlateFromBytes(
            _cameraPhotoBytes!,
            isTestMode: !widget.enableLiveClock,
          )
        : await NativeHardwareBridge.scanLiveLicensePlate(
            isTestMode: !widget.enableLiveClock,
          );
    if (!mounted) return null;
    setState(() {
      _isScanningPlate = false;
      if (recognized != null && recognized.isNotEmpty) {
        _applyRecognizedPlate(recognized, lockAsCustomNote: false);
      }
    });
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1F1F23),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        content: Text(
          recognized != null && recognized.isNotEmpty
              ? (widget.isZh
                  ? '已辨識車牌：$recognized'
                  : 'Plate recognized: $recognized')
              : (widget.isZh
                  ? '未偵測到清晰車牌，請拉近對準後再試'
                  : 'No clear plate detected. Move closer.'),
          style: TextStyle(
            color: (recognized != null && recognized.isNotEmpty)
                ? const Color(0xFF34C759)
                : const Color(0xFFE4E4E7),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    return recognized;
  }

  void _openPlateQuickPad() {
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return TaiwanPlateQuickPad(
          isZh: widget.isZh,
          initialValue: _noteController.text,
          onScanPlateOcr: _scanPlateWithVision,
          onApplyNote: (String newNote) {
            setState(() {
              _hasCustomNote = newNote.trim().isNotEmpty;
              _noteController.text = newNote;
            });
          },
        );
      },
    );
  }

  /// 位置摘要與官方通報指引（已移除硬編碼錯誤 110 簡訊專線，無 GPS 時禁止使用）
  void _showLocationSummarySheet() {
    HapticFeedback.mediumImpact();
    FocusManager.instance.primaryFocus?.unfocus();
    final WatermarkSnapshot snap = _currentSnapshot();
    EmergencyIncidentType selectedType = _emergencyIncidentType;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheetState) {
            final bool hasRealLocation = snap.hasValidGps;
            final String summaryBody =
                WatermarkLocationEngine.buildLocationSummaryForShare(
              snapshot: snap,
              incidentType: selectedType,
              isZh: widget.isZh,
            );

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF161618),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF5B73B),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(6)),
                            ),
                            child: const Text(
                              'GPS',
                              style: TextStyle(
                                color: Color(0xFF09090B),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.isZh ? '現場位置摘要與通報指引' : 'Location Summary',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                      if (!hasRealLocation) ...<Widget>[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF453A).withValues(alpha: 0.14),
                            borderRadius:
                                const BorderRadius.all(Radius.circular(12)),
                            border: Border.all(
                              color: const Color(0xFFFF453A).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            widget.isZh
                                ? '尚未取得真實 GPS 定位，請先點擊「同步定位」成功後再複製摘要，避免位置資訊錯誤。'
                                : 'Valid GPS fix required before sharing location summary.',
                            style: const TextStyle(
                              color: Color(0xFFFF8A80),
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: EmergencyIncidentType.values
                            .map((EmergencyIncidentType type) {
                          final bool isSelected = selectedType == type;
                          return GestureDetector(
                            key: Key('sms_incident_chip_${type.name}'),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _emergencyIncidentType = type);
                              setSheetState(() => selectedType = type);
                              _syncCameraPrefs();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFF5B73B)
                                    : const Color(0xFF232326),
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(999),
                                ),
                              ),
                              child: Text(
                                type.localizedTitle(isZh: widget.isZh),
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF09090B)
                                      : const Color(0xFFE4E4E7),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0B0B0D),
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                        child: Text(
                          summaryBody,
                          style: const TextStyle(
                            color: Color(0xFFE4E4E7),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          key: const Key('copy_110_sms_btn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasRealLocation
                                ? const Color(0xFFF5B73B)
                                : const Color(0xFF2C2C2E),
                            foregroundColor: hasRealLocation
                                ? const Color(0xFF09090B)
                                : const Color(0xFF8E8E93),
                            elevation: 0,
                            shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(14)),
                            ),
                          ),
                          onPressed: !hasRealLocation
                              ? null
                              : () async {
                                  final NavigatorState sheetNav =
                                      Navigator.of(sheetContext);
                                  final ScaffoldMessengerState messenger =
                                      ScaffoldMessenger.of(context);
                                  await Clipboard.setData(
                                    ClipboardData(text: summaryBody),
                                  );
                                  if (!mounted) return;
                                  sheetNav.pop();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: const Color(0xFF1F1F23),
                                      content: Text(
                                        widget.isZh
                                            ? '已複製真實 GPS 現場摘要'
                                            : 'Copied verified GPS summary',
                                        style: const TextStyle(
                                          color: Color(0xFF34C759),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                          child: Text(
                            widget.isZh
                                ? '複製真實 GPS 現場摘要'
                                : 'Copy Verified Location Summary',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (widget.isZh) ...<Widget>[
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              NativeHardwareBridge.openOfficialPortalSafari(
                                'https://www.npa.gov.tw/',
                              );
                            },
                            child: const Text(
                              '查看內政部警政署 110 官方資訊網 (npa.gov.tw)',
                              style: TextStyle(
                                color: Color(0xFFA1A1AA),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 無邊界精密儀器浮水印 HUD
  Widget _buildWatermarkHud(WatermarkSnapshot snap) {
    final EvidenceIntegrityCertificate cert =
        EvidenceIntegrityEngine.generateCertificate(
      snapshot: snap,
      isProUnlocked: widget.isProUnlocked,
    );
    final String tzLabel =
        WatermarkLocationEngine.formatLocalTimezoneLabel(_now);
    final String headerBadge = PersonaPositioningEngine.buildWatermarkHeader(
      widget.activePersona,
      isZh: widget.isZh,
      tzLabel: tzLabel,
    );

    final String customHeader =
        widget.isProUnlocked ? widget.companyHeader.trim() : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.transparent,
            Colors.black.withValues(
              alpha: (_watermarkOpacity * 0.72).clamp(0.25, 0.85),
            ),
            Colors.black.withValues(
              alpha: _watermarkOpacity.clamp(0.35, 0.95),
            ),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Container(
            width: 2.5,
            height: (snap.plateOrProjectNote.isNotEmpty ||
                    customHeader.isNotEmpty)
                ? 76
                : 48,
            decoration: const BoxDecoration(
              color: Color(0xFFF5B73B),
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (customHeader.isNotEmpty) ...<Widget>[
                  Text(
                    customHeader,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF5B73B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          snap.utcPlus8FormattedTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            shadows: <Shadow>[
                              Shadow(blurRadius: 6, color: Colors.black54),
                            ],
                            fontFeatures: <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      headerBadge,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  snap.fullAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: snap.hasValidGps
                        ? const Color(0xFFF5F5F7)
                        : const Color(0xFFFDE68A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    shadows: const <Shadow>[
                      Shadow(blurRadius: 4, color: Colors.black54),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${snap.formattedCoordinates(isZh: widget.isZh)}  ·  ${cert.displayBadge(isZh: widget.isZh)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                if (snap.plateOrProjectNote.isNotEmpty ||
                    snap.showBrandBadge) ...<Widget>[
                  const SizedBox(height: 5),
                  Row(
                    children: <Widget>[
                      if (snap.plateOrProjectNote.isNotEmpty)
                        Expanded(
                          child: Text(
                            snap.plateOrProjectNote,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (snap.showBrandBadge)
                        Flexible(
                          child: GestureDetector(
                          key: const Key('watermark_remove_badge_btn'),
                          onTap: () => widget.onRequestPaywall(
                            widget.isZh
                                ? '升級 Pro 可隱藏預設品牌浮水印，並自訂專屬公司名稱抬頭'
                                : 'Upgrade to Pro to hide brand watermark & set custom company header',
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(6),
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                              'TimeCam Pro',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFE4E4E7),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingPill({
    Key? key,
    Widget? leading,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.52),
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading,
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomControlBar() {
    const List<int> zoomLevels = <int>[1, 2, 3];
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.48),
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: zoomLevels.map((int level) {
            final bool selected = (level == 1 && _zoomFactor < 1.6) ||
                (level == 2 && _zoomFactor >= 1.6 && _zoomFactor < 2.6) ||
                (level == 3 && _zoomFactor >= 2.6);
            final bool isIntermediate =
                selected && (_zoomFactor - level).abs() >= 0.15;
            final String text = isIntermediate
                ? '${_zoomFactor.toStringAsFixed(1)}x'
                : '${level}x';
            return GestureDetector(
              key: Key('camera_zoom_${level}x'),
              onTap: () => _setZoom(level.toDouble()),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 34,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFFF5B73B)
                        : const Color(0xFFD4D4D8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildViewfinder(WatermarkSnapshot snap) {
    final bool showNativeLivePreview =
        NativeHardwareBridge.isLiveIosRuntime &&
            widget.enableLiveClock &&
            _cameraPhotoBytes == null;

    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints box) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (TapUpDetails d) =>
                  _handleTapFocus(d, box.maxWidth, box.maxHeight),
              onScaleStart: (_) => _pinchBaseZoom = _zoomFactor,
              onScaleUpdate: (ScaleUpdateDetails d) {
                if ((d.scale - 1.0).abs() > 0.03) {
                  _setZoom(_pinchBaseZoom * d.scale, persist: false);
                }
              },
              onScaleEnd: (_) => _syncCameraPrefs(),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(24)),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (_cameraPhotoBytes != null)
                      Image.memory(
                        _cameraPhotoBytes!,
                        fit: BoxFit.cover,
                      )
                    else if (showNativeLivePreview)
                      const UiKitView(
                        viewType:
                            NativeHardwareBridge.liveCameraPreviewViewType,
                      )
                    else
                      Container(
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(0, -0.15),
                            radius: 1.0,
                            colors: <Color>[
                              Color(0xFF141822),
                              Color(0xFF090C12),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.camera_outlined,
                            size: 42,
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                      ),
                    if (_showGridLines)
                      const IgnorePointer(
                        child: CustomPaint(painter: _RuleOfThirdsPainter()),
                      ),
                    // Dynamic flow stack: Zoom control sits cleanly ABOVE HUD even at 2.0x text scale
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _buildZoomControlBar(),
                          const SizedBox(height: 6),
                          _buildWatermarkHud(snap),
                        ],
                      ),
                    ),
                    IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _shutterFlash ? 0.85 : 0.0,
                        duration: const Duration(milliseconds: 120),
                        child: Container(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_focusTapLocalOffset != null)
              Positioned(
                left: _focusTapLocalOffset!.dx - 28,
                top: _focusTapLocalOffset!.dy - 28,
                child: IgnorePointer(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFF5B73B),
                        width: 1.6,
                      ),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: <Widget>[
                  _buildFloatingPill(
                    key: const Key('live_gps_sync_btn'),
                    leading: Container(
                      width: 6.5,
                      height: 6.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _useLiveDeviceGps && _liveLat != null
                            ? const Color(0xFF34C759)
                            : (_isSyncingGps
                                ? const Color(0xFFF5B73B)
                                : const Color(0xFF8E8E93)),
                      ),
                    ),
                    label: _isSyncingGps
                        ? (widget.isZh ? '定位中…' : 'GPS…')
                        : (_useLiveDeviceGps && _liveLat != null
                            ? (widget.isZh ? 'GPS 已鎖定' : 'GPS Fixed')
                            : (widget.isZh ? '同步定位' : 'Sync GPS')),
                    onTap: () => _syncRealDeviceGps(silent: false),
                  ),
                  const Spacer(),
                  Flexible(
                    child: _buildFloatingPill(
                      key: const Key('camera_persona_cycle_btn'),
                      label: _shortPersonaLabel(widget.activePersona),
                      onTap: _cyclePersona,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    key: const Key('camera_torch_btn'),
                    onTap: _toggleTorch,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _torchEnabled
                            ? const Color(0xFFF5B73B).withValues(alpha: 0.28)
                            : Colors.black.withValues(alpha: 0.52),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _torchEnabled
                              ? const Color(0xFFF5B73B)
                              : Colors.white.withValues(alpha: 0.12),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        _torchEnabled
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        size: 15,
                        color: _torchEnabled
                            ? const Color(0xFFF5B73B)
                            : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    key: const Key('camera_settings_btn'),
                    onTap: _openSettingsSheet,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.52),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 0.6,
                        ),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCameraDock() {
    final String hint = PersonaPositioningEngine.buildInputHint(
      widget.activePersona,
      isZh: widget.isZh,
    );
    final bool isTrafficMode =
        widget.activePersona == UserPersonaMode.trafficEvidence;
    final bool isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final bool showLocationSummaryBtn =
        widget.isZh && isTrafficMode && !isTablet;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFF161618),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Row(
            children: <Widget>[
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('camera_plate_note_input'),
                  controller: _noteController,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                    color: Color(0xFFF5F5F7),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: const TextStyle(
                      color: Color(0xFF636366),
                      fontSize: 13,
                    ),
                  ),
                  onChanged: (String val) {
                    _hasCustomNote = val.trim().isNotEmpty;
                    setState(() {});
                  },
                ),
              ),
              if (_noteController.text.isNotEmpty)
                GestureDetector(
                  key: const Key('camera_note_clear_btn'),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _hasCustomNote = false;
                      _noteController.clear();
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ),
              if (isTrafficMode) ...<Widget>[
                GestureDetector(
                  key: const Key('camera_ocr_plate_btn'),
                  onTap: _isScanningPlate ? null : _scanPlateWithVision,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    child: _isScanningPlate
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFF5B73B),
                            ),
                          )
                        : const Icon(
                            Icons.document_scanner_rounded,
                            size: 17,
                            color: Color(0xFFF5B73B),
                          ),
                  ),
                ),
                GestureDetector(
                  key: const Key('open_plate_quick_pad_btn'),
                  onTap: _openPlateQuickPad,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.only(left: 4, right: 12),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.dialpad_rounded,
                      size: 17,
                      color: Color(0xFFF5B73B),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          key: const Key('toggle_camera_mode_btn'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            GestureDetector(
              key: const Key('camera_mode_photo_btn'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_isVideoMode) {
                  HapticFeedback.selectionClick();
                  setState(() => _isVideoMode = false);
                  _syncCameraPrefs();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Text(
                  widget.isZh ? '拍照' : 'PHOTO',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: !_isVideoMode
                        ? const Color(0xFFF5B73B)
                        : const Color(0xFF636366),
                  ),
                ),
              ),
            ),
            GestureDetector(
              key: const Key('camera_mode_video_btn'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!_isVideoMode) {
                  HapticFeedback.selectionClick();
                  setState(() => _isVideoMode = true);
                  _syncCameraPrefs();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Text(
                  widget.isZh ? '錄影' : 'VIDEO',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: _isVideoMode
                        ? const Color(0xFFFF453A)
                        : const Color(0xFF636366),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            if (showLocationSummaryBtn)
              GestureDetector(
                key: const Key('open_110_sms_sheet_btn'),
                onTap: _showLocationSummarySheet,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5B73B).withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.share_location_rounded,
                        color: Color(0xFFF5B73B),
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '位置摘要',
                      style: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              GestureDetector(
                key: const Key('camera_grid_toggle_btn'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showGridLines = !_showGridLines);
                  _syncCameraPrefs();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _showGridLines
                            ? const Color(0xFFF5B73B).withValues(alpha: 0.18)
                            : const Color(0xFF1C1C1E),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.grid_on_rounded,
                        color: _showGridLines
                            ? const Color(0xFFF5B73B)
                            : const Color(0xFFF5F5F7),
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isZh ? '九宮格' : 'Grid',
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            GestureDetector(
              key: const Key('camera_main_shutter_btn'),
              onTapDown: (_) => setState(() => _shutterPressed = true),
              onTapCancel: () => setState(() => _shutterPressed = false),
              onTapUp: (_) => setState(() => _shutterPressed = false),
              onTap: _isCapturing ? null : _handleTriggerCapture,
              child: AnimatedScale(
                scale: _shutterPressed ? 0.92 : 1.0,
                duration: const Duration(milliseconds: 90),
                child: Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isVideoMode
                          ? const Color(0xFFFF453A)
                          : Colors.white,
                      width: 3,
                    ),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isCapturing
                          ? const Color(0xFF636366)
                          : (_isVideoMode
                              ? const Color(0xFFFF453A)
                              : Colors.white),
                    ),
                    child: _isCapturing
                        ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            GestureDetector(
              key: const Key('real_camera_btn'),
              onTap: _cameraPhotoBytes != null
                  ? () {
                      HapticFeedback.selectionClick();
                      setState(() => _cameraPhotoBytes = null);
                    }
                  : (_lastCapturedWatermarkPng != null
                      ? _openLastShotPreviewSheet
                      : _openRealCameraPicker),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      shape: BoxShape.circle,
                      border: _lastCapturedWatermarkPng != null &&
                              _cameraPhotoBytes == null
                          ? Border.all(
                              color: const Color(0xFFF5B73B),
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: (_cameraPhotoBytes == null &&
                            _lastCapturedWatermarkPng != null)
                        ? ClipOval(
                            child: Image.memory(
                              _lastCapturedWatermarkPng!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            _cameraPhotoBytes != null
                                ? Icons.refresh_rounded
                                : Icons.photo_camera_outlined,
                            color: const Color(0xFFF5F5F7),
                            size: 20,
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _cameraPhotoBytes != null
                        ? (widget.isZh ? '返回即時' : 'Live')
                        : (_lastCapturedWatermarkPng != null
                            ? (widget.isZh ? '分享' : 'Share')
                            : (widget.isZh ? '系統相機' : 'Camera')),
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final WatermarkSnapshot snap = _currentSnapshot();
    final String tipText = widget.activePersona == UserPersonaMode.trafficEvidence
        ? (widget.isZh
            ? '右側調諧鈕可切換場景模式・行車模式支援 AI 辨識車牌'
            : 'Tap top-right tune icon to switch modes • OCR active')
        : (widget.isZh
            ? '點快門直接將完整浮水印存相簿・調諧鈕可設定公司抬頭'
            : 'Tap shutter for full-res watermark photo & SHA-256 log');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        children: <Widget>[
          Expanded(
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.15,
              child: _buildViewfinder(snap),
            ),
          ),
          if (widget.showFirstTimeTip) ...<Widget>[
            const SizedBox(height: 8),
            FirstTimeTipBar(
              key: const Key('camera_first_tip_bar'),
              closeKey: const Key('camera_first_tip_close'),
              text: tipText,
              onDismiss: widget.onDismissFirstTimeTip,
            ),
            const SizedBox(height: 8),
          ] else
            const SizedBox(height: 12),
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: _buildCameraDock(),
          ),
        ],
      ),
    );
  }
}

class _RuleOfThirdsPainter extends CustomPainter {
  const _RuleOfThirdsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 0.6;
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
