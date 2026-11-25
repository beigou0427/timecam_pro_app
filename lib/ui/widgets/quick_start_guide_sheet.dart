import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuickStartGuideSheet extends StatefulWidget {
  const QuickStartGuideSheet({
    super.key,
    required this.isZh,
    required this.onJumpToTab,
    required this.onOpenSettings,
    this.onContactSupport,
    this.isTestMode = false,
  });

  final bool isZh;
  final ValueChanged<int> onJumpToTab;
  final VoidCallback onOpenSettings;
  final VoidCallback? onContactSupport;
  final bool isTestMode;

  @override
  State<QuickStartGuideSheet> createState() => _QuickStartGuideSheetState();
}

class _QuickStartGuideSheetState extends State<QuickStartGuideSheet> {
  int? _expandedFaqIndex = 0;

  void _jumpTo(int tabIndex) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
    widget.onJumpToTab(tabIndex);
  }

  Widget _buildStepCard({
    required String stepKey,
    required String stepNo,
    required String title,
    required String subtitle,
    required String actionLabel,
    required int targetTab,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF5B73B).withValues(alpha: 0.16),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: Text(
              stepNo,
              style: const TextStyle(
                color: Color(0xFFF5B73B),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            key: Key(stepKey),
            onTap: () => _jumpTo(targetTab),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: const BoxDecoration(
                color: Color(0xFF2C2C2E),
                borderRadius: BorderRadius.all(Radius.circular(9)),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: Color(0xFFF5B73B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem({
    required int index,
    required String question,
    required String answer,
    Widget? footer,
  }) {
    final bool expanded = _expandedFaqIndex == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _expandedFaqIndex = expanded ? null : index;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      question,
                      style: const TextStyle(
                        color: Color(0xFFF5F5F7),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF8E8E93),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    answer,
                    style: const TextStyle(
                      color: Color(0xFFA1A1AA),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  if (footer != null) ...<Widget>[
                    const SizedBox(height: 10),
                    footer,
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double maxH = MediaQuery.of(context).size.height * 0.86;
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
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
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
                      borderRadius: const BorderRadius.all(Radius.circular(99)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.isZh ? '30 秒快速上手' : '30-Second Quick Guide',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.isZh
                                ? '點右側按鈕可直接跳至對應功能'
                                : 'Tap any action button to jump right in',
                            style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('quick_guide_close_btn'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStepCard(
                  stepKey: 'guide_jump_tab_0',
                  stepNo: '01',
                  title: widget.isZh
                      ? '一秒拍時間地點存證照'
                      : 'Instant Timestamp Photo',
                  subtitle: widget.isZh
                      ? '即時抓取真實 GPS 地址與系統時間，並附上 SHA-256 數位校驗碼。'
                      : 'Captures live GPS address, local timestamp & SHA-256 file hash.',
                  actionLabel: widget.isZh ? '去拍照' : 'Shoot',
                  targetTab: 0,
                ),
                _buildStepCard(
                  stepKey: 'guide_jump_tab_0_note',
                  stepNo: '02',
                  title: widget.isZh
                      ? '場景模式切換 & 自訂企業抬頭'
                      : 'Persona Modes & Company Header',
                  subtitle: widget.isZh
                      ? '可切換工程巡檢、配送簽收或行車蒐證；行車模式支援 AI 辨識車牌與快捷鍵盤。'
                      : 'Switch between Engineering, Logistics & Traffic modes; AI OCR included in Traffic mode.',
                  actionLabel: widget.isZh ? '去設定' : 'Setup',
                  targetTab: 0,
                ),
                _buildStepCard(
                  stepKey: 'guide_jump_tab_1',
                  stepNo: '03',
                  title: widget.isZh
                      ? '4K 影片位元率壓縮進 20MB'
                      : 'Shrink 4K Video Under 20MB',
                  subtitle: widget.isZh
                      ? '從相簿選片 → 拖曳起訖裁切秒數 → 依真實目標容量硬體轉碼保存。'
                      : 'Pick video → trim exact range → hardware H.264 export under target size.',
                  actionLabel: widget.isZh ? '去壓縮' : 'Compress',
                  targetTab: 1,
                ),
                _buildStepCard(
                  stepKey: 'guide_jump_tab_2',
                  stepNo: '04',
                  title: widget.isZh
                      ? '匯出 A4 驗收 PDF 與備份紀錄'
                      : 'A4 Inspection PDF & Local Backup',
                  subtitle: widget.isZh
                      ? '拍完自動歸檔案件夾，含現場縮圖與真實 GPS 座標，可一鍵匯出 PDF 或 JSON 備份。'
                      : 'Auto-logs captures with thumbnails & real GPS; export A4 PDF or JSON backup.',
                  actionLabel: widget.isZh ? '看案件' : 'Cases',
                  targetTab: 2,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.isZh ? '常見問題' : 'Quick FAQ',
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _buildFaqItem(
                  index: 0,
                  question: widget.isZh
                      ? '沒顯示真實門牌或無法存相簿怎麼辦？'
                      : 'No GPS address or unable to save photo?',
                  answer: widget.isZh
                      ? '請確認已允許「定位（使用期間）」與「照片（加入或完整取用）」權限；我們絕不以假座標替代，開啟權限後點左上角「同步定位」即可取得真實地址。'
                      : 'Ensure Location and Photos permissions are granted in iOS Settings, then tap Sync GPS on the camera screen.',
                  footer: GestureDetector(
                    key: const Key('guide_open_ios_settings_btn'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onOpenSettings();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5B73B),
                        borderRadius: BorderRadius.all(Radius.circular(9)),
                      ),
                      child: Text(
                        widget.isZh ? '打開 iPhone 權限設定' : 'Open iOS Settings',
                        style: const TextStyle(
                          color: Color(0xFF09090B),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                _buildFaqItem(
                  index: 1,
                  question: widget.isZh
                      ? '照片、定位與案件縮圖如何保障隱私？'
                      : 'How is my photo, GPS & thumbnail privacy protected?',
                  answer: widget.isZh
                      ? '拍攝與壓縮檔案直接存入您的 iPhone「照片」；App 內案件與縮圖均啟用 FileProtection 保護且不加入 iCloud 備份。地址轉換透過 Apple 原生逆地理編碼服務即時查詢，不經任何開發者伺服器。'
                      : 'Media saves directly to Photos. Internal logs & thumbnails use FileProtection and exclude iCloud backup. Address lookup uses Apple Geocoding directly.',
                ),
                _buildFaqItem(
                  index: 2,
                  question: widget.isZh
                      ? '換手機或重裝 App 如何恢復 Pro？'
                      : 'How do I restore Pro on a new iPhone?',
                  answer: widget.isZh
                      ? '點畫面右上角「Pro」鈕後點擊「恢復購買」，系統將向 Apple StoreKit 核對您的 Apple ID 有效授權後免費還原，不會重複扣款。'
                      : 'Tap Pro at top-right, then tap Restore to verify active StoreKit entitlements under your Apple ID.',
                ),
                _buildFaqItem(
                  index: 3,
                  question: widget.isZh
                      ? '公司行號購買可以開立統一編號發票報帳嗎？'
                      : 'Can I receive a corporate tax receipt for expense claims?',
                  answer: widget.isZh
                      ? 'App Store 內購款項由 Apple 官方代收並寄送「Apple 電子收據」至您的 Apple ID 信箱（屬境外平台憑證，不含台灣三聯式統一編號，無法扣抵營業稅進項）。如需向公司請款報帳，購買前請先確認貴公司財務之境外電子憑證報支規定；本授權亦僅限單一 Apple ID 使用。'
                      : 'App Store purchases are billed by Apple, which sends an official Apple electronic receipt to your Apple ID email (no local VAT invoice ID). Please verify your company finance rules before expensing.',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    key: const Key('guide_support_feedback_btn'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD4D4D8),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                      widget.onContactSupport?.call();
                    },
                    icon: const Icon(Icons.mail_outline_rounded, size: 17),
                    label: Text(
                      widget.isZh
                          ? '回報問題 / 聯絡開發者客服'
                          : 'Report Issue / Contact Support',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

/// 首次進入各分頁時顯示的輕量單行微提示條
class FirstTimeTipBar extends StatelessWidget {
  const FirstTimeTipBar({
    super.key,
    required this.text,
    required this.onDismiss,
    this.closeKey,
  });

  final String text;
  final VoidCallback? onDismiss;
  final Key? closeKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: const BorderRadius.all(Radius.circular(11)),
        border: Border.all(
          color: const Color(0xFFF5B73B).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF5B73B),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFD4D4D8),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            key: closeKey,
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onDismiss?.call();
            },
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 15,
                color: Color(0xFF8E8E93),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
