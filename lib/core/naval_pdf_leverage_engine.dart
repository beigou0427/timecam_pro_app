import 'package:flutter/foundation.dart';

enum ReportDossierTheme {
  solarEngineering(
    titleZh: '外勤工程 / 太陽能案場巡檢驗收報告書',
    titleEn: 'Field Engineering & Solar Inspection Dossier',
  ),
  civilConstruction(
    titleZh: '營造施工安全與履約存證紀錄表',
    titleEn: 'Construction Compliance & Site Audit Log',
  ),
  trafficPetition(
    titleZh: '交通 / 環保現場採證時序彙整表',
    titleEn: 'Traffic & Environmental Evidence Summary',
  );

  const ReportDossierTheme({required this.titleZh, required this.titleEn});
  final String titleZh;
  final String titleEn;
  String localizedTitle({required bool isZh}) => isZh ? titleZh : titleEn;
}

@immutable
class DossierEntry {
  const DossierEntry({
    required this.sequenceNo,
    required this.utcPlus8Time,
    required this.address,
    required this.gpsText,
    required this.integritySealCode,
    required this.siteOrPlateNote,
  });
  final int sequenceNo;
  final String utcPlus8Time;
  final String address;
  final String gpsText;
  final String integritySealCode;
  final String siteOrPlateNote;
}

class NavalPdfLeverageEngine {
  const NavalPdfLeverageEngine._();
  static const int maxFreeDossierEntries = 1;

  static String escapeHtml(String raw) {
    return raw
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static List<DossierEntry> enforceExportLimit({
    required List<DossierEntry> entries,
    required bool isProUnlocked,
  }) {
    if (isProUnlocked || entries.length <= maxFreeDossierEntries) {
      return entries;
    }
    return entries.sublist(0, maxFreeDossierEntries);
  }

  static String buildDossierPaywallPitch({
    required int totalCount,
    required bool isZh,
  }) {
    final int safeCount = totalCount.clamp(1, 9999);
    if (isZh) {
      return '📄 免費版僅可匯出 1 筆試閱報告書；升級 B2B 工程版 (NT\$990) 立即解鎖全部 $safeCount 筆批次驗收表與 12 碼防偽簽章';
    }
    return '📄 Free tier exports 1 sample entry. Upgrade to B2B Pro to export all $safeCount entries with 12-char seals';
  }

  static String renderPrintableA4Html({
    required ReportDossierTheme theme,
    required String companyHeader,
    required List<DossierEntry> entries,
    required bool isProUnlocked,
    required bool isZh,
  }) {
    final List<DossierEntry> activeEntries = enforceExportLimit(
      entries: entries,
      isProUnlocked: isProUnlocked,
    );
    final String safeHeader = escapeHtml(
      companyHeader.trim().isEmpty ? 'TimeCam Pro Verified Log' : companyHeader.trim(),
    );
    final String title = escapeHtml(theme.localizedTitle(isZh: isZh));
    final StringBuffer rows = StringBuffer();
    for (final DossierEntry e in activeEntries) {
      rows.writeln(
        '<tr><td>${e.sequenceNo}</td><td>${escapeHtml(e.utcPlus8Time)}</td>'
        '<td>${escapeHtml(e.address)}<br><small>${escapeHtml(e.gpsText)}</small></td>'
        '<td>${escapeHtml(e.siteOrPlateNote)}</td>'
        '<td><code>${escapeHtml(e.integritySealCode)}</code></td></tr>',
      );
    }
    return '<!DOCTYPE html><html><head><meta charset="utf-8"><style>'
        '@page{size:A4;margin:14mm;}body{font-family:-apple-system,sans-serif;color:#111;}'
        'h2{margin:0 0 4px;}table{width:100%;border-collapse:collapse;margin-top:12px;font-size:12px;}'
        'th,td{border:1px solid #cbd5e1;padding:6px;text-align:left;}th{background:#f1f5f9;}'
        '</style></head><body><h2>$title</h2><div>$safeHeader</div>'
        '<table><thead><tr><th>No.</th><th>UTC+8</th><th>Location</th><th>Note</th><th>Seal</th></tr></thead>'
        '<tbody>${rows.toString()}</tbody></table>'
        '<p style="margin-top:24px;font-size:12px;">Sign-off: ____________________</p></body></html>';
  }
}
