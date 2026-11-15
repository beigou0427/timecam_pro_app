import 'package:flutter/foundation.dart';

/// 台灣四大地理分區篩選列舉
enum PortalRegion {
  north(labelZh: '北北基桃竹苗', labelEn: 'Northern TW'),
  central(labelZh: '中彰投雲', labelEn: 'Central TW'),
  south(labelZh: '嘉南高屏', labelEn: 'Southern TW'),
  eastAndIslands(labelZh: '宜花東與離島', labelEn: 'Eastern & Islands');

  const PortalRegion({required this.labelZh, required this.labelEn});
  final String labelZh;
  final String labelEn;

  String localizedLabel({required bool isZh}) => isZh ? labelZh : labelEn;
}

/// 本地蒐證案件送件狀態列舉
enum CaseSubmissionStatus {
  pending(labelZh: '待送件 (7日內)', labelEn: 'Pending (7d Limit)'),
  submitted(labelZh: '已完成通報', labelEn: 'Submitted'),
  archived(labelZh: '純存證歸檔', labelEn: 'Archived');

  const CaseSubmissionStatus({required this.labelZh, required this.labelEn});
  final String labelZh;
  final String labelEn;

  String localizedLabel({required bool isZh}) => isZh ? labelZh : labelEn;
}

/// 全台各縣市交通違規與環保局獎金檢舉官方入口模型
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

  /// 安全解析交通檢舉網址 (防崩潰保底)
  Uri get safeTrafficUri {
    final Uri? parsed = Uri.tryParse(trafficPortalUrl);
    if (parsed != null && parsed.hasScheme && parsed.scheme == 'https') {
      return parsed;
    }
    return Uri.parse('https://www.npa.gov.tw/');
  }

  /// 安全解析環保局檢舉網址 (防崩潰保底)
  Uri get safeEpaUri {
    final Uri? parsed = Uri.tryParse(epaPortalUrl);
    if (parsed != null && parsed.hasScheme && parsed.scheme == 'https') {
      return parsed;
    }
    return Uri.parse('https://www.moenv.gov.tw/');
  }
}

/// 道路交通管理處罰條例與環保法規標準事實描述模板模型
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

/// 本地加密/隔離案件紀錄模型
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
  });

  final String id;
  final DateTime capturedAtUtc;
  final String formattedTimeUtc8;
  final String address;
  final String plateOrNote;
  final String statuteCode;
  final double compressedSizeMB;
  final CaseSubmissionStatus status;

  EvidenceCaseRecord copyWith({
    CaseSubmissionStatus? status,
    String? plateOrNote,
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
    );
  }
}

/// 全台 22 縣市通報入口、法條描述模板庫與 7 日舉發時效管理引擎
class TaiwanReportRepository {
  const TaiwanReportRepository._();

