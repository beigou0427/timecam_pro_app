import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'watermark_location_engine.dart';

/// 現場檔案 SHA-256 數位校驗憑證模型（無誇大「防偽／官方認證」字樣）
@immutable
class EvidenceIntegrityCertificate {
  const EvidenceIntegrityCertificate({
    required this.sealCode,
    required this.sha256Hex,
    required this.canonicalPayload,
    required this.isProFullSeal,
  });

  /// 簡短識別碼 (格式: SHA-XXXX-XXXX-XXXX)
  final String sealCode;

  /// 完整 64 字元十六進位 SHA-256 摘要
  final String sha256Hex;

  /// 參與雜湊計算的正規化載荷字串
  final String canonicalPayload;

  /// 是否為 Pro 版顯示完整校驗碼
  final bool isProFullSeal;

  /// 根據 Pro 狀態輸出中性的檔案校驗標記（無 emoji、無法律保證誇稱）
  String displayBadge({required bool isZh}) {
    if (isProFullSeal) {
      return 'SHA-256 $sealCode';
    }
    final String masked =
        sealCode.length >= 13 ? '${sealCode.substring(0, 13)}-****' : sealCode;
    return isZh ? 'SHA-256 $masked (Pro)' : 'SHA-256 $masked (Pro)';
  }
}

/// 標準 FIPS 180-4 SHA-256 校驗碼引擎（純 Dart 實作 + 支援原生像素 SHA-256）
class EvidenceIntegrityEngine {
  const EvidenceIntegrityEngine._();

  static const List<int> _k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
    0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
    0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
    0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
    0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static const int _mask32 = 0xFFFFFFFF;

  static int _rotr(int x, int n) =>
      (((x & _mask32) >> n) | ((x << (32 - n)) & _mask32)) & _mask32;

