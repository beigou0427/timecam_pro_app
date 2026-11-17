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
