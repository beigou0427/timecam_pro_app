import 'package:flutter/foundation.dart';

/// 台灣地理分區篩選列舉（含中央總入口＋全部 22 縣市）
enum PortalRegion {
  national(labelZh: '中央與國道', labelEn: 'National'),
  north(labelZh: '北北基桃竹苗', labelEn: 'Northern TW'),
  central(labelZh: '中彰投雲', labelEn: 'Central TW'),
  south(labelZh: '嘉南高屏', labelEn: 'Southern TW'),
  eastAndIslands(labelZh: '宜花東與離島', labelEn: 'Eastern & Islands');

  const PortalRegion({required this.labelZh, required this.labelEn});
  final String labelZh;
  final String labelEn;

  String localizedLabel({required bool isZh}) => isZh ? labelZh : labelEn;
}

/// 本地存證案件狀態列舉
enum CaseSubmissionStatus {
  pending(labelZh: '待處理', labelEn: 'Pending'),
  submitted(labelZh: '已通報', labelEn: 'Submitted'),
  archived(labelZh: '已歸檔', labelEn: 'Archived');

  const CaseSubmissionStatus({required this.labelZh, required this.labelEn});
  final String labelZh;
  final String labelEn;

  String localizedLabel({required bool isZh}) => isZh ? labelZh : labelEn;
}

/// 各級政府公開檢舉與環境通報官方網站入口模型
@immutable
class CityReportPortal {
  const CityReportPortal({
    required this.id,
    required this.region,
    required this.cityNameZh,
    required this.cityNameEn,
    required this.trafficPortalUrl,
    required this.epaPortalUrl,
    required this.maxTrafficVideoMB,
    required this.epaRewardNoteZh,
    required this.epaRewardNoteEn,
  });

  final String id;
  final PortalRegion region;
  final String cityNameZh;
  final String cityNameEn;
  final String trafficPortalUrl;
  final String epaPortalUrl;
  final double maxTrafficVideoMB;
  final String epaRewardNoteZh;
  final String epaRewardNoteEn;

  String localizedCityName({required bool isZh}) =>
      isZh ? cityNameZh : cityNameEn;

  String localizedEpaNote({required bool isZh}) =>
      isZh ? epaRewardNoteZh : epaRewardNoteEn;

  /// 安全解析交通入口網址 (僅限 HTTPS，防崩潰保底警政署官網)
  Uri get safeTrafficUri {
    final Uri? parsed = Uri.tryParse(trafficPortalUrl);
    if (parsed != null && parsed.hasScheme && parsed.scheme == 'https') {
      return parsed;
    }
    return Uri.parse('https://www.npa.gov.tw/');
  }

  /// 安全解析環保入口網址 (僅限 HTTPS，防崩潰保底環境部公害陳情網)
  Uri get safeEpaUri {
    final Uri? parsed = Uri.tryParse(epaPortalUrl);
    if (parsed != null && parsed.hasScheme && parsed.scheme == 'https') {
      return parsed;
    }
    return Uri.parse('https://ww3.moenv.gov.tw/');
  }
}

/// 道路交通與環境法規文字記載模板模型
@immutable
class TrafficStatuteTemplate {
  const TrafficStatuteTemplate({
    required this.code,
    required this.articleNumberZh,
    required this.articleNumberEn,
    required this.violationTitleZh,
    required this.violationTitleEn,
    required this.fineRangeTextZh,
    required this.fineRangeTextEn,
    required this.templateBodyZh,
    required this.templateBodyEn,
    required this.isProRequired,
  });

  final String code;
  final String articleNumberZh;
  final String articleNumberEn;
  final String violationTitleZh;
  final String violationTitleEn;
  final String fineRangeTextZh;
  final String fineRangeTextEn;
  final String templateBodyZh;
  final String templateBodyEn;
  final bool isProRequired;

  String localizedArticle({required bool isZh}) =>
      isZh ? articleNumberZh : articleNumberEn;

  String localizedTitle({required bool isZh}) =>
      isZh ? violationTitleZh : violationTitleEn;

  String localizedFine({required bool isZh}) =>
      isZh ? fineRangeTextZh : fineRangeTextEn;