  /// 計算標準 FIPS 180-4 SHA-256（大寫 64 碼 Hex 字串）
  static String computeSha256Hex(List<int> input) {
    final int bitLen = input.length * 8;
    final List<int> padded = List<int>.from(input)..add(0x80);
    while ((padded.length % 64) != 56) {
      padded.add(0x00);
    }
    for (int shift = 56; shift >= 0; shift -= 8) {
      padded.add((bitLen >> shift) & 0xFF);
    }

    int h0 = 0x6a09e667;
    int h1 = 0xbb67ae85;
    int h2 = 0x3c6ef372;
    int h3 = 0xa54ff53a;
    int h4 = 0x510e527f;
    int h5 = 0x9b05688c;
    int h6 = 0x1f83d9ab;
    int h7 = 0x5be0cd19;

    final List<int> w = List<int>.filled(64, 0);
    for (int offset = 0; offset < padded.length; offset += 64) {
      for (int i = 0; i < 16; i++) {
        final int j = offset + (i * 4);
        w[i] = ((padded[j] & 0xFF) << 24) |
            ((padded[j + 1] & 0xFF) << 16) |
            ((padded[j + 2] & 0xFF) << 8) |
            (padded[j + 3] & 0xFF);
      }
      for (int i = 16; i < 64; i++) {
        final int s0 = _rotr(w[i - 15], 7) ^
            _rotr(w[i - 15], 18) ^
            ((w[i - 15] & _mask32) >> 3);
        final int s1 = _rotr(w[i - 2], 17) ^
            _rotr(w[i - 2], 19) ^
            ((w[i - 2] & _mask32) >> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & _mask32;
      }

      int a = h0;
      int b = h1;
      int c = h2;
      int d = h3;
      int e = h4;
      int f = h5;
      int g = h6;
      int h = h7;

      for (int i = 0; i < 64; i++) {
        final int s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final int ch = (e & f) ^ ((~e & _mask32) & g);
        final int temp1 = (h + s1 + ch + _k[i] + w[i]) & _mask32;
        final int s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final int maj = (a & b) ^ (a & c) ^ (b & c);
        final int temp2 = (s0 + maj) & _mask32;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & _mask32;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & _mask32;
      }

      h0 = (h0 + a) & _mask32;
      h1 = (h1 + b) & _mask32;
      h2 = (h2 + c) & _mask32;
      h3 = (h3 + d) & _mask32;
      h4 = (h4 + e) & _mask32;
      h5 = (h5 + f) & _mask32;
      h6 = (h6 + g) & _mask32;
      h7 = (h7 + h) & _mask32;
    }

    final List<int> words = <int>[h0, h1, h2, h3, h4, h5, h6, h7];
    return words
        .map((int val) => val.toRadixString(16).toUpperCase().padLeft(8, '0'))
        .join();
  }

  /// 將浮水印快照正規化為標準載荷字串
  static String buildCanonicalPayload(WatermarkSnapshot snapshot) {
    final String lat = snapshot.hasValidGps
        ? snapshot.latitude.toStringAsFixed(5)
        : '0.00000';
    final String lng = snapshot.hasValidGps
        ? snapshot.longitude.toStringAsFixed(5)
        : '0.00000';
    final String alt = (snapshot.hasValidGps && snapshot.altitudeMeters.isFinite)
        ? snapshot.altitudeMeters.toStringAsFixed(1)
        : '0.0';
    final String note = snapshot.plateOrProjectNote.trim();
    return '${snapshot.utcPlus8FormattedTime}|$lat,$lng,$alt|${snapshot.fullAddress}|$note';
  }

  /// 依 64 碼 SHA-256 摘要產生 12 碼縮寫辨識碼 (SHA-XXXX-XXXX-XXXX)
  static String formatShortSeal(String sha256Hex) {
    final String clean = sha256Hex.trim().toUpperCase().padRight(12, '0');
    return 'SHA-${clean.substring(0, 4)}-${clean.substring(4, 8)}-${clean.substring(8, 12)}';
  }

  /// 對載荷與選配原始位元組計算 SHA-256 校驗碼
  static String computeSealCode(
    String canonicalPayload, {
    List<int>? mediaBytes,
  }) {
    final List<int> data = <int>[
      if (mediaBytes != null && mediaBytes.isNotEmpty) ...mediaBytes,
      ...utf8.encode(canonicalPayload),
    ];
    final String digest = computeSha256Hex(data);
    return formatShortSeal(digest);
  }

  /// 由原生硬體產出之影像+載荷完整 SHA-256 建立不可變憑證
  static EvidenceIntegrityCertificate fromNativeSha256({
    required String sha256Hex,
    required WatermarkSnapshot snapshot,
    required bool isProUnlocked,
  }) {
    final String cleanHex = sha256Hex.trim().toUpperCase();
    return EvidenceIntegrityCertificate(
      sealCode: formatShortSeal(cleanHex),
      sha256Hex: cleanHex,
      canonicalPayload: buildCanonicalPayload(snapshot),
      isProFullSeal: isProUnlocked,
    );
  }

  /// 根據當前浮水印快照與可選媒體位元組簽發 SHA-256 校驗憑證
  static EvidenceIntegrityCertificate generateCertificate({
    required WatermarkSnapshot snapshot,
    required bool isProUnlocked,
    List<int>? mediaBytes,
  }) {
    final String payload = buildCanonicalPayload(snapshot);
    final List<int> bytes = <int>[
      if (mediaBytes != null && mediaBytes.isNotEmpty) ...mediaBytes,
      ...utf8.encode(payload),
    ];
    final String digest = computeSha256Hex(bytes);
    return EvidenceIntegrityCertificate(
      sealCode: formatShortSeal(digest),
      sha256Hex: digest,
      canonicalPayload: payload,
      isProFullSeal: isProUnlocked,
    );
  }

  /// 驗證快照與預期 SHA-XXXX-XXXX-XXXX 校驗碼是否吻合
  static bool verifySealIntegrity({
    required WatermarkSnapshot snapshot,
    required String expectedSealCode,
    List<int>? mediaBytes,
  }) {
    final String cleanExpected = expectedSealCode.trim().toUpperCase();
    if (!cleanExpected.startsWith('SHA-') || cleanExpected.length != 18) {
      return false;
    }
    final String actualPayload = buildCanonicalPayload(snapshot);
    final String actualCode =
        computeSealCode(actualPayload, mediaBytes: mediaBytes);
    return actualCode == cleanExpected;
  }
}