  /// 道交條例第 7-1 條法定舉發有效期限 (自違規日起算 7 日內)
  static const int statutoryReportLimitDays = 7;
  /// 全台主要縣市警察局交通違規與環保局獎金檢舉官方入口清單
  static const List<CityReportPortal> allCityPortals = <CityReportPortal>[
    CityReportPortal(
      id: 'taipei_city',
      region: PortalRegion.north,
      cityNameZh: '台北市',
      cityNameEn: 'Taipei City',
      trafficPortalUrl: 'https://tvrs.tcpd.gov.tw/',
      epaPortalUrl: 'https://www.dep.gov.taipei/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '亂丟煙蒂/垃圾實收罰鍰 30%~50% 檢舉獎金',
      epaRewardNoteEn: '30%~50% EPA reward for littering/cigarette butts',
    ),
    CityReportPortal(
      id: 'new_taipei',
      region: PortalRegion.north,
      cityNameZh: '新北市',
      cityNameEn: 'New Taipei City',
      trafficPortalUrl: 'https://tvrs.ntpd.gov.tw/',
      epaPortalUrl: 'https://www.epd.ntpc.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '亂丟煙蒂/垃圾實收罰鍰 30% 檢舉獎金',
      epaRewardNoteEn: '30% EPA reward for verified littering reports',
    ),
    CityReportPortal(
      id: 'taoyuan',
      region: PortalRegion.north,
      cityNameZh: '桃園市',
      cityNameEn: 'Taoyuan City',
      trafficPortalUrl: 'https://tvrs.tyhp.gov.tw/',
      epaPortalUrl: 'https://www.tydep.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '環境清潔違規實收罰鍰 20%~30% 獎金',
      epaRewardNoteEn: '20%~30% EPA environmental reward',
    ),
    CityReportPortal(
      id: 'hsinchu',
      region: PortalRegion.north,
      cityNameZh: '新竹市 / 新竹縣',
      cityNameEn: 'Hsinchu City & County',
      trafficPortalUrl: 'https://tra.hccp.gov.tw/',
      epaPortalUrl: 'https://www.hccepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '亂丟廢棄物實收罰鍰 30% 檢舉獎金',
      epaRewardNoteEn: '30% EPA reward for illegal waste disposal',
    ),
    CityReportPortal(
      id: 'taichung',
      region: PortalRegion.central,
      cityNameZh: '台中市',
      cityNameEn: 'Taichung City',
      trafficPortalUrl: 'https://suggest.police.taichung.gov.tw/traffic/',
      epaPortalUrl: 'https://www.epb.taichung.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '亂丟煙蒂/吐檳榔汁實收罰鍰 20%~30% 獎金',
      epaRewardNoteEn: '20%~30% EPA reward for littering violations',
    ),
    CityReportPortal(
      id: 'changhua_nantou',
      region: PortalRegion.central,
      cityNameZh: '彰化縣 / 南投縣 / 雲林縣',
      cityNameEn: 'Changhua / Nantou / Yunlin',
      trafficPortalUrl: 'https://www.chpb.gov.tw/',
      epaPortalUrl: 'https://www.chepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '環境污染與亂丟垃圾實收罰鍰 20% 獎金',
      epaRewardNoteEn: '20% EPA reward for verified reports',
    ),
    CityReportPortal(
      id: 'tainan',
      region: PortalRegion.south,
      cityNameZh: '台南市',
      cityNameEn: 'Tainan City',
      trafficPortalUrl: 'https://ba.tnpd.gov.tw/',
      epaPortalUrl: 'https://www.tnepb.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '亂丟煙蒂/垃圾實收罰鍰 10%~30% 檢舉獎金',
      epaRewardNoteEn: '10%~30% EPA reward for littering reports',
    ),
    CityReportPortal(
      id: 'kaohsiung',
      region: PortalRegion.south,
      cityNameZh: '高雄市 / 屏東縣 / 嘉義',
      cityNameEn: 'Kaohsiung / Pingtung / Chiayi',
      trafficPortalUrl: 'https://trs.kcpd.gov.tw/',
      epaPortalUrl: 'https://ksepb.kcg.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '亂丟煙蒂/廢棄物實收罰鍰 20%~35% 獎金',
      epaRewardNoteEn: '20%~35% EPA reward for littering violations',
    ),
    CityReportPortal(
      id: 'east_highway',
      region: PortalRegion.eastAndIslands,
      cityNameZh: '宜花東 / 國道公路警察局',
      cityNameEn: 'East TW & National Highway Police',
      trafficPortalUrl: 'https://tvrs.hpb.gov.tw/',
      epaPortalUrl: 'https://www.moenv.gov.tw/',
      maxTrafficVideoMB: 20.0,
      epaRewardNoteZh: '國道違規上限 20MB / 環境部全區通報網',
      epaRewardNoteEn: 'Highway Police 20MB limit & National EPA Portal',
    ),
  ];

