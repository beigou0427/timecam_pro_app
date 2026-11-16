import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS 原生硬體通道 (CoreLocation / AVFoundation / Photos / SFSafariViewController)
class NativeHardwareBridge {
  const NativeHardwareBridge._();

  static bool get _isTestSandbox =>
      kIsWeb || Platform.environment.containsKey('FLUTTER_TEST');

  static const MethodChannel _channel =
      MethodChannel('com.beigou.timecampro/native');

  /// 呼叫 iPhone 真實 GPS 與 CLGeocoder 台灣中文路名反查
  static Future<Map<String, dynamic>?> fetchLiveGpsAddress({
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return null;
    try {
      final Map<Object?, Object?>? res = await _channel
          .invokeMethod<Map<Object?, Object?>>('getLiveGpsAddress');
      if (res == null) return null;
      return res.map(
        (Object? k, Object? v) => MapEntry<String, dynamic>(k.toString(), v),
      );
    } catch (_) {
      return null;
    }
  }

  /// 開啟 iPhone 系統相簿挑選真實 4K / 1080p 影片
  static Future<Map<String, dynamic>?> pickVideoFromPhotos({
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return null;
    try {
      final Map<Object?, Object?>? res = await _channel
          .invokeMethod<Map<Object?, Object?>>('pickVideoFromLibrary');
      if (res == null) return null;
      return res.map(
        (Object? k, Object? v) => MapEntry<String, dynamic>(k.toString(), v),
      );
    } catch (_) {
      return null;
    }
  }

  /// 呼叫 iOS AVAssetExportSession 真實裁切壓縮影片並存入系統相簿
  static Future<Map<String, dynamic>?> compressAndSaveRealVideo({
    required double trimSeconds,
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return null;
    try {
      final Map<Object?, Object?>? res =
          await _channel.invokeMethod<Map<Object?, Object?>>(
        'compressAndSaveRealVideo',
        <String, dynamic>{'trimSeconds': trimSeconds},
      );
      if (res == null) return null;
      return res.map(
        (Object? k, Object? v) => MapEntry<String, dynamic>(k.toString(), v),
      );
    } catch (_) {
      return null;
    }
  }

  /// 呼叫原生 SFSafariViewController 直接開啟縣市警局/環保局檢舉網站
  static Future<bool> openOfficialPortalSafari(
    String url, {
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return false;
    try {
      final bool? opened = await _channel.invokeMethod<bool>(
        'openOfficialPortalSafari',
        <String, dynamic>{'url': url},
      );
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 呼叫原生 iOS 簡訊 App 自動帶入 110 專線與報案內容
  static Future<bool> launchNativeSms(
    String smsUri, {
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return false;
    try {
      final bool? launched = await _channel.invokeMethod<bool>(
        'launchNativeSms',
        <String, dynamic>{'uri': smsUri},
      );
      return launched ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 將 RepaintBoundary 合成之真實浮水印照片 PNG Bytes 存入 iPhone 系統相簿
  static Future<bool> saveWatermarkPhotoBytes(
    Uint8List pngBytes, {
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return false;
    try {
      final bool? saved = await _channel.invokeMethod<bool>(
        'saveWatermarkPhotoBytes',
        <String, dynamic>{'pngBytes': pngBytes},
      );
      return saved ?? false;
    } catch (_) {
      return false;
    }
  }
}
