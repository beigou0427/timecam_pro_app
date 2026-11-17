import 'package:flutter/foundation.dart';

enum NorthStarStage {
  coldInstall,
  halfwayActivated,
  magicMomentReached,
  dormantRecallNeeded,
}

@immutable
class NorthStarStatus {
  const NorthStarStatus({
    required this.daysSinceInstall,
    required this.capturesCount,
    required this.exportsCount,
    required this.stage,
    required this.progressRatio,
  });

  final int daysSinceInstall;
  final int capturesCount;
  final int exportsCount;
  final NorthStarStage stage;
  final double progressRatio;

  bool get isActivated => stage == NorthStarStage.magicMomentReached;
}

class ChamathNorthStarEngine {
  const ChamathNorthStarEngine._();
  static const int goldenWindowDays = 7;
  static const int targetCapturesThreshold = 2;
  static const int targetExportsThreshold = 1;

  static double computeActivationRatio({
    required int capturesCount,
    required int exportsCount,
  }) {
    final int safeCaptures = capturesCount.clamp(0, 999999);
    final int safeExports = exportsCount.clamp(0, 999999);
    if (safeExports >= targetExportsThreshold ||
        safeCaptures >= targetCapturesThreshold) {
      return 1.0;
    }
    return (safeCaptures / targetCapturesThreshold).clamp(0.0, 1.0);
  }

  static NorthStarStatus evaluateStatus({
    required DateTime installedAtUtc,
    required DateTime nowUtc,
    required int capturesCount,
    required int exportsCount,
  }) {
    final int rawDays = nowUtc.toUtc().difference(installedAtUtc.toUtc()).inDays;
    final int safeDays = rawDays < 0 ? 0 : rawDays.clamp(0, 9999);
    final int safeCaptures = capturesCount.clamp(0, 999999);
    final int safeExports = exportsCount.clamp(0, 999999);
    final double ratio = computeActivationRatio(
      capturesCount: safeCaptures,
      exportsCount: safeExports,
    );

    final NorthStarStage stage;
    if (ratio >= 1.0) {
      stage = NorthStarStage.magicMomentReached;
    } else if (safeDays > goldenWindowDays) {
      stage = NorthStarStage.dormantRecallNeeded;
    } else if (safeCaptures >= 1) {
      stage = NorthStarStage.halfwayActivated;
    } else {
      stage = NorthStarStage.coldInstall;
    }

    return NorthStarStatus(
      daysSinceInstall: safeDays,
      capturesCount: safeCaptures,
      exportsCount: safeExports,
      stage: stage,
      progressRatio: ratio,
    );
  }

  static String buildNorthStarNudge(
    NorthStarStatus status, {
    required bool isZh,
  }) {
    switch (status.stage) {
      case NorthStarStage.coldInstall:
        return isZh
            ? '📸 立即拍下第 1 張 UTC+8 防偽水印照片，開啟 7 日黃金存證保護'
            : '📸 Capture your first UTC+8 watermarked photo to start 7-day protection';
      case NorthStarStage.halfwayActivated:
        return isZh
            ? '🔥 太棒了（進度 50%）！再拍 1 張存證或壓縮 1 支 20MB 影片即完成北極星守護'
            : '🔥 50% Activated! Capture 1 more clip or compress 1 video to reach full status';
      case NorthStarStage.magicMomentReached:
        return isZh
            ? '🏆 已達成 7 日北極星留存門檻！您的防偽存證與 20MB 壓縮引擎已全面啟動'
            : '🏆 North Star Activated! Full timestamp & 20MB workflow unlocked';
      case NorthStarStage.dormantRecallNeeded:
        return isZh
            ? '⏳ 已安裝超過 7 天，別忘了測試 1 次 4K 影片壓縮至 19MB 與 110 報案草稿'
            : '⏳ Over 7 days since install — try compressing a 4K clip under 19MB today';
    }
  }
}
