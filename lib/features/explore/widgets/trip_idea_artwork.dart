import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../trip_ideas.dart';

/// Minimal landscape for a trip idea, painted in the current theme's
/// colours so it follows every palette and dark mode. Decorative only.
class TripIdeaArtwork extends StatelessWidget {
  const TripIdeaArtwork({super.key, required this.art});

  final TripIdeaArt art;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _ArtPainter(art, Theme.of(context).colorScheme),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.art, this.colors);

  final TripIdeaArt art;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final sky = switch (art) {
      TripIdeaArt.sea => colors.secondaryContainer,
      TripIdeaArt.sunset => colors.tertiaryContainer,
      TripIdeaArt.temple => colors.primaryContainer,
      TripIdeaArt.city => colors.secondaryContainer,
    };
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [sky, colors.surfaceContainerLowest],
        ).createShader(rect),
    );
    switch (art) {
      case TripIdeaArt.sea:
        _sun(canvas, size, Offset(size.width * 0.74, size.height * 0.32), 0.13);
        _waves(canvas, size);
      case TripIdeaArt.sunset:
        _sun(canvas, size, Offset(size.width * 0.5, size.height * 0.62), 0.24);
        _water(canvas, size);
      case TripIdeaArt.temple:
        _sun(canvas, size, Offset(size.width * 0.8, size.height * 0.26), 0.1);
        _temple(canvas, size);
      case TripIdeaArt.city:
        _sun(canvas, size, Offset(size.width * 0.22, size.height * 0.28), 0.1);
        _skyline(canvas, size);
    }
  }

  void _sun(Canvas canvas, Size size, Offset centre, double radius) {
    canvas.drawCircle(
      centre,
      size.shortestSide * radius,
      Paint()..color = colors.tertiary.withValues(alpha: 0.85),
    );
  }

  /// Three layers of rolling waves, lighter at the back.
  void _waves(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    for (var i = 0; i < 3; i++) {
      final base = h * (0.6 + 0.13 * i);
      final amp = h * 0.035;
      final length = w / (2.2 + i * 0.4);
      final path = Path()..moveTo(0, base);
      for (var x = 0.0; x <= w + length; x += length) {
        path
          ..relativeQuadraticBezierTo(length / 4, -amp, length / 2, 0)
          ..relativeQuadraticBezierTo(length / 4, amp, length / 2, 0);
      }
      path
        ..lineTo(w + length, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = colors.primary.withValues(alpha: 0.4 + 0.3 * i),
      );
    }
  }

  /// Calm water with the low sun's reflection.
  void _water(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Rect.fromLTRB(0, h * 0.64, w, h),
      Paint()..color = colors.primary,
    );
    final reflection = Paint()
      ..color = colors.tertiaryContainer.withValues(alpha: 0.8)
      ..strokeWidth = h * 0.025
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final y = h * (0.7 + 0.07 * i);
      final half = w * (0.16 - 0.03 * i);
      canvas.drawLine(
        Offset(w / 2 - half, y),
        Offset(w / 2 + half, y),
        reflection,
      );
    }
  }

  /// A Thai temple: stacked roofs, a spire and a door, on a ground band.
  void _temple(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ground = h * 0.84;
    canvas.drawRect(
      Rect.fromLTRB(0, ground, w, h),
      Paint()..color = colors.primary,
    );
    final roof = Paint()..color = colors.primary;
    final body = Paint()..color = colors.primary.withValues(alpha: 0.7);
    canvas.drawRect(Rect.fromLTRB(w * 0.32, h * 0.6, w * 0.68, ground), body);
    for (final (left, right, eave, apex) in [
      (0.22, 0.78, 0.62, 0.42),
      (0.3, 0.7, 0.47, 0.3),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(w * left, h * eave)
          ..lineTo(w * 0.5, h * apex)
          ..lineTo(w * right, h * eave)
          ..close(),
        roof,
      );
    }
    canvas.drawLine(
      Offset(w * 0.5, h * 0.32),
      Offset(w * 0.5, h * 0.14),
      Paint()
        ..color = colors.primary
        ..strokeWidth = math.max(2, w * 0.012)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(w * 0.46, h * 0.7, w * 0.54, ground),
        topLeft: Radius.circular(w * 0.04),
        topRight: Radius.circular(w * 0.04),
      ),
      Paint()..color = colors.surfaceContainerLowest,
    );
  }

  /// Low-rise buildings with lit windows.
  void _skyline(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const heights = [0.42, 0.62, 0.5, 0.74, 0.46, 0.58, 0.38];
    final unit = w / heights.length;
    final window = Paint()
      ..color = colors.surfaceContainerLowest.withValues(alpha: 0.7);
    for (var i = 0; i < heights.length; i++) {
      final top = h * (1 - heights[i]);
      final building = Rect.fromLTRB(
        unit * i + unit * 0.08,
        top,
        unit * (i + 1) - unit * 0.08,
        h,
      );
      canvas.drawRect(
        building,
        Paint()
          ..color = (i.isEven ? colors.primary : colors.secondary).withValues(
            alpha: i.isEven ? 1 : 0.75,
          ),
      );
      for (var y = top + h * 0.06; y < h - h * 0.08; y += h * 0.1) {
        canvas.drawRect(
          Rect.fromLTWH(
            building.left + building.width * 0.3,
            y,
            building.width * 0.4,
            h * 0.035,
          ),
          window,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.art != art || old.colors != colors;
}
