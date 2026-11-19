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
    priceUsd: 119.99,
    titleZh: '個人終身買斷版 (永久解鎖)',
    titleEn: 'Personal Lifetime (One-Time)',
    pitchZh: r'一次付費 NT$590 永久使用・檢舉 1 件煙蒂獎金即回本',
    pitchEn: r'Pay $119.99 once, own forever. Zero recurring fees.',
  ),
  b2bContractorPro(
    skuId: 'com.beigou.timecampro.b2b990',
    priceNtd: 990,
    priceUsd: 219.99,
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
