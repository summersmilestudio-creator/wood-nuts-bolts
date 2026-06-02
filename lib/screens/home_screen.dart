import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import '../services/iap_service.dart';
import '../widgets/remove_ads_offer.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _level = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _level = p.getInt('level') ?? 1);
  }

  Future<void> _play() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameScreen(startLevel: _level)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8A5A2B), Color(0xFF42280F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(Icons.handyman_rounded,
                  size: 92, color: Color(0xFFFFCA3A)),
              const SizedBox(height: 16),
              const Text(
                'Wood Nuts\n& Bolts',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: Colors.black54, offset: Offset(0, 3), blurRadius: 4)
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text('Screw Puzzle',
                  style: TextStyle(color: Colors.white70, fontSize: 18, letterSpacing: 2)),
              const Spacer(),
              _bigButton(
                label: _level > 1 ? 'Continuă · Nivel $_level' : 'Joacă',
                color: const Color(0xFF8AC926),
                onTap: _play,
              ),
              const SizedBox(height: 14),
              _bigButton(
                label: 'Începe de la 1',
                color: const Color(0xFF4895EF),
                onTap: () async {
                  final p = await SharedPreferences.getInstance();
                  await p.setInt('level', 1);
                  setState(() => _level = 1);
                  _play();
                },
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: IapService.instance,
                builder: (context, _) {
                  if (IapService.instance.noAds) return const SizedBox.shrink();
                  return TextButton.icon(
                    icon: const Icon(Icons.block_rounded,
                        color: Colors.white70, size: 20),
                    label: Text(
                      'Elimină reclamele · ${IapService.instance.removeAdsPrice}',
                      style: const TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                    onPressed: () => RemoveAdsOffer.show(context),
                  );
                },
              ),
              IconButton(
                iconSize: 30,
                icon: Icon(
                  AudioService.instance.muted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: Colors.white70,
                ),
                onPressed: () async {
                  await AudioService.instance.toggleMuted();
                  setState(() {});
                },
              ),
              // Hidden debug: long-press to fire a test notification.
              GestureDetector(
                onLongPress: () =>
                    NotificationService.instance.showTestNow('Wood Nuts & Bolts'),
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('v1.0', style: TextStyle(color: Colors.white24)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bigButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 260,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 6,
        ),
        onPressed: onTap,
        child: Text(label,
            style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