  String localizedBody({required bool isZh}) =>
      isZh ? templateBodyZh : templateBodyEn;
}

/// 本地保護存證案件紀錄模型（保存拍攝當下不可變動之真實 GPS 與檔案 SHA-256）
@immutable
class EvidenceCaseRecord {
  const EvidenceCaseRecord({
    required this.id,
    required this.capturedAtUtc,
    required this.formattedTimeUtc8,
    required this.address,
    required this.plateOrNote,
    required this.statuteCode,
    required this.compressedSizeMB,
    required this.status,
    this.thumbnailPath,
    this.isSample = false,
    this.latitude,
    this.longitude,
    this.altitudeMeters,
    this.evidenceHash,
    this.personaMode,
  });

  final String id;
  final DateTime capturedAtUtc;
  final String formattedTimeUtc8;
  final String address;
  final String plateOrNote;
  final String statuteCode;
  final double compressedSizeMB;
  final CaseSubmissionStatus status;
  final String? thumbnailPath;
  final bool isSample;
  final double? latitude;
  final double? longitude;
  final double? altitudeMeters;
  final String? evidenceHash;
  final String? personaMode;

  bool get hasValidCoordinates {
    final double? lat = latitude;
    final double? lng = longitude;
    if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) {
      return false;
    }
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return false;
    return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }

  /// 僅更新狀態、可讀備註或縮圖路徑；時間、原始座標與拍攝 SHA-256 不可被篡改
  EvidenceCaseRecord copyWith({
    CaseSubmissionStatus? status,
    String? plateOrNote,
    String? thumbnailPath,
    bool? isSample,
  }) {
    return EvidenceCaseRecord(
      id: id,
      capturedAtUtc: capturedAtUtc,
      formattedTimeUtc8: formattedTimeUtc8,
      address: address,
      plateOrNote: plateOrNote ?? this.plateOrNote,
      statuteCode: statuteCode,
      compressedSizeMB: compressedSizeMB,
      status: status ?? this.status,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      isSample: isSample ?? this.isSample,
      latitude: latitude,
      longitude: longitude,
      altitudeMeters: altitudeMeters,
      evidenceHash: evidenceHash,
      personaMode: personaMode,
    );
  }
}

/// 全台 22 縣市獨立官方公開入口＋中央總網、法規參考模板與 7 日時效管理引擎
class TaiwanReportRepository {
  const TaiwanReportRepository._();

  /// 道交條例第 7-1 條法定舉發參考期限 (自違規日起算 7 日內)
  static const int statutoryReportLimitDays = 7;

