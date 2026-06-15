import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'iap_service.dart';

class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  // Real AdMob unit IDs — Android app ~8190366261, iOS app ~6473408576 (creat 2026-06-15).
  static const String _bannerIOS = 'ca-app-pub-5549243085914479/8716428532';
  static const String _interstitialIOS = 'ca-app-pub-5549243085914479/6090265191';
  static const String _rewardedIOS = 'ca-app-pub-5549243085914479/4777183520';
  static const String _bannerAndroid = 'ca-app-pub-5549243085914479/6877284595';
  static const String _interstitialAndroid = 'ca-app-pub-5549243085914479/8663185155';
  static const String _rewardedAndroid = 'ca-app-pub-5549243085914479/1572987027';

  // Rewarded Interstitial — cel mai mare eCPM (~11€). iOS real (2026-06-15).
  // Android nu are încă unitate → null (nu se încarcă, fallback la rewarded).
  static const String _rewardedInterstitialIOS = 'ca-app-pub-5549243085914479/3069391749';
  static const String _rewardedInterstitialTest = 'ca-app-pub-3940256099942544/5354046379';

  // App Open (highest-value launch/return ad). iOS real (2026-06-15); Android încă placeholder.
  static const String _appOpenProdAndroid = 'ca-app-pub-5549243085914479/APPOPEN_ANDROID';
  static const String _appOpenProdIOS = 'ca-app-pub-5549243085914479/9331547765';

  static const String _bannerTest = 'ca-app-pub-3940256099942544/6300978111';
  static const String _interstitialTest = 'ca-app-pub-3940256099942544/1033173712';
  static const String _rewardedTest = 'ca-app-pub-3940256099942544/5224354917';
  static const String _appOpenTestAndroid = 'ca-app-pub-3940256099942544/9257395921';
  static const String _appOpenTestIOS = 'ca-app-pub-3940256099942544/5575463023';

  static const Duration _minInterval = Duration(seconds: 34);
  static const Duration _appOpenMaxAge = Duration(hours: 4);
  static const Duration _rewIntCooldown = Duration(minutes: 2);

  bool _initialized = false;
  InterstitialAd? _interstitial;
  bool _interstitialLoading = false;
  DateTime? _lastInterstitialShown;
  RewardedAd? _rewarded;
  bool _rewardedLoading = false;
  RewardedInterstitialAd? _rewardedInterstitial;
  bool _rewardedInterstitialLoading = false;
  DateTime? _lastRewIntShown;
  AppOpenAd? _appOpen;
  bool _appOpenLoading = false;
  DateTime? _appOpenLoadTime;
  bool _showingFullScreenAd = false;

  /// Bumped whenever a full-screen ad (App Open or interstitial) closes, so the
  /// UI can offer the "Remove ads" upsell right after.
  final ValueNotifier<int> adClosedTick = ValueNotifier(0);
  void _notifyAdClosed() => adClosedTick.value++;

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
  String get appOpenUnitId {
    if (kDebugMode) return Platform.isIOS ? _appOpenTestIOS : _appOpenTestAndroid;
    return Platform.isIOS ? _appOpenProdIOS : _appOpenProdAndroid;
  }
  String? get rewardedInterstitialUnitId {
    if (kDebugMode) return _rewardedInterstitialTest;
    return Platform.isIOS ? _rewardedInterstitialIOS : null;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _loadInterstitial();
    _loadRewarded();
    _loadRewardedInterstitial();
    loadAppOpen();
  }

  void loadAppOpen() {
    if (_appOpenLoading || _appOpen != null) return;
    _appOpenLoading = true;
    AppOpenAd.load(
      adUnitId: appOpenUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpen = ad;
          _appOpenLoadTime = DateTime.now();
          _appOpenLoading = false;
        },
        onAdFailedToLoad: (err) {
          _appOpen = null;
          _appOpenLoading = false;
        },
      ),
    );
  }

  bool get _appOpenValid =>
      _appOpen != null &&
      _appOpenLoadTime != null &&
      DateTime.now().difference(_appOpenLoadTime!) < _appOpenMaxAge;

  /// Shows the App Open ad on app foreground if one is ready. Skips when ads are
  /// removed, another full-screen ad is showing, or none is loaded (then preloads).
  Future<void> showAppOpenIfReady() async {
    if (!_initialized || IapService.instance.noAds) return;
    if (_showingFullScreenAd) return;
    if (!_appOpenValid) {
      loadAppOpen();
      return;
    }
    final ad = _appOpen!;
    _appOpen = null;
    _showingFullScreenAd = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _showingFullScreenAd = false;
        loadAppOpen();
        _notifyAdClosed();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _showingFullScreenAd = false;
        loadAppOpen();
      },
    );
    await ad.show();
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
    _showingFullScreenAd = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose(); _interstitial = null;
        _showingFullScreenAd = false;
        _lastInterstitialShown = DateTime.now(); _loadInterstitial();
        _notifyAdClosed();
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose(); _interstitial = null;
        _showingFullScreenAd = false;
        _loadInterstitial();
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
    _showingFullScreenAd = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose(); _rewarded = null;
        _showingFullScreenAd = false;
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose(); _rewarded = null;
        _showingFullScreenAd = false;
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, __) {
      if (!completer.isCompleted) completer.complete(true);
    });
    return completer.future;
  }

  // ---- Rewarded Interstitial (eCPM cel mai mare) ----------------------------
  void _loadRewardedInterstitial() {
    final id = rewardedInterstitialUnitId;
    if (id == null) return;
    if (_rewardedInterstitialLoading || _rewardedInterstitial != null) return;
    _rewardedInterstitialLoading = true;
    RewardedInterstitialAd.load(
      adUnitId: id,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) { _rewardedInterstitial = ad; _rewardedInterstitialLoading = false; },
        onAdFailedToLoad: (err) { _rewardedInterstitial = null; _rewardedInterstitialLoading = false; },
      ),
    );
  }

  bool get _rewIntReady => _rewardedInterstitial != null;
  bool get _rewIntOffCooldown =>
      _lastRewIntShown == null ||
      DateTime.now().difference(_lastRewIntShown!) >= _rewIntCooldown;

  Future<bool> _showRewardedInterstitial() async {
    final ad = _rewardedInterstitial;
    if (ad == null) { _loadRewardedInterstitial(); return false; }
    final completer = Completer<bool>();
    _showingFullScreenAd = true;
    _lastRewIntShown = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose(); _rewardedInterstitial = null;
        _showingFullScreenAd = false;
        _loadRewardedInterstitial();
        _notifyAdClosed();
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose(); _rewardedInterstitial = null;
        _showingFullScreenAd = false;
        _loadRewardedInterstitial();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, __) {
      if (!completer.isCompleted) completer.complete(true);
    });
    return completer.future;
  }

  /// Recompensă opt-in: preferă Rewarded Interstitial (eCPM mult mai mare) când
  /// e disponibil și off-cooldown, altfel cade pe Rewarded normal. Apelat doar
  /// din butoane „vezi reclamă" => conform politicii AdMob.
  Future<bool> showBonusAd() async {
    // Paid the "remove ads" upgrade → grant the reward without an ad.
    if (IapService.instance.noAds) return true;
    if (!_showingFullScreenAd && _rewIntReady && _rewIntOffCooldown) {
      return _showRewardedInterstitial();
    }
    return showRewarded();
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
