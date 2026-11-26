import 'package:flutter/foundation.dart';

/// 現場事件與位置摘要分類列舉（非自動撥號／非違規檢舉切結，僅作位置分享草稿）
enum EmergencyIncidentType {
  laneHazard(
    code: 'LANE_HAZARD',
    titleZh: '車道障礙 / 安全事故',
    titleEn: 'Lane Hazard / Incident',
    summaryTemplateZh: '現場發現車道障礙或影響通行安全狀況，提供即時位置摘要以供記錄或通報參考。',
    summaryTemplateEn: 'Lane obstruction or traffic safety hazard observed at recorded GPS coordinates.',
  ),
  doubleParking(
    code: 'OBSTRUCTION',
    titleZh: '道路占用阻塞',
    titleEn: 'Road Obstruction',
    summaryTemplateZh: '現場車道嚴重受阻影響通行安全，附上時間與位置資訊供協助處理參考。',
    summaryTemplateEn: 'Active traffic lane severely obstructed; timestamped GPS summary attached.',
  ),
  sidewalkObstruction(
    code: 'SIDEWALK',
    titleZh: '人行通道受阻',
    titleEn: 'Sidewalk Blocked',
    summaryTemplateZh: '人行通道或路口通行空間受阻影響行人安全，提供現場座標摘要供參考。',
    summaryTemplateEn: 'Pedestrian walkway or crossing obstructed at recorded location.',
  ),
  trafficAccident(
    code: 'ACCIDENT',
    titleZh: '交通事故記錄',
    titleEn: 'Traffic Collision',
    summaryTemplateZh: '現場發生道路交通事故，記錄時間與精準座標以利後續聯繫與協助處理。',
    summaryTemplateEn: 'Traffic collision recorded on site with verified timestamp and GPS fix.',
  );

  const EmergencyIncidentType({
    required this.code,
    required this.titleZh,
    required this.titleEn,
    required this.summaryTemplateZh,
    required this.summaryTemplateEn,
  });

  final String code;
  final String titleZh;
  final String titleEn;
  final String summaryTemplateZh;
  final String summaryTemplateEn;

  String localizedTitle({required bool isZh}) => isZh ? titleZh : titleEn;
  String localizedSummaryBody({required bool isZh}) =>
      isZh ? summaryTemplateZh : summaryTemplateEn;
}

/// 相機即時時間與定位浮水印快照模型
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

  /// 格式化 GPS 座標與海拔字串 (若無實機定位，誠實顯示未取得定位，絕不偽造座標)
  String formattedCoordinates({required bool isZh}) {
    if (!hasValidGps) {
      return isZh ? '尚未取得 GPS 定位' : 'No GPS Fix';
    }
    final String latDir = latitude >= 0 ? 'N' : 'S';
    final String lngDir = longitude >= 0 ? 'E' : 'W';
    final String latStr = latitude.abs().toStringAsFixed(5);
    final String lngStr = longitude.abs().toStringAsFixed(5);
    final String altStr =
        altitudeMeters.isFinite ? altitudeMeters.toStringAsFixed(1) : '0.0';
    return '$latStr° $latDir, $lngStr° $lngDir  (H: ${altStr}m)';
  }

  /// 完整合併地址字串（英文地址自動在地區與門牌間補上逗號與空格）
  String get fullAddress {
    final String c = cityAndDistrict.trim();
    final String s = streetAddress.trim();
    if (c.isEmpty) return s;
    if (s.isEmpty) return c;
    final bool asciiBoundary =
        RegExp(r'[A-Za-z0-9]$').hasMatch(c) ||
        RegExp(r'^[A-Za-z0-9]').hasMatch(s);
    return asciiBoundary ? '$c, $s' : '$c$s';
  }

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

/// 時間與真實定位浮水印引擎
class WatermarkLocationEngine {
  const WatermarkLocationEngine._();

  static const Duration taiwanTimeZoneOffset = Duration(hours: 8);

  /// 依裝置當地時區格式化現場時間 (YYYY/MM/DD HH:mm:ss)
  static String formatLocalTimestamp(
    DateTime rawTime, {
    bool includeMilliseconds = false,
  }) {
    final DateTime local = rawTime.toLocal();
    return _formatDateTimeParts(local, includeMilliseconds: includeMilliseconds);
  }

  /// 取得裝置目前當地時區標籤 (例如 UTC+8、UTC-5、UTC+9:30)
  static String formatLocalTimezoneLabel(DateTime rawTime) {
    final Duration offset = rawTime.toLocal().timeZoneOffset;
    final int totalMinutes = offset.inMinutes;
    final String sign = totalMinutes >= 0 ? '+' : '-';
    final int absMin = totalMinutes.abs();
    final int hrs = absMin ~/ 60;
    final int mins = absMin % 60;
    return mins == 0
        ? 'UTC$sign$hrs'
        : 'UTC$sign$hrs:${mins.toString().padLeft(2, '0')}';
  }