  /// 中央主管機關總網 + 台灣本島及離島完整 22 縣市獨立入口（絕不混區錯導）
  static const List<CityReportPortal> allCityPortals = <CityReportPortal>[
    // --- 中央主管機關總入口 (3) ---
    CityReportPortal(
      id: 'national_npa',
      region: PortalRegion.national,
      cityNameZh: '內政部警政署 (全國警政入口)',
      cityNameEn: 'National Police Agency (TW)',
      trafficPortalUrl: 'https://www.npa.gov.tw/',
      epaPortalUrl: 'https://ww3.moenv.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '中央警政署與環境部公害陳情總入口',
      epaRewardNoteEn: 'Central Police & Ministry of Environment Portal',
    ),
    CityReportPortal(
      id: 'highway_police',
      region: PortalRegion.national,
      cityNameZh: '國道公路警察局',
      cityNameEn: 'National Highway Police Bureau',
      trafficPortalUrl: 'https://tvrs.hpb.gov.tw/',
      epaPortalUrl: 'https://ww3.moenv.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依國道公路警察局官網影片上傳規範',
      epaRewardNoteEn: 'Follows Highway Police upload guidelines',
    ),
    CityReportPortal(
      id: 'national_moenv',
      region: PortalRegion.national,
      cityNameZh: '環境部公害陳情系統',
      cityNameEn: 'Ministry of Environment (MOENV)',
      trafficPortalUrl: 'https://www.npa.gov.tw/',
      epaPortalUrl: 'https://ww3.moenv.gov.tw/',
      maxTrafficVideoMB: 10.0,
      epaRewardNoteZh: '全國環境公害與亂丟廢棄物官方陳情平台',
      epaRewardNoteEn: 'National public environmental nuisance reporting portal',
    ),

    // --- 北北基桃竹苗 (7 縣市) ---
    CityReportPortal(
      id: 'taipei_city',
      region: PortalRegion.north,
      cityNameZh: '台北市',
      cityNameEn: 'Taipei City',
      trafficPortalUrl: 'https://tvrs.tcpd.gov.tw/',
      epaPortalUrl: 'https://www.dep.gov.taipei/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依台北市政府警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Taipei City portal rules',
    ),
    CityReportPortal(
      id: 'new_taipei',
      region: PortalRegion.north,
      cityNameZh: '新北市',
      cityNameEn: 'New Taipei City',
      trafficPortalUrl: 'https://tvrs.ntpd.gov.tw/',
      epaPortalUrl: 'https://www.epd.ntpc.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依新北市政府警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official New Taipei portal rules',
    ),
    CityReportPortal(
      id: 'keelung',
      region: PortalRegion.north,
      cityNameZh: '基隆市',
      cityNameEn: 'Keelung City',
      trafficPortalUrl: 'https://www.klg.gov.tw/',
      epaPortalUrl: 'https://www.klepb.klcg.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依基隆市警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Keelung portal rules',
    ),
    CityReportPortal(
      id: 'taoyuan',
      region: PortalRegion.north,
      cityNameZh: '桃園市',
      cityNameEn: 'Taoyuan City',
      trafficPortalUrl: 'https://tvrs.tyhp.gov.tw/',
      epaPortalUrl: 'https://www.tydep.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依桃園市政府警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Taoyuan portal rules',
    ),
    CityReportPortal(
      id: 'hsinchu_city',
      region: PortalRegion.north,
      cityNameZh: '新竹市',
      cityNameEn: 'Hsinchu City',
      trafficPortalUrl: 'https://tra.hccp.gov.tw/',
      epaPortalUrl: 'https://www.hccepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依新竹市警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Hsinchu City portal rules',
    ),
    CityReportPortal(
      id: 'hsinchu_county',
      region: PortalRegion.north,
      cityNameZh: '新竹縣',
      cityNameEn: 'Hsinchu County',
      trafficPortalUrl: 'https://www.hchpb.gov.tw/',
      epaPortalUrl: 'https://www.hcepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依新竹縣政府警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Hsinchu County portal rules',
    ),
    CityReportPortal(
      id: 'miaoli',
      region: PortalRegion.north,
      cityNameZh: '苗栗縣',
      cityNameEn: 'Miaoli County',
      trafficPortalUrl: 'https://www.mpb.gov.tw/',
      epaPortalUrl: 'https://www.mlepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依苗栗縣警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Miaoli County portal rules',
    ),

    // --- 中彰投雲 (4 縣市) ---
    CityReportPortal(
      id: 'taichung',
      region: PortalRegion.central,
      cityNameZh: '台中市',
      cityNameEn: 'Taichung City',
      trafficPortalUrl: 'https://suggest.police.taichung.gov.tw/traffic/',
      epaPortalUrl: 'https://www.epb.taichung.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依台中市政府警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Taichung portal rules',
    ),
    CityReportPortal(
      id: 'changhua',
      region: PortalRegion.central,
      cityNameZh: '彰化縣',
      cityNameEn: 'Changhua County',
      trafficPortalUrl: 'https://www.chpb.gov.tw/',
      epaPortalUrl: 'https://www.chepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依彰化縣警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Changhua portal rules',
    ),
    CityReportPortal(
      id: 'nantou',
      region: PortalRegion.central,
      cityNameZh: '南投縣',
      cityNameEn: 'Nantou County',
      trafficPortalUrl: 'https://www.ncpb.gov.tw/',
      epaPortalUrl: 'https://www.ntepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依南投縣政府警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Nantou portal rules',
    ),
    CityReportPortal(
      id: 'yunlin',
      region: PortalRegion.central,
      cityNameZh: '雲林縣',
      cityNameEn: 'Yunlin County',
      trafficPortalUrl: 'https://www.ylhpb.gov.tw/',
      epaPortalUrl: 'https://www.ylepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依雲林縣警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Yunlin portal rules',
    ),

    // --- 嘉南高屏 (5 縣市) ---
    CityReportPortal(
      id: 'chiayi_city',
      region: PortalRegion.south,
      cityNameZh: '嘉義市',
      cityNameEn: 'Chiayi City',
      trafficPortalUrl: 'https://www.ccpb.gov.tw/',
      epaPortalUrl: 'https://epb.chiayi.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依嘉義市政府警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Chiayi City portal rules',
    ),
    CityReportPortal(
      id: 'chiayi_county',
      region: PortalRegion.south,
      cityNameZh: '嘉義縣',
      cityNameEn: 'Chiayi County',
      trafficPortalUrl: 'https://www.cypd.gov.tw/',
      epaPortalUrl: 'https://www.cyepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依嘉義縣警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Chiayi County portal rules',
    ),
    CityReportPortal(
      id: 'tainan',
      region: PortalRegion.south,
      cityNameZh: '台南市',
      cityNameEn: 'Tainan City',
      trafficPortalUrl: 'https://ba.tnpd.gov.tw/',
      epaPortalUrl: 'https://www.tnepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依台南市政府警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Tainan portal rules',
    ),
    CityReportPortal(
      id: 'kaohsiung',
      region: PortalRegion.south,
      cityNameZh: '高雄市',
      cityNameEn: 'Kaohsiung City',
      trafficPortalUrl: 'https://trs.kcpd.gov.tw/',
      epaPortalUrl: 'https://ksepb.kcg.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依高雄市政府警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Kaohsiung portal rules',
    ),
    CityReportPortal(
      id: 'pingtung',
      region: PortalRegion.south,
      cityNameZh: '屏東縣',
      cityNameEn: 'Pingtung County',
      trafficPortalUrl: 'https://www.ptpolice.gov.tw/',
      epaPortalUrl: 'https://www.ptepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依屏東縣政府警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Pingtung portal rules',
    ),

    // --- 宜花東與離島 (6 縣市) ---
    CityReportPortal(
      id: 'yilan',
      region: PortalRegion.eastAndIslands,
      cityNameZh: '宜蘭縣',
      cityNameEn: 'Yilan County',
      trafficPortalUrl: 'https://www.ilcpb.gov.tw/',
      epaPortalUrl: 'https://www.ilepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依宜蘭縣政府警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Yilan portal rules',
    ),
    CityReportPortal(
      id: 'hualien',
      region: PortalRegion.eastAndIslands,
      cityNameZh: '花蓮縣',
      cityNameEn: 'Hualien County',
      trafficPortalUrl: 'https://www.hlpb.gov.tw/',
      epaPortalUrl: 'https://www.hlepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依花蓮縣警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Hualien portal rules',
    ),
    CityReportPortal(
      id: 'taitung',
      region: PortalRegion.eastAndIslands,
      cityNameZh: '臺東縣',
      cityNameEn: 'Taitung County',
      trafficPortalUrl: 'https://www.ttcpb.gov.tw/',
      epaPortalUrl: 'https://www.ttepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依臺東縣警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Taitung portal rules',
    ),
    CityReportPortal(
      id: 'penghu',
      region: PortalRegion.eastAndIslands,
      cityNameZh: '澎湖縣',
      cityNameEn: 'Penghu County',
      trafficPortalUrl: 'https://www.phpb.gov.tw/',
      epaPortalUrl: 'https://www.phepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依澎湖縣政府警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Penghu portal rules',
    ),
    CityReportPortal(
      id: 'kinmen',
      region: PortalRegion.eastAndIslands,
      cityNameZh: '金門縣',
      cityNameEn: 'Kinmen County',
      trafficPortalUrl: 'https://www.kmpb.gov.tw/',
      epaPortalUrl: 'https://kepb.kinmen.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依金門縣警察局與環保局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Kinmen portal rules',
    ),
    CityReportPortal(
      id: 'lienchiang',
      region: PortalRegion.eastAndIslands,
      cityNameZh: '連江縣 (馬祖)',
      cityNameEn: 'Lienchiang County (Matsu)',
      trafficPortalUrl: 'https://www.mtpb.gov.tw/',
      epaPortalUrl: 'https://www.lcem.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '依連江縣警察局與環境資源局官網最新規範為準',
      epaRewardNoteEn: 'Refer to official Lienchiang portal rules',
    ),
  ];

