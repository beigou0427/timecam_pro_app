import 'package:flutter/foundation.dart';

enum NuclearLocaleSlot {
  zhHant('zh-Hant'),
  enGb('en-GB'),
  enUs('en-US'),
  zhHans('zh-Hans'),
  esMx('es-MX'),
  ko('ko'),
  vi('vi'),
  ptBr('pt-BR'),
  frFr('fr-FR'),
  arSa('ar-SA');

  const NuclearLocaleSlot(this.code);
  final String code;
}

@immutable
class NuclearLocalePayload {
  const NuclearLocalePayload({
    required this.slot,
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.promo,
  });
  final NuclearLocaleSlot slot;
  final String title;
  final String subtitle;
  final String keywords;
  final String promo;
}

@immutable
class IapKeywordSpec {
  const IapKeywordSpec({
    required this.skuId,
    required this.displayNameZh,
    required this.displayNameEn,
    required this.priceNtd,
  });
  final String skuId;
  final String displayNameZh;
  final String displayNameEn;
  final int priceNtd;
}

@immutable
class OcrScreenshotCaption {
  const OcrScreenshotCaption({
    required this.index,
    required this.headlineZh,
    required this.sublineZh,
    required this.headlineEn,
  });
  final int index;
  final String headlineZh;
  final String sublineZh;
  final String headlineEn;
}

class AsoNuclear10LocaleEngine {
  const AsoNuclear10LocaleEngine._();
  static const int paretoTop1Multiplier = 95;
  static const double iapDemandBoost = 0.28;
  static const double searchTrafficShare = 0.65;

  static const List<NuclearLocalePayload> localeMatrix = <NuclearLocalePayload>[
    NuclearLocalePayload(slot: NuclearLocaleSlot.zhHant, title: '時間相機：GPS水印打卡與經緯度・20MB影片壓縮錄影', subtitle: '行車紀錄器違規檢舉・環保煙蒂獎金・工地外勤拍照防偽', keywords: '記錄,巡檢,太陽能,施工,驗收,轉檔,裁切,定位,地址,座標,車牌,罰單,時光,110', promo: r'🎁 新戶免費1次20MB壓縮！拍煙蒂實領NT$864回本'),
    NuclearLocalePayload(slot: NuclearLocaleSlot.enGb, title: '日期戳記110報案助手・車禍蒐證A4工程PDF', subtitle: '未禮讓行人闖紅燈併排紅線・太陽能營造水電報帳統編', keywords: 'TimeCam,Timestamp,Watermark,Dashcam,Trim,Resize,Log,Audit,GPS,Exif,Solar,Pipe,Site', promo: r'Compress 4K clips under 19MB & export A4 audit PDFs'),
    NuclearLocalePayload(slot: NuclearLocaleSlot.enUs, title: 'Timestamp Camera: GPS & 20MB', subtitle: 'Watermark Cam, Video Trim, Log', keywords: 'dashcam,bitrate,resize,compress,evidence,inspection,coordinates,address,fieldwork,solar,pdf,audit', promo: r'Try 1 FREE 20MB 4K compression & tamper-proof GPS seals'),
    NuclearLocalePayload(slot: NuclearLocaleSlot.zhHans, title: '时间相机-水印经纬度打卡・20MB视频压缩工程取证', subtitle: '行车记录仪防伪时间戳・外勤考勤巡检验收日期定位', keywords: '坐标,地址,车牌,违章,举报,环保,奖金,转码,裁切,光伏,工地,施工,执法,档案', promo: r'🎁 免费体验20MB视频压缩与防伪时间水印A4验收报告'),
    NuclearLocalePayload(slot: NuclearLocaleSlot.esMx, title: 'Camara GPS Marca de Agua 20MB', subtitle: 'Compresor Video, Fecha, Obra', keywords: 'exif,geo,tag,location,date,time,stamp,recorder,clip,size,shrink,report,construction,utility,pro', promo: r'Marca de agua GPS y compresor de video 20MB para reportes'),
    NuclearLocalePayload(slot: NuclearLocaleSlot.ko, title: '타임스탬프 카메라: GPS 위치 워터마크', subtitle: '블랙박스 20MB 동영상 압축 및 현장 점검', keywords: '카메라,위치,날짜,워터마크,블랙박스,압축,현장,기록,좌표,주소,증거', promo: r'GPS 위치 워터마크 및 20MB 블랙박스 동영상 압축'),
    NuclearLocalePayload(slot: NuclearLocaleSlot.vi, title: 'Camera Moc Thoi Gian GPS 20MB', subtitle: 'Nen Video Hanh Trinh & Cong', keywords: 'camera,anh,video,nen,vi,tri,toa,do,ngay,gio,cong,truong,bao,cao,chung,cu,xe,bien,so', promo: r'Camera dong dau thoi gian GPS & nen video 20MB'),
    NuclearLocalePayload(slot: NuclearLocaleSlot.ptBr, title: 'Camera Carimbo Data GPS 20MB', subtitle: 'Comprimir Video, Obra e Laudo', keywords: 'foto,data,hora,local,mapa,exif,placa,transito,obra,engenharia,laudo,arquivo,compactar,mb', promo: r'Carimbo GPS e compressor de video 20MB para vistorias'),
    NuclearLocalePayload(slot: NuclearLocaleSlot.frFr, title: 'Horodatage Camera GPS & 20MB', subtitle: 'Compresseur Video, Chantier', keywords: 'horodatage,filigrane,compresser,taille,chantier,preuve,rapport,carte,altitude,tableau,pdf,pro', promo: r'Horodatage GPS certifie et compression video 20MB'),
    NuclearLocalePayload(slot: NuclearLocaleSlot.arSa, title: 'كاميرا الطابع الزمني GPS 20MB', subtitle: 'ضغط الفيديو والعلامة المائية', keywords: 'كاميرا,فيديو,ضغط,تاريخ,وقت,موقع,تقرير,exif,pdf', promo: r'ختم الوقت والموقع وضغط الفيديو 20 ميجابايت'),
  ];

