import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'iap_service.dart';

class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  // Real AdMob unit IDs — AdMob app ca-app-pub-5549243085914479~8190366261.
  // iOS still uses Google test IDs until the iOS AdMob app is created.
  static const String _bannerIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const String _interstitialIOS = 'ca-app-pub-3940256099942544/4411468910';
  static const String _rewardedIOS = 'ca-app-pub-3940256099942544/1712485313';
  static const String _bannerAndroid = 'ca-app-pub-5549243085914479/6877284595';
  static const String _interstitialAndroid = 'ca-app-pub-5549243085914479/8663185155';
  static const String _rewardedAndroid = 'ca-app-pub-5549243085914479/1572987027';

  static const String _bannerTest = 'ca-app-pub-3940256099942544/6300978111';
  static const String _interstitialTest = 'ca-app-pub-3940256099942544/1033173712';
  static const String _rewardedTest = 'ca-app-pub-3940256099942544/5224354917';

  static const Duration _minInterval = Duration(seconds: 45);

  bool _initialized = false;
  InterstitialAd? _interstitial;
  bool _interstitialLoading = false;
  DateTime? _lastInterstitialShown;
  RewardedAd? _rewarded;
  bool _rewardedLoading = false;

  String get bannerUnitId {
    if (kDebugMode) return _bannerTest;
    return Platform.isIOS ? _bannerIOS : _bannerAndroid;
  }
  String get interstitialUnitId {
    if (kDebugMode) return _interstitialTest;
    return Platform.isIOS ? _interstitialIOS : _interstitialAndroid;
  }
  String get rewardedUnitId {
    if (kDebugMode) return _rewardedTest;
    return Platform.isIOS ? _rewardedIOS : _rewardedAndroid;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _loadInterstitial();
    _loadRewarded();
  }

  void _loadInterstitial() {
    if (_interstitialLoading || _interstitial != null) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) { _interstitial = ad; _interstitialLoading = false; },
        onAdFailedToLoad: (err) { _interstitial = null; _interstitialLoading = false; },
      ),
    );
  }

  /// Shows a full-screen interstitial if one is ready and the user hasn't
  /// bought "remove ads". Returns `true` only when an ad was actually shown and
  /// dismissed — the caller uses that to follow up with the remove-ads offer.
  Future<bool> maybeShowInterstitial() async {
    if (IapService.instance.noAds) return false;
    if (!_initialized) return false;
    final now = DateTime.now();
    if (_lastInterstitialShown != null &&
        now.difference(_lastInterstitialShown!) < _minInterval) return false;
    final ad = _interstitial;
    if (ad == null) { _loadInterstitial(); return false; }
    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose(); _interstitial = null;
        _lastInterstitialShown = DateTime.now(); _loadInterstitial();
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose(); _interstitial = null; _loadInterstitial();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    await ad.show();
    return completer.future;
  }

  void _loadRewarded() {
    if (_rewardedLoading || _rewarded != null) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) { _rewarded = ad; _rewardedLoading = false; },
        onAdFailedToLoad: (err) { _rewarded = null; _rewardedLoading = false; },
      ),
    );
  }

  Future<bool> showRewarded() async {
    // Paid the "remove ads" upgrade → grant the reward without an ad.
    if (IapService.instance.noAds) return true;
    if (!_initialized) return false;
    final ad = _rewarded;
    if (ad == null) { _loadRewarded(); return false; }
    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose(); _rewarded = null; _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose(); _rewarded = null; _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, __) {
      if (!completer.isCompleted) completer.complete(true);
    });
    return completer.future;
  }

  BannerAd createBanner({required AdSize size, void Function(Ad)? onLoaded}) {
    return BannerAd(
      adUnitId: bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => onLoaded?.call(ad),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    );
  }
}