  /// 道路交通與環境法規標準事實記載模板庫（無虛假獎勵宣傳、符合現行條文）
  static const List<TrafficStatuteTemplate> statuteTemplates =
      <TrafficStatuteTemplate>[
    TrafficStatuteTemplate(
      code: 'ART_42_SIGNAL',
      articleNumberZh: '道交條例 第 42 條',
      articleNumberEn: 'Traffic Act Art. 42',
      violationTitleZh: '轉彎或變換車道未依規定使用方向燈',
      violationTitleEn: 'Failure to Signal When Turning or Changing Lanes',
      fineRangeTextZh: '依現行法規裁罰範圍',
      fineRangeTextEn: 'Statutory Traffic Penalty',
      templateBodyZh:
          '該車於上述時間與地點，於變換車道或轉彎過程中，未依規定使用方向燈，跨越車道線影響後方車輛反應安全，請貴局依權責查處。',
      templateBodyEn:
          'The vehicle failed to use turn signals during the lane change or turn maneuver at the recorded timestamp and location.',
      isProRequired: false,
    ),
    TrafficStatuteTemplate(
      code: 'ART_53_RED_LIGHT',
      articleNumberZh: '道交條例 第 53 條第 1 項',
      articleNumberEn: 'Traffic Act Art. 53-1',
      violationTitleZh: '行經有燈光號誌管制交岔路口闖紅燈',
      violationTitleEn: 'Running a Red Traffic Light at Intersection',
      fineRangeTextZh: '依現行法規裁罰範圍',
      fineRangeTextEn: 'Statutory Traffic Penalty',
      templateBodyZh:
          '該車於上述路口號誌已轉換為紅燈後，仍超越停止線並繼續穿越交岔路口，請貴局依權責查處。',
      templateBodyEn:
          'The vehicle crossed the stop line and proceeded through the intersection after the traffic signal turned red.',
      isProRequired: false,
    ),
    TrafficStatuteTemplate(
      code: 'ART_44_PEDESTRIAN',
      articleNumberZh: '道交條例 第 44 條第 2 項',
      articleNumberEn: 'Traffic Act Art. 44-2',
      violationTitleZh: '行近行人穿越道不停讓行人優先通行',
      violationTitleEn: 'Failure to Yield to Pedestrians on Crosswalk',
      fineRangeTextZh: '依現行法規裁罰範圍',
      fineRangeTextEn: 'Statutory Traffic Penalty',
      templateBodyZh:
          '該車行近行人穿越道時，斑馬線上已有行人正在通行，該車未減速暫停禮讓行人優先通過，請貴局依權責查處。',
      templateBodyEn:
          'The vehicle failed to stop and yield to pedestrians actively crossing on the marked crosswalk.',
      isProRequired: true,
    ),
    TrafficStatuteTemplate(
      code: 'ART_43_AGGRESSIVE',
      articleNumberZh: '道交條例 第 43 條第 1 項',
      articleNumberEn: 'Traffic Act Art. 43-1',
      violationTitleZh: '危險駕駛 / 任意以迫近或驟然變換車道迫使讓道',
      violationTitleEn: 'Reckless Driving / Sudden Cut-off',
      fineRangeTextZh: '依現行法規裁罰範圍',
      fineRangeTextEn: 'Statutory Traffic Penalty',
      templateBodyZh:
          '該車於行駛途中，任意以迫近、驟然變換車道或於車道中驟然減速迫使他車讓道，危及行車安全，請貴局依權責查處。',
      templateBodyEn:
          'The vehicle engaged in dangerous driving by intentionally cutting off or braking abruptly in an active lane.',
      isProRequired: true,
    ),
    TrafficStatuteTemplate(
      code: 'ART_45_SIDEWALK',
      articleNumberZh: '道交條例 第 45 條第 1 項',
      articleNumberEn: 'Traffic Act Art. 45-1',
      violationTitleZh: '不依規定駕車行駛人行道或跨越雙黃線',
      violationTitleEn: 'Driving on Sidewalk or Crossing Double Yellow Line',
      fineRangeTextZh: '依現行法規裁罰範圍',
      fineRangeTextEn: 'Statutory Traffic Penalty',
      templateBodyZh:
          '該車於上述時地跨越分向限制線駛入來車道或違規駛上人行道，危害用路人安全，請貴局依權責查處。',
      templateBodyEn:
          'The vehicle crossed the double yellow line into oncoming traffic or drove onto the pedestrian sidewalk.',
      isProRequired: true,
    ),
    TrafficStatuteTemplate(
      code: 'EPA_ART_27_LITTER',
      articleNumberZh: '廢棄物清理法 第 27 條',
      articleNumberEn: 'Waste Disposal Act Art. 27',
      violationTitleZh: '隨地拋棄煙蒂、紙屑或一般廢棄物',
      violationTitleEn: 'Discarding Litter from Vehicle',
      fineRangeTextZh: '依各縣市環保局規範查處',
      fineRangeTextEn: 'Refer to Official EPA Portal Rules',
      templateBodyZh:
          '該車人員於上述時間地點停等或行進間，於公共道路範圍隨意拋棄廢棄物，附上連續影像紀錄，請貴局依權責查處。',
      templateBodyEn:
          'Continuous video captures litter being discarded onto the public roadway at the recorded timestamp and location.',
      isProRequired: true,
    ),
  ];

