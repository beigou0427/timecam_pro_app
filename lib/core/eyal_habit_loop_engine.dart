import 'package:flutter/foundation.dart';

enum HabitMilestoneRank {
  rookieWatcher(minReports: 0, badgeZh: '🌱 現場存證新手', badgeEn: '🌱 Field Rookie'),
  streetGuardian(minReports: 3, badgeZh: '🛡️ 道路安全守護者', badgeEn: '🛡️ Safety Guardian'),
  goldAuditor(minReports: 10, badgeZh: '🏅 黃金稽查領航員', badgeEn: '🏅 Gold Auditor'),
  legendaryInspector(minReports: 25, badgeZh: '👑 傳奇執法與驗收大師', badgeEn: '👑 Master Inspector');

  const HabitMilestoneRank({required this.minReports, required this.badgeZh, required this.badgeEn});
  final int minReports;
  final String badgeZh;
  final String badgeEn;
  String localizedBadge({required bool isZh}) => isZh ? badgeZh : badgeEn;
}

@immutable
class HabitVaultProgress {
  const HabitVaultProgress({
    required this.totalEvidenceCaptured,
    required this.totalReportsSubmitted,
    required this.totalSavedMB,
    required this.estimatedRewardPotNtd,
    required this.rank,
  });
  final int totalEvidenceCaptured;
  final int totalReportsSubmitted;
  final double totalSavedMB;
  final int estimatedRewardPotNtd;
  final HabitMilestoneRank rank;
}

class EyalHabitLoopEngine {
  const EyalHabitLoopEngine._();
  static const int proConversionSweetSpotActions = 3;

  static HabitMilestoneRank resolveRank(int totalReportsSubmitted) {
    final int safe = totalReportsSubmitted.clamp(0, 100000);
    if (safe >= HabitMilestoneRank.legendaryInspector.minReports) {
      return HabitMilestoneRank.legendaryInspector;
    }
    if (safe >= HabitMilestoneRank.goldAuditor.minReports) {
      return HabitMilestoneRank.goldAuditor;
    }
    if (safe >= HabitMilestoneRank.streetGuardian.minReports) {
      return HabitMilestoneRank.streetGuardian;
    }
    return HabitMilestoneRank.rookieWatcher;
  }

  static HabitVaultProgress initialProgress() => const HabitVaultProgress(
        totalEvidenceCaptured: 0,
        totalReportsSubmitted: 0,
        totalSavedMB: 0.0,
        estimatedRewardPotNtd: 0,
        rank: HabitMilestoneRank.rookieWatcher,
      );

  static HabitVaultProgress recordHabitAction({
    required HabitVaultProgress current,
    required bool isReportSubmitted,
    double savedMB = 0.0,
    int addedRewardNtd = 0,
  }) {
    final int nextCaptured = (current.totalEvidenceCaptured + 1).clamp(0, 999999);
    final int nextSubmitted = isReportSubmitted
        ? (current.totalReportsSubmitted + 1).clamp(0, 999999)
        : current.totalReportsSubmitted;
    final double safeSaved =
        (savedMB.isFinite && savedMB > 0.0) ? savedMB.clamp(0.0, 10000.0) : 0.0;
    final int safeReward = addedRewardNtd.clamp(0, 50000);

    return HabitVaultProgress(
      totalEvidenceCaptured: nextCaptured,
      totalReportsSubmitted: nextSubmitted,
      totalSavedMB: (current.totalSavedMB + safeSaved).clamp(0.0, 9999999.0),
      estimatedRewardPotNtd:
          (current.estimatedRewardPotNtd + safeReward).clamp(0, 9999999),
      rank: resolveRank(nextSubmitted),
    );
  }

  static int reportsNeededForNextRank(HabitVaultProgress progress) {
    final int current = progress.totalReportsSubmitted;
    if (current < HabitMilestoneRank.streetGuardian.minReports) {
      return HabitMilestoneRank.streetGuardian.minReports - current;
    }
    if (current < HabitMilestoneRank.goldAuditor.minReports) {
      return HabitMilestoneRank.goldAuditor.minReports - current;
    }
    if (current < HabitMilestoneRank.legendaryInspector.minReports) {
      return HabitMilestoneRank.legendaryInspector.minReports - current;
    }
    return 0;
  }

  static String buildHabitSummaryBanner(
    HabitVaultProgress progress, {
    required bool isZh,
  }) {
    final String rankLabel = progress.rank.localizedBadge(isZh: isZh);
    final String savedStr = progress.totalSavedMB.toStringAsFixed(1);
    final int needed = reportsNeededForNextRank(progress);
    if (isZh) {
      final String nextHint = needed > 0 ? '・再 $needed 件升級下一勳章' : '・已達最高傳奇等級';
      return '$rankLabel｜已瘦身 $savedStr MB｜獎金存錢筒 NT\$${progress.estimatedRewardPotNtd}$nextHint';
    }
    final String nextHintEn = needed > 0 ? ' • $needed more to rank up' : ' • Max Rank Reached';
    return '$rankLabel | Saved $savedStr MB | Reward Pot NT\$${progress.estimatedRewardPotNtd}$nextHintEn';
  }
}
