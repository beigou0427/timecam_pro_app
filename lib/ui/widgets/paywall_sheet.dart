import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/native_hardware_bridge.dart';

enum ProPlanTier {
  annual(
    productId: 'com.beigou.timecampro.annual550',
    titleZh: '年訂閱',
    titleEn: 'Annual Pro',
    priceTextZh: r'NT$550 / 年',
    priceTextEn: r'$18.99 / yr',
    subNoteZh: '年付最超值・可隨時於系統設定取消',
    subNoteEn: 'Best value • Cancel anytime in Settings',
    badgeZh: '最受歡迎 · 超值推薦',
    badgeEn: 'MOST POPULAR',
  ),
  lifetime(
    productId: 'com.beigou.timecampro.lifetime590',
    titleZh: '終身買斷版',
    titleEn: 'Lifetime Pro',
    priceTextZh: r'NT$1,290',
    priceTextEn: r'$39.99',
    subNoteZh: '一次付費，單一 Apple ID 永久解鎖',
    subNoteEn: 'One-time purchase, yours forever',
    badgeZh: '永久買斷',
    badgeEn: 'ONE-TIME',
  ),
  // 僅保留供 StoreKit 既有舊購買者還原辨識，UI 不再販售空殼團隊多機授權
  b2bCrew(
    productId: 'com.beigou.timecampro.crew1990',
    titleZh: '商用買斷版',
    titleEn: 'Commercial Lifetime',
    priceTextZh: r'NT$1,990',
    priceTextEn: r'$59.99',
    subNoteZh: '單一帳號進階永久授權',
    subNoteEn: 'Commercial lifetime entitlement',
    badgeZh: '',
    badgeEn: '',
  ),
  monthly(
    productId: 'com.beigou.timecampro.monthly150',
    titleZh: '月訂閱',
    titleEn: 'Monthly Pro',
    priceTextZh: r'NT$150 / 月',
    priceTextEn: r'$4.99 / mo',
    subNoteZh: '彈性月付，可隨時於系統設定取消',
    subNoteEn: 'Flexible monthly • Cancel anytime',
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

  bool get isSubscription =>
      this == ProPlanTier.annual || this == ProPlanTier.monthly;

  String localizedTitle({required bool isZh}) => isZh ? titleZh : titleEn;
  String localizedPrice({required bool isZh}) =>
      isZh ? priceTextZh : priceTextEn;
  String localizedSubNote({required bool isZh}) =>
      isZh ? subNoteZh : subNoteEn;
  String localizedBadge({required bool isZh}) => isZh ? badgeZh : badgeEn;

  static ProPlanTier fromProductId(String productId) {
    for (final ProPlanTier tier in ProPlanTier.values) {
      if (tier.productId == productId) return tier;
    }
    return ProPlanTier.lifetime;
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
  ProPlanTier _selectedTier = ProPlanTier.annual;
  bool _showMonthlyPlan = false;
  bool _isProcessing = false;
  bool _isLoadingProducts = false;
  Map<String, Map<String, dynamic>> _sk2Products =
      <String, Map<String, dynamic>>{};

  static const String _eulaUrl =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  static const String _privacyUrl =
      'https://beigou0427.github.io/timecam_pro_app/privacy.html';
  static const String _manageSubsUrl =
      'https://apps.apple.com/account/subscriptions';

  static const List<ProPlanTier> _sellableTiers = <ProPlanTier>[
    ProPlanTier.annual,
    ProPlanTier.lifetime,
    ProPlanTier.monthly,
  ];

  @override
  void initState() {
    super.initState();
    _sk2Products = Map<String, Map<String, dynamic>>.from(
      NativeHardwareBridge.cachedStoreKit2Products,
    );
    _isLoadingProducts =
        NativeHardwareBridge.isLiveIosRuntime && _sk2Products.isEmpty;
    _loadStorePrices();
  }

  Future<void> _loadStorePrices() async {
    if (!NativeHardwareBridge.isLiveIosRuntime) return;
    final Set<String> ids =
        _sellableTiers.map((ProPlanTier t) => t.productId).toSet();
    final Map<String, Map<String, dynamic>> loaded =
        await NativeHardwareBridge.fetchStoreKit2Products(ids);
    if (!mounted) return;
    setState(() {
      if (loaded.isNotEmpty) {
        _sk2Products = loaded;
      }
      _isLoadingProducts = false;
    });
  }

  String _displayPrice(ProPlanTier tier) {
    final Map<String, dynamic>? live = _sk2Products[tier.productId];
    final String displayPrice = live?['displayPrice']?.toString() ?? '';
    if (displayPrice.isNotEmpty) {
      if (tier == ProPlanTier.annual) {
        return widget.isZh ? '$displayPrice / 年' : '$displayPrice / yr';
      }
      if (tier == ProPlanTier.monthly) {
        return widget.isZh ? '$displayPrice / 月' : '$displayPrice / mo';
      }
      return displayPrice;
    }
    if (NativeHardwareBridge.isLiveIosRuntime && _isLoadingProducts) {
      return '...';
    }
    return tier.localizedPrice(isZh: widget.isZh);
  }

  String _dynamicSubNote(ProPlanTier tier) {
    if (tier == ProPlanTier.annual) {
      final Map<String, dynamic>? live = _sk2Products[tier.productId];
      final double? rawPrice = (live?['price'] as num?)?.toDouble();
      if (rawPrice != null && rawPrice > 0) {
        final double daily = rawPrice / 365.0;
        final String cur = live?['currencyCode']?.toString() ?? '';
        return widget.isZh
            ? '平均約 $cur ${daily.toStringAsFixed(1)} / 日・隨時可取消'
            : 'Approx. $cur ${daily.toStringAsFixed(2)} / day • Cancel anytime';
      }
    }
    return tier.localizedSubNote(isZh: widget.isZh);
  }

  Widget _buildBenefitsList() {
    final List<String> features = <String>[
      widget.isZh
          ? '完整多筆匯出 A4 驗收報告 PDF（含縮圖直傳 LINE / Email）'
          : 'Full batch A4 inspection PDF reports with photos',
      widget.isZh
          ? '自訂專屬公司抬頭・可隱藏預設品牌角標'
          : 'Custom company header & hide default brand mark',
      widget.isZh
          ? '無限次 20MB / 10MB 4K 影片位元率壓縮匯出'
          : 'Unlimited 20MB & 10MB hardware video exports',
      widget.isZh
          ? '完整 SHA-256 檔案校驗碼與本機完整紀錄備份'
          : 'Full SHA-256 integrity hash & local JSON record backup',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features.map((String line) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Color(0xFFF5B73B),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  line,
                  style: const TextStyle(
                    color: Color(0xFFE4E4E7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlanRow(ProPlanTier tier) {
    final bool isSelected = _selectedTier == tier;
    final String badge = tier.localizedBadge(isZh: widget.isZh);
    final String priceLabel = _displayPrice(tier);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: _isProcessing
            ? null
            : () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTier = tier);
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color:
                isSelected ? const Color(0xFF232326) : const Color(0xFF161618),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFF5B73B)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        Text(
                          tier.localizedTitle(isZh: widget.isZh),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (badge.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5B73B)
                                  .withValues(alpha: 0.18),
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(5)),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: Color(0xFFF5B73B),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _dynamicSubNote(tier),
                      style: const TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                priceLabel,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFF5B73B) : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ctaLabel() {
    final String price = _displayPrice(_selectedTier);
    switch (_selectedTier) {
      case ProPlanTier.lifetime:
      case ProPlanTier.b2bCrew:
        return widget.isZh ? '解鎖終身版 · $price' : 'Unlock Lifetime · $price';
      case ProPlanTier.annual:
        return widget.isZh ? '開始年訂閱 · $price' : 'Subscribe Yearly · $price';
      case ProPlanTier.monthly:
        return widget.isZh ? '開始月訂閱 · $price' : 'Subscribe Monthly · $price';
    }
  }

  Future<void> _executeBuy() async {
    if (_isProcessing) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);

    if (!NativeHardwareBridge.isLiveIosRuntime) {
      setState(() => _isProcessing = false);
      widget.onUnlockSuccess(_selectedTier);
      return;
    }

    final Map<String, dynamic>? res =
        await NativeHardwareBridge.purchaseStoreKit2Product(
      _selectedTier.productId,
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);

    final String status = res?['status']?.toString() ?? 'error';
    if (status == 'purchased') {
      final String purchasedId =
          res?['productId']?.toString() ?? _selectedTier.productId;
      widget.onUnlockSuccess(ProPlanTier.fromProductId(purchasedId));
      return;
    }
    if (status == 'canceled') {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          persist: false,
          backgroundColor: const Color(0xFF1F1F23),
          content: Text(
            widget.isZh ? '已取消購買' : 'Purchase canceled',
            style: const TextStyle(color: Color(0xFFE4E4E7)),
          ),
        ),
      );
      return;
    }
    if (status == 'pending') {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          persist: false,
          backgroundColor: const Color(0xFF1F1F23),
          content: Text(
            widget.isZh
                ? '購買等待核准，核准後將自動解鎖'
                : 'Purchase pending approval; unlocks once approved.',
            style: const TextStyle(color: Color(0xFFF5B73B)),
          ),
        ),
      );
      return;
    }

    final String errMsg = res?['message']?.toString() ??
        (widget.isZh
            ? '購買失敗，請確認網路與 Apple ID 設定後重試'
            : 'Purchase failed. Check connection & Apple ID.');
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        persist: false,
        backgroundColor: const Color(0xFFFF453A),
        content: Text(errMsg),
      ),
    );
  }

  Future<void> _executeRestore() async {
    if (_isProcessing) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);

    if (!NativeHardwareBridge.isLiveIosRuntime) {
      setState(() => _isProcessing = false);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          persist: false,
          backgroundColor: const Color(0xFF1F1F23),
          content: Text(
            widget.isZh
                ? '目前此 Apple ID 查無有效購買紀錄'
                : 'No active purchases found for this Apple ID.',
            style: const TextStyle(color: Color(0xFFE4E4E7)),
          ),
        ),
      );
      return;
    }

    final List<String>? activeIds =
        await NativeHardwareBridge.syncStoreKitRestore();
    if (!mounted) return;
    setState(() => _isProcessing = false);

    final Set<String> knownIds =
        ProPlanTier.values.map((ProPlanTier t) => t.productId).toSet();
    final String? matchedId = activeIds?.cast<String?>().firstWhere(
          (String? id) => id != null && knownIds.contains(id),
          orElse: () => null,
        );

    if (matchedId != null) {
      widget.onUnlockSuccess(ProPlanTier.fromProductId(matchedId));
      return;
    }

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        persist: false,
        backgroundColor: const Color(0xFF1F1F23),
        content: Text(
          widget.isZh
              ? '查無可恢復的有效訂閱或買斷紀錄'
              : 'No active Pro purchase or subscription found.',
          style: const TextStyle(
            color: Color(0xFFE4E4E7),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double maxH = MediaQuery.of(context).size.height * 0.9;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0E0E10),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(99)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.isZh ? '升級時間相機 Pro' : 'TimeCam Pro',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('paywall_close_btn'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (BuildContext ctx) {
                    final String reason = (widget.isZh
                            ? widget.triggerReasonZh
                            : widget.triggerReasonEn)
                        .trim();
                    if (reason.isEmpty) return const SizedBox.shrink();
                    return Container(
                      key: const Key('paywall_trigger_reason_box'),
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5B73B).withValues(alpha: 0.12),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(11)),
                        border: Border.all(
                          color: const Color(0xFFF5B73B)
                              .withValues(alpha: 0.34),
                        ),
                      ),
                      child: Text(
                        reason,
                        style: const TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    );
                  },
                ),
                _buildBenefitsList(),
                const SizedBox(height: 14),
                for (final ProPlanTier tier in _sellableTiers)
                  if (_showMonthlyPlan ||
                      tier == ProPlanTier.annual ||
                      tier == ProPlanTier.lifetime ||
                      tier == _selectedTier)
                    _buildPlanRow(tier),
                if (!_showMonthlyPlan)
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      key: const Key('paywall_more_plans_btn'),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showMonthlyPlan = true);
                      },
                      child: Text(
                        widget.isZh
                            ? '顯示彈性月訂閱方案 ▾'
                            : 'Show Monthly Plan ▾',
                        style: const TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    key: const Key('paywall_primary_cta_btn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5B73B),
                      foregroundColor: const Color(0xFF09090B),
                      elevation: 0,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                    ),
                    onPressed: _isProcessing ? null : _executeBuy,
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Color(0xFF09090B),
                            ),
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _ctaLabel(),
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      TextButton(
                        key: const Key('paywall_restore_btn'),
                        onPressed: _isProcessing ? null : _executeRestore,
                        child: Text(
                          widget.isZh ? '恢復購買' : 'Restore',
                          style: const TextStyle(
                            color: Color(0xFFE4E4E7),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('paywall_manage_subs_btn'),
                        onPressed: () =>
                            NativeHardwareBridge.openExternalUrl(
                          _manageSubsUrl,
                        ),
                        child: Text(
                          widget.isZh ? '管理訂閱' : 'Manage Sub',
                          style: const TextStyle(
                            color: Color(0xFFA1A1AA),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('eula_btn'),
                        onPressed: () =>
                            NativeHardwareBridge.openOfficialPortalSafari(
                          _eulaUrl,
                        ),
                        child: Text(
                          widget.isZh ? '條款' : 'Terms',
                          style: const TextStyle(
                            color: Color(0xFFA1A1AA),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('privacy_btn'),
                        onPressed: () =>
                            NativeHardwareBridge.openOfficialPortalSafari(
                          _privacyUrl,
                        ),
                        child: Text(
                          widget.isZh ? '隱私權' : 'Privacy',
                          style: const TextStyle(
                            color: Color(0xFFA1A1AA),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isZh
                      ? '確認購買後將向您的 Apple ID 帳號扣款。買斷版永久有效；訂閱方案於當前週期結束前 24 小時自動續訂並扣款，您可隨時前往「iPhone 設定 > Apple ID > 訂閱項目」或點上方「管理訂閱」取消。'
                      : 'Payment is charged to your Apple ID at confirmation. Lifetime unlocks permanently. Subscriptions auto-renew unless canceled at least 24h before period end in Apple ID Subscriptions.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFA1A1AA),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
