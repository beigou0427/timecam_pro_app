import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/epa_reward_calculator_engine.dart';
import '../../core/persona_positioning_engine.dart';
import '../../core/statutory_urgency_engine.dart';
import '../../core/taiwan_report_repository.dart';

class ConversionHookBanner extends StatelessWidget {
  const ConversionHookBanner({
    super.key,
    required this.isZh,
    required this.isProUnlocked,
    required this.activePersona,
    required this.cases,
    required this.onPersonaChanged,
    required this.onRequestPaywall,
  });

  final bool isZh;
  final bool isProUnlocked;
  final UserPersonaMode activePersona;
  final List<EvidenceCaseRecord> cases;
  final ValueChanged<UserPersonaMode> onPersonaChanged;
  final ValueChanged<String> onRequestPaywall;

  Widget _buildPersonaSelectorRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: UserPersonaMode.values.map((UserPersonaMode mode) {
          final bool selected = activePersona == mode;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: Key('persona_chip_${mode.name}'),
              label: Text(
                mode.localizedTitle(isZh: isZh),
                style: TextStyle(
                  color: selected ? const Color(0xFF121212) : Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              selected: selected,
              selectedColor: const Color(0xFFF59E0B),
              backgroundColor: const Color(0xFF0F172A),
              visualDensity: VisualDensity.compact,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                onPersonaChanged(mode);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  String _buildHookHeadline() {
    final UrgencyRadarSummary radar = StatutoryUrgencyEngine.scanCases(
      cases,
      DateTime.now().toUtc(),
    );
    if (radar.hasUrgentAlert) {
      return StatutoryUrgencyEngine.buildAlertBannerText(radar, isZh: isZh);
    }
    if (activePersona == UserPersonaMode.trafficEvidence) {
      final EpaRewardEstimate est = EpaRewardCalculatorEngine.calculateReward(
        cityId: 'taipei_city',
        item: EpaViolationItem.cigaretteButt,
      );
      return isZh
          ? '💰 拍煙蒂扣稅實領約 NT\$${est.netRewardAfterTaxNtd}（1件即賺回軟體）• 140MB 1秒壓進 19MB'
          : '💰 Est. NT\$${est.netRewardAfterTaxNtd} net EPA reward/case • Compress 4K under 19MB';
    }
    if (activePersona == UserPersonaMode.fieldEngineering) {
      return isZh
          ? '👷 1 秒匯出業主 A4 驗收 PDF ＋ 台灣統編核銷單（直接報公帳）'
          : '👷 Export A4 Inspection PDF + Corporate Expense Memo in 1 tap';
    }
    return isZh
        ? '📦 防偽 UTC+8 時間與 12 碼數位指紋 • 配送存證影片壓縮不失真'
        : '📦 Tamper-proof UTC+8 & 12-char seal • Lossless delivery clip compression';
  }

  @override
  Widget build(BuildContext context) {
    final String hookText = _buildHookHeadline();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.65),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildPersonaSelectorRow(),
          const SizedBox(height: 8),
          InkWell(
            key: const Key('conversion_hook_cta_row'),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            onTap: isProUnlocked
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    onRequestPaywall(
                      PersonaPositioningEngine.buildPersonaPaywallPitch(
                        activePersona,
                        isZh: isZh,
                      ),
                    );
                  },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                border: Border.all(
                  color: isProUnlocked
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      hookText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isProUnlocked
                            ? const Color(0xFF34D399)
                            : const Color(0xFFFDE68A),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (!isProUnlocked) ...<Widget>[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                      child: Text(
                        isZh ? '立即解鎖' : 'UNLOCK',
                        style: const TextStyle(
                          color: Color(0xFF121212),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
