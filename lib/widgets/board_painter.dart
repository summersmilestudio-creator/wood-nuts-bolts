import 'package:flutter/material.dart';
import '../game/game_model.dart';

/// Paints the wooden board background and all the colored planks.
/// Screws are drawn as separate tappable widgets on top.
class BoardPainter extends CustomPainter {
  BoardPainter({required this.planks, required this.repaint})
      : super(repaint: repaint);
  final List<Plank> planks;
  final Listenable repaint;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    for (final p in planks) {
      if (p.removed) continue;
      _paintPlank(canvas, p);
    }
  }

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE3B778), Color(0xFFCB9A5C)],
      ).createShader(rect);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    canvas.drawRRect(rr, bg);

    // Subtle horizontal grain lines.
    final grain = Paint()
      ..color = const Color(0x16000000)
      ..strokeWidth = 1;
    for (double y = 16; y < size.height; y += 22) {
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), grain);
    }
    // Inner border.
    canvas.drawRRect(
      rr.deflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0x33000000),
    );
  }

  void _paintPlank(Canvas canvas, Plank p) {
    canvas.save();
    canvas.translate(p.center.dx, p.center.dy);
    canvas.rotate(p.angle);

    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset.zero, width: p.length, height: p.thickness),
      Radius.circular(p.thickness / 2),
    );

    // Drop shadow for depth (overlapping planks).
    canvas.drawRRect(
      r.shift(const Offset(0, 3)),
      Paint()
        ..color = const Color(0x44000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    final shades = _woodShades[p.woodIndex % _woodShades.length];
    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: shades,
      ).createShader(r.outerRect);
    canvas.drawRRect(r, body);

    // Highlight stripe.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: const Offset(0, -1),
            width: p.length - 10,
            height: p.thickness * 0.35),
        Radius.circular(p.thickness),
      ),
      Paint()..color = const Color(0x33FFFFFF),
    );

    // Grain ticks along the plank.
    final tick = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;
    final n = (p.length / 14).floor();
    for (var i = 1; i < n; i++) {
      final x = -p.length / 2 + i * 14;
      canvas.drawLine(Offset(x, -p.thickness * 0.3),
          Offset(x + 4, p.thickness * 0.3), tick);
    }

    // Outline.
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x55000000),
    );
    canvas.restore();
  }

  // Warm wood tones with light variation per plank.
  static const List<List<Color>> _woodShades = [
    [Color(0xFFB9844F), Color(0xFF9A6536)],
    [Color(0xFFC79257), Color(0xFFA9733E)],
    [Color(0xFFAD7A48), Color(0xFF8C5C30)],
  ];

  @override
  bool shouldRepaint(covariant BoardPainter old) => old.planks != planks;
}

/// A single colored screw head, drawn with a CustomPaint inside a tappable box.
class ScrewView extends StatelessWidget {
  const ScrewView({super.key, required this.color, this.size = 30});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _ScrewPainter(color));
  }
}

class _ScrewPainter extends CustomPainter {
  _ScrewPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.width / 2;

    canvas.drawCircle(
      c + const Offset(0, 1.5),
      radius,
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Metal rim.
    canvas.drawCircle(c, radius, Paint()..color = const Color(0xFF3A3A3A));
    // Colored head.
    canvas.drawCircle(
      c,
      radius - 2.5,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            Color.lerp(color, Colors.white, 0.45)!,
            color,
            Color.lerp(color, Colors.black, 0.25)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: radius)),
    );

    // Phillips cross slot.
    final slot = Paint()
      ..color = const Color(0x66000000)
      ..strokeWidth = radius * 0.22
      ..strokeCap = StrokeCap.round;
    final a = radius * 0.5;
    canvas.drawLine(c + Offset(-a, 0), c + Offset(a, 0), slot);
    canvas.drawLine(c + Offset(0, -a), c + Offset(0, a), slot);

    // Glossy highlight.
    canvas.drawCircle(
      c + Offset(-radius * 0.3, -radius * 0.35),
      radius * 0.22,
      Paint()..color = const Color(0x66FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _ScrewPainter old) => old.color != color;
}

/// A bottom bucket / nut-holder showing stacked screws.
class BucketView extends StatelessWidget {
  const BucketView({super.key, required this.bucket});
  final Bucket bucket;

  @override
  Widget build(BuildContext context) {
    final color = bucket.colorIndex == null
        ? const Color(0xFF6B4E2E)
        : kScrewColors[bucket.colorIndex!];
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF5A3D22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A2614), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(bucket.capacity, (i) {
          final idx = bucket.capacity - 1 - i; // fill from bottom
          final isFilled = idx < bucket.count;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: isFilled
                ? ScrewView(color: color, size: 22)
                : Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A2614),
                      shape: BoxShape.circle,
                    ),
                  ),
          );
        }),
      ),
    );
  }
}
