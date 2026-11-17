import 'package:flutter/foundation.dart';

enum ExpenseClaimCategory {
  solarInspection(labelZh: '太陽能案場巡檢存證費', labelEn: 'Solar Field Inspection Software'),
  constructionAudit(labelZh: '營造工程驗收影像授權', labelEn: 'Construction Audit License'),
  fleetLogistics(labelZh: '物流車隊簽收存證系統', labelEn: 'Fleet Delivery Proof License'),
  trafficDocumentation(labelZh: '公務行車安全存證軟體', labelEn: 'Fleet Safety Documentation');

  const ExpenseClaimCategory({required this.labelZh, required this.labelEn});
  final String labelZh;
  final String labelEn;
  String localizedLabel({required bool isZh}) => isZh ? labelZh : labelEn;
}

@immutable
class ExpenseReceiptVoucher {
  const ExpenseReceiptVoucher({
    required this.companyName,
    required this.taxId8Digits,
    required this.projectCode,
    required this.amountNtd,
    required this.issuedDateUtc8,
    required this.category,
  });
  final String companyName;
  final String taxId8Digits;
  final String projectCode;
  final int amountNtd;
  final String issuedDateUtc8;
  final ExpenseClaimCategory category;
}

class LemkinExpenseReceiptEngine {
  const LemkinExpenseReceiptEngine._();
  static const int taiwanTaxIdLength = 8;

  static const List<int> _taxWeights = <int>[1, 2, 1, 2, 1, 2, 4, 1];

  static bool isValidTaiwanTaxId(String rawTaxId) {
    final String clean = rawTaxId.trim();
    if (!RegExp(r'^\d{8}$').hasMatch(clean) || clean == '00000000') {
      return false;
    }
    int sum = 0;
    for (int i = 0; i < 8; i++) {
      final int prod = int.parse(clean[i]) * _taxWeights[i];
      sum += (prod ~/ 10) + (prod % 10);
    }
    if (sum % 5 == 0) return true;
    return clean[6] == '7' && (sum - 9) % 5 == 0;
  }

  static ExpenseReceiptVoucher createVoucher({
    required String companyName,
    required String taxId8Digits,
    required String projectCode,
    required int amountNtd,
    required String issuedDateUtc8,
    required ExpenseClaimCategory category,
  }) {
    return ExpenseReceiptVoucher(
      companyName: companyName.trim().isEmpty ? '合作工程行' : companyName.trim(),
      taxId8Digits: taxId8Digits.trim(),
      projectCode: projectCode.trim().isEmpty ? 'PRJ-2026' : projectCode.trim(),
      amountNtd: amountNtd.clamp(1, 999999),
      issuedDateUtc8: issuedDateUtc8.trim(),
      category: category,
    );
  }

  static String buildReimbursementMemo(
    ExpenseReceiptVoucher voucher, {
    required bool isZh,
  }) {
    final bool taxValid = isValidTaiwanTaxId(voucher.taxId8Digits);
    final String taxStatus = taxValid
        ? voucher.taxId8Digits
        : (isZh ? '${voucher.taxId8Digits} (格式待確認)' : '${voucher.taxId8Digits} (Unverified)');
    if (isZh) {
      return '【公司工程軟體費用核銷明細】\n'
          '・報帳抬頭：${voucher.companyName}\n'
          '・統一編號：$taxStatus\n'
          '・專案案號：${voucher.projectCode}\n'
          '・核銷科目：${voucher.category.localizedLabel(isZh: true)}\n'
          '・核銷金額：NT\$${voucher.amountNtd}（請併附 Apple 官方電子收據）\n'
          '・開立日期：${voucher.issuedDateUtc8}';
    }
    return '[Corporate Software Reimbursement Memo]\n'
        '- Company: ${voucher.companyName}\n'
        '- Tax ID: $taxStatus\n'
        '- Project Code: ${voucher.projectCode}\n'
        '- Expense Category: ${voucher.category.localizedLabel(isZh: false)}\n'
        '- Amount: NT\$${voucher.amountNtd} (Attach Apple App Store Receipt)\n'
        '- Issue Date: ${voucher.issuedDateUtc8}';
  }
}
