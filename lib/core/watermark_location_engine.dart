import 'package:flutter/foundation.dart';

/// 110 簡訊報案與現場違規快速分類列舉
enum EmergencyIncidentType {
  redLineParking(
    code: 'RED_LINE',
    titleZh: '紅線違停',
    titleEn: 'Red-Zone Parking',
    smsTemplateZh: '紅線違規停車，影響車道通行安全，請派員協助處理。',
    smsTemplateEn: 'Illegal parking on red curb obstructing traffic flow.',
  ),
  doubleParking(
    code: 'DOUBLE_PARK',
    titleZh: '併排停車',
    titleEn: 'Double Parking',
    smsTemplateZh: '車輛嚴重併排停車占用車道，造成後方車流回堵與危險，請派員取締。',
    smsTemplateEn: 'Double parking occupying active lane and causing hazard.',
  ),
  sidewalkObstruction(
    code: 'SIDEWALK',
    titleZh: '占用人行道/騎樓',
    titleEn: 'Sidewalk Blocked',
    smsTemplateZh: '車輛違規停放占用人行道/斑馬線，迫使行人走入車道，請派員處理。',
    smsTemplateEn: 'Vehicle blocking pedestrian sidewalk/crosswalk.',
  ),
  trafficAccident(
    code: 'ACCIDENT',
    titleZh: '交通事故報案',
    titleEn: 'Traffic Collision',
    smsTemplateZh: '現場發生道路交通事故，需請警方到場協助測繪與交通疏導。',
    smsTemplateEn: 'Traffic collision occurred on site, police assistance requested.',
  );

  const EmergencyIncidentType({
    required this.code,
    required this.titleZh,
    required this.titleEn,
    required this.smsTemplateZh,
    required this.smsTemplateEn,
  });

  final String code;
  final String titleZh;
  final String titleEn;
  final String smsTemplateZh;
  final String smsTemplateEn;

  String localizedTitle({required bool isZh}) => isZh ? titleZh : titleEn;
  String localizedSmsBody({required bool isZh}) =>
      isZh ? smsTemplateZh : smsTemplateEn;
}

/// 蒐證相機即時浮水印資訊快照模型
@immutable
class WatermarkSnapshot {
  const WatermarkSnapshot({
    required this.utcPlus8FormattedTime,
    required this.cityAndDistrict,
    required this.streetAddress,
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
    required this.plateOrProjectNote,
    required this.isTimeVerified,
    required this.showBrandBadge,
  });

  final String utcPlus8FormattedTime;
  final String cityAndDistrict;
  final String streetAddress;
  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final String plateOrProjectNote;
  final bool isTimeVerified;
  final bool showBrandBadge;

  /// 檢查 GPS 座標是否為有效非零定位 (排除 0.0, 0.0 幾內亞灣無效初始值與 NaN)
  bool get hasValidGps {
    if (!latitude.isFinite || !longitude.isFinite) return false;
    if (latitude.abs() < 0.0001 && longitude.abs() < 0.0001) return false;
    return latitude >= -90.0 &&
        latitude <= 90.0 &&
        longitude >= -180.0 &&
        longitude <= 180.0;
  }

  /// 格式化精準小數點後 5 位之 GPS 座標與海拔字串 (誤差 <= 1.1m)
  String formattedCoordinates({required bool isZh}) {
    if (!hasValidGps) {
      return isZh ? 'GPS 衛星定位校準中...' : 'Calibrating GPS...';
    }
    final String latDir = latitude >= 0 ? 'N' : 'S';
    final String lngDir = longitude >= 0 ? 'E' : 'W';
    final String latStr = latitude.abs().toStringAsFixed(5);
    final String lngStr = longitude.abs().toStringAsFixed(5);
    final String altStr =
        altitudeMeters.isFinite ? altitudeMeters.toStringAsFixed(1) : '0.0';
    return '$latStr° $latDir, $lngStr° $lngDir  (H: ${altStr}m)';
  }

  /// 完整合併地址字串
  String get fullAddress => '$cityAndDistrict$streetAddress';

  WatermarkSnapshot copyWith({
    String? utcPlus8FormattedTime,
    String? cityAndDistrict,
    String? streetAddress,
    double? latitude,
    double? longitude,
    double? altitudeMeters,
    String? plateOrProjectNote,
    bool? isTimeVerified,
    bool? showBrandBadge,
  }) {
    return WatermarkSnapshot(
      utcPlus8FormattedTime:
          utcPlus8FormattedTime ?? this.utcPlus8FormattedTime,
      cityAndDistrict: cityAndDistrict ?? this.cityAndDistrict,
      streetAddress: streetAddress ?? this.streetAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitudeMeters: altitudeMeters ?? this.altitudeMeters,
      plateOrProjectNote: plateOrProjectNote ?? this.plateOrProjectNote,
      isTimeVerified: isTimeVerified ?? this.isTimeVerified,
      showBrandBadge: showBrandBadge ?? this.showBrandBadge,
    );
  }
}

/// 時間地點浮水印與 110 簡訊報案核心引擎
class WatermarkLocationEngine {
  const WatermarkLocationEngine._();

  /// 台灣標準時間時區偏移量 (UTC+8)
  static const Duration taiwanTimeZoneOffset = Duration(hours: 8);
  /// 將任意時區之時間強制校正為台灣標準時間 (UTC+8)，輸出 YYYY/MM/DD HH:mm:ss 格式
  static String formatTaiwanTimestamp(
    DateTime rawTime, {
    bool includeMilliseconds = false,
  }) {
    final DateTime twTime = rawTime.toUtc().add(taiwanTimeZoneOffset);
    final String y = twTime.year.toString().padLeft(4, '0');
    final String m = twTime.month.toString().padLeft(2, '0');
    final String d = twTime.day.toString().padLeft(2, '0');
    final String hh = twTime.hour.toString().padLeft(2, '0');
    final String mm = twTime.minute.toString().padLeft(2, '0');
    final String ss = twTime.second.toString().padLeft(2, '0');
    if (!includeMilliseconds) {
      return '$y/$m/$d $hh:$mm:$ss';
    }
    final String ms = (twTime.millisecond ~/ 10).toString().padLeft(2, '0');
    return '$y/$m/$d $hh:$mm:$ss.$ms';
  }

