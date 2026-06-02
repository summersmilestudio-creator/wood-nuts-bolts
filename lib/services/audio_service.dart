import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight SFX player for casual games. Plays bundled WAVs from assets/sfx/.
/// Uses a small pool so rapid sounds can overlap. Respects a persisted mute toggle.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const int _poolSize = 4;
  final List<AudioPlayer> _pool = [];
  int _next = 0;
  bool _muted = false;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      final p = await SharedPreferences.getInstance();
      _muted = p.getBool('sfx_muted') ?? false;
      for (var i = 0; i < _poolSize; i++) {
        final pl = AudioPlayer(playerId: 'sfx_$i');
        await pl.setReleaseMode(ReleaseMode.stop);
        _pool.add(pl);
      }
      _ready = true;
    } catch (_) {}
  }

  bool get muted => _muted;

  Future<void> setMuted(bool m) async {
    _muted = m;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('sfx_muted', m);
    } catch (_) {}
  }

  Future<void> toggleMuted() => setMuted(!_muted);

  /// name = file in assets/sfx without extension: tap, pop, place, swap, match, coin, win, lose, error
  void play(String name, {double volume = 0.7}) {
    if (_muted || !_ready) return;
    try {
      final pl = _pool[_next];
      _next = (_next + 1) % _pool.length;
      pl.stop();
      pl.play(AssetSource('sfx/$name.wav'), volume: volume);
    } catch (_) {}
  }

  // Convenience helpers
  void tap() => play('tap', volume: 0.5);
  void pop() => play('pop');
  void place() => play('place', volume: 0.6);
  void swap() => play('swap', volume: 0.6);
  void match() => play('match');
  void coin() => play('coin');
  void win() => play('win', volume: 0.85);
  void lose() => play('lose', volume: 0.7);
  void error() => play('error', volume: 0.5);
}
