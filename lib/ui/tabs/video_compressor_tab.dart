import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/activation_quota_engine.dart';
import '../../core/native_hardware_bridge.dart';
import '../../core/user_preferences_state.dart';
import '../../core/video_compression_engine.dart';
import '../../core/watermark_location_engine.dart';
import '../widgets/quick_start_guide_sheet.dart';

/// 內建高畫質影片試算樣本模型
@immutable
class SampleSourceVideo {
  const SampleSourceVideo({
    required this.id,
    required this.titleZh,
    required this.titleEn,
    required this.plateNumber,
    required this.locationZh,
    required this.locationEn,
    required this.sourceSizeMB,
    required this.totalSeconds,
    required this.originalSpec,
    this.isRealDeviceVideo = false,
  });

  final String id;
  final String titleZh;
  final String titleEn;
  final String plateNumber;
  final String locationZh;
  final String locationEn;
  final double sourceSizeMB;
  final double totalSeconds;
  final String originalSpec;
  final bool isRealDeviceVideo;

  String localizedTitle({required bool isZh}) => isZh ? titleZh : titleEn;
  String localizedLocation({required bool isZh}) =>
      isZh ? locationZh : locationEn;
}

/// Tab 2：零偽報真實進度 20MB / 10MB 影片壓縮器（範例試算不扣體驗額度）
class VideoCompressorTab extends StatefulWidget {
  const VideoCompressorTab({
    super.key,
    required this.isZh,
    required this.isProUnlocked,
    required this.onRequestPaywall,
    required this.onExportCompleted,
    this.externalRealVideo,
    this.usedFreeExports = 0,
    this.totalSavedMB = 0.0,
    this.onQuotaUpdated,
    this.isTestMode = false,
    this.showFirstTimeTip = false,
    this.onDismissFirstTimeTip,
    this.preferences = const UserPreferencesState(),
    this.onPreferencesChanged,
  });

  final bool isZh;
  final bool isProUnlocked;
  final ValueChanged<String> onRequestPaywall;
  final void Function({
    required CompressionPlan plan,
    required String plateNumber,
    required String address,
    required double actualOutputMB,
    required String clipboardSummary,
  }) onExportCompleted;
  final Map<String, dynamic>? externalRealVideo;
  final int usedFreeExports;
  final double totalSavedMB;
  final void Function(int usedFreeExports, double totalSavedMB)? onQuotaUpdated;
  final bool isTestMode;
  final bool showFirstTimeTip;
  final VoidCallback? onDismissFirstTimeTip;
  final UserPreferencesState preferences;
  final ValueChanged<UserPreferencesState>? onPreferencesChanged;

  static const List<SampleSourceVideo> sampleVideos = <SampleSourceVideo>[
    SampleSourceVideo(
      id: 'VID_4K_FIELD',
      titleZh: '4K 案場巡檢範例',
      titleEn: '4K Site Audit Demo',
      plateNumber: 'SITE-A08 巡檢紀錄',
      locationZh: '範例案場（試算用）',
      locationEn: 'Sample Site (Preview)',
      sourceSizeMB: 142.8,
      totalSeconds: 45.0,
      originalSpec: '4K 60fps HEVC',
    ),
    SampleSourceVideo(
      id: 'VID_4K_DELIVERY',
      titleZh: '4K 貨物點交範例',
      titleEn: '4K Delivery Demo',
      plateNumber: 'TW-99281 簽收影像',
      locationZh: '範例物流節點（試算用）',
      locationEn: 'Sample Logistics Hub',
      sourceSizeMB: 168.4,
      totalSeconds: 50.0,
      originalSpec: '4K 60fps HDR',
    ),
    SampleSourceVideo(
      id: 'VID_1080P_DASHCAM',
      titleZh: '1080p 行車影像範例',
      titleEn: '1080p Dashcam Demo',
      plateNumber: 'DEMO-CLIP 影像壓縮',
      locationZh: '範例路段（試算用）',
      locationEn: 'Sample Road Clip',
      sourceSizeMB: 78.5,
      totalSeconds: 30.0,
      originalSpec: '1080p 60fps MOV',
    ),
  ];

