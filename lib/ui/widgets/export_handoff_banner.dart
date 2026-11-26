import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/persona_positioning_engine.dart';
import '../../core/taiwan_report_repository.dart';

/// 轉碼完成接力上下文模型
@immutable
class ExportHandoffContext {
  const ExportHandoffContext({
    required this.plateNumber,
    required this.address,
    required this.outputSizeMB,
    required this.matchedPortal,
    required this.clipboardSummary,
  });

  final String plateNumber;
  final String address;
  final double outputSizeMB;
  final CityReportPortal? matchedPortal;
  final String clipboardSummary;

  String get formattedSizeMB {
    if (!outputSizeMB.isFinite || outputSizeMB <= 0.0) {
      return '18.6 MB';
    }
    return '${outputSizeMB.clamp(0.1, 100.0).toStringAsFixed(1)} MB';
  }
}

/// 轉碼完成接力卡（嚴格隔離模式與真實地區，並支援一鍵 PDF 與系統評分）
class ExportHandoffBanner extends StatelessWidget {
  const ExportHandoffBanner({
    super.key,
    required this.isZh,
    required this.handoff,
    required this.onOpenTrafficPortal,
    required this.onOpenEpaPortal,
    required this.onDismiss,
    this.activePersona = UserPersonaMode.fieldEngineering,
    this.onExportPdf,
    this.onRequestReview,
  });

  final bool isZh;
  final ExportHandoffContext handoff;
  final ValueChanged<CityReportPortal> onOpenTrafficPortal;
  final ValueChanged<CityReportPortal> onOpenEpaPortal;
  final VoidCallback onDismiss;
  final UserPersonaMode activePersona;
  final VoidCallback? onExportPdf;
  final VoidCallback? onRequestReview;

  /// 根據實際地址精準匹配對應台灣縣市或國道公開入口；若非台灣地址回傳 null（絕不誤導向台北）
  static CityReportPortal? resolvePortalByAddress(String rawAddress) {
    final String normalized =
        rawAddress.trim().replaceAll('臺', '台').toLowerCase();
    if (normalized.isEmpty) return null;

    const List<CityReportPortal> portals =
        TaiwanReportRepository.allCityPortals;

    final RegExp highwayRegex = RegExp(
      r'(國道|高速公路|快速道路|快速公路|台6[12468]|台7[2468]|台8[2468]|highway|freeway|expressway)',
    );
    if (highwayRegex.hasMatch(normalized)) {
      return portals.firstWhere(
        (CityReportPortal p) => p.id == 'highway_police',
        orElse: () => portals.first,
      );
    }

    // Pass 1: exact full city/county name match (disambiguates 新竹縣 vs 新竹市, 嘉義縣 vs 嘉義市, 新北市 vs 台北市, New Taipei vs Taipei City, 連江/馬祖)
    for (final CityReportPortal portal in portals) {
      if (portal.region == PortalRegion.national) continue;
      if (portal.id == 'taipei_city' &&
          (normalized.contains('新北') || normalized.contains('new taipei'))) {
        continue;
      }
      final String fullZh = portal.cityNameZh
          .replaceAll('臺', '台')
          .replaceAll(' (馬祖)', '')
          .toLowerCase();
      final String fullEn = portal.cityNameEn.toLowerCase();
      if (normalized.contains(fullZh) ||
          (portal.id == 'lienchiang' && normalized.contains('馬祖')) ||
          normalized.contains(fullEn)) {
        return portal;
      }
    }

    // Pass 2: short 2-char zh fallback only for unambiguous divisions
    for (final CityReportPortal portal in portals) {
      if (portal.region == PortalRegion.national) continue;
      final String fullZh =
          portal.cityNameZh.replaceAll('臺', '台').replaceAll(' (馬祖)', '');
      final String shortZh = fullZh.length >= 2 ? fullZh.substring(0, 2) : fullZh;
      if (shortZh == '新竹' || shortZh == '嘉義') continue;
      if (shortZh == '台北' && normalized.contains('新北')) continue;
      final String enFirst = portal.cityNameEn.split(' ').first.toLowerCase();
      if (normalized.contains(shortZh.toLowerCase()) ||
          (portal.id != 'taipei_city' &&
              enFirst.length >= 4 &&
              normalized.contains(enFirst))) {
        return portal;
      }
    }
    return null;
  }

  static ExportHandoffContext createContext({
    required String plateNumber,
    required String address,
    required double outputSizeMB,
    required String clipboardSummary,
  }) {
    final String cleanNote = plateNumber.trim();
    return ExportHandoffContext(
      plateNumber: cleanNote,
      address: address.trim(),
      outputSizeMB: outputSizeMB,
      matchedPortal: resolvePortalByAddress(address),
      clipboardSummary: clipboardSummary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final CityReportPortal? portal = handoff.matchedPortal;
    final bool showTaiwanTrafficPortals = isZh &&
        activePersona == UserPersonaMode.trafficEvidence &&
        portal != null;
    final String? cityName = portal?.localizedCityName(isZh: isZh);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(
          color: const Color(0xFF34C759).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF34C759),
                size: 16,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  showTaiwanTrafficPortals && cityName != null
                      ? '已匯出 ${handoff.formattedSizeMB}・對應 $cityName'
                      : (isZh
                          ? '已儲存至相簿 (${handoff.formattedSizeMB})'
                          : 'Saved to Photos (${handoff.formattedSizeMB})'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                key: const Key('handoff_dismiss_btn'),
                onTap: onDismiss,
                child: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF8E8E93),
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  handoff.plateNumber.isEmpty
                      ? (isZh ? '已準備本機影像摘要' : 'Timestamp summary ready')
                      : (isZh
                          ? '已複製摘要：${handoff.plateNumber}'
                          : 'Copied: ${handoff.plateNumber}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 12,
                  ),
                ),
              ),
              GestureDetector(
                key: const Key('handoff_recopy_summary_btn'),
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final ScaffoldMessengerState messenger =
                      ScaffoldMessenger.of(context);
                  await Clipboard.setData(
                    ClipboardData(text: handoff.clipboardSummary),
                  );
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                      persist: false,
                      backgroundColor: const Color(0xFF1F1F23),
                      content: Text(
                        isZh ? '已複製影像摘要' : 'Summary copied',
                        style: const TextStyle(
                          color: Color(0xFF34C759),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
                child: Text(
                  isZh ? '重新複製' : 'Copy',
                  style: const TextStyle(
                    color: Color(0xFFF5B73B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (showTaiwanTrafficPortals)
            Row(
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      key: const Key('handoff_open_traffic_btn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF34C759),
                        foregroundColor: const Color(0xFF09090B),
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                      onPressed: () => onOpenTrafficPortal(portal),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '開啟 ${cityName!} 交通官網',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      key: const Key('handoff_open_epa_btn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF232326),
                        foregroundColor: const Color(0xFFE4E4E7),
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                      onPressed: () => onOpenEpaPortal(portal),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '環保通報官網',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: <Widget>[
                if (onExportPdf != null)
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        key: const Key('handoff_export_pdf_btn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF5B73B),
                          foregroundColor: const Color(0xFF09090B),
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                        onPressed: onExportPdf,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isZh ? '匯出 A4 PDF 報告' : 'Export A4 PDF',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (onExportPdf != null && onRequestReview != null)
                  const SizedBox(width: 8),
                if (onRequestReview != null)
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: OutlinedButton(
                        key: const Key('handoff_rate_app_btn'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE4E4E7),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                        onPressed: onRequestReview,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isZh ? '覺得好用・評分鼓勵' : 'Rate TimeCam Pro',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