  /// 將任意時區時間格式化為台灣標準時間 (UTC+8)
  static String formatTaiwanTimestamp(
    DateTime rawTime, {
    bool includeMilliseconds = false,
  }) {
    final DateTime twTime = rawTime.toUtc().add(taiwanTimeZoneOffset);
    return _formatDateTimeParts(twTime, includeMilliseconds: includeMilliseconds);
  }

  static String _formatDateTimeParts(
    DateTime t, {
    required bool includeMilliseconds,
  }) {
    final String y = t.year.toString().padLeft(4, '0');
    final String m = t.month.toString().padLeft(2, '0');
    final String d = t.day.toString().padLeft(2, '0');
    final String hh = t.hour.toString().padLeft(2, '0');
    final String mm = t.minute.toString().padLeft(2, '0');
    final String ss = t.second.toString().padLeft(2, '0');
    if (!includeMilliseconds) {
      return '$y/$m/$d $hh:$mm:$ss';
    }
    final String ms = (t.millisecond ~/ 10).toString().padLeft(2, '0');
    return '$y/$m/$d $hh:$mm:$ss.$ms';
  }

  /// 驗證經緯度是否位於台灣本島與澎金馬轄區合理範圍
  static bool isWithinTaiwanBounds(double latitude, double longitude) {
    if (!latitude.isFinite || !longitude.isFinite) return false;
    return latitude >= 21.5 &&
        latitude <= 26.5 &&
        longitude >= 118.0 &&
        longitude <= 122.5;
  }

  /// 建立誠實且經過邊界消毒的浮水印快照（無真實 GPS 時嚴禁偽造假地址與假座標）
  static WatermarkSnapshot createSnapshot({
    required DateTime timestamp,
    String? cityAndDistrict,
    String? streetAddress,
    double latitude = double.nan,
    double longitude = double.nan,
    double altitudeMeters = double.nan,
    String plateOrProjectNote = '',
    bool isTimeVerified = false,
    bool isProUnlocked = false,
    bool isZh = true,
    bool useLocalTimezone = true,
  }) {
    final String formattedTime = useLocalTimezone
        ? formatLocalTimestamp(timestamp)
        : formatTaiwanTimestamp(timestamp);

    final double safeLat =
        latitude.isFinite ? latitude.clamp(-90.0, 90.0) : double.nan;
    final double safeLng =
        longitude.isFinite ? longitude.clamp(-180.0, 180.0) : double.nan;
    final double safeAlt =
        altitudeMeters.isFinite ? altitudeMeters.clamp(-500.0, 9000.0) : double.nan;

    final bool validCoords = safeLat.isFinite &&
        safeLng.isFinite &&
        !(safeLat.abs() < 0.0001 && safeLng.abs() < 0.0001);

    final String cleanCity = (cityAndDistrict ?? '').trim();
    final String cleanStreet = (streetAddress ?? '').trim();

    final String resolvedCity = cleanCity;
    final String resolvedStreet = cleanStreet.isNotEmpty
        ? cleanStreet
        : (validCoords
            ? (isZh ? '已完成衛星座標定位' : 'GPS Coordinates Locked')
            : (isZh ? '尚未取得定位（請確認系統定位權限）' : 'Location unavailable — enable GPS'));

    return WatermarkSnapshot(
      utcPlus8FormattedTime: formattedTime,
      cityAndDistrict: resolvedCity,
      streetAddress: resolvedStreet,
      latitude: safeLat,
      longitude: safeLng,
      altitudeMeters: safeAlt,
      plateOrProjectNote: plateOrProjectNote.trim(),
      isTimeVerified: isTimeVerified,
      showBrandBadge: !isProUnlocked,
    );
  }

  /// 生成可複製或分享的即時時間地點摘要（取代硬編碼與可能誤撥的縣市 110 號碼）
  static String buildLocationSummaryForShare({
    required WatermarkSnapshot snapshot,
    required EmergencyIncidentType incidentType,
    required bool isZh,
  }) {
    final String rawNote = snapshot.plateOrProjectNote.trim();
    final String safeNote = rawNote.length > 48
        ? '${rawNote.substring(0, 48)}...'
        : (rawNote.isEmpty ? (isZh ? '未填寫備註' : 'N/A') : rawNote);
    final String gpsText = snapshot.formattedCoordinates(isZh: isZh);
    final String addrText = snapshot.fullAddress;

    if (isZh) {
      return '【現場時間地點摘要】\n'
          '時間：${snapshot.utcPlus8FormattedTime}\n'
          '地點：$addrText\n'
          '座標：$gpsText\n'
          '編號/備註：$safeNote\n'
          '狀況說明：${incidentType.localizedSummaryBody(isZh: true)}';
    }

    return '[Timestamped Location Summary]\n'
        'Time: ${snapshot.utcPlus8FormattedTime}\n'
        'Address: $addrText\n'
        'GPS: $gpsText\n'
        'Ref/Note: $safeNote\n'
        'Details: ${incidentType.localizedSummaryBody(isZh: false)}';
  }
}
