import 'package:flutter/foundation.dart';

enum UserPersonaMode {
  fieldEngineering(
    titleZh: '工程與案場巡檢',
    titleEn: 'Field Engineering',
    notePrefixZh: '工程案場',
    notePrefixEn: 'Project Site',
    defaultSampleNote: 'A08 案場配管配線查驗合格',
  ),
  logisticsProof(
    titleZh: '配送與驗車打卡',
    titleEn: 'Delivery & Fleet Proof',
    notePrefixZh: '配送單號',
    notePrefixEn: 'Order ID',
    defaultSampleNote: 'TW-99281 已送達指定窗口簽收',
  ),
  trafficEvidence(
    titleZh: '行車與路口蒐證',
    titleEn: 'Traffic & Incident Log',
    notePrefixZh: '車牌 / 備註',
    notePrefixEn: 'Plate / Note',
    defaultSampleNote: 'ABC-1234 路口影像存證',
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
    String tzLabel = 'UTC+8',
  }) {
    switch (mode) {
      case UserPersonaMode.fieldEngineering:
        return isZh ? '$tzLabel 工程巡檢' : '$tzLabel INSPECTION';
      case UserPersonaMode.logisticsProof:
        return isZh ? '$tzLabel 配送存證' : '$tzLabel LOGISTICS';
      case UserPersonaMode.trafficEvidence:
        return isZh ? '$tzLabel 行車存證' : '$tzLabel INCIDENT LOG';
    }
  }

  static String buildInputHint(
    UserPersonaMode mode, {
    required bool isZh,
  }) {
    switch (mode) {
      case UserPersonaMode.fieldEngineering:
        return isZh
            ? '輸入案場編號與查驗項目 (例: 案場#A08 合格)'
            : 'Enter site & inspection note (e.g. Site #A08 OK)';
      case UserPersonaMode.logisticsProof:
        return isZh
            ? '輸入配送單號與簽收狀態 (例: TW-99281 已簽收)'
            : 'Enter order ID & handoff note (e.g. TW-99281 Delivered)';
      case UserPersonaMode.trafficEvidence:
        return isZh
            ? '輸入車牌號碼或現場備註 (例: ABC-1234)'
            : 'Enter plate number or note (e.g. ABC-1234)';
    }
  }

  static String buildPersonaPaywallPitch(
    UserPersonaMode mode, {
    required bool isZh,
  }) {
    switch (mode) {
      case UserPersonaMode.fieldEngineering:
        return isZh
            ? '升級 Pro 專業版：啟用專屬公司抬頭浮水印、批次多筆 A4 驗收 PDF 報告與無限影片壓縮。'
            : 'Upgrade to Pro for custom company header watermarks, batch A4 PDF dossiers, and unlimited exports.';
      case UserPersonaMode.logisticsProof:
        return isZh
            ? '升級 Pro 專業版：無限匯出配送存證影片、自訂公司名稱抬頭與多筆 A4 簽收總表 PDF。'
            : 'Upgrade to Pro for unlimited delivery video exports, custom headers, and batch A4 PDF logs.';
      case UserPersonaMode.trafficEvidence:
        return isZh
            ? '升級 Pro 專業版：無限次 20MB / 10MB 影片壓縮匯出與完整 A4 PDF 紀錄彙整。'
            : 'Upgrade to Pro for unlimited 20MB / 10MB video exports and complete A4 PDF logs.';
    }
  }
}
