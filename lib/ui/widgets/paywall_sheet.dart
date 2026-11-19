import '../../core/native_hardware_bridge.dart';
import '../../core/storekit_iap_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ariely_decoy_pricing_engine.dart';
import '../../core/epa_reward_calculator_engine.dart';
import '../../core/hormozi_grand_slam_offer_engine.dart';

enum ProPlanTier {
  b2bCrew(
    productId: 'com.beigou.timecampro.crew1990',
    titleZh: '工程班組 5 機包 (支援公司報帳)',
    titleEn: '5-Device Engineering Crew Pack',
    priceTextZh: r'NT$1,990',
    priceTextEn: r'$519.99',
    subNoteZh: r'平均每台僅 NT$398・自訂公司抬頭與 A4 驗收書',
    subNoteEn: r'Just $12/device • Custom company headers & PDF',
    badgeZh: '👷 B2B 工程團隊首選',
    badgeEn: '👷 B2B TEAM PACK',
  ),
  lifetime(
    productId: 'com.beigou.timecampro.lifetime590',
    titleZh: '旗艦終身買斷版 (全套解鎖)',
    titleEn: 'Flagship Lifetime (All Unlocked)',
    priceTextZh: r'NT$590',
    priceTextEn: r'$119.99',
    subNoteZh: r'只比年費多 NT$40 ➔ 永久終身＋法條＋12碼防偽',
    subNoteEn: r'Just $1 more than 1-Yr ➔ Own forever!',
    badgeZh: '🔥 68% 用戶首選・最划算',
    badgeEn: '🔥 BEST VALUE',
  ),
  annual(
    productId: 'com.beigou.timecampro.annual550',
    titleZh: '純年費基本授權 (1年期)',
    titleEn: 'Basic Annual License (1 Year)',
    priceTextZh: r'NT$550 / 年',
    priceTextEn: r'$18.99 / yr',
    subNoteZh: r'平均每日 NT$1.5・不含完整法條與12碼防偽章',
    subNoteEn: r'$18.99/yr • Renews annually',
    badgeZh: '1年期基礎版',
    badgeEn: '1-YEAR BASIC',
  ),
  monthly(
    productId: 'com.beigou.timecampro.monthly150',
    titleZh: '單月輕量體驗版',
    titleEn: 'Monthly Starter Plan',
    priceTextZh: r'NT$150 / 月',
    priceTextEn: r'$4.99 / mo',
    subNoteZh: '適合短期單次案件壓縮',
    subNoteEn: 'Flexible monthly access',
    badgeZh: '',
    badgeEn: '',
  );

  const ProPlanTier({
    required this.productId,
    required this.titleZh,
    required this.titleEn,
    required this.priceTextZh,
    required this.priceTextEn,
    required this.subNoteZh,
    required this.subNoteEn,
    required this.badgeZh,
    required this.badgeEn,
  });

  final String productId;
  final String titleZh;
  final String titleEn;
  final String priceTextZh;
  final String priceTextEn;
  final String subNoteZh;
  final String subNoteEn;
  final String badgeZh;
  final String badgeEn;

  String localizedTitle({required bool isZh}) => isZh ? titleZh : titleEn;
  String localizedPrice({required bool isZh}) => isZh ? priceTextZh : priceTextEn;
  String localizedSubNote({required bool isZh}) => isZh ? subNoteZh : subNoteEn;
  String localizedBadge({required bool isZh}) => isZh ? badgeZh : badgeEn;
}

class PulsingCtaButton extends StatefulWidget {
  const PulsingCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  State<PulsingCtaButton> createState() => _PulsingCtaButtonState();
}

