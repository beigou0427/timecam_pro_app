import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 台灣公路總局監理所車牌與外勤案場分類列舉
enum TaiwanVehiclePlateCategory {
  standard7Code(
    labelZh: '新式汽機車 (3英-4數)',
    labelEn: 'Standard 7-Char (ABC-1234)',
    samplePrefix: 'ABC-',
  ),
  commercialTaxi(
    labelZh: '營業/多元計程車 (R開頭)',
    labelEn: 'Commercial/Taxi (RCD-5566)',
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

/// 單手一鍵附加之高頻違規態樣與巡檢狀態膠囊模型
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

/// PM #2 Shreyas Doshi 改進：零摩擦台灣車牌智慧格式化與單手閃電快選面板
class TaiwanPlateQuickPad extends StatefulWidget {
  const TaiwanPlateQuickPad({
    super.key,
    required this.isZh,
    required this.initialValue,
    required this.onApplyNote,
  });

  final bool isZh;
  final String initialValue;
  final ValueChanged<String> onApplyNote;

  /// 台灣街頭高頻車牌字首快選清單
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

  /// 單手一鍵點選之高頻違規與外勤巡檢標籤庫
  static const List<QuickViolationTag> quickTags = <QuickViolationTag>[
    QuickViolationTag(
      tagZh: '紅線違停',
      tagEn: 'Red Curb',
      isEngineering: false,
    ),
    QuickViolationTag(
      tagZh: '併排停車',
      tagEn: 'Double Parked',
      isEngineering: false,
    ),
    QuickViolationTag(
      tagZh: '未打方向燈',
      tagEn: 'No Turn Signal',
      isEngineering: false,
    ),
    QuickViolationTag(
      tagZh: '未禮讓行人',
      tagEn: 'No Pedestrian Yield',
      isEngineering: false,
    ),
    QuickViolationTag(
      tagZh: '占用人行道',
      tagEn: 'Sidewalk Blocked',
      isEngineering: false,
    ),
    QuickViolationTag(
      tagZh: '亂丟煙蒂',
      tagEn: 'Littering Butt',
      isEngineering: false,
    ),
    QuickViolationTag(
      tagZh: '太陽能案場巡檢合格',
      tagEn: 'Solar Site Inspected',
      isEngineering: true,
    ),
    QuickViolationTag(
      tagZh: '施工前現場存證',
      tagEn: 'Pre-Work Evidence',
      isEngineering: true,
    ),
  ];

  /// 台灣監理所車牌防混淆智慧格式化：自動轉大寫、補連字號並將數字區誤植之 O/I 校正為 0/1
  static String sanitizeTaiwanPlate(String rawInput) {
    final String trimmed = rawInput.trim().toUpperCase();
    if (trimmed.isEmpty) return 'ABC-1234';

    final String clean = trimmed.replaceAll(RegExp(r'[^A-Z0-9-]'), '');
    if (!clean.contains('-') && clean.length == 7) {
      final String prefix = clean.substring(0, 3);
      final String suffix = clean
          .substring(3, 7)
          .replaceAll('O', '0')
          .replaceAll('I', '1');
      return '$prefix-$suffix';
    }

    if (clean.contains('-')) {
      final List<String> parts = clean.split('-');
      if (parts.length >= 2) {
        final String p0 = parts[0].isEmpty ? 'ABC' : parts[0];
        final String p1 =
            parts[1].replaceAll('O', '0').replaceAll('I', '1');
        return '$p0-$p1';
      }
    }
    return clean;
  }

  @override
  State<TaiwanPlateQuickPad> createState() => _TaiwanPlateQuickPadState();
}

class _TaiwanPlateQuickPadState extends State<TaiwanPlateQuickPad> {
  late String _platePart;
  late String _tagPart;

  @override
  void initState() {
    super.initState();
    final String init = widget.initialValue.trim();
    final int spaceIdx = init.indexOf(' ');
    if (spaceIdx > 0) {
      _platePart =
          TaiwanPlateQuickPad.sanitizeTaiwanPlate(init.substring(0, spaceIdx));
      _tagPart = init.substring(spaceIdx + 1).trim();
    } else {
      _platePart = TaiwanPlateQuickPad.sanitizeTaiwanPlate(
        init.isEmpty ? 'ABC-1234' : init,
      );
      _tagPart = widget.isZh ? '紅線違停' : 'Red Curb';
    }
  }

  void _applyPrefix(String prefix) {
    HapticFeedback.selectionClick();
    setState(() {
      final int dashIdx = _platePart.indexOf('-');
      final String currentDigits =
          (dashIdx >= 0 && dashIdx + 1 < _platePart.length)
              ? _platePart.substring(dashIdx + 1)
              : '';
      _platePart = '$prefix$currentDigits';
    });
  }

  void _appendDigit(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      final int dashIdx = _platePart.indexOf('-');
      final String prefix =
          dashIdx >= 0 ? _platePart.substring(0, dashIdx + 1) : 'ABC-';
      final String currentDigits =
          (dashIdx >= 0 && dashIdx + 1 < _platePart.length)
              ? _platePart.substring(dashIdx + 1)
              : '';
      final String nextDigits = currentDigits.length >= 4
          ? digit
          : '$currentDigits$digit';
      _platePart = '$prefix$nextDigits';
    });
  }

