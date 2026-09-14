import 'package:flutter/material.dart';

/// Official Google "G" 4-color vector logo.
/// Conforms to Google Brand Identity Guidelines with exact vector paths.
class GoogleLogoWidget extends StatelessWidget {
  final double size;

  const GoogleLogoWidget({super.key, this.size = 20.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OfficialGoogleLogoPainter(),
        size: Size(size, size),
      ),
    );
  }
}

class _OfficialGoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 48.0;
    canvas.save();
    canvas.scale(scale, scale);

    // 1. Red segment (top arc)
    final pathRed = Path()
      ..moveTo(24.0, 9.5)
      ..cubicTo(27.54, 9.5, 30.71, 10.72, 33.21, 13.1)
      ..lineTo(40.06, 6.25)
      ..cubicTo(35.9, 2.38, 30.47, 0.0, 24.0, 0.0)
      ..cubicTo(14.62, 0.0, 6.51, 5.38, 2.55, 13.22)
      ..lineTo(10.53, 19.41)
      ..cubicTo(12.43, 13.72, 17.74, 9.5, 24.0, 9.5)
      ..close();

    // 2. Blue segment (horizontal crossbar and right arc)
    final pathBlue = Path()
      ..moveTo(46.98, 24.55)
      ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.6, 20.0)
      ..lineTo(24.0, 20.0)
      ..lineTo(24.0, 29.02)
      ..lineTo(36.94, 29.02)
      ..cubicTo(36.36, 31.98, 34.68, 34.5, 32.16, 36.2)
      ..lineTo(39.89, 42.2)
      ..cubicTo(44.4, 38.02, 46.98, 31.84, 46.98, 24.55)
      ..close();

    // 3. Yellow segment (left middle arc)
    final pathYellow = Path()
      ..moveTo(10.53, 19.41)
      ..cubicTo(10.05, 20.86, 9.77, 22.4, 9.77, 24.0)
      ..cubicTo(9.77, 25.6, 10.05, 27.14, 10.53, 28.59)
      ..lineTo(2.55, 34.78)
      ..cubicTo(0.92, 31.54, 0.0, 27.88, 0.0, 24.0)
      ..cubicTo(0.0, 20.12, 0.92, 16.46, 2.55, 13.22)
      ..lineTo(10.53, 19.41)
      ..close();

    // 4. Green segment (bottom arc)
    final pathGreen = Path()
      ..moveTo(24.0, 48.0)
      ..cubicTo(30.48, 48.0, 35.93, 45.87, 39.89, 42.2)
      ..lineTo(32.16, 36.2)
      ..cubicTo(30.01, 37.65, 27.24, 38.5, 24.0, 38.5)
      ..cubicTo(17.74, 38.5, 12.43, 34.28, 10.53, 28.59)
      ..lineTo(2.55, 34.78)
      ..cubicTo(6.51, 42.62, 14.62, 48.0, 24.0, 48.0)
      ..close();

    canvas.drawPath(
      pathRed,
      Paint()
        ..color = const Color(0xFFEA4335)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      pathBlue,
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      pathYellow,
      Paint()
        ..color = const Color(0xFFFBBC05)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      pathGreen,
      Paint()
        ..color = const Color(0xFF34A853)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
