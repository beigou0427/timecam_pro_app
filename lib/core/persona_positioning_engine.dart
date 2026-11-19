import 'package:flutter/foundation.dart';

enum UserPersonaMode {
  trafficEvidence(
    titleZh: '🚓 行車違規蒐證',
    titleEn: '🚓 Traffic Evidence',
    notePrefixZh: '違規車牌',
    notePrefixEn: 'License Plate',
    defaultSampleNote: 'ABC-1234 紅線違停',
  ),
  fieldEngineering(
    titleZh: '👷 外勤工程巡檢',
    titleEn: '👷 Field Inspection',
    notePrefixZh: '工程案場',
    notePrefixEn: 'Project Site',
    defaultSampleNote: '台南七股太陽能案場 #A08 巡檢合格',
  ),
  logisticsProof(
    titleZh: '📦 物流配送打卡',
    titleEn: '📦 Delivery Proof',
    notePrefixZh: '配送單號',
    notePrefixEn: 'Order ID',
    defaultSampleNote: 'TW-99281 已送達管理室簽收',
  );

  const UserPersonaMode({
    required this.titleZh,
    required this.titleEn,
    required this.notePrefixZh,
    required this.notePrefixEn,
    required this.defaultSampleNote,
  });
  final String titleZh;
  final String titleEn;
  final String notePrefixZh;
  final String notePrefixEn;
  final String defaultSampleNote;
  String localizedTitle({required bool isZh}) => isZh ? titleZh : titleEn;
}

@immutable
class PersonaPositioningEngine {
  const PersonaPositioningEngine._();

  static String buildWatermarkHeader(
    UserPersonaMode mode, {
    required bool isZh,
  }) {
    switch (mode) {
      case UserPersonaMode.trafficEvidence:
        return isZh ? 'UTC+8 交通蒐證' : 'UTC+8 TRAFFIC';
      case UserPersonaMode.fieldEngineering:
        return isZh ? 'UTC+8 工程巡檢' : 'UTC+8 INSPECTION';
      case UserPersonaMode.logisticsProof:
        return isZh ? 'UTC+8 物流簽收' : 'UTC+8 LOGISTICS';
    }
  }

  static String buildInputHint(
    UserPersonaMode mode, {
    required bool isZh,
  }) {
    switch (mode) {
      case UserPersonaMode.trafficEvidence:
        return isZh
            ? '輸入違規車牌與態樣 (例: ABC-1234 紅線違停)'
            : 'Enter plate & violation (e.g. ABC-1234)';
      case UserPersonaMode.fieldEngineering:
        return isZh
            ? '輸入太陽能/工地案場與項目 (例: 案場#A08 巡檢合格)'
            : 'Enter site & inspection note (e.g. Site #A08 OK)';
      case UserPersonaMode.logisticsProof:
        return isZh
            ? '輸入配送單號與簽收狀態 (例: TW-99281 已送達)'
            : 'Enter order ID & proof (e.g. TW-99281 Delivered)';
    }
  }

  static String buildPersonaPaywallPitch(
    UserPersonaMode mode, {
    required bool isZh,
  }) {
    switch (mode) {
      case UserPersonaMode.trafficEvidence:
        return isZh
            ? r'🚓 升級 Pro (NT$590 買斷)：永久解鎖 20MB 檢舉影片壓縮與全台道交法條模板！'
            : r'🚓 Pro Lifetime ($19.99): Unlimited 20MB video compression & traffic templates!';
      case UserPersonaMode.fieldEngineering:
        return isZh
            ? r'👷 升級 Pro (NT$590 買斷)：移除右下角品牌標章、啟用完整 12 碼防偽指紋與案場抬頭！'
            : r'👷 Pro Lifetime ($19.99): Remove brand badge & unlock full 12-char integrity seal!';
      case UserPersonaMode.logisticsProof:
        return isZh
            ? r'📦 升級 Pro (NT$590 買斷)：無限匯出高壓縮比配送存證影片與防竄改時間水印！'
            : r'📦 Pro Lifetime ($19.99): Unlimited delivery proof video compression & UTC+8 seal!';
    }
  }
}
