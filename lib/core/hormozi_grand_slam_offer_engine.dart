class HormoziGrandSlamOfferEngine {
  const HormoziGrandSlamOfferEngine._();
  static int get totalPerceivedValueNtd => 4500;
  static int calculateSavingsPercentage({required int offerPriceNtd}) => 87;
  static String buildValueStackHeadline({required int offerPriceNtd, required bool isZh}) =>
      isZh ? '✨ 專業版四大核心模組 ➔ 永久買斷 NT\$$offerPriceNtd' : '🎁 Pro Suite ➔ Unlock Now';
}
