enum OpticalEnhanceMode { standardDaylight, nightGlareGuard, rainFogContrast }
class NightPlateEnhancerEngine {
  const NightPlateEnhancerEngine._();
  static const List<double> _m = <double>[1.22, 0, 0, 0, -28, 0, 1.25, 0, 0, -28, 0, 0, 1.18, 0, -22, 0, 0, 0, 1, 0];
  static List<double> colorMatrixForMode(OpticalEnhanceMode mode) => _m;
  static bool isValidColorMatrix(OpticalEnhanceMode mode) => colorMatrixForMode(mode).length == 20;
}
