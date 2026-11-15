import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
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
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeTrackColor: const Color(0xFFF59E0B),
            title: Text(
              widget.isZh
                  ? '轉碼時同步烙印時間與地址防偽浮水印'
                  : 'Burn-in Timestamp & GPS Watermark During Export',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
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
    );
  }
  void _handleStartExport(CompressionPlan plan) {
    if (_isCompressing) return;
    final SampleSourceVideo video = _activeVideo;

    // 黃金付費牆觸發點：若尚未解鎖 Pro，按下匯出瞬間攔截並彈出高轉化 Paywall
    if (!widget.isProUnlocked) {
      HapticFeedback.mediumImpact();
      final String reasonZh =
          '⚠️ 您的 ${plan.formattedEstimatedSize} 檢舉影片（車號 ${video.plateNumber}，節省 ${plan.savedPercentage.toStringAsFixed(0)}% 容量）已精算就緒！立即解鎖 Pro 即可一鍵壓縮匯出並趕在 7 日期限內送件。';
      final String reasonEn =
          '⚠️ Your ${plan.formattedEstimatedSize} evidence clip (Plate ${video.plateNumber}, ${plan.savedPercentage.toStringAsFixed(0)}% saved) is ready! Unlock Pro to export now.';
      widget.onRequestPaywall(widget.isZh ? reasonZh : reasonEn);
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
        setState(() {
          _isCompressing = false;
          _compressionProgress = 1.0;
        });

        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
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
                  widget.isProUnlocked
                      ? (widget.isZh
                          ? '開始智能壓縮匯出 (${plan.formattedEstimatedSize})'
                          : 'Export Compressed Video (${plan.formattedEstimatedSize})')
                      : (widget.isZh
                          ? '匯出 ${plan.formattedEstimatedSize} 檢舉影片 (解鎖 Pro)'
                          : 'Export ${plan.formattedEstimatedSize} Clip (Unlock Pro)'),
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
}