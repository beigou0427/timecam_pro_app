import 'package:flutter/foundation.dart';

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
  static const int proLifetimePriceNtd = 590;
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