  /// 依地理分區與關鍵字篩選入口 (支援中英文與臺/台同義字搜尋)
  static List<CityReportPortal> filterPortals({
    PortalRegion? region,
    String query = '',
  }) {
    final String cleanQuery =
        query.trim().replaceAll('臺', '台').toLowerCase();
    if (region == null && cleanQuery.isEmpty) {
      return allCityPortals;
    }
    return allCityPortals.where((CityReportPortal portal) {
      final bool matchRegion = region == null || portal.region == region;
      if (!matchRegion) return false;
      if (cleanQuery.isEmpty) return true;
      final String normZh =
          portal.cityNameZh.replaceAll('臺', '台').toLowerCase();
      return normZh.contains(cleanQuery) ||
          portal.cityNameEn.toLowerCase().contains(cleanQuery) ||
          portal.epaRewardNoteZh.toLowerCase().contains(cleanQuery);
    }).toList(growable: false);
  }

  /// 計算距離 7 日參考舉發期限剩餘小時數 (0 ~ 168)
  static int remainingHoursToReport({
    required DateTime capturedAtUtc,
    required DateTime nowUtc,
  }) {
    final DateTime deadlineUtc =
        capturedAtUtc.toUtc().add(const Duration(days: statutoryReportLimitDays));
    final int diffHours = deadlineUtc.difference(nowUtc.toUtc()).inHours;
    return diffHours.clamp(0, statutoryReportLimitDays * 24);
  }

