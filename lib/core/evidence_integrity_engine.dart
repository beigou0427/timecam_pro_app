import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'watermark_location_engine.dart';

/// PM #5 Gibson Biddle (DHM 模型) 改進：現場存證防竄改數位指紋證書模型
@immutable
class EvidenceIntegrityCertificate {
  const EvidenceIntegrityCertificate({
    required this.sealCode,
    required this.canonicalPayload,
    required this.isProFullSeal,
  });

  /// 12 碼十六進位防偽指紋碼 (格式: TC-XXXX-XXXX-XXXX)
  final String sealCode;

  /// 參與雜湊計算之正規化原始載荷字串
  final String canonicalPayload;

  /// 是否為 Pro 專業版完整解鎖之防偽認證章
  final bool isProFullSeal;

  /// 根據語系與 Pro 狀態輸出烙印於浮水印上之防偽認證章文字
  String displayBadge({required bool isZh}) {
    if (isProFullSeal) {
      return isZh
          ? '🛡️ 防偽數位指紋：$sealCode (已鎖定)'
          : '🛡️ Integrity Seal: $sealCode (Verified)';
    }
    final String masked =
        sealCode.length >= 12 ? '${sealCode.substring(0, 12)}-****' : sealCode;
    return isZh
        ? '🛡️ 防偽指紋：$masked (升級Pro顯示全碼)'
        : '🛡️ Hash: $masked (Pro Full Seal)';
  }
}

/// PM #5 Gibson Biddle 改進：決定論雙通道位元組雜湊與防竄改驗證引擎
class EvidenceIntegrityEngine {
  const EvidenceIntegrityEngine._();

  /// FNV-1a 32-bit 初始基底與質數常數
  static const int _fnvOffsetBasis = 0x811C9DC5;
  static const int _fnvPrime = 0x01000193;

  /// DJB2 第二通道初始種子與應用專屬鹽值
  static const int _djb2Seed = 5381;
  static const String _appDomainSalt = 'TIMECAM_PRO_TW_UTC8_SALT_v1';

  /// 將浮水印快照正規化為防竄改標準載荷字串
  static String buildCanonicalPayload(WatermarkSnapshot snapshot) {
    final String lat = snapshot.hasValidGps
        ? snapshot.latitude.toStringAsFixed(5)
        : '0.00000';
    final String lng = snapshot.hasValidGps
        ? snapshot.longitude.toStringAsFixed(5)
        : '0.00000';
    final String alt = snapshot.altitudeMeters.isFinite
        ? snapshot.altitudeMeters.toStringAsFixed(1)
        : '0.0';
    final String note = snapshot.plateOrProjectNote.trim();
    return '${snapshot.utcPlus8FormattedTime}|$lat,$lng,$alt|${snapshot.fullAddress}|$note';
  }

  /// 執行雙通道 (FNV-1a + DJB2) UTF-8 位元組雪崩雜湊，產出 12 碼防偽指紋 (TC-XXXX-XXXX-XXXX)
  static String computeSealCode(String canonicalPayload) {
    final List<int> bytes =
        utf8.encode('$canonicalPayload|$_appDomainSalt');

    int hashA = _fnvOffsetBasis;
    int hashB = _djb2Seed;

    for (int i = 0; i < bytes.length; i++) {
      final int b = bytes[i] & 0xFF;
      hashA ^= b;
      hashA = (hashA * _fnvPrime) & 0xFFFFFFFF;

      hashB = (((hashB << 5) + hashB) ^ b) & 0xFFFFFFFF;
    }

    final int block1 = (hashA >> 16) & 0xFFFF;
    final int block2 = (hashA ^ (hashB >> 16)) & 0xFFFF;
    final int block3 = (hashB ^ (hashA & 0xFFFF)) & 0xFFFF;

    final String hex1 = block1.toRadixString(16).toUpperCase().padLeft(4, '0');
    final String hex2 = block2.toRadixString(16).toUpperCase().padLeft(4, '0');
    final String hex3 = block3.toRadixString(16).toUpperCase().padLeft(4, '0');

    return 'TC-$hex1-$hex2-$hex3';
  }

  /// 根據當前浮水印快照與 Pro 解鎖狀態，簽發數位防偽證書
  static EvidenceIntegrityCertificate generateCertificate({
    required WatermarkSnapshot snapshot,
    required bool isProUnlocked,
  }) {
    final String payload = buildCanonicalPayload(snapshot);
    final String code = computeSealCode(payload);
    return EvidenceIntegrityCertificate(
      sealCode: code,
      canonicalPayload: payload,
      isProFullSeal: isProUnlocked,
    );
  }

  /// 驗證浮水印快照是否與數位防偽指紋 100% 吻合 (若時間、座標或車牌遭竄改1個字元即回傳 false)
  static bool verifySealIntegrity({
    required WatermarkSnapshot snapshot,
    required String expectedSealCode,
  }) {
    final String cleanExpected = expectedSealCode.trim().toUpperCase();
    if (!cleanExpected.startsWith('TC-') || cleanExpected.length != 17) {
      return false;
    }
    final String actualPayload = buildCanonicalPayload(snapshot);
    final String actualCode = computeSealCode(actualPayload);
    return actualCode == cleanExpected;
  }
}
