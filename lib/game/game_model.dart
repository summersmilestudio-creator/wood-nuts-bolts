import 'dart:math';
import 'package:flutter/material.dart';

/// Logical board size. The view scales this to the available space.
const double kBoardW = 360;
const double kBoardH = 600;
const double kTopPad = 60; // reserved at the top of the board
const double kBottomPad = 40; // reserved at the bottom (above the buckets row)

/// Screw colors used across the game (wood-puzzle palette).
const List<Color> kScrewColors = [
  Color(0xFF2EC4B6), // teal
  Color(0xFFE71D36), // red
  Color(0xFFFF9F1C), // orange
  Color(0xFF4895EF), // blue
  Color(0xFF8AC926), // green
  Color(0xFF9B5DE5), // purple
  Color(0xFFF15BB5), // pink
  Color(0xFFFFCA3A), // yellow
];

class Screw {
  Screw({required this.id, required this.colorIndex, required this.pos});
  final int id;
  final int colorIndex;
  Offset pos; // in board coordinates
  bool removed = false;
  Color get color => kScrewColors[colorIndex];
}

class Plank {
  Plank({
    required this.id,
    required this.center,
    required this.angle,
    required this.length,
    required this.thickness,
    required this.woodIndex,
    required this.screwA,
    required this.screwB,
  });
  final int id;
  final Offset center;
  final double angle;
  final double length;
  final double thickness;
  final int woodIndex; // wood shade variation
  final Screw screwA;
  final Screw screwB;
  bool removed = false;

  bool get bothGone => screwA.removed && screwB.removed;
}

class Bucket {
  Bucket({required this.capacity});
  final int capacity;
  int? colorIndex; // null = empty/open, accepts any color
  int count = 0;
  bool get isEmpty => count == 0;
  bool get isFull => count >= capacity;
  bool accepts(int c) =>
      !isFull && (colorIndex == null || colorIndex == c);
}

enum GameStatus { playing, won, lost }

class GameModel extends ChangeNotifier {
  GameModel();

  final List<Plank> planks = [];
  final List<Screw> screws = [];
  final List<Bucket> buckets = [];

  int level = 1;
  int moves = 0;
  int cleared = 0; // buckets cleared this level
  GameStatus status = GameStatus.playing;

  static const int capacity = 4;

  int get remainingScrews => screws.where((s) => !s.removed).length;

  /// Generate a guaranteed-solvable level. Difficulty scales with [level].
  void loadLevel(int lvl) {
    level = lvl;
    moves = 0;
    cleared = 0;
    status = GameStatus.playing;
    planks.clear();
    screws.clear();
    buckets.clear();

    final rng = Random(lvl * 7919 + 13);

    // Difficulty curve.
    final int colors = (3 + (lvl ~/ 2)).clamp(3, kScrewColors.length);
    // units of `capacity` per color; more colors+units on higher levels.
    final int unitsPerColor = 1 + (lvl ~/ 5).clamp(0, 2);
    final int bucketCount = (colors <= 4 ? colors : 4) + (lvl > 8 ? 1 : 0);

    // Build the multiset of screw colors (each color a multiple of capacity).
    final List<int> bag = [];
    for (var c = 0; c < colors; c++) {
      for (var k = 0; k < unitsPerColor * capacity; k++) {
        bag.add(c);
      }
    }
    // Make it even so it pairs into planks (capacity=4 keeps it even already).
    if (bag.length.isOdd) bag.add(bag[rng.nextInt(bag.length)]);
    bag.shuffle(rng);

    // Buckets.
    for (var i = 0; i < bucketCount; i++) {
      buckets.add(Bucket(capacity: capacity));
    }

    // Create screws + planks (2 screws per plank).
    int screwId = 0;
    int plankId = 0;
    final double minX = 36, maxX = kBoardW - 36;
    final double minY = kTopPad + 30, maxY = kBoardH - kBottomPad - 30;

    for (var i = 0; i + 1 < bag.length; i += 2) {
      final double len = 120 + rng.nextDouble() * 90;
      final double thick = 26.0;
      final double angle = rng.nextDouble() * pi; // 0..180°
      final double cx = minX + rng.nextDouble() * (maxX - minX);
      final double cy = minY + rng.nextDouble() * (maxY - minY);
      final center = Offset(cx, cy);
      final half = (len - thick) / 2;
      final dir = Offset(cos(angle), sin(angle));
      var pA = center - dir * half;
      var pB = center + dir * half;
      pA = _clampToBoard(pA);
      pB = _clampToBoard(pB);

      final sA = Screw(id: screwId++, colorIndex: bag[i], pos: pA);
      final sB = Screw(id: screwId++, colorIndex: bag[i + 1], pos: pB);
      screws.add(sA);
      screws.add(sB);
      planks.add(Plank(
        id: plankId++,
        center: center,
        angle: angle,
        length: len,
        thickness: thick,
        woodIndex: rng.nextInt(3),
        screwA: sA,
        screwB: sB,
      ));
    }
    notifyListeners();
  }

  Offset _clampToBoard(Offset p) {
    return Offset(
      p.dx.clamp(28.0, kBoardW - 28),
      p.dy.clamp(kTopPad + 22, kBoardH - kBottomPad - 22),
    );
  }

  /// Try to unscrew [screw] into a bucket.
  /// Returns the bucket index it went into, or -1 if the move is illegal.
  int tapScrew(Screw screw) {
    if (status != GameStatus.playing || screw.removed) return -1;
    final target = _chooseBucket(screw.colorIndex);
    if (target == -1) return -1;

    final b = buckets[target];
    b.colorIndex ??= screw.colorIndex;
    b.count++;
    screw.removed = true;
    moves++;

    // Remove planks whose both screws are gone.
    for (final p in planks) {
      if (!p.removed && p.bothGone) p.removed = true;
    }

    // Clear full buckets.
    if (b.isFull) {
      b.colorIndex = null;
      b.count = 0;
      cleared++;
    }

    _evaluate();
    notifyListeners();
    return target;
  }

  int _chooseBucket(int colorIndex) {
    // Prefer a matching, non-empty bucket with space.
    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      if (!b.isEmpty && b.colorIndex == colorIndex && !b.isFull) return i;
    }
    // Else an empty/open bucket.
    for (var i = 0; i < buckets.length; i++) {
      if (buckets[i].isEmpty) return i;
    }
    return -1;
  }

  bool _hasLegalMove() {
    for (final s in screws) {
      if (s.removed) continue;
      if (_chooseBucket(s.colorIndex) != -1) return true;
    }
    return false;
  }

  void _evaluate() {
    if (remainingScrews == 0) {
      status = GameStatus.won;
    } else if (!_hasLegalMove()) {
      status = GameStatus.lost;
    }
  }

  /// Rewarded-ad helper: add one extra empty bucket to escape a jam.
  void addExtraBucket() {
    buckets.add(Bucket(capacity: capacity));
    if (status == GameStatus.lost) {
      status = GameStatus.playing;
    }
    notifyListeners();
  }

  int starsForMoves() {
    // Fewer moves than a generous par = more stars. (cosmetic)
    final par = screws.length;
    if (moves <= par) return 3;
    if (moves <= par * 1.3) return 2;
    return 1;
  }
}
