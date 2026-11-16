import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/native_hardware_bridge.dart';
import '../../core/taiwan_report_repository.dart';
import '../widgets/export_handoff_banner.dart';

/// Tab 3：全台 22 縣市通報入口、道交法條模板庫與 7 日時效案件夾
class ReportPortalTab extends StatefulWidget {
  const ReportPortalTab({
    super.key,
    required this.isZh,
    required this.isProUnlocked,
    required this.cases,
    required this.onUpdateCaseStatus,
    required this.onRequestPaywall,
    this.activeHandoff,
    this.onDismissHandoff,
  });

  final bool isZh;
  final bool isProUnlocked;
  final List<EvidenceCaseRecord> cases;
  final void Function(String caseId, CaseSubmissionStatus nextStatus)
      onUpdateCaseStatus;
  final ValueChanged<String> onRequestPaywall;
  final ExportHandoffContext? activeHandoff;
  final VoidCallback? onDismissHandoff;

  @override
  State<ReportPortalTab> createState() => _ReportPortalTabState();
}

class _ReportPortalTabState extends State<ReportPortalTab> {
  final TextEditingController _searchController = TextEditingController();
  PortalRegion? _selectedRegion;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _copyStatuteTemplate(TrafficStatuteTemplate tpl) async {
    if (tpl.isProRequired && !widget.isProUnlocked) {
      HapticFeedback.mediumImpact();
      final String reasonZh =
          '🔒「${tpl.articleNumberZh}：${tpl.violationTitleZh}」屬於 Pro 專業版標準舉發構成要件模板。立即解鎖 Pro 即可一鍵複製全套法條與環保獎金檢舉範本！';
      final String reasonEn =
          '🔒 "${tpl.articleNumberEn}: ${tpl.violationTitleEn}" is a Pro template. Unlock Pro to copy all official legal statements!';
      widget.onRequestPaywall(widget.isZh ? reasonZh : reasonEn);
      return;
    }

    HapticFeedback.heavyImpact();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final EvidenceCaseRecord? latestCase =
        widget.cases.isNotEmpty ? widget.cases.first : null;

    final String fullStatement =
        TaiwanReportRepository.composeFullReportStatement(
      template: tpl,
      formattedTimeUtc8: latestCase?.formattedTimeUtc8 ?? '2026/11/16 14:30:00',
      fullAddress: latestCase?.address ??
          (widget.isZh ? '台北市信義區忠孝東路五段22號' : 'Xinyi Dist., Taipei City'),
      plateNumber: latestCase?.plateOrNote ?? 'ABC-8899',
      isZh: widget.isZh,
    );

    await Clipboard.setData(ClipboardData(text: fullStatement));
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        content: Text(
          widget.isZh
              ? '📋 已複製「${tpl.articleNumberZh}」完整檢舉事實描述（含最新案件時間與車號）！'
              : '📋 Copied "${tpl.articleNumberEn}" full statement to clipboard!',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Future<void> _openOrCopyPortalUrl(
    CityReportPortal portal, {
    required bool isEpa,
  }) async {
    HapticFeedback.selectionClick();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String url =
        isEpa ? portal.safeEpaUri.toString() : portal.safeTrafficUri.toString();
    final String city = portal.localizedCityName(isZh: widget.isZh);

    await Clipboard.setData(ClipboardData(text: url));
    await NativeHardwareBridge.openOfficialPortalSafari(url);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0284C7),
        content: Text(
          widget.isZh
              ? '🌐 已準備開啟「$city${isEpa ? "環保局獎金" : "警察局交通"}檢舉網」並複製官方網址：$url'
              : '🌐 Ready to open $city ${isEpa ? "EPA" : "Traffic"} Portal (URL copied): $url',
          style: const TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildEvidenceCaseVault() {
    final DateTime nowUtc = DateTime.now().toUtc();
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
          Row(
            children: <Widget>[
              const Icon(
                Icons.folder_special_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isZh
                      ? '本地加密案件庫 (道交 7-1 條：7 日舉發時效追蹤)'
                      : 'Local Evidence Vault (7-Day Statutory Limit Tracker)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                child: Text(
                  '${widget.cases.length}',
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final EvidenceCaseRecord record in widget.cases)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(
                  color: record.status == CaseSubmissionStatus.pending
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.7)
                      : const Color(0xFF334155),
                ),
              ),
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
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: record.status == CaseSubmissionStatus.submitted
                              ? const Color(0xFF10B981).withValues(alpha: 0.2)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(6)),
                        ),
                        child: Text(
                          TaiwanReportRepository.formatDeadlineBadge(
                            record: record,
                            nowUtc: nowUtc,
                            isZh: widget.isZh,
                          ),
                          style: TextStyle(
                            color:
                                record.status == CaseSubmissionStatus.submitted
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFFFDE68A),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${record.formattedTimeUtc8} • ${record.address}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        widget.isZh
                            ? '壓縮容量：${record.compressedSizeMB.toStringAsFixed(1)} MB'
                            : 'Size: ${record.compressedSizeMB.toStringAsFixed(1)} MB',
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      OutlinedButton.icon(
                        key: Key('toggle_case_status_${record.id}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          side: const BorderSide(color: Color(0xFF475569)),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          widget.onUpdateCaseStatus(
                            record.id,
                            _nextStatus(record.status),
                          );
                        },
                        icon: const Icon(Icons.sync_rounded, size: 15),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            record.status.localizedLabel(isZh: widget.isZh),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
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
    );
  }

  Widget _buildStatuteTemplatesSection() {
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
          Row(
            children: <Widget>[
              const Icon(
                Icons.gavel_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isZh
                      ? '常用道交條例與環保獎金事實描述模板 (一鍵複製)'
                      : 'Official Traffic & EPA Legal Statement Templates',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final TrafficStatuteTemplate tpl
              in TaiwanReportRepository.statuteTemplates)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF59E0B),
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                        ),
                        child: Text(
                          tpl.localizedArticle(isZh: widget.isZh),
                          style: const TextStyle(
                            color: Color(0xFF121212),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        tpl.localizedFine(isZh: widget.isZh),
                        style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (tpl.isProRequired && !widget.isProUnlocked)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFEF4444).withValues(alpha: 0.2),
                            borderRadius:
                                const BorderRadius.all(Radius.circular(5)),
                          ),
                          child: const Text(
                            '🔒 PRO',
                            style: TextStyle(
                              color: Color(0xFFFCA5A5),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tpl.localizedTitle(isZh: widget.isZh),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tpl.localizedBody(isZh: widget.isZh),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: Key('copy_statute_btn_${tpl.code}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            (tpl.isProRequired && !widget.isProUnlocked)
                                ? const Color(0xFF334155)
                                : const Color(0xFFF59E0B),
                        foregroundColor:
                            (tpl.isProRequired && !widget.isProUnlocked)
                                ? Colors.white
                                : const Color(0xFF121212),
                        visualDensity: VisualDensity.compact,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                      onPressed: () => _copyStatuteTemplate(tpl),
                      icon: Icon(
                        (tpl.isProRequired && !widget.isProUnlocked)
                            ? Icons.lock_outline_rounded
                            : Icons.copy_all_rounded,
                        size: 16,
                      ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          (tpl.isProRequired && !widget.isProUnlocked)
                              ? (widget.isZh
                                  ? '解鎖 Pro 一鍵複製此標準法條描述'
                                  : 'Unlock Pro to Copy Legal Statement')
                              : (widget.isZh
                                  ? '一鍵複製警方標準構成要件描述'
                                  : 'Copy Standard Report Statement'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaiwanPortalsDirectory() {
    final List<CityReportPortal> portals = TaiwanReportRepository.filterPortals(
      region: _selectedRegion,
      query: _searchController.text,
    );

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
          Row(
            children: <Widget>[
              const Icon(
                Icons.public_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isZh
                      ? '全台各縣市警察局交通 / 環保局獎金檢舉官方入口'
                      : 'Taiwan Official Traffic & EPA Reward Portals',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('portal_city_search_input'),
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF0F172A),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF94A3B8),
                size: 18,
              ),
              hintText: widget.isZh
                  ? '搜尋縣市名稱或關鍵字 (例: 台北 / 台南 / 煙蒂)'
                  : 'Search city or keyword (e.g. Taipei / Tainan)',
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
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      widget.isZh ? '全部地區' : 'All Regions',
                      style: TextStyle(
                        color: _selectedRegion == null
                            ? const Color(0xFF121212)
                            : Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    selected: _selectedRegion == null,
                    selectedColor: const Color(0xFFF59E0B),
                    backgroundColor: const Color(0xFF0F172A),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedRegion = null;
                      });
                    },
                  ),
                ),
                for (final PortalRegion region in PortalRegion.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        region.localizedLabel(isZh: widget.isZh),
                        style: TextStyle(
                          color: _selectedRegion == region
                              ? const Color(0xFF121212)
                              : Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      selected: _selectedRegion == region,
                      selectedColor: const Color(0xFFF59E0B),
                      backgroundColor: const Color(0xFF0F172A),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedRegion = region;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (portals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  widget.isZh
                      ? '找不到符合搜尋條件的縣市入口'
                      : 'No matching city portals found.',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          for (final CityReportPortal portal in portals)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          portal.localizedCityName(isZh: widget.isZh),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E293B),
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                        ),
                        child: Text(
                          '上限 ${portal.maxTrafficVideoMB.toStringAsFixed(0)}MB',
                          style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '💰 ${portal.localizedEpaNote(isZh: widget.isZh)}',
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton.icon(
                          key: Key('open_traffic_portal_${portal.id}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                          ),
                          onPressed: () =>
                              _openOrCopyPortalUrl(portal, isEpa: false),
                          icon: const Icon(
                            Icons.local_police_rounded,
                            size: 15,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.isZh ? '交通違規檢舉網' : 'Traffic Portal',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: Key('open_epa_portal_${portal.id}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF34D399),
                            visualDensity: VisualDensity.compact,
                            side: const BorderSide(color: Color(0xFF10B981)),
                            shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                          ),
                          onPressed: () =>
                              _openOrCopyPortalUrl(portal, isEpa: true),
                          icon: const Icon(Icons.eco_rounded, size: 15),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.isZh ? '環保獎金檢舉網' : 'EPA Reward Web',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
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
    );
  }

  Widget _buildDisclaimerFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Text(
        TaiwanReportRepository.officialDisclaimer(isZh: widget.isZh),
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 11,
          height: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (widget.activeHandoff != null)
            ExportHandoffBanner(
              isZh: widget.isZh,
              handoff: widget.activeHandoff!,
              onOpenTrafficPortal: (CityReportPortal p) =>
                  _openOrCopyPortalUrl(p, isEpa: false),
              onOpenEpaPortal: (CityReportPortal p) =>
                  _openOrCopyPortalUrl(p, isEpa: true),
              onDismiss: widget.onDismissHandoff ?? () {},
            ),
          _buildEvidenceCaseVault(),
          const SizedBox(height: 12),
          _buildStatuteTemplatesSection(),
          const SizedBox(height: 12),
          _buildTaiwanPortalsDirectory(),
          const SizedBox(height: 12),
          _buildDisclaimerFooter(),
        ],
      ),
    );
  }
}
