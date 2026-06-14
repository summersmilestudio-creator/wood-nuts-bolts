import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';
import 'screens/home_screen.dart';
import 'services/ads_service.dart';
import 'services/audio_service.dart';
import 'services/review_service.dart';
import 'services/notification_service.dart';
import 'services/iap_service.dart';
import 'widgets/remove_ads_offer.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the "remove ads" entitlement before ads init so banners/interstitials
  // are gated correctly from the very first frame.
  await IapService.instance.init();
  await AdsService.instance.initialize();
  ReviewService.instance.registerLaunch();
  AudioService.instance.init();
  NotificationService.instance.setup(
    appTitle: 'Wood Nuts & Bolts',
    messages: const [
      'Au rămas șuruburi de strâns! Hai înapoi 🔧',
      'Un puzzle rapid? Te așteaptă un nivel nou 🪛',
      'Pune mintea la treabă — deșurubează tot! 🧠',
      'Stai cu noi 2 minute și mai treci un nivel 🎯',
    ],
  );
  runApp(const NutsBoltsApp());
}

class NutsBoltsApp extends StatefulWidget {
  const NutsBoltsApp({super.key});

  @override
  State<NutsBoltsApp> createState() => _NutsBoltsAppState();
}

class _NutsBoltsAppState extends State<NutsBoltsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Show the upsell right after a full-screen ad (App Open / interstitial) closes.
    AdsService.instance.adClosedTick.addListener(_onAdClosed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AdsService.instance.adClosedTick.removeListener(_onAdClosed);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AdsService.instance.showAppOpenIfReady();
    }
  }

  void _onAdClosed() {
    RemoveAdsOffer.maybeShow(navigatorKey.currentContext);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wood Nuts & Bolts',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF9F1C),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF2A1B0E),
      ),
      home: UpgradeAlert(child: const HomeScreen()),
    );
  }
}
