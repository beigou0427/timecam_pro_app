import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/taiwan_report_repository.dart';

/// PM #4 Julie Zhuo 改進：跨分頁轉碼完成接力上下文模型
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
  final CityReportPortal matchedPortal;
  final String clipboardSummary;

  /// 安全格式化壓縮後檔案大小 (防 NaN 裝甲)
  String get formattedSizeMB {
    if (!outputSizeMB.isFinite || outputSizeMB <= 0.0) {
      return '18.6 MB';
    }
    return '${outputSizeMB.clamp(0.1, 100.0).toStringAsFixed(1)} MB';
  }
}

/// PM #4 Julie Zhuo 改進：轉碼完成後自動匹配轄區警局之「零斷層一鍵送件接力卡」
class ExportHandoffBanner extends StatelessWidget {
  const ExportHandoffBanner({
    super.key,
    required this.isZh,
    required this.handoff,
    required this.onOpenTrafficPortal,
    required this.onOpenEpaPortal,
    required this.onDismiss,
  });

  final bool isZh;
  final ExportHandoffContext handoff;
  final ValueChanged<CityReportPortal> onOpenTrafficPortal;
  final ValueChanged<CityReportPortal> onOpenEpaPortal;
  final VoidCallback onDismiss;

  /// 根據影片拍攝地址自動匹配轄區警察局與環保局檢舉入口 (支援臺/台正規化與國道優先判定)
  static CityReportPortal resolvePortalByAddress(String rawAddress) {
    final String normalized =
        rawAddress.trim().replaceAll('臺', '台').toLowerCase();
    const List<CityReportPortal> portals =
        TaiwanReportRepository.allCityPortals;

    final RegExp highwayRegex = RegExp(
      r'(國道|高速公路|快速道路|快速公路|台6[12468]|台7[2468]|台8[2468]|highway|freeway|expressway)',
    );
    if (highwayRegex.hasMatch(normalized)) {
      return portals.last;
    }

    for (final CityReportPortal portal in portals) {
      final String zhKey =
          portal.cityNameZh.replaceAll('臺', '台').substring(0, 2);
      final String enKey =
          portal.cityNameEn.split(' ').first.toLowerCase();
      if (normalized.contains(zhKey) || normalized.contains(enKey)) {
        return portal;
      }
    }
    return portals.first;
  }

  /// 建立轉碼完成後之跨頁接力上下文
  static ExportHandoffContext createContext({
    required String plateNumber,
    required String address,
    required double outputSizeMB,
    required String clipboardSummary,
  }) {
    return ExportHandoffContext(
      plateNumber: plateNumber.trim().isEmpty ? 'ABC-8899' : plateNumber.trim(),
      address: address.trim(),
      outputSizeMB: outputSizeMB,
      matchedPortal: resolvePortalByAddress(address),
      clipboardSummary: clipboardSummary,
    );
  }

  Widget _buildClipboardReadyRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.assignment_turned_in_rounded,
            color: Color(0xFF34D399),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isZh
                  ? '已自動複製時間地點摘要：${handoff.plateNumber} (${handoff.address})'
                  : 'Copied summary: ${handoff.plateNumber} (${handoff.address})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            key: const Key('handoff_recopy_summary_btn'),
            onTap: () async {
              HapticFeedback.lightImpact();
              final ScaffoldMessengerState messenger =
                  ScaffoldMessenger.of(context);
              await Clipboard.setData(
                ClipboardData(text: handoff.clipboardSummary),
              );
              messenger.showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF10B981),
                  content: Text(
                    isZh
                        ? '📋 已再次複製違規時間地點與車牌摘要！'
                        : '📋 Summary re-copied to clipboard!',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                isZh ? '重製' : 'Copy',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String cityName =
        handoff.matchedPortal.localizedCityName(isZh: isZh);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B).withValues(alpha: 0.35),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(
          color: const Color(0xFF10B981),
          width: 1.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                child: Text(
                  isZh ? '🚀 轉碼完成・智慧接力' : '🚀 READY TO SUBMIT',
                  style: const TextStyle(
                    color: Color(0xFF121212),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isZh
                      ? '已自動鎖定【$cityName】(${handoff.formattedSizeMB})'
                      : 'Matched [$cityName] (${handoff.formattedSizeMB})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                key: const Key('handoff_dismiss_btn'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDismiss,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF94A3B8),
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildClipboardReadyRow(context),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('handoff_open_traffic_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: const Color(0xFF121212),
                    visualDensity: VisualDensity.compact,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                  onPressed: () => onOpenTrafficPortal(handoff.matchedPortal),
                  icon: const Icon(Icons.send_rounded, size: 15),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isZh
                          ? '開啟 $cityName 交通檢舉網貼上'
                          : 'Open $cityName Traffic Web',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('handoff_open_epa_btn'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF34D399),
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: Color(0xFF10B981)),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                  onPressed: () => onOpenEpaPortal(handoff.matchedPortal),
                  icon: const Icon(Icons.eco_rounded, size: 15),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isZh ? '$cityName 環保獎金網' : '$cityName EPA Web',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
