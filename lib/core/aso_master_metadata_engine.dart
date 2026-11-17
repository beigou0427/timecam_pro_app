import 'package:flutter/foundation.dart';

enum AsoMarketLocale {
  zhHant(ascLocaleCode: 'zh-Hant', labelZh: '台灣繁體主力', labelEn: 'TW Primary (zh-Hant)'),
  enGb(ascLocaleCode: 'en-GB', labelZh: '台灣第二交叉索引槽', labelEn: 'TW Secondary Slot (en-GB)'),
  enUs(ascLocaleCode: 'en-US', labelZh: '美國/全球英語主力', labelEn: 'US Primary (en-US)'),
  zhHans(ascLocaleCode: 'zh-Hans', labelZh: '美區/全球華人交叉槽', labelEn: 'Global Chinese Slot (zh-Hans)');

  const AsoMarketLocale({
    required this.ascLocaleCode,
    required this.labelZh,
    required this.labelEn,
  });
  final String ascLocaleCode;
  final String labelZh;
  final String labelEn;
}

@immutable
class AsoStoreListingSpec {
  const AsoStoreListingSpec({
    required this.locale,
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.promotionalText,
    required this.inAppEventTitle,
  });

  final AsoMarketLocale locale;
  final String title;
  final String subtitle;
  final String keywords;
  final String promotionalText;
  final String inAppEventTitle;
}

class AsoMasterMetadataEngine {
  const AsoMasterMetadataEngine._();
  static const int maxTitleChars = 30;
  static const int maxSubtitleChars = 30;
  static const int maxKeywordsUtf8Bytes = 100;
  static const int maxPromoTextChars = 170;

  static const AsoStoreListingSpec zhHantSpec = AsoStoreListingSpec(
    locale: AsoMarketLocale.zhHant,
    title: '時間相機-GPS浮水印經緯度工程打卡・20MB影片壓縮錄影',
    subtitle: '110報案行車紀錄器・違規檢舉環保獎金日期戳記外勤巡檢拍照',
    keywords: '記錄,太陽能,工地,施工,驗收,轉檔,裁切,定位,地址,座標,車牌,罰單,時光,防偽',
    promotionalText: r'🎁 新戶免費體驗 20MB 壓縮！成功檢舉 1 件亂丟煙蒂實領獎金 NT$864 直接賺回終身版！支援 Built for iPhone Duo 雙屏協作與 10 秒 110 報案。',
    inAppEventTitle: '2026 檢舉影片20MB秒壓與環保獎金攻略上線',
  );

  static const AsoStoreListingSpec enGbSpec = AsoStoreListingSpec(
    locale: AsoMarketLocale.enGb,
    title: 'TimeCam Pro: Timestamp & Trim',
    subtitle: 'Dashcam Resize, Watermark, PDF',
    keywords: '車禍,蒐證,未禮讓行人,闖紅燈,併排,紅線,水電,營造,監工,報帳,統編,A4,audit',
    promotionalText: r'Built for iPhone Duo! Compress 4K clips under 20MB in 1 tap, stamp 12-char anti-tamper UTC+8 seals, and export A4 inspection logs.',
    inAppEventTitle: 'B2B Field Audit PDF & 20MB Smart Trim Update',
  );

  static const AsoStoreListingSpec enUsSpec = AsoStoreListingSpec(
    locale: AsoMarketLocale.enUs,
    title: 'Timestamp Camera: GPS & 20MB',
    subtitle: 'Watermark Cam, Video Trim, Log',
    keywords: 'dashcam,bitrate,resize,compress,evidence,inspection,coordinates,address,fieldwork,solar,pdf,audit',
    promotionalText: r'Stamp tamper-proof UTC+8 & GPS watermarks, compress 4K dashcam clips under 20MB, and generate A4 inspection PDFs on iPhone Duo.',
    inAppEventTitle: 'iPhone Duo Dual-Pane & 20MB Bitrate Engine Launch',
  );

  static const AsoStoreListingSpec zhHansSpec = AsoStoreListingSpec(
    locale: AsoMarketLocale.zhHans,
    title: '时间相机-水印经纬度打卡・20MB视频压缩工程取证',
    subtitle: '行车记录仪防伪时间戳・外勤考勤巡检验收日期定位',
    keywords: '坐标,地址,车牌,违章,举报,环保,奖金,转码,裁切,光伏,工地,施工,执法,档案',
    promotionalText: r'全新支持 iPhone Duo 双屏协作！一键将 4K 视频精准压缩至 20MB 以内，内置防篡改 UTC+8 时间地址水印与 A4 验收报告生成。',
    inAppEventTitle: '20MB 视频智能压缩与工程防伪水印升级',
  );

  static AsoStoreListingSpec specForLocale(AsoMarketLocale locale) {
    switch (locale) {
      case AsoMarketLocale.zhHant:
        return zhHantSpec;
      case AsoMarketLocale.enGb:
        return enGbSpec;
      case AsoMarketLocale.enUs:
        return enUsSpec;
      case AsoMarketLocale.zhHans:
        return zhHansSpec;
    }
  }

  static String deduplicateKeywords({
    required String title,
    required String subtitle,
    required String rawKeywords,
  }) {
    final String combinedHeader = '${title.toLowerCase()} ${subtitle.toLowerCase()}';
    final List<String> tokens = rawKeywords.replaceAll('，', ',').split(',');
    final List<String> kept = <String>[];
    for (final String raw in tokens) {
      final String term = raw.trim();
      if (term.isEmpty) continue;
      final String lower = term.toLowerCase();
      if (!combinedHeader.contains(lower) && !kept.contains(term)) {
        kept.add(term);
      }
    }
    return kept.join(',');
  }

  static int utf8ByteLength(String text) {
    int bytes = 0;
    for (final int rune in text.runes) {
      if (rune <= 0x7F) {
        bytes += 1;
      } else if (rune <= 0x7FF) {
        bytes += 2;
      } else if (rune <= 0xFFFF) {
        bytes += 3;
      } else {
        bytes += 4;
      }
    }
    return bytes;
  }

  static bool isCompliant(AsoStoreListingSpec spec) {
    return spec.title.isNotEmpty &&
        spec.title.length <= maxTitleChars &&
        spec.subtitle.isNotEmpty &&
        spec.subtitle.length <= maxSubtitleChars &&
        spec.keywords.isNotEmpty &&
        utf8ByteLength(spec.keywords) <= maxKeywordsUtf8Bytes &&
        spec.promotionalText.length <= maxPromoTextChars;
  }

  static bool hasZeroKeywordOverlapBetweenTaiwanLocales() {
    final Set<String> twPrimary =
        zhHantSpec.keywords.split(',').map((String e) => e.trim().toLowerCase()).toSet();
    final Set<String> twSecondary =
        enGbSpec.keywords.split(',').map((String e) => e.trim().toLowerCase()).toSet();
    return twPrimary.intersection(twSecondary).isEmpty;
  }

  static String buildAuditSummary(AsoStoreListingSpec spec) {
    final int kwBytes = utf8ByteLength(spec.keywords);
    final String status = isCompliant(spec) ? 'PASS' : 'FAIL';
    return '[${spec.locale.ascLocaleCode}] Title ${spec.title.length}/$maxTitleChars | '
        'Sub ${spec.subtitle.length}/$maxSubtitleChars | '
        'KW $kwBytes/${maxKeywordsUtf8Bytes}B | $status';
  }
}
