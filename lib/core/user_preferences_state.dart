import 'package:flutter/foundation.dart';
import 'taiwan_report_repository.dart';
import 'video_compression_engine.dart';
import 'watermark_location_engine.dart';

/// 跨重啟永久保留的使用者儀器偏好設定模型（不保留前次車牌，避免跨案件誤蓋）
@immutable
class UserPreferencesState {
  const UserPreferencesState({
    this.preferredIsZh,
    this.isVideoMode = false,
    this.lastCameraNote = '',
    this.hasCustomCameraNote = false,
    this.selectedSpotIndex = 0,
    this.watermarkOpacity = defaultWatermarkOpacity,
    this.showGridLines = false,
    this.emergencyIncidentType = EmergencyIncidentType.laneHazard,
    this.compressorPreset = ReportTargetPreset.trafficPolice20MB,
    this.compressorTrimSeconds = defaultTrimSeconds,
    this.autoCopySummary = true,
    this.sampleVideoIndex = 0,
    this.selectedPortalRegion,
    this.cameraZoomFactor = defaultZoomFactor,
  });

  static const int minSpotIndex = 0;
  static const int maxSpotIndex = 4;
  static const double minWatermarkOpacity = 0.35;
  static const double maxWatermarkOpacity = 0.95;
  static const double defaultWatermarkOpacity = 0.72;
  static const double minTrimSeconds = 5.0;
  static const double maxTrimSeconds = 600.0;
  static const double defaultTrimSeconds = 15.0;
  static const int minSampleVideoIndex = 0;
  static const int maxSampleVideoIndex = 2;
  static const double minZoomFactor = 1.0;
  static const double maxZoomFactor = 6.0;
  static const double defaultZoomFactor = 1.0;

  final bool? preferredIsZh;
  final bool isVideoMode;
  final String lastCameraNote;
  final bool hasCustomCameraNote;
  final int selectedSpotIndex;
  final double watermarkOpacity;
  final bool showGridLines;
  final EmergencyIncidentType emergencyIncidentType;
  final ReportTargetPreset compressorPreset;
  final double compressorTrimSeconds;
  final bool autoCopySummary;
  final int sampleVideoIndex;
  final PortalRegion? selectedPortalRegion;
  final double cameraZoomFactor;

  static int _clampInt(
    Object? raw, {
    required int min,
    required int max,
    required int fallback,
  }) {
    if (raw is int) return raw.clamp(min, max);
    if (raw is double && raw.isFinite) return raw.round().clamp(min, max);
    return fallback;
  }

  static double _clampDouble(
    Object? raw, {
    required double min,
    required double max,
    required double fallback,
  }) {
    if (raw is num) {
      final double v = raw.toDouble();
      if (v.isFinite) return v.clamp(min, max).toDouble();
    }
    return fallback;
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    Object? raw,
    T fallback,
  ) {
    if (raw is String) {
      for (final T v in values) {
        if (v.name == raw) return v;
      }
    }
    return fallback;
  }

  static T? _nullableEnumByName<T extends Enum>(
    List<T> values,
    Object? raw,
  ) {
    if (raw is String) {
      for (final T v in values) {
        if (v.name == raw) return v;
      }
    }
    return null;
  }

  /// 注意：刻意不恢復 lastCameraNote / hasCustomCameraNote，確保每次啟動為乾淨現場狀態
  factory UserPreferencesState.fromJson(Object? raw) {
    if (raw is! Map) {
      return const UserPreferencesState();
    }
    final Object? rawZh = raw['preferredIsZh'];
    final bool? preferredIsZh = rawZh is bool ? rawZh : null;

    return UserPreferencesState(
      preferredIsZh: preferredIsZh,
      isVideoMode: raw['isVideoMode'] is bool ? raw['isVideoMode'] as bool : false,
      lastCameraNote: '',
      hasCustomCameraNote: false,
      selectedSpotIndex: _clampInt(
        raw['selectedSpotIndex'],
        min: minSpotIndex,
        max: maxSpotIndex,
        fallback: 0,
      ),
      watermarkOpacity: _clampDouble(
        raw['watermarkOpacity'],
        min: minWatermarkOpacity,
        max: maxWatermarkOpacity,
        fallback: defaultWatermarkOpacity,
      ),
      showGridLines:
          raw['showGridLines'] is bool ? raw['showGridLines'] as bool : false,
      emergencyIncidentType: _enumByName<EmergencyIncidentType>(
        EmergencyIncidentType.values,
        raw['emergencyIncidentType'],
        EmergencyIncidentType.laneHazard,
      ),
      compressorPreset: _enumByName<ReportTargetPreset>(
        ReportTargetPreset.values,
        raw['compressorPreset'],
        ReportTargetPreset.trafficPolice20MB,
      ),
      compressorTrimSeconds: _clampDouble(
        raw['compressorTrimSeconds'],
        min: minTrimSeconds,
        max: maxTrimSeconds,
        fallback: defaultTrimSeconds,
      ),
      autoCopySummary:
          raw['autoCopySummary'] is bool ? raw['autoCopySummary'] as bool : true,
      sampleVideoIndex: _clampInt(
        raw['sampleVideoIndex'],
        min: minSampleVideoIndex,
        max: maxSampleVideoIndex,
        fallback: 0,
      ),
      selectedPortalRegion: _nullableEnumByName<PortalRegion>(
        PortalRegion.values,
        raw['selectedPortalRegion'],
      ),
      cameraZoomFactor: _clampDouble(
        raw['cameraZoomFactor'],
        min: minZoomFactor,
        max: maxZoomFactor,
        fallback: defaultZoomFactor,
      ),
    );
  }

