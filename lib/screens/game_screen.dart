import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/game_model.dart';
import '../services/ads_service.dart';
import '../services/audio_service.dart';
import '../widgets/board_painter.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/remove_ads_offer.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.startLevel});
  final int startLevel;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameModel model = GameModel();
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    model.loadLevel(widget.startLevel);
    model.addListener(_onChange);
  }

  @override
  void dispose() {
    model.removeListener(_onChange);
    model.dispose();
    super.dispose();
  }

  void _onChange() {
    if (model.status == GameStatus.won && !_dialogOpen) {
      _dialogOpen = true;
      AudioService.instance.win();
      Future.delayed(const Duration(milliseconds: 350), _showWin);
    } else if (model.status == GameStatus.lost && !_dialogOpen) {
      _dialogOpen = true;
      AudioService.instance.lose();
      Future.delayed(const Duration(milliseconds: 250), _showLose);
    }
  }

  int _onTapScrew(Screw s) {
    final target = model.tapScrew(s);
    if (target == -1) {
      AudioService.instance.error();
    } else {
      AudioService.instance.pop();
    }
    return target;
  }

  Future<void> _showWin() async {
    if (!mounted) return;
    final adShown = await AdsService.instance.maybeShowInterstitial();
    if (!mounted) return;
    // Right after the full-screen ad, offer to remove ads for good.
    if (adShown) {
      await RemoveAdsOffer.maybeShowAfterAd(context);
      if (!mounted) return;
    }
    final stars = model.starsForMoves();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
        title: 'Nivel rezolvat! 🎉',
        accent: const Color(0xFF8AC926),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (i) => Icon(Icons.star_rounded,
                size: 44,
                color: i < stars
                    ? const Color(0xFFFFCA3A)
                    : Colors.white24),
          ),
        ),
        primaryLabel: 'Nivelul ${model.level + 1}',
        onPrimary: () async {
          Navigator.pop(context);
          _dialogOpen = false;
          setState(() => model.loadLevel(model.level + 1));
          final p = await SharedPreferences.getInstance();
          await p.setInt('level', model.level);
        },
        secondaryLabel: 'Reia',
        onSecondary: () {
          Navigator.pop(context);
          _dialogOpen = false;
          setState(() => model.loadLevel(model.level));
        },
      ),
    );
  }

  Future<void> _showLose() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
        title: 'Blocat! 😅',
        accent: const Color(0xFFE71D36),
        child: const Text(
          'Toate cutiile sunt pline. Adaugă o cutie liberă sau reia nivelul.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        primaryLabel: '➕ Cutie extra (reclamă)',
        onPrimary: () async {
          final ok = await AdsService.instance.showRewarded();
          if (!mounted) return;
          Navigator.pop(context);
          _dialogOpen = false;
          if (ok) {
            model.addExtraBucket();
          } else {
            setState(() => model.loadLevel(model.level));
          }
        },
        secondaryLabel: 'Reia nivelul',
        onSecondary: () {
          Navigator.pop(context);
          _dialogOpen = false;
          setState(() => model.loadLevel(model.level));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A1B0E),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: kBoardW,
                      height: kBoardH,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CustomPaint(
                            size: const Size(kBoardW, kBoardH),
                            painter:
                                BoardPainter(planks: model.planks, repaint: model),
                          ),
                          for (final s in model.screws)
                            _AnimatedScrew(
                              key: ValueKey(s.id),
                              screw: s,
                              model: model,
                              onTap: _onTapScrew,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _bucketsRow(),
            const SizedBox(height: 6),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: model,
            builder: (_, __) => Text(
              'Nivel ${model.level}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => setState(() => model.loadLevel(model.level)),
          ),
          IconButton(
            icon: Icon(
              AudioService.instance.muted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              color: Colors.white,
            ),
            onPressed: () async {
              await AudioService.instance.toggleMuted();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _bucketsRow() {
    return AnimatedBuilder(
      animation: model,
      builder: (_, __) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final b in model.buckets)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: BucketView(bucket: b),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tappable screw that animates its own exit (when removed) and shakes on an
/// illegal tap — without being rebuilt away by the model.
class _AnimatedScrew extends StatefulWidget {
  const _AnimatedScrew({
    super.key,
    required this.screw,
    required this.model,
    required this.onTap,
  });
  final Screw screw;
  final GameModel model;
  final int Function(Screw) onTap;

  @override
  State<_AnimatedScrew> createState() => _AnimatedScrewState();
}

class _AnimatedScrewState extends State<_AnimatedScrew>
    with TickerProviderStateMixin {
  late final AnimationController _exit = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 230));
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320));
  static const double _size = 30;

  @override
  void initState() {
    super.initState();
    widget.model.addListener(_check);
  }

  void _check() {
    if (widget.screw.removed && _exit.isDismissed) {
      _exit.forward();
    }
  }

  @override
  void dispose() {
    widget.model.removeListener(_check);
    _exit.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.screw.removed) return;
    final r = widget.onTap(widget.screw);
    if (r == -1) {
      _shake.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.screw;
    return AnimatedBuilder(
      animation: Listenable.merge([_exit, _shake]),
      builder: (context, _) {
        final exitT = Curves.easeIn.transform(_exit.value);
        final scale = 1.0 - exitT;
        final rot = exitT * pi * 2; // spin out like unscrewing
        final shakeX = sin(_shake.value * pi * 6) * (1 - _shake.value) * 6;
        if (s.removed && _exit.isCompleted) {
          return const SizedBox.shrink();
        }
        return Positioned(
          left: s.pos.dx - _size / 2 + shakeX,
          top: s.pos.dy - _size / 2,
          child: Opacity(
            opacity: (1.0 - exitT).clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: rot,
              child: Transform.scale(
                scale: scale,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleTap,
                  child: ScrewView(color: s.color, size: _size),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({
    required this.title,
    required this.accent,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });
  final String title;
  final Color accent;
  final Widget child;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF3A2614),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: TextStyle(
                    color: accent,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            child,
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: onPrimary,
                child: Text(primaryLabel,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel,
                    style: const TextStyle(color: Colors.white70)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