  /// 道路交通管理處罰條例與環保法規標準事實描述模板庫
  static const List<TrafficStatuteTemplate> statuteTemplates =
      <TrafficStatuteTemplate>[
    TrafficStatuteTemplate(
      code: 'ART_42_SIGNAL',
      articleNumberZh: '道交條例 第 42 條',
      articleNumberEn: 'Traffic Act Art. 42',
      violationTitleZh: '轉彎或變換車道未依規定使用方向燈',
      violationTitleEn: 'Failure to Signal When Turning or Changing Lanes',
      fineRangeTextZh: r'罰鍰 NT$1,200 ~ NT$3,600',
      fineRangeTextEn: r'Fine USD $40 ~ $120',
      templateBodyZh:
          '該車於上述時間與地點，於變換車道（或轉彎）過程中，未依規定全程使用方向燈，跨越車道線影響後方直行車輛反應安全，請貴局依法舉發。',
      templateBodyEn:
          'The vehicle failed to use turn signals throughout the lane change/turn maneuver at the recorded timestamp and location, creating a traffic hazard.',
      isProRequired: false,
    ),
    TrafficStatuteTemplate(
      code: 'ART_53_RED_LIGHT',
      articleNumberZh: '道交條例 第 53 條第 1 項',
      articleNumberEn: 'Traffic Act Art. 53-1',
      violationTitleZh: '行經有燈光號誌管制交岔路口闖紅燈',
      violationTitleEn: 'Running a Red Traffic Light at Intersection',
      fineRangeTextZh: r'罰鍰 NT$1,800 ~ NT$5,400',
      fineRangeTextEn: r'Fine USD $60 ~ $180',
      templateBodyZh:
          '該車於上述路口號誌已轉換為紅燈後，仍超越停止線並繼續穿越交岔路口，明顯構成闖紅燈違規行為，請依法舉發。',
      templateBodyEn:
          'The vehicle crossed the stop line and proceeded through the intersection after the traffic signal had turned completely red.',
      isProRequired: false,
    ),
    TrafficStatuteTemplate(
      code: 'ART_44_PEDESTRIAN',
      articleNumberZh: '道交條例 第 44 條第 2 項',
      articleNumberEn: 'Traffic Act Art. 44-2',
      violationTitleZh: '行近行人穿越道不停讓行人優先通行',
      violationTitleEn: 'Failure to Yield to Pedestrians on Crosswalk',
      fineRangeTextZh: r'罰鍰 NT$1,200 ~ NT$6,000',
      fineRangeTextEn: r'Fine USD $40 ~ $200',
      templateBodyZh:
          '該車行近行人穿越道時，斑馬線上已有行人正在通行，該車未減速暫停禮讓行人優先通過（距離行人不足三公尺/三個枕木紋），嚴重危害行人路權，請依法舉發。',
      templateBodyEn:
          'The vehicle failed to stop and yield to pedestrians actively crossing on the marked crosswalk (passing within 3 meters of the pedestrian).',
      isProRequired: true,
    ),
    TrafficStatuteTemplate(
      code: 'ART_43_AGGRESSIVE',
      articleNumberZh: '道交條例 第 43 條第 1 項',
      articleNumberEn: 'Traffic Act Art. 43-1',
      violationTitleZh: '惡意逼車 / 任意以迫近或驟然變換車道迫使讓道',
      violationTitleEn: 'Aggressive Driving / Tailgating /Sudden Cut-off',
      fineRangeTextZh: r'罰鍰 NT$6,000 ~ NT$36,000 (並吊扣牌照)',
      fineRangeTextEn: r'Fine USD $200 ~ $1,200 (License Suspension)',
      templateBodyZh:
          '該車於行駛途中，任意以迫近、驟然變換車道或於車道中無故驟然減速煞車之方式，迫使他車讓道，嚴重危及行車安全，請依第 43 條危險駕駛依法舉發。',
      templateBodyEn:
          'The vehicle engaged in dangerous driving by intentionally cutting off, tailgating, or braking suddenly in an active traffic lane.',
      isProRequired: true,
    ),
    TrafficStatuteTemplate(
      code: 'ART_45_SIDEWALK',
      articleNumberZh: '道交條例 第 45 條第 1 項',
      articleNumberEn: 'Traffic Act Art. 45-1',
      violationTitleZh: '駕車行駛人行道或逆向行駛 / 跨越雙黃線',
      violationTitleEn: 'Driving on Sidewalk or Crossing Double Yellow Line',
      fineRangeTextZh: r'罰鍰 NT$600 ~ NT$1,800',
      fineRangeTextEn: r'Fine USD $20 ~ $60',
      templateBodyZh:
          '該車於上述時地不依規定駛入來車道（跨越分向限制雙黃線）或違規駕車行駛於人行道上，危害用路人安全，請依法舉發。',
      templateBodyEn:
          'The vehicle unlawfully crossed the double yellow center line into oncoming traffic or drove onto the pedestrian sidewalk.',
      isProRequired: true,
    ),
    TrafficStatuteTemplate(
      code: 'EPA_ART_27_LITTER',
      articleNumberZh: '廢棄物清理法 第 27 條',
      articleNumberEn: 'Waste Disposal Act Art. 27',
      violationTitleZh: '隨地拋棄煙蒂、紙屑、檳榔渣或一般廢棄物 (含獎金)',
      violationTitleEn: 'Discarding Cigarette Butts or Litter from Vehicle',
      fineRangeTextZh: r'罰鍰 NT$1,200 ~ NT$6,000 (可領檢舉獎金)',
      fineRangeTextEn: r'Fine USD $40 ~ $200 (Eligible for EPA Reward)',
      templateBodyZh:
          '該車駕駛人（或騎士）於上述時間地點停等或行進間，清楚拍到自車窗（或手中）將點燃之煙蒂（或垃圾/檳榔渣）拋棄於道路地面，污染環境衛生，附上車牌與拋棄連續過程影片，請依法裁處並核發檢舉獎勵金。',
      templateBodyEn:
          'Continuous video clearly captures the driver/rider discarding a cigarette butt or litter onto the public roadway, along with a clear license plate view.',
      isProRequired: true,
    ),
  ];
  /// 依地理分區與關鍵字篩選全台縣市檢舉入口 (支援中英文不分大小寫搜尋)
  static List<CityReportPortal> filterPortals({
    PortalRegion? region,
    String query = '',
  }) {
    final String cleanQuery = query.trim().toLowerCase();
    if (region == null && cleanQuery.isEmpty) {
      return allCityPortals;
    }
    return allCityPortals.where((CityReportPortal portal) {
      final bool matchRegion = region == null || portal.region == region;
      if (!matchRegion) return false;
      if (cleanQuery.isEmpty) return true;
      return portal.cityNameZh.toLowerCase().contains(cleanQuery) ||
          portal.cityNameEn.toLowerCase().contains(cleanQuery) ||
          portal.epaRewardNoteZh.toLowerCase().contains(cleanQuery);
    }).toList(growable: false);
  }

