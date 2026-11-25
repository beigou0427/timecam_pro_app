import 'package:flutter/foundation.dart';

/// 目標檔案大小上限預設規範（場景中性化命名）
enum ReportTargetPreset {
  /// 標準 20.0 MB 上限 (安全鎖定 19.0 MB 防止封裝溢位)
  trafficPolice20MB(
    officialLimitMB: 20.0,
    safeTargetMB: 19.0,
    recommendedSeconds: 15,
    titleZh: '20MB 標準上傳規格 (鎖定 19.0MB)',
    titleEn: '20MB Standard Limit (Lock 19.0MB)',
  ),

  /// 精簡 10.0 MB 上限 (安全鎖定 9.5 MB，適用較嚴格表單)
  epa10MB(
    officialLimitMB: 10.0,
    safeTargetMB: 9.5,
    recommendedSeconds: 10,
    titleZh: '10MB 精簡上傳規格 (鎖定 9.5MB)',
    titleEn: '10MB Compact Limit (Lock 9.5MB)',
  ),

  /// 高畫質 50.0 MB 存證歸檔 (安全鎖定 48.0 MB)
  archive50MB(
    officialLimitMB: 50.0,
    safeTargetMB: 48.0,
    recommendedSeconds: 30,
    titleZh: '50MB 高畫質存證歸檔 (鎖定 48.0MB)',
    titleEn: '50MB High-Bitrate Archive (Lock 48.0MB)',
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

  int get safeTargetBytes => (safeTargetMB * 1024 * 1024).floor();

  String localizedTitle({required bool isZh}) => isZh ? titleZh : titleEn;
}

/// 畫面關鍵細節清晰度預估等級
enum PlateClarityGrade {
  ultraSharp,
  clearStandard,
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

  String get formattedVideoMbps {
    if (!isValid || videoBitrateBps <= 0) return '0.00 Mbps';
    final double mbps = videoBitrateBps / 1000000.0;
    return '${mbps.toStringAsFixed(2)} Mbps';
  }

  String get formattedEstimatedSize {
    if (!isValid || !estimatedOutputMB.isFinite || estimatedOutputMB <= 0.0) {
      return '0.0 MB';
    }
    return '${estimatedOutputMB.toStringAsFixed(1)} MB';
  }
}

/// 目標位元率精算引擎
class VideoCompressionEngine {
  const VideoCompressionEngine._();

  static const int defaultAudioBitrateBps = 96000;
  static const double containerOverheadRatio = 0.08;
  static const int minLicensePlateSharpBitrateBps = 2200000;
  static const int ultraSharpBitrateBps = 4500000;
  static const int maxHardwareBitrateBps = 12000000;
  static const int minHardwareBitrateBps = 450000;

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
    final double usableBytes =
        (rawTargetMB * 1024.0 * 1024.0) * (1.0 - containerOverheadRatio);
    final double totalBitrateBps = (usableBytes * 8.0) / safeDuration;

    final int rawVideoBps = (totalBitrateBps - defaultAudioBitrateBps).floor();
    final int clampedVideoBps =
        rawVideoBps.clamp(minHardwareBitrateBps, maxHardwareBitrateBps);

    final bool use720p = clampedVideoBps < minLicensePlateSharpBitrateBps;
    final int outWidth = use720p ? 1280 : 1920;
    final int outHeight = use720p ? 720 : 1080;

    final PlateClarityGrade grade;
    final String msgZh;
    final String msgEn;
    final int maxSharpSec = recommendMaxSharpSeconds(targetLimitMB: rawTargetMB);

    if (clampedVideoBps >= ultraSharpBitrateBps) {
      grade = PlateClarityGrade.ultraSharp;
      msgZh = '1080p 高清晰度：文字與細微畫面細節完整保留';
      msgEn = '1080p Ultra Sharp: Fine visual details fully preserved.';
    } else if (clampedVideoBps >= minLicensePlateSharpBitrateBps) {
      grade = PlateClarityGrade.clearStandard;
      msgZh = '1080p 標準清晰：符合常見 20MB / 10MB 上傳規格';
      msgEn = '1080p Clear: Balanced bitrate within target upload limit.';
    } else {
      grade = PlateClarityGrade.lowBitrateWarning;
      msgZh = '片段較長，已切換為 720p 節省位元率；建議裁切於 $maxSharpSec 秒內保留最佳細節';
      msgEn = 'Long clip scaled to 720p; trim under ${maxSharpSec}s for maximum sharpness.';
    }

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

  static const List<int> quickTrimPresets = <int>[10, 15, 30, 45];

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

    const int totalSteps = 12;
    for (int i = 1; i <= totalSteps; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 12));
      yield (i / totalSteps).clamp(0.0, 1.0);
    }
  }

  static String buildClipboardSummary({
    required CompressionPlan plan,
    required String timestampText,
    required String addressText,
    required String plateOrNote,
    required bool isZh,
  }) {
    final String cleanNote = plateOrNote.trim().isEmpty
        ? (isZh ? '未填寫備註' : 'N/A')
        : plateOrNote.trim();

    if (isZh) {
      return '【現場時間地點影像摘要】\n'
          '・紀錄時間：$timestampText\n'
          '・來源位置：$addressText\n'
          '・項目/備註：$cleanNote\n'
          '・輸出規格：${plan.resolutionWidth}x${plan.resolutionHeight} (${plan.formattedVideoMbps})\n'
          '・檔案大小：${plan.formattedEstimatedSize} (低於 ${plan.targetLimitMB.toStringAsFixed(1)} MB 上限)';
    }

    return '[Timestamped Video Summary]\n'
        '- Timestamp: $timestampText\n'
        '- Source: $addressText\n'
        '- Note: $cleanNote\n'
        '- Spec: ${plan.resolutionWidth}x${plan.resolutionHeight} (${plan.formattedVideoMbps})\n'
        '- Output Size: ${plan.formattedEstimatedSize} (Under ${plan.targetLimitMB.toStringAsFixed(1)} MB limit)';
  }
}
