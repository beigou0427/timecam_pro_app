
  static int get totalPerceivedValueNtd {
    int sum = 0;
    for (final ValueStackBonusItem item in grandSlamStack) {
      sum += item.perceivedValueNtd;
    }
    return sum;
  }

  static int get totalPerceivedValueUsd {
    int sum = 0;
    for (final ValueStackBonusItem item in grandSlamStack) {
      sum += item.perceivedValueUsd;
    }
    return sum;
  }

  static int calculateSavingsPercentage({required int offerPriceNtd}) {
    final int total = totalPerceivedValueNtd;
    if (total <= 0 || offerPriceNtd <= 0 || offerPriceNtd >= total) {
      return 80;
    }
    final int pct = (((total - offerPriceNtd) / total) * 100.0).round();
    return pct.clamp(10, 95);
  }

  static String buildValueStackHeadline({
    required int offerPriceNtd,
    required bool isZh,
  }) {
    final int total = totalPerceivedValueNtd;
    final int totalUsd = totalPerceivedValueUsd;
    final int pct = calculateSavingsPercentage(offerPriceNtd: offerPriceNtd);
    if (isZh) {
      return '🎁 四大專業模組總價值 NT\$$total ➔ 限時買斷立省 $pct% (僅 NT\$$offerPriceNtd)！';
    }
    return '🎁 Total Value USD \$$totalUsd ➔ Save $pct% Today with One-Time Unlock!';
  }
}
