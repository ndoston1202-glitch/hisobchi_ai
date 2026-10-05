import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Hisobchi logosi: doira ichida "H" va o'suvchi chiziq.
/// [progress] 0 → 1 bo'ylab logo bosqichma-bosqich chiziladi (splash animatsiyasi).
class HisobchiLogo extends StatelessWidget {
  const HisobchiLogo({super.key, this.size = 96, this.progress = 1, this.onBrand = false});

  final double size;
  final double progress;

  /// Yashil fon ustida (oq chiziqlar) yoki oddiy fonda (yashil doira ichida).
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: LogoPainter(progress: progress, filled: !onBrand)),
    );
  }
}

class LogoPainter extends CustomPainter {
  LogoPainter({required this.progress, required this.filled});

  final double progress;
  final bool filled;

  double _phase(double start, double end) => ((progress - start) / (end - start)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s / 2, s / 2);

    if (filled) {
      final bg = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF34D399), brandColor, brandDark],
        ).createShader(Offset.zero & size);
      canvas.drawCircle(center, s / 2 * Curves.easeOutBack.transform(_phase(0, 0.3)), bg);
    }

    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Halqa
    final ring = _phase(0.05, 0.45);
    if (ring > 0) {
      stroke.strokeWidth = s * 0.045;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: s * 0.38),
        -math.pi / 2,
        2 * math.pi * Curves.easeInOut.transform(ring),
        false,
        stroke..color = Colors.white.withValues(alpha: 0.9),
      );
    }

    // "H"
    stroke
      ..color = Colors.white
      ..strokeWidth = s * 0.075;
    final h = Path()
      ..moveTo(s * 0.33, s * 0.32)
      ..lineTo(s * 0.33, s * 0.68)
      ..moveTo(s * 0.33, s * 0.5)
      ..lineTo(s * 0.52, s * 0.5)
      ..moveTo(s * 0.52, s * 0.32)
      ..lineTo(s * 0.52, s * 0.68);
    _drawPartial(canvas, h, _phase(0.3, 0.7), stroke);

    // O'suvchi chiziq + strelka
    final trend = _phase(0.6, 0.95);
    if (trend > 0) {
      final gold = Paint()
        ..color = accentGold
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = s * 0.06;
      final line = Path()
        ..moveTo(s * 0.58, s * 0.66)
        ..lineTo(s * 0.64, s * 0.56)
        ..lineTo(s * 0.69, s * 0.6)
        ..lineTo(s * 0.76, s * 0.44);
      _drawPartial(canvas, line, Curves.easeOut.transform(trend), gold);
      if (trend >= 1) {
        final head = Path()
          ..moveTo(s * 0.705, s * 0.455)
          ..lineTo(s * 0.765, s * 0.43)
          ..lineTo(s * 0.785, s * 0.495);
        canvas.drawPath(head, gold);
      }
    }
  }

  void _drawPartial(Canvas canvas, Path path, double t, Paint paint) {
    if (t <= 0) return;
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
    var remaining = total * t;
    for (final PathMetric m in metrics) {
      if (remaining <= 0) break;
      final len = math.min(remaining, m.length);
      canvas.drawPath(m.extractPath(0, len), paint);
      remaining -= len;
    }
  }

  @override
  bool shouldRepaint(LogoPainter old) => old.progress != progress || old.filled != filled;
}
