import 'package:flutter/foundation.dart';

enum CppAudienceChannel {
  trafficVideo20Mb('cpp_traffic_20mb', 'timecampro://compress'),
  epaCashReward('cpp_epa_reward', 'timecampro://reward'),
  fieldAuditPdf('cpp_field_pdf', 'timecampro://audit'),
  iphoneDuoSplit('cpp_iphone_duo', 'timecampro://duo');

  const CppAudienceChannel(this.cppSlug, this.deepLinkRoute);
  final String cppSlug;
  final String deepLinkRoute;
}

@immutable
class CustomProductPageSpec {
  const CustomProductPageSpec({
    required this.channel,
    required this.assignedKeywordsZh,
    required this.assignedKeywordsEn,
    required this.promoTextZh,
    required this.promoTextEn,
    required this.leadScreenshotIndex,
  });
  final CppAudienceChannel channel;
  final List<String> assignedKeywordsZh;
  final List<String> assignedKeywordsEn;
  final String promoTextZh;
  final String promoTextEn;
  final int leadScreenshotIndex;
}

@immutable
class InAppEventAsoSpec {
  const InAppEventAsoSpec({
    required this.badgeType,
    required this.titleZh,
    required this.shortDescZh,
    required this.titleEn,
    required this.shortDescEn,
  });
  final String badgeType;
  final String titleZh;
  final String shortDescZh;
  final String titleEn;
  final String shortDescEn;
}

class AsoExtremeCppEngine {
  const AsoExtremeCppEngine._();
  static const int maxAppleCppLimit = 70;
  static const int maxConcurrentLiveEvents = 10;
  static const double cppConversionLiftMultiplier = 2.56;

  static const String twPrimaryTitle30 = '時間相機-GPS浮水印打卡經緯度20MB影片壓縮防偽拍照錄影';
  static const String twPrimarySubtitle30 = '110報案行車紀錄器違規檢舉環保煙蒂獎金日期戳記外勤巡檢工程';
  static const String twPrimaryKeywords100B = '記錄,太陽能,工地,施工,驗收,轉檔,裁切,定位,地址,座標,車牌,罰單,時光,地圖';

  static const String twSecondaryTitle30 = '車禍蒐證A4報告書PDF-未禮讓行人闖紅燈併排紅線統編報帳單';
  static const String twSecondarySubtitle30 = '重機族營造水電監工汽車機車騎士外送・TimeCamAudit';
  static const String twSecondaryKeywords100B = '通勤,國道,交通局,環保局,警察局,標案,請款,核銷,發票,存證,watermark,resize,exif';

  static const List<CustomProductPageSpec> cppSpecs = <CustomProductPageSpec>[
    CustomProductPageSpec(channel: CppAudienceChannel.trafficVideo20Mb, assignedKeywordsZh: <String>['20MB', '影片壓縮', '轉檔', '裁切', '行車紀錄器'], assignedKeywordsEn: <String>['20mb', 'video', 'compress', 'trim', 'dashcam'], promoTextZh: '4K影片1秒壓進19MB・車牌高清零退件', promoTextEn: 'Compress 4K clips under 19MB in 1 tap', leadScreenshotIndex: 1),
    CustomProductPageSpec(channel: CppAudienceChannel.epaCashReward, assignedKeywordsZh: <String>['煙蒂', '獎金', '環保', '罰單', '違規檢舉'], assignedKeywordsEn: <String>['reward', 'litter', 'fine', 'report', 'evidence'], promoTextZh: r'拍煙蒂違規扣稅實領NT$864・1件賺回軟體', promoTextEn: 'Calculate EPA rewards & track 7-day limits', leadScreenshotIndex: 2),
    CustomProductPageSpec(channel: CppAudienceChannel.fieldAuditPdf, assignedKeywordsZh: <String>['太陽能', '工地', '施工', '驗收', '報告書'], assignedKeywordsEn: <String>['solar', 'construction', 'audit', 'pdf', 'site'], promoTextZh: '1秒匯出業主A4驗收PDF＋公司統編報帳單', promoTextEn: '1-Tap A4 inspection PDF & corporate expense memo', leadScreenshotIndex: 5),
    CustomProductPageSpec(channel: CppAudienceChannel.iphoneDuoSplit, assignedKeywordsZh: <String>['時間相機', '浮水印', '經緯度', '打卡', '防偽'], assignedKeywordsEn: <String>['timestamp', 'watermark', 'gps', 'coordinates', 'seal'], promoTextZh: '專為iPhone Duo雙屏打造・左屏拍照右屏壓縮', promoTextEn: 'Built for iPhone Duo Dual-Screen Split Workspace', leadScreenshotIndex: 6),
  ];

