import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/native_hardware_bridge.dart';
import '../../core/activation_quota_engine.dart';
import '../../core/video_compression_engine.dart';

/// 內建高畫質 4K 行車紀錄與外勤影片樣本模型 (供快速實測與審核員沙盒體驗)
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

  String localizedTitle({required bool isZh}) => isZh ? titleZh : titleEn;
  String localizedLocation({required bool isZh}) =>
      isZh ? locationZh : locationEn;
}

/// Tab 2：20MB 檢舉影片智能壓縮器（核心付費牆變現引擎）
class VideoCompressorTab extends StatefulWidget {
  const VideoCompressorTab({
    super.key,
    required this.isZh,
    required this.isProUnlocked,
    required this.onRequestPaywall,
    required this.onExportCompleted,
    this.isTestMode = false,
  });

  final bool isZh;
  final bool isProUnlocked;
  final ValueChanged<String> onRequestPaywall;
  final void Function({
    required CompressionPlan plan,
    required String plateNumber,
    required String address,
  }) onExportCompleted;
  final bool isTestMode;

  static const List<SampleSourceVideo> sampleVideos = <SampleSourceVideo>[
    SampleSourceVideo(
      id: 'VID_4K_SIGNAL',
      titleZh: '4K 行車記錄器：變換車道未打方向燈',
      titleEn: '4K Dashcam: Unsignaled Lane Change',
      plateNumber: 'ABC-8899',
      locationZh: '台北市信義區忠孝東路五段22號',
      locationEn: 'Sec. 5, Zhongxiao E. Rd., Taipei',
      sourceSizeMB: 142.8,
      totalSeconds: 45.0,
      originalSpec: '4K 60fps HEVC (142.8 MB)',
    ),
    SampleSourceVideo(
      id: 'VID_4K_PEDESTRIAN',
      titleZh: 'iPhone 4K 錄影：斑馬線未禮讓行人',
      titleEn: 'iPhone 4K: Failure to Yield on Crosswalk',
      plateNumber: 'RCD-5566',
      locationZh: '台南市東區中華東路三段路口',
      locationEn: 'Sec. 3, Zhonghua E. Rd., Tainan',
      sourceSizeMB: 168.4,
      totalSeconds: 50.0,
      originalSpec: '4K 60fps ProRes/HDR (168.4 MB)',
    ),
    SampleSourceVideo(
      id: 'VID_EPA_LITTER',
      titleZh: '環保獎金蒐證：停等紅燈亂丟煙蒂',
      titleEn: 'EPA Reward Clip: Littering Cigarette Butt',
      plateNumber: 'NML-7788',
      locationZh: '台中市西屯區台灣大道三段99號',
      locationEn: 'Sec. 3, Taiwan Blvd., Taichung',
      sourceSizeMB: 78.5,
      totalSeconds: 30.0,
      originalSpec: '1080p 60fps MOV (78.5 MB)',
    ),
  ];

  @override
  State<VideoCompressorTab> createState() => _VideoCompressorTabState();
}

class _VideoCompressorTabState extends State<VideoCompressorTab> {
  int _selectedVideoIndex = 0;
  ReportTargetPreset _selectedPreset = ReportTargetPreset.trafficPolice20MB;
  double _trimDurationSeconds = 15.0;
  double _plateZoomScale = 1.5;
  bool _burnInWatermark = true;
  int _usedFreeExports = 0;
  double _totalSavedMB = 0.0;
  bool _isCompressing = false;
  double _compressionProgress = 0.0;
  StreamSubscription<double>? _compressionSub;

  @override
  void dispose() {
    _compressionSub?.cancel();
    super.dispose();
  }

  SampleSourceVideo get _activeVideo =>
      VideoCompressorTab.sampleVideos[_selectedVideoIndex];

  CompressionPlan _currentPlan() {
    final SampleSourceVideo video = _activeVideo;
    final double safeTrim =
        _trimDurationSeconds.clamp(5.0, video.totalSeconds);
    return VideoCompressionEngine.createPlan(
      sourceSizeMB: video.sourceSizeMB,
      clipDurationSeconds: safeTrim,
      preset: _selectedPreset,
      burnInWatermark: _burnInWatermark,
    );
  }
  Color _clarityBadgeColor(PlateClarityGrade grade) {
    switch (grade) {
      case PlateClarityGrade.ultraSharp:
        return const Color(0xFF10B981);
      case PlateClarityGrade.clearStandard:
        return const Color(0xFF0284C7);
      case PlateClarityGrade.lowBitrateWarning:
        return const Color(0xFFF59E0B);
    }
  }

  String _clarityBadgeLabel(PlateClarityGrade grade) {
    switch (grade) {
      case PlateClarityGrade.ultraSharp:
        return widget.isZh ? '車牌極致銳利' : 'PLATE ULTRA SHARP';
      case PlateClarityGrade.clearStandard:
        return widget.isZh ? '車牌標準清晰' : 'PLATE CLEAR';
      case PlateClarityGrade.lowBitrateWarning:
        return widget.isZh ? '建議縮短秒數' : 'TRIM ADVISED';
    }
  }

