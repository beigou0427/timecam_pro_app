import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 台灣監理格式車牌與外勤案場分類列舉
enum TaiwanVehiclePlateCategory {
  standard7Code(
    labelZh: '新式汽機車 (3英-4數)',
    labelEn: 'Standard 7-Char (ABC-1234)',
    samplePrefix: 'ABC-',
  ),
  commercialTaxi(
    labelZh: '營業/多元車隊 (R開頭)',
    labelEn: 'Commercial/Fleet (RCD-5566)',
    samplePrefix: 'RCD-',
  ),
  electricVehicle(
    labelZh: '電動汽機車 (E開頭)',
    labelEn: 'Electric Vehicle (EAL-8899)',
    samplePrefix: 'EAL-',
  ),
  heavyMotorcycle(
    labelZh: '大型重機 (L開頭)',
    labelEn: 'Heavy Moto (LGA-7788)',
    samplePrefix: 'LGA-',
  ),
  engineeringSite(
    labelZh: '外勤工程/太陽能案場',
    labelEn: 'Field Engineering Site',
    samplePrefix: 'SITE-',
  );

  const TaiwanVehiclePlateCategory({
    required this.labelZh,
    required this.labelEn,
    required this.samplePrefix,
  });

  final String labelZh;
  final String labelEn;
  final String samplePrefix;

  String localizedLabel({required bool isZh}) => isZh ? labelZh : labelEn;
}

/// 單手一鍵附加之現場態樣與巡檢標籤模型
@immutable
class QuickViolationTag {
  const QuickViolationTag({
    required this.tagZh,
    required this.tagEn,
    required this.isEngineering,
  });

  final String tagZh;
  final String tagEn;
  final bool isEngineering;

  String localizedTag({required bool isZh}) => isZh ? tagZh : tagEn;
}

/// 全鍵盤（符合 >=44pt Apple HIG 觸控高度）極簡車牌與備註快選面板
class TaiwanPlateQuickPad extends StatefulWidget {
  const TaiwanPlateQuickPad({
    super.key,
    required this.isZh,
    required this.initialValue,
    required this.onApplyNote,
    this.onScanPlateOcr,
  });

  final bool isZh;
  final String initialValue;
  final ValueChanged<String> onApplyNote;
  final Future<String?> Function()? onScanPlateOcr;

  static const List<String> commonPrefixes = <String>[
    'ABC-',
    'BLN-',
    'MPR-',
    'RCD-',
    'EAL-',
    'NML-',
    'KPD-',
    'TAA-',
  ];

  static const List<QuickViolationTag> quickTags = <QuickViolationTag>[
    QuickViolationTag(tagZh: '車道阻塞', tagEn: 'Lane Obstruction', isEngineering: false),
    QuickViolationTag(tagZh: '未打方向燈', tagEn: 'No Signal', isEngineering: false),
    QuickViolationTag(tagZh: '未禮讓行人', tagEn: 'No Yield', isEngineering: false),
    QuickViolationTag(tagZh: '危險變換車道', tagEn: 'Unsafe Merge', isEngineering: false),
    QuickViolationTag(tagZh: '占用人行道', tagEn: 'Sidewalk Blocked', isEngineering: false),
    QuickViolationTag(tagZh: '環保清潔紀錄', tagEn: 'Environmental Log', isEngineering: false),
    QuickViolationTag(tagZh: '巡檢合格', tagEn: 'Inspected', isEngineering: true),
    QuickViolationTag(tagZh: '施工存證', tagEn: 'Pre-Work', isEngineering: true),
  ];

  /// 監理車牌格式整理：支援 3英-4數 與舊式前/後數字車牌，只針對數字段校正 O/I
  static String sanitizeTaiwanPlate(String rawInput) {
    final String trimmed = rawInput.trim().toUpperCase();
    if (trimmed.isEmpty) return '';

    final String clean = trimmed.replaceAll(RegExp(r'[^A-Z0-9-]'), '');
    if (clean.isEmpty) return '';

    if (!clean.contains('-')) {
      final RegExpMatch? m34 =
          RegExp(r'^([A-Z]{3})([0-9OI]{4})$').firstMatch(clean);
      if (m34 != null) {
        final String suffix =
            m34.group(2)!.replaceAll('O', '0').replaceAll('I', '1');
        return '${m34.group(1)}-$suffix';
      }
      final RegExpMatch? m42 =
          RegExp(r'^([0-9OI]{4})([A-Z]{2})$').firstMatch(clean);
      if (m42 != null) {
        final String prefix =
            m42.group(1)!.replaceAll('O', '0').replaceAll('I', '1');
        return '$prefix-${m42.group(2)}';
      }
      return clean;
    }

    final List<String> parts = clean.split('-');
    if (parts.length >= 2) {
      final String p0 = parts[0];
      final String p1 = parts[1];
      if (RegExp(r'^[A-Z]+$').hasMatch(p0)) {
        final String fixedP1 = p1.replaceAll('O', '0').replaceAll('I', '1');
        return '$p0-$fixedP1';
      }
      if (RegExp(r'^[A-Z]+$').hasMatch(p1)) {
        final String fixedP0 = p0.replaceAll('O', '0').replaceAll('I', '1');
        return '$fixedP0-$p1';
      }
      return '$p0-$p1';
    }
    return clean;
  }