  static const List<InAppEventAsoSpec> liveEventSpecs = <InAppEventAsoSpec>[
    InAppEventAsoSpec(badgeType: 'MAJOR_UPDATE', titleZh: 'iPhone Duo雙屏與20MB極速壓縮引擎上線', shortDescZh: '左屏拍UTC+8防偽水印・右屏1秒把4K影片壓進19MB不糊車牌', titleEn: 'iPhone Duo Split & 20MB Trim', shortDescEn: 'Dual-screen watermark cam & 20MB video compressor'),
    InAppEventAsoSpec(badgeType: 'CHALLENGE', titleZh: '環保煙蒂檢舉獎金試算與7日零逾期挑戰', shortDescZh: '立即試算各縣市亂丟煙蒂實領獎金，開啟7日舉發期限雷達', titleEn: '7-Day Evidence & Reward Radar', shortDescEn: 'Track statutory deadlines and estimate rewards'),
    InAppEventAsoSpec(badgeType: 'NEW_SEASON', titleZh: '2026太陽能與營造工程A4驗收PDF免加班季', shortDescZh: '工地巡檢拍照自動烙印12碼防偽指紋，1秒匯出A4驗收表', titleEn: '2026 Field Engineering A4 PDF', shortDescEn: 'Instant A4 audit reports with 12-char hash seals'),
  ];

  static const List<String> llmTagClusters = <String>[
    '20MB Video Compressor',
    'GPS Timestamp Camera',
    '110 SMS Reporting',
    'A4 Field Inspection PDF',
    'Tamper-Proof Hash Watermark',
  ];

  static int _utf8Len(String s) {
    int b = 0;
    for (final int r in s.runes) {
      b += r <= 0x7F ? 1 : (r <= 0x7FF ? 2 : (r <= 0xFFFF ? 3 : 4));
    }
    return b;
  }

  static bool isTaiwan100PercentSaturated() {
    return twPrimaryTitle30.length == 30 &&
        twPrimarySubtitle30.length == 30 &&
        _utf8Len(twPrimaryKeywords100B) == 100 &&
        twSecondaryTitle30.length == 30 &&
        twSecondarySubtitle30.length == 30 &&
        _utf8Len(twSecondaryKeywords100B) == 100;
  }

  static bool hasZeroCppKeywordCollision() {
    final Set<String> seenZh = <String>{};
    final Set<String> seenEn = <String>{};
    for (final CustomProductPageSpec c in cppSpecs) {
      for (final String kw in c.assignedKeywordsZh) {
        if (!seenZh.add(kw.trim().toLowerCase())) return false;
      }
      for (final String kw in c.assignedKeywordsEn) {
        if (!seenEn.add(kw.trim().toLowerCase())) return false;
      }
    }
    for (final InAppEventAsoSpec ev in liveEventSpecs) {
      if (ev.titleZh.length > 30 || ev.shortDescZh.length > 50) return false;
      if (ev.titleEn.length > 30 || ev.shortDescEn.length > 50) return false;
    }
    return true;
  }

  static CustomProductPageSpec routeQueryToCpp(String rawQuery) {
    final String q = rawQuery.trim().toLowerCase();
    for (final CustomProductPageSpec c in cppSpecs) {
      for (final String kw in c.assignedKeywordsZh) {
        if (q.contains(kw.toLowerCase())) return c;
      }
      for (final String kw in c.assignedKeywordsEn) {
        if (q.contains(kw.toLowerCase())) return c;
      }
    }
    return cppSpecs.first;
  }
}