  /// 產生狀態標籤文字
  static String formatDeadlineBadge({
    required EvidenceCaseRecord record,
    required DateTime nowUtc,
    required bool isZh,
  }) {
    if (record.status == CaseSubmissionStatus.submitted) {
      return isZh ? '已完成通報記錄' : 'Reported';
    }
    if (record.status == CaseSubmissionStatus.archived) {
      return isZh ? '已本機歸檔' : 'Archived locally';
    }
    final int hoursLeft = remainingHoursToReport(
      capturedAtUtc: record.capturedAtUtc,
      nowUtc: nowUtc,
    );
    if (hoursLeft <= 0) {
      return isZh ? '已逾 7 日參考期' : 'Past 7-day window';
    }
    final int days = hoursLeft ~/ 24;
    final int remHours = hoursLeft % 24;
    if (isZh) {
      return '7 日參考期限剩 $days 天 $remHours 小時';
    }
    return '${days}d ${remHours}h remaining';
  }

  /// 合成標準事件紀錄摘要
  static String composeFullReportStatement({
    required TrafficStatuteTemplate template,
    required String formattedTimeUtc8,
    required String fullAddress,
    required String plateNumber,
    required bool isZh,
  }) {
    final String safePlate = plateNumber.trim().isEmpty
        ? (isZh ? '（請依實際畫面填寫車號）' : '(Enter plate / ID)')
        : plateNumber.trim();
    if (isZh) {
      return '【時間】$formattedTimeUtc8\n'
          '【地點】$fullAddress\n'
          '【車號】$safePlate\n'
          '【條文】${template.articleNumberZh}（${template.violationTitleZh}）\n'
          '【事實】${template.templateBodyZh}';
    }
    return '[Time] $formattedTimeUtc8\n'
        '[Location] $fullAddress\n'
        '[Plate / ID] $safePlate\n'
        '[Reference] ${template.articleNumberEn} (${template.violationTitleEn})\n'
        '[Summary] ${template.templateBodyEn}';
  }

