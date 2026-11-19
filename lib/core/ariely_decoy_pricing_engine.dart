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
    DecoyPricingOption(role: ArielyOfferRole.targetHero, skuId: 'com.beigou.timecampro.lifetime590', priceNtd: 590, priceUsd: 119.99, annualizedCostNtd: 295, titleZh: '終身買斷旗艦版', titleEn: 'Lifetime Flagship', comparisonTagZh: r'只比年費多 NT$40 ➔ 永久終身', comparisonTagEn: r'Just $1 more ➔ Own Forever'),
  ];
  static int twoYearTotalCostNtd(DecoyPricingOption option) => option.role == ArielyOfferRole.lowAnchor ? option.priceNtd * 24 : (option.role == ArielyOfferRole.decoyDominated ? option.priceNtd * 2 : option.priceNtd);
  static int twoYearSavingsVsDecoyNtd() => (twoYearTotalCostNtd(decoyMatrix[1]) - twoYearTotalCostNtd(decoyMatrix[2])).clamp(0, 100000);
  static bool isDecoySpreadValid() => (decoyMatrix[2].priceNtd - decoyMatrix[1].priceNtd) == decoyToTargetSpreadNtd;
  static String buildDecoyComparisonPitch({required bool isZh}) => isZh ? '🧠 精算對比：純年費 2 年需 NT\$${twoYearTotalCostNtd(decoyMatrix[1])}；旗艦終身版僅多 NT\$$decoyToTargetSpreadNtd（NT\$${decoyMatrix[2].priceNtd} 一次買斷），2 年即省 NT\$${twoYearSavingsVsDecoyNtd()}' : '🧠 2-Yr Annual is NT\$${twoYearTotalCostNtd(decoyMatrix[1])}; Lifetime is just NT\$$decoyToTargetSpreadNtd more';
}