  @override
  State<TaiwanPlateQuickPad> createState() => _TaiwanPlateQuickPadState();
}

class _TaiwanPlateQuickPadState extends State<TaiwanPlateQuickPad> {
  late final TextEditingController _plateController;
  late String _tagPart;
  bool _isScanningOcr = false;

  static const List<List<String>> _qwertyRows = <List<String>>[
    <String>['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    <String>['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    <String>['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ];

  @override
  void initState() {
    super.initState();
    final String init = widget.initialValue.trim();
    final int spaceIdx = init.indexOf(' ');
    String initialPlate;
    if (spaceIdx > 0) {
      initialPlate =
          TaiwanPlateQuickPad.sanitizeTaiwanPlate(init.substring(0, spaceIdx));
      _tagPart = init.substring(spaceIdx + 1).trim();
    } else {
      initialPlate = init.isEmpty
          ? ''
          : TaiwanPlateQuickPad.sanitizeTaiwanPlate(init);
      _tagPart = '';
    }
    _plateController = TextEditingController(text: initialPlate);
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  void _setPlateText(String next) {
    _plateController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    setState(() {});
  }

  void _appendChar(String ch, {required bool isLetter}) {
    HapticFeedback.lightImpact();
    final String cur = _plateController.text.toUpperCase();
    if (cur.length >= 8) return;

    if (ch == '-') {
      if (cur.isEmpty || cur.contains('-')) return;
      _setPlateText('$cur-');
      return;
    }

    if (isLetter && !cur.contains('-') && RegExp(r'^[A-Z]{2}$').hasMatch(cur)) {
      _setPlateText('$cur$ch-');
      return;
    }
    if (!isLetter &&
        !cur.contains('-') &&
        RegExp(r'^[A-Z]{2,3}$').hasMatch(cur)) {
      _setPlateText('$cur-$ch');
      return;
    }
    _setPlateText('$cur$ch');
  }

  void _backspace() {
    HapticFeedback.selectionClick();
    final String cur = _plateController.text;
    if (cur.isEmpty) return;
    _setPlateText(cur.substring(0, cur.length - 1));
  }

  Future<void> _triggerOcrScan() async {
    if (_isScanningOcr || widget.onScanPlateOcr == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _isScanningOcr = true);
    final String? recognized = await widget.onScanPlateOcr!();
    if (!mounted) return;
    setState(() => _isScanningOcr = false);
    if (recognized != null && recognized.trim().isNotEmpty) {
      _setPlateText(
        TaiwanPlateQuickPad.sanitizeTaiwanPlate(recognized),
      );
    }
  }

  String _composedPreview() {
    final String raw = _plateController.text.trim();
    final String formattedPlate =
        raw.isEmpty ? '' : TaiwanPlateQuickPad.sanitizeTaiwanPlate(raw);
    final String tag = _tagPart.trim();
    if (formattedPlate.isEmpty) return tag;
    if (tag.isEmpty) return formattedPlate;
    return '$formattedPlate $tag';
  }

  Widget _buildKeyButton({
    Key? key,
    required String label,
    required VoidCallback onTap,
    Color bgColor = const Color(0xFF232326),
    Color fgColor = Colors.white,
    double fontSize = 15,
    Widget? child,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: child ??
            Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
      ),
    );
  }

  Widget _buildDigitsRow() {
    const List<String> digits = <String>[
      '1', '2', '3', '4', '5', '6', '7', '8', '9', '0',
    ];
    return Row(
      children: <Widget>[
        for (int i = 0; i < digits.length; i++) ...<Widget>[
          Expanded(
            child: _buildKeyButton(
              key: Key('plate_digit_btn_${digits[i]}'),
              label: digits[i],
              onTap: () => _appendChar(digits[i], isLetter: false),
            ),
          ),
          if (i < digits.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }

  Widget _buildQwertyKeyboard() {
    return Column(
      children: <Widget>[
        // Row 1: Q..P (10 keys)
        Row(
          children: <Widget>[
            for (int c = 0; c < _qwertyRows[0].length; c++) ...<Widget>[
              Expanded(
                child: _buildKeyButton(
                  key: Key('plate_letter_btn_${_qwertyRows[0][c]}'),
                  label: _qwertyRows[0][c],
                  fontSize: 13.5,
                  onTap: () =>
                      _appendChar(_qwertyRows[0][c], isLetter: true),
                ),
              ),
              if (c < _qwertyRows[0].length - 1) const SizedBox(width: 4),
            ],
          ],
        ),
        const SizedBox(height: 5),
        // Row 2: A..L (9 keys centered)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              for (int c = 0; c < _qwertyRows[1].length; c++) ...<Widget>[
                Expanded(
                  child: _buildKeyButton(
                    key: Key('plate_letter_btn_${_qwertyRows[1][c]}'),
                    label: _qwertyRows[1][c],
                    fontSize: 13.5,
                    onTap: () =>
                        _appendChar(_qwertyRows[1][c], isLetter: true),
                  ),
                ),
                if (c < _qwertyRows[1].length - 1) const SizedBox(width: 4),
              ],
            ],
          ),
        ),
        const SizedBox(height: 5),
        // Row 3: '-' + Z..M + Backspace (9 slots comfortably meeting HIG target width)
        Row(
          children: <Widget>[
            Expanded(
              child: _buildKeyButton(
                key: const Key('plate_hyphen_btn'),
                label: '-',
                bgColor: const Color(0xFF2C2C2E),
                fgColor: const Color(0xFFA1A1AA),
                onTap: () => _appendChar('-', isLetter: false),
              ),
            ),
            const SizedBox(width: 4),
            for (int c = 0; c < _qwertyRows[2].length; c++) ...<Widget>[
              Expanded(
                child: _buildKeyButton(
                  key: Key('plate_letter_btn_${_qwertyRows[2][c]}'),
                  label: _qwertyRows[2][c],
                  fontSize: 13.5,
                  onTap: () =>
                      _appendChar(_qwertyRows[2][c], isLetter: true),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              flex: 2,
              child: _buildKeyButton(
                key: const Key('plate_backspace_btn'),
                label: '',
                bgColor: const Color(0xFF2C2C2E),
                onTap: _backspace,
                child: const Icon(
                  Icons.backspace_outlined,
                  color: Color(0xFFF5B73B),
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 18 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: const BorderRadius.all(Radius.circular(99)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.isZh ? '車牌辨識與快選' : 'Plate OCR & Keypad',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.onScanPlateOcr != null)
                    GestureDetector(
                      key: const Key('plate_ocr_scan_btn'),
                      onTap: _isScanningOcr ? null : _triggerOcrScan,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5B73B).withValues(alpha: 0.18),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(999)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (_isScanningOcr)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  color: Color(0xFFF5B73B),
                                ),
                              )
                            else
                              const Icon(
                                Icons.document_scanner_rounded,
                                size: 14,
                                color: Color(0xFFF5B73B),
                              ),
                            const SizedBox(width: 5),
                            Text(
                              widget.isZh ? 'AI 辨識車牌' : 'Scan Plate',
                              style: const TextStyle(
                                color: Color(0xFFF5B73B),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF0A0A0C),
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        key: const Key('plate_custom_input'),
                        controller: _plateController,
                        textCapitalization: TextCapitalization.characters,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFF5F5F7),
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          fontFeatures: <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: widget.isZh ? '輸入或辨識車牌號碼' : 'ABC-1234',
                          hintStyle: const TextStyle(
                            color: Color(0xFF52525B),
                            fontSize: 16,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    GestureDetector(
                      key: const Key('plate_clear_btn'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _setPlateText('');
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.cancel_rounded,
                          color: Color(0xFF636366),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _buildDigitsRow(),
              const SizedBox(height: 5),
              _buildQwertyKeyboard(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    TaiwanPlateQuickPad.quickTags.map((QuickViolationTag t) {
                  final String label = t.localizedTag(isZh: widget.isZh);
                  final bool selected = _tagPart == label;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _tagPart = selected ? '' : label;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF34C759)
                            : const Color(0xFF232326),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(999)),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF09090B)
                              : const Color(0xFFE4E4E7),
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  key: const Key('apply_plate_quick_pad_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5B73B),
                    foregroundColor: const Color(0xFF09090B),
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onApplyNote(_composedPreview());
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    widget.isZh ? '套用備註' : 'Apply',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
