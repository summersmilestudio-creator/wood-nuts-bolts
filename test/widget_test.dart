// Basic smoke test for Wood Nuts & Bolts.
import 'package:flutter_test/flutter_test.dart';

import 'package:nuts_bolts/game/game_model.dart';

void main() {
  test('level generation has clearable color counts', () {
    final m = GameModel();
    m.loadLevel(1);
    expect(m.screws.isNotEmpty, true);
    expect(m.planks.isNotEmpty, true);
    expect(m.buckets.isNotEmpty, true);
    final counts = <int, int>{};
    for (final s in m.screws) {
      counts[s.colorIndex] = (counts[s.colorIndex] ?? 0) + 1;
    }
    for (final c in counts.values) {
      expect(c % GameModel.capacity, 0);
    }
  });
}
