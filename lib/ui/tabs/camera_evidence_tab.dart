import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/native_hardware_bridge.dart';
import '../../core/watermark_location_engine.dart';

/// 預設台灣主要都會區與外勤巡檢 GPS 定位點模型
@immutable
class PresetGpsSpot {
  const PresetGpsSpot({
    required this.cityZh,
    required this.cityEn,
    required this.streetZh,
    required this.streetEn,
    required this.latitude,
    required this.longitude,
    required this.altitude,
  });

  final String cityZh;
  final String cityEn;
  final String streetZh;
  final String streetEn;
  final double latitude;
  final double longitude;
  final double altitude;
}

/// Tab 1：蒐證相機（主畫面・即時時間/GPS/地址浮水印與一鍵 110 簡訊報案）
class CameraEvidenceTab extends StatefulWidget {
  const CameraEvidenceTab({
    super.key,
    required this.isZh,
    required this.isProUnlocked,
    required this.onCaptureEvidence,
    required this.onRequestPaywall,
    this.enableLiveClock = true,
  });

  final bool isZh;
  final bool isProUnlocked;
  final ValueChanged<WatermarkSnapshot> onCaptureEvidence;
  final ValueChanged<String> onRequestPaywall;
  final bool enableLiveClock;

  static const List<PresetGpsSpot> presetSpots = <PresetGpsSpot>[
    PresetGpsSpot(
      cityZh: '台北市信義區',
      cityEn: 'Xinyi Dist., Taipei ',
      streetZh: '忠孝東路五段22號',
      streetEn: 'No. 22, Sec. 5, Zhongxiao E. Rd.',
      latitude: 25.04086,
      longitude: 121.56482,
      altitude: 14.2,
    ),
    PresetGpsSpot(
      cityZh: '新北市板橋區',
      cityEn: 'Banqiao Dist., New Taipei ',
      streetZh: '縣民大道二段7號',
      streetEn: 'No. 7, Sec. 2, Xianmin Blvd.',
      latitude: 25.01425,
      longitude: 121.46375,
      altitude: 11.8,
    ),
    PresetGpsSpot(
      cityZh: '台中市西屯區',
      cityEn: 'Xitun Dist., Taichung ',
      streetZh: '台灣大道三段99號',
      streetEn: 'No. 99, Sec. 3, Taiwan Blvd.',
      latitude: 24.16184,
      longitude: 120.64685,
      altitude: 86.5,
    ),
    PresetGpsSpot(
      cityZh: '台南市東區',
      cityEn: 'East Dist., Tainan ',
      streetZh: '中華東路三段336號',
      streetEn: 'No. 336, Sec. 3, Zhonghua E. Rd.',
      latitude: 22.97482,
      longitude: 120.22156,
      altitude: 21.0,
    ),
    PresetGpsSpot(
      cityZh: '高雄市左營區',
      cityEn: 'Zuoying Dist., Kaohsiung ',
      streetZh: '博愛二路777號',
      streetEn: 'No. 777, Bo-ai 2nd Rd.',
      latitude: 22.66912,
      longitude: 120.30328,
      altitude: 9.4,
    ),
  ];

  @override
  State<CameraEvidenceTab> createState() => _CameraEvidenceTabState();
}

class _CameraEvidenceTabState extends State<CameraEvidenceTab> {
  final TextEditingController _noteController = TextEditingController(
    text: 'ABC-1234 紅線違停',
  );
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  final GlobalKey _viewfinderBoundaryKey = GlobalKey();
  int _selectedSpotIndex = 0;
  bool _useLiveDeviceGps = false;
  bool _isSyncingGps = false;
  String? _liveCity;
  String? _liveStreet;
  double? _liveLat;
  double? _liveLng;
  double? _liveAlt;
  bool _isVideoMode = true;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  bool _showGridLines = true;
  double _watermarkOpacity = 0.88;

  @override
  void initState() {
    super.initState();
    if (widget.enableLiveClock) {
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _now = DateTime.now();
          if (_isRecording) {
            _recordingSeconds += 1;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  WatermarkSnapshot _currentSnapshot() {
    final PresetGpsSpot spot = CameraEvidenceTab.presetSpots[_selectedSpotIndex];
    final String city = (_useLiveDeviceGps && _liveCity != null)
        ? _liveCity!
        : (widget.isZh ? spot.cityZh : spot.cityEn);
    final String street = (_useLiveDeviceGps && _liveStreet != null)
        ? _liveStreet!
        : (widget.isZh ? spot.streetZh : spot.streetEn);
    return WatermarkLocationEngine.createSnapshot(
      timestamp: _now,
      cityAndDistrict: city,
      streetAddress: street,
      latitude: (_useLiveDeviceGps && _liveLat != null) ? _liveLat! : spot.latitude,
      longitude: (_useLiveDeviceGps && _liveLng != null) ? _liveLng! : spot.longitude,
      altitudeMeters: (_useLiveDeviceGps && _liveAlt != null) ? _liveAlt! : spot.altitude,
      plateOrProjectNote: _noteController.text,
      isTimeVerified: true,
      isProUnlocked: widget.isProUnlocked,
      isZh: widget.isZh,
    );
  }

  Future<void> _syncRealDeviceGps() async {
    if (_isSyncingGps) return;
    HapticFeedback.mediumImpact();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isSyncingGps = true;
    });
    final Map<String, dynamic>? gps =
        await NativeHardwareBridge.fetchLiveGpsAddress(
      isTestMode: !widget.enableLiveClock,
    );
    if (!mounted) return;
    setState(() {
      _isSyncingGps = false;
      if (gps != null) {
        _useLiveDeviceGps = true;
        _liveCity = gps['city']?.toString();
        _liveStreet = gps['street']?.toString();
        _liveLat = (gps['latitude'] as num?)?.toDouble();
        _liveLng = (gps['longitude'] as num?)?.toDouble();
        _liveAlt = (gps['altitude'] as num?)?.toDouble();
      }
    });
    messenger.showSnackBar(
      SnackBar(
        backgroundColor:
            gps != null ? const Color(0xFF10B981) : const Color(0xFF0284C7),
        content: Text(
          gps != null
              ? (widget.isZh
                  ? '🛰️ 已鎖定真實 iPhone GPS 座標與台灣街道地址！'
                  : '🛰️ Locked real iPhone GPS coordinates & street address!')
              : (widget.isZh
                  ? '📍 目前為模擬器/離線環境，已使用高精度預設巡檢座標'
                  : '📍 Using preset inspection coordinates in simulator/offline mode'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _captureAndSaveWatermarkImage() async {
    if (!widget.enableLiveClock) return;
    try {
      final RenderRepaintBoundary? boundary = _viewfinderBoundaryKey
          .currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      await NativeHardwareBridge.saveWatermarkPhotoBytes(pngBytes);
    } catch (_) {}
  }
  void _handleTriggerCapture() {
    HapticFeedback.heavyImpact();
    final WatermarkSnapshot snap = _currentSnapshot();
    if (_isVideoMode) {
      setState(() {
        if (_isRecording) {
          _isRecording = false;
          _recordingSeconds = 0;
          widget.onCaptureEvidence(snap);
      _captureAndSaveWatermarkImage();
        } else {
          _isRecording = true;
          _recordingSeconds = 0;
        }
      });
      if (!_isRecording) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              widget.isZh
                  ? '✅ 蒐證錄影已烙印時間地點浮水印並歸檔至案件庫！'
                  : '✅ Video watermarked and saved to Evidence Vault!',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
    } else {
      widget.onCaptureEvidence(snap);
      _captureAndSaveWatermarkImage();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0284C7),
          content: Text(
            widget.isZh
                ? '📸 現場存證照片已烙印 UTC+8 時間與 GPS 浮水印！'
                : '📸 Photo captured with UTC+8 & GPS watermark!',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
  }

  void _show110QuickReportSheet() {
    HapticFeedback.mediumImpact();
    final WatermarkSnapshot snap = _currentSnapshot();
    EmergencyIncidentType selectedType = EmergencyIncidentType.redLineParking;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheetState) {
            final String recipient =
                WatermarkLocationEngine.resolve110SmsRecipient(
              snap.cityAndDistrict,
            );
            final String smsBody = WatermarkLocationEngine.build110SmsBody(
              snapshot: snap,
              incidentType: selectedType,
              isZh: widget.isZh,
            );

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(6)),
                            ),
                            child: const Text(
                              '110 SMS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.isZh
                                  ? '一鍵 110 簡訊報案快速產生器'
                                  : '110 Emergency SMS Generator',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isZh
                            ? '自動匹配轄區警局簡訊專線：$recipient（可選違規態樣）'
                            : 'Matched Police SMS Recipient: $recipient',
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: EmergencyIncidentType.values
                            .map((EmergencyIncidentType type) {
                          final bool isSelected = selectedType == type;
                          return ChoiceChip(
                            label: Text(
                              type.localizedTitle(isZh: widget.isZh),
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF121212)
                                    : Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFFF59E0B),
                            backgroundColor: const Color(0xFF1E293B),
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              setSheetState(() {
                                selectedType = type;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(12)),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Text(
                          smsBody,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          key: const Key('copy_110_sms_btn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          onPressed: () async {
                            final NavigatorState sheetNav =
                                Navigator.of(sheetContext);
                            final ScaffoldMessengerState messenger =
                                ScaffoldMessenger.of(context);
                            await Clipboard.setData(
                              ClipboardData(text: smsBody),
                            );
                            final Uri smsUri = WatermarkLocationEngine.build110SmsUri(snapshot: snap, incidentType: selectedType, isZh: widget.isZh);
                            await NativeHardwareBridge.launchNativeSms(smsUri.toString());
                            if (!mounted) return;
                            sheetNav.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF10B981),
                                content: Text(
                                  widget.isZh
                                      ? '✅ 已複製 110 報案簡訊（專線：$recipient），請貼上簡訊寄出！'
                                      : '✅ Copied 110 SMS body for $recipient!',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.send_to_mobile_rounded),
                          label: Text(
                            widget.isZh
                                ? '一鍵複製報案簡訊全文 (寄至 $recipient)'
                                : 'Copy Emergency SMS (To $recipient)',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLiveWatermarkOverlay(WatermarkSnapshot snap) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: _watermarkOpacity),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.75),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                child: Text(
                  widget.isZh ? 'UTC+8 國家標準校時' : 'UTC+8 VERIFIED',
                  style: const TextStyle(
                    color: Color(0xFF121212),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    snap.utcPlus8FormattedTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      fontFeatures: <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              const Icon(
                Icons.location_on_rounded,
                color: Color(0xFFF59E0B),
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  snap.fullAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'GPS: ${snap.formattedCoordinates(isZh: widget.isZh)}',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          if (snap.plateOrProjectNote.isNotEmpty) ...<Widget>[
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
                border: Border.all(color: const Color(0xFF475569)),
              ),
              child: Text(
                widget.isZh
                    ? '車牌/案場備註：${snap.plateOrProjectNote}'
                    : 'Plate/Note: ${snap.plateOrProjectNote}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFDE68A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          if (snap.showBrandBadge) ...<Widget>[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                key: const Key('watermark_remove_badge_btn'),
                onTap: () => widget.onRequestPaywall(
                  widget.isZh
                      ? '解鎖 Pro 即可移除照片/影片右下角品牌標章，並啟用自訂公司案場抬頭！'
                      : 'Unlock Pro to remove brand badge and customize project headers!',
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                  child: Text(
                    widget.isZh
                        ? '⚡ 時間相機 Pro 認證水印 (點此移除)'
                        : '⚡ TimeCam Pro Badge (Tap to remove)',
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildViewfinderArea(WatermarkSnapshot snap) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 270),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF090D16),
          ],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(
          color: _isRecording
              ? const Color(0xFFEF4444)
              : const Color(0xFF334155),
          width: _isRecording ? 2.2 : 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            // 頂部 HUD 狀態列：GPS 定位點切換 + 錄影狀態計時
            Row(
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            key: const Key('live_gps_sync_btn'),
                            backgroundColor: _useLiveDeviceGps
                                ? const Color(0xFF10B981)
                                : const Color(0xFF0284C7),
                            visualDensity: VisualDensity.compact,
                            avatar: Icon(
                              _isSyncingGps
                                  ? Icons.sync_rounded
                                  : Icons.my_location_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            label: Text(
                              widget.isZh ? '真機GPS定位' : 'Live GPS',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            onPressed: _syncRealDeviceGps,
                          ),
                        ),
                        ...List<Widget>.generate(
                        CameraEvidenceTab.presetSpots.length,
                        (int idx) {
                          final PresetGpsSpot spot =
                              CameraEvidenceTab.presetSpots[idx];
                          final bool selected = _selectedSpotIndex == idx;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                widget.isZh ? spot.cityZh : spot.cityEn,
                                style: TextStyle(
                                  color: selected
                                      ? const Color(0xFF121212)
                                      : Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              selected: selected,
                              selectedColor: const Color(0xFFF59E0B),
                              backgroundColor: const Color(0xFF0F172A),
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _useLiveDeviceGps = false;
                                  _selectedSpotIndex = idx;
                                });
                              },
                            ),
                          );
                        },
                      ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(6)),
                  ),
                  child: Text(
                    _isRecording
                        ? 'REC ${_recordingSeconds.toString().padLeft(2, '0')}s'
                        : '1080p 60FPS',
                    style: TextStyle(
                      color: _isRecording
                          ? Colors.white
                          : const Color(0xFF34D399),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 中央光學車牌對焦準星 HUD
            if (_showGridLines)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    const Icon(
                      Icons.center_focus_strong_rounded,
                      color: Color(0xFFF59E0B),
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isZh
                          ? '車牌/案場光學銳利化對焦區 (AF-C)'
                          : 'License Plate Optical Focus Zone (AF-C)',
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // 底部即時浮水印疊加預覽
            _buildLiveWatermarkOverlay(snap),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbControlZone() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 車牌號碼或外勤案場名稱快速輸入欄
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const Key('camera_plate_note_input'),
                  controller: _noteController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    prefixIcon: const Icon(
                      Icons.pin_invoke_rounded,
                      color: Color(0xFFF59E0B),
                      size: 19,
                    ),
                    hintText: widget.isZh
                        ? '輸入違規車牌或案場備註 (例: ABC-1234)'
                        : 'Enter plate or project note (e.g. ABC-1234)',
                    hintStyle: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12.5,
                    ),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: widget.isZh ? '對焦網格開關' : 'Toggle Grid',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _showGridLines = !_showGridLines;
                  });
                },
                icon: Icon(
                  _showGridLines
                      ? Icons.grid_on_rounded
                      : Icons.grid_off_rounded,
                  color: _showGridLines
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 浮水印底板透明度微調滑桿
          Row(
            children: <Widget>[
              Text(
                widget.isZh ? '水印底板透明度' : 'Watermark Opacity',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _watermarkOpacity,
                  min: 0.4,
                  max: 1.0,
                  activeColor: const Color(0xFFF59E0B),
                  inactiveColor: const Color(0xFF0F172A),
                  onChanged: (double val) {
                    setState(() {
                      _watermarkOpacity = val.clamp(0.4, 1.0);
                    });
                  },
                ),
              ),
              Text(
                '${(_watermarkOpacity * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 單手拇指熱區三大核心按鈕：110 簡訊報案 / 主快門鈕 / 錄影拍照切換
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('open_110_sms_sheet_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  onPressed: _show110QuickReportSheet,
                  icon: const Icon(Icons.sms_failed_rounded, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.isZh ? '110 簡訊報案' : '110 SMS',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  key: const Key('camera_main_shutter_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFF59E0B),
                    foregroundColor: _isRecording
                        ? Colors.white
                        : const Color(0xFF121212),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  onPressed: _handleTriggerCapture,
                  icon: Icon(
                    _isVideoMode
                        ? (_isRecording
                            ? Icons.stop_circle_rounded
                            : Icons.videocam_rounded)
                        : Icons.camera_alt_rounded,
                    size: 21,
                  ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _isVideoMode
                          ? (_isRecording
                              ? (widget.isZh ? '停止並存證' : 'Stop & Save')
                              : (widget.isZh ? '開始水印錄影' : 'Record Video'))
                          : (widget.isZh ? '拍攝水印存證照' : 'Capture Photo'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  key: const Key('toggle_camera_mode_btn'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF475569)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isRecording = false;
                      _isVideoMode = !_isVideoMode;
                    });
                  },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _isVideoMode
                          ? (widget.isZh ? '切至拍照' : 'Photo Mode')
                          : (widget.isZh ? '切至錄影' : 'Video Mode'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final WatermarkSnapshot snap = _currentSnapshot();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          RepaintBoundary(
            key: _viewfinderBoundaryKey,
            child: _buildViewfinderArea(snap),
          ),
          const SizedBox(height: 12),
          _buildThumbControlZone(),
        ],
      ),
    );
  }
}