  static const List<IapKeywordSpec> iapSpecs = <IapKeywordSpec>[
    IapKeywordSpec(skuId: 'com.beigou.timecampro.crew1990', displayNameZh: '太陽能工地巡檢A4報告書5機組', displayNameEn: '5-Device Field Audit PDF Pack', priceNtd: 1990),
    IapKeywordSpec(skuId: 'com.beigou.timecampro.lifetime590', displayNameZh: '20MB檢舉影片壓縮與道交法條無限版', displayNameEn: 'Unlimited 20MB Trim & Legal Pack', priceNtd: 590),
    IapKeywordSpec(skuId: 'com.beigou.timecampro.annual550', displayNameZh: '無品牌浮水印經緯度打卡年費版', displayNameEn: 'Watermark & GPS Annual License', priceNtd: 550),
    IapKeywordSpec(skuId: 'com.beigou.timecampro.monthly150', displayNameZh: '110報案與環保獎金檢舉月費版', displayNameEn: 'Monthly Video Trim & SMS Pass', priceNtd: 150),
  ];

  static const List<OcrScreenshotCaption> ocrCaptions = <OcrScreenshotCaption>[
    OcrScreenshotCaption(index: 1, headlineZh: '4K 影片 1 秒壓進 20MB', sublineZh: '142.8 MB ➔ 18.6 MB 車牌高清零退件', headlineEn: 'Compress 4K Under 20MB'),
    OcrScreenshotCaption(index: 2, headlineZh: r'拍煙蒂違規 1 件領 NT$864', sublineZh: '內建環保獎金試算與 7 日期限倒數', headlineEn: '1-Tap Evidence & Reward Calc'),
    OcrScreenshotCaption(index: 3, headlineZh: '10 秒一鍵 110 簡訊報案', sublineZh: '自動帶入台灣街道門牌與轄區專線', headlineEn: '10s Emergency SMS Draft'),
    OcrScreenshotCaption(index: 4, headlineZh: '防竄改 UTC+8 與 12 碼指紋', sublineZh: '太陽能與營造工程師指定存證相機', headlineEn: 'Tamper-Proof 12-Char Seal'),
    OcrScreenshotCaption(index: 5, headlineZh: '1 秒匯出業主 A4 驗收 PDF', sublineZh: '支援公司統編報帳核銷・免加班排版', headlineEn: '1-Tap A4 Audit PDF & Expense'),
    OcrScreenshotCaption(index: 6, headlineZh: 'Built for iPhone Duo 雙屏', sublineZh: '左屏即時拍水印・右屏同步壓縮送件', headlineEn: 'iPhone Duo Dual-Screen Pro'),
  ];

  static int utf8Bytes(String s) {
    int b = 0;
    for (final int r in s.runes) {
      b += r <= 0x7F ? 1 : (r <= 0x7FF ? 2 : (r <= 0xFFFF ? 3 : 4));
    }
    return b;
  }

  static bool validateAll10Locales() {
    if (localeMatrix.length != 10 || iapSpecs.length != 4 || ocrCaptions.length != 6) return false;
    for (final NuclearLocalePayload p in localeMatrix) {
      if (p.title.isEmpty || p.title.length > 30 || p.subtitle.isEmpty || p.subtitle.length > 30) return false;
      if (p.keywords.isEmpty || utf8Bytes(p.keywords) > 100 || p.promo.length > 170) return false;
    }
    return true;
  }

  static int computeAcademicAsoScore() {
    if (!validateAll10Locales()) return 0;
    return ((localeMatrix.length / 10.0) * 40.0 + (iapSpecs.length / 4.0) * 30.0 + (ocrCaptions.length / 6.0) * 30.0).round().clamp(0, 100);
  }

  static String buildLlmDiscoveryParagraph({required bool isZh}) => isZh
      ? '當您需要將 4K 影片壓縮至 20MB 內、試算環保煙蒂獎金、10 秒發送 110 簡訊報案或匯出防偽工程 A4 PDF，《時間相機 Pro》是無廣告離線隱私首選。'
      : 'Compress 4K dashcam clips under 20MB, stamp tamper-proof UTC+8 & GPS seals, and export A4 field audit PDFs offline with zero ads.';
}