  /// 注意：僅持久化儀器參數與顯示設定，不儲存前次車牌文字
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'preferredIsZh': preferredIsZh,
      'isVideoMode': isVideoMode,
      'selectedSpotIndex': selectedSpotIndex,
      'watermarkOpacity': watermarkOpacity,
      'showGridLines': showGridLines,
      'emergencyIncidentType': emergencyIncidentType.name,
      'compressorPreset': compressorPreset.name,
      'compressorTrimSeconds': compressorTrimSeconds,
      'autoCopySummary': autoCopySummary,
      'sampleVideoIndex': sampleVideoIndex,
      'selectedPortalRegion': selectedPortalRegion?.name,
      'cameraZoomFactor': cameraZoomFactor,
    };
  }

  UserPreferencesState copyWith({
    bool? preferredIsZh,
    bool clearPreferredIsZh = false,
    bool? isVideoMode,
    String? lastCameraNote,
    bool? hasCustomCameraNote,
    int? selectedSpotIndex,
    double? watermarkOpacity,
    bool? showGridLines,
    EmergencyIncidentType? emergencyIncidentType,
    ReportTargetPreset? compressorPreset,
    double? compressorTrimSeconds,
    bool? autoCopySummary,
    int? sampleVideoIndex,
    PortalRegion? selectedPortalRegion,
    bool clearSelectedPortalRegion = false,
    double? cameraZoomFactor,
  }) {
    final double nextOpacity = watermarkOpacity ?? this.watermarkOpacity;
    final double safeOpacity = nextOpacity.isFinite
        ? nextOpacity.clamp(minWatermarkOpacity, maxWatermarkOpacity).toDouble()
        : this.watermarkOpacity;

    final double nextTrim = compressorTrimSeconds ?? this.compressorTrimSeconds;
    final double safeTrim = nextTrim.isFinite
        ? nextTrim.clamp(minTrimSeconds, maxTrimSeconds).toDouble()
        : this.compressorTrimSeconds;

    final double nextZoom = cameraZoomFactor ?? this.cameraZoomFactor;
    final double safeZoom = nextZoom.isFinite
        ? nextZoom.clamp(minZoomFactor, maxZoomFactor).toDouble()
        : this.cameraZoomFactor;

    return UserPreferencesState(
      preferredIsZh:
          clearPreferredIsZh ? null : (preferredIsZh ?? this.preferredIsZh),
      isVideoMode: isVideoMode ?? this.isVideoMode,
      lastCameraNote: lastCameraNote ?? this.lastCameraNote,
      hasCustomCameraNote: hasCustomCameraNote ?? this.hasCustomCameraNote,
      selectedSpotIndex: (selectedSpotIndex ?? this.selectedSpotIndex)
          .clamp(minSpotIndex, maxSpotIndex),
      watermarkOpacity: safeOpacity,
      showGridLines: showGridLines ?? this.showGridLines,
      emergencyIncidentType:
          emergencyIncidentType ?? this.emergencyIncidentType,
      compressorPreset: compressorPreset ?? this.compressorPreset,
      compressorTrimSeconds: safeTrim,
      autoCopySummary: autoCopySummary ?? this.autoCopySummary,
      sampleVideoIndex: (sampleVideoIndex ?? this.sampleVideoIndex)
          .clamp(minSampleVideoIndex, maxSampleVideoIndex),
      selectedPortalRegion: clearSelectedPortalRegion
          ? null
          : (selectedPortalRegion ?? this.selectedPortalRegion),
      cameraZoomFactor: safeZoom,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPreferencesState &&
        other.preferredIsZh == preferredIsZh &&
        other.isVideoMode == isVideoMode &&
        other.lastCameraNote == lastCameraNote &&
        other.hasCustomCameraNote == hasCustomCameraNote &&
        other.selectedSpotIndex == selectedSpotIndex &&
        other.watermarkOpacity == watermarkOpacity &&
        other.showGridLines == showGridLines &&
        other.emergencyIncidentType == emergencyIncidentType &&
        other.compressorPreset == compressorPreset &&
        other.compressorTrimSeconds == compressorTrimSeconds &&
        other.autoCopySummary == autoCopySummary &&
        other.sampleVideoIndex == sampleVideoIndex &&
        other.selectedPortalRegion == selectedPortalRegion &&
        other.cameraZoomFactor == cameraZoomFactor;
  }

  @override
  int get hashCode => Object.hash(
        preferredIsZh,
        isVideoMode,
        lastCameraNote,
        hasCustomCameraNote,
        selectedSpotIndex,
        watermarkOpacity,
        showGridLines,
        emergencyIncidentType,
        compressorPreset,
        compressorTrimSeconds,
        autoCopySummary,
        sampleVideoIndex,
        selectedPortalRegion,
        cameraZoomFactor,
      );
}
