import 'package:flutter/foundation.dart';
import 'taiwan_report_repository.dart';

enum UrgencyLevel { safe, warning48h, critical24h, expired }

@immutable
class UrgencyRadarSummary {
  const UrgencyRadarSummary({
    required this.pendingCount,
    required this.expiringWithin48hCount,
    required this.mostUrgentHoursLeft,
    required this.highestLevel,
  });
  final int pendingCount;
  final int expiringWithin48hCount;
  final int mostUrgentHoursLeft;
  final UrgencyLevel highestLevel;
  bool get hasUrgentAlert => expiringWithin48hCount > 0;
}

class StatutoryUrgencyEngine {
  const StatutoryUrgencyEngine._();
  static const int warningThresholdHours = 48;
  static const int criticalThresholdHours = 24;

  static UrgencyRadarSummary scanCases(
    List<EvidenceCaseRecord> cases,
    DateTime nowUtc,
  ) {
    int pending = 0;
    int expiring48h = 0;
    int minHours = 168;
    UrgencyLevel highest = UrgencyLevel.safe;

    for (final EvidenceCaseRecord c in cases) {
      if (c.status != CaseSubmissionStatus.pending) continue;
      pending += 1;
      final int rem = TaiwanReportRepository.remainingHoursToReport(
        capturedAtUtc: c.capturedAtUtc,
        nowUtc: nowUtc,
      );
      if (rem < minHours) minHours = rem;
      if (rem <= 0) {
        expiring48h += 1;
        highest = UrgencyLevel.expired;
      } else if (rem <= criticalThresholdHours) {
        expiring48h += 1;
        if (highest != UrgencyLevel.expired) highest = UrgencyLevel.critical24h;
      } else if (rem <= warningThresholdHours) {
        expiring48h += 1;
        if (highest == UrgencyLevel.safe) highest = UrgencyLevel.warning48h;
      }
    }
    return UrgencyRadarSummary(
      pendingCount: pending,
      expiringWithin48hCount: expiring48h,
      mostUrgentHoursLeft: minHours,
      highestLevel: highest,
    );
  }

  static String buildAlertBannerText(
    UrgencyRadarSummary summary, {
    required bool isZh,
  }) {
    if (!summary.hasUrgentAlert) {
      return isZh
          ? '✅ 案件庫安全：目前 ${summary.pendingCount} 件待辦皆在 7 日法定舉發期內'
          : '✅ Vault Safe: ${summary.pendingCount} pending case(s) within 7-day limit';
    }
    return isZh
        ? '🚨 期限警報：有 ${summary.expiringWithin48hCount} 件違規存證僅剩 ${summary.mostUrgentHoursLeft} 小時即將逾越 7 日舉發期！'
        : '🚨 Urgency Alert: ${summary.expiringWithin48hCount} case(s) expire in ${summary.mostUrgentHoursLeft}h (7-day limit)!';
  }
}
