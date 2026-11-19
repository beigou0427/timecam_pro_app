import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
class StorekitIapService {
  const StorekitIapService._();
  static bool get isTest => kIsWeb ||
      Platform.environment.containsKey(
        'FLUTTER_TEST');
  static Future<String?> buy(String id) async {
    if (isTest) return null;
    final iap = InAppPurchase.instance;
    if (await iap.isAvailable() == false) {
      return 'Store Unavailable';
    }
    final r = await iap
        .queryProductDetails(<String>{id});
    if (r.productDetails.isEmpty) {
      return 'SKU Not Found';
    }
    final p = PurchaseParam(
      productDetails: r.productDetails.first);
    await iap.buyNonConsumable(purchaseParam: p);
    return null;
  }

  static StreamSubscription<Object>? _sub;
  static VoidCallback? _onOk;
  static void bind(VoidCallback onOk) {
    _onOk = onOk;
    if (isTest || _sub is Object) return;
    final i = InAppPurchase.instance;
    _sub = i.purchaseStream.listen((ls) async {
    for (final d in ls) { final s = d.status;
      if (s == PurchaseStatus.purchased) _onOk?.call();
      if (s == PurchaseStatus.restored) _onOk?.call();
      if (d.pendingCompletePurchase) {
        await i.completePurchase(d);}}});}
  static Future<String?> restore() async {
    if (isTest) return null;
    final i = InAppPurchase.instance;
    if (await i.isAvailable()) {
      await i.restorePurchases(); return null;}
    return 'Store Unavailable';}
  static Future<String?> go(bool r, String id) => r ? restore() : buy(id);}
