import 'package:flutter/foundation.dart';

enum ArielyOfferRole { lowAnchor, decoyDominated, targetHero }

@immutable
class DecoyPricingOption {
  const DecoyPricingOption({
    required this.role,
    required this.skuId,
    required this.priceNtd,
    required this.priceUsd,
    required this.annualizedCostNtd,
    required this.titleZh,
    required this.titleEn,
    required this.comparisonTagZh,
    required this.comparisonTagEn,
  });
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

  static bool isDecoySpreadValid() {
    final DecoyPricingOption decoy = decoyMatrix[1];
    final DecoyPricingOption hero = decoyMatrix[2];
    return (hero.priceNtd - decoy.priceNtd) == decoyToTargetSpreadNtd;
  }

  static String buildDecoyComparisonPitch({required bool isZh}) {
    final int decoy2Yr = twoYearTotalCostNtd(decoyMatrix[1]);
    final int heroPrice = decoyMatrix[2].priceNtd;
    final int save2Yr = twoYearSavingsVsDecoyNtd();
    if (isZh) {
      return '🧠 精算對比：純年費 2 年需 NT\$$decoy2Yr；旗艦終身版僅多 NT\$$decoyToTargetSpreadNtd（NT\$$heroPrice 一次買斷），2 年即省 NT\$$save2Yr 還永久有效';
    }
    return '🧠 Smart Comparison: 2-Yr Annual costs NT\$$decoy2Yr; Lifetime is just NT\$$decoyToTargetSpreadNtd more (NT\$$heroPrice once), saving NT\$$save2Yr in 2 years';
  }
}