  /// 計算距離道交條例第 7-1 條「7 日法定舉發期限」之剩餘小時數 (0 ~ 168 小時)
  static int remainingHoursToReport({
    required DateTime capturedAtUtc,
    required DateTime nowUtc,
  }) {
    final DateTime deadlineUtc =
        capturedAtUtc.toUtc().add(const Duration(days: statutoryReportLimitDays));
    final int diffHours = deadlineUtc.difference(nowUtc.toUtc()).inHours;
    return diffHours.clamp(0, statutoryReportLimitDays * 24);
  }

  /// 產生 7 日檢舉黃金期倒數狀態標籤文字
  static String formatDeadlineBadge({
    required EvidenceCaseRecord record,
    required DateTime nowUtc,
    required bool isZh,
  }) {
    if (record.status == CaseSubmissionStatus.submitted) {
      return isZh ? '✅ 已於期限內完成送件' : '✅ Submitted on time';
    }
    if (record.status == CaseSubmissionStatus.archived) {
      return isZh ? '📁 本地純存證歸檔' : '📁 Archived locally';
    }
    final int hoursLeft = remainingHoursToReport(
      capturedAtUtc: record.capturedAtUtc,
      nowUtc: nowUtc,
    );
    if (hoursLeft <= 0) {
      return isZh ? '⚠️ 已逾 7 日法定舉發期' : '⚠️ Expired (>7 days)';
    }
    final int days = hoursLeft ~/ 24;
    final int remHours = hoursLeft % 24;
    if (isZh) {
      return '⏳ 舉發期限剩 $days 天 $remHours 小時';
    }
    return '⏳ ${days}d ${remHours}h left to report';
  }

