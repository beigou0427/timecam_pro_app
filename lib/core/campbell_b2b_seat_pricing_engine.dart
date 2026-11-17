import 'package:flutter/foundation.dart';

enum B2bTeamBundleTier {
  soloInspector(maxSeats: 1, priceNtd: 590, titleZh: '單人專業版', titleEn: 'Solo Pro'),
  crew5Seats(maxSeats: 5, priceNtd: 1990, titleZh: '5人工程班組包', titleEn: '5-Seat Crew Pack'),
  fleet15Seats(maxSeats: 15, priceNtd: 3990, titleZh: '15人營造車隊包', titleEn: '15-Seat Fleet Pack');

  const B2bTeamBundleTier({required this.maxSeats, required this.priceNtd, required this.titleZh, required this.titleEn});
  final int maxSeats;
  final int priceNtd;
  final String titleZh;
  final String titleEn;
}

@immutable
class CampbellB2bSeatPricingEngine {
  const CampbellB2bSeatPricingEngine._();

  static int pricePerSeatNtd(B2bTeamBundleTier tier) =>
      (tier.priceNtd / tier.maxSeats.clamp(1, 100)).round();

  static B2bTeamBundleTier recommendTier(int teamSize) =>
      teamSize <= 1 ? B2bTeamBundleTier.soloInspector : (teamSize <= 5 ? B2bTeamBundleTier.crew5Seats : B2bTeamBundleTier.fleet15Seats);

  static String buildB2bBundlePitch(B2bTeamBundleTier tier, {required bool isZh}) {
    final int perSeat = pricePerSeatNtd(tier);
    return isZh
        ? '👷 ${tier.titleZh}：總價 NT\$${tier.priceNtd}（平均每台僅 NT\$$perSeat，支援公司統編報帳）'
        : '👷 ${tier.titleEn}: NT\$${tier.priceNtd} total (Just NT\$$perSeat/device)';
  }
}
