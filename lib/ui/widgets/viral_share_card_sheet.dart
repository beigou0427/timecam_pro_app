import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/taiwan_report_repository.dart';

/// PM #6 Brian Balfour 成長飛輪改進：社群戰報隱私打碼模式列舉 (符合 Apple 1.2 防公審規範)
enum SharePrivacyMaskMode {
  /// 公開社群安全模式：自動將車牌中間碼打星號 (例: ABC-**99)，適合發 Threads / FB / PTT
  maskMiddlePlate(
    labelZh: '社群安全打碼 (ABC-**99)',
    labelEn: 'Public Safe Mask (ABC-**99)',
  ),

  /// 完整顯示模式：適合傳送至公司內部工程驗收群組或個人備份
  fullUnmasked(
    labelZh: '完整顯示 (內部驗收/備份)',
    labelEn: 'Full Details (Internal Backup)',
  ),

  /// 高度匿名模式：隱藏車牌後四碼與詳細門牌號
  strictAnonymous(
    labelZh: '高度匿名 (僅顯示路段)',
    labelEn: 'Strict Anonymous',
  );

  const SharePrivacyMaskMode({
    required this.labelZh,
    required this.labelEn,
  });

  final String labelZh;
  final String labelEn;

  String localizedLabel({required bool isZh}) => isZh ? labelZh : labelEn;
}

/// PM #6 Brian Balfour 改進：一鍵生成 Threads / LINE 違規存證與外勤驗收社群戰報分享卡
class ViralShareCardSheet extends StatefulWidget {
  const ViralShareCardSheet({
    super.key,
    required this.isZh,
    required this.record,
    required this.statute,
  });

  final bool isZh;
  final EvidenceCaseRecord record;
  final TrafficStatuteTemplate statute;

  /// 根據隱私模式自動將車牌號碼中間碼打星號 (例: ABC-8899 -> ABC-**99)，防止公開社群個資爭議
  static String maskPlateText(
    String rawPlateOrNote,
    SharePrivacyMaskMode mode,
  ) {
    final String clean = rawPlateOrNote.trim();
    if (clean.isEmpty) return 'ABC-**99';
    if (mode == SharePrivacyMaskMode.fullUnmasked) {
      return clean;
    }
    if (mode == SharePrivacyMaskMode.strictAnonymous) {
      return clean.replaceAllMapped(
        RegExp(r'([A-Z0-9]{2,3}-)[A-Z0-9]{2,4}'),
        (Match m) => '${m.group(1)}****',
      );
    }
    return clean.replaceAllMapped(
      RegExp(r'([A-Z0-9]{2,3}-)([A-Z0-9]{2})([A-Z0-9]{1,2})'),
      (Match m) => '${m.group(1)}**${m.group(3)}',
    );
  }

  /// 根據隱私模式自動將詳細門牌號打碼 (例: 22號 -> **號)
  static String maskAddressText(
    String rawAddress,
    SharePrivacyMaskMode mode,
  ) {
    final String clean = rawAddress.trim();
    if (mode != SharePrivacyMaskMode.strictAnonymous) {
      return clean;
    }
    return clean.replaceAll(RegExp(r'\d+號'), '**號');
  }

  /// 生成高傳播力之 Threads / LINE / PTT 違規存證與外勤巡檢社群戰報文案
  static String buildViralPostText({
    required EvidenceCaseRecord record,
    required TrafficStatuteTemplate statute,
    required SharePrivacyMaskMode maskMode,
    required bool isZh,
  }) {
    final String safePlate = maskPlateText(record.plateOrNote, maskMode);
    final String safeAddr = maskAddressText(record.address, maskMode);
    final String sizeStr = record.compressedSizeMB.toStringAsFixed(1);

    if (isZh) {
      return '⚡【時間相機 Pro・現場違規存證戰報】\n'
          '🕒 校準時間：${record.formattedTimeUtc8} (UTC+8)\n'
          '📍 發生路段：$safeAddr\n'
          '🚗 對象備註：$safePlate\n'
          '⚖️ 適用法條：${statute.articleNumberZh}（${statute.violationTitleZh}）\n'
          '💰 法定罰鍰：${statute.fineRangeTextZh}\n'
          '🎬 影片規格：已智能壓縮至 $sizeStr MB (符合警局 20MB 上限)\n'
          '📲 10秒110報案＆檢舉壓縮神器：App Store 搜尋「時間相機 Pro」';
    }

    return '⚡ [TimeCam Pro Evidence Report]\n'
        '🕒 Timestamp: ${record.formattedTimeUtc8} (UTC+8)\n'
        '📍 Location: $safeAddr\n'
        '🚗 Plate/Note: $safePlate\n'
        '⚖️ Statute: ${statute.articleNumberEn} (${statute.violationTitleEn})\n'
        '💰 Fine Range: ${statute.fineRangeTextEn}\n'
        '🎬 Video Size: Smart compressed to $sizeStr MB (<20MB limit)\n'
        '📲 Search "TimeCam Pro" on the App Store';
  }

  @override
  State<ViralShareCardSheet> createState() => _ViralShareCardSheetState();
}

class _ViralShareCardSheetState extends State<ViralShareCardSheet> {
  SharePrivacyMaskMode _maskMode = SharePrivacyMaskMode.maskMiddlePlate;

  @override
  Widget build(BuildContext context) {
    final String postText = ViralShareCardSheet.buildViralPostText(
      record: widget.record,
      statute: widget.statute,
      maskMode: _maskMode,
      isZh: widget.isZh,
    );

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.campaign_rounded,
                    color: Color(0xFFF59E0B),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isZh
                          ? '一鍵生成 Threads / LINE 違規存證戰報卡'
                          : 'Generate Viral Evidence Share Card',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.isZh
                    ? '選擇隱私保護層級（公開貼文建議使用社群安全打碼）：'
                    : 'Select Privacy Mask Level for Social Sharing:',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SharePrivacyMaskMode.values
                    .map((SharePrivacyMaskMode mode) {
                  final bool selected = _maskMode == mode;
                  return ChoiceChip(
                    label: Text(
                      mode.localizedLabel(isZh: widget.isZh),
                      style: TextStyle(
                        color:
                            selected ? const Color(0xFF121212) : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    selected: selected,
                    selectedColor: const Color(0xFFF59E0B),
                    backgroundColor: const Color(0xFF1E293B),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _maskMode = mode;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  postText,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('copy_viral_post_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF121212),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  onPressed: () async {
                    HapticFeedback.heavyImpact();
                    final NavigatorState nav = Navigator.of(context);
                    final ScaffoldMessengerState messenger =
                        ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: postText));
                    if (!mounted) return;
                    nav.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF10B981),
                        content: Text(
                          widget.isZh
                              ? '🚀 已複製戰報全文！可直接貼上 Threads / LINE / PTT 分享！'
                              : '🚀 Copied viral report card for social sharing!',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: Text(
                    widget.isZh
                        ? '一鍵複製戰報貼上 Threads / LINE 群組'
                        : 'Copy Viral Report for Threads / LINE',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
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
