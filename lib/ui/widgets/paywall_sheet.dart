import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pro 專業版三層誘餌定價方案列舉
enum ProPlanTier {
  /// 主力高轉換方案：終身買斷 (一次付費，永久解鎖)
  lifetime(
    productId: 'com.beigou.timecampro.lifetime',
    titleZh: 'Pro 終身買斷版 (永久解鎖)',
    titleEn: 'Pro Lifetime (One-Time Purchase)',
    priceTextZh: r'NT$290',
    priceTextEn: r'$9.99',
    subNoteZh: '一次付費永久使用・省下每次剪片轉檔 15 分鐘',
    subNoteEn: 'Pay once, own forever. No recurring fees.',
    badgeZh: '🔥 85% 車友首選・最划算',
    badgeEn: '🔥 BEST VALUE',
  ),

  /// 免費試用錨點方案：年度訂閱 (含 3 天免費試用)
  annual(
    productId: 'com.beigou.timecampro.annual',
    titleZh: 'Pro 年度專業版 (含3天免費試用)',
    titleEn: 'Pro Annual (3-Day Free Trial)',
    priceTextZh: r'NT$590 / 年',
    priceTextEn: r'$19.99 / yr',
    subNoteZh: r'平均每日僅 NT$1.6・隨時可於設定取消',
    subNoteEn: r'Just $0.05/day. Cancel anytime in Settings.',
    badgeZh: '免費試用 3 天',
    badgeEn: '3-DAY FREE TRIAL',
  ),

  /// 價格對照錨點：月度訂閱
  monthly(
    productId: 'com.beigou.timecampro.monthly',
    titleZh: 'Pro 單月體驗版',
    titleEn: 'Pro Monthly Plan',
    priceTextZh: r'NT$90 / 月',
    priceTextEn: r'$2.99 / mo',
    subNoteZh: '適合短期外勤專案或單次大宗案件整理',
    subNoteEn: 'Flexible monthly access for short-term projects.',
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
  String localizedPrice({required bool isZh}) =>
      isZh ? priceTextZh : priceTextEn;
  String localizedSubNote({required bool isZh}) =>
      isZh ? subNoteZh : subNoteEn;
  String localizedBadge({required bool isZh}) => isZh ? badgeZh : badgeEn;
}

/// 1250ms 非整數週期高轉化呼吸脈衝行動呼籲按鈕
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

/// 高轉化 Pro 解鎖付費牆底部彈窗 (支援損失規避情境動態標題)
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
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String textZh, String textEn) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF10B981),
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.isZh ? textZh : textEn,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
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
      padding: const EdgeInsets.only(bottom: 10),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Color(0xFF121212),
                      fontSize: 11,
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
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tier.localizedSubNote(isZh: widget.isZh),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
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
                        fontSize: 17,
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
      case ProPlanTier.lifetime:
        return widget.isZh
            ? r'立即以 NT$290 永久解鎖 Pro'
            : r'Unlock Lifetime Pro for $9.99';
      case ProPlanTier.annual:
        return widget.isZh
            ? r'開始 3 天免費試用 (之後 NT$590/年)'
            : r'Start 3-Day Free Trial ($19.99/yr)';
      case ProPlanTier.monthly:
        return widget.isZh
            ? r'立即訂閱單月版 (NT$90/月)'
            : r'Subscribe Monthly ($2.99/mo)';
    }
  }

  Future<void> _handlePurchase() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
    });
    widget.onUnlockSuccess(_selectedTier);
  }

  Future<void> _handleRestore() async {
    if (_isProcessing) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isProcessing = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
    });
    widget.onUnlockSuccess(ProPlanTier.lifetime);
  }

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
              const SizedBox(height: 14),
              _buildFeatureRow(
                '無限制 20MB / 10MB 檢舉影片智能位元率壓縮匯出',
                'Unlimited 20MB / 10MB Smart Bitrate Video Compression',
              ),
              _buildFeatureRow(
                '解鎖全台道交條例（未禮讓行人/逼車/煙蒂獎金）標準模板',
                'Unlock All Traffic & EPA Reward Report Templates',
              ),
              _buildFeatureRow(
                '移除照片與影片右下角官方品牌微浮水印標章',
                'Remove Brand Watermark Badge from Photos & Videos',
              ),
              _buildFeatureRow(
                '自訂外勤工程案場抬頭、車牌號碼與防偽 UTC+8 認證章',
                'Custom Project Header, Plate Note & UTC+8 Seal',
              ),
              const SizedBox(height: 14),
              for (final ProPlanTier tier in ProPlanTier.values)
                _buildPlanCard(tier),
              const SizedBox(height: 6),
              PulsingCtaButton(
                label: _ctaLabel(),
                isLoading: _isProcessing,
                onPressed: _handlePurchase,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                ],
              ),
              Text(
                widget.isZh
                    ? '確認購買後將由您的 Apple ID 扣款。終身買斷版為一次付費永久有效；訂閱方案除非於當期結束前 24 小時於系統設定取消，否則將自動續訂。'
                    : 'Payment will be charged to your Apple ID. Lifetime plan is a one-time purchase. Subscriptions auto-renew unless canceled 24 hours before period end.',
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