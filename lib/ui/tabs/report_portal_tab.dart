import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/evidence_integrity_engine.dart';
import '../../core/native_hardware_bridge.dart';
import '../../core/naval_pdf_leverage_engine.dart';
import '../../core/persona_positioning_engine.dart';
import '../../core/taiwan_report_repository.dart';
import '../../core/user_preferences_state.dart';
import '../../core/watermark_location_engine.dart';
import '../widgets/export_handoff_banner.dart';
import '../widgets/quick_start_guide_sheet.dart';

/// Tab 3：本機存證案件夾（完整保存真實座標與 SHA-256、刪除前確認、JSON 備份、嚴格模式隔離）
class ReportPortalTab extends StatefulWidget {
  const ReportPortalTab({
    super.key,
    required this.isZh,
    required this.isProUnlocked,
    required this.cases,
    required this.onUpdateCaseStatus,
    required this.onRequestPaywall,
    this.onDeleteCase,
    this.onEditCaseNote,
    this.activePersona = UserPersonaMode.fieldEngineering,
    this.companyHeader = '',
    this.isTestMode = false,
    this.activeHandoff,
    this.onDismissHandoff,
    this.showFirstTimeTip = false,
    this.onDismissFirstTimeTip,
    this.preferences = const UserPreferencesState(),
    this.onPreferencesChanged,
  });

  final Object? activeHandoff;
  final VoidCallback? onDismissHandoff;
  final bool showFirstTimeTip;
  final VoidCallback? onDismissFirstTimeTip;
  final bool isZh;
  final bool isProUnlocked;
  final UserPersonaMode activePersona;
  final String companyHeader;
  final bool isTestMode;
  final List<EvidenceCaseRecord> cases;
  final void Function(String caseId, CaseSubmissionStatus nextStatus)
      onUpdateCaseStatus;
  final ValueChanged<String>? onDeleteCase;
  final void Function(String caseId, String nextNote)? onEditCaseNote;
  final ValueChanged<String> onRequestPaywall;
  final UserPreferencesState preferences;
  final ValueChanged<UserPreferencesState>? onPreferencesChanged;

  @override
  State<ReportPortalTab> createState() => _ReportPortalTabState();
}

class _ReportPortalTabState extends State<ReportPortalTab> {
  int _sectionIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  PortalRegion? _selectedRegion;

  bool get _showTrafficPortals =>
      widget.isZh && widget.activePersona == UserPersonaMode.trafficEvidence;

  @override
  void initState() {
    super.initState();
    _selectedRegion = widget.preferences.selectedPortalRegion;
  }

