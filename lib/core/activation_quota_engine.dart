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
          ? 'Pro 專業版已啟用（累計已節省 ${snap.formattedTotalSavedMB}）'
          : 'Pro Unlimited Active (Total saved: ${snap.formattedTotalSavedMB})';
    }
    if (snap.hasFreeGoldenPass) {
      return isZh
          ? '新戶享 ${snap.remainingFreeExports} 次免費 20MB 壓縮體驗'
          : '${snap.remainingFreeExports} free 20MB export pass remaining';
    }
    return isZh
        ? '已體驗極速壓縮（已省 ${snap.formattedTotalSavedMB}）・升級 Pro 解鎖無限匯出'
        : 'Saved ${snap.formattedTotalSavedMB} with free pass • Upgrade to Pro for unlimited exports';
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
            ? '免費體驗壓縮匯出 ($formattedEstimatedSize • 剩 ${quota.remainingFreeExports} 次)'
            : 'Free Pass Export ($formattedEstimatedSize • ${quota.remainingFreeExports} left)';
      case ExportGateDecision.interceptWithPaywall:
        return isZh
            ? '升級 Pro 匯出 $formattedEstimatedSize 影片'
            : 'Unlock Pro to Export $formattedEstimatedSize Clip';
    }
  }

  /// 當用戶用完首張免費體驗券、第 2 次點擊匯出時，喚醒「已瘦身成果」之高轉換說帖（不含硬寫價格）
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
          ? '您剛才已省下 ${quota.formattedTotalSavedMB} 容量！升級 Pro 立即無限次匯出這支 $formattedEstimatedSize 影片（$plateNumber，省下 $pct%），並含完整 A4 PDF 報告。'
          : 'You already saved ${quota.formattedTotalSavedMB}! Upgrade to Pro to export this $formattedEstimatedSize clip ($plateNumber, -$pct%) with unlimited 20MB & A4 PDF access.';
    }
    return isZh
        ? '這支 $formattedEstimatedSize 影片（$plateNumber，省下 $pct% 容量）已精算就緒；升級 Pro 立即無限次匯出。'
        : 'Your $formattedEstimatedSize clip ($plateNumber, -$pct%) is ready; upgrade to Pro for unlimited exports.';
  }
}