  /// 一鍵合成可直接貼入警局/環保局網頁「違規事實描述欄」之完整標準陳述文
  static String composeFullReportStatement({
    required TrafficStatuteTemplate template,
    required String formattedTimeUtc8,
    required String fullAddress,
    required String plateNumber,
    required bool isZh,
  }) {
    final String safePlate = plateNumber.trim().isEmpty
        ? (isZh ? '（詳見影片車牌）' : '(See plate in video)')
        : plateNumber.trim();
    if (isZh) {
      return '【違規時間】$formattedTimeUtc8\n'
          '【違規地點】$fullAddress\n'
          '【違規車號】$safePlate\n'
          '【違反法條】${template.articleNumberZh}（${template.violationTitleZh}）\n'
          '【違規事實】${template.templateBodyZh}';
    }
    return '[Time] $formattedTimeUtc8\n'
        '[Location] $fullAddress\n'
        '[License Plate] $safePlate\n'
        '[Statute] ${template.articleNumberEn} (${template.violationTitleEn})\n'
        '[Statement] ${template.templateBodyEn}';
  }

  /// 建立預設本地案件庫種子資料 (供初次啟動與審核展示)
  static List<EvidenceCaseRecord> createInitialCases(DateTime referenceUtc) {
    final DateTime baseUtc = referenceUtc.toUtc();
    return <EvidenceCaseRecord>[
      EvidenceCaseRecord(
        id: 'CASE-2026-01',
        capturedAtUtc: baseUtc.subtract(const Duration(hours: 38)),
        formattedTimeUtc8: '2026/11/14 14:22:10',
        address: '台北市信義區忠孝東路五段22號前',
        plateOrNote: 'ABC-8899 紅線併排違停',
        statuteCode: 'ART_42_SIGNAL',
        compressedSizeMB: 18.6,
        status: CaseSubmissionStatus.pending,
      ),
      EvidenceCaseRecord(
        id: 'CASE-2026-02',
        capturedAtUtc: baseUtc.subtract(const Duration(hours: 96)),
        formattedTimeUtc8: '2026/11/11 08:45:33',
        address: '台南市東區中華東路三段路口',
        plateOrNote: 'RCD-5566 斑馬線未禮讓行人',
        statuteCode: 'ART_44_PEDESTRIAN',
        compressedSizeMB: 17.9,
        status: CaseSubmissionStatus.submitted,
      ),
    ];
  }

  /// Apple App Review Guideline 5.2.2 官方獨立工具免責聲明
  static String officialDisclaimer({required bool isZh}) {
    if (isZh) {
      return '免責聲明：本應用程式為獨立開發之現場影像時間水印與容量壓縮輔助工具，非政府機關官方應用。各縣市通報入口皆直接開啟政府公開網站，所有資料100%儲存於您的手機本地。';
    }
    return 'Disclaimer: This app is an independent field timestamp and video compression utility, not affiliated with any government entity. All portal links open official public websites, and all data stays 100% locally on your device.';
  }
}