  @override
  void didUpdateWidget(covariant ReportPortalTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_showTrafficPortals && _sectionIndex != 0) {
      _sectionIndex = 0;
    }
    if (widget.preferences.selectedPortalRegion !=
        oldWidget.preferences.selectedPortalRegion) {
      _selectedRegion = widget.preferences.selectedPortalRegion;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ReportDossierTheme _themeForPersona(UserPersonaMode mode) {
    switch (mode) {
      case UserPersonaMode.fieldEngineering:
        return ReportDossierTheme.solarEngineering;
      case UserPersonaMode.logisticsProof:
        return ReportDossierTheme.logisticsDelivery;
      case UserPersonaMode.trafficEvidence:
        return ReportDossierTheme.trafficPetition;
    }
  }

  Future<void> _handleExportPdfReport() async {
    HapticFeedback.mediumImpact();
    widget.onDismissFirstTimeTip?.call();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final List<DossierEntry> entries = <DossierEntry>[];
    for (int i = 0; i < widget.cases.length; i++) {
      final EvidenceCaseRecord c = widget.cases[i];
      // 使用案件保存之拍攝當下真實座標；無實機定位時保留 NaN（「尚未取得 GPS 定位」），絕不偽造台北座標！
      final WatermarkSnapshot snap = WatermarkLocationEngine.createSnapshot(
        timestamp: c.capturedAtUtc.toLocal(),
        cityAndDistrict: '',
        streetAddress: c.address,
        latitude: c.hasValidCoordinates ? c.latitude! : double.nan,
        longitude: c.hasValidCoordinates ? c.longitude! : double.nan,
        altitudeMeters: c.altitudeMeters ?? double.nan,
        plateOrProjectNote: c.plateOrNote,
        isProUnlocked: widget.isProUnlocked,
        isZh: widget.isZh,
      );

      // 優先使用拍攝當時產出之不可變雜湊；不因事後修改備註就重算假指紋
      final String sealDisplay;
      if (c.evidenceHash != null && c.evidenceHash!.trim().isNotEmpty) {
        final String raw = c.evidenceHash!.trim().toUpperCase();
        if (raw.startsWith('SHA-')) {
          sealDisplay = widget.isProUnlocked
              ? 'SHA-256 $raw'
              : 'SHA-256 ${raw.length >= 13 ? raw.substring(0, 13) : raw}-**** (Pro)';
        } else {
          final EvidenceIntegrityCertificate cert =
              EvidenceIntegrityEngine.fromNativeSha256(
            sha256Hex: raw,
            snapshot: snap,
            isProUnlocked: widget.isProUnlocked,
          );
          sealDisplay = cert.displayBadge(isZh: widget.isZh);
        }
      } else {
        final EvidenceIntegrityCertificate cert =
            EvidenceIntegrityEngine.generateCertificate(
          snapshot: snap,
          isProUnlocked: widget.isProUnlocked,
        );
        sealDisplay = cert.displayBadge(isZh: widget.isZh);
      }

      String? thumbB64;
      if (!widget.isTestMode &&
          c.thumbnailPath != null &&
          c.thumbnailPath!.isNotEmpty) {
        try {
          final File f = File(c.thumbnailPath!);
          if (await f.exists()) {
            thumbB64 = base64Encode(await f.readAsBytes());
          }
        } catch (_) {}
      }
      entries.add(
        DossierEntry(
          sequenceNo: i + 1,
          utcPlus8Time: c.formattedTimeUtc8,
          address: c.address,
          gpsText: snap.formattedCoordinates(isZh: widget.isZh),
          integritySealCode: sealDisplay,
          siteOrPlateNote: c.plateOrNote,
          thumbnailBase64: thumbB64,
        ),
      );
    }

    final String html = NavalPdfLeverageEngine.renderPrintableA4Html(
      theme: _themeForPersona(widget.activePersona),
      companyHeader: widget.isProUnlocked ? widget.companyHeader : '',
      entries: entries,
      isProUnlocked: widget.isProUnlocked,
      isZh: widget.isZh,
    );

    final bool exported = await NativeHardwareBridge.exportAndSharePdfReport(
      html: html,
      fileName: 'TimeCamPro_Report.pdf',
      isTestMode: widget.isTestMode,
    );
    if (!mounted) return;

    final bool limited = !widget.isProUnlocked && widget.cases.length > 1;
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1F1F23),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        content: Text(
          exported
              ? (limited
                  ? (widget.isZh
                      ? '已產出試閱版 PDF（僅含第 1 筆）'
                      : 'Exported 1-entry preview PDF')
                  : (widget.isZh
                      ? '已產出完整 A4 驗收報告 PDF'
                      : 'Exported full A4 inspection PDF'))
              : (widget.isZh ? '無法產生 PDF 報告' : 'Failed to generate PDF'),
          style: TextStyle(
            color: exported
                ? const Color(0xFF34C759)
                : const Color(0xFFFF453A),
            fontWeight: FontWeight.w600,
          ),
        ),
        action: exported && limited
            ? SnackBarAction(
                label: widget.isZh ? '升級全筆' : 'Unlock All',
                textColor: const Color(0xFFF5B73B),
                onPressed: () {
                  widget.onRequestPaywall(
                    NavalPdfLeverageEngine.buildDossierPaywallPitch(
                      totalCount: widget.cases.length,
                      isZh: widget.isZh,
                    ),
                  );
                },
              )
            : null,
      ),
    );
  }

  Future<void> _backupAllCasesJson() async {
    HapticFeedback.selectionClick();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String backupJson = const JsonEncoder.withIndent('  ').convert(
      <String, dynamic>{
        'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'count': widget.cases.length,
        'cases': widget.cases
            .map(
              (EvidenceCaseRecord c) => <String, dynamic>{
                'id': c.id,
                'capturedAtUtc': c.capturedAtUtc.toIso8601String(),
                'timestamp': c.formattedTimeUtc8,
                'address': c.address,
                'latitude': c.latitude,
                'longitude': c.longitude,
                'note': c.plateOrNote,
                'sha256': c.evidenceHash,
                'status': c.status.name,
              },
            )
            .toList(growable: false),
      },
    );
    await Clipboard.setData(ClipboardData(text: backupJson));
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1F1F23),
        content: Text(
          widget.isZh
              ? '已複製完整 ${widget.cases.length} 筆案件 JSON 備份至剪貼簿'
              : 'Copied JSON backup (${widget.cases.length} records) to clipboard',
          style: const TextStyle(
            color: Color(0xFF34C759),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _copyStatuteTemplate(TrafficStatuteTemplate tpl) async {
    if (tpl.isProRequired && !widget.isProUnlocked) {
      HapticFeedback.mediumImpact();
      widget.onRequestPaywall(
        '「${tpl.articleNumberZh}：${tpl.violationTitleZh}」需解鎖 Pro 以使用完整法條參考範本。',
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final EvidenceCaseRecord? latestCase =
        widget.cases.isNotEmpty ? widget.cases.first : null;

    final String fullStatement =
        TaiwanReportRepository.composeFullReportStatement(
      template: tpl,
      formattedTimeUtc8: latestCase?.formattedTimeUtc8 ??
          WatermarkLocationEngine.formatLocalTimestamp(DateTime.now()),
      fullAddress: latestCase?.address ??
          (widget.isZh ? '請填入實際現場地址' : 'Enter recorded site address'),
      plateNumber: latestCase?.plateOrNote ?? '',
      isZh: widget.isZh,
    );

    await Clipboard.setData(ClipboardData(text: fullStatement));
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1F1F23),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        content: Text(
          '已複製「${tpl.articleNumberZh}」文字範本',
          style: const TextStyle(
            color: Color(0xFF34C759),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _openOrCopyPortalUrl(
    CityReportPortal portal, {
    required bool isEpa,
    String? autoCopyNote,
  }) async {
    HapticFeedback.selectionClick();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String url =
        isEpa ? portal.safeEpaUri.toString() : portal.safeTrafficUri.toString();
    final String city = portal.localizedCityName(isZh: widget.isZh);

    await Clipboard.setData(ClipboardData(text: autoCopyNote ?? url));
    await NativeHardwareBridge.openOfficialPortalSafari(url);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1F1F23),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        content: Text(
          autoCopyNote != null
              ? '已複製紀錄摘要並開啟「$city官網」'
              : '已開啟「$city${isEpa ? "環保" : "交通"}官方網站」',
          style: const TextStyle(
            color: Color(0xFFF5F5F7),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  CaseSubmissionStatus _nextStatus(CaseSubmissionStatus current) {
    switch (current) {
      case CaseSubmissionStatus.pending:
        return CaseSubmissionStatus.submitted;
      case CaseSubmissionStatus.submitted:
        return CaseSubmissionStatus.archived;
      case CaseSubmissionStatus.archived:
        return CaseSubmissionStatus.pending;
    }
  }

  Widget _buildTopSegmentedBar() {
    if (!_showTrafficPortals) {
      return const SizedBox.shrink();
    }
    final List<({String keyName, String label})> segments =
        <({String keyName, String label})>[
      (keyName: 'portal_seg_cases', label: '案件 (${widget.cases.length})'),
      (keyName: 'portal_seg_portals', label: '22縣市入口'),
      (keyName: 'portal_seg_statutes', label: '法規參考'),
    ];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        children: List<Widget>.generate(segments.length, (int i) {
          final bool selected = _sectionIndex == i;
          return Expanded(
            child: GestureDetector(
              key: Key(segments[i].keyName),
              onTap: () {
                if (_sectionIndex == i) return;
                HapticFeedback.selectionClick();
                setState(() => _sectionIndex = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color:
                      selected ? const Color(0xFF2C2C2E) : Colors.transparent,
                  borderRadius: const BorderRadius.all(Radius.circular(9)),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      segments[i].label,
                      style: TextStyle(
                        color:
                            selected ? Colors.white : const Color(0xFF8E8E93),
                        fontSize: 12.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPdfReportCard() {
    final String subtitle = widget.isProUnlocked
        ? (widget.isZh
            ? 'LINE / Email 一鍵分享・含現場縮圖與全部 ${widget.cases.length} 筆 SHA-256'
            : 'Share PDF • All ${widget.cases.length} entries & photos')
        : (widget.isZh
            ? '免費試閱 1 筆含縮圖・升級解鎖全部 ${widget.cases.length} 筆與企業抬頭'
            : 'Free 1-entry photo preview • Upgrade for all ${widget.cases.length} entries');

    return Column(
      children: <Widget>[
        GestureDetector(
          key: const Key('export_pdf_report_btn'),
          onTap: widget.cases.isEmpty ? null : _handleExportPdfReport,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF161618),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(
                color: const Color(0xFFF5B73B).withValues(alpha: 0.32),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5B73B).withValues(alpha: 0.16),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFF5B73B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.isZh
                            ? '匯出 A4 驗收報告 PDF'
                            : 'Export A4 Inspection PDF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5B73B),
                    borderRadius: BorderRadius.all(Radius.circular(9)),
                  ),
                  child: Text(
                    widget.isZh ? '匯出' : 'Export',
                    style: const TextStyle(
                      color: Color(0xFF09090B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const Key('backup_cases_json_btn'),
            onPressed: widget.cases.isEmpty ? null : _backupAllCasesJson,
            icon: const Icon(
              Icons.download_outlined,
              size: 15,
              color: Color(0xFFA1A1AA),
            ),
            label: Text(
              widget.isZh
                  ? '備份完整紀錄 JSON (${widget.cases.length} 筆)'
                  : 'Backup All Records (${widget.cases.length})',
              style: const TextStyle(
                color: Color(0xFFA1A1AA),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildCasesView() {
    final DateTime nowUtc = DateTime.now().toUtc();
    if (widget.cases.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            widget.isZh
                ? '尚無本機存證紀錄，回相機拍攝即可自動歸檔'
                : 'No cases yet. Capture a photo to log.',
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        if (widget.showFirstTimeTip) ...<Widget>[
          FirstTimeTipBar(
            key: const Key('portal_first_tip_bar'),
            closeKey: const Key('portal_first_tip_close'),
            text: widget.isZh
                ? '拍完自動歸檔：可匯出 A4 PDF 報告或複製完整 JSON 備份'
                : 'Auto-logged captures: export A4 PDF or copy JSON backup',
            onDismiss: widget.onDismissFirstTimeTip,
          ),
          const SizedBox(height: 10),
        ],
        _buildPdfReportCard(),
        for (final EvidenceCaseRecord record in widget.cases) ...<Widget>[
          _buildCaseCard(record, nowUtc),
        ],
      ],
    );
  }

  Future<void> _promptEditCaseNote(EvidenceCaseRecord record) async {
    final TextEditingController ctrl =
        TextEditingController(text: record.plateOrNote);
    final String? edited = await showDialog<String>(
      context: context,
      builder: (BuildContext dlgCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161618),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          title: Text(
            widget.isZh ? '編輯備註說明' : 'Edit Case Note',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            key: const Key('edit_case_note_input'),
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF232326),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide.none,
              ),
              hintText: widget.isZh ? '輸入案場點位或項目說明' : 'Project or site note',
              hintStyle: const TextStyle(color: Color(0xFF636366)),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dlgCtx).pop(),
              child: Text(
                widget.isZh ? '取消' : 'Cancel',
                style: const TextStyle(color: Color(0xFF8E8E93)),
              ),
            ),
            ElevatedButton(
              key: const Key('save_case_note_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5B73B),
                foregroundColor: const Color(0xFF09090B),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(dlgCtx).pop(ctrl.text),
              child: Text(
                widget.isZh ? '儲存' : 'Save',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    if (edited != null && edited.trim().isNotEmpty && mounted) {
      widget.onEditCaseNote?.call(record.id, edited.trim());
    }
  }

  Future<bool?> _confirmDeleteCase(EvidenceCaseRecord record) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dlgCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161618),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          title: Text(
            widget.isZh ? '確認刪除此筆紀錄？' : 'Delete Record?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            widget.isZh
                ? '刪除後將同時移除 App 內縮圖「${record.plateOrNote}」，系統相簿原檔不會受影響。'
                : 'Removes "${record.plateOrNote}" from Cases. Original in Photos stays intact.',
            style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 13),
          ),
          actions: <Widget>[
            TextButton(
              key: const Key('cancel_delete_case_btn'),
              onPressed: () => Navigator.of(dlgCtx).pop(false),
              child: Text(
                widget.isZh ? '取消' : 'Cancel',
                style: const TextStyle(color: Color(0xFF8E8E93)),
              ),
            ),
            ElevatedButton(
              key: const Key('confirm_delete_case_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF453A),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () => Navigator.of(dlgCtx).pop(true),
              child: Text(
                widget.isZh ? '確認刪除' : 'Delete',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareCaseThumbnail(EvidenceCaseRecord record) async {
    if (widget.isTestMode ||
        record.thumbnailPath == null ||
        record.thumbnailPath!.isEmpty) {
      return;
    }
    try {
      final File file = File(record.thumbnailPath!);
      if (!await file.exists()) return;
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;
      await NativeHardwareBridge.shareImageBytes(
        bytes,
        text: '${record.formattedTimeUtc8} | ${record.address} | ${record.plateOrNote}',
        isTestMode: widget.isTestMode,
      );
    } catch (_) {}
  }

  Widget _buildCaseCard(EvidenceCaseRecord record, DateTime nowUtc) {
    final CityReportPortal? matchedPortal =
        ExportHandoffBanner.resolvePortalByAddress(record.address);
    final bool isDone = record.status == CaseSubmissionStatus.submitted ||
        record.status == CaseSubmissionStatus.archived;
    final bool hasThumb = !widget.isTestMode &&
        record.thumbnailPath != null &&
        record.thumbnailPath!.isNotEmpty &&
        File(record.thumbnailPath!).existsSync();
    final String coordsLabel = record.hasValidCoordinates
        ? '${record.latitude!.toStringAsFixed(4)}, ${record.longitude!.toStringAsFixed(4)}'
        : (widget.isZh ? '無實機 GPS' : 'No GPS');

    return Dismissible(
      key: Key('case_dismissible_${record.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeleteCase(record),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: const Color(0xFFFF453A).withValues(alpha: 0.22),
          borderRadius: const BorderRadius.all(Radius.circular(16)),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Color(0xFFFF453A),
          size: 22,
        ),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        widget.onDeleteCase?.call(record.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: Color(0xFF161618),
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFF232326),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: hasThumb
                      ? ClipRRect(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(10)),
                          child: Image.file(
                            File(record.thumbnailPath!),
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(
                          Icons.photo_camera_back_rounded,
                          color: Color(0xFF636366),
                          size: 22,
                        ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              record.plateOrNote,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (record.isSample) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFF232326),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(5)),
                              ),
                              child: Text(
                                widget.isZh ? '範例' : 'Sample',
                                style: const TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          GestureDetector(
                            key: Key('edit_case_note_${record.id}'),
                            onTap: () => _promptEditCaseNote(record),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.edit_outlined,
                                color: Color(0xFF8E8E93),
                                size: 15,
                              ),
                            ),
                          ),
                          if (hasThumb) ...<Widget>[
                            const SizedBox(width: 6),
                            GestureDetector(
                              key: Key('share_case_${record.id}'),
                              onTap: () => _shareCaseThumbnail(record),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(
                                  Icons.ios_share_rounded,
                                  color: Color(0xFFF5B73B),
                                  size: 15,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${record.formattedTimeUtc8} · ${record.address}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          GestureDetector(
                            key: Key('toggle_case_status_${record.id}'),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              widget.onUpdateCaseStatus(
                                record.id,
                                _nextStatus(record.status),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: isDone
                                    ? const Color(0xFF34C759)
                                        .withValues(alpha: 0.14)
                                    : const Color(0xFF232326),
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(999)),
                              ),
                              child: Text(
                                record.status.localizedLabel(isZh: widget.isZh),
                                style: TextStyle(
                                  color: isDone
                                      ? const Color(0xFF34C759)
                                      : const Color(0xFFE4E4E7),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              coordsLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF636366),
                                fontSize: 11,
                                fontFeatures: <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_showTrafficPortals) ...<Widget>[
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      TaiwanReportRepository.formatDeadlineBadge(
                        record: record,
                        nowUtc: nowUtc,
                        isZh: widget.isZh,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDone
                            ? const Color(0xFF34C759)
                            : const Color(0xFFF5B73B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (matchedPortal != null) ...<Widget>[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _openOrCopyPortalUrl(
                        matchedPortal,
                        isEpa: false,
                        autoCopyNote:
                            '${record.formattedTimeUtc8} | ${record.address} | ${record.plateOrNote}',
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.all(Radius.circular(9)),
                        ),
                        child: Text(
                          '${matchedPortal.cityNameZh}官網',
                          style: const TextStyle(
                            color: Color(0xFFF5F5F7),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPortalsView() {
    final List<CityReportPortal> portals = TaiwanReportRepository.filterPortals(
      region: _selectedRegion,
      query: _searchController.text,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFF161618),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: TextField(
            key: const Key('portal_city_search_input'),
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF636366),
                size: 18,
              ),
              hintText: widget.isZh
                  ? '搜尋 22 縣市或中央機關（例：花蓮、雲林）'
                  : 'Search Taiwan cities',
              hintStyle: const TextStyle(
                color: Color(0xFF636366),
                fontSize: 13,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              _buildFilterPill(
                key: const Key('portal_region_all'),
                label: '全部 (${TaiwanReportRepository.allCityPortals.length})',
                selected: _selectedRegion == null,
                onTap: () {
                  setState(() => _selectedRegion = null);
                  widget.onPreferencesChanged?.call(
                    widget.preferences.copyWith(clearSelectedPortalRegion: true),
                  );
                },
              ),
              for (final PortalRegion region in PortalRegion.values)
                _buildFilterPill(
                  key: Key('portal_region_${region.name}'),
                  label: region.localizedLabel(isZh: widget.isZh),
                  selected: _selectedRegion == region,
                  onTap: () {
                    setState(() => _selectedRegion = region);
                    widget.onPreferencesChanged?.call(
                      widget.preferences.copyWith(selectedPortalRegion: region),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (portals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                widget.isZh ? '找不到符合條件的入口' : 'No matching portals',
                style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
              ),
            ),
          ),
        for (final CityReportPortal portal in portals)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              color: Color(0xFF161618),
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        portal.localizedCityName(isZh: widget.isZh),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${portal.maxTrafficVideoMB.toStringAsFixed(0)} MB · ${portal.localizedEpaNote(isZh: widget.isZh)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  key: Key('open_traffic_portal_${portal.id}'),
                  onTap: () => _openOrCopyPortalUrl(portal, isEpa: false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.all(Radius.circular(9)),
                    ),
                    child: const Text(
                      '交通',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  key: Key('open_epa_portal_${portal.id}'),
                  onTap: () => _openOrCopyPortalUrl(portal, isEpa: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF232326),
                      borderRadius: BorderRadius.all(Radius.circular(9)),
                    ),
                    child: const Text(
                      '環保',
                      style: TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFilterPill({
    Key? key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        key: key,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF5B73B) : const Color(0xFF161618),
            borderRadius: const BorderRadius.all(Radius.circular(999)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF09090B) : const Color(0xFF8E8E93),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatutesView() {
    final List<TrafficStatuteTemplate> all =
        TaiwanReportRepository.statuteTemplates;

    return Column(
      children: <Widget>[
        for (final TrafficStatuteTemplate tpl in all)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFF161618),
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${tpl.localizedArticle(isZh: widget.isZh)} · ${tpl.localizedFine(isZh: widget.isZh)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tpl.localizedTitle(isZh: widget.isZh),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  key: Key('copy_statute_btn_${tpl.code}'),
                  onTap: () => _copyStatuteTemplate(tpl),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: (tpl.isProRequired && !widget.isProUnlocked)
                          ? const Color(0xFF232326)
                          : const Color(0xFFF5B73B),
                      borderRadius: const BorderRadius.all(Radius.circular(9)),
                    ),
                    child: Text(
                      (tpl.isProRequired && !widget.isProUnlocked)
                          ? 'Pro'
                          : (widget.isZh ? '複製' : 'Copy'),
                      style: TextStyle(
                        color: (tpl.isProRequired && !widget.isProUnlocked)
                            ? const Color(0xFF8E8E93)
                            : const Color(0xFF09090B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ExportHandoffContext? handoff =
        widget.activeHandoff is ExportHandoffContext
            ? widget.activeHandoff as ExportHandoffContext
            : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (handoff != null)
            ExportHandoffBanner(
              isZh: widget.isZh,
              handoff: handoff,
              activePersona: widget.activePersona,
              onOpenTrafficPortal: (CityReportPortal portal) =>
                  _openOrCopyPortalUrl(
                portal,
                isEpa: false,
                autoCopyNote: handoff.clipboardSummary,
              ),
              onOpenEpaPortal: (CityReportPortal portal) =>
                  _openOrCopyPortalUrl(
                portal,
                isEpa: true,
                autoCopyNote: handoff.clipboardSummary,
              ),
              onExportPdf: widget.cases.isEmpty ? null : _handleExportPdfReport,
              onRequestReview: () => NativeHardwareBridge.requestInAppReview(
                isTestMode: widget.isTestMode,
              ),
              onDismiss: widget.onDismissHandoff ?? () {},
            ),
          _buildTopSegmentedBar(),
          if (_showTrafficPortals) const SizedBox(height: 14),
          if (_sectionIndex == 0 || !_showTrafficPortals) _buildCasesView(),
          if (_showTrafficPortals && _sectionIndex == 1) _buildPortalsView(),
          if (_showTrafficPortals && _sectionIndex == 2) _buildStatutesView(),
          const SizedBox(height: 14),
          Text(
            TaiwanReportRepository.officialDisclaimer(isZh: widget.isZh),
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
