import 'package:flutter/foundation.dart';

enum OpticalEnhanceMode {
  standardDaylight(
    labelZh: '日間標準 (0.0 EV)',
    labelEn: 'Daylight Standard',
    exposureBiasEv: 0.0,
    isProRequired: false,
  ),
  nightGlareGuard(
    labelZh: '夜間防眩光車牌鎖定 (-1.0 EV)',
    labelEn: 'Night Anti-Glare Plate Lock',
    exposureBiasEv: -1.0,
    isProRequired: true,
  ),
  rainFogContrast(
    labelZh: '豪雨破霧高反差 (+對比)',
    labelEn: 'Rain & Fog High Contrast',
    exposureBiasEv: -0.3,
    isProRequired: true,
  );

  const OpticalEnhanceMode({
    required this.labelZh,
    required this.labelEn,
    required this.exposureBiasEv,
    required this.isProRequired,
  });
  final String labelZh;
  final String labelEn;
  final double exposureBiasEv;
  final bool isProRequired;
  String localizedLabel({required bool isZh}) => isZh ? labelZh : labelEn;
}

class NightPlateEnhancerEngine {
  const NightPlateEnhancerEngine._();

  static bool isValidColorMatrix(OpticalEnhanceMode mode) =>
      colorMatrixForMode(mode).length == 20;

  static String buildOpticalAdvisory(
    OpticalEnhanceMode mode, {
    required bool isZh,
  }) {
    switch (mode) {
      case OpticalEnhanceMode.standardDaylight:
        return isZh ? '日間標準自然色彩 (0.0 EV)' : 'Standard Daylight (0.0 EV)';
      case OpticalEnhanceMode.nightGlareGuard:
        return isZh
            ? '已啟動 -1.0 EV 夜間車牌防過曝矩陣，抑制大燈反光死白'
            : 'Night Anti-Glare (-1.0 EV) active to suppress high-beam washout';
      case OpticalEnhanceMode.rainFogContrast:
        return isZh
            ? '已啟動豪雨破霧高反差矩陣，強化車牌邊緣銳利度'
            : 'Rain/Fog High Contrast active for sharper plate edges';
    }
  }
}