  /// 建立語系對齊的預設範例資料 (使用者首次實拍後自動清除)
  static List<EvidenceCaseRecord> createInitialCases(
    DateTime referenceUtc, {
    bool isZh = true,
  }) {
    final DateTime baseUtc = referenceUtc.toUtc();
    if (!isZh) {
      return <EvidenceCaseRecord>[
        EvidenceCaseRecord(
          id: 'SAMPLE-ENG-01',
          capturedAtUtc: baseUtc.subtract(const Duration(hours: 18)),
          formattedTimeUtc8: '2026/11/14 14:22:10',
          address: 'Sample Site • Main St. Substation #A08',
          plateOrNote: 'Solar Panel Array A08 Pre-Check OK',
          statuteCode: 'FIELD_AUDIT',
          compressedSizeMB: 18.4,
          status: CaseSubmissionStatus.archived,
          isSample: true,
          latitude: 37.33465,
          longitude: -122.00897,
          altitudeMeters: 18.0,
          evidenceHash: 'SHA-4A91-C302-88F1',
          personaMode: 'fieldEngineering',
        ),
      ];
    }

    return <EvidenceCaseRecord>[
      EvidenceCaseRecord(
        id: 'CASE-2026-01',
        capturedAtUtc: baseUtc.subtract(const Duration(hours: 38)),
        formattedTimeUtc8: '2026/11/14 14:22:10',
        address: '範例案場：台南市七股區光電變電站 #A08',
        plateOrNote: '範例紀錄：逆變器端子巡檢封裝完成',
        statuteCode: 'FIELD_AUDIT',
        compressedSizeMB: 18.6,
        status: CaseSubmissionStatus.archived,
        isSample: true,
        latitude: 23.14175,
        longitude: 120.13624,
        altitudeMeters: 6.4,
        evidenceHash: 'SHA-7D21-9A04-5C88',
        personaMode: 'fieldEngineering',
      ),
      EvidenceCaseRecord(
        id: 'CASE-2026-02',
        capturedAtUtc: baseUtc.subtract(const Duration(hours: 48)),
        formattedTimeUtc8: '2026/11/13 08:45:33',
        address: '範例路段：台中市西屯區台灣大道三段路口',
        plateOrNote: '範例紀錄：RCD-5566 斑馬線安全通行紀錄',
        statuteCode: 'ART_44_PEDESTRIAN',
        compressedSizeMB: 17.9,
        status: CaseSubmissionStatus.pending,
        isSample: true,
        latitude: 24.16184,
        longitude: 120.64685,
        altitudeMeters: 86.5,
        evidenceHash: 'SHA-3B88-E119-0F42',
        personaMode: 'trafficEvidence',
      ),
    ];
  }

  /// Apple Guideline 5.2.2 官方獨立工具暨個資保護免責聲明（中英文雙語強制顯示）
  static String officialDisclaimer({required bool isZh}) {
    if (isZh) {
      return '免責與個資聲明：本應用程式為獨立開發之時間浮水印相機與影片壓縮輔助工具，非任何政府機關官方應用程式；政府入口僅直接開啟公開官方網站。拍攝或分享公共場所影像及車牌資訊時，請自行遵守當地個人資料保護與肖像隱私法規，所有檔案皆儲存於您的本機裝置。';
    }
    return 'Disclaimer & Privacy Notice: TimeCam Pro is an independent camera watermark and video compression tool, not affiliated with any government agency. External links open public websites directly. When capturing or sharing public scenes or license plates, comply with local privacy regulations. All records are stored locally on your device.';
  }
}