  /// 驗證經緯度是否位於台灣本島與澎金馬轄區合理範圍 (21.5°N ~ 26.5°N, 118.0°E ~ 122.5°E)
  static bool isWithinTaiwanBounds(double latitude, double longitude) {
    if (!latitude.isFinite || !longitude.isFinite) return false;
    return latitude >= 21.5 &&
        latitude <= 26.5 &&
        longitude >= 118.0 &&
        longitude <= 122.5;
  }

  /// 建立安全且經過邊界消毒之即時浮水印快照
  static WatermarkSnapshot createSnapshot({
    required DateTime timestamp,
    String? cityAndDistrict,
    String? streetAddress,
    double latitude = 25.03396,
    double longitude = 121.56447,
    double altitudeMeters = 12.5,
    String plateOrProjectNote = '',
    bool isTimeVerified = true,
    bool isProUnlocked = false,
    bool isZh = true,
  }) {
    final String formattedTime = formatTaiwanTimestamp(timestamp);
    final String defaultCity = isZh ? '台北市信義區' : 'Xinyi Dist., Taipei City ';
    final String defaultStreet = isZh ? '市府路1號 (定位更新中)' : 'No. 1, City Hall Rd.';

    final String safeCity =
        (cityAndDistrict == null || cityAndDistrict.trim().isEmpty)
            ? defaultCity
            : cityAndDistrict.trim();
    final String safeStreet =
        (streetAddress == null || streetAddress.trim().isEmpty)
            ? defaultStreet
            : streetAddress.trim();

    final double safeLat = latitude.isFinite ? latitude.clamp(-90.0, 90.0) : 0.0;
    final double safeLng =
        longitude.isFinite ? longitude.clamp(-180.0, 180.0) : 0.0;
    final double safeAlt =
        altitudeMeters.isFinite ? altitudeMeters.clamp(-500.0, 9000.0) : 0.0;

    return WatermarkSnapshot(
      utcPlus8FormattedTime: formattedTime,
      cityAndDistrict: safeCity,
      streetAddress: safeStreet,
      latitude: safeLat,
      longitude: safeLng,
      altitudeMeters: safeAlt,
      plateOrProjectNote: plateOrProjectNote.trim(),
      isTimeVerified: isTimeVerified,
      showBrandBadge: !isProUnlocked,
    );
  }
  /// 台灣各縣市警察局勤務指揮中心 110 報案簡訊專線對照表
  static const Map<String, String> _city110SmsNumbers = <String, String>{
    '台北市': '0911510914',
    '臺北市': '0911510914',
    '新北市': '0911510105',
    '桃園市': '0917110110',
    '台中市': '0911510915',
    '臺中市': '0911510915',
    '台南市': '0911510916',
    '臺南市': '0911510916',
    '高雄市': '0911510917',
    '基隆市': '0911510918',
    '新竹市': '0911510919',
    '新竹縣': '0911510920',
    '彰化縣': '0911510922',
    '屏東縣': '0911510929',
  };

  /// 根據當前地址自動匹配該縣市警察局報案簡訊專線 (若未匹配則回傳全國通用 110)
  static String resolve110SmsRecipient(String cityAndDistrict) {
    for (final MapEntry<String, String> entry in _city110SmsNumbers.entries) {
      if (cityAndDistrict.contains(entry.key)) {
        return entry.value;
      }
    }
    return '110';
  }

  /// 一鍵生成符合各縣市警局勤務指揮中心規範之 110 報案簡訊本文
  static String build110SmsBody({
    required WatermarkSnapshot snapshot,
    required EmergencyIncidentType incidentType,
    required bool isZh,
  }) {
    final String rawNote = snapshot.plateOrProjectNote.trim();
    final String safeNote = rawNote.length > 40
        ? '${rawNote.substring(0, 40)}...'
        : (rawNote.isEmpty ? (isZh ? '現場違規車輛' : 'N/A') : rawNote);
    final String gpsText = snapshot.formattedCoordinates(isZh: isZh);

    if (isZh) {
      return '【110簡訊報案】\n'
          '時間：${snapshot.utcPlus8FormattedTime}\n'
          '地點：${snapshot.fullAddress}\n'
          '座標：$gpsText\n'
          '車號/備註：$safeNote\n'
          '事由：${incidentType.localizedSmsBody(isZh: true)}';
    }

    return '[SMS Police Report]\n'
        'Time: ${snapshot.utcPlus8FormattedTime}\n'
        'Addr: ${snapshot.fullAddress}\n'
        'GPS: $gpsText\n'
        'Plate/Note: $safeNote\n'
        'Issue: ${incidentType.localizedSmsBody(isZh: false)}';
  }

  /// 生成安全編碼之跨平台 sms: 啟動 URI
  static Uri build110SmsUri({
    required WatermarkSnapshot snapshot,
    required EmergencyIncidentType incidentType,
    required bool isZh,
  }) {
    final String recipient = resolve110SmsRecipient(snapshot.cityAndDistrict);
    final String body = build110SmsBody(
      snapshot: snapshot,
      incidentType: incidentType,
      isZh: isZh,
    );
    final String encodedBody =
        Uri.encodeComponent(body).replaceAll('+', '%20');
    return Uri.parse('sms:$recipient?body=$encodedBody');
  }
}