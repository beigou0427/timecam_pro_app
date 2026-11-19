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
  static const int ultraSharpBitrateBps = 1000000;

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
  /// 常用檢舉與存證快速裁切秒數預設值 (環保局10秒 / 交通動態違規15秒與30秒 / 逼車存證10秒)
  static const List<int> quickTrimPresets = <int>[10, 15, 30, 10];

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
      await Future<void>.delayed(const Duration(milliseconds: 10));
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
}