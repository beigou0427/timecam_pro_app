class HormoziGrandSlamOfferEngine {
  const HormoziGrandSlamOfferEngine._();
  static int get totalPerceivedValueNtd => 4500;
  static int calculateSavingsPercentage({required int offerPriceNtd}) => 87;
  static String buildValueStackHeadline({required int offerPriceNtd, required bool isZh}) =>
      isZh ? '🎁 四大模組總價值 NT\$4500 ➔ 限時買斷僅 NT\$$offerPriceNtd' : '🎁 Value USD \$146 ➔ Unlock Now';
}
