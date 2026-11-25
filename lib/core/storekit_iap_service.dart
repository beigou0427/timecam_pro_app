import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class StorekitIapService {
  const StorekitIapService._();

  static bool get isTest =>
      kIsWeb || Platform.environment.containsKey('FLUTTER_TEST');

  static StreamSubscription<List<PurchaseDetails>>? _sub;
  static void Function(String productId, bool isRestore)? _onPurchaseEvent;
  static void Function(String message)? _onError;
  static VoidCallback? _onCanceled;
  static final Map<String, ProductDetails> _cachedProducts =
      <String, ProductDetails>{};

  static Map<String, ProductDetails> get cachedProducts =>
      Map<String, ProductDetails>.unmodifiable(_cachedProducts);

  /// 僅轉發購買/恢復事件至 StoreKit 2 驗證，禁止未驗權直接解鎖
  static void initialize({
    required void Function(String productId, bool isRestore) onPurchaseEvent,
    void Function(String message)? onError,
    VoidCallback? onCanceled,
  }) {
    _onPurchaseEvent = onPurchaseEvent;
    _onError = onError;
    _onCanceled = onCanceled;
    if (isTest || _sub != null) return;

    final InAppPurchase iap = InAppPurchase.instance;
    _sub = iap.purchaseStream.listen(
      (List<PurchaseDetails> purchases) async {
        for (final PurchaseDetails details in purchases) {
          switch (details.status) {
            case PurchaseStatus.purchased:
              _onPurchaseEvent?.call(details.productID, false);
            case PurchaseStatus.restored:
              _onPurchaseEvent?.call(details.productID, true);
            case PurchaseStatus.error:
              _onError?.call(
                details.error?.message ?? 'Purchase failed. Please try again.',
              );
            case PurchaseStatus.canceled:
              _onCanceled?.call();
            case PurchaseStatus.pending:
              break;
          }
          if (details.pendingCompletePurchase) {
            try {
              await iap.completePurchase(details);
            } catch (e) {
              debugPrint('[StorekitIapService] completePurchase error: $e');
            }
          }
        }
      },
      onError: (Object err) {
        debugPrint('[StorekitIapService] purchaseStream error: $err');
        _onError?.call(err.toString());
      },
    );
  }

  static void setUiCallbacks({
    void Function(String message)? onError,
    VoidCallback? onCanceled,
  }) {
    _onError = onError;
    _onCanceled = onCanceled;
  }

  static Future<Map<String, ProductDetails>> fetchProducts(
    Set<String> productIds,
  ) async {
    if (isTest) return <String, ProductDetails>{};
    try {
      final InAppPurchase iap = InAppPurchase.instance;
      if (!await iap.isAvailable()) return <String, ProductDetails>{};
      final ProductDetailsResponse resp =
          await iap.queryProductDetails(productIds);
      for (final ProductDetails p in resp.productDetails) {
        _cachedProducts[p.id] = p;
      }
      return Map<String, ProductDetails>.unmodifiable(_cachedProducts);
    } catch (e) {
      debugPrint('[StorekitIapService] fetchProducts error: $e');
      return Map<String, ProductDetails>.unmodifiable(_cachedProducts);
    }
  }

  static Future<String?> buy(String productId) async {
    if (isTest) return null;
    try {
      final InAppPurchase iap = InAppPurchase.instance;
      if (!await iap.isAvailable()) {
        return 'App Store Unavailable';
      }
      ProductDetails? details = _cachedProducts[productId];
      if (details == null) {
        final ProductDetailsResponse resp =
            await iap.queryProductDetails(<String>{productId});
        if (resp.productDetails.isEmpty) {
          return 'Product unavailable ($productId)';
        }
        details = resp.productDetails.first;
        _cachedProducts[productId] = details;
      }
      final PurchaseParam param = PurchaseParam(productDetails: details);
      await iap.buyNonConsumable(purchaseParam: param);
      return null;
    } catch (e) {
      debugPrint('[StorekitIapService] buy error: $e');
      return e.toString();
    }
  }

  static Future<String?> restore() async {
    if (isTest) return null;
    try {
      final InAppPurchase iap = InAppPurchase.instance;
      if (!await iap.isAvailable()) {
        return 'App Store Unavailable';
      }
      await iap.restorePurchases();
      return null;
    } catch (e) {
      debugPrint('[StorekitIapService] restore error: $e');
      return e.toString();
    }
  }

  static Future<String?> go(bool isRestore, String productId) =>
      isRestore ? restore() : buy(productId);
}