  void _backspaceDigit() {
    HapticFeedback.selectionClick();
    setState(() {
      final int dashIdx = _platePart.indexOf('-');
      if (dashIdx >= 0 && dashIdx + 1 < _platePart.length) {
        _platePart = _platePart.substring(0, _platePart.length - 1);
      }
    });
  }

  String _composedPreview() {
    final String formattedPlate =
        TaiwanPlateQuickPad.sanitizeTaiwanPlate(_platePart);
    if (_tagPart.trim().isEmpty) return formattedPlate;
    return '$formattedPlate ${_tagPart.trim()}';
  }

  Widget _buildDigitGrid() {
    const List<String> digits = <String>[
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '0',
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final String d in digits)
          SizedBox(
            width: 54,
            height: 40,
            child: ElevatedButton(
              key: Key('plate_digit_btn_$d'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
              onPressed: () => _appendDigit(d),
              child: Text(
                d,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        SizedBox(
          width: 68,
          height: 40,
          child: OutlinedButton.icon(
            key: const Key('plate_backspace_btn'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFF59E0B),
              padding: EdgeInsets.zero,
              side: const BorderSide(color: Color(0xFFF59E0B)),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
            onPressed: _backspaceDigit,
            icon: const Icon(Icons.backspace_outlined, size: 16),
            label: Text(
              widget.isZh ? '退格' : 'Del',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String preview = _composedPreview();
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
                  const Icon(
                    Icons.flash_on_rounded,
                    color: Color(0xFFF59E0B),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isZh
                          ? '台灣車牌與違規態樣單手閃電快選器'
                          : 'Quick License Plate & Violation Pad',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  border: Border.all(
                    color: const Color(0xFF121212),
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      preview,
                      style: const TextStyle(
                        color: Color(0xFF121212),
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.isZh
                    ? '1. 點選車牌英文開頭 (自動防 I/O 混淆與補連字號)'
                    : '1. Select Plate Prefix (Auto Hyphen & I/O Guard)',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: TaiwanPlateQuickPad.commonPrefixes.map((String pre) {
                  final bool active = _platePart.startsWith(pre);
                  return ChoiceChip(
                    label: Text(
                      pre,
                      style: TextStyle(
                        color: active ? const Color(0xFF121212) : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                    selected: active,
                    selectedColor: const Color(0xFFF59E0B),
                    backgroundColor: const Color(0xFF1E293B),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => _applyPrefix(pre),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Text(
                widget.isZh ? '2. 單手快速輸入後四碼數字' : '2. Tap Rear 4 Digits',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              _buildDigitGrid(),
              const SizedBox(height: 10),
              Text(
                widget.isZh
                    ? '3. 一鍵附加違規事實或外勤巡檢標籤'
                    : '3. Attach Violation or Inspection Tag',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    TaiwanPlateQuickPad.quickTags.map((QuickViolationTag t) {
                  final String label = t.localizedTag(isZh: widget.isZh);
                  final bool selected = _tagPart == label;
                  return ChoiceChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        color:
                            selected ? const Color(0xFF121212) : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    selected: selected,
                    selectedColor: const Color(0xFF10B981),
                    backgroundColor: const Color(0xFF1E293B),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _tagPart = label;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('apply_plate_quick_pad_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF121212),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    widget.onApplyNote(preview);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text(
                    widget.isZh
                        ? '套用至浮水印與 110 報案 ($preview)'
                        : 'Apply to Watermark ($preview)',
                    style: const TextStyle(
                      fontSize: 14.5,
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
  }
}
