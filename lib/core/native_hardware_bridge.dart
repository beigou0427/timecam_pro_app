import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS 原生硬體與安全儲存通道
class NativeHardwareBridge {
  const NativeHardwareBridge._();

  static bool get _isTestSandbox =>
      kIsWeb || Platform.environment.containsKey('FLUTTER_TEST');

  static bool get isLiveIosRuntime =>
      !_isTestSandbox && !kIsWeb && Platform.isIOS;

  static const MethodChannel _channel =
      MethodChannel('com.beigou.timecampro/native');

  static const String liveCameraPreviewViewType =
      'com.beigou.timecampro/live_camera_preview';

  static void Function(List<String> activeIds)? _onEntitlementsChanged;
  static void Function(double progress)? _onCompressionProgress;
  static bool _handlerRegistered = false;

  static void setNativeEventHandlers({
    void Function(List<String> activeIds)? onStoreKitEntitlementsChanged,
    void Function(double progress)? onVideoCompressionProgress,
  }) {
    if (onStoreKitEntitlementsChanged != null) {
      _onEntitlementsChanged = onStoreKitEntitlementsChanged;
    }
    if (onVideoCompressionProgress != null) {
      _onCompressionProgress = onVideoCompressionProgress;
    }
    if (_isTestSandbox || _handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onStoreKitEntitlementsChanged':
          final List<Object?>? raw = call.arguments as List<Object?>?;
          if (raw != null) {
            final List<String> ids = raw
                .where((Object? e) => e != null)
                .map((Object? e) => e.toString())
                .toList(growable: false);
            _onEntitlementsChanged?.call(ids);
          }
          break;
        case 'onVideoCompressionProgress':
          final num? p = call.arguments as num?;
          if (p != null) {
            _onCompressionProgress?.call(p.toDouble().clamp(0.0, 1.0));
          }
          break;
      }
      return null;
    });
  }

  static Future<Map<String, dynamic>?> fetchLiveGpsAddress({
    bool isZh = true,
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return null;
    try {
      final Map<Object?, Object?>? res =
          await _channel.invokeMethod<Map<Object?, Object?>>(
        'getLiveGpsAddress',
        <String, dynamic>{'isZh': isZh},
      );
      if (res == null) return null;
      return res.map(
        (Object? k, Object? v) => MapEntry<String, dynamic>(k.toString(), v),
      );
    } catch (e) {
      debugPrint('[NativeHardwareBridge] fetchLiveGpsAddress failed: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> captureAndRenderWatermarkPhoto({
    required String timestampText,
    required String headerText,
    required String addressText,
    required String coordsText,
    required String noteText,
    required bool showBrandBadge,
    required double watermarkOpacity,
    double? latitude,
    double? longitude,
    double? altitude,
    required int timestampMs,
    required String caseId,
    required bool autoDetectPlate,
    required bool isZh,
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return null;
    try {
      final Map<Object?, Object?>? res =
          await _channel.invokeMethod<Map<Object?, Object?>>(
        'captureAndRenderWatermarkPhoto',
        <String, dynamic>{
          'timestampText': timestampText,
          'headerText': headerText,
          'addressText': addressText,
          'coordsText': coordsText,
          'noteText': noteText,
          'showBrandBadge': showBrandBadge,
          'watermarkOpacity': watermarkOpacity,
          'latitude': latitude,
          'longitude': longitude,
          'altitude': altitude,
          'timestampMs': timestampMs,
          'caseId': caseId,
          'autoDetectPlate': autoDetectPlate,
          'isZh': isZh,
        },
      );
      if (res == null) return null;
      return res.map(
        (Object? k, Object? v) => MapEntry<String, dynamic>(k.toString(), v),
      );
    } catch (e) {
      debugPrint(
        '[NativeHardwareBridge] captureAndRenderWatermarkPhoto failed: $e',
      );
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
    } catch (e) {
      debugPrint('[NativeHardwareBridge] pickVideoFromPhotos failed: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> recordRealCameraVideo({
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return null;
    try {
      final Map<Object?, Object?>? res = await _channel
          .invokeMethod<Map<Object?, Object?>>('recordRealCameraVideo');
      if (res == null) return null;
      return res.map(
        (Object? k, Object? v) => MapEntry<String, dynamic>(k.toString(), v),
      );
    } catch (e) {
      debugPrint('[NativeHardwareBridge] recordRealCameraVideo failed: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> compressAndSaveRealVideo({
    double startSeconds = 0.0,
    required double trimSeconds,
    double targetLimitMB = 19.0,
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return null;
    try {
      final Map<Object?, Object?>? res =
          await _channel.invokeMethod<Map<Object?, Object?>>(
        'compressAndSaveRealVideo',
        <String, dynamic>{
          'startSeconds': startSeconds,
          'trimSeconds': trimSeconds,
          'targetLimitMB': targetLimitMB,
        },
      );
      if (res == null) return null;
      return res.map(
        (Object? k, Object? v) => MapEntry<String, dynamic>(k.toString(), v),
      );
    } catch (e) {
      debugPrint('[NativeHardwareBridge] compressAndSaveRealVideo failed: $e');
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
    } catch (e) {
      debugPrint('[NativeHardwareBridge] openOfficialPortalSafari failed: $e');
      return false;
    }
  }

  static Future<bool> saveWatermarkPhotoBytes(
    Uint8List pngBytes, {
    double? latitude,
    double? longitude,
    double? altitude,
    int? timestampMs,
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return false;
    try {
      final bool? saved = await _channel.invokeMethod<bool>(
        'saveWatermarkPhotoBytes',
        <String, dynamic>{
          'pngBytes': pngBytes,
          'latitude': latitude,
          'longitude': longitude,
          'altitude': altitude,
          'timestampMs': timestampMs,
        },
      );
      return saved ?? false;
    } catch (e) {
      debugPrint('[NativeHardwareBridge] saveWatermarkPhotoBytes failed: $e');
      return false;
    }
  }

  static Future<Uint8List?> captureRealCameraPhoto({
    bool preferLiveSession = true,
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return null;
    try {
      return await _channel.invokeMethod<Uint8List>(
        'captureRealCameraPhoto',
        <String, dynamic>{'preferLiveSession': preferLiveSession},
      );
    } catch (e) {
      debugPrint('[NativeHardwareBridge] captureRealCameraPhoto failed: $e');
      return null;
    }
  }

  static Future<String?> loadPersistedState({
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return null;
    try {
      return await _channel.invokeMethod<String>('loadPersistedState');
    } catch (e) {
      debugPrint('[NativeHardwareBridge] loadPersistedState failed: $e');
      return null;
    }
  }

  static Future<bool> savePersistedState(
    String json, {
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return false;
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'savePersistedState',
        <String, dynamic>{'json': json},
      );
      return ok ?? false;
    } catch (e) {
      debugPrint('[NativeHardwareBridge] savePersistedState failed: $e');
      return false;
    }
  }

  static Future<int> loadKeychainQuota({bool isTestMode = false}) async {
    if (isTestMode || _isTestSandbox) return 0;
    try {
      final int? count = await _channel.invokeMethod<int>('loadKeychainQuota');
      return (count ?? 0) < 0 ? 0 : (count ?? 0);
    } catch (e) {
      debugPrint('[NativeHardwareBridge] loadKeychainQuota failed: $e');
      return 0;
    }
  }

  static Future<bool> saveKeychainQuota(
    int usedFreeExports, {
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return false;
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'saveKeychainQuota',
        <String, dynamic>{'usedFreeExports': usedFreeExports},
      );
      return ok ?? false;
    } catch (e) {
      debugPrint('[NativeHardwareBridge] saveKeychainQuota failed: $e');
      return false;
    }
  }

  static Future<bool> requestInAppReview({
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return false;
    try {
      final bool? ok = await _channel.invokeMethod<bool>('requestInAppReview');
      return ok ?? false;
    } catch (e) {
      debugPrint('[NativeHardwareBridge] requestInAppReview failed: $e');
      return false;
    }
  }

  static Future<bool> exportAndSharePdfReport({
    required String html,
    String fileName = 'TimeCamPro_Report.pdf',
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return true;
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'exportAndSharePdfReport',
        <String, dynamic>{
          'html': html,
          'fileName': fileName,
        },
      );
      return ok ?? false;
    } catch (e) {
      debugPrint('[NativeHardwareBridge] exportAndSharePdfReport failed: $e');
      return false;
    }
  }

  static Future<bool> openAppSettings({
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return false;
    try {
      final bool? ok = await _channel.invokeMethod<bool>('openAppSettings');
      return ok ?? false;
    } catch (e) {
      debugPrint('[NativeHardwareBridge] openAppSettings failed: $e');
      return false;
    }
  }

  static Future<String?> scanLiveLicensePlate({
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return null;
    try {
      return await _channel.invokeMethod<String>('scanLiveLicensePlate');
    } catch (e) {
      debugPrint('[NativeHardwareBridge] scanLiveLicensePlate failed: $e');
      return null;
    }
  }

  static Future<String?> recognizeLicensePlateFromBytes(
    Uint8List imageBytes, {
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return null;
    try {
      return await _channel.invokeMethod<String>(
        'recognizeLicensePlateFromBytes',
        <String, dynamic>{'imageBytes': imageBytes},
      );
    } catch (e) {
      debugPrint(
        '[NativeHardwareBridge] recognizeLicensePlateFromBytes failed: $e',
      );
      return null;
    }
  }

  static Future<String> startLiveCameraSession({
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return 'unavailable';
    try {
      final String? status =
          await _channel.invokeMethod<String>('startLiveCameraSession');
      return status ?? 'unavailable';
    } catch (e) {
      debugPrint('[NativeHardwareBridge] startLiveCameraSession failed: $e');
      return 'unavailable';
    }
  }

  static Future<bool> stopLiveCameraSession({
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return false;
    try {
      final bool? ok =
          await _channel.invokeMethod<bool>('stopLiveCameraSession');
      return ok ?? false;
    } catch (e) {
      debugPrint('[NativeHardwareBridge] stopLiveCameraSession failed: $e');
      return false;
    }
  }

  static Future<double> setCameraZoom(
    double factor, {
    bool isTestMode = false,
  }) async {
    final double clamped = factor.isFinite ? factor.clamp(1.0, 6.0) : 1.0;
    if (isTestMode || _isTestSandbox) return clamped;
    try {
      final double? applied = await _channel.invokeMethod<double>(
        'setCameraZoom',
        <String, dynamic>{'factor': clamped},
      );
      return applied ?? clamped;
    } catch (e) {
      debugPrint('[NativeHardwareBridge] setCameraZoom failed: $e');
      return clamped;
    }
  }

  static Future<bool> setCameraTorch(
    bool enabled, {
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return enabled;
    try {
      final bool? isOn = await _channel.invokeMethod<bool>(
        'setCameraTorch',
        <String, dynamic>{'enabled': enabled},
      );
      return isOn ?? false;
    } catch (e) {
      debugPrint('[NativeHardwareBridge] setCameraTorch failed: $e');
      return false;
    }
  }

  static Future<bool> focusCameraAt({
    required double normalizedX,
    required double normalizedY,
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return false;
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'focusCameraAt',
        <String, dynamic>{
          'x': normalizedX.clamp(0.0, 1.0),
          'y': normalizedY.clamp(0.0, 1.0),
        },
      );
      return ok ?? false;
    } catch (e) {
      debugPrint('[NativeHardwareBridge] focusCameraAt failed: $e');
      return false;
    }
  }

  static Future<bool> shareImageBytes(
    Uint8List pngBytes, {
    String text = '',
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return false;
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'shareImageBytes',
        <String, dynamic>{'pngBytes': pngBytes, 'text': text},
      );
      return ok ?? false;
    } catch (e) {
      debugPrint('[NativeHardwareBridge] shareImageBytes failed: $e');
      return false;
    }
  }

  static Future<String?> saveCaseThumbnail(
    Uint8List pngBytes, {
    required String caseId,
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return null;
    try {
      return await _channel.invokeMethod<String>(
        'saveCaseThumbnail',
        <String, dynamic>{'pngBytes': pngBytes, 'caseId': caseId},
      );
    } catch (e) {
      debugPrint('[NativeHardwareBridge] saveCaseThumbnail failed: $e');
      return null;
    }
  }

  static Future<bool> deleteCaseThumbnail(
    String path, {
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox || path.trim().isEmpty) return false;
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'deleteCaseThumbnail',
        <String, dynamic>{'path': path},
      );
      return ok ?? false;
    } catch (e) {
      debugPrint('[NativeHardwareBridge] deleteCaseThumbnail failed: $e');
      return false;
    }
  }

  static Future<List<String>?> fetchActiveStoreKitEntitlements({
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return null;
    try {
      final List<Object?>? raw =
          await _channel.invokeMethod<List<Object?>>('checkActiveEntitlements');
      if (raw == null) return null;
      return raw
          .where((Object? e) => e != null)
          .map((Object? e) => e.toString())
          .toList(growable: false);
    } catch (e) {
      debugPrint(
        '[NativeHardwareBridge] fetchActiveStoreKitEntitlements failed: $e',
      );
      return null;
    }
  }

  static Future<List<String>?> syncStoreKitRestore({
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return <String>[];
    try {
      final List<Object?>? raw =
          await _channel.invokeMethod<List<Object?>>('syncStoreKitRestore');
      if (raw == null) return <String>[];
      return raw
          .where((Object? e) => e != null)
          .map((Object? e) => e.toString())
          .toList(growable: false);
    } catch (e) {
      debugPrint('[NativeHardwareBridge] syncStoreKitRestore failed: $e');
      return null;
    }
  }

  static final Map<String, Map<String, dynamic>> cachedStoreKit2Products =
      <String, Map<String, dynamic>>{};

  static Future<Map<String, Map<String, dynamic>>> fetchStoreKit2Products(
    Set<String> productIds, {
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox || productIds.isEmpty) {
      return <String, Map<String, dynamic>>{};
    }
    try {
      final List<Object?>? raw = await _channel.invokeMethod<List<Object?>>(
        'fetchStoreKitProducts',
        <String, dynamic>{'productIds': productIds.toList(growable: false)},
      );
      if (raw == null) return <String, Map<String, dynamic>>{};
      final Map<String, Map<String, dynamic>> out =
          <String, Map<String, dynamic>>{};
      for (final Object? item in raw) {
        if (item is Map) {
          final Map<String, dynamic> m = item.map(
            (Object? k, Object? v) =>
                MapEntry<String, dynamic>(k.toString(), v),
          );
          final String id = m['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            out[id] = m;
          }
        }
      }
      if (out.isNotEmpty) {
        cachedStoreKit2Products.addAll(out);
      }
      return out;
    } catch (e) {
      debugPrint('[NativeHardwareBridge] fetchStoreKit2Products failed: $e');
      return <String, Map<String, dynamic>>{};
    }
  }

  static Future<Map<String, dynamic>?> purchaseStoreKit2Product(
    String productId, {
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return null;
    try {
      final Map<Object?, Object?>? raw =
          await _channel.invokeMethod<Map<Object?, Object?>>(
        'purchaseStoreKitProduct',
        <String, dynamic>{'productId': productId},
      );
      if (raw == null) return null;
      return raw.map(
        (Object? k, Object? v) => MapEntry<String, dynamic>(k.toString(), v),
      );
    } catch (e) {
      debugPrint('[NativeHardwareBridge] purchaseStoreKit2Product failed: $e');
      return <String, dynamic>{
        'status': 'error',
        'message': e.toString(),
      };
    }
  }

  static Future<bool> openExternalUrl(
    String url, {
    bool isTestMode = false,
  }) async {
    if (isTestMode || _isTestSandbox) return false;
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'openExternalUrl',
        <String, dynamic>{'url': url},
      );
      return ok ?? false;
    } catch (e) {
      debugPrint('[NativeHardwareBridge] openExternalUrl failed: $e');
      return false;
    }
  }
}
