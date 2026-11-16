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