  @override
  State<VideoCompressorTab> createState() => _VideoCompressorTabState();
}

class _VideoCompressorTabState extends State<VideoCompressorTab> {
  int _selectedVideoIndex = 0;
  SampleSourceVideo? _realPickedVideo;
  bool _useRealPickedVideo = false;
  ReportTargetPreset _selectedPreset = ReportTargetPreset.trafficPolice20MB;
  double _trimStartSeconds = 0.0;
  double _trimDurationSeconds = 15.0;
  bool _autoCopySummary = true;
  late int _usedFreeExports;
  late double _totalSavedMB;
  bool _isCompressing = false;
  double _compressionProgress = 0.0;
  StreamSubscription<double>? _demoProgressSub;

  String _formatMmSs(double totalSeconds) {
    final int safe = totalSeconds.isFinite ? totalSeconds.round().clamp(0, 3599) : 0;
    final int min = safe ~/ 60;
    final int sec = safe % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  void _syncCompressorPrefs() {
    widget.onPreferencesChanged?.call(
      widget.preferences.copyWith(
        compressorPreset: _selectedPreset,
        compressorTrimSeconds: _trimDurationSeconds,
        autoCopySummary: _autoCopySummary,
        sampleVideoIndex: _selectedVideoIndex,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedVideoIndex = widget.preferences.sampleVideoIndex
        .clamp(0, VideoCompressorTab.sampleVideos.length - 1);
    _selectedPreset = widget.preferences.compressorPreset;
    _autoCopySummary = widget.preferences.autoCopySummary;
    _trimDurationSeconds = widget.preferences.compressorTrimSeconds.clamp(
      5.0,
      VideoCompressorTab.sampleVideos[_selectedVideoIndex].totalSeconds,
    );
    _usedFreeExports = widget.usedFreeExports;
    _totalSavedMB = widget.totalSavedMB;
    if (widget.externalRealVideo != null) {
      _applyRealVideoMap(widget.externalRealVideo!);
    }
    NativeHardwareBridge.setNativeEventHandlers(
      onVideoCompressionProgress: (double progress) {
        if (!mounted || !_isCompressing) return;
        setState(() {
          _compressionProgress = progress.clamp(0.0, 1.0);
        });
      },
    );
  }

  @override
  void didUpdateWidget(covariant VideoCompressorTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.preferences != oldWidget.preferences) {
      _selectedVideoIndex = widget.preferences.sampleVideoIndex
          .clamp(0, VideoCompressorTab.sampleVideos.length - 1);
      _selectedPreset = widget.preferences.compressorPreset;
      _autoCopySummary = widget.preferences.autoCopySummary;
      final double maxSec = _activeVideo.totalSeconds.clamp(1.0, 600.0);
      final double minDur = maxSec < 5.0 ? maxSec : 5.0;
      _trimDurationSeconds = widget.preferences.compressorTrimSeconds
          .clamp(minDur, maxSec);
    }
    if (widget.usedFreeExports != oldWidget.usedFreeExports) {
      _usedFreeExports = widget.usedFreeExports;
    }
    if (widget.totalSavedMB != oldWidget.totalSavedMB) {
      _totalSavedMB = widget.totalSavedMB;
    }
    if (widget.externalRealVideo != null &&
        widget.externalRealVideo != oldWidget.externalRealVideo) {
      _applyRealVideoMap(widget.externalRealVideo!);
    }
  }

  @override
  void dispose() {
    _demoProgressSub?.cancel();
    super.dispose();
  }

  void _applyRealVideoMap(Map<String, dynamic> meta) {
    final double sizeMB =
        ((meta['sizeMB'] as num?)?.toDouble() ?? 25.0).clamp(0.2, 4096.0);
    final double durationSec =
        ((meta['durationSeconds'] as num?)?.toDouble() ?? 15.0)
            .clamp(1.0, 600.0);
    final String fileName = (meta['fileName']?.toString() ?? 'iPhone_Clip.mov');
    final SampleSourceVideo real = SampleSourceVideo(
      id: 'REAL_DEVICE_VIDEO',
      titleZh: fileName,
      titleEn: fileName,
      plateNumber: fileName.length > 20 ? fileName.substring(0, 20) : fileName,
      locationZh: 'iPhone 相簿匯入',
      locationEn: 'iPhone Photos',
      sourceSizeMB: sizeMB,
      totalSeconds: durationSec,
      originalSpec:
          '${durationSec.toStringAsFixed(0)}s · ${sizeMB.toStringAsFixed(1)} MB',
      isRealDeviceVideo: true,
    );
    _realPickedVideo = real;
    _useRealPickedVideo = true;
    _trimStartSeconds = 0.0;
    final double minDur = durationSec < 5.0 ? durationSec : 5.0;
    _trimDurationSeconds = _trimDurationSeconds.clamp(minDur, durationSec);
  }

  SampleSourceVideo get _activeVideo {
    if (_useRealPickedVideo && _realPickedVideo != null) {
      return _realPickedVideo!;
    }
    return VideoCompressorTab.sampleVideos[_selectedVideoIndex];
  }

  CompressionPlan _currentPlan() {
    final SampleSourceVideo video = _activeVideo;
    final double minDur = video.totalSeconds < 5.0 ? video.totalSeconds : 5.0;
    final double safeTrim =
        _trimDurationSeconds.clamp(minDur, video.totalSeconds);
    return VideoCompressionEngine.createPlan(
      sourceSizeMB: video.sourceSizeMB,
      clipDurationSeconds: safeTrim,
      preset: _selectedPreset,
      burnInWatermark: _autoCopySummary,
    );
  }

  String _shortPresetLabel(ReportTargetPreset preset) {
    switch (preset) {
      case ReportTargetPreset.trafficPolice20MB:
        return widget.isZh ? '20MB 標準' : '20MB';
      case ReportTargetPreset.epa10MB:
        return widget.isZh ? '10MB 精簡' : '10MB';
      case ReportTargetPreset.archive50MB:
        return widget.isZh ? '50MB 高畫質' : '50MB';
    }
  }

  Color _clarityColor(PlateClarityGrade grade) {
    switch (grade) {
      case PlateClarityGrade.ultraSharp:
        return const Color(0xFF34C759);
      case PlateClarityGrade.clearStandard:
        return const Color(0xFF64D2FF);
      case PlateClarityGrade.lowBitrateWarning:
        return const Color(0xFFF5B73B);
    }
  }

  String _clarityLabel(PlateClarityGrade grade) {
    switch (grade) {
      case PlateClarityGrade.ultraSharp:
        return widget.isZh ? '高清晰度' : 'Ultra Sharp';
      case PlateClarityGrade.clearStandard:
        return widget.isZh ? '標準清晰' : 'Clear';
      case PlateClarityGrade.lowBitrateWarning:
        return widget.isZh ? '建議縮短秒數' : 'Trim Advised';
    }
  }

  Future<void> _pickRealVideo() async {
    HapticFeedback.selectionClick();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Map<String, dynamic>? picked =
        await NativeHardwareBridge.pickVideoFromPhotos(
      isTestMode: widget.isTestMode,
    );
    if (!mounted) return;
    if (picked != null) {
      widget.onDismissFirstTimeTip?.call();
      setState(() {
        _applyRealVideoMap(picked);
      });
      final SampleSourceVideo v = _activeVideo;
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          persist: false,
          backgroundColor: const Color(0xFF1F1F23),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          content: Text(
            widget.isZh
                ? '已載入真實影片（${v.sourceSizeMB.toStringAsFixed(1)} MB）'
                : 'Loaded real video (${v.sourceSizeMB.toStringAsFixed(1)} MB)',
            style: const TextStyle(
              color: Color(0xFF34C759),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
  }

  QuotaStatusSnapshot _currentQuota() {
    return ActivationQuotaEngine.evaluateGate(
      isProUnlocked: widget.isProUnlocked,
      usedFreeExports: _usedFreeExports,
      totalSavedMB: _totalSavedMB,
    );
  }

  Future<void> _handleStartExport(CompressionPlan plan) async {
    if (_isCompressing) return;
    widget.onDismissFirstTimeTip?.call();
    final SampleSourceVideo video = _activeVideo;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    // 內建範例影片僅作試算示範，絕對不扣免費體驗額度！
    if (!video.isRealDeviceVideo) {
      HapticFeedback.mediumImpact();
      setState(() {
        _isCompressing = true;
        _compressionProgress = 0.0;
      });
      _demoProgressSub?.cancel();
      _demoProgressSub = VideoCompressionEngine.executeCompressionStream(
        plan: plan,
        isTestMode: widget.isTestMode,
      ).listen(
        (double progress) {
          if (!mounted) return;
          setState(() => _compressionProgress = progress);
        },
        onDone: () async {
          if (!mounted) return;
          final String nowTs =
              WatermarkLocationEngine.formatLocalTimestamp(DateTime.now());
          final String summary = VideoCompressionEngine.buildClipboardSummary(
            plan: plan,
            timestampText: nowTs,
            addressText: video.localizedLocation(isZh: widget.isZh),
            plateOrNote: video.plateNumber,
            isZh: widget.isZh,
          );
          if (_autoCopySummary) {
            await Clipboard.setData(ClipboardData(text: summary));
          }
          if (!mounted) return;
          setState(() {
            _isCompressing = false;
            _compressionProgress = 1.0;
          });
          messenger.clearSnackBars();
          messenger.showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              persist: false,
              backgroundColor: const Color(0xFF1F1F23),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              content: Text(
                widget.isZh
                    ? '範例預估計算完成（${plan.formattedEstimatedSize}・未扣真實額度，點右上方「選取影片」可轉碼真實影片）'
                    : 'Demo preview done (${plan.formattedEstimatedSize} • Quota untouched). Tap Pick Video for real clips.',
                style: const TextStyle(
                  color: Color(0xFFF5B73B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      );
      return;
    }

    // 以下為真實裝置影片轉碼流程：必須成功存回相簿才扣除額度，絕不偽造成功
    final QuotaStatusSnapshot quota = _currentQuota();
    if (quota.decision == ExportGateDecision.interceptWithPaywall) {
      HapticFeedback.mediumImpact();
      final String reason = ActivationQuotaEngine.buildPostAhaPaywallReason(
        quota: quota,
        formattedEstimatedSize: plan.formattedEstimatedSize,
        plateNumber: video.plateNumber,
        savedPercentage: plan.savedPercentage,
        isZh: widget.isZh,
      );
      widget.onRequestPaywall(reason);
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _isCompressing = true;
      _compressionProgress = 0.05;
    });

    final double maxStart = (video.totalSeconds - plan.clipDurationSeconds)
        .clamp(0.0, video.totalSeconds);
    final double safeStart = _trimStartSeconds.clamp(0.0, maxStart);

    final Map<String, dynamic>? nativeRes = widget.isTestMode
        ? <String, dynamic>{
            'ok': true,
            'savedToPhotos': true,
            'outputMB': plan.estimatedOutputMB,
          }
        : await NativeHardwareBridge.compressAndSaveRealVideo(
            startSeconds: safeStart,
            trimSeconds: plan.clipDurationSeconds,
            targetLimitMB: plan.targetLimitMB,
            isTestMode: widget.isTestMode,
          );

    if (!mounted) return;

    final bool ok = nativeRes != null &&
        nativeRes['ok'] == true &&
        nativeRes['savedToPhotos'] == true;
    if (!ok) {
      final String errCode =
          nativeRes?['errorCode']?.toString() ?? 'TRANSCODE_FAILED';
      final String errDetail =
          nativeRes?['errorDetail']?.toString().trim() ?? '';
      final bool isPhotoDenied = errCode == 'PHOTO_PERMISSION_DENIED';
      setState(() {
        _isCompressing = false;
        _compressionProgress = 0.0;
      });
      final String detailSuffix =
          errDetail.isNotEmpty ? ' ($errDetail)' : '';
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: isPhotoDenied ? 4 : 3),
          persist: false,
          backgroundColor: const Color(0xFF1F1F23),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          content: Text(
            isPhotoDenied
                ? (widget.isZh
                    ? '未獲相簿寫入權限，影片未儲存且未扣除體驗額度'
                    : 'Photos permission denied. File not saved; quota untouched.')
                : (widget.isZh
                    ? '硬體轉碼或存檔失敗$detailSuffix，未扣除您的體驗額度'
                    : 'Compression or save failed$detailSuffix; quota untouched.'),
            style: const TextStyle(
              color: Color(0xFFFF453A),
              fontWeight: FontWeight.w600,
            ),
          ),
          action: isPhotoDenied
              ? SnackBarAction(
                  label: widget.isZh ? '前往設定' : 'Settings',
                  textColor: const Color(0xFFF5B73B),
                  onPressed: () {
                    NativeHardwareBridge.openAppSettings(
                      isTestMode: widget.isTestMode,
                    );
                  },
                )
              : null,
        ),
      );
      return;
    }

    final double actualMB = (nativeRes['outputMB'] as num?)?.toDouble() ??
        plan.estimatedOutputMB;

    final QuotaStatusSnapshot updatedQuota =
        ActivationQuotaEngine.recordSuccessfulExport(
      current: quota,
      sourceSizeMB: plan.sourceSizeMB,
      estimatedOutputMB: actualMB,
    );

    setState(() {
      _isCompressing = false;
      _compressionProgress = 1.0;
      _usedFreeExports = updatedQuota.usedFreeExports;
      _totalSavedMB = updatedQuota.totalSavedMB;
    });
    widget.onQuotaUpdated?.call(_usedFreeExports, _totalSavedMB);

    final String nowTimestamp =
        WatermarkLocationEngine.formatLocalTimestamp(DateTime.now());
    final String summary = VideoCompressionEngine.buildClipboardSummary(
      plan: plan,
      timestampText: nowTimestamp,
      addressText: video.localizedLocation(isZh: widget.isZh),
      plateOrNote: video.plateNumber,
      isZh: widget.isZh,
    );
    if (_autoCopySummary) {
      await Clipboard.setData(ClipboardData(text: summary));
    }
    if (!mounted) return;

    widget.onExportCompleted(
      plan: plan,
      plateNumber: video.plateNumber,
      address: video.localizedLocation(isZh: widget.isZh),
      actualOutputMB: actualMB,
      clipboardSummary: summary,
    );

    final String sizeStr = '${actualMB.toStringAsFixed(1)} MB';
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        persist: false,
        backgroundColor: const Color(0xFF1F1F23),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        content: Text(
          widget.isZh
              ? '壓縮完成 ($sizeStr)，已存至系統相簿'
              : 'Saved to Photos ($sizeStr)',
          style: const TextStyle(
            color: Color(0xFF34C759),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoSourceCard(CompressionPlan plan) {
    final SampleSourceVideo video = _activeVideo;
    final Color clarityColor = _clarityColor(plan.clarityGrade);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      video.localizedTitle(isZh: widget.isZh),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: clarityColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${_clarityLabel(plan.clarityGrade)} · ${plan.formattedVideoMbps}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                key: const Key('pick_video_btn'),
                onTap: _isCompressing ? null : _pickRealVideo,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.photo_library_outlined,
                        size: 15,
                        color: Color(0xFF09090B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _useRealPickedVideo
                            ? (widget.isZh ? '更換影片' : 'Change')
                            : (widget.isZh ? '選取影片' : 'Pick Video'),
                        style: const TextStyle(
                          color: Color(0xFF09090B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.isZh ? '原始容量' : 'Original',
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${plan.sourceSizeMB.toStringAsFixed(1)} MB',
                        style: const TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          fontFeatures: <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF636366),
                  size: 18,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      widget.isZh ? '目標輸出' : 'Target',
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        plan.formattedEstimatedSize,
                        style: const TextStyle(
                          color: Color(0xFF34C759),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontFeatures: <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: const BoxDecoration(
                  color: Color(0xFF232326),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Text(
                  '-${plan.savedPercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFFF5F5F7),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard(CompressionPlan plan) {
    final SampleSourceVideo video = _activeVideo;
    final double maxSec = video.totalSeconds.clamp(1.0, 600.0);
    final double minTrim = maxSec < 5.0 ? maxSec : 5.0;
    final double safeTrim = _trimDurationSeconds.clamp(minTrim, maxSec);
    final double maxStart = (maxSec - safeTrim).clamp(0.0, maxSec);
    final double safeStart = _trimStartSeconds.clamp(0.0, maxStart);
    final double safeEnd = (safeStart + safeTrim).clamp(safeStart + minTrim, maxSec);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Color(0xFF0A0A0C),
              borderRadius: BorderRadius.all(Radius.circular(11)),
            ),
            child: Row(
              children: ReportTargetPreset.values.map((ReportTargetPreset p) {
                final bool selected = _selectedPreset == p;
                return Expanded(
                  child: GestureDetector(
                    key: Key('compressor_preset_${p.name}'),
                    onTap: _isCompressing
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedPreset = p);
                            _syncCompressorPrefs();
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF2C2C2E)
                            : Colors.transparent,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _shortPresetLabel(p),
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF8E8E93),
                              fontSize: 12.5,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 8,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.isZh
                        ? '裁切長度 · ${safeTrim.toStringAsFixed(0)} 秒'
                        : 'Trim · ${safeTrim.toStringAsFixed(0)}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatMmSs(safeStart)} – ${_formatMmSs(safeEnd)}',
                    style: const TextStyle(
                      color: Color(0xFFF5B73B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final int sec in VideoCompressionEngine.quickTrimPresets)
                    if (sec <= maxSec)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: GestureDetector(
                          key: Key('compressor_trim_chip_$sec'),
                          onTap: _isCompressing
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  final double nextDur =
                                      sec.toDouble().clamp(minTrim, maxSec);
                                  final double nextStart =
                                      (safeStart + nextDur <= maxSec)
                                          ? safeStart
                                          : (maxSec - nextDur).clamp(0.0, maxSec);
                                  setState(() {
                                    _trimStartSeconds = nextStart;
                                    _trimDurationSeconds = nextDur;
                                  });
                                  _syncCompressorPrefs();
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (safeTrim - sec).abs() < 0.5
                                  ? const Color(0xFFF5B73B)
                                  : const Color(0xFF232326),
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(7)),
                            ),
                            child: Text(
                              '${sec}s',
                              style: TextStyle(
                                color: (safeTrim - sec).abs() < 0.5
                                    ? const Color(0xFF09090B)
                                    : const Color(0xFF8E8E93),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ],
          ),
          RangeSlider(
            key: const Key('compressor_trim_range_slider'),
            values: RangeValues(safeStart, safeEnd),
            min: 0.0,
            max: maxSec,
            divisions: maxSec.round().clamp(1, 120),
            onChanged: (_isCompressing || maxSec <= minTrim)
                ? null
                : (RangeValues vals) {
                    double nextStart = vals.start;
                    double nextEnd = vals.end;
                    if (nextEnd - nextStart < minTrim) {
                      if ((nextStart - safeStart).abs() > 0.05) {
                        nextStart = (nextEnd - minTrim).clamp(0.0, maxSec);
                        nextEnd = (nextStart + minTrim).clamp(minTrim, maxSec);
                      } else {
                        nextEnd = (nextStart + minTrim).clamp(minTrim, maxSec);
                        nextStart = (nextEnd - minTrim).clamp(0.0, maxSec);
                      }
                    }
                    setState(() {
                      _trimStartSeconds = nextStart;
                      _trimDurationSeconds =
                          (nextEnd - nextStart).clamp(minTrim, maxSec);
                    });
                  },
            onChangeEnd: _isCompressing ? null : (_) => _syncCompressorPrefs(),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.isZh
                      ? '匯出後自動複製時間地點文字摘要'
                      : 'Auto-copy timestamp text summary',
                  style: const TextStyle(
                    color: Color(0xFFD4D4D8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch.adaptive(
                key: const Key('compressor_autocopy_switch'),
                activeTrackColor: const Color(0xFFF5B73B),
                value: _autoCopySummary,
                onChanged: _isCompressing
                    ? null
                    : (bool val) {
                        setState(() => _autoCopySummary = val);
                        _syncCompressorPrefs();
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubtleSamplesRow() {
    if (_useRealPickedVideo) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: _isCompressing
              ? null
              : () {
                  setState(() => _useRealPickedVideo = false);
                },
          child: Text(
            widget.isZh ? '切換回內建範例試算' : 'Switch back to Demo Clips',
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.isZh
              ? '內建範例試算（不消耗真實免費體驗次數）'
              : 'Demo Preview Clips (No Export Quota Used)',
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List<Widget>.generate(
              VideoCompressorTab.sampleVideos.length,
              (int idx) {
                final SampleSourceVideo item =
                    VideoCompressorTab.sampleVideos[idx];
                final bool selected =
                    !_useRealPickedVideo && _selectedVideoIndex == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    key: Key('sample_video_chip_$idx'),
                    onTap: _isCompressing
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _useRealPickedVideo = false;
                              _selectedVideoIndex = idx;
                              _trimStartSeconds = 0.0;
                              _trimDurationSeconds = _trimDurationSeconds.clamp(
                                5.0,
                                item.totalSeconds,
                              );
                            });
                            _syncCompressorPrefs();
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF2C2C2E)
                            : const Color(0xFF161618),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(999)),
                      ),
                      child: Text(
                        item.localizedTitle(isZh: widget.isZh),
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF8E8E93),
                          fontSize: 11.5,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExportFooter(CompressionPlan plan) {
    final QuotaStatusSnapshot quota = _currentQuota();
    final SampleSourceVideo video = _activeVideo;
    final String buttonText = !video.isRealDeviceVideo
        ? (widget.isZh
            ? '試算範例壓縮效果 (${plan.formattedEstimatedSize}・不扣額度)'
            : 'Demo Estimate (${plan.formattedEstimatedSize} • Free)')
        : ActivationQuotaEngine.buildCtaButtonLabel(
            quota: quota,
            formattedEstimatedSize: plan.formattedEstimatedSize,
            isZh: widget.isZh,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_isCompressing) ...<Widget>[
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            child: LinearProgressIndicator(
              value: _compressionProgress,
              backgroundColor: const Color(0xFF232326),
              color: const Color(0xFFF5B73B),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isZh
                ? '硬體真實轉碼中 · ${(_compressionProgress * 100).round()}%'
                : 'Hardware Encoding · ${(_compressionProgress * 100).round()}%',
            style: const TextStyle(
              color: Color(0xFFF5B73B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            key: const Key('compressor_export_cta_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5B73B),
              foregroundColor: const Color(0xFF09090B),
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
            onPressed: _isCompressing ? null : () => _handleStartExport(plan),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            ActivationQuotaEngine.buildBannerLabel(quota, isZh: widget.isZh),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final CompressionPlan plan = _currentPlan();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (widget.showFirstTimeTip) ...<Widget>[
            FirstTimeTipBar(
              key: const Key('compress_first_tip_bar'),
              closeKey: const Key('compress_first_tip_close'),
              text: widget.isZh
                  ? '點選相簿影片 → 拖曳起訖秒數 → 依目標容量真位元率轉碼'
                  : 'Pick real video → trim range → hardware bitrate export',
              onDismiss: widget.onDismissFirstTimeTip,
            ),
            const SizedBox(height: 10),
          ],
          _buildVideoSourceCard(plan),
          const SizedBox(height: 12),
          _buildControlsCard(plan),
          const SizedBox(height: 16),
          _buildExportFooter(plan),
          const SizedBox(height: 18),
          _buildSubtleSamplesRow(),
        ],
      ),
    );
  }
}
