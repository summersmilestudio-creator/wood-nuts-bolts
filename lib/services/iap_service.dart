import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-time "Remove ads" purchase (15 lei).
///
/// The entitlement is a non-consumable managed product. We mirror its state
/// into SharedPreferences so the game can hide ads instantly on the next launch
/// without waiting for the store, and we still reconcile with the real store
/// entitlement (via restore + the purchase stream) so a reinstall keeps it.
class IapService extends ChangeNotifier {
  IapService._();
  static final IapService instance = IapService._();

  /// Must match the managed product id created in Play Console / App Store.
  static const String removeAdsId = 'remove_ads';
  static const String _prefKey = 'no_ads_purchased';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _removeAdsProduct;
  bool _available = false;
  bool _noAds = false;
  bool _purchasePending = false;

  /// True once the user owns the "remove ads" entitlement.
  bool get noAds => _noAds;
  bool get storeAvailable => _available;
  bool get purchasePending => _purchasePending;

  /// Localised price the store returned (e.g. "15,00 RON"); falls back to a
  /// hard-coded label before the store responds or on desktop/test.
  String get removeAdsPrice => _removeAdsProduct?.price ?? '15 lei';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _noAds = prefs.getBool(_prefKey) ?? false;
    notifyListeners();

    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      _available = await _iap.isAvailable();
    } catch (_) {
      _available = false;
    }
    if (!_available) return;

    await _sub?.cancel();
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (e) {
        if (kDebugMode) debugPrint('purchaseStream error: $e');
      },
    );

    await _loadProducts();
    // Silently reconcile a previous purchase (e.g. after reinstall).
    try {
      await _iap.restorePurchases();
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
    try {
      final resp = await _iap.queryProductDetails({removeAdsId});
      if (resp.productDetails.isNotEmpty) {
        _removeAdsProduct = resp.productDetails.first;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('queryProductDetails failed: $e');
    }
  }

  /// Kicks off the native purchase flow. Result arrives via [_onPurchaseUpdates].
  Future<void> buyRemoveAds() async {
    if (_noAds || _purchasePending) return;
    if (_removeAdsProduct == null) await _loadProducts();
    final product = _removeAdsProduct;
    if (product == null) return;
    _purchasePending = true;
    notifyListeners();
    try {
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      _purchasePending = false;
      notifyListeners();
      if (kDebugMode) debugPrint('buyNonConsumable failed: $e');
    }
  }

  /// "Restore purchases" — required by App Store review guidelines.
  Future<void> restore() async {
    if (!_available) return;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      if (kDebugMode) debugPrint('restore failed: $e');
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID == removeAdsId) {
        switch (p.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            await _grantNoAds();
            break;
          case PurchaseStatus.error:
          case PurchaseStatus.canceled:
            _purchasePending = false;
            notifyListeners();
            break;
          case PurchaseStatus.pending:
            _purchasePending = true;
            notifyListeners();
            break;
        }
      }
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (_) {}
      }
    }
  }

  Future<void> _grantNoAds() async {
    _purchasePending = false;
    if (_noAds) {
      notifyListeners();
      return;
    }
    _noAds = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
    notifyListeners();
  }
}