class _PulsingCtaButtonState extends State<PulsingCtaButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.035).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: const Color(0xFF121212),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            elevation: 6,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
          ),
          onPressed: widget.isLoading
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  widget.onPressed();
                },
          child: widget.isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF121212),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(Icons.bolt_rounded, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.label,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class PaywallSheet extends StatefulWidget {
  const PaywallSheet({
    super.key,
    required this.isZh,
    required this.triggerReasonZh,
    required this.triggerReasonEn,
    required this.onUnlockSuccess,
  });
  final bool isZh;
  final String triggerReasonZh;
  final String triggerReasonEn;
  final ValueChanged<ProPlanTier> onUnlockSuccess;

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  ProPlanTier _selectedTier = ProPlanTier.lifetime;
  bool _isProcessing = false;

  Widget _buildLossAversionHeader() {
    final String reason =
        widget.isZh ? widget.triggerReasonZh : widget.triggerReasonEn;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFF59E0B),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reason,
              style: const TextStyle(
                color: Color(0xFFFDE68A),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisoryStackCard() {
    final String hormoziText = HormoziGrandSlamOfferEngine.buildValueStackHeadline(
      offerPriceNtd: 590,
      isZh: widget.isZh,
    );
    final EpaRewardEstimate roiEst = EpaRewardCalculatorEngine.calculateReward(
      cityId: 'taipei_city',
      item: EpaViolationItem.cigaretteButt,
    );
    final String roiText = EpaRewardCalculatorEngine.buildRoiPitchText(
      roiEst,
      isZh: widget.isZh,
    );
    final String arielyText = ArielyDecoyPricingEngine.buildDecoyComparisonPitch(
      isZh: widget.isZh,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  hormoziText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                child: Text(
                  widget.isZh ? '官方授權' : 'PRO',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            roiText,
            style: const TextStyle(
              color: Color(0xFF34D399),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            arielyText,
            style: const TextStyle(
              color: Color(0xFF38BDF8),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(ProPlanTier tier) {
    final bool isSelected = _selectedTier == tier;
    final String badge = tier.localizedBadge(isZh: widget.isZh);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        onTap: _isProcessing
            ? null
            : () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedTier = tier;
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF1E293B)
                : const Color(0xFF0F172A),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF334155),
              width: isSelected ? 2.2 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (badge.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Color(0xFF121212),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              Row(
                children: <Widget>[
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: isSelected
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF64748B),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          tier.localizedTitle(isZh: widget.isZh),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tier.localizedSubNote(isZh: widget.isZh),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tier.localizedPrice(isZh: widget.isZh),
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFF59E0B)
                            : Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ctaLabel() {
    switch (_selectedTier) {
      case ProPlanTier.b2bCrew:
        return widget.isZh
            ? r'解鎖 5 人工程班組包 (NT$1,990 可報帳)'
            : r'Unlock 5-Device Crew Pack ($519.99)';
      case ProPlanTier.lifetime:
        return widget.isZh
            ? r'立即以 NT$590 永久解鎖旗艦終身版'
            : r'Unlock Flagship Lifetime for $119.99';
      case ProPlanTier.annual:
        return widget.isZh
            ? r'訂閱 1 年期基本授權 (NT$550/年)'
            : r'Subscribe 1-Year Basic ($18.99/yr)';
      case ProPlanTier.monthly:
        return widget.isZh
            ? r'訂閱單月輕量體驗版 (NT$150/月)'
            : r'Subscribe Monthly ($4.99/mo)';
    }
  }

  Future<void> _iap(
    bool r) async { if (_isProcessing) return;
  final sm = ScaffoldMessenger.of(context);
  setState(() => _isProcessing = true);
  final t2 = r ? ProPlanTier.lifetime
    : _selectedTier; StorekitIapService.bind(() {
    if (mounted) widget.onUnlockSuccess(t2);});
  final e = await StorekitIapService.go(
    r, t2.productId);
  if (mounted == false) return;
  setState(() => _isProcessing = false);
  if (e is String) {
    sm.showSnackBar(SnackBar(content:Text(e)));
  } else if (StorekitIapService.isTest) {
    widget.onUnlockSuccess(t2);}}
  void _handlePurchase() => _iap(false);
  void _handleRestore() => _iap(true);
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFFF59E0B),
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isZh
                          ? '升級 時間相機 Pro 專業版'
                          : 'Upgrade to TimeCam Pro',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('paywall_close_btn'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildLossAversionHeader(),
              const SizedBox(height: 10),
              _buildAdvisoryStackCard(),
              const SizedBox(height: 12),
              for (final ProPlanTier tier in ProPlanTier.values)
                _buildPlanCard(tier),
              const SizedBox(height: 6),
              PulsingCtaButton(
                label: _ctaLabel(),
                isLoading: _isProcessing,
                onPressed: _handlePurchase,
              ),
              const SizedBox(height: 8),
              Wrap(alignment:WrapAlignment.center,
children: <Widget>[
                  TextButton(
                    key: const Key('paywall_restore_btn'),
                    onPressed: _isProcessing ? null : _handleRestore,
                    child: Text(
                      widget.isZh ? '恢復購買 (Restore)' : 'Restore Purchases',
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                TextButton(key:const Key('eula_btn'),onPressed:()=>NativeHardwareBridge.openOfficialPortalSafari('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),child:Text(widget.isZh?'服務條款':'EULA')),TextButton(key:const Key('privacy_btn'),onPressed:()=>NativeHardwareBridge.openOfficialPortalSafari('https://github.com/beigou0427/timecam_pro_app'),child:Text(widget.isZh?'隱私權':'Privacy')),],
              ),
              Text(
                widget.isZh
                    ? '確認購買後將由您的 Apple ID 扣款。終身與班組買斷版為一次付費永久有效；訂閱方案除非於當期結束前 24 小時於系統設定取消，否則將自動續訂。'
                    : 'Payment will be charged to your Apple ID. Lifetime & Crew packs are one-time purchases. Subscriptions auto-renew unless canceled 24h before period end.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
