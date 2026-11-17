import 'package:flutter/foundation.dart';

@immutable
class ReferralStatusSnapshot {
  const ReferralStatusSnapshot({
    required this.myInviteCode,
    required this.redeemedFriendCount,
    required this.bonusExportPassesEarned,
    required this.hasRedeemedStarterCode,
  });

  final String myInviteCode;
  final int redeemedFriendCount;
  final int bonusExportPassesEarned;
  final bool hasRedeemedStarterCode;

  bool get canEarnMoreBonus =>
      bonusExportPassesEarned < ChenReferralViralEngine.maxBonusExportPasses;
}

class ChenReferralViralEngine {
  const ChenReferralViralEngine._();
  static const int bonusPassesPerInvite = 2;
  static const int maxBonusExportPasses = 6;
  static const String _referralSalt = 'TIMECAM_VIRAL_TW';

  static String _computeChecksum2Digits(String core4Digits) {
    int acc = 17;
    final String salted = '$core4Digits$_referralSalt';
    for (int i = 0; i < salted.length; i++) {
      acc = ((acc * 31) + salted.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return (acc % 100).toString().padLeft(2, '0');
  }

  static String generateInviteCode(int seedNumber) {
    final int normalized = (seedNumber.abs() % 9000) + 1000;
    final String core = normalized.toString();
    final String chk = _computeChecksum2Digits(core);
    return 'TC-$core-$chk';
  }

  static bool isValidInviteCode(String rawCode) {
    final String clean = rawCode.trim().toUpperCase();
    if (!RegExp(r'^TC-\d{4}-\d{2}$').hasMatch(clean)) {
      return false;
    }
    final String core = clean.substring(3, 7);
    final String chk = clean.substring(8, 10);
    return _computeChecksum2Digits(core) == chk;
  }

  static ReferralStatusSnapshot redeemFriendCode({
    required ReferralStatusSnapshot current,
    required String friendCode,
  }) {
    final String clean = friendCode.trim().toUpperCase();
    if (current.hasRedeemedStarterCode ||
        !current.canEarnMoreBonus ||
        clean == current.myInviteCode.trim().toUpperCase() ||
        !isValidInviteCode(clean)) {
      return current;
    }
    final int nextBonus = (current.bonusExportPassesEarned + bonusPassesPerInvite)
        .clamp(0, maxBonusExportPasses);
    return ReferralStatusSnapshot(
      myInviteCode: current.myInviteCode,
      redeemedFriendCount: current.redeemedFriendCount + 1,
      bonusExportPassesEarned: nextBonus,
      hasRedeemedStarterCode: true,
    );
  }

  static ReferralStatusSnapshot initialSnapshot(int deviceSeed) {
    return ReferralStatusSnapshot(
      myInviteCode: generateInviteCode(deviceSeed),
      redeemedFriendCount: 0,
      bonusExportPassesEarned: 0,
      hasRedeemedStarterCode: false,
    );
  }

  static String buildReferralInviteMessage(
    ReferralStatusSnapshot snap, {
    required bool isZh,
  }) {
    if (isZh) {
      return '🚀 推薦這套超強的「時間相機 Pro」給你！4K 違規影片 1 秒壓進 20MB 不退件，還有 UTC+8 防偽水印跟 110 一鍵簡訊報案！\n'
          '🎁 下載後輸入我的車友推薦碼【${snap.myInviteCode}】，你我雙方各免費多領 $bonusPassesPerInvite 次 20MB 壓縮匯出額度！';
    }
    return '🚀 Check out TimeCam Pro! Compresses 4K clips strictly under 20MB with verified UTC+8 & GPS watermarks.\n'
        '🎁 Enter my invite code [${snap.myInviteCode}] so we both unlock +$bonusPassesPerInvite free 20MB export passes!';
  }
}
