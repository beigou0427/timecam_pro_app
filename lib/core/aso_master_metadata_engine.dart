import 'package:flutter/foundation.dart';

enum AsoMarketLocale {
  zhHant(ascLocaleCode: 'zh-Hant', labelZh: '台灣繁體中文', labelEn: 'Traditional Chinese (TW)'),
  enUs(ascLocaleCode: 'en-US', labelZh: '美國/全球英語', labelEn: 'English (US)');

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
    title: '時間相機 Pro：GPS水印與20MB壓縮',
    subtitle: '110報案助手・交通環保檢舉存證',
    keywords: '工程,拍照,行車記錄器,經緯度,車牌,煙蒂,獎金,罰單,打卡,巡檢,太陽能,定位',
    promotionalText: '🔥 全新支援 Built for iPhone Duo 雙屏協作！內建 20MB 警政影片壓縮與環保煙蒂獎金試算，10 秒完成 110 簡訊報案！',
    inAppEventTitle: '2026 檢舉影片20MB秒壓與環保獎金攻略上線',
  );

  static const AsoStoreListingSpec enUsSpec = AsoStoreListingSpec(
    locale: AsoMarketLocale.enUs,
    title: 'TimeCam Pro: GPS Timestamp Cam',
    subtitle: '20MB Video Compressor & Audit',
    keywords: 'watermark,dashcam,bitrate,resize,trim,evidence,inspection,coordinates,address,fieldwork,solar,log',
    promotionalText: 'Built for iPhone Duo Dual-Screen! Stamp verified UTC+8 & GPS watermarks and compress 4K clips strictly under 20MB.',
    inAppEventTitle: 'iPhone Duo Dual-Pane & 20MB Bitrate Engine Launch',
  );

  static AsoStoreListingSpec specForLocale(AsoMarketLocale locale) {
    return locale == AsoMarketLocale.zhHant ? zhHantSpec : enUsSpec;
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

  static String buildAuditSummary(AsoStoreListingSpec spec) {
    final int kwBytes = utf8ByteLength(spec.keywords);
    final String status = isCompliant(spec) ? 'PASS' : 'FAIL';
    return '[${spec.locale.ascLocaleCode}] Title ${spec.title.length}/$maxTitleChars | '
        'Sub ${spec.subtitle.length}/$maxSubtitleChars | '
        'KW $kwBytes/${maxKeywordsUtf8Bytes}B | $status';
  }
}