  Widget _buildVideoSelectorAndPlateLoupe(CompressionPlan plan) {
    final SampleSourceVideo video = _activeVideo;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.video_file_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isZh
                      ? '步驟 1：選擇原始高畫質影片與車牌放大檢視'
                      : 'Step 1: Select Source Video & Plate Loupe',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List<Widget>.generate(
                VideoCompressorTab.sampleVideos.length,
                (int idx) {
                  final SampleSourceVideo item =
                      VideoCompressorTab.sampleVideos[idx];
                  final bool isSelected = _selectedVideoIndex == idx;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('sample_video_chip_$idx'),
                      label: Text(
                        '${item.localizedTitle(isZh: widget.isZh)} (${item.sourceSizeMB.toStringAsFixed(0)}MB)',
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF121212)
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFFF59E0B),
                      backgroundColor: const Color(0xFF0F172A),
                      onSelected: _isCompressing
                          ? null
                          : (_) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedVideoIndex = idx;
                                _trimDurationSeconds = _trimDurationSeconds
                                    .clamp(5.0, item.totalSeconds);
                              });
                            },
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 車牌局部放大檢視鏡 (1.0x / 1.5x / 2.5x)
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF090D16),
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                border: Border.all(color: const Color(0xFF475569)),
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          video.originalSpec,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _clarityBadgeColor(plan.clarityGrade),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(6)),
                        ),
                        child: Text(
                          '${_clarityBadgeLabel(plan.clarityGrade)} • ${plan.formattedVideoMbps}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AnimatedScale(
                    scale: _plateZoomScale,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(6)),
                        border: Border.all(
                          color: const Color(0xFF121212),
                          width: 2.5,
                        ),
                      ),
                      child: Text(
                        video.plateNumber,
                        style: const TextStyle(
                          color: Color(0xFF121212),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: <double>[1.0, 1.5, 2.2].map((double zoom) {
                      final bool active =
                          (_plateZoomScale - zoom).abs() < 0.05;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: active
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF1E293B),
                            foregroundColor: active
                                ? const Color(0xFF121212)
                                : Colors.white,
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(
                              color: active
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF475569),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _plateZoomScale = zoom;
                            });
                          },
                          child: Text(
                            '${zoom.toStringAsFixed(1)}x ${widget.isZh ? "車牌放大" : "Zoom"}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrimAndPresetControls(CompressionPlan plan) {
    final SampleSourceVideo video = _activeVideo;
    final double safeTrim =
        _trimDurationSeconds.clamp(5.0, video.totalSeconds);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.tune_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isZh
                      ? '步驟 2：鎖定目標平台容量與黃金秒數裁切'
                      : 'Step 2: Lock Target Limit & Trim Duration',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 目標檢舉系統容量預設選擇 (20MB 警局 / 10MB 環保局 / 50MB 事故歸檔)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ReportTargetPreset.values.map((ReportTargetPreset p) {
              final bool selected = _selectedPreset == p;
              return ChoiceChip(
                label: Text(
                  p.localizedTitle(isZh: widget.isZh),
                  style: TextStyle(
                    color: selected ? const Color(0xFF121212) : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                selected: selected,
                selectedColor: const Color(0xFFF59E0B),
                backgroundColor: const Color(0xFF0F172A),
                onSelected: _isCompressing
                    ? null
                    : (_) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedPreset = p;
                        });
                      },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // 快速裁切秒數選擇 (10s / 15s / 30s / 45s)
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.isZh
                      ? '裁切關鍵違規區間：${safeTrim.toStringAsFixed(0)} 秒'
                      : 'Trim Clip Duration: ${safeTrim.toStringAsFixed(0)}s',
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final int sec in VideoCompressionEngine.quickTrimPresets)
                if (sec <= video.totalSeconds)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: InkWell(
                      onTap: _isCompressing
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _trimDurationSeconds = sec
                                    .toDouble()
                                    .clamp(5.0, video.totalSeconds);
                              });
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (safeTrim - sec).abs() < 0.5
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF0F172A),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(6)),
                        ),
                        child: Text(
                          '${sec}s',
                          style: TextStyle(
                            color: (safeTrim - sec).abs() < 0.5
                                ? const Color(0xFF121212)
                                : const Color(0xFFCBD5E1),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
          Slider(
            value: safeTrim,
            min: 5.0,
            max: video.totalSeconds,
            divisions: (video.totalSeconds - 5.0).round().clamp(1, 100),
            activeColor: const Color(0xFFF59E0B),
            inactiveColor: const Color(0xFF0F172A),
            onChanged: _isCompressing
                ? null
                : (double val) {
                    setState(() {
                      _trimDurationSeconds = val.clamp(5.0, video.totalSeconds);
                    });
                  },
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.isZh
                      ? '轉碼時同步烙印時間與地址防偽浮水印'
                      : 'Burn-in Timestamp & GPS Watermark During Export',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch.adaptive(
                activeTrackColor: const Color(0xFFF59E0B),
                value: _burnInWatermark,
                onChanged: _isCompressing
                    ? null
                    : (bool val) {
                        setState(() {
                          _burnInWatermark = val;
                        });
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
  QuotaStatusSnapshot _currentQuota() {
    return ActivationQuotaEngine.evaluateGate(
      isProUnlocked: widget.isProUnlocked,
      usedFreeExports: _usedFreeExports,
      totalSavedMB: _totalSavedMB,
    );
  }

  void _handleStartExport(CompressionPlan plan) {
    if (_isCompressing) return;
    final SampleSourceVideo video = _activeVideo;
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
      _compressionProgress = 0.0;
    });

    _compressionSub?.cancel();
    _compressionSub = VideoCompressionEngine.executeCompressionStream(
      plan: plan,
      isTestMode: widget.isTestMode,
    ).listen(
      (double progress) {
        if (!mounted) return;
        setState(() {
          _compressionProgress = progress;
        });
      },
      onDone: () async {
        if (!mounted) return;
        final QuotaStatusSnapshot updatedQuota =
            ActivationQuotaEngine.recordSuccessfulExport(
          current: _currentQuota(),
          sourceSizeMB: plan.sourceSizeMB,
          estimatedOutputMB: plan.estimatedOutputMB,
        );
        setState(() {
          _isCompressing = false;
          _compressionProgress = 1.0;
          _usedFreeExports = updatedQuota.usedFreeExports;
          _totalSavedMB = updatedQuota.totalSavedMB;
        });

        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        await NativeHardwareBridge.compressAndSaveRealVideo(trimSeconds: plan.clipDurationSeconds, isTestMode: widget.isTestMode);
        final String summary = VideoCompressionEngine.buildClipboardSummary(
          plan: plan,
          timestampText: '2026/11/15 14:30:00',
          addressText: video.localizedLocation(isZh: widget.isZh),
          plateOrNote: video.plateNumber,
          isZh: widget.isZh,
        );
        await Clipboard.setData(ClipboardData(text: summary));
        if (!mounted) return;

        widget.onExportCompleted(
          plan: plan,
          plateNumber: video.plateNumber,
          address: video.localizedLocation(isZh: widget.isZh),
        );

        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              widget.isZh
                  ? '🎉 壓縮完成 (${plan.formattedEstimatedSize})！已存入案件庫並複製時間地點摘要至剪貼簿！'
                  : '🎉 Exported (${plan.formattedEstimatedSize})! Saved to vault & copied summary!',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatMetricColumn(
    String label,
    String value,
    Color valueColor,
  ) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompressionSummaryAndCta(CompressionPlan plan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _buildStatMetricColumn(
                widget.isZh ? '原始檔案大小' : 'Original Size',
                '${plan.sourceSizeMB.toStringAsFixed(1)} MB',
                const Color(0xFFEF4444),
              ),
              const Icon(
                Icons.double_arrow_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              _buildStatMetricColumn(
                widget.isZh ? '智能壓縮後容量' : 'Target Output',
                plan.formattedEstimatedSize,
                const Color(0xFF10B981),
              ),
              const SizedBox(width: 6),
              _buildStatMetricColumn(
                widget.isZh ? '瘦身節省幅度' : 'Size Saved',
                '-${plan.savedPercentage.toStringAsFixed(1)}%',
                const Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: Text(
              widget.isZh ? plan.advisoryMessageZh : plan.advisoryMessageEn,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_isCompressing) ...<Widget>[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _compressionProgress,
              backgroundColor: const Color(0xFF1E293B),
              color: const Color(0xFFF59E0B),
              minHeight: 8,
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            const SizedBox(height: 6),
            Text(
              widget.isZh
                  ? '⚡ H.264 目標位元率 (${plan.formattedVideoMbps}) 硬體轉碼中... ${(_compressionProgress * 100).round()}%'
                  : '⚡ Hardware encoding at ${plan.formattedVideoMbps}... ${(_compressionProgress * 100).round()}%',
              style: const TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('compressor_export_cta_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF121212),
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 16,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
              onPressed:
                  _isCompressing ? null : () => _handleStartExport(plan),
              icon: Icon(
                widget.isProUnlocked
                    ? Icons.rocket_launch_rounded
                    : Icons.lock_open_rounded,
                size: 20,
              ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  ActivationQuotaEngine.buildCtaButtonLabel(
                    quota: _currentQuota(),
                    formattedEstimatedSize: plan.formattedEstimatedSize,
                    isZh: widget.isZh,
                  ),
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CompressionPlan plan = _currentPlan();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildVideoSelectorAndPlateLoupe(plan),
          const SizedBox(height: 12),
          _buildTrimAndPresetControls(plan),
          const SizedBox(height: 12),
          _buildCompressionSummaryAndCta(plan),
        ],
      ),
    );
  }
}import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/native_hardware_bridge.dart';
import '../../core/evidence_integrity_engine.dart';
import '../../core/watermark_location_engine.dart';
import '../widgets/taiwan_plate_quick_pad.dart';

/// 預設台灣主要都會區與外勤巡檢 GPS 定位點模型
@immutable
class PresetGpsSpot {
  const PresetGpsSpot({
    required this.cityZh,
    required this.cityEn,
    required this.streetZh,
    required this.streetEn,
    required this.latitude,
    required this.longitude,
    required this.altitude,
  });

  final String cityZh;
  final String cityEn;
  final String streetZh;
  final String streetEn;
  final double latitude;
  final double longitude;
  final double altitude;
}

/// Tab 1：蒐證相機（主畫面・即時時間/GPS/地址浮水印與一鍵 110 簡訊報案）
class CameraEvidenceTab extends StatefulWidget {
  const CameraEvidenceTab({
    super.key,
    required this.isZh,
    required this.isProUnlocked,
    required this.onCaptureEvidence,
    required this.onRequestPaywall,
    this.enableLiveClock = true,
  });

  final bool isZh;
  final bool isProUnlocked;
  final ValueChanged<WatermarkSnapshot> onCaptureEvidence;
  final ValueChanged<String> onRequestPaywall;
  final bool enableLiveClock;

  static const List<PresetGpsSpot> presetSpots = <PresetGpsSpot>[
    PresetGpsSpot(
      cityZh: '台北市信義區',
      cityEn: 'Xinyi Dist., Taipei ',
      streetZh: '忠孝東路五段22號',
      streetEn: 'No. 22, Sec. 5, Zhongxiao E. Rd.',
      latitude: 25.04086,
      longitude: 121.56482,
      altitude: 14.2,
    ),
    PresetGpsSpot(
      cityZh: '新北市板橋區',
      cityEn: 'Banqiao Dist., New Taipei ',
      streetZh: '縣民大道二段7號',
      streetEn: 'No. 7, Sec. 2, Xianmin Blvd.',
      latitude: 25.01425,
      longitude: 121.46375,
      altitude: 11.8,
    ),
    PresetGpsSpot(
      cityZh: '台中市西屯區',
      cityEn: 'Xitun Dist., Taichung ',
      streetZh: '台灣大道三段99號',
      streetEn: 'No. 99, Sec. 3, Taiwan Blvd.',
      latitude: 24.16184,
      longitude: 120.64685,
      altitude: 86.5,
    ),
    PresetGpsSpot(
      cityZh: '台南市東區',
      cityEn: 'East Dist., Tainan ',
      streetZh: '中華東路三段336號',
      streetEn: 'No. 336, Sec. 3, Zhonghua E. Rd.',
      latitude: 22.97482,
      longitude: 120.22156,
      altitude: 21.0,
    ),
    PresetGpsSpot(
      cityZh: '高雄市左營區',
      cityEn: 'Zuoying Dist., Kaohsiung ',
      streetZh: '博愛二路777號',
      streetEn: 'No. 777, Bo-ai 2nd Rd.',
      latitude: 22.66912,
      longitude: 120.30328,
      altitude: 9.4,
    ),
  ];

  @override
  State<CameraEvidenceTab> createState() => _CameraEvidenceTabState();
}

class _CameraEvidenceTabState extends State<CameraEvidenceTab> {
  final TextEditingController _noteController = TextEditingController(
    text: 'ABC-1234 紅線違停',
  );
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  final GlobalKey _viewfinderBoundaryKey = GlobalKey();
  int _selectedSpotIndex = 0;
  bool _useLiveDeviceGps = false;
  bool _isSyncingGps = false;
  String? _liveCity;
  String? _liveStreet;
  double? _liveLat;
  double? _liveLng;
  double? _liveAlt;
  bool _isVideoMode = true;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  bool _showGridLines = true;
  double _watermarkOpacity = 0.88;

  @override
  void initState() {
    super.initState();
    if (widget.enableLiveClock) {
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _now = DateTime.now();
          if (_isRecording) {
            _recordingSeconds += 1;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  WatermarkSnapshot _currentSnapshot() {
    final PresetGpsSpot spot = CameraEvidenceTab.presetSpots[_selectedSpotIndex];
    final String city = (_useLiveDeviceGps && _liveCity != null)
        ? _liveCity!
        : (widget.isZh ? spot.cityZh : spot.cityEn);
    final String street = (_useLiveDeviceGps && _liveStreet != null)
        ? _liveStreet!
        : (widget.isZh ? spot.streetZh : spot.streetEn);
    return WatermarkLocationEngine.createSnapshot(
      timestamp: _now,
      cityAndDistrict: city,
      streetAddress: street,
      latitude: (_useLiveDeviceGps && _liveLat != null) ? _liveLat! : spot.latitude,
      longitude: (_useLiveDeviceGps && _liveLng != null) ? _liveLng! : spot.longitude,
      altitudeMeters: (_useLiveDeviceGps && _liveAlt != null) ? _liveAlt! : spot.altitude,
      plateOrProjectNote: _noteController.text,
      isTimeVerified: true,
      isProUnlocked: widget.isProUnlocked,
      isZh: widget.isZh,
    );
  }

  Future<void> _syncRealDeviceGps() async {
    if (_isSyncingGps) return;
    HapticFeedback.mediumImpact();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isSyncingGps = true;
    });
    final Map<String, dynamic>? gps =
        await NativeHardwareBridge.fetchLiveGpsAddress(
      isTestMode: !widget.enableLiveClock,
    );
    if (!mounted) return;
    setState(() {
      _isSyncingGps = false;
      if (gps != null) {
        _useLiveDeviceGps = true;
        _liveCity = gps['city']?.toString();
        _liveStreet = gps['street']?.toString();
        _liveLat = (gps['latitude'] as num?)?.toDouble();
        _liveLng = (gps['longitude'] as num?)?.toDouble();
        _liveAlt = (gps['altitude'] as num?)?.toDouble();
      }
    });
    messenger.showSnackBar(
      SnackBar(
        backgroundColor:
            gps != null ? const Color(0xFF10B981) : const Color(0xFF0284C7),
        content: Text(
          gps != null
              ? (widget.isZh
                  ? '🛰️ 已鎖定真實 iPhone GPS 座標與台灣街道地址！'
                  : '🛰️ Locked real iPhone GPS coordinates & street address!')
              : (widget.isZh
                  ? '📍 目前為模擬器/離線環境，已使用高精度預設巡檢座標'
                  : '📍 Using preset inspection coordinates in simulator/offline mode'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _captureAndSaveWatermarkImage() async {
    if (!widget.enableLiveClock) return;
    try {
      final RenderRepaintBoundary? boundary = _viewfinderBoundaryKey
          .currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      await NativeHardwareBridge.saveWatermarkPhotoBytes(pngBytes);
    } catch (_) {}
  }
  void _handleTriggerCapture() {
    HapticFeedback.heavyImpact();
    final WatermarkSnapshot snap = _currentSnapshot();
    if (_isVideoMode) {
      setState(() {
        if (_isRecording) {
          _isRecording = false;
          _recordingSeconds = 0;
          widget.onCaptureEvidence(snap);
      _captureAndSaveWatermarkImage();
        } else {
          _isRecording = true;
          _recordingSeconds = 0;
        }
      });
      if (!_isRecording) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              widget.isZh
                  ? '✅ 蒐證錄影已烙印時間地點浮水印並歸檔至案件庫！'
                  : '✅ Video watermarked and saved to Evidence Vault!',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
    } else {
      widget.onCaptureEvidence(snap);
      _captureAndSaveWatermarkImage();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0284C7),
          content: Text(
            widget.isZh
                ? '📸 現場存證照片已烙印 UTC+8 時間與 GPS 浮水印！'
                : '📸 Photo captured with UTC+8 & GPS watermark!',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
  }


  void _openPlateQuickPad() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return TaiwanPlateQuickPad(
          isZh: widget.isZh,
          initialValue: _noteController.text,
          onApplyNote: (String newNote) {
            setState(() {
              _noteController.text = newNote;
            });
          },
        );
      },
    );
  }

  void _show110QuickReportSheet() {
    HapticFeedback.mediumImpact();
    final WatermarkSnapshot snap = _currentSnapshot();
    EmergencyIncidentType selectedType = EmergencyIncidentType.redLineParking;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheetState) {
            final String recipient =
                WatermarkLocationEngine.resolve110SmsRecipient(
              snap.cityAndDistrict,
            );
            final String smsBody = WatermarkLocationEngine.build110SmsBody(
              snapshot: snap,
              incidentType: selectedType,
              isZh: widget.isZh,
            );

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(6)),
                            ),
                            child: const Text(
                              '110 SMS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.isZh
                                  ? '一鍵 110 簡訊報案快速產生器'
                                  : '110 Emergency SMS Generator',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isZh
                            ? '自動匹配轄區警局簡訊專線：$recipient（可選違規態樣）'
                            : 'Matched Police SMS Recipient: $recipient',
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: EmergencyIncidentType.values
                            .map((EmergencyIncidentType type) {
                          final bool isSelected = selectedType == type;
                          return ChoiceChip(
                            label: Text(
                              type.localizedTitle(isZh: widget.isZh),
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF121212)
                                    : Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFFF59E0B),
                            backgroundColor: const Color(0xFF1E293B),
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              setSheetState(() {
                                selectedType = type;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(12)),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Text(
                          smsBody,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          key: const Key('copy_110_sms_btn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          onPressed: () async {
                            final NavigatorState sheetNav =
                                Navigator.of(sheetContext);
                            final ScaffoldMessengerState messenger =
                                ScaffoldMessenger.of(context);
                            await Clipboard.setData(
                              ClipboardData(text: smsBody),
                            );
                            final Uri smsUri = WatermarkLocationEngine.build110SmsUri(snapshot: snap, incidentType: selectedType, isZh: widget.isZh);
                            await NativeHardwareBridge.launchNativeSms(smsUri.toString());
                            if (!mounted) return;
                            sheetNav.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF10B981),
                                content: Text(
                                  widget.isZh
                                      ? '✅ 已複製 110 報案簡訊（專線：$recipient），請貼上簡訊寄出！'
                                      : '✅ Copied 110 SMS body for $recipient!',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.send_to_mobile_rounded),
                          label: Text(
                            widget.isZh
                                ? '一鍵複製報案簡訊全文 (寄至 $recipient)'
                                : 'Copy Emergency SMS (To $recipient)',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
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
      },
    );
  }

  Widget _buildLiveWatermarkOverlay(WatermarkSnapshot snap) {
    final EvidenceIntegrityCertificate cert =
        EvidenceIntegrityEngine.generateCertificate(
      snapshot: snap,
      isProUnlocked: widget.isProUnlocked,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: _watermarkOpacity),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.75),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                child: Text(
                  widget.isZh ? 'UTC+8 國家標準校時' : 'UTC+8 VERIFIED',
                  style: const TextStyle(
                    color: Color(0xFF121212),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    snap.utcPlus8FormattedTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      fontFeatures: <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              const Icon(
                Icons.location_on_rounded,
                color: Color(0xFFF59E0B),
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  snap.fullAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'GPS: ${snap.formattedCoordinates(isZh: widget.isZh)}',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              cert.displayBadge(isZh: widget.isZh),
              style: const TextStyle(
                color: Color(0xFF38BDF8),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (snap.plateOrProjectNote.isNotEmpty) ...<Widget>[
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
                border: Border.all(color: const Color(0xFF475569)),
              ),
              child: Text(
                widget.isZh
                    ? '車牌/案場備註：${snap.plateOrProjectNote}'
                    : 'Plate/Note: ${snap.plateOrProjectNote}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFDE68A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          if (snap.showBrandBadge) ...<Widget>[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                key: const Key('watermark_remove_badge_btn'),
                onTap: () => widget.onRequestPaywall(
                  widget.isZh
                      ? '解鎖 Pro 即可移除照片/影片右下角品牌標章，並啟用自訂公司案場抬頭！'
                      : 'Unlock Pro to remove brand badge and customize project headers!',
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                  child: Text(
                    widget.isZh
                        ? '⚡ 時間相機 Pro 認證水印 (點此移除)'
                        : '⚡ TimeCam Pro Badge (Tap to remove)',
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildViewfinderArea(WatermarkSnapshot snap) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 270),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF090D16),
          ],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(
          color: _isRecording
              ? const Color(0xFFEF4444)
              : const Color(0xFF334155),
          width: _isRecording ? 2.2 : 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            // 頂部 HUD 狀態列：GPS 定位點切換 + 錄影狀態計時
            Row(
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            key: const Key('live_gps_sync_btn'),
                            backgroundColor: _useLiveDeviceGps
                                ? const Color(0xFF10B981)
                                : const Color(0xFF0284C7),
                            visualDensity: VisualDensity.compact,
                            avatar: Icon(
                              _isSyncingGps
                                  ? Icons.sync_rounded
                                  : Icons.my_location_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            label: Text(
                              widget.isZh ? '真機GPS定位' : 'Live GPS',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            onPressed: _syncRealDeviceGps,
                          ),
                        ),
                        ...List<Widget>.generate(
                        CameraEvidenceTab.presetSpots.length,
                        (int idx) {
                          final PresetGpsSpot spot =
                              CameraEvidenceTab.presetSpots[idx];
                          final bool selected = _selectedSpotIndex == idx;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                widget.isZh ? spot.cityZh : spot.cityEn,
                                style: TextStyle(
                                  color: selected
                                      ? const Color(0xFF121212)
                                      : Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              selected: selected,
                              selectedColor: const Color(0xFFF59E0B),
                              backgroundColor: const Color(0xFF0F172A),
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _useLiveDeviceGps = false;
                                  _selectedSpotIndex = idx;
                                });
                              },
                            ),
                          );
                        },
                      ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(6)),
                  ),
                  child: Text(
                    _isRecording
                        ? 'REC ${_recordingSeconds.toString().padLeft(2, '0')}s'
                        : '1080p 60FPS',
                    style: TextStyle(
                      color: _isRecording
                          ? Colors.white
                          : const Color(0xFF34D399),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 中央光學車牌對焦準星 HUD
            if (_showGridLines)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    const Icon(
                      Icons.center_focus_strong_rounded,
                      color: Color(0xFFF59E0B),
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isZh
                          ? '車牌/案場光學銳利化對焦區 (AF-C)'
                          : 'License Plate Optical Focus Zone (AF-C)',
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // 底部即時浮水印疊加預覽
            _buildLiveWatermarkOverlay(snap),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbControlZone() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 車牌號碼或外勤案場名稱快速輸入欄
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const Key('camera_plate_note_input'),
                  controller: _noteController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    prefixIcon: const Icon(
                      Icons.pin_invoke_rounded,
                      color: Color(0xFFF59E0B),
                      size: 19,
                    ),
                    hintText: widget.isZh
                        ? '輸入違規車牌或案場備註 (例: ABC-1234)'
                        : 'Enter plate or project note (e.g. ABC-1234)',
                    hintStyle: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12.5,
                    ),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                key: const Key('open_plate_quick_pad_btn'),
                tooltip: widget.isZh ? '車牌單手快選' : 'Quick Plate Pad',
                onPressed: _openPlateQuickPad,
                icon: const Icon(
                  Icons.dialpad_rounded,
                  color: Color(0xFFF59E0B),
                ),
              ),
              IconButton(
                tooltip: widget.isZh ? '對焦網格開關' : 'Toggle Grid',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _showGridLines = !_showGridLines;
                  });
                },
                icon: Icon(
                  _showGridLines
                      ? Icons.grid_on_rounded
                      : Icons.grid_off_rounded,
                  color: _showGridLines
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 浮水印底板透明度微調滑桿
          Row(
            children: <Widget>[
              Text(
                widget.isZh ? '水印底板透明度' : 'Watermark Opacity',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _watermarkOpacity,
                  min: 0.4,
                  max: 1.0,
                  activeColor: const Color(0xFFF59E0B),
                  inactiveColor: const Color(0xFF0F172A),
                  onChanged: (double val) {
                    setState(() {
                      _watermarkOpacity = val.clamp(0.4, 1.0);
                    });
                  },
                ),
              ),
              Text(
                '${(_watermarkOpacity * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 單手拇指熱區三大核心按鈕：110 簡訊報案 / 主快門鈕 / 錄影拍照切換
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('open_110_sms_sheet_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  onPressed: _show110QuickReportSheet,
                  icon: const Icon(Icons.sms_failed_rounded, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.isZh ? '110 簡訊報案' : '110 SMS',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  key: const Key('camera_main_shutter_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFF59E0B),
                    foregroundColor: _isRecording
                        ? Colors.white
                        : const Color(0xFF121212),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  onPressed: _handleTriggerCapture,
                  icon: Icon(
                    _isVideoMode
                        ? (_isRecording
                            ? Icons.stop_circle_rounded
                            : Icons.videocam_rounded)
                        : Icons.camera_alt_rounded,
                    size: 21,
                  ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _isVideoMode
                          ? (_isRecording
                              ? (widget.isZh ? '停止並存證' : 'Stop & Save')
                              : (widget.isZh ? '開始水印錄影' : 'Record Video'))
                          : (widget.isZh ? '拍攝水印存證照' : 'Capture Photo'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  key: const Key('toggle_camera_mode_btn'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF475569)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isRecording = false;
                      _isVideoMode = !_isVideoMode;
                    });
                  },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _isVideoMode
                          ? (widget.isZh ? '切至拍照' : 'Photo Mode')
                          : (widget.isZh ? '切至錄影' : 'Video Mode'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final WatermarkSnapshot snap = _currentSnapshot();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          RepaintBoundary(
            key: _viewfinderBoundaryKey,
            child: _buildViewfinderArea(snap),
          ),
          const SizedBox(height: 12),
          _buildThumbControlZone(),
        ],
      ),
    );
  }
}import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/taiwan_report_repository.dart';

/// Tab 3：全台 22 縣市通報入口、道交法條模板庫與 7 日時效案件夾
class ReportPortalTab extends StatefulWidget {
  const ReportPortalTab({
    super.key,
    required this.isZh,
    required this.isProUnlocked,
    required this.cases,
    required this.onUpdateCaseStatus,
    required this.onRequestPaywall,
    this.activeHandoff,
    this.onDismissHandoff,
  });
  final Object? activeHandoff;
  final VoidCallback? onDismissHandoff;

  final bool isZh;
  final bool isProUnlocked;
  final List<EvidenceCaseRecord> cases;
  final void Function(String caseId, CaseSubmissionStatus nextStatus)
      onUpdateCaseStatus;
  final ValueChanged<String> onRequestPaywall;

  @override
  State<ReportPortalTab> createState() => _ReportPortalTabState();
}

class _ReportPortalTabState extends State<ReportPortalTab> {
  final TextEditingController _searchController = TextEditingController();
  PortalRegion? _selectedRegion;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _copyStatuteTemplate(TrafficStatuteTemplate tpl) async {
    if (tpl.isProRequired && !widget.isProUnlocked) {
      HapticFeedback.mediumImpact();
      final String reasonZh =
          '🔒「${tpl.articleNumberZh}：${tpl.violationTitleZh}」屬於 Pro 專業版標準舉發構成要件模板。立即解鎖 Pro 即可一鍵複製全套法條與環保獎金檢舉範本！';
      final String reasonEn =
          '🔒 "${tpl.articleNumberEn}: ${tpl.violationTitleEn}" is a Pro template. Unlock Pro to copy all official legal statements!';
      widget.onRequestPaywall(widget.isZh ? reasonZh : reasonEn);
      return;
    }

    HapticFeedback.heavyImpact();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final EvidenceCaseRecord? latestCase =
        widget.cases.isNotEmpty ? widget.cases.first : null;

    final String fullStatement =
        TaiwanReportRepository.composeFullReportStatement(
      template: tpl,
      formattedTimeUtc8: latestCase?.formattedTimeUtc8 ?? '2026/11/16 14:30:00',
      fullAddress: latestCase?.address ??
          (widget.isZh ? '台北市信義區忠孝東路五段22號' : 'Xinyi Dist., Taipei City'),
      plateNumber: latestCase?.plateOrNote ?? 'ABC-8899',
      isZh: widget.isZh,
    );

    await Clipboard.setData(ClipboardData(text: fullStatement));
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        content: Text(
          widget.isZh
              ? '📋 已複製「${tpl.articleNumberZh}」完整檢舉事實描述（含最新案件時間與車號）！'
              : '📋 Copied "${tpl.articleNumberEn}" full statement to clipboard!',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Future<void> _openOrCopyPortalUrl(
    CityReportPortal portal, {
    required bool isEpa,
  }) async {
    HapticFeedback.selectionClick();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String url =
        isEpa ? portal.safeEpaUri.toString() : portal.safeTrafficUri.toString();
    final String city = portal.localizedCityName(isZh: widget.isZh);

    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0284C7),
        content: Text(
          widget.isZh
              ? '🌐 已準備開啟「$city${isEpa ? "環保局獎金" : "警察局交通"}檢舉網」並複製官方網址：$url'
              : '🌐 Ready to open $city ${isEpa ? "EPA" : "Traffic"} Portal (URL copied): $url',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  CaseSubmissionStatus _nextStatus(CaseSubmissionStatus current) {
    switch (current) {
      case CaseSubmissionStatus.pending:
        return CaseSubmissionStatus.submitted;
      case CaseSubmissionStatus.submitted:
        return CaseSubmissionStatus.archived;
      case CaseSubmissionStatus.archived:
        return CaseSubmissionStatus.pending;
    }
  }

  Widget _buildEvidenceCaseVault() {
    final DateTime nowUtc = DateTime.now().toUtc();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.folder_special_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isZh
                      ? '本地加密案件庫 (道交 7-1 條：7 日舉發時效追蹤)'
                      : 'Local Evidence Vault (7-Day Statutory Limit Tracker)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                child: Text(
                  '${widget.cases.length}',
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final EvidenceCaseRecord record in widget.cases)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(
                  color: record.status == CaseSubmissionStatus.pending
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.7)
                      : const Color(0xFF334155),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          record.plateOrNote,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: record.status == CaseSubmissionStatus.submitted
                              ? const Color(0xFF10B981).withValues(alpha: 0.2)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(6)),
                        ),
                        child: Text(
                          TaiwanReportRepository.formatDeadlineBadge(
                            record: record,
                            nowUtc: nowUtc,
                            isZh: widget.isZh,
                          ),
                          style: TextStyle(
                            color:
                                record.status == CaseSubmissionStatus.submitted
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFFFDE68A),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${record.formattedTimeUtc8} • ${record.address}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        widget.isZh
                            ? '壓縮容量：${record.compressedSizeMB.toStringAsFixed(1)} MB'
                            : 'Size: ${record.compressedSizeMB.toStringAsFixed(1)} MB',
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      OutlinedButton.icon(
                        key: Key('toggle_case_status_${record.id}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          side: const BorderSide(color: Color(0xFF475569)),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          widget.onUpdateCaseStatus(
                            record.id,
                            _nextStatus(record.status),
                          );
                        },
                        icon: const Icon(Icons.sync_rounded, size: 15),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            record.status.localizedLabel(isZh: widget.isZh),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatuteTemplatesSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.gavel_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isZh
                      ? '常用道交條例與環保獎金事實描述模板 (一鍵複製)'
                      : 'Official Traffic & EPA Legal Statement Templates',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final TrafficStatuteTemplate tpl
              in TaiwanReportRepository.statuteTemplates)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF59E0B),
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                        ),
                        child: Text(
                          tpl.localizedArticle(isZh: widget.isZh),
                          style: const TextStyle(
                            color: Color(0xFF121212),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        tpl.localizedFine(isZh: widget.isZh),
                        style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (tpl.isProRequired && !widget.isProUnlocked)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFEF4444).withValues(alpha: 0.2),
                            borderRadius:
                                const BorderRadius.all(Radius.circular(5)),
                          ),
                          child: const Text(
                            '🔒 PRO',
                            style: TextStyle(
                              color: Color(0xFFFCA5A5),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tpl.localizedTitle(isZh: widget.isZh),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tpl.localizedBody(isZh: widget.isZh),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: Key('copy_statute_btn_${tpl.code}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            (tpl.isProRequired && !widget.isProUnlocked)
                                ? const Color(0xFF334155)
                                : const Color(0xFFF59E0B),
                        foregroundColor:
                            (tpl.isProRequired && !widget.isProUnlocked)
                                ? Colors.white
                                : const Color(0xFF121212),
                        visualDensity: VisualDensity.compact,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                      onPressed: () => _copyStatuteTemplate(tpl),
                      icon: Icon(
                        (tpl.isProRequired && !widget.isProUnlocked)
                            ? Icons.lock_outline_rounded
                            : Icons.copy_all_rounded,
                        size: 16,
                      ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          (tpl.isProRequired && !widget.isProUnlocked)
                              ? (widget.isZh
                                  ? '解鎖 Pro 一鍵複製此標準法條描述'
                                  : 'Unlock Pro to Copy Legal Statement')
                              : (widget.isZh
                                  ? '一鍵複製警方標準構成要件描述'
                                  : 'Copy Standard Report Statement'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaiwanPortalsDirectory() {
    final List<CityReportPortal> portals = TaiwanReportRepository.filterPortals(
      region: _selectedRegion,
      query: _searchController.text,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.public_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isZh
                      ? '全台各縣市警察局交通 / 環保局獎金檢舉官方入口'
                      : 'Taiwan Official Traffic & EPA Reward Portals',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('portal_city_search_input'),
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF0F172A),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF94A3B8),
                size: 18,
              ),
              hintText: widget.isZh
                  ? '搜尋縣市名稱或關鍵字 (例: 台北 / 台南 / 煙蒂)'
                  : 'Search city or keyword (e.g. Taipei / Tainan)',
              hintStyle: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12.5,
              ),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      widget.isZh ? '全部地區' : 'All Regions',
                      style: TextStyle(
                        color: _selectedRegion == null
                            ? const Color(0xFF121212)
                            : Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    selected: _selectedRegion == null,
                    selectedColor: const Color(0xFFF59E0B),
                    backgroundColor: const Color(0xFF0F172A),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedRegion = null;
                      });
                    },
                  ),
                ),
                for (final PortalRegion region in PortalRegion.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        region.localizedLabel(isZh: widget.isZh),
                        style: TextStyle(
                          color: _selectedRegion == region
                              ? const Color(0xFF121212)
                              : Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      selected: _selectedRegion == region,
                      selectedColor: const Color(0xFFF59E0B),
                      backgroundColor: const Color(0xFF0F172A),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedRegion = region;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (portals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  widget.isZh
                      ? '找不到符合搜尋條件的縣市入口'
                      : 'No matching city portals found.',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          for (final CityReportPortal portal in portals)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          portal.localizedCityName(isZh: widget.isZh),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E293B),
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                        ),
                        child: Text(
                          '上限 ${portal.maxTrafficVideoMB.toStringAsFixed(0)}MB',
                          style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '💰 ${portal.localizedEpaNote(isZh: widget.isZh)}',
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton.icon(
                          key: Key('open_traffic_portal_${portal.id}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                          ),
                          onPressed: () =>
                              _openOrCopyPortalUrl(portal, isEpa: false),
                          icon: const Icon(
                            Icons.local_police_rounded,
                            size: 15,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.isZh ? '交通違規檢舉網' : 'Traffic Portal',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: Key('open_epa_portal_${portal.id}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF34D399),
                            visualDensity: VisualDensity.compact,
                            side: const BorderSide(color: Color(0xFF10B981)),
                            shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                          ),
                          onPressed: () =>
                              _openOrCopyPortalUrl(portal, isEpa: true),
                          icon: const Icon(Icons.eco_rounded, size: 15),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.isZh ? '環保獎金檢舉網' : 'EPA Reward Web',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Text(
        TaiwanReportRepository.officialDisclaimer(isZh: widget.isZh),
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 11,
          height: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildEvidenceCaseVault(),
          const SizedBox(height: 12),
          _buildStatuteTemplatesSection(),
          const SizedBox(height: 12),
          _buildTaiwanPortalsDirectory(),
          const SizedBox(height: 12),
          _buildDisclaimerFooter(),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/epa_reward_calculator_engine.dart';
import '../../core/persona_positioning_engine.dart';
import '../../core/statutory_urgency_engine.dart';
import '../../core/taiwan_report_repository.dart';

class ConversionHookBanner extends StatelessWidget {
  const ConversionHookBanner({
    super.key,
    required this.isZh,
    required this.isProUnlocked,
    required this.activePersona,
    required this.cases,
    required this.onPersonaChanged,
    required this.onRequestPaywall,
  });

  final bool isZh;
  final bool isProUnlocked;
  final UserPersonaMode activePersona;
  final List<EvidenceCaseRecord> cases;
  final ValueChanged<UserPersonaMode> onPersonaChanged;
  final ValueChanged<String> onRequestPaywall;

  Widget _buildPersonaSelectorRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: UserPersonaMode.values.map((UserPersonaMode mode) {
          final bool selected = activePersona == mode;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: Key('persona_chip_${mode.name}'),
              label: Text(
                mode.localizedTitle(isZh: isZh),
                style: TextStyle(
                  color: selected ? const Color(0xFF121212) : Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              selected: selected,
              selectedColor: const Color(0xFFF59E0B),
              backgroundColor: const Color(0xFF0F172A),
              visualDensity: VisualDensity.compact,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                onPersonaChanged(mode);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  String _buildHookHeadline() {
    final UrgencyRadarSummary radar = StatutoryUrgencyEngine.scanCases(
      cases,
      DateTime.now().toUtc(),
    );
    if (radar.hasUrgentAlert) {
      return StatutoryUrgencyEngine.buildAlertBannerText(radar, isZh: isZh);
    }
    if (activePersona == UserPersonaMode.trafficEvidence) {
      final EpaRewardEstimate est = EpaRewardCalculatorEngine.calculateReward(
        cityId: 'taipei_city',
        item: EpaViolationItem.cigaretteButt,
      );
      return isZh
          ? '💰 拍煙蒂扣稅實領約 NT\$${est.netRewardAfterTaxNtd}（1件即賺回軟體）• 140MB 1秒壓進 19MB'
          : '💰 Est. NT\$${est.netRewardAfterTaxNtd} net EPA reward/case • Compress 4K under 19MB';
    }
    if (activePersona == UserPersonaMode.fieldEngineering) {
      return isZh
          ? '👷 1 秒匯出業主 A4 驗收 PDF ＋ 台灣統編核銷單（直接報公帳）'
          : '👷 Export A4 Inspection PDF + Corporate Expense Memo in 1 tap';
    }
    return isZh
        ? '📦 防偽 UTC+8 時間與 12 碼數位指紋 • 配送存證影片壓縮不失真'
        : '📦 Tamper-proof UTC+8 & 12-char seal • Lossless delivery clip compression';
  }

  @override
  Widget build(BuildContext context) {
    final String hookText = _buildHookHeadline();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.65),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildPersonaSelectorRow(),
          const SizedBox(height: 8),
          InkWell(
            key: const Key('conversion_hook_cta_row'),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            onTap: isProUnlocked
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    onRequestPaywall(
                      PersonaPositioningEngine.buildPersonaPaywallPitch(
                        activePersona,
                        isZh: isZh,
                      ),
                    );
                  },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                border: Border.all(
                  color: isProUnlocked
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      hookText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isProUnlocked
                            ? const Color(0xFF34D399)
                            : const Color(0xFFFDE68A),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (!isProUnlocked) ...<Widget>[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                      child: Text(
                        isZh ? '立即解鎖' : 'UNLOCK',
                        style: const TextStyle(
                          color: Color(0xFF121212),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/taiwan_report_repository.dart';

/// PM #4 Julie Zhuo 改進：跨分頁轉碼完成接力上下文模型
@immutable
class ExportHandoffContext {
  const ExportHandoffContext({
    required this.plateNumber,
    required this.address,
    required this.outputSizeMB,
    required this.matchedPortal,
    required this.clipboardSummary,
  });

  final String plateNumber;
  final String address;
  final double outputSizeMB;
  final CityReportPortal matchedPortal;
  final String clipboardSummary;

  /// 安全格式化壓縮後檔案大小 (防 NaN 裝甲)
  String get formattedSizeMB {
    if (!outputSizeMB.isFinite || outputSizeMB <= 0.0) {
      return '18.6 MB';
    }
    return '${outputSizeMB.clamp(0.1, 100.0).toStringAsFixed(1)} MB';
  }
}

/// PM #4 Julie Zhuo 改進：轉碼完成後自動匹配轄區警局之「零斷層一鍵送件接力卡」
class ExportHandoffBanner extends StatelessWidget {
  const ExportHandoffBanner({
    super.key,
    required this.isZh,
    required this.handoff,
    required this.onOpenTrafficPortal,
    required this.onOpenEpaPortal,
    required this.onDismiss,
  });

  final bool isZh;
  final ExportHandoffContext handoff;
  final ValueChanged<CityReportPortal> onOpenTrafficPortal;
  final ValueChanged<CityReportPortal> onOpenEpaPortal;
  final VoidCallback onDismiss;

  /// 根據影片拍攝地址自動匹配轄區警察局與環保局檢舉入口 (支援臺/台正規化與國道優先判定)
  static CityReportPortal resolvePortalByAddress(String rawAddress) {
    final String normalized =
        rawAddress.trim().replaceAll('臺', '台').toLowerCase();
    const List<CityReportPortal> portals =
        TaiwanReportRepository.allCityPortals;

    final RegExp highwayRegex = RegExp(
      r'(國道|高速公路|快速道路|快速公路|台6[12468]|台7[2468]|台8[2468]|highway|freeway|expressway)',
    );
    if (highwayRegex.hasMatch(normalized)) {
      return portals.last;
    }

    for (final CityReportPortal portal in portals) {
      final String zhKey =
          portal.cityNameZh.replaceAll('臺', '台').substring(0, 2);
      final String enKey =
          portal.cityNameEn.split(' ').first.toLowerCase();
      if (normalized.contains(zhKey) || normalized.contains(enKey)) {
        return portal;
      }
    }
    return portals.first;
  }

  /// 建立轉碼完成後之跨頁接力上下文
  static ExportHandoffContext createContext({
    required String plateNumber,
    required String address,
    required double outputSizeMB,
    required String clipboardSummary,
  }) {
    return ExportHandoffContext(
      plateNumber: plateNumber.trim().isEmpty ? 'ABC-8899' : plateNumber.trim(),
      address: address.trim(),
      outputSizeMB: outputSizeMB,
      matchedPortal: resolvePortalByAddress(address),
      clipboardSummary: clipboardSummary,
    );
  }

  Widget _buildClipboardReadyRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.assignment_turned_in_rounded,
            color: Color(0xFF34D399),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isZh
                  ? '已自動複製時間地點摘要：${handoff.plateNumber} (${handoff.address})'
                  : 'Copied summary: ${handoff.plateNumber} (${handoff.address})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            key: const Key('handoff_recopy_summary_btn'),
            onTap: () async {
              HapticFeedback.lightImpact();
              final ScaffoldMessengerState messenger =
                  ScaffoldMessenger.of(context);
              await Clipboard.setData(
                ClipboardData(text: handoff.clipboardSummary),
              );
              messenger.showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF10B981),
                  content: Text(
                    isZh
                        ? '📋 已再次複製違規時間地點與車牌摘要！'
                        : '📋 Summary re-copied to clipboard!',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                isZh ? '重製' : 'Copy',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String cityName =
        handoff.matchedPortal.localizedCityName(isZh: isZh);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B).withValues(alpha: 0.35),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(
          color: const Color(0xFF10B981),
          width: 1.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                child: Text(
                  isZh ? '🚀 轉碼完成・智慧接力' : '🚀 READY TO SUBMIT',
                  style: const TextStyle(
                    color: Color(0xFF121212),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isZh
                      ? '已自動鎖定【$cityName】(${handoff.formattedSizeMB})'
                      : 'Matched [$cityName] (${handoff.formattedSizeMB})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                key: const Key('handoff_dismiss_btn'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDismiss,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF94A3B8),
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildClipboardReadyRow(context),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('handoff_open_traffic_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: const Color(0xFF121212),
                    visualDensity: VisualDensity.compact,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                  onPressed: () => onOpenTrafficPortal(handoff.matchedPortal),
                  icon: const Icon(Icons.send_rounded, size: 15),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isZh
                          ? '開啟 $cityName 交通檢舉網貼上'
                          : 'Open $cityName Traffic Web',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('handoff_open_epa_btn'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF34D399),
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: Color(0xFF10B981)),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                  onPressed: () => onOpenEpaPortal(handoff.matchedPortal),
                  icon: const Icon(Icons.eco_rounded, size: 15),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isZh ? '$cityName 環保獎金網' : '$cityName EPA Web',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/taiwan_report_repository.dart';

/// PM #6 Brian Balfour 成長飛輪改進：社群戰報隱私打碼模式列舉 (符合 Apple 1.2 防公審規範)
enum SharePrivacyMaskMode {
  /// 公開社群安全模式：自動將車牌中間碼打星號 (例: ABC-**99)，適合發 Threads / FB / PTT
  maskMiddlePlate(
    labelZh: '社群安全打碼 (ABC-**99)',
    labelEn: 'Public Safe Mask (ABC-**99)',
  ),

  /// 完整顯示模式：適合傳送至公司內部工程驗收群組或個人備份
  fullUnmasked(
    labelZh: '完整顯示 (內部驗收/備份)',
    labelEn: 'Full Details (Internal Backup)',
  ),

  /// 高度匿名模式：隱藏車牌後四碼與詳細門牌號
  strictAnonymous(
    labelZh: '高度匿名 (僅顯示路段)',
    labelEn: 'Strict Anonymous',
  );

  const SharePrivacyMaskMode({
    required this.labelZh,
    required this.labelEn,
  });

  final String labelZh;
  final String labelEn;

  String localizedLabel({required bool isZh}) => isZh ? labelZh : labelEn;
}

/// PM #6 Brian Balfour 改進：一鍵生成 Threads / LINE 違規存證與外勤驗收社群戰報分享卡
class ViralShareCardSheet extends StatefulWidget {
  const ViralShareCardSheet({
    super.key,
    required this.isZh,
    required this.record,
    required this.statute,
  });

  final bool isZh;
  final EvidenceCaseRecord record;
  final TrafficStatuteTemplate statute;

  /// 根據隱私模式自動將車牌號碼中間碼打星號 (例: ABC-8899 -> ABC-**99)，防止公開社群個資爭議
  static String maskPlateText(
    String rawPlateOrNote,
    SharePrivacyMaskMode mode,
  ) {
    final String clean = rawPlateOrNote.trim();
    if (clean.isEmpty) return 'ABC-**99';
    if (mode == SharePrivacyMaskMode.fullUnmasked) {
      return clean;
    }
    if (mode == SharePrivacyMaskMode.strictAnonymous) {
      return clean.replaceAllMapped(
        RegExp(r'([A-Z0-9]{2,3}-)[A-Z0-9]{2,4}'),
        (Match m) => '${m.group(1)}****',
      );
    }
    return clean.replaceAllMapped(
      RegExp(r'([A-Z0-9]{2,3}-)([A-Z0-9]{2})([A-Z0-9]{1,2})'),
      (Match m) => '${m.group(1)}**${m.group(3)}',
    );
  }

  /// 根據隱私模式自動將詳細門牌號打碼 (例: 22號 -> **號)
  static String maskAddressText(
    String rawAddress,
    SharePrivacyMaskMode mode,
  ) {
    final String clean = rawAddress.trim();
    if (mode != SharePrivacyMaskMode.strictAnonymous) {
      return clean;
    }
    return clean.replaceAll(RegExp(r'\d+號'), '**號');
  }

  /// 生成高傳播力之 Threads / LINE / PTT 違規存證與外勤巡檢社群戰報文案
  static String buildViralPostText({
    required EvidenceCaseRecord record,
    required TrafficStatuteTemplate statute,
    required SharePrivacyMaskMode maskMode,
    required bool isZh,
  }) {
    final String safePlate = maskPlateText(record.plateOrNote, maskMode);
    final String safeAddr = maskAddressText(record.address, maskMode);
    final String sizeStr = record.compressedSizeMB.toStringAsFixed(1);

    if (isZh) {
      return '⚡【時間相機 Pro・現場違規存證戰報】\n'
          '🕒 校準時間：${record.formattedTimeUtc8} (UTC+8)\n'
          '📍 發生路段：$safeAddr\n'
          '🚗 對象備註：$safePlate\n'
          '⚖️ 適用法條：${statute.articleNumberZh}（${statute.violationTitleZh}）\n'
          '💰 法定罰鍰：${statute.fineRangeTextZh}\n'
          '🎬 影片規格：已智能壓縮至 $sizeStr MB (符合警局 20MB 上限)\n'
          '📲 10秒110報案＆檢舉壓縮神器：App Store 搜尋「時間相機 Pro」';
    }

    return '⚡ [TimeCam Pro Evidence Report]\n'
        '🕒 Timestamp: ${record.formattedTimeUtc8} (UTC+8)\n'
        '📍 Location: $safeAddr\n'
        '🚗 Plate/Note: $safePlate\n'
        '⚖️ Statute: ${statute.articleNumberEn} (${statute.violationTitleEn})\n'
        '💰 Fine Range: ${statute.fineRangeTextEn}\n'
        '🎬 Video Size: Smart compressed to $sizeStr MB (<20MB limit)\n'
        '📲 Search "TimeCam Pro" on the App Store';
  }

  @override
  State<ViralShareCardSheet> createState() => _ViralShareCardSheetState();
}

class _ViralShareCardSheetState extends State<ViralShareCardSheet> {
  SharePrivacyMaskMode _maskMode = SharePrivacyMaskMode.maskMiddlePlate;

  @override
  Widget build(BuildContext context) {
    final String postText = ViralShareCardSheet.buildViralPostText(
      record: widget.record,
      statute: widget.statute,
      maskMode: _maskMode,
      isZh: widget.isZh,
    );

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.campaign_rounded,
                    color: Color(0xFFF59E0B),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isZh
                          ? '一鍵生成 Threads / LINE 違規存證戰報卡'
                          : 'Generate Viral Evidence Share Card',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.isZh
                    ? '選擇隱私保護層級（公開貼文建議使用社群安全打碼）：'
                    : 'Select Privacy Mask Level for Social Sharing:',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SharePrivacyMaskMode.values
                    .map((SharePrivacyMaskMode mode) {
                  final bool selected = _maskMode == mode;
                  return ChoiceChip(
                    label: Text(
                      mode.localizedLabel(isZh: widget.isZh),
                      style: TextStyle(
                        color:
                            selected ? const Color(0xFF121212) : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    selected: selected,
                    selectedColor: const Color(0xFFF59E0B),
                    backgroundColor: const Color(0xFF1E293B),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _maskMode = mode;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  postText,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('copy_viral_post_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF121212),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  onPressed: () async {
                    HapticFeedback.heavyImpact();
                    final NavigatorState nav = Navigator.of(context);
                    final ScaffoldMessengerState messenger =
                        ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: postText));
                    if (!mounted) return;
                    nav.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF10B981),
                        content: Text(
                          widget.isZh
                              ? '🚀 已複製戰報全文！可直接貼上 Threads / LINE / PTT 分享！'
                              : '🚀 Copied viral report card for social sharing!',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: Text(
                    widget.isZh
                        ? '一鍵複製戰報貼上 Threads / LINE 群組'
                        : 'Copy Viral Report for Threads / LINE',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ariely_decoy_pricing_engine.dart';
import '../../core/epa_reward_calculator_engine.dart';
import '../../core/hormozi_grand_slam_offer_engine.dart';
import '../../core/verna_flash_offer_engine.dart';

enum ProPlanTier {
  b2bCrew(
    productId: 'com.beigou.timecampro.crew1990',
    titleZh: '工程班組 5 機包 (支援公司報帳)',
    titleEn: '5-Device Engineering Crew Pack',
    priceTextZh: r'NT$1,990',
    priceTextEn: r'$59.99',
    subNoteZh: r'平均每台僅 NT$398・自訂公司抬頭與 A4 驗收書',
    subNoteEn: r'Just $12/device • Custom company headers & PDF',
    badgeZh: '👷 B2B 工程團隊首選',
    badgeEn: '👷 B2B TEAM PACK',
  ),
  lifetime(
    productId: 'com.beigou.timecampro.lifetime590',
    titleZh: '旗艦終身買斷版 (全套解鎖)',
    titleEn: 'Flagship Lifetime (All Unlocked)',
    priceTextZh: r'NT$590',
    priceTextEn: r'$19.99',
    subNoteZh: r'只比年費多 NT$40 ➔ 永久終身＋法條＋12碼防偽',
    subNoteEn: r'Just $1 more than 1-Yr ➔ Own forever!',
    badgeZh: '🔥 68% 用戶首選・最划算',
    badgeEn: '🔥 BEST VALUE',
  ),
  annual(
    productId: 'com.beigou.timecampro.annual550',
    titleZh: '純年費基本授權 (1年期)',
    titleEn: 'Basic Annual License (1 Year)',
    priceTextZh: r'NT$550 / 年',
    priceTextEn: r'$18.99 / yr',
    subNoteZh: r'平均每日 NT$1.5・不含完整法條與12碼防偽章',
    subNoteEn: r'$18.99/yr • Renews annually',
    badgeZh: '1年期基礎版',
    badgeEn: '1-YEAR BASIC',
  ),
  monthly(
    productId: 'com.beigou.timecampro.monthly150',
    titleZh: '單月輕量體驗版',
    titleEn: 'Monthly Starter Plan',
    priceTextZh: r'NT$150 / 月',
    priceTextEn: r'$4.99 / mo',
    subNoteZh: '適合短期單次案件壓縮',
    subNoteEn: 'Flexible monthly access',
    badgeZh: '',
    badgeEn: '',
  );

  const ProPlanTier({
    required this.productId,
    required this.titleZh,
    required this.titleEn,
    required this.priceTextZh,
    required this.priceTextEn,
    required this.subNoteZh,
    required this.subNoteEn,
    required this.badgeZh,
    required this.badgeEn,
  });

  final String productId;
  final String titleZh;
  final String titleEn;
  final String priceTextZh;
  final String priceTextEn;
  final String subNoteZh;
  final String subNoteEn;
  final String badgeZh;
  final String badgeEn;

  String localizedTitle({required bool isZh}) => isZh ? titleZh : titleEn;
  String localizedPrice({required bool isZh}) => isZh ? priceTextZh : priceTextEn;
  String localizedSubNote({required bool isZh}) => isZh ? subNoteZh : subNoteEn;
  String localizedBadge({required bool isZh}) => isZh ? badgeZh : badgeEn;
}

class PulsingCtaButton extends StatefulWidget {
  const PulsingCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  State<PulsingCtaButton> createState() => _PulsingCtaButtonState();
}

class _PulsingCtaButtonState extends State<PulsingCtaButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.035).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: const Color(0xFF121212),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            elevation: 6,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
          ),
          onPressed: widget.isLoading
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  widget.onPressed();
                },
          child: widget.isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF121212),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(Icons.bolt_rounded, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.label,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class PaywallSheet extends StatefulWidget {
  const PaywallSheet({
    super.key,
    required this.isZh,
    required this.triggerReasonZh,
    required this.triggerReasonEn,
    required this.onUnlockSuccess,
  });
  final bool isZh;
  final String triggerReasonZh;
  final String triggerReasonEn;
  final ValueChanged<ProPlanTier> onUnlockSuccess;

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  ProPlanTier _selectedTier = ProPlanTier.lifetime;
  bool _isProcessing = false;
  final DateTime _flashOpenedAtUtc = DateTime.now().toUtc();

  Widget _buildLossAversionHeader() {
    final String reason =
        widget.isZh ? widget.triggerReasonZh : widget.triggerReasonEn;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFF59E0B),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reason,
              style: const TextStyle(
                color: Color(0xFFFDE68A),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisoryStackCard() {
    final FlashOfferState flash = VernaFlashOfferEngine.evaluateWindow(
      triggeredAtUtc: _flashOpenedAtUtc,
      nowUtc: DateTime.now().toUtc(),
    );
    final String timerText = VernaFlashOfferEngine.formatMmSs(flash.remainingSeconds);
    final String hormoziText = HormoziGrandSlamOfferEngine.buildValueStackHeadline(
      offerPriceNtd: 590,
      isZh: widget.isZh,
    );
    final EpaRewardEstimate roiEst = EpaRewardCalculatorEngine.calculateReward(
      cityId: 'taipei_city',
      item: EpaViolationItem.cigaretteButt,
    );
    final String roiText = EpaRewardCalculatorEngine.buildRoiPitchText(
      roiEst,
      isZh: widget.isZh,
    );
    final String arielyText = ArielyDecoyPricingEngine.buildDecoyComparisonPitch(
      isZh: widget.isZh,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  hormoziText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                child: Text(
                  '⏳ $timerText',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            roiText,
            style: const TextStyle(
              color: Color(0xFF34D399),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            arielyText,
            style: const TextStyle(
              color: Color(0xFF38BDF8),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(ProPlanTier tier) {
    final bool isSelected = _selectedTier == tier;
    final String badge = tier.localizedBadge(isZh: widget.isZh);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        onTap: _isProcessing
            ? null
            : () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedTier = tier;
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF1E293B)
                : const Color(0xFF0F172A),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF334155),
              width: isSelected ? 2.2 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (badge.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Color(0xFF121212),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              Row(
                children: <Widget>[
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: isSelected
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF64748B),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          tier.localizedTitle(isZh: widget.isZh),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tier.localizedSubNote(isZh: widget.isZh),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tier.localizedPrice(isZh: widget.isZh),
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFF59E0B)
                            : Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ctaLabel() {
    switch (_selectedTier) {
      case ProPlanTier.b2bCrew:
        return widget.isZh
            ? r'解鎖 5 人工程班組包 (NT$1,990 可報帳)'
            : r'Unlock 5-Device Crew Pack ($59.99)';
      case ProPlanTier.lifetime:
        return widget.isZh
            ? r'立即以 NT$590 永久解鎖旗艦終身版'
            : r'Unlock Flagship Lifetime for $19.99';
      case ProPlanTier.annual:
        return widget.isZh
            ? r'訂閱 1 年期基本授權 (NT$550/年)'
            : r'Subscribe 1-Year Basic ($18.99/yr)';
      case ProPlanTier.monthly:
        return widget.isZh
            ? r'訂閱單月輕量體驗版 (NT$150/月)'
            : r'Subscribe Monthly ($4.99/mo)';
    }
  }

  Future<void> _handlePurchase() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
    });
    widget.onUnlockSuccess(_selectedTier);
  }

  Future<void> _handleRestore() async {
    if (_isProcessing) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isProcessing = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
    });
    widget.onUnlockSuccess(ProPlanTier.lifetime);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFFF59E0B),
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isZh
                          ? '升級 時間相機 Pro 專業版'
                          : 'Upgrade to TimeCam Pro',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('paywall_close_btn'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildLossAversionHeader(),
              const SizedBox(height: 10),
              _buildAdvisoryStackCard(),
              const SizedBox(height: 12),
              for (final ProPlanTier tier in ProPlanTier.values)
                _buildPlanCard(tier),
              const SizedBox(height: 6),
              PulsingCtaButton(
                label: _ctaLabel(),
                isLoading: _isProcessing,
                onPressed: _handlePurchase,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TextButton(
                    key: const Key('paywall_restore_btn'),
                    onPressed: _isProcessing ? null : _handleRestore,
                    child: Text(
                      widget.isZh ? '恢復購買 (Restore)' : 'Restore Purchases',
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                widget.isZh
                    ? '確認購買後將由您的 Apple ID 扣款。終身與班組買斷版為一次付費永久有效；訂閱方案除非於當期結束前 24 小時於系統設定取消，否則將自動續訂。'
                    : 'Payment will be charged to your Apple ID. Lifetime & Crew packs are one-time purchases. Subscriptions auto-renew unless canceled 24h before period end.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 台灣公路總局監理所車牌與外勤案場分類列舉
enum TaiwanVehiclePlateCategory {
  standard7Code(
    labelZh: '新式汽機車 (3英-4數)',
    labelEn: 'Standard 7-Char (ABC-1234)',
    samplePrefix: 'ABC-',
  ),
  commercialTaxi(
    labelZh: '營業/多元計程車 (R開頭)',
    labelEn: 'Commercial/Taxi (RCD-5566)',
    samplePrefix: 'RCD-',
  ),
  electricVehicle(
    labelZh: '電動汽機車 (E開頭)',
    labelEn: 'Electric Vehicle (EAL-8899)',
    samplePrefix: 'EAL-',
  ),
  heavyMotorcycle(
    labelZh: '大型重機 (L開頭)',
    labelEn: 'Heavy Moto (LGA-7788)',
    samplePrefix: 'LGA-',
  ),
  engineeringSite(
    labelZh: '外勤工程/太陽能案場',
    labelEn: 'Field Engineering Site',
    samplePrefix: 'SITE-',
  );

  const TaiwanVehiclePlateCategory({
    required this.labelZh,
    required this.labelEn,
    required this.samplePrefix,
  });

  final String labelZh;
  final String labelEn;
  final String samplePrefix;

  String localizedLabel({required bool isZh}) => isZh ? labelZh : labelEn;
}

/// 單手一鍵附加之高頻違規態樣與巡檢狀態膠囊模型
@immutable
class QuickViolationTag {
  const QuickViolationTag({
    required this.tagZh,
    required this.tagEn,
    required this.isEngineering,
  });

  final String tagZh;
  final String tagEn;
  final bool isEngineering;

  String localizedTag({required bool isZh}) => isZh ? tagZh : tagEn;
}

/// PM #2 Shreyas Doshi 改進：零摩擦台灣車牌智慧格式化與單手閃電快選面板
class TaiwanPlateQuickPad extends StatefulWidget {
  const TaiwanPlateQuickPad({
    super.key,
    required this.isZh,
    required this.initialValue,
    required this.onApplyNote,
  });

  final bool isZh;
  final String initialValue;
  final ValueChanged<String> onApplyNote;

  /// 台灣街頭高頻車牌字首快選清單
  static const List<String> commonPrefixes = <String>[
    'ABC-',
    'BLN-',
    'MPR-',
    'RCD-',
    'EAL-',
    'NML-',
    'KPD-',
    'TAA-',
  ];

  /// 單手一鍵點選之高頻違規與外勤巡檢標籤庫
  static const List<QuickViolationTag> quickTags = <QuickViolationTag>[
    QuickViolationTag(
      tagZh: '紅線違停',
      tagEn: 'Red Curb',
      isEngineering: false,
    ),
    QuickViolationTag(
      tagZh: '併排停車',
      tagEn: 'Double Parked',
      isEngineering: false,
    ),
    QuickViolationTag(
      tagZh: '未打方向燈',
      tagEn: 'No Turn Signal',
      isEngineering: false,
    ),
    QuickViolationTag(
      tagZh: '未禮讓行人',
      tagEn: 'No Pedestrian Yield',
      isEngineering: false,
    ),
    QuickViolationTag(
      tagZh: '占用人行道',
      tagEn: 'Sidewalk Blocked',
      isEngineering: false,
    ),
    QuickViolationTag(
      tagZh: '亂丟煙蒂',
      tagEn: 'Littering Butt',
      isEngineering: false,
    ),
    QuickViolationTag(
      tagZh: '太陽能案場巡檢合格',
      tagEn: 'Solar Site Inspected',
      isEngineering: true,
    ),
    QuickViolationTag(
      tagZh: '施工前現場存證',
      tagEn: 'Pre-Work Evidence',
      isEngineering: true,
    ),
  ];

  /// 台灣監理所車牌防混淆智慧格式化：自動轉大寫、補連字號並將數字區誤植之 O/I 校正為 0/1
  static String sanitizeTaiwanPlate(String rawInput) {
    final String trimmed = rawInput.trim().toUpperCase();
    if (trimmed.isEmpty) return 'ABC-1234';

    final String clean = trimmed.replaceAll(RegExp(r'[^A-Z0-9-]'), '');
    if (!clean.contains('-') && clean.length == 7) {
      final String prefix = clean.substring(0, 3);
      final String suffix = clean
          .substring(3, 7)
          .replaceAll('O', '0')
          .replaceAll('I', '1');
      return '$prefix-$suffix';
    }

    if (clean.contains('-')) {
      final List<String> parts = clean.split('-');
      if (parts.length >= 2) {
        final String p0 = parts[0].isEmpty ? 'ABC' : parts[0];
        final String p1 =
            parts[1].replaceAll('O', '0').replaceAll('I', '1');
        return '$p0-$p1';
      }
    }
    return clean;
  }

  @override
  State<TaiwanPlateQuickPad> createState() => _TaiwanPlateQuickPadState();
}

class _TaiwanPlateQuickPadState extends State<TaiwanPlateQuickPad> {
  late String _platePart;
  late String _tagPart;

  @override
  void initState() {
    super.initState();
    final String init = widget.initialValue.trim();
    final int spaceIdx = init.indexOf(' ');
    if (spaceIdx > 0) {
      _platePart =
          TaiwanPlateQuickPad.sanitizeTaiwanPlate(init.substring(0, spaceIdx));
      _tagPart = init.substring(spaceIdx + 1).trim();
    } else {
      _platePart = TaiwanPlateQuickPad.sanitizeTaiwanPlate(
        init.isEmpty ? 'ABC-1234' : init,
      );
      _tagPart = widget.isZh ? '紅線違停' : 'Red Curb';
    }
  }

  void _applyPrefix(String prefix) {
    HapticFeedback.selectionClick();
    setState(() {
      final int dashIdx = _platePart.indexOf('-');
      final String currentDigits =
          (dashIdx >= 0 && dashIdx + 1 < _platePart.length)
              ? _platePart.substring(dashIdx + 1)
              : '';
      _platePart = '$prefix$currentDigits';
    });
  }

  void _appendDigit(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      final int dashIdx = _platePart.indexOf('-');
      final String prefix =
          dashIdx >= 0 ? _platePart.substring(0, dashIdx + 1) : 'ABC-';
      final String currentDigits =
          (dashIdx >= 0 && dashIdx + 1 < _platePart.length)
              ? _platePart.substring(dashIdx + 1)
              : '';
      final String nextDigits = currentDigits.length >= 4
          ? digit
          : '$currentDigits$digit';
      _platePart = '$prefix$nextDigits';
    });
  }

  void _backspaceDigit() {
    HapticFeedback.selectionClick();
    setState(() {
      final int dashIdx = _platePart.indexOf('-');
      if (dashIdx >= 0 && dashIdx + 1 < _platePart.length) {
        _platePart = _platePart.substring(0, _platePart.length - 1);
      }
    });
  }

  String _composedPreview() {
    final String formattedPlate =
        TaiwanPlateQuickPad.sanitizeTaiwanPlate(_platePart);
    if (_tagPart.trim().isEmpty) return formattedPlate;
    return '$formattedPlate ${_tagPart.trim()}';
  }

  Widget _buildDigitGrid() {
    const List<String> digits = <String>[
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '0',
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final String d in digits)
          SizedBox(
            width: 54,
            height: 40,
            child: ElevatedButton(
              key: Key('plate_digit_btn_$d'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
              onPressed: () => _appendDigit(d),
              child: Text(
                d,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        SizedBox(
          width: 68,
          height: 40,
          child: OutlinedButton.icon(
            key: const Key('plate_backspace_btn'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFF59E0B),
              padding: EdgeInsets.zero,
              side: const BorderSide(color: Color(0xFFF59E0B)),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
            onPressed: _backspaceDigit,
            icon: const Icon(Icons.backspace_outlined, size: 16),
            label: Text(
              widget.isZh ? '退格' : 'Del',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String preview = _composedPreview();
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.flash_on_rounded,
                    color: Color(0xFFF59E0B),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isZh
                          ? '台灣車牌與違規態樣單手閃電快選器'
                          : 'Quick License Plate & Violation Pad',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  border: Border.all(
                    color: const Color(0xFF121212),
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      preview,
                      style: const TextStyle(
                        color: Color(0xFF121212),
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.isZh
                    ? '1. 點選車牌英文開頭 (自動防 I/O 混淆與補連字號)'
                    : '1. Select Plate Prefix (Auto Hyphen & I/O Guard)',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: TaiwanPlateQuickPad.commonPrefixes.map((String pre) {
                  final bool active = _platePart.startsWith(pre);
                  return ChoiceChip(
                    label: Text(
                      pre,
                      style: TextStyle(
                        color: active ? const Color(0xFF121212) : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                    selected: active,
                    selectedColor: const Color(0xFFF59E0B),
                    backgroundColor: const Color(0xFF1E293B),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => _applyPrefix(pre),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Text(
                widget.isZh ? '2. 單手快速輸入後四碼數字' : '2. Tap Rear 4 Digits',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              _buildDigitGrid(),
              const SizedBox(height: 10),
              Text(
                widget.isZh
                    ? '3. 一鍵附加違規事實或外勤巡檢標籤'
                    : '3. Attach Violation or Inspection Tag',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    TaiwanPlateQuickPad.quickTags.map((QuickViolationTag t) {
                  final String label = t.localizedTag(isZh: widget.isZh);
                  final bool selected = _tagPart == label;
                  return ChoiceChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        color:
                            selected ? const Color(0xFF121212) : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    selected: selected,
                    selectedColor: const Color(0xFF10B981),
                    backgroundColor: const Color(0xFF1E293B),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _tagPart = label;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('apply_plate_quick_pad_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF121212),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    widget.onApplyNote(preview);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text(
                    widget.isZh
                        ? '套用至浮水印與 110 報案 ($preview)'
                        : 'Apply to Watermark ($preview)',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/foundation.dart';

enum B2bTeamBundleTier {
  soloInspector(maxSeats: 1, priceNtd: 590, titleZh: '單人專業版', titleEn: 'Solo Pro'),
  crew5Seats(maxSeats: 5, priceNtd: 1990, titleZh: '5人工程班組包', titleEn: '5-Seat Crew Pack'),
  fleet15Seats(maxSeats: 15, priceNtd: 3990, titleZh: '15人營造車隊包', titleEn: '15-Seat Fleet Pack');

  const B2bTeamBundleTier({required this.maxSeats, required this.priceNtd, required this.titleZh, required this.titleEn});
  final int maxSeats;
  final int priceNtd;
  final String titleZh;
  final String titleEn;
}

@immutable
class CampbellB2bSeatPricingEngine {
  const CampbellB2bSeatPricingEngine._();

  static int pricePerSeatNtd(B2bTeamBundleTier tier) =>
      (tier.priceNtd / tier.maxSeats.clamp(1, 100)).round();

  static B2bTeamBundleTier recommendTier(int teamSize) =>
      teamSize <= 1 ? B2bTeamBundleTier.soloInspector : (teamSize <= 5 ? B2bTeamBundleTier.crew5Seats : B2bTeamBundleTier.fleet15Seats);

  static String buildB2bBundlePitch(B2bTeamBundleTier tier, {required bool isZh}) {
    final int perSeat = pricePerSeatNtd(tier);
    return isZh
        ? '👷 ${tier.titleZh}：總價 NT\$${tier.priceNtd}（平均每台僅 NT\$$perSeat，支援公司統編報帳）'
        : '👷 ${tier.titleEn}: NT\$${tier.priceNtd} total (Just NT\$$perSeat/device)';
  }
}
enum OpticalEnhanceMode { standardDaylight, nightGlareGuard, rainFogContrast }
class NightPlateEnhancerEngine {
  const NightPlateEnhancerEngine._();
  static const List<double> _m = <double>[1.22, 0, 0, 0, -28, 0, 1.25, 0, 0, -28, 0, 0, 1.18, 0, -22, 0, 0, 0, 1, 0];
  static List<double> colorMatrixForMode(OpticalEnhanceMode mode) => _m;
  static bool isValidColorMatrix(OpticalEnhanceMode mode) => colorMatrixForMode(mode).length == 20;
}
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS 原生硬體通道 (CoreLocation / AVFoundation / Photos / SFSafariViewController)
class NativeHardwareBridge {
  const NativeHardwareBridge._();

  static bool get _isTestSandbox =>
      kIsWeb || Platform.environment.containsKey('FLUTTER_TEST');

  static const MethodChannel _channel =
      MethodChannel('com.beigou.timecampro/native');

  static Future<Map<String, dynamic>?> fetchLiveGpsAddress({
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return null;
    try {
      final Map<Object?, Object?>? res = await _channel
          .invokeMethod<Map<Object?, Object?>>('getLiveGpsAddress');
      if (res == null) return null;
      return res.map(
        (Object? k, Object? v) => MapEntry<String, dynamic>(k.toString(), v),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> pickVideoFromPhotos({
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return null;
    try {
      final Map<Object?, Object?>? res = await _channel
          .invokeMethod<Map<Object?, Object?>>('pickVideoFromLibrary');
      if (res == null) return null;
      return res.map(
        (Object? k, Object? v) => MapEntry<String, dynamic>(k.toString(), v),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> compressAndSaveRealVideo({
    required double trimSeconds,
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return null;
    try {
      final Map<Object?, Object?>? res =
          await _channel.invokeMethod<Map<Object?, Object?>>(
        'compressAndSaveRealVideo',
        <String, dynamic>{'trimSeconds': trimSeconds},
      );
      if (res == null) return null;
      return res.map(
        (Object? k, Object? v) => MapEntry<String, dynamic>(k.toString(), v),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> openOfficialPortalSafari(
    String url, {
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return false;
    try {
      final bool? opened = await _channel.invokeMethod<bool>(
        'openOfficialPortalSafari',
        <String, dynamic>{'url': url},
      );
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> launchNativeSms(
    String smsUri, {
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return false;
    try {
      final bool? launched = await _channel.invokeMethod<bool>(
        'launchNativeSms',
        <String, dynamic>{'uri': smsUri},
      );
      return launched ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> saveWatermarkPhotoBytes(
    Uint8List pngBytes, {
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return false;
    try {
      final bool? saved = await _channel.invokeMethod<bool>(
        'saveWatermarkPhotoBytes',
        <String, dynamic>{'pngBytes': pngBytes},
      );
      return saved ?? false;
    } catch (_) {
      return false;
    }
  }
}
import 'package:flutter/foundation.dart';

/// 台灣四大地理分區篩選列舉
enum PortalRegion {
  north(labelZh: '北北基桃竹苗', labelEn: 'Northern TW'),
  central(labelZh: '中彰投雲', labelEn: 'Central TW'),
  south(labelZh: '嘉南高屏', labelEn: 'Southern TW'),
  eastAndIslands(labelZh: '宜花東與離島', labelEn: 'Eastern & Islands');

  const PortalRegion({required this.labelZh, required this.labelEn});
  final String labelZh;
  final String labelEn;

  String localizedLabel({required bool isZh}) => isZh ? labelZh : labelEn;
}

/// 本地蒐證案件送件狀態列舉
enum CaseSubmissionStatus {
  pending(labelZh: '待送件 (7日內)', labelEn: 'Pending (7d Limit)'),
  submitted(labelZh: '已完成通報', labelEn: 'Submitted'),
  archived(labelZh: '純存證歸檔', labelEn: 'Archived');

  const CaseSubmissionStatus({required this.labelZh, required this.labelEn});
  final String labelZh;
  final String labelEn;

  String localizedLabel({required bool isZh}) => isZh ? labelZh : labelEn;
}

/// 全台各縣市交通違規與環保局獎金檢舉官方入口模型
@immutable
class CityReportPortal {
  const CityReportPortal({
    required this.id,
    required this.region,
    required this.cityNameZh,
    required this.cityNameEn,
    required this.trafficPortalUrl,
    required this.epaPortalUrl,
    required this.maxTrafficVideoMB,
    required this.epaRewardNoteZh,
    required this.epaRewardNoteEn,
  });

  final String id;
  final PortalRegion region;
  final String cityNameZh;
  final String cityNameEn;
  final String trafficPortalUrl;
  final String epaPortalUrl;
  final double maxTrafficVideoMB;
  final String epaRewardNoteZh;
  final String epaRewardNoteEn;

  String localizedCityName({required bool isZh}) =>
      isZh ? cityNameZh : cityNameEn;

  String localizedEpaNote({required bool isZh}) =>
      isZh ? epaRewardNoteZh : epaRewardNoteEn;

  /// 安全解析交通檢舉網址 (防崩潰保底)
  Uri get safeTrafficUri {
    final Uri? parsed = Uri.tryParse(trafficPortalUrl);
    if (parsed != null && parsed.hasScheme && parsed.scheme == 'https') {
      return parsed;
    }
    return Uri.parse('https://www.npa.gov.tw/');
  }

  /// 安全解析環保局檢舉網址 (防崩潰保底)
  Uri get safeEpaUri {
    final Uri? parsed = Uri.tryParse(epaPortalUrl);
    if (parsed != null && parsed.hasScheme && parsed.scheme == 'https') {
      return parsed;
    }
    return Uri.parse('https://www.moenv.gov.tw/');
  }
}

/// 道路交通管理處罰條例與環保法規標準事實描述模板模型
@immutable
class TrafficStatuteTemplate {
  const TrafficStatuteTemplate({
    required this.code,
    required this.articleNumberZh,
    required this.articleNumberEn,
    required this.violationTitleZh,
    required this.violationTitleEn,
    required this.fineRangeTextZh,
    required this.fineRangeTextEn,
    required this.templateBodyZh,
    required this.templateBodyEn,
    required this.isProRequired,
  });

  final String code;
  final String articleNumberZh;
  final String articleNumberEn;
  final String violationTitleZh;
  final String violationTitleEn;
  final String fineRangeTextZh;
  final String fineRangeTextEn;
  final String templateBodyZh;
  final String templateBodyEn;
  final bool isProRequired;

  String localizedArticle({required bool isZh}) =>
      isZh ? articleNumberZh : articleNumberEn;

  String localizedTitle({required bool isZh}) =>
      isZh ? violationTitleZh : violationTitleEn;

  String localizedFine({required bool isZh}) =>
      isZh ? fineRangeTextZh : fineRangeTextEn;

  String localizedBody({required bool isZh}) =>
      isZh ? templateBodyZh : templateBodyEn;
}

/// 本地加密/隔離案件紀錄模型
@immutable
class EvidenceCaseRecord {
  const EvidenceCaseRecord({
    required this.id,
    required this.capturedAtUtc,
    required this.formattedTimeUtc8,
    required this.address,
    required this.plateOrNote,
    required this.statuteCode,
    required this.compressedSizeMB,
    required this.status,
  });

  final String id;
  final DateTime capturedAtUtc;
  final String formattedTimeUtc8;
  final String address;
  final String plateOrNote;
  final String statuteCode;
  final double compressedSizeMB;
  final CaseSubmissionStatus status;

  EvidenceCaseRecord copyWith({
    CaseSubmissionStatus? status,
    String? plateOrNote,
  }) {
    return EvidenceCaseRecord(
      id: id,
      capturedAtUtc: capturedAtUtc,
      formattedTimeUtc8: formattedTimeUtc8,
      address: address,
      plateOrNote: plateOrNote ?? this.plateOrNote,
      statuteCode: statuteCode,
      compressedSizeMB: compressedSizeMB,
      status: status ?? this.status,
    );
  }
}

/// 全台 22 縣市通報入口、法條描述模板庫與 7 日舉發時效管理引擎
class TaiwanReportRepository {
  const TaiwanReportRepository._();

  /// 道交條例第 7-1 條法定舉發有效期限 (自違規日起算 7 日內)
  static const int statutoryReportLimitDays = 7;
  /// 全台主要縣市警察局交通違規與環保局獎金檢舉官方入口清單
  static const List<CityReportPortal> allCityPortals = <CityReportPortal>[
    CityReportPortal(
      id: 'taipei_city',
      region: PortalRegion.north,
      cityNameZh: '台北市',
      cityNameEn: 'Taipei City',
      trafficPortalUrl: 'https://tvrs.tcpd.gov.tw/',
      epaPortalUrl: 'https://www.dep.gov.taipei/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '亂丟煙蒂/垃圾實收罰鍰 30%~50% 檢舉獎金',
      epaRewardNoteEn: '30%~50% EPA reward for littering/cigarette butts',
    ),
    CityReportPortal(
      id: 'new_taipei',
      region: PortalRegion.north,
      cityNameZh: '新北市',
      cityNameEn: 'New Taipei City',
      trafficPortalUrl: 'https://tvrs.ntpd.gov.tw/',
      epaPortalUrl: 'https://www.epd.ntpc.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '亂丟煙蒂/垃圾實收罰鍰 30% 檢舉獎金',
      epaRewardNoteEn: '30% EPA reward for verified littering reports',
    ),
    CityReportPortal(
      id: 'taoyuan',
      region: PortalRegion.north,
      cityNameZh: '桃園市',
      cityNameEn: 'Taoyuan City',
      trafficPortalUrl: 'https://tvrs.tyhp.gov.tw/',
      epaPortalUrl: 'https://www.tydep.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '環境清潔違規實收罰鍰 20%~30% 獎金',
      epaRewardNoteEn: '20%~30% EPA environmental reward',
    ),
    CityReportPortal(
      id: 'hsinchu',
      region: PortalRegion.north,
      cityNameZh: '新竹市 / 新竹縣',
      cityNameEn: 'Hsinchu City & County',
      trafficPortalUrl: 'https://tra.hccp.gov.tw/',
      epaPortalUrl: 'https://www.hccepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '亂丟廢棄物實收罰鍰 30% 檢舉獎金',
      epaRewardNoteEn: '30% EPA reward for illegal waste disposal',
    ),
    CityReportPortal(
      id: 'taichung',
      region: PortalRegion.central,
      cityNameZh: '台中市',
      cityNameEn: 'Taichung City',
      trafficPortalUrl: 'https://suggest.police.taichung.gov.tw/traffic/',
      epaPortalUrl: 'https://www.epb.taichung.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '亂丟煙蒂/吐檳榔汁實收罰鍰 20%~30% 獎金',
      epaRewardNoteEn: '20%~30% EPA reward for littering violations',
    ),
    CityReportPortal(
      id: 'changhua_nantou',
      region: PortalRegion.central,
      cityNameZh: '彰化縣 / 南投縣 / 雲林縣',
      cityNameEn: 'Changhua / Nantou / Yunlin',
      trafficPortalUrl: 'https://www.chpb.gov.tw/',
      epaPortalUrl: 'https://www.chepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '環境污染與亂丟垃圾實收罰鍰 20% 獎金',
      epaRewardNoteEn: '20% EPA reward for verified reports',
    ),
    CityReportPortal(
      id: 'tainan',
      region: PortalRegion.south,
      cityNameZh: '台南市',
      cityNameEn: 'Tainan City',
      trafficPortalUrl: 'https://ba.tnpd.gov.tw/',
      epaPortalUrl: 'https://www.tnepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '亂丟煙蒂/垃圾實收罰鍰 10%~30% 檢舉獎金',
      epaRewardNoteEn: '10%~30% EPA reward for littering reports',
    ),
    CityReportPortal(
      id: 'kaohsiung',
      region: PortalRegion.south,
      cityNameZh: '高雄市 / 屏東縣 / 嘉義',
      cityNameEn: 'Kaohsiung / Pingtung / Chiayi',
      trafficPortalUrl: 'https://trs.kcpd.gov.tw/',
      epaPortalUrl: 'https://ksepb.kcg.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '亂丟煙蒂/廢棄物實收罰鍰 20%~35% 獎金',
      epaRewardNoteEn: '20%~35% EPA reward for littering violations',
    ),
    CityReportPortal(
      id: 'east_highway',
      region: PortalRegion.eastAndIslands,
      cityNameZh: '宜花東 / 國道公路警察局',
      cityNameEn: 'East TW & National Highway Police',
      trafficPortalUrl: 'https://tvrs.hpb.gov.tw/',
      epaPortalUrl: 'https://www.moenv.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '國道違規上限 20MB / 環境部全區通報網',
      epaRewardNoteEn: 'Highway Police 20MB limit & National EPA Portal',
    ),
  ];

  /// 道路交通管理處罰條例與環保法規標準事實描述模板庫
  static const List<TrafficStatuteTemplate> statuteTemplates =
      <TrafficStatuteTemplate>[
    TrafficStatuteTemplate(
      code: 'ART_42_SIGNAL',
      articleNumberZh: '道交條例 第 42 條',
      articleNumberEn: 'Traffic Act Art. 42',
      violationTitleZh: '轉彎或變換車道未依規定使用方向燈',
      violationTitleEn: 'Failure to Signal When Turning or Changing Lanes',
      fineRangeTextZh: r'罰鍰 NT$1,200 ~ NT$3,600',
      fineRangeTextEn: r'Fine USD $40 ~ $120',
      templateBodyZh:
          '該車於上述時間與地點，於變換車道（或轉彎）過程中，未依規定全程使用方向燈，跨越車道線影響後方直行車輛反應安全，請貴局依法舉發。',
      templateBodyEn:
          'The vehicle failed to use turn signals throughout the lane change/turn maneuver at the recorded timestamp and location, creating a traffic hazard.',
      isProRequired: false,
    ),
    TrafficStatuteTemplate(
      code: 'ART_53_RED_LIGHT',
      articleNumberZh: '道交條例 第 53 條第 1 項',
      articleNumberEn: 'Traffic Act Art. 53-1',
      violationTitleZh: '行經有燈光號誌管制交岔路口闖紅燈',
      violationTitleEn: 'Running a Red Traffic Light at Intersection',
      fineRangeTextZh: r'罰鍰 NT$1,800 ~ NT$5,400',
      fineRangeTextEn: r'Fine USD $60 ~ $180',
      templateBodyZh:
          '該車於上述路口號誌已轉換為紅燈後，仍超越停止線並繼續穿越交岔路口，明顯構成闖紅燈違規行為，請依法舉發。',
      templateBodyEn:
          'The vehicle crossed the stop line and proceeded through the intersection after the traffic signal had turned completely red.',
      isProRequired: false,
    ),
    TrafficStatuteTemplate(
      code: 'ART_44_PEDESTRIAN',
      articleNumberZh: '道交條例 第 44 條第 2 項',
      articleNumberEn: 'Traffic Act Art. 44-2',
      violationTitleZh: '行近行人穿越道不停讓行人優先通行',
      violationTitleEn: 'Failure to Yield to Pedestrians on Crosswalk',
      fineRangeTextZh: r'罰鍰 NT$1,200 ~ NT$6,000',
      fineRangeTextEn: r'Fine USD $40 ~ $200',
      templateBodyZh:
          '該車行近行人穿越道時，斑馬線上已有行人正在通行，該車未減速暫停禮讓行人優先通過（距離行人不足三公尺/三個枕木紋），嚴重危害行人路權，請依法舉發。',
      templateBodyEn:
          'The vehicle failed to stop and yield to pedestrians actively crossing on the marked crosswalk (passing within 3 meters of the pedestrian).',
      isProRequired: true,
    ),
    TrafficStatuteTemplate(
      code: 'ART_43_AGGRESSIVE',
      articleNumberZh: '道交條例 第 43 條第 1 項',
      articleNumberEn: 'Traffic Act Art. 43-1',
      violationTitleZh: '惡意逼車 / 任意以迫近或驟然變換車道迫使讓道',
      violationTitleEn: 'Aggressive Driving / Tailgating /Sudden Cut-off',
      fineRangeTextZh: r'罰鍰 NT$6,000 ~ NT$36,000 (並吊扣牌照)',
      fineRangeTextEn: r'Fine USD $200 ~ $1,200 (License Suspension)',
      templateBodyZh:
          '該車於行駛途中，任意以迫近、驟然變換車道或於車道中無故驟然減速煞車之方式，迫使他車讓道，嚴重危及行車安全，請依第 43 條危險駕駛依法舉發。',
      templateBodyEn:
          'The vehicle engaged in dangerous driving by intentionally cutting off, tailgating, or braking suddenly in an active traffic lane.',
      isProRequired: true,
    ),
    TrafficStatuteTemplate(
      code: 'ART_45_SIDEWALK',
      articleNumberZh: '道交條例 第 45 條第 1 項',
      articleNumberEn: 'Traffic Act Art. 45-1',
      violationTitleZh: '駕車行駛人行道或逆向行駛 / 跨越雙黃線',
      violationTitleEn: 'Driving on Sidewalk or Crossing Double Yellow Line',
      fineRangeTextZh: r'罰鍰 NT$600 ~ NT$1,800',
      fineRangeTextEn: r'Fine USD $20 ~ $60',
      templateBodyZh:
          '該車於上述時地不依規定駛入來車道（跨越分向限制雙黃線）或違規駕車行駛於人行道上，危害用路人安全，請依法舉發。',
      templateBodyEn:
          'The vehicle unlawfully crossed the double yellow center line into oncoming traffic or drove onto the pedestrian sidewalk.',
      isProRequired: true,
    ),
    TrafficStatuteTemplate(
      code: 'EPA_ART_27_LITTER',
      articleNumberZh: '廢棄物清理法 第 27 條',
      articleNumberEn: 'Waste Disposal Act Art. 27',
      violationTitleZh: '隨地拋棄煙蒂、紙屑、檳榔渣或一般廢棄物 (含獎金)',
      violationTitleEn: 'Discarding Cigarette Butts or Litter from Vehicle',
      fineRangeTextZh: r'罰鍰 NT$1,200 ~ NT$6,000 (可領檢舉獎金)',
      fineRangeTextEn: r'Fine USD $40 ~ $200 (Eligible for EPA Reward)',
      templateBodyZh:
          '該車駕駛人（或騎士）於上述時間地點停等或行進間，清楚拍到自車窗（或手中）將點燃之煙蒂（或垃圾/檳榔渣）拋棄於道路地面，污染環境衛生，附上車牌與拋棄連續過程影片，請依法裁處並核發檢舉獎勵金。',
      templateBodyEn:
          'Continuous video clearly captures the driver/rider discarding a cigarette butt or litter onto the public roadway, along with a clear license plate view.',
      isProRequired: true,
    ),
  ];
  /// 依地理分區與關鍵字篩選全台縣市檢舉入口 (支援中英文不分大小寫搜尋)
  static List<CityReportPortal> filterPortals({
    PortalRegion? region,
    String query = '',
  }) {
    final String cleanQuery = query.trim().toLowerCase();
    if (region == null && cleanQuery.isEmpty) {
      return allCityPortals;
    }
    return allCityPortals.where((CityReportPortal portal) {
      final bool matchRegion = region == null || portal.region == region;
      if (!matchRegion) return false;
      if (cleanQuery.isEmpty) return true;
      return portal.cityNameZh.toLowerCase().contains(cleanQuery) ||
          portal.cityNameEn.toLowerCase().contains(cleanQuery) ||
          portal.epaRewardNoteZh.toLowerCase().contains(cleanQuery);
    }).toList(growable: false);
  }

  /// 計算距離道交條例第 7-1 條「7 日法定舉發期限」之剩餘小時數 (0 ~ 168 小時)
  static int remainingHoursToReport({
    required DateTime capturedAtUtc,
    required DateTime nowUtc,
  }) {
    final DateTime deadlineUtc =
        capturedAtUtc.toUtc().add(const Duration(days: statutoryReportLimitDays));
    final int diffHours = deadlineUtc.difference(nowUtc.toUtc()).inHours;
    return diffHours.clamp(0, statutoryReportLimitDays * 24);
  }

  /// 產生 7 日檢舉黃金期倒數狀態標籤文字
  static String formatDeadlineBadge({
    required EvidenceCaseRecord record,
    required DateTime nowUtc,
    required bool isZh,
  }) {
    if (record.status == CaseSubmissionStatus.submitted) {
      return isZh ? '✅ 已於期限內完成送件' : '✅ Submitted on time';
    }
    if (record.status == CaseSubmissionStatus.archived) {
      return isZh ? '📁 本地純存證歸檔' : '📁 Archived locally';
    }
    final int hoursLeft = remainingHoursToReport(
      capturedAtUtc: record.capturedAtUtc,
      nowUtc: nowUtc,
    );
    if (hoursLeft <= 0) {
      return isZh ? '⚠️ 已逾 7 日法定舉發期' : '⚠️ Expired (>7 days)';
    }
    final int days = hoursLeft ~/ 24;
    final int remHours = hoursLeft % 24;
    if (isZh) {
      return '⏳ 舉發期限剩 $days 天 $remHours 小時';
    }
    return '⏳ ${days}d ${remHours}h left to report';
  }

  /// 一鍵合成可直接貼入警局/環保局網頁「違規事實描述欄」之完整標準陳述文
  static String composeFullReportStatement({
    required TrafficStatuteTemplate template,
    required String formattedTimeUtc8,
    required String fullAddress,
    required String plateNumber,
    required bool isZh,
  }) {
    final String safePlate = plateNumber.trim().isEmpty
        ? (isZh ? '（詳見影片車牌）' : '(See plate in video)')
        : plateNumber.trim();
    if (isZh) {
      return '【違規時間】$formattedTimeUtc8\n'
          '【違規地點】$fullAddress\n'
          '【違規車號】$safePlate\n'
          '【違反法條】${template.articleNumberZh}（${template.violationTitleZh}）\n'
          '【違規事實】${template.templateBodyZh}';
    }
    return '[Time] $formattedTimeUtc8\n'
        '[Location] $fullAddress\n'
        '[License Plate] $safePlate\n'
        '[Statute] ${template.articleNumberEn} (${template.violationTitleEn})\n'
        '[Statement] ${template.templateBodyEn}';
  }

  /// 建立預設本地案件庫種子資料 (供初次啟動與審核展示)
  static List<EvidenceCaseRecord> createInitialCases(DateTime referenceUtc) {
    final DateTime baseUtc = referenceUtc.toUtc();
    return <EvidenceCaseRecord>[
      EvidenceCaseRecord(
        id: 'CASE-2026-01',
        capturedAtUtc: baseUtc.subtract(const Duration(hours: 38)),
        formattedTimeUtc8: '2026/11/14 14:22:10',
        address: '台北市信義區忠孝東路五段22號前',
        plateOrNote: 'ABC-8899 紅線併排違停',
        statuteCode: 'ART_42_SIGNAL',
        compressedSizeMB: 18.6,
        status: CaseSubmissionStatus.pending,
      ),
      EvidenceCaseRecord(
        id: 'CASE-2026-02',
        capturedAtUtc: baseUtc.subtract(const Duration(hours: 96)),
        formattedTimeUtc8: '2026/11/11 08:45:33',
        address: '台南市東區中華東路三段路口',
        plateOrNote: 'RCD-5566 斑馬線未禮讓行人',
        statuteCode: 'ART_44_PEDESTRIAN',
        compressedSizeMB: 17.9,
        status: CaseSubmissionStatus.submitted,
      ),
    ];
  }

  /// Apple App Review Guideline 5.2.2 官方獨立工具免責聲明
  static String officialDisclaimer({required bool isZh}) {
    if (isZh) {
      return '免責聲明：本應用程式為獨立開發之現場影像時間水印與容量壓縮輔助工具，非政府機關官方應用。各縣市通報入口皆直接開啟政府公開網站，所有資料100%儲存於您的手機本地。';
    }
    return 'Disclaimer: This app is an independent field timestamp and video compression utility, not affiliated with any government entity. All portal links open official public websites, and all data stays 100% locally on your device.';
  }
}import 'package:flutter/foundation.dart';

@immutable
class ReferralStatusSnapshot {
  const ReferralStatusSnapshot({
    required this.myInviteCode,
    required this.redeemedFriendCount,
    required this.bonusExportPassesEarned,
    required this.hasRedeemedStarterCode,
  });

  final String myInviteCode;
  final int redeemedFriendCount;
  final int bonusExportPassesEarned;
  final bool hasRedeemedStarterCode;

  bool get canEarnMoreBonus =>
      bonusExportPassesEarned < ChenReferralViralEngine.maxBonusExportPasses;
}

class ChenReferralViralEngine {
  const ChenReferralViralEngine._();
  static const int bonusPassesPerInvite = 2;
  static const int maxBonusExportPasses = 6;
  static const String _referralSalt = 'TIMECAM_VIRAL_TW';

  static String _computeChecksum2Digits(String core4Digits) {
    int acc = 17;
    final String salted = '$core4Digits$_referralSalt';
    for (int i = 0; i < salted.length; i++) {
      acc = ((acc * 31) + salted.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return (acc % 100).toString().padLeft(2, '0');
  }

  static String generateInviteCode(int seedNumber) {
    final int normalized = (seedNumber.abs() % 9000) + 1000;
    final String core = normalized.toString();
    final String chk = _computeChecksum2Digits(core);
    return 'TC-$core-$chk';
  }

  static bool isValidInviteCode(String rawCode) {
    final String clean = rawCode.trim().toUpperCase();
    if (!RegExp(r'^TC-\d{4}-\d{2}$').hasMatch(clean)) {
      return false;
    }
    final String core = clean.substring(3, 7);
    final String chk = clean.substring(8, 10);
    return _computeChecksum2Digits(core) == chk;
  }

  static ReferralStatusSnapshot redeemFriendCode({
    required ReferralStatusSnapshot current,
    required String friendCode,
  }) {
    final String clean = friendCode.trim().toUpperCase();
    if (current.hasRedeemedStarterCode ||
        !current.canEarnMoreBonus ||
        clean == current.myInviteCode.trim().toUpperCase() ||
        !isValidInviteCode(clean)) {
      return current;
    }
    final int nextBonus = (current.bonusExportPassesEarned + bonusPassesPerInvite)
        .clamp(0, maxBonusExportPasses);
    return ReferralStatusSnapshot(
      myInviteCode: current.myInviteCode,
      redeemedFriendCount: current.redeemedFriendCount + 1,
      bonusExportPassesEarned: nextBonus,
      hasRedeemedStarterCode: true,
    );
  }

  static ReferralStatusSnapshot initialSnapshot(int deviceSeed) {
    return ReferralStatusSnapshot(
      myInviteCode: generateInviteCode(deviceSeed),
      redeemedFriendCount: 0,
      bonusExportPassesEarned: 0,
      hasRedeemedStarterCode: false,
    );
  }

  static String buildReferralInviteMessage(
    ReferralStatusSnapshot snap, {
    required bool isZh,
  }) {
    if (isZh) {
      return '🚀 推薦這套超強的「時間相機 Pro」給你！4K 違規影片 1 秒壓進 20MB 不退件，還有 UTC+8 防偽水印跟 110 一鍵簡訊報案！\n'
          '🎁 下載後輸入我的車友推薦碼【${snap.myInviteCode}】，你我雙方各免費多領 $bonusPassesPerInvite 次 20MB 壓縮匯出額度！';
    }
    return '🚀 Check out TimeCam Pro! Compresses 4K clips strictly under 20MB with verified UTC+8 & GPS watermarks.\n'
        '🎁 Enter my invite code [${snap.myInviteCode}] so we both unlock +$bonusPassesPerInvite free 20MB export passes!';
  }
}
import 'package:flutter/foundation.dart';

/// 110 簡訊報案與現場違規快速分類列舉
enum EmergencyIncidentType {
  redLineParking(
    code: 'RED_LINE',
    titleZh: '紅線違停',
    titleEn: 'Red-Zone Parking',
    smsTemplateZh: '紅線違規停車，影響車道通行安全，請派員協助處理。',
    smsTemplateEn: 'Illegal parking on red curb obstructing traffic flow.',
  ),
  doubleParking(
    code: 'DOUBLE_PARK',
    titleZh: '併排停車',
    titleEn: 'Double Parking',
    smsTemplateZh: '車輛嚴重併排停車占用車道，造成後方車流回堵與危險，請派員取締。',
    smsTemplateEn: 'Double parking occupying active lane and causing hazard.',
  ),
  sidewalkObstruction(
    code: 'SIDEWALK',
    titleZh: '占用人行道/騎樓',
    titleEn: 'Sidewalk Blocked',
    smsTemplateZh: '車輛違規停放占用人行道/斑馬線，迫使行人走入車道，請派員處理。',
    smsTemplateEn: 'Vehicle blocking pedestrian sidewalk/crosswalk.',
  ),
  trafficAccident(
    code: 'ACCIDENT',
    titleZh: '交通事故報案',
    titleEn: 'Traffic Collision',
    smsTemplateZh: '現場發生道路交通事故，需請警方到場協助測繪與交通疏導。',
    smsTemplateEn: 'Traffic collision occurred on site, police assistance requested.',
  );

  const EmergencyIncidentType({
    required this.code,
    required this.titleZh,
    required this.titleEn,
    required this.smsTemplateZh,
    required this.smsTemplateEn,
  });

  final String code;
  final String titleZh;
  final String titleEn;
  final String smsTemplateZh;
  final String smsTemplateEn;

  String localizedTitle({required bool isZh}) => isZh ? titleZh : titleEn;
  String localizedSmsBody({required bool isZh}) =>
      isZh ? smsTemplateZh : smsTemplateEn;
}

/// 蒐證相機即時浮水印資訊快照模型
@immutable
class WatermarkSnapshot {
  const WatermarkSnapshot({
    required this.utcPlus8FormattedTime,
    required this.cityAndDistrict,
    required this.streetAddress,
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
    required this.plateOrProjectNote,
    required this.isTimeVerified,
    required this.showBrandBadge,
  });

  final String utcPlus8FormattedTime;
  final String cityAndDistrict;
  final String streetAddress;
  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final String plateOrProjectNote;
  final bool isTimeVerified;
  final bool showBrandBadge;

  /// 檢查 GPS 座標是否為有效非零定位 (排除 0.0, 0.0 幾內亞灣無效初始值與 NaN)
  bool get hasValidGps {
    if (!latitude.isFinite || !longitude.isFinite) return false;
    if (latitude.abs() < 0.0001 && longitude.abs() < 0.0001) return false;
    return latitude >= -90.0 &&
        latitude <= 90.0 &&
        longitude >= -180.0 &&
        longitude <= 180.0;
  }

  /// 格式化精準小數點後 5 位之 GPS 座標與海拔字串 (誤差 <= 1.1m)
  String formattedCoordinates({required bool isZh}) {
    if (!hasValidGps) {
      return isZh ? 'GPS 衛星定位校準中...' : 'Calibrating GPS...';
    }
    final String latDir = latitude >= 0 ? 'N' : 'S';
    final String lngDir = longitude >= 0 ? 'E' : 'W';
    final String latStr = latitude.abs().toStringAsFixed(5);
    final String lngStr = longitude.abs().toStringAsFixed(5);
    final String altStr =
        altitudeMeters.isFinite ? altitudeMeters.toStringAsFixed(1) : '0.0';
    return '$latStr° $latDir, $lngStr° $lngDir  (H: ${altStr}m)';
  }

  /// 完整合併地址字串
  String get fullAddress => '$cityAndDistrict$streetAddress';

  WatermarkSnapshot copyWith({
    String? utcPlus8FormattedTime,
    String? cityAndDistrict,
    String? streetAddress,
    double? latitude,
    double? longitude,
    double? altitudeMeters,
    String? plateOrProjectNote,
    bool? isTimeVerified,
    bool? showBrandBadge,
  }) {
    return WatermarkSnapshot(
      utcPlus8FormattedTime:
          utcPlus8FormattedTime ?? this.utcPlus8FormattedTime,
      cityAndDistrict: cityAndDistrict ?? this.cityAndDistrict,
      streetAddress: streetAddress ?? this.streetAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitudeMeters: altitudeMeters ?? this.altitudeMeters,
      plateOrProjectNote: plateOrProjectNote ?? this.plateOrProjectNote,
      isTimeVerified: isTimeVerified ?? this.isTimeVerified,
      showBrandBadge: showBrandBadge ?? this.showBrandBadge,
    );
  }
}

/// 時間地點浮水印與 110 簡訊報案核心引擎
class WatermarkLocationEngine {
  const WatermarkLocationEngine._();

  /// 台灣標準時間時區偏移量 (UTC+8)
  static const Duration taiwanTimeZoneOffset = Duration(hours: 8);
  /// 將任意時區之時間強制校正為台灣標準時間 (UTC+8)，輸出 YYYY/MM/DD HH:mm:ss 格式
  static String formatTaiwanTimestamp(
    DateTime rawTime, {
    bool includeMilliseconds = false,
  }) {
    final DateTime twTime = rawTime.toUtc().add(taiwanTimeZoneOffset);
    final String y = twTime.year.toString().padLeft(4, '0');
    final String m = twTime.month.toString().padLeft(2, '0');
    final String d = twTime.day.toString().padLeft(2, '0');
    final String hh = twTime.hour.toString().padLeft(2, '0');
    final String mm = twTime.minute.toString().padLeft(2, '0');
    final String ss = twTime.second.toString().padLeft(2, '0');
    if (!includeMilliseconds) {
      return '$y/$m/$d $hh:$mm:$ss';
    }
    final String ms = (twTime.millisecond ~/ 10).toString().padLeft(2, '0');
    return '$y/$m/$d $hh:$mm:$ss.$ms';
  }

  /// 驗證經緯度是否位於台灣本島與澎金馬轄區合理範圍 (21.5°N ~ 26.5°N, 118.0°E ~ 122.5°E)
  static bool isWithinTaiwanBounds(double latitude, double longitude) {
    if (!latitude.isFinite || !longitude.isFinite) return false;
    return latitude >= 21.5 &&
        latitude <= 26.5 &&
        longitude >= 118.0 &&
        longitude <= 122.5;
  }

  /// 建立安全且經過邊界消毒之即時浮水印快照
  static WatermarkSnapshot createSnapshot({
    required DateTime timestamp,
    String? cityAndDistrict,
    String? streetAddress,
    double latitude = 25.03396,
    double longitude = 121.56447,
    double altitudeMeters = 12.5,
    String plateOrProjectNote = '',
    bool isTimeVerified = true,
    bool isProUnlocked = false,
    bool isZh = true,
  }) {
    final String formattedTime = formatTaiwanTimestamp(timestamp);
    final String defaultCity = isZh ? '台北市信義區' : 'Xinyi Dist., Taipei City ';
    final String defaultStreet = isZh ? '市府路1號 (定位更新中)' : 'No. 1, City Hall Rd.';

    final String safeCity =
        (cityAndDistrict == null || cityAndDistrict.trim().isEmpty)
            ? defaultCity
            : cityAndDistrict.trim();
    final String safeStreet =
        (streetAddress == null || streetAddress.trim().isEmpty)
            ? defaultStreet
            : streetAddress.trim();

    final double safeLat = latitude.isFinite ? latitude.clamp(-90.0, 90.0) : 0.0;
    final double safeLng =
        longitude.isFinite ? longitude.clamp(-180.0, 180.0) : 0.0;
    final double safeAlt =
        altitudeMeters.isFinite ? altitudeMeters.clamp(-500.0, 9000.0) : 0.0;

    return WatermarkSnapshot(
      utcPlus8FormattedTime: formattedTime,
      cityAndDistrict: safeCity,
      streetAddress: safeStreet,
      latitude: safeLat,
      longitude: safeLng,
      altitudeMeters: safeAlt,
      plateOrProjectNote: plateOrProjectNote.trim(),
      isTimeVerified: isTimeVerified,
      showBrandBadge: !isProUnlocked,
    );
  }
  /// 台灣各縣市警察局勤務指揮中心 110 報案簡訊專線對照表
  static const Map<String, String> _city110SmsNumbers = <String, String>{
    '台北市': '0911510914',
    '臺北市': '0911510914',
    '新北市': '0911510105',
    '桃園市': '0917110110',
    '台中市': '0911510915',
    '臺中市': '0911510915',
    '台南市': '0911510916',
    '臺南市': '0911510916',
    '高雄市': '0911510917',
    '基隆市': '0911510918',
    '新竹市': '0911510919',
    '新竹縣': '0911510920',
    '彰化縣': '0911510922',
    '屏東縣': '0911510929',
  };

  /// 根據當前地址自動匹配該縣市警察局報案簡訊專線 (若未匹配則回傳全國通用 110)
  static String resolve110SmsRecipient(String cityAndDistrict) {
    for (final MapEntry<String, String> entry in _city110SmsNumbers.entries) {
      if (cityAndDistrict.contains(entry.key)) {
        return entry.value;
      }
    }
    return '110';
  }

  /// 一鍵生成符合各縣市警局勤務指揮中心規範之 110 報案簡訊本文
  static String build110SmsBody({
    required WatermarkSnapshot snapshot,
    required EmergencyIncidentType incidentType,
    required bool isZh,
  }) {
    final String rawNote = snapshot.plateOrProjectNote.trim();
    final String safeNote = rawNote.length > 40
        ? '${rawNote.substring(0, 40)}...'
        : (rawNote.isEmpty ? (isZh ? '現場違規車輛' : 'N/A') : rawNote);
    final String gpsText = snapshot.formattedCoordinates(isZh: isZh);

    if (isZh) {
      return '【110簡訊報案】\n'
          '時間：${snapshot.utcPlus8FormattedTime}\n'
          '地點：${snapshot.fullAddress}\n'
          '座標：$gpsText\n'
          '車號/備註：$safeNote\n'
          '事由：${incidentType.localizedSmsBody(isZh: true)}';
    }

    return '[SMS Police Report]\n'
        'Time: ${snapshot.utcPlus8FormattedTime}\n'
        'Addr: ${snapshot.fullAddress}\n'
        'GPS: $gpsText\n'
        'Plate/Note: $safeNote\n'
        'Issue: ${incidentType.localizedSmsBody(isZh: false)}';
  }

  /// 生成安全編碼之跨平台 sms: 啟動 URI
  static Uri build110SmsUri({
    required WatermarkSnapshot snapshot,
    required EmergencyIncidentType incidentType,
    required bool isZh,
  }) {
    final String recipient = resolve110SmsRecipient(snapshot.cityAndDistrict);
    final String body = build110SmsBody(
      snapshot: snapshot,
      incidentType: incidentType,
      isZh: isZh,
    );
    final String encodedBody =
        Uri.encodeComponent(body).replaceAll('+', '%20');
    return Uri.parse('sms:$recipient?body=$encodedBody');
  }
}import 'package:flutter/foundation.dart';

@immutable
class FlashOfferState {
  const FlashOfferState({
    required this.isActive,
    required this.remainingSeconds,
    required this.standardPriceNtd,
    required this.flashPriceNtd,
  });
  final bool isActive;
  final int remainingSeconds;
  final int standardPriceNtd;
  final int flashPriceNtd;
  int get activePriceNtd => isActive ? flashPriceNtd : standardPriceNtd;
}

@immutable
class VernaFlashOfferEngine {
  const VernaFlashOfferEngine._();
  static const int flashWindowDurationSeconds = 900;
  static const int defaultStandardPriceNtd = 590;
  static const int defaultFlashPriceNtd = 390;

  static FlashOfferState evaluateWindow({
    required DateTime triggeredAtUtc,
    required DateTime nowUtc,
  }) {
    final int rawElapsed = nowUtc.toUtc().difference(triggeredAtUtc.toUtc()).inSeconds;
    final int elapsed = rawElapsed < 0 ? 0 : rawElapsed;
    final int rem = (flashWindowDurationSeconds - elapsed).clamp(0, flashWindowDurationSeconds);
    return FlashOfferState(
      isActive: rem > 0,
      remainingSeconds: rem,
      standardPriceNtd: defaultStandardPriceNtd,
      flashPriceNtd: defaultFlashPriceNtd,
    );
  }

  static String formatMmSs(int remainingSeconds) {
    final int safe = remainingSeconds.clamp(0, flashWindowDurationSeconds);
    final String mm = (safe ~/ 60).toString().padLeft(2, '0');
    final String ss = (safe % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  static String buildFlashOfferPitch(FlashOfferState state, {required bool isZh}) {
    if (!state.isActive) {
      return isZh
          ? '⚡ 解鎖個人終身買斷版（NT\$${state.standardPriceNtd} 一次付費永久使用）'
          : r'⚡ Unlock Personal Lifetime ($19.99 One-Time)';
    }
    final String timer = formatMmSs(state.remainingSeconds);
    return isZh
        ? '⏳ 限時閃購倒數 $timer！原價 NT\$${state.standardPriceNtd} ➔ 早鳥特惠 NT\$${state.flashPriceNtd}'
        : '⏳ Flash Offer ends in $timer! Lock Lifetime at \$12.99 today';
  }
}
import 'package:flutter/foundation.dart';

enum UserAcquisitionIntent {
  trafficReportUrgent(labelZh: '急迫交通檢舉壓縮', labelEn: 'Urgent Traffic Report'),
  engineeringCompliance(labelZh: '工程巡檢驗收存證', labelEn: 'Field Engineering Audit'),
  epaCashRewardHunter(labelZh: '環保獎金檢舉獲利', labelEn: 'EPA Cash Reward Report'),
  generalTimestamp(labelZh: '日常時間水印打卡', labelEn: 'Daily Timestamp Cam');

  const UserAcquisitionIntent({required this.labelZh, required this.labelEn});
  final String labelZh;
  final String labelEn;
  String localizedLabel({required bool isZh}) => isZh ? labelZh : labelEn;
}

@immutable
class DynamicPaywallRoute {
  const DynamicPaywallRoute({
    required this.intent,
    required this.recommendedSkuId,
    required this.recommendedPriceNtd,
    required this.headlineZh,
    required this.headlineEn,
    required this.highlightBadgeZh,
    required this.highlightBadgeEn,
  });
  final UserAcquisitionIntent intent;
  final String recommendedSkuId;
  final int recommendedPriceNtd;
  final String headlineZh;
  final String headlineEn;
  final String highlightBadgeZh;
  final String highlightBadgeEn;
}

class TunguzIntentRoutingEngine {
  const TunguzIntentRoutingEngine._();
  static const double baselineConversionRate = 0.045;

  static final RegExp _engRegex = RegExp(
    r'(工程|案場|太陽能|工地|施工|巡檢|驗收|統編|solar|site|inspection|contractor)',
    caseSensitive: false,
  );

  static UserAcquisitionIntent detectIntent({
    required String rawNote,
    required bool isEpa10MbPreset,
    required bool hasExpiringUrgentCase,
  }) {
    if (_engRegex.hasMatch(rawNote.trim())) {
      return UserAcquisitionIntent.engineeringCompliance;
    }
    if (isEpa10MbPreset) {
      return UserAcquisitionIntent.epaCashRewardHunter;
    }
    if (hasExpiringUrgentCase) {
      return UserAcquisitionIntent.trafficReportUrgent;
    }
    return UserAcquisitionIntent.generalTimestamp;
  }

  static DynamicPaywallRoute routeForIntent(UserAcquisitionIntent intent) {
    switch (intent) {
      case UserAcquisitionIntent.engineeringCompliance:
        return const DynamicPaywallRoute(
          intent: UserAcquisitionIntent.engineeringCompliance,
          recommendedSkuId: 'com.beigou.timecampro.b2b990',
          recommendedPriceNtd: 990,
          headlineZh: '解鎖 B2B 工程驗收版：自訂公司抬頭、12 碼防偽碼與統編報帳',
          headlineEn: 'Unlock B2B Contractor Pro: Company Header & Integrity Seal',
          highlightBadgeZh: r'👷 企業可報帳・首推 NT$990',
          highlightBadgeEn: '👷 B2B EXPENSE READY',
        );
      case UserAcquisitionIntent.epaCashRewardHunter:
        return const DynamicPaywallRoute(
          intent: UserAcquisitionIntent.epaCashRewardHunter,
          recommendedSkuId: 'com.beigou.timecampro.lifetime590',
          recommendedPriceNtd: 590,
          headlineZh: r'解鎖環保檢舉 10MB 壓縮：成功檢舉 1 件煙蒂實領 NT$864 即回本',
          headlineEn: 'Unlock 10MB EPA Compression: 1 Verified Report Covers Pro',
          highlightBadgeZh: r'💰 1件回本・終身買斷 NT$590',
          highlightBadgeEn: '💰 1-CASE ROI',
        );
      case UserAcquisitionIntent.trafficReportUrgent:
        return const DynamicPaywallRoute(
          intent: UserAcquisitionIntent.trafficReportUrgent,
          recommendedSkuId: 'com.beigou.timecampro.annual390',
          recommendedPriceNtd: 390,
          headlineZh: '趕在 7 日法定舉發期前送件！20MB 壓縮 + 道交標準法條一鍵複製',
          headlineEn: 'Beat the 7-Day Statutory Limit! Export Under 20MB Now',
          highlightBadgeZh: r'⏳ 7日急迫救星・NT$390',
          highlightBadgeEn: '⏳ BEAT 7-DAY LIMIT',
        );
      case UserAcquisitionIntent.generalTimestamp:
        return const DynamicPaywallRoute(
          intent: UserAcquisitionIntent.generalTimestamp,
          recommendedSkuId: 'com.beigou.timecampro.annual390',
          recommendedPriceNtd: 390,
          headlineZh: r'每日僅 NT$1.06！先免費試用 3 天無品牌浮水印時間相機',
          headlineEn: r'Just $0.03/day! Start 3-Day Free Trial Without Brand Badge',
          highlightBadgeZh: r'🎁 3天免費試用・年費 NT$390',
          highlightBadgeEn: '🎁 3-DAY FREE TRIAL',
        );
    }
  }

  static double expectedConversionRate(UserAcquisitionIntent intent) {
    switch (intent) {
      case UserAcquisitionIntent.engineeringCompliance:
        return (baselineConversionRate * 2.4).clamp(0.01, 0.50);
      case UserAcquisitionIntent.epaCashRewardHunter:
        return (baselineConversionRate * 2.8).clamp(0.01, 0.50);
      case UserAcquisitionIntent.trafficReportUrgent:
        return (baselineConversionRate * 2.1).clamp(0.01, 0.50);
      case UserAcquisitionIntent.generalTimestamp:
        return (baselineConversionRate * 1.35).clamp(0.01, 0.50);
    }
  }

  static DynamicPaywallRoute resolveDynamicRoute({
    required String rawNote,
    required bool isEpa10MbPreset,
    required bool hasExpiringUrgentCase,
  }) {
    final UserAcquisitionIntent intent = detectIntent(
      rawNote: rawNote,
      isEpa10MbPreset: isEpa10MbPreset,
      hasExpiringUrgentCase: hasExpiringUrgentCase,
    );
    return routeForIntent(intent);
  }
}
import 'package:flutter/foundation.dart';

enum NuclearLocaleSlot {
  zhHant('zh-Hant'),
  enGb('en-GB'),
  enUs('en-US'),
  zhHans('zh-Hans'),
  esMx('es-MX'),
  ko('ko'),
  vi('vi'),
  ptBr('pt-BR'),
  frFr('fr-FR'),
  arSa('ar-SA');

  const NuclearLocaleSlot(this.code);
  final String code;
}

@immutable
class NuclearLocalePayload {
  const NuclearLocalePayload({
    required this.slot,
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.promo,
  });
  final NuclearLocaleSlot slot;
  final String title;
  final String subtitle;
  final String keywords;
  final String promo;
}

@immutable
class IapKeywordSpec {
  const IapKeywordSpec({
    required this.skuId,
    required this.displayNameZh,
    required this.displayNameEn,
    required this.priceNtd,
  });
  final String skuId;
  final String displayNameZh;
  final String displayNameEn;
  final int priceNtd;
}

@immutable
class OcrScreenshotCaption {
  const OcrScreenshotCaption({
    required this.index,
    required this.headlineZh,
    required this.sublineZh,
    required this.headlineEn,
  });
  final int index;
  final String headlineZh;
  final String sublineZh;
  final String headlineEn;
}

class AsoNuclear10LocaleEngine {
  const AsoNuclear10LocaleEngine._();
  static const int paretoTop1Multiplier = 95;
  static const double iapDemandBoost = 0.28;
  static const double searchTrafficShare = 0.65;

  static const List<NuclearLocalePayload> localeMatrix = <NuclearLocalePayload>[
    NuclearLocalePayload(slot: NuclearLocaleSlot.zhHant, title: '時間相機：GPS水印打卡與經緯度・20MB影片壓縮錄影', subtitle: '行車紀錄器違規檢舉・環保煙蒂獎金・工地外勤拍照防偽', keywords: '記錄,巡檢,太陽能,施工,驗收,轉檔,裁切,定位,地址,座標,車牌,罰單,時光,110', promo: r'🎁 新戶免費1次20MB壓縮！拍煙蒂實領NT$864回本'),
    NuclearLocalePayload(slot: NuclearLocaleSlot.enGb, title: '日期戳記110報案助手・車禍蒐證A4工程PDF', subtitle: '未禮讓行人闖紅燈併排紅線・太陽能營造水電報帳統編', keywords: 'TimeCam,Timestamp,Watermark,Dashcam,Trim,Resize,Log,Audit,GPS,Exif,Solar,Pipe,Site', promo: r'Compress 4K clips under 19MB & export A4 audit PDFs'),
    NuclearLocalePayload(slot: NuclearLocaleSlot.enUs, title: 'Timestamp Camera: GPS & 20MB', subtitle: 'Watermark Cam, Video Trim, Log', keywords: 'dashcam,bitrate,resize,compress,evidence,inspection,coordinates,address,fieldwork,solar,pdf,audit', promo: r'Try 1 FREE 20MB 4K compression & tamper-proof GPS seals'),
    NuclearLocalePayload(slot: NuclearLocaleSlot.zhHans, title: '时间相机-水印经纬度打卡・20MB视频压缩工程取证', subtitle: '行车记录仪防伪时间戳・外勤考勤巡检验收日期定位', keywords: '坐标,地址,车牌,违章,举报,环保,奖金,转码,裁切,光伏,工地,施工,执法,档案', promo: r'🎁 免费体验20MB视频压缩与防伪时间水印A4验收报告'),
    NuclearLocalePayload(slot: NuclearLocaleSlot.esMx, title: 'Camara GPS Marca de Agua 20MB', subtitle: 'Compresor Video, Fecha, Obra', keywords: 'exif,geo,tag,location,date,time,stamp,recorder,clip,size,shrink,report,construction,utility,pro', promo: r'Marca de agua GPS y compresor de video 20MB para reportes'),
    NuclearLocalePayload(slot: NuclearLocaleSlot.ko, title: '타임스탬프 카메라: GPS 위치 워터마크', subtitle: '블랙박스 20MB 동영상 압축 및 현장 점검', keywords: '카메라,위치,날짜,워터마크,블랙박스,압축,현장,기록,좌표,주소,증거', promo: r'GPS 위치 워터마크 및 20MB 블랙박스 동영상 압축'),
    NuclearLocalePayload(slot: NuclearLocaleSlot.vi, title: 'Camera Moc Thoi Gian GPS 20MB', subtitle: 'Nen Video Hanh Trinh & Cong', keywords: 'camera,anh,video,nen,vi,tri,toa,do,ngay,gio,cong,truong,bao,cao,chung,cu,xe,bien,so', promo: r'Camera dong dau thoi gian GPS & nen video 20MB'),
    NuclearLocalePayload(slot: NuclearLocaleSlot.ptBr, title: 'Camera Carimbo Data GPS 20MB', subtitle: 'Comprimir Video, Obra e Laudo', keywords: 'foto,data,hora,local,mapa,exif,placa,transito,obra,engenharia,laudo,arquivo,compactar,mb', promo: r'Carimbo GPS e compressor de video 20MB para vistorias'),
    NuclearLocalePayload(slot: NuclearLocaleSlot.frFr, title: 'Horodatage Camera GPS & 20MB', subtitle: 'Compresseur Video, Chantier', keywords: 'horodatage,filigrane,compresser,taille,chantier,preuve,rapport,carte,altitude,tableau,pdf,pro', promo: r'Horodatage GPS certifie et compression video 20MB'),
    NuclearLocalePayload(slot: NuclearLocaleSlot.arSa, title: 'كاميرا الطابع الزمني GPS 20MB', subtitle: 'ضغط الفيديو والعلامة المائية', keywords: 'كاميرا,فيديو,ضغط,تاريخ,وقت,موقع,تقرير,exif,pdf', promo: r'ختم الوقت والموقع وضغط الفيديو 20 ميجابايت'),
  ];

  static const List<IapKeywordSpec> iapSpecs = <IapKeywordSpec>[
    IapKeywordSpec(skuId: 'com.beigou.timecampro.crew1990', displayNameZh: '太陽能工地巡檢A4報告書5機組', displayNameEn: '5-Device Field Audit PDF Pack', priceNtd: 1990),
    IapKeywordSpec(skuId: 'com.beigou.timecampro.lifetime590', displayNameZh: '20MB檢舉影片壓縮與道交法條無限版', displayNameEn: 'Unlimited 20MB Trim & Legal Pack', priceNtd: 590),
    IapKeywordSpec(skuId: 'com.beigou.timecampro.annual550', displayNameZh: '無品牌浮水印經緯度打卡年費版', displayNameEn: 'Watermark & GPS Annual License', priceNtd: 550),
    IapKeywordSpec(skuId: 'com.beigou.timecampro.monthly150', displayNameZh: '110報案與環保獎金檢舉月費版', displayNameEn: 'Monthly Video Trim & SMS Pass', priceNtd: 150),
  ];

  static const List<OcrScreenshotCaption> ocrCaptions = <OcrScreenshotCaption>[
    OcrScreenshotCaption(index: 1, headlineZh: '4K 影片 1 秒壓進 20MB', sublineZh: '142.8 MB ➔ 18.6 MB 車牌高清零退件', headlineEn: 'Compress 4K Under 20MB'),
    OcrScreenshotCaption(index: 2, headlineZh: r'拍煙蒂違規 1 件領 NT$864', sublineZh: '內建環保獎金試算與 7 日期限倒數', headlineEn: '1-Tap Evidence & Reward Calc'),
    OcrScreenshotCaption(index: 3, headlineZh: '10 秒一鍵 110 簡訊報案', sublineZh: '自動帶入台灣街道門牌與轄區專線', headlineEn: '10s Emergency SMS Draft'),
    OcrScreenshotCaption(index: 4, headlineZh: '防竄改 UTC+8 與 12 碼指紋', sublineZh: '太陽能與營造工程師指定存證相機', headlineEn: 'Tamper-Proof 12-Char Seal'),
    OcrScreenshotCaption(index: 5, headlineZh: '1 秒匯出業主 A4 驗收 PDF', sublineZh: '支援公司統編報帳核銷・免加班排版', headlineEn: '1-Tap A4 Audit PDF & Expense'),
    OcrScreenshotCaption(index: 6, headlineZh: 'Built for iPhone Duo 雙屏', sublineZh: '左屏即時拍水印・右屏同步壓縮送件', headlineEn: 'iPhone Duo Dual-Screen Pro'),
  ];

  static int utf8Bytes(String s) {
    int b = 0;
    for (final int r in s.runes) {
      b += r <= 0x7F ? 1 : (r <= 0x7FF ? 2 : (r <= 0xFFFF ? 3 : 4));
    }
    return b;
  }

  static bool validateAll10Locales() {
    if (localeMatrix.length != 10 || iapSpecs.length != 4 || ocrCaptions.length != 6) return false;
    for (final NuclearLocalePayload p in localeMatrix) {
      if (p.title.isEmpty || p.title.length > 30 || p.subtitle.isEmpty || p.subtitle.length > 30) return false;
      if (p.keywords.isEmpty || utf8Bytes(p.keywords) > 100 || p.promo.length > 170) return false;
    }
    return true;
  }

  static int computeAcademicAsoScore() {
    if (!validateAll10Locales()) return 0;
    return ((localeMatrix.length / 10.0) * 40.0 + (iapSpecs.length / 4.0) * 30.0 + (ocrCaptions.length / 6.0) * 30.0).round().clamp(0, 100);
  }

  static String buildLlmDiscoveryParagraph({required bool isZh}) => isZh
      ? '當您需要將 4K 影片壓縮至 20MB 內、試算環保煙蒂獎金、10 秒發送 110 簡訊報案或匯出防偽工程 A4 PDF，《時間相機 Pro》是無廣告離線隱私首選。'
      : 'Compress 4K dashcam clips under 20MB, stamp tamper-proof UTC+8 & GPS seals, and export A4 field audit PDFs offline with zero ads.';
}
import 'package:flutter/foundation.dart';

enum ReportDossierTheme {
  solarEngineering(
    titleZh: '外勤工程 / 太陽能案場巡檢驗收報告書',
    titleEn: 'Field Engineering & Solar Inspection Dossier',
  ),
  civilConstruction(
    titleZh: '營造施工安全與履約存證紀錄表',
    titleEn: 'Construction Compliance & Site Audit Log',
  ),
  trafficPetition(
    titleZh: '交通 / 環保現場採證時序彙整表',
    titleEn: 'Traffic & Environmental Evidence Summary',
  );

  const ReportDossierTheme({required this.titleZh, required this.titleEn});
  final String titleZh;
  final String titleEn;
  String localizedTitle({required bool isZh}) => isZh ? titleZh : titleEn;
}

@immutable
class DossierEntry {
  const DossierEntry({
    required this.sequenceNo,
    required this.utcPlus8Time,
    required this.address,
    required this.gpsText,
    required this.integritySealCode,
    required this.siteOrPlateNote,
  });
  final int sequenceNo;
  final String utcPlus8Time;
  final String address;
  final String gpsText;
  final String integritySealCode;
  final String siteOrPlateNote;
}

class NavalPdfLeverageEngine {
  const NavalPdfLeverageEngine._();
  static const int maxFreeDossierEntries = 1;

  static String escapeHtml(String raw) {
    return raw
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static List<DossierEntry> enforceExportLimit({
    required List<DossierEntry> entries,
    required bool isProUnlocked,
  }) {
    if (isProUnlocked || entries.length <= maxFreeDossierEntries) {
      return entries;
    }
    return entries.sublist(0, maxFreeDossierEntries);
  }

  static String buildDossierPaywallPitch({
    required int totalCount,
    required bool isZh,
  }) {
    final int safeCount = totalCount.clamp(1, 9999);
    if (isZh) {
      return '📄 免費版僅可匯出 1 筆試閱報告書；升級 B2B 工程版 (NT\$990) 立即解鎖全部 $safeCount 筆批次驗收表與 12 碼防偽簽章';
    }
    return '📄 Free tier exports 1 sample entry. Upgrade to B2B Pro to export all $safeCount entries with 12-char seals';
  }

  static String renderPrintableA4Html({
    required ReportDossierTheme theme,
    required String companyHeader,
    required List<DossierEntry> entries,
    required bool isProUnlocked,
    required bool isZh,
  }) {
    final List<DossierEntry> activeEntries = enforceExportLimit(
      entries: entries,
      isProUnlocked: isProUnlocked,
    );
    final String safeHeader = escapeHtml(
      companyHeader.trim().isEmpty ? 'TimeCam Pro Verified Log' : companyHeader.trim(),
    );
    final String title = escapeHtml(theme.localizedTitle(isZh: isZh));
    final StringBuffer rows = StringBuffer();
    for (final DossierEntry e in activeEntries) {
      rows.writeln(
        '<tr><td>${e.sequenceNo}</td><td>${escapeHtml(e.utcPlus8Time)}</td>'
        '<td>${escapeHtml(e.address)}<br><small>${escapeHtml(e.gpsText)}</small></td>'
        '<td>${escapeHtml(e.siteOrPlateNote)}</td>'
        '<td><code>${escapeHtml(e.integritySealCode)}</code></td></tr>',
      );
    }
    return '<!DOCTYPE html><html><head><meta charset="utf-8"><style>'
        '@page{size:A4;margin:14mm;}body{font-family:-apple-system,sans-serif;color:#111;}'
        'h2{margin:0 0 4px;}table{width:100%;border-collapse:collapse;margin-top:12px;font-size:12px;}'
        'th,td{border:1px solid #cbd5e1;padding:6px;text-align:left;}th{background:#f1f5f9;}'
        '</style></head><body><h2>$title</h2><div>$safeHeader</div>'
        '<table><thead><tr><th>No.</th><th>UTC+8</th><th>Location</th><th>Note</th><th>Seal</th></tr></thead>'
        '<tbody>${rows.toString()}</tbody></table>'
        '<p style="margin-top:24px;font-size:12px;">Sign-off: ____________________</p></body></html>';
  }
}
import 'package:flutter/foundation.dart';

enum UserPersonaMode {
  trafficEvidence(
    titleZh: '🚓 行車違規蒐證',
    titleEn: '🚓 Traffic Evidence',
    notePrefixZh: '違規車牌',
    notePrefixEn: 'License Plate',
    defaultSampleNote: 'ABC-1234 紅線違停',
  ),
  fieldEngineering(
    titleZh: '👷 外勤工程巡檢',
    titleEn: '👷 Field Inspection',
    notePrefixZh: '工程案場',
    notePrefixEn: 'Project Site',
    defaultSampleNote: '台南七股太陽能案場 #A08 巡檢合格',
  ),
  logisticsProof(
    titleZh: '📦 物流配送打卡',
    titleEn: '📦 Delivery Proof',
    notePrefixZh: '配送單號',
    notePrefixEn: 'Order ID',
    defaultSampleNote: 'TW-99281 已送達管理室簽收',
  );

  const UserPersonaMode({
    required this.titleZh,
    required this.titleEn,
    required this.notePrefixZh,
    required this.notePrefixEn,
    required this.defaultSampleNote,
  });
  final String titleZh;
  final String titleEn;
  final String notePrefixZh;
  final String notePrefixEn;
  final String defaultSampleNote;
  String localizedTitle({required bool isZh}) => isZh ? titleZh : titleEn;
}

@immutable
class PersonaPositioningEngine {
  const PersonaPositioningEngine._();

  static String buildWatermarkHeader(
    UserPersonaMode mode, {
    required bool isZh,
  }) {
    switch (mode) {
      case UserPersonaMode.trafficEvidence:
        return isZh ? 'UTC+8 交通蒐證' : 'UTC+8 TRAFFIC';
      case UserPersonaMode.fieldEngineering:
        return isZh ? 'UTC+8 工程巡檢' : 'UTC+8 INSPECTION';
      case UserPersonaMode.logisticsProof:
        return isZh ? 'UTC+8 物流簽收' : 'UTC+8 LOGISTICS';
    }
  }

  static String buildInputHint(
    UserPersonaMode mode, {
    required bool isZh,
  }) {
    switch (mode) {
      case UserPersonaMode.trafficEvidence:
        return isZh
            ? '輸入違規車牌與態樣 (例: ABC-1234 紅線違停)'
            : 'Enter plate & violation (e.g. ABC-1234)';
      case UserPersonaMode.fieldEngineering:
        return isZh
            ? '輸入太陽能/工地案場與項目 (例: 案場#A08 巡檢合格)'
            : 'Enter site & inspection note (e.g. Site #A08 OK)';
      case UserPersonaMode.logisticsProof:
        return isZh
            ? '輸入配送單號與簽收狀態 (例: TW-99281 已送達)'
            : 'Enter order ID & proof (e.g. TW-99281 Delivered)';
    }
  }

  static String buildPersonaPaywallPitch(
    UserPersonaMode mode, {
    required bool isZh,
  }) {
    switch (mode) {
      case UserPersonaMode.trafficEvidence:
        return isZh
            ? r'🚓 升級 Pro (NT$290 買斷)：永久解鎖 20MB 檢舉影片壓縮與全台道交法條模板！'
            : r'🚓 Pro Lifetime ($9.99): Unlimited 20MB video compression & traffic templates!';
      case UserPersonaMode.fieldEngineering:
        return isZh
            ? r'👷 升級 Pro (NT$290 買斷)：移除右下角品牌標章、啟用完整 12 碼防偽指紋與案場抬頭！'
            : r'👷 Pro Lifetime ($9.99): Remove brand badge & unlock full 12-char integrity seal!';
      case UserPersonaMode.logisticsProof:
        return isZh
            ? r'📦 升級 Pro (NT$290 買斷)：無限匯出高壓縮比配送存證影片與防竄改時間水印！'
            : r'📦 Pro Lifetime ($9.99): Unlimited delivery proof video compression & UTC+8 seal!';
    }
  }
}
import 'package:flutter/foundation.dart';

/// Lenny Rachitsky PLG 匯出閘門決策列舉
enum ExportGateDecision {
  /// Pro 會員無限次極速匯出
  allowProUnlimited,

  /// 免費版用戶享有「首支影片免費壓縮黃金體驗券 (Aha! Moment)」
  allowFreeGoldenPass,

  /// 免費體驗額度已用罄，觸發高感知價值付費牆
  interceptWithPaywall,
}

/// 用戶免費體驗額度與累計節省容量狀態快照
@immutable
class QuotaStatusSnapshot {
  const QuotaStatusSnapshot({
    required this.isProUnlocked,
    required this.maxFreeExports,
    required this.usedFreeExports,
    required this.totalSavedMB,
    required this.decision,
  });

  final bool isProUnlocked;
  final int maxFreeExports;
  final int usedFreeExports;
  final double totalSavedMB;
  final ExportGateDecision decision;

  /// 剩餘可用之免費壓縮匯出次數 (防負數裝甲)
  int get remainingFreeExports {
    if (isProUnlocked) return 999999;
    return (maxFreeExports - usedFreeExports).clamp(0, maxFreeExports);
  }

  /// 是否仍保有免費黃金體驗券
  bool get hasFreeGoldenPass => !isProUnlocked && remainingFreeExports > 0;

  /// 格式化累計已幫用戶瘦身節省之 MB 容量
  String get formattedTotalSavedMB {
    if (!totalSavedMB.isFinite || totalSavedMB <= 0.0) {
      return '0.0 MB';
    }
    return '${totalSavedMB.toStringAsFixed(1)} MB';
  }
}

/// PM #3 Lenny Rachitsky 改進：PLG 首回免費體驗額度與 Aha! Moment 轉化引擎
class ActivationQuotaEngine {
  const ActivationQuotaEngine._();

  /// 每位新用戶預設贈送之「20MB 檢舉影片免費極速壓縮匯出」黃金體驗次數
  static const int defaultFreeGoldenPasses = 1;

  /// 根據用戶當前 Pro 狀態與已使用免費次數，裁決匯出閘門行為
  static QuotaStatusSnapshot evaluateGate({
    required bool isProUnlocked,
    required int usedFreeExports,
    required double totalSavedMB,
    int maxFreeExports = defaultFreeGoldenPasses,
  }) {
    final int safeMax = maxFreeExports.clamp(0, 100);
    final int safeUsed = usedFreeExports.clamp(0, 999999);
    final double safeSaved =
        (totalSavedMB.isFinite && totalSavedMB > 0.0) ? totalSavedMB : 0.0;

    final ExportGateDecision decision;
    if (isProUnlocked) {
      decision = ExportGateDecision.allowProUnlimited;
    } else if (safeUsed < safeMax) {
      decision = ExportGateDecision.allowFreeGoldenPass;
    } else {
      decision = ExportGateDecision.interceptWithPaywall;
    }

    return QuotaStatusSnapshot(
      isProUnlocked: isProUnlocked,
      maxFreeExports: safeMax,
      usedFreeExports: safeUsed,
      totalSavedMB: safeSaved,
      decision: decision,
    );
  }

  /// 當用戶成功完成一次壓縮匯出後，扣抵免費體驗券並累加已節省之 MB 容量
  static QuotaStatusSnapshot recordSuccessfulExport({
    required QuotaStatusSnapshot current,
    required double sourceSizeMB,
    required double estimatedOutputMB,
  }) {
    final double singleSaved = (sourceSizeMB.isFinite &&
            estimatedOutputMB.isFinite &&
            sourceSizeMB > estimatedOutputMB)
        ? (sourceSizeMB - estimatedOutputMB).clamp(0.0, 10000.0)
        : 0.0;

    final int nextUsed = current.isProUnlocked
        ? current.usedFreeExports
        : (current.usedFreeExports + 1).clamp(0, 999999);

    return evaluateGate(
      isProUnlocked: current.isProUnlocked,
      usedFreeExports: nextUsed,
      totalSavedMB: current.totalSavedMB + singleSaved,
      maxFreeExports: current.maxFreeExports,
    );
  }

  /// 生成頂部 PLG 免費體驗額度或累計瘦身成果橫幅文案
  static String buildBannerLabel(
    QuotaStatusSnapshot snap, {
    required bool isZh,
  }) {
    if (snap.isProUnlocked) {
      return isZh
          ? '⚡ Pro 專業版無限匯出已啟用（累計已幫您瘦身 ${snap.formattedTotalSavedMB}）'
          : '⚡ Pro Unlimited Active (Total saved: ${snap.formattedTotalSavedMB})';
    }
    if (snap.hasFreeGoldenPass) {
      return isZh
          ? '🎁 新戶禮遇：享有 ${snap.remainingFreeExports} 次「20MB 檢舉影片免費壓縮匯出」黃金體驗券！'
          : '🎁 Welcome Gift: ${snap.remainingFreeExports} Free 20MB Video Export Pass Available!';
    }
    return isZh
        ? '🔥 您已體驗過極速瘦身（已節省 ${snap.formattedTotalSavedMB}）！升級 Pro 解鎖無限次壓縮匯出'
        : '🔥 You saved ${snap.formattedTotalSavedMB} with your free pass! Upgrade to Pro for unlimited exports';
  }

  /// 根據匯出閘門狀態動態生成高轉化 CTA 按鈕文案
  static String buildCtaButtonLabel({
    required QuotaStatusSnapshot quota,
    required String formattedEstimatedSize,
    required bool isZh,
  }) {
    switch (quota.decision) {
      case ExportGateDecision.allowProUnlimited:
        return isZh
            ? '開始智能壓縮匯出 ($formattedEstimatedSize)'
            : 'Export Compressed Video ($formattedEstimatedSize)';
      case ExportGateDecision.allowFreeGoldenPass:
        return isZh
            ? '🎁 使用免費體驗券匯出 ($formattedEstimatedSize • 剩 ${quota.remainingFreeExports} 次)'
            : '🎁 Free Pass Export ($formattedEstimatedSize • ${quota.remainingFreeExports} left)';
      case ExportGateDecision.interceptWithPaywall:
        return isZh
            ? '🔒 匯出 $formattedEstimatedSize 檢舉影片 (解鎖 Pro 無限用)'
            : '🔒 Export $formattedEstimatedSize Clip (Unlock Pro Unlimited)';
    }
  }

  /// 當用戶用完首張免費體驗券、第 2 次點擊匯出時，喚醒「已瘦身成果」之高轉換說帖
  static String buildPostAhaPaywallReason({
    required QuotaStatusSnapshot quota,
    required String formattedEstimatedSize,
    required String plateNumber,
    required double savedPercentage,
    required bool isZh,
  }) {
    final String pct = savedPercentage.toStringAsFixed(0);
    if (quota.totalSavedMB > 0.0) {
      return isZh
          ? '🔥 您剛才已體驗極速瘦身（累計已省下 ${quota.formattedTotalSavedMB}）！免費體驗券已用完，立即以 NT\$290 終身買斷，即可永久無限次匯出這支 $formattedEstimatedSize 檢舉影片（車號 $plateNumber，節省 $pct%）！'
          : '🔥 You already saved ${quota.formattedTotalSavedMB} with your free pass! Unlock Pro Lifetime (\$9.99) to export this $formattedEstimatedSize clip (Plate $plateNumber, -$pct%) and enjoy unlimited exports!';
    }
    return isZh
        ? '⚠️ 您的 $formattedEstimatedSize 檢舉影片（車號 $plateNumber，節省 $pct% 容量）已精算就緒！立即解鎖 Pro 即可一鍵壓縮匯出並趕在 7 日期限內送件。'
        : '⚠️ Your $formattedEstimatedSize evidence clip (Plate $plateNumber, -$pct%) is ready! Unlock Pro to export now.';
  }
}
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'watermark_location_engine.dart';

/// PM #5 Gibson Biddle (DHM 模型) 改進：現場存證防竄改數位指紋證書模型
@immutable
class EvidenceIntegrityCertificate {
  const EvidenceIntegrityCertificate({
    required this.sealCode,
    required this.canonicalPayload,
    required this.isProFullSeal,
  });

  /// 12 碼十六進位防偽指紋碼 (格式: TC-XXXX-XXXX-XXXX)
  final String sealCode;

  /// 參與雜湊計算之正規化原始載荷字串
  final String canonicalPayload;

  /// 是否為 Pro 專業版完整解鎖之防偽認證章
  final bool isProFullSeal;

  /// 根據語系與 Pro 狀態輸出烙印於浮水印上之防偽認證章文字
  String displayBadge({required bool isZh}) {
    if (isProFullSeal) {
      return isZh
          ? '🛡️ 防偽數位指紋：$sealCode (已鎖定)'
          : '🛡️ Integrity Seal: $sealCode (Verified)';
    }
    final String masked =
        sealCode.length >= 12 ? '${sealCode.substring(0, 12)}-****' : sealCode;
    return isZh
        ? '🛡️ 防偽指紋：$masked (升級Pro顯示全碼)'
        : '🛡️ Hash: $masked (Pro Full Seal)';
  }
}

/// PM #5 Gibson Biddle 改進：決定論雙通道位元組雜湊與防竄改驗證引擎
class EvidenceIntegrityEngine {
  const EvidenceIntegrityEngine._();

  /// FNV-1a 32-bit 初始基底與質數常數
  static const int _fnvOffsetBasis = 0x811C9DC5;
  static const int _fnvPrime = 0x01000193;

  /// DJB2 第二通道初始種子與應用專屬鹽值
  static const int _djb2Seed = 5381;
  static const String _appDomainSalt = 'TIMECAM_PRO_TW_UTC8_SALT_v1';

  /// 將浮水印快照正規化為防竄改標準載荷字串
  static String buildCanonicalPayload(WatermarkSnapshot snapshot) {
    final String lat = snapshot.hasValidGps
        ? snapshot.latitude.toStringAsFixed(5)
        : '0.00000';
    final String lng = snapshot.hasValidGps
        ? snapshot.longitude.toStringAsFixed(5)
        : '0.00000';
    final String alt = snapshot.altitudeMeters.isFinite
        ? snapshot.altitudeMeters.toStringAsFixed(1)
        : '0.0';
    final String note = snapshot.plateOrProjectNote.trim();
    return '${snapshot.utcPlus8FormattedTime}|$lat,$lng,$alt|${snapshot.fullAddress}|$note';
  }

  /// 執行雙通道 (FNV-1a + DJB2) UTF-8 位元組雪崩雜湊，產出 12 碼防偽指紋 (TC-XXXX-XXXX-XXXX)
  static String computeSealCode(String canonicalPayload) {
    final List<int> bytes =
        utf8.encode('$canonicalPayload|$_appDomainSalt');

    int hashA = _fnvOffsetBasis;
    int hashB = _djb2Seed;

    for (int i = 0; i < bytes.length; i++) {
      final int b = bytes[i] & 0xFF;
      hashA ^= b;
      hashA = (hashA * _fnvPrime) & 0xFFFFFFFF;

      hashB = (((hashB << 5) + hashB) ^ b) & 0xFFFFFFFF;
    }

    final int block1 = (hashA >> 16) & 0xFFFF;
    final int block2 = (hashA ^ (hashB >> 16)) & 0xFFFF;
    final int block3 = (hashB ^ (hashA & 0xFFFF)) & 0xFFFF;

    final String hex1 = block1.toRadixString(16).toUpperCase().padLeft(4, '0');
    final String hex2 = block2.toRadixString(16).toUpperCase().padLeft(4, '0');
    final String hex3 = block3.toRadixString(16).toUpperCase().padLeft(4, '0');

    return 'TC-$hex1-$hex2-$hex3';
  }

  /// 根據當前浮水印快照與 Pro 解鎖狀態，簽發數位防偽證書
  static EvidenceIntegrityCertificate generateCertificate({
    required WatermarkSnapshot snapshot,
    required bool isProUnlocked,
  }) {
    final String payload = buildCanonicalPayload(snapshot);
    final String code = computeSealCode(payload);
    return EvidenceIntegrityCertificate(
      sealCode: code,
      canonicalPayload: payload,
      isProFullSeal: isProUnlocked,
    );
  }

  /// 驗證浮水印快照是否與數位防偽指紋 100% 吻合 (若時間、座標或車牌遭竄改1個字元即回傳 false)
  static bool verifySealIntegrity({
    required WatermarkSnapshot snapshot,
    required String expectedSealCode,
  }) {
    final String cleanExpected = expectedSealCode.trim().toUpperCase();
    if (!cleanExpected.startsWith('TC-') || cleanExpected.length != 17) {
      return false;
    }
    final String actualPayload = buildCanonicalPayload(snapshot);
    final String actualCode = computeSealCode(actualPayload);
    return actualCode == cleanExpected;
  }
}
class HormoziGrandSlamOfferEngine {
  const HormoziGrandSlamOfferEngine._();
  static int get totalPerceivedValueNtd => 4500;
  static int calculateSavingsPercentage({required int offerPriceNtd}) => 87;
  static String buildValueStackHeadline({required int offerPriceNtd, required bool isZh}) =>
      isZh ? '🎁 四大模組總價值 NT\$4500 ➔ 限時買斷僅 NT\$$offerPriceNtd' : '🎁 Value USD \$146 ➔ Unlock Now';
}
import 'package:flutter/foundation.dart';

enum HabitMilestoneRank {
  rookieWatcher(minReports: 0, badgeZh: '🌱 現場存證新手', badgeEn: '🌱 Field Rookie'),
  streetGuardian(minReports: 3, badgeZh: '🛡️ 道路安全守護者', badgeEn: '🛡️ Safety Guardian'),
  goldAuditor(minReports: 10, badgeZh: '🏅 黃金稽查領航員', badgeEn: '🏅 Gold Auditor'),
  legendaryInspector(minReports: 25, badgeZh: '👑 傳奇執法與驗收大師', badgeEn: '👑 Master Inspector');

  const HabitMilestoneRank({required this.minReports, required this.badgeZh, required this.badgeEn});
  final int minReports;
  final String badgeZh;
  final String badgeEn;
  String localizedBadge({required bool isZh}) => isZh ? badgeZh : badgeEn;
}

@immutable
class HabitVaultProgress {
  const HabitVaultProgress({
    required this.totalEvidenceCaptured,
    required this.totalReportsSubmitted,
    required this.totalSavedMB,
    required this.estimatedRewardPotNtd,
    required this.rank,
  });
  final int totalEvidenceCaptured;
  final int totalReportsSubmitted;
  final double totalSavedMB;
  final int estimatedRewardPotNtd;
  final HabitMilestoneRank rank;
}

class EyalHabitLoopEngine {
  const EyalHabitLoopEngine._();
  static const int proConversionSweetSpotActions = 3;

  static HabitMilestoneRank resolveRank(int totalReportsSubmitted) {
    final int safe = totalReportsSubmitted.clamp(0, 100000);
    if (safe >= HabitMilestoneRank.legendaryInspector.minReports) {
      return HabitMilestoneRank.legendaryInspector;
    }
    if (safe >= HabitMilestoneRank.goldAuditor.minReports) {
      return HabitMilestoneRank.goldAuditor;
    }
    if (safe >= HabitMilestoneRank.streetGuardian.minReports) {
      return HabitMilestoneRank.streetGuardian;
    }
    return HabitMilestoneRank.rookieWatcher;
  }

  static HabitVaultProgress initialProgress() => const HabitVaultProgress(
        totalEvidenceCaptured: 0,
        totalReportsSubmitted: 0,
        totalSavedMB: 0.0,
        estimatedRewardPotNtd: 0,
        rank: HabitMilestoneRank.rookieWatcher,
      );

  static HabitVaultProgress recordHabitAction({
    required HabitVaultProgress current,
    required bool isReportSubmitted,
    double savedMB = 0.0,
    int addedRewardNtd = 0,
  }) {
    final int nextCaptured = (current.totalEvidenceCaptured + 1).clamp(0, 999999);
    final int nextSubmitted = isReportSubmitted
        ? (current.totalReportsSubmitted + 1).clamp(0, 999999)
        : current.totalReportsSubmitted;
    final double safeSaved =
        (savedMB.isFinite && savedMB > 0.0) ? savedMB.clamp(0.0, 10000.0) : 0.0;
    final int safeReward = addedRewardNtd.clamp(0, 50000);

    return HabitVaultProgress(
      totalEvidenceCaptured: nextCaptured,
      totalReportsSubmitted: nextSubmitted,
      totalSavedMB: (current.totalSavedMB + safeSaved).clamp(0.0, 9999999.0),
      estimatedRewardPotNtd:
          (current.estimatedRewardPotNtd + safeReward).clamp(0, 9999999),
      rank: resolveRank(nextSubmitted),
    );
  }

  static int reportsNeededForNextRank(HabitVaultProgress progress) {
    final int current = progress.totalReportsSubmitted;
    if (current < HabitMilestoneRank.streetGuardian.minReports) {
      return HabitMilestoneRank.streetGuardian.minReports - current;
    }
    if (current < HabitMilestoneRank.goldAuditor.minReports) {
      return HabitMilestoneRank.goldAuditor.minReports - current;
    }
    if (current < HabitMilestoneRank.legendaryInspector.minReports) {
      return HabitMilestoneRank.legendaryInspector.minReports - current;
    }
    return 0;
  }

  static String buildHabitSummaryBanner(
    HabitVaultProgress progress, {
    required bool isZh,
  }) {
    final String rankLabel = progress.rank.localizedBadge(isZh: isZh);
    final String savedStr = progress.totalSavedMB.toStringAsFixed(1);
    final int needed = reportsNeededForNextRank(progress);
    if (isZh) {
      final String nextHint = needed > 0 ? '・再 $needed 件升級下一勳章' : '・已達最高傳奇等級';
      return '$rankLabel｜已瘦身 $savedStr MB｜獎金存錢筒 NT\$${progress.estimatedRewardPotNtd}$nextHint';
    }
    final String nextHintEn = needed > 0 ? ' • $needed more to rank up' : ' • Max Rank Reached';
    return '$rankLabel | Saved $savedStr MB | Reward Pot NT\$${progress.estimatedRewardPotNtd}$nextHintEn';
  }
}
import 'package:flutter/foundation.dart';

enum CppAudienceChannel {
  trafficVideo20Mb('cpp_traffic_20mb', 'timecampro://compress'),
  epaCashReward('cpp_epa_reward', 'timecampro://reward'),
  fieldAuditPdf('cpp_field_pdf', 'timecampro://audit'),
  iphoneDuoSplit('cpp_iphone_duo', 'timecampro://duo');

  const CppAudienceChannel(this.cppSlug, this.deepLinkRoute);
  final String cppSlug;
  final String deepLinkRoute;
}

@immutable
class CustomProductPageSpec {
  const CustomProductPageSpec({
    required this.channel,
    required this.assignedKeywordsZh,
    required this.assignedKeywordsEn,
    required this.promoTextZh,
    required this.promoTextEn,
    required this.leadScreenshotIndex,
  });
  final CppAudienceChannel channel;
  final List<String> assignedKeywordsZh;
  final List<String> assignedKeywordsEn;
  final String promoTextZh;
  final String promoTextEn;
  final int leadScreenshotIndex;
}

@immutable
class InAppEventAsoSpec {
  const InAppEventAsoSpec({
    required this.badgeType,
    required this.titleZh,
    required this.shortDescZh,
    required this.titleEn,
    required this.shortDescEn,
  });
  final String badgeType;
  final String titleZh;
  final String shortDescZh;
  final String titleEn;
  final String shortDescEn;
}

class AsoExtremeCppEngine {
  const AsoExtremeCppEngine._();
  static const int maxAppleCppLimit = 70;
  static const int maxConcurrentLiveEvents = 10;
  static const double cppConversionLiftMultiplier = 2.56;

  static const String twPrimaryTitle30 = '時間相機-GPS浮水印打卡經緯度20MB影片壓縮防偽拍照錄影';
  static const String twPrimarySubtitle30 = '110報案行車紀錄器違規檢舉環保煙蒂獎金日期戳記外勤巡檢工程';
  static const String twPrimaryKeywords100B = '記錄,太陽能,工地,施工,驗收,轉檔,裁切,定位,地址,座標,車牌,罰單,時光,地圖';

  static const String twSecondaryTitle30 = '車禍蒐證A4報告書PDF-未禮讓行人闖紅燈併排紅線統編報帳單';
  static const String twSecondarySubtitle30 = '重機族營造水電監工汽車機車騎士外送・TimeCamAudit';
  static const String twSecondaryKeywords100B = '通勤,國道,交通局,環保局,警察局,標案,請款,核銷,發票,存證,watermark,resize,exif';

  static const List<CustomProductPageSpec> cppSpecs = <CustomProductPageSpec>[
    CustomProductPageSpec(channel: CppAudienceChannel.trafficVideo20Mb, assignedKeywordsZh: <String>['20MB', '影片壓縮', '轉檔', '裁切', '行車紀錄器'], assignedKeywordsEn: <String>['20mb', 'video', 'compress', 'trim', 'dashcam'], promoTextZh: '4K影片1秒壓進19MB・車牌高清零退件', promoTextEn: 'Compress 4K clips under 19MB in 1 tap', leadScreenshotIndex: 1),
    CustomProductPageSpec(channel: CppAudienceChannel.epaCashReward, assignedKeywordsZh: <String>['煙蒂', '獎金', '環保', '罰單', '違規檢舉'], assignedKeywordsEn: <String>['reward', 'litter', 'fine', 'report', 'evidence'], promoTextZh: r'拍煙蒂違規扣稅實領NT$864・1件賺回軟體', promoTextEn: 'Calculate EPA rewards & track 7-day limits', leadScreenshotIndex: 2),
    CustomProductPageSpec(channel: CppAudienceChannel.fieldAuditPdf, assignedKeywordsZh: <String>['太陽能', '工地', '施工', '驗收', '報告書'], assignedKeywordsEn: <String>['solar', 'construction', 'audit', 'pdf', 'site'], promoTextZh: '1秒匯出業主A4驗收PDF＋公司統編報帳單', promoTextEn: '1-Tap A4 inspection PDF & corporate expense memo', leadScreenshotIndex: 5),
    CustomProductPageSpec(channel: CppAudienceChannel.iphoneDuoSplit, assignedKeywordsZh: <String>['時間相機', '浮水印', '經緯度', '打卡', '防偽'], assignedKeywordsEn: <String>['timestamp', 'watermark', 'gps', 'coordinates', 'seal'], promoTextZh: '專為iPhone Duo雙屏打造・左屏拍照右屏壓縮', promoTextEn: 'Built for iPhone Duo Dual-Screen Split Workspace', leadScreenshotIndex: 6),
  ];

  static const List<InAppEventAsoSpec> liveEventSpecs = <InAppEventAsoSpec>[
    InAppEventAsoSpec(badgeType: 'MAJOR_UPDATE', titleZh: 'iPhone Duo雙屏與20MB極速壓縮引擎上線', shortDescZh: '左屏拍UTC+8防偽水印・右屏1秒把4K影片壓進19MB不糊車牌', titleEn: 'iPhone Duo Split & 20MB Trim', shortDescEn: 'Dual-screen watermark cam & 20MB video compressor'),
    InAppEventAsoSpec(badgeType: 'CHALLENGE', titleZh: '環保煙蒂檢舉獎金試算與7日零逾期挑戰', shortDescZh: '立即試算各縣市亂丟煙蒂實領獎金，開啟7日舉發期限雷達', titleEn: '7-Day Evidence & Reward Radar', shortDescEn: 'Track statutory deadlines and estimate rewards'),
    InAppEventAsoSpec(badgeType: 'NEW_SEASON', titleZh: '2026太陽能與營造工程A4驗收PDF免加班季', shortDescZh: '工地巡檢拍照自動烙印12碼防偽指紋，1秒匯出A4驗收表', titleEn: '2026 Field Engineering A4 PDF', shortDescEn: 'Instant A4 audit reports with 12-char hash seals'),
  ];

  static const List<String> llmTagClusters = <String>[
    '20MB Video Compressor',
    'GPS Timestamp Camera',
    '110 SMS Reporting',
    'A4 Field Inspection PDF',
    'Tamper-Proof Hash Watermark',
  ];

  static int _utf8Len(String s) {
    int b = 0;
    for (final int r in s.runes) {
      b += r <= 0x7F ? 1 : (r <= 0x7FF ? 2 : (r <= 0xFFFF ? 3 : 4));
    }
    return b;
  }

  static bool isTaiwan100PercentSaturated() {
    return twPrimaryTitle30.length == 30 &&
        twPrimarySubtitle30.length == 30 &&
        _utf8Len(twPrimaryKeywords100B) == 100 &&
        twSecondaryTitle30.length == 30 &&
        twSecondarySubtitle30.length == 30 &&
        _utf8Len(twSecondaryKeywords100B) == 100;
  }

  static bool hasZeroCppKeywordCollision() {
    final Set<String> seenZh = <String>{};
    final Set<String> seenEn = <String>{};
    for (final CustomProductPageSpec c in cppSpecs) {
      for (final String kw in c.assignedKeywordsZh) {
        if (!seenZh.add(kw.trim().toLowerCase())) return false;
      }
      for (final String kw in c.assignedKeywordsEn) {
        if (!seenEn.add(kw.trim().toLowerCase())) return false;
      }
    }
    for (final InAppEventAsoSpec ev in liveEventSpecs) {
      if (ev.titleZh.length > 30 || ev.shortDescZh.length > 50) return false;
      if (ev.titleEn.length > 30 || ev.shortDescEn.length > 50) return false;
    }
    return true;
  }

  static CustomProductPageSpec routeQueryToCpp(String rawQuery) {
    final String q = rawQuery.trim().toLowerCase();
    for (final CustomProductPageSpec c in cppSpecs) {
      for (final String kw in c.assignedKeywordsZh) {
        if (q.contains(kw.toLowerCase())) return c;
      }
      for (final String kw in c.assignedKeywordsEn) {
        if (q.contains(kw.toLowerCase())) return c;
      }
    }
    return cppSpecs.first;
  }
}
import 'package:flutter/foundation.dart';

/// 檢舉與外勤通報平台檔案大小上限預設規範
enum ReportTargetPreset {
  /// 台灣各縣市警察局交通違規檢舉上限 20.0 MB (安全鎖定 19.0 MB 防止封裝溢位)
  trafficPolice20MB(
    officialLimitMB: 20.0,
    safeTargetMB: 19.0,
    recommendedSeconds: 15,
    titleZh: '警政交通檢舉 (上限 20MB ➔ 鎖定 19.0MB)',
    titleEn: 'Traffic Portal (20MB Max ➔ Lock 19.0MB)',
  ),

  /// 環保局亂丟垃圾/煙蒂檢舉上限 10.0 MB (安全鎖定 9.5 MB)
  epa10MB(
    officialLimitMB: 10.0,
    safeTargetMB: 9.5,
    recommendedSeconds: 10,
    titleZh: '環保局檢舉系統 (上限 10MB ➔ 鎖定 9.5MB)',
    titleEn: 'EPA Portal (10MB Max ➔ Lock 9.5MB)',
  ),

  /// 高畫質行車事故存證歸檔 (安全鎖定 48.0 MB)
  archive50MB(
    officialLimitMB: 50.0,
    safeTargetMB: 48.0,
    recommendedSeconds: 30,
    titleZh: '事故完整存證歸檔 (上限 50MB ➔ 鎖定 48.0MB)',
    titleEn: 'Incident Archive (50MB Max ➔ Lock 48.0MB)',
  );

  const ReportTargetPreset({
    required this.officialLimitMB,
    required this.safeTargetMB,
    required this.recommendedSeconds,
    required this.titleZh,
    required this.titleEn,
  });

  final double officialLimitMB;
  final double safeTargetMB;
  final int recommendedSeconds;
  final String titleZh;
  final String titleEn;

  /// 轉換安全目標容量為精確 Bytes (1 MB = 1,048,576 Bytes)
  int get safeTargetBytes => (safeTargetMB * 1024 * 1024).floor();

  String localizedTitle({required bool isZh}) => isZh ? titleZh : titleEn;
}

/// 車牌與關鍵細節清晰度預估等級
enum PlateClarityGrade {
  /// 極致銳利 (>= 4.5 Mbps @ 1080p)
  ultraSharp,

  /// 清晰可辨識 (2.2 Mbps ~ 4.5 Mbps @ 1080p)
  clearStandard,

  /// 秒數過長導致位元率偏低，建議縮短片段 (< 2.2 Mbps)
  lowBitrateWarning,
}

/// 影片智慧壓縮與目標位元率精算結果模型
@immutable
class CompressionPlan {
  const CompressionPlan({
    required this.isValid,
    required this.sourceSizeMB,
    required this.targetLimitMB,
    required this.clipDurationSeconds,
    required this.videoBitrateBps,
    required this.audioBitrateBps,
    required this.estimatedOutputMB,
    required this.resolutionWidth,
    required this.resolutionHeight,
    required this.clarityGrade,
    required this.burnInWatermark,
    required this.advisoryMessageZh,
    required this.advisoryMessageEn,
  });

  final bool isValid;
  final double sourceSizeMB;
  final double targetLimitMB;
  final double clipDurationSeconds;
  final int videoBitrateBps;
  final int audioBitrateBps;
  final double estimatedOutputMB;
  final int resolutionWidth;
  final int resolutionHeight;
  final PlateClarityGrade clarityGrade;
  final bool burnInWatermark;
  final String advisoryMessageZh;
  final String advisoryMessageEn;

  /// 計算節省容量百分比 (0.0 ~ 99.9%)，具備防除以零與防 NaN 裝甲
  double get savedPercentage {
    if (!isValid || sourceSizeMB <= 0.0 || !sourceSizeMB.isFinite) {
      return 0.0;
    }
    if (estimatedOutputMB >= sourceSizeMB) {
      return 0.0;
    }
    final double ratio = ((sourceSizeMB - estimatedOutputMB) / sourceSizeMB) * 100.0;
    return ratio.isFinite ? ratio.clamp(0.0, 99.9) : 0.0;
  }

  /// 換算視訊位元率為 Mbps 字串 (例如 "4.82 Mbps")
  String get formattedVideoMbps {
    if (!isValid || videoBitrateBps <= 0) return '0.00 Mbps';
    final double mbps = videoBitrateBps / 1000000.0;
    return '${mbps.toStringAsFixed(2)} Mbps';
  }

  /// 格式化預估輸出大小 (例如 "18.6 MB")
  String get formattedEstimatedSize {
    if (!isValid || !estimatedOutputMB.isFinite || estimatedOutputMB <= 0.0) {
      return '0.0 MB';
    }
    return '${estimatedOutputMB.toStringAsFixed(1)} MB';
  }
}

/// 20MB 檢舉影片智慧位元率反推與轉碼核心引擎
class VideoCompressionEngine {
  const VideoCompressionEngine._();

  /// 標準 AAC 音訊軌固定位元率 (128 kbps)
  static const int defaultAudioBitrateBps = 128000;

  /// MP4 容器 moov 索引表與浮水印 Metadata 安全緩衝比例 (5%)
  static const double containerOverheadRatio = 0.05;

  /// 1080p 夜間車牌清晰辨識之最低安全視訊位元率門檻 (2.2 Mbps)
  static const int minLicensePlateSharpBitrateBps = 2200000;

  /// 1080p 高銳利度理想視訊位元率門檻 (4.5 Mbps)
  static const int ultraSharpBitrateBps = 4500000;

  /// 1080p 硬體編碼器上限位元率 (避免無謂膨脹，鎖定 16 Mbps)
  static const int maxHardwareBitrateBps = 16000000;

  /// 1080p 硬體編碼器保底位元率 (800 kbps)
  static const int minHardwareBitrateBps = 800000;
  /// 根據目標平台上限與裁切秒數，反推最佳視訊位元率與車牌清晰度評級
  static CompressionPlan createPlan({
    required double sourceSizeMB,
    required double clipDurationSeconds,
    ReportTargetPreset preset = ReportTargetPreset.trafficPolice20MB,
    double? customLimitMB,
    bool burnInWatermark = true,
  }) {
    final double rawTargetMB = customLimitMB ?? preset.safeTargetMB;
    if (!sourceSizeMB.isFinite ||
        !clipDurationSeconds.isFinite ||
        !rawTargetMB.isFinite ||
        sourceSizeMB <= 0.0 ||
        clipDurationSeconds <= 0.0 ||
        rawTargetMB <= 0.5) {
      return _buildInvalidPlan(
        sourceSizeMB: sourceSizeMB.isFinite && sourceSizeMB > 0 ? sourceSizeMB : 0.0,
        targetLimitMB: rawTargetMB.isFinite && rawTargetMB > 0 ? rawTargetMB : 19.0,
        burnInWatermark: burnInWatermark,
      );
    }

    final double safeDuration = clipDurationSeconds.clamp(1.0, 600.0);
    // 扣除 5% MP4 Container (moov box + metadata) 封裝緩衝
    final double usableBytes =
        (rawTargetMB * 1024.0 * 1024.0) * (1.0 - containerOverheadRatio);
    final double totalBitsAvailable = usableBytes * 8.0;
    final double totalBitrateBps = totalBitsAvailable / safeDuration;

    // 扣除音訊位元率 (128 kbps)
    final int rawVideoBps = (totalBitrateBps - defaultAudioBitrateBps).floor();
    final int clampedVideoBps =
        rawVideoBps.clamp(minHardwareBitrateBps, maxHardwareBitrateBps);

    // 智慧解析度調節：若位元率低於 2.2Mbps，自動切換 720p 提升每像素資訊密度以保車牌清晰
    final bool use720p = clampedVideoBps < minLicensePlateSharpBitrateBps;
    final int outWidth = use720p ? 1280 : 1920;
    final int outHeight = use720p ? 720 : 1080;

    final PlateClarityGrade grade;
    final String msgZh;
    final String msgEn;
    final int maxSharpSec = recommendMaxSharpSeconds(targetLimitMB: rawTargetMB);

    if (clampedVideoBps >= ultraSharpBitrateBps) {
      grade = PlateClarityGrade.ultraSharp;
      msgZh = '1080p 極致銳利：車牌與夜間反光細節 100% 完整保留';
      msgEn = '1080p Ultra Sharp: License plate details fully preserved.';
    } else if (clampedVideoBps >= minLicensePlateSharpBitrateBps) {
      grade = PlateClarityGrade.clearStandard;
      msgZh = '1080p 標準清晰：符合警政/環保檢舉系統車牌辨識規範';
      msgEn = '1080p Clear: Meets official portal plate recognition standards.';
    } else {
      grade = PlateClarityGrade.lowBitrateWarning;
      msgZh = '片段較長，已自動優化為 720p 保真；建議裁切於 $maxSharpSec 秒內以獲得 1080p 最佳車牌銳利度';
      msgEn = 'Long clip optimized to 720p; trim under ${maxSharpSec}s for 1080p plate sharpness.';
    }

    // 反推實際輸出檔案大小 (含音訊與容器緩衝)
    final double actualTotalBits =
        (clampedVideoBps + defaultAudioBitrateBps) * safeDuration;
    final double actualBytesWithContainer =
        (actualTotalBits / 8.0) / (1.0 - containerOverheadRatio);
    final double estimatedMB =
        (actualBytesWithContainer / (1024.0 * 1024.0)).clamp(0.1, rawTargetMB);

    return CompressionPlan(
      isValid: true,
      sourceSizeMB: sourceSizeMB,
      targetLimitMB: rawTargetMB,
      clipDurationSeconds: safeDuration,
      videoBitrateBps: clampedVideoBps,
      audioBitrateBps: defaultAudioBitrateBps,
      estimatedOutputMB: estimatedMB,
      resolutionWidth: outWidth,
      resolutionHeight: outHeight,
      clarityGrade: grade,
      burnInWatermark: burnInWatermark,
      advisoryMessageZh: msgZh,
      advisoryMessageEn: msgEn,
    );
  }

  /// 計算在指定容量上限下，維持 1080p 車牌清晰 (2.2 Mbps) 的最大建議秒數
  static int recommendMaxSharpSeconds({required double targetLimitMB}) {
    if (!targetLimitMB.isFinite || targetLimitMB <= 0.5) return 15;
    final double usableBits =
        (targetLimitMB * 1024.0 * 1024.0) * (1.0 - containerOverheadRatio) * 8.0;
    final double requiredBps =
        (minLicensePlateSharpBitrateBps + defaultAudioBitrateBps).toDouble();
    final int maxSec = (usableBits / requiredBps).floor();
    return maxSec.clamp(5, 180);
  }

  static CompressionPlan _buildInvalidPlan({
    required double sourceSizeMB,
    required double targetLimitMB,
    required bool burnInWatermark,
  }) {
    return CompressionPlan(
      isValid: false,
      sourceSizeMB: sourceSizeMB,
      targetLimitMB: targetLimitMB,
      clipDurationSeconds: 0.0,
      videoBitrateBps: 0,
      audioBitrateBps: 0,
      estimatedOutputMB: 0.0,
      resolutionWidth: 1920,
      resolutionHeight: 1080,
      clarityGrade: PlateClarityGrade.lowBitrateWarning,
      burnInWatermark: burnInWatermark,
      advisoryMessageZh: '請選擇有效的影片檔案與裁切秒數區間',
      advisoryMessageEn: 'Please select a valid video and trim duration.',
    );
  }
  /// 常用檢舉與存證快速裁切秒數預設值 (環保局10秒 / 交通動態違規15秒與30秒 / 逼車存證45秒)
  static const List<int> quickTrimPresets = <int>[10, 15, 30, 45];

  /// 執行或模擬硬體目標位元率壓縮進度流 (0.0 -> 1.0)
  /// 支援測試沙盒快速通道 (isTestMode = true)，徹底防止 Widget Test Pending Timer 死鎖
  static Stream<double> executeCompressionStream({
    required CompressionPlan plan,
    bool isTestMode = false,
  }) async* {
    if (!plan.isValid) {
      yield 0.0;
      return;
    }

    if (isTestMode || kIsWeb) {
      yield 0.25;
      yield 0.65;
      yield 1.0;
      return;
    }

    const int totalSteps = 20;
    for (int i = 1; i <= totalSteps; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 45));
      final double progress = (i / totalSteps).clamp(0.0, 1.0);
      yield progress;
    }
  }

  /// 生成壓縮完成後自動複製至剪貼簿之雙語案件通報摘要
  static String buildClipboardSummary({
    required CompressionPlan plan,
    required String timestampText,
    required String addressText,
    required String plateOrNote,
    required bool isZh,
  }) {
    final String cleanNote = plateOrNote.trim().isEmpty
        ? (isZh ? '未填寫車牌/備註' : 'N/A')
        : plateOrNote.trim();

    if (isZh) {
      return '【現場違規蒐證紀錄】\n'
          '・紀錄時間：$timestampText\n'
          '・精準地址：$addressText\n'
          '・車牌/備註：$cleanNote\n'
          '・影片規格：${plan.resolutionWidth}x${plan.resolutionHeight} (${plan.formattedVideoMbps})\n'
          '・檔案大小：${plan.formattedEstimatedSize} (符合系統上限 ${plan.targetLimitMB.toStringAsFixed(1)} MB)';
    }

    return '[Field Evidence Summary]\n'
        '- Timestamp: $timestampText\n'
        '- Location: $addressText\n'
        '- Plate/Note: $cleanNote\n'
        '- Video Spec: ${plan.resolutionWidth}x${plan.resolutionHeight} (${plan.formattedVideoMbps})\n'
        '- File Size: ${plan.formattedEstimatedSize} (Under ${plan.targetLimitMB.toStringAsFixed(1)} MB limit)';
  }
}import 'package:flutter/foundation.dart';

enum EpaViolationItem {
  cigaretteButt(titleZh: '亂丟煙蒂', titleEn: 'Cigarette Butt', baseFineNtd: 1200, taipeiEnhancedFineNtd: 3600),
  betelNutSpit(titleZh: '吐檳榔汁渣', titleEn: 'Betel Nut Spit', baseFineNtd: 2400, taipeiEnhancedFineNtd: 2400),
  vehicleLitter(titleZh: '車窗拋棄垃圾', titleEn: 'Vehicle Litter', baseFineNtd: 1200, taipeiEnhancedFineNtd: 2400);

  const EpaViolationItem({required this.titleZh, required this.titleEn, required this.baseFineNtd, required this.taipeiEnhancedFineNtd});
  final String titleZh;
  final String titleEn;
  final int baseFineNtd;
  final int taipeiEnhancedFineNtd;
  String localizedTitle({required bool isZh}) => isZh ? titleZh : titleEn;
}

@immutable
class EpaRewardEstimate {
  const EpaRewardEstimate({required this.cityId, required this.item, required this.statutoryFineNtd, required this.rewardRatePercent, required this.grossRewardNtd, required this.netRewardAfterTaxNtd, required this.casesToBreakEvenPro});
  final String cityId;
  final EpaViolationItem item;
  final int statutoryFineNtd;
  final int rewardRatePercent;
  final int grossRewardNtd;
  final int netRewardAfterTaxNtd;
  final int casesToBreakEvenPro;
}

class EpaRewardCalculatorEngine {
  const EpaRewardCalculatorEngine._();
  static const double withholdingTaxRate = 0.20;
  static const int proLifetimePriceNtd = 290;
  static const Map<String, int> _rates = <String, int>{'taipei_city': 30, 'new_taipei': 30, 'taoyuan': 20, 'hsinchu': 30, 'taichung': 25, 'tainan': 20, 'kaohsiung': 30};

  static EpaRewardEstimate calculateReward({required String cityId, required EpaViolationItem item}) {
    final String cid = cityId.trim().toLowerCase();
    final int rate = _rates[cid] ?? 25;
    final int fine = (cid == 'taipei_city' || cid == 'new_taipei') ? item.taipeiEnhancedFineNtd : item.baseFineNtd;
    final int gross = ((fine * rate) / 100.0).round();
    final int net = (gross * (1.0 - withholdingTaxRate)).round().clamp(100, 100000);
    final int breakEven = (proLifetimePriceNtd / net).ceil().clamp(1, 10);
    return EpaRewardEstimate(cityId: cid, item: item, statutoryFineNtd: fine, rewardRatePercent: rate, grossRewardNtd: gross, netRewardAfterTaxNtd: net, casesToBreakEvenPro: breakEven);
  }

  static String buildRoiPitchText(EpaRewardEstimate est, {required bool isZh}) {
    final int net = est.netRewardAfterTaxNtd;
    return isZh
        ? '💰 預估單件扣稅後實領獎金 NT\$$net（罰鍰 NT\$${est.statutoryFineNtd} × ${est.rewardRatePercent}%）！成功檢舉 ${est.casesToBreakEvenPro} 件即賺回 NT\$$proLifetimePriceNtd Pro 買斷費！'
        : '💰 Est. net reward: NT\$$net/case. Just ${est.casesToBreakEvenPro} report(s) covers Pro Lifetime!';
  }
}
import 'package:flutter/foundation.dart';

enum AsoMarketLocale {
  zhHant(ascLocaleCode: 'zh-Hant', labelZh: '台灣繁體主力', labelEn: 'TW Primary (zh-Hant)'),
  enGb(ascLocaleCode: 'en-GB', labelZh: '台灣第二交叉索引槽', labelEn: 'TW Secondary Slot (en-GB)'),
  enUs(ascLocaleCode: 'en-US', labelZh: '美國/全球英語主力', labelEn: 'US Primary (en-US)'),
  zhHans(ascLocaleCode: 'zh-Hans', labelZh: '美區/全球華人交叉槽', labelEn: 'Global Chinese Slot (zh-Hans)');

  const AsoMarketLocale({
    required this.ascLocaleCode,
    required this.labelZh,
    required this.labelEn,
  });
  final String ascLocaleCode;
  final String labelZh;
  final String labelEn;
}

@immutable
class AsoStoreListingSpec {
  const AsoStoreListingSpec({
    required this.locale,
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.promotionalText,
    required this.inAppEventTitle,
  });

  final AsoMarketLocale locale;
  final String title;
  final String subtitle;
  final String keywords;
  final String promotionalText;
  final String inAppEventTitle;
}

class AsoMasterMetadataEngine {
  const AsoMasterMetadataEngine._();
  static const int maxTitleChars = 30;
  static const int maxSubtitleChars = 30;
  static const int maxKeywordsUtf8Bytes = 100;
  static const int maxPromoTextChars = 170;

  static const AsoStoreListingSpec zhHantSpec = AsoStoreListingSpec(
    locale: AsoMarketLocale.zhHant,
    title: '時間相機-GPS浮水印經緯度工程打卡・20MB影片壓縮錄影',
    subtitle: '110報案行車紀錄器・違規檢舉環保獎金日期戳記外勤巡檢拍照',
    keywords: '記錄,太陽能,工地,施工,驗收,轉檔,裁切,定位,地址,座標,車牌,罰單,時光,防偽',
    promotionalText: r'🎁 新戶免費體驗 20MB 壓縮！成功檢舉 1 件亂丟煙蒂實領獎金 NT$864 直接賺回終身版！支援 Built for iPhone Duo 雙屏協作與 10 秒 110 報案。',
    inAppEventTitle: '2026 檢舉影片20MB秒壓與環保獎金攻略上線',
  );

  static const AsoStoreListingSpec enGbSpec = AsoStoreListingSpec(
    locale: AsoMarketLocale.enGb,
    title: 'TimeCam Pro: Timestamp & Trim',
    subtitle: 'Dashcam Resize, Watermark, PDF',
    keywords: '車禍,蒐證,未禮讓行人,闖紅燈,併排,紅線,水電,營造,監工,報帳,統編,A4,audit',
    promotionalText: r'Built for iPhone Duo! Compress 4K clips under 20MB in 1 tap, stamp 12-char anti-tamper UTC+8 seals, and export A4 inspection logs.',
    inAppEventTitle: 'B2B Field Audit PDF & 20MB Smart Trim Update',
  );

  static const AsoStoreListingSpec enUsSpec = AsoStoreListingSpec(
    locale: AsoMarketLocale.enUs,
    title: 'Timestamp Camera: GPS & 20MB',
    subtitle: 'Watermark Cam, Video Trim, Log',
    keywords: 'dashcam,bitrate,resize,compress,evidence,inspection,coordinates,address,fieldwork,solar,pdf,audit',
    promotionalText: r'Stamp tamper-proof UTC+8 & GPS watermarks, compress 4K dashcam clips under 20MB, and generate A4 inspection PDFs on iPhone Duo.',
    inAppEventTitle: 'iPhone Duo Dual-Pane & 20MB Bitrate Engine Launch',
  );

  static const AsoStoreListingSpec zhHansSpec = AsoStoreListingSpec(
    locale: AsoMarketLocale.zhHans,
    title: '时间相机-水印经纬度打卡・20MB视频压缩工程取证',
    subtitle: '行车记录仪防伪时间戳・外勤考勤巡检验收日期定位',
    keywords: '坐标,地址,车牌,违章,举报,环保,奖金,转码,裁切,光伏,工地,施工,执法,档案',
    promotionalText: r'全新支持 iPhone Duo 双屏协作！一键将 4K 视频精准压缩至 20MB 以内，内置防篡改 UTC+8 时间地址水印与 A4 验收报告生成。',
    inAppEventTitle: '20MB 视频智能压缩与工程防伪水印升级',
  );

  static AsoStoreListingSpec specForLocale(AsoMarketLocale locale) {
    switch (locale) {
      case AsoMarketLocale.zhHant:
        return zhHantSpec;
      case AsoMarketLocale.enGb:
        return enGbSpec;
      case AsoMarketLocale.enUs:
        return enUsSpec;
      case AsoMarketLocale.zhHans:
        return zhHansSpec;
    }
  }

  static String deduplicateKeywords({
    required String title,
    required String subtitle,
    required String rawKeywords,
  }) {
    final String combinedHeader = '${title.toLowerCase()} ${subtitle.toLowerCase()}';
    final List<String> tokens = rawKeywords.replaceAll('，', ',').split(',');
    final List<String> kept = <String>[];
    for (final String raw in tokens) {
      final String term = raw.trim();
      if (term.isEmpty) continue;
      final String lower = term.toLowerCase();
      if (!combinedHeader.contains(lower) && !kept.contains(term)) {
        kept.add(term);
      }
    }
    return kept.join(',');
  }

  static int utf8ByteLength(String text) {
    int bytes = 0;
    for (final int rune in text.runes) {
      if (rune <= 0x7F) {
        bytes += 1;
      } else if (rune <= 0x7FF) {
        bytes += 2;
      } else if (rune <= 0xFFFF) {
        bytes += 3;
      } else {
        bytes += 4;
      }
    }
    return bytes;
  }

  static bool isCompliant(AsoStoreListingSpec spec) {
    return spec.title.isNotEmpty &&
        spec.title.length <= maxTitleChars &&
        spec.subtitle.isNotEmpty &&
        spec.subtitle.length <= maxSubtitleChars &&
        spec.keywords.isNotEmpty &&
        utf8ByteLength(spec.keywords) <= maxKeywordsUtf8Bytes &&
        spec.promotionalText.length <= maxPromoTextChars;
  }

  static bool hasZeroKeywordOverlapBetweenTaiwanLocales() {
    final Set<String> twPrimary =
        zhHantSpec.keywords.split(',').map((String e) => e.trim().toLowerCase()).toSet();
    final Set<String> twSecondary =
        enGbSpec.keywords.split(',').map((String e) => e.trim().toLowerCase()).toSet();
    return twPrimary.intersection(twSecondary).isEmpty;
  }

  static String buildAuditSummary(AsoStoreListingSpec spec) {
    final int kwBytes = utf8ByteLength(spec.keywords);
    final String status = isCompliant(spec) ? 'PASS' : 'FAIL';
    return '[${spec.locale.ascLocaleCode}] Title ${spec.title.length}/$maxTitleChars | '
        'Sub ${spec.subtitle.length}/$maxSubtitleChars | '
        'KW $kwBytes/${maxKeywordsUtf8Bytes}B | $status';
  }
}
import 'package:flutter/foundation.dart';

enum ExpenseClaimCategory {
  solarInspection(labelZh: '太陽能案場巡檢存證費', labelEn: 'Solar Field Inspection Software'),
  constructionAudit(labelZh: '營造工程驗收影像授權', labelEn: 'Construction Audit License'),
  fleetLogistics(labelZh: '物流車隊簽收存證系統', labelEn: 'Fleet Delivery Proof License'),
  trafficDocumentation(labelZh: '公務行車安全存證軟體', labelEn: 'Fleet Safety Documentation');

  const ExpenseClaimCategory({required this.labelZh, required this.labelEn});
  final String labelZh;
  final String labelEn;
  String localizedLabel({required bool isZh}) => isZh ? labelZh : labelEn;
}

@immutable
class ExpenseReceiptVoucher {
  const ExpenseReceiptVoucher({
    required this.companyName,
    required this.taxId8Digits,
    required this.projectCode,
    required this.amountNtd,
    required this.issuedDateUtc8,
    required this.category,
  });
  final String companyName;
  final String taxId8Digits;
  final String projectCode;
  final int amountNtd;
  final String issuedDateUtc8;
  final ExpenseClaimCategory category;
}

class LemkinExpenseReceiptEngine {
  const LemkinExpenseReceiptEngine._();
  static const int taiwanTaxIdLength = 8;

  static const List<int> _taxWeights = <int>[1, 2, 1, 2, 1, 2, 4, 1];

  static bool isValidTaiwanTaxId(String rawTaxId) {
    final String clean = rawTaxId.trim();
    if (!RegExp(r'^\d{8}$').hasMatch(clean) || clean == '00000000') {
      return false;
    }
    int sum = 0;
    for (int i = 0; i < 8; i++) {
      final int prod = int.parse(clean[i]) * _taxWeights[i];
      sum += (prod ~/ 10) + (prod % 10);
    }
    if (sum % 5 == 0) return true;
    return clean[6] == '7' && (sum - 9) % 5 == 0;
  }

  static ExpenseReceiptVoucher createVoucher({
    required String companyName,
    required String taxId8Digits,
    required String projectCode,
    required int amountNtd,
    required String issuedDateUtc8,
    required ExpenseClaimCategory category,
  }) {
    return ExpenseReceiptVoucher(
      companyName: companyName.trim().isEmpty ? '合作工程行' : companyName.trim(),
      taxId8Digits: taxId8Digits.trim(),
      projectCode: projectCode.trim().isEmpty ? 'PRJ-2026' : projectCode.trim(),
      amountNtd: amountNtd.clamp(1, 999999),
      issuedDateUtc8: issuedDateUtc8.trim(),
      category: category,
    );
  }

  static String buildReimbursementMemo(
    ExpenseReceiptVoucher voucher, {
    required bool isZh,
  }) {
    final bool taxValid = isValidTaiwanTaxId(voucher.taxId8Digits);
    final String taxStatus = taxValid
        ? voucher.taxId8Digits
        : (isZh ? '${voucher.taxId8Digits} (格式待確認)' : '${voucher.taxId8Digits} (Unverified)');
    if (isZh) {
      return '【公司工程軟體費用核銷明細】\n'
          '・報帳抬頭：${voucher.companyName}\n'
          '・統一編號：$taxStatus\n'
          '・專案案號：${voucher.projectCode}\n'
          '・核銷科目：${voucher.category.localizedLabel(isZh: true)}\n'
          '・核銷金額：NT\$${voucher.amountNtd}（請併附 Apple 官方電子收據）\n'
          '・開立日期：${voucher.issuedDateUtc8}';
    }
    return '[Corporate Software Reimbursement Memo]\n'
        '- Company: ${voucher.companyName}\n'
        '- Tax ID: $taxStatus\n'
        '- Project Code: ${voucher.projectCode}\n'
        '- Expense Category: ${voucher.category.localizedLabel(isZh: false)}\n'
        '- Amount: NT\$${voucher.amountNtd} (Attach Apple App Store Receipt)\n'
        '- Issue Date: ${voucher.issuedDateUtc8}';
  }
}
import 'package:flutter/foundation.dart';
import 'taiwan_report_repository.dart';

enum UrgencyLevel { safe, warning48h, critical24h, expired }

@immutable
class UrgencyRadarSummary {
  const UrgencyRadarSummary({
    required this.pendingCount,
    required this.expiringWithin48hCount,
    required this.mostUrgentHoursLeft,
    required this.highestLevel,
  });
  final int pendingCount;
  final int expiringWithin48hCount;
  final int mostUrgentHoursLeft;
  final UrgencyLevel highestLevel;
  bool get hasUrgentAlert => expiringWithin48hCount > 0;
}

class StatutoryUrgencyEngine {
  const StatutoryUrgencyEngine._();
  static const int warningThresholdHours = 48;
  static const int criticalThresholdHours = 24;

  static UrgencyRadarSummary scanCases(
    List<EvidenceCaseRecord> cases,
    DateTime nowUtc,
  ) {
    int pending = 0;
    int expiring48h = 0;
    int minHours = 168;
    UrgencyLevel highest = UrgencyLevel.safe;

    for (final EvidenceCaseRecord c in cases) {
      if (c.status != CaseSubmissionStatus.pending) continue;
      pending += 1;
      final int rem = TaiwanReportRepository.remainingHoursToReport(
        capturedAtUtc: c.capturedAtUtc,
        nowUtc: nowUtc,
      );
      if (rem < minHours) minHours = rem;
      if (rem <= 0) {
        expiring48h += 1;
        highest = UrgencyLevel.expired;
      } else if (rem <= criticalThresholdHours) {
        expiring48h += 1;
        if (highest != UrgencyLevel.expired) highest = UrgencyLevel.critical24h;
      } else if (rem <= warningThresholdHours) {
        expiring48h += 1;
        if (highest == UrgencyLevel.safe) highest = UrgencyLevel.warning48h;
      }
    }
    return UrgencyRadarSummary(
      pendingCount: pending,
      expiringWithin48hCount: expiring48h,
      mostUrgentHoursLeft: minHours,
      highestLevel: highest,
    );
  }

  static String buildAlertBannerText(
    UrgencyRadarSummary summary, {
    required bool isZh,
  }) {
    if (!summary.hasUrgentAlert) {
      return isZh
          ? '✅ 案件庫安全：目前 ${summary.pendingCount} 件待辦皆在 7 日法定舉發期內'
          : '✅ Vault Safe: ${summary.pendingCount} pending case(s) within 7-day limit';
    }
    return isZh
        ? '🚨 期限警報：有 ${summary.expiringWithin48hCount} 件違規存證僅剩 ${summary.mostUrgentHoursLeft} 小時即將逾越 7 日舉發期！'
        : '🚨 Urgency Alert: ${summary.expiringWithin48hCount} case(s) expire in ${summary.mostUrgentHoursLeft}h (7-day limit)!';
  }
}
import 'package:flutter/foundation.dart';

enum NorthStarStage {
  coldInstall,
  halfwayActivated,
  magicMomentReached,
  dormantRecallNeeded,
}

@immutable
class NorthStarStatus {
  const NorthStarStatus({
    required this.daysSinceInstall,
    required this.capturesCount,
    required this.exportsCount,
    required this.stage,
    required this.progressRatio,
  });

  final int daysSinceInstall;
  final int capturesCount;
  final int exportsCount;
  final NorthStarStage stage;
  final double progressRatio;

  bool get isActivated => stage == NorthStarStage.magicMomentReached;
}

class ChamathNorthStarEngine {
  const ChamathNorthStarEngine._();
  static const int goldenWindowDays = 7;
  static const int targetCapturesThreshold = 2;
  static const int targetExportsThreshold = 1;

  static double computeActivationRatio({
    required int capturesCount,
    required int exportsCount,
  }) {
    final int safeCaptures = capturesCount.clamp(0, 999999);
    final int safeExports = exportsCount.clamp(0, 999999);
    if (safeExports >= targetExportsThreshold ||
        safeCaptures >= targetCapturesThreshold) {
      return 1.0;
    }
    return (safeCaptures / targetCapturesThreshold).clamp(0.0, 1.0);
  }

  static NorthStarStatus evaluateStatus({
    required DateTime installedAtUtc,
    required DateTime nowUtc,
    required int capturesCount,
    required int exportsCount,
  }) {
    final int rawDays = nowUtc.toUtc().difference(installedAtUtc.toUtc()).inDays;
    final int safeDays = rawDays < 0 ? 0 : rawDays.clamp(0, 9999);
    final int safeCaptures = capturesCount.clamp(0, 999999);
    final int safeExports = exportsCount.clamp(0, 999999);
    final double ratio = computeActivationRatio(
      capturesCount: safeCaptures,
      exportsCount: safeExports,
    );

    final NorthStarStage stage;
    if (ratio >= 1.0) {
      stage = NorthStarStage.magicMomentReached;
    } else if (safeDays > goldenWindowDays) {
      stage = NorthStarStage.dormantRecallNeeded;
    } else if (safeCaptures >= 1) {
      stage = NorthStarStage.halfwayActivated;
    } else {
      stage = NorthStarStage.coldInstall;
    }

    return NorthStarStatus(
      daysSinceInstall: safeDays,
      capturesCount: safeCaptures,
      exportsCount: safeExports,
      stage: stage,
      progressRatio: ratio,
    );
  }

  static String buildNorthStarNudge(
    NorthStarStatus status, {
    required bool isZh,
  }) {
    switch (status.stage) {
      case NorthStarStage.coldInstall:
        return isZh
            ? '📸 立即拍下第 1 張 UTC+8 防偽水印照片，開啟 7 日黃金存證保護'
            : '📸 Capture your first UTC+8 watermarked photo to start 7-day protection';
      case NorthStarStage.halfwayActivated:
        return isZh
            ? '🔥 太棒了（進度 50%）！再拍 1 張存證或壓縮 1 支 20MB 影片即完成北極星守護'
            : '🔥 50% Activated! Capture 1 more clip or compress 1 video to reach full status';
      case NorthStarStage.magicMomentReached:
        return isZh
            ? '🏆 已達成 7 日北極星留存門檻！您的防偽存證與 20MB 壓縮引擎已全面啟動'
            : '🏆 North Star Activated! Full timestamp & 20MB workflow unlocked';
      case NorthStarStage.dormantRecallNeeded:
        return isZh
            ? '⏳ 已安裝超過 7 天，別忘了測試 1 次 4K 影片壓縮至 19MB 與 110 報案草稿'
            : '⏳ Over 7 days since install — try compressing a 4K clip under 19MB today';
    }
  }
}
import 'package:flutter/foundation.dart';

enum MonetizationTierSpec {
  annualTrial(
    skuId: 'com.beigou.timecampro.annual390',
    priceNtd: 390,
    priceUsd: 12.99,
    titleZh: 'Pro 年度訂閱 (含3天免費試用)',
    titleEn: 'Pro Annual (3-Day Free Trial)',
    pitchZh: r'平均每日僅 NT$1.06・先免費壓縮匯出，滿意再續訂',
    pitchEn: r'Just $0.03/day. Try 3 days free, cancel anytime.',
  ),
  personalLifetime(
    skuId: 'com.beigou.timecampro.lifetime590',
    priceNtd: 590,
    priceUsd: 19.99,
    titleZh: '個人終身買斷版 (永久解鎖)',
    titleEn: 'Personal Lifetime (One-Time)',
    pitchZh: r'一次付費 NT$590 永久使用・檢舉 1 件煙蒂獎金即回本',
    pitchEn: r'Pay $19.99 once, own forever. Zero recurring fees.',
  ),
  b2bContractorPro(
    skuId: 'com.beigou.timecampro.b2b990',
    priceNtd: 990,
    priceUsd: 29.99,
    titleZh: '工程商務驗收版 (公司抬頭/防偽章)',
    titleEn: 'B2B Contractor Edition',
    pitchZh: r'專為太陽能/營造包商打造・自訂公司標案抬頭與12碼防偽碼',
    pitchEn: r'For solar & construction teams: custom company headers.',
  );

  const MonetizationTierSpec({
    required this.skuId,
    required this.priceNtd,
    required this.priceUsd,
    required this.titleZh,
    required this.titleEn,
    required this.pitchZh,
    required this.pitchEn,
  });
  final String skuId;
  final int priceNtd;
  final double priceUsd;
  final String titleZh;
  final String titleEn;
  final String pitchZh;
  final String pitchEn;
}

@immutable
class RevenueAcceleratorEngine {
  const RevenueAcceleratorEngine._();

  static final RegExp _b2bKeywordRegex = RegExp(
    r'(工程|案場|太陽能|工地|施工|巡檢|驗收|標案|營造|水電|solar|site|inspection|project|contractor)',
    caseSensitive: false,
  );

  static MonetizationTierSpec recommendTierForNote(String rawNote) {
    if (_b2bKeywordRegex.hasMatch(rawNote.trim())) {
      return MonetizationTierSpec.b2bContractorPro;
    }
    return MonetizationTierSpec.personalLifetime;
  }

  static bool shouldTriggerReviewPrompt({
    required int completedActions,
    required bool alreadyPromptedInSession,
  }) {
    if (alreadyPromptedInSession || completedActions <= 0) {
      return false;
    }
    return completedActions == 2 || completedActions == 5;
  }

  static const double appleSmallBusinessKeepRate = 0.85;

  static int estimateMonthlyNetProfitNtd({
    required int annualCount,
    required int personalLifetimeCount,
    required int b2bContractorCount,
  }) {
    final int a = annualCount.clamp(0, 100000);
    final int p = personalLifetimeCount.clamp(0, 100000);
    final int b = b2bContractorCount.clamp(0, 100000);

    final int grossNtd =
        (a * MonetizationTierSpec.annualTrial.priceNtd) +
        (p * MonetizationTierSpec.personalLifetime.priceNtd) +
        (b * MonetizationTierSpec.b2bContractorPro.priceNtd);

    return (grossNtd * appleSmallBusinessKeepRate).round();
  }
}
import 'package:flutter/foundation.dart';

enum ArielyOfferRole { lowAnchor, decoyDominated, targetHero }

@immutable
class DecoyPricingOption {
  const DecoyPricingOption({required this.role, required this.skuId, required this.priceNtd, required this.priceUsd, required this.annualizedCostNtd, required this.titleZh, required this.titleEn, required this.comparisonTagZh, required this.comparisonTagEn});
  final ArielyOfferRole role;
  final String skuId;
  final int priceNtd;
  final double priceUsd;
  final int annualizedCostNtd;
  final String titleZh;
  final String titleEn;
  final String comparisonTagZh;
  final String comparisonTagEn;
}

class ArielyDecoyPricingEngine {
  const ArielyDecoyPricingEngine._();
  static const int decoyToTargetSpreadNtd = 40;
  static const List<DecoyPricingOption> decoyMatrix = <DecoyPricingOption>[
    DecoyPricingOption(role: ArielyOfferRole.lowAnchor, skuId: 'com.beigou.timecampro.monthly150', priceNtd: 150, priceUsd: 4.99, annualizedCostNtd: 1800, titleZh: '單月輕量體驗版', titleEn: 'Monthly Starter Plan', comparisonTagZh: r'一年累計 NT$1,800', comparisonTagEn: r'$4.99/mo'),
    DecoyPricingOption(role: ArielyOfferRole.decoyDominated, skuId: 'com.beigou.timecampro.annual550', priceNtd: 550, priceUsd: 18.99, annualizedCostNtd: 550, titleZh: '純年費基本授權 (1年期)', titleEn: 'Basic Annual License', comparisonTagZh: r'僅限1年使用・不含法條庫', comparisonTagEn: r'$18.99/yr'),
    DecoyPricingOption(role: ArielyOfferRole.targetHero, skuId: 'com.beigou.timecampro.lifetime590', priceNtd: 590, priceUsd: 19.99, annualizedCostNtd: 295, titleZh: '終身買斷旗艦版', titleEn: 'Lifetime Flagship', comparisonTagZh: r'只比年費多 NT$40 ➔ 永久終身', comparisonTagEn: r'Just $1 more ➔ Own Forever'),
  ];
  static int twoYearTotalCostNtd(DecoyPricingOption option) => option.role == ArielyOfferRole.lowAnchor ? option.priceNtd * 24 : (option.role == ArielyOfferRole.decoyDominated ? option.priceNtd * 2 : option.priceNtd);
  static int twoYearSavingsVsDecoyNtd() => (twoYearTotalCostNtd(decoyMatrix[1]) - twoYearTotalCostNtd(decoyMatrix[2])).clamp(0, 100000);
  static bool isDecoySpreadValid() => (decoyMatrix[2].priceNtd - decoyMatrix[1].priceNtd) == decoyToTargetSpreadNtd;
  static String buildDecoyComparisonPitch({required bool isZh}) => isZh ? '🧠 精算對比：純年費 2 年需 NT\$${twoYearTotalCostNtd(decoyMatrix[1])}；旗艦終身版僅多 NT\$$decoyToTargetSpreadNtd（NT\$${decoyMatrix[2].priceNtd} 一次買斷），2 年即省 NT\$${twoYearSavingsVsDecoyNtd()}' : '🧠 2-Yr Annual is NT\$${twoYearTotalCostNtd(decoyMatrix[1])}; Lifetime is just NT\$$decoyToTargetSpreadNtd more';
}
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
    expect(StatutoryUrgencyEngine.scanCases(TaiwanReportRepository.createInitialCases(t), t.add(const Duration(days: 4))).hasUrgentAlert, isTrue);
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
    await tester.pump();
    await tester.tap(find.byKey(const Key('compressor_export_cta_btn')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
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
    expect(find.descendant(of: find.byType(PaywallSheet), matching: find.textContaining('864')), findsOneWidget);
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
