import 'package:flutter/material.dart';
import 'dart:math';

class AnimatedLightning extends StatefulWidget {
  final double size;
  final Color color;
  final VoidCallback? onTap;

  const AnimatedLightning({
    super.key,
    this.size = 32,
    this.color = Colors.yellow,
    this.onTap,
  });

  @override
  State<AnimatedLightning> createState() => _AnimatedLightningState();
}

class _AnimatedLightningState extends State<AnimatedLightning> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isAnimating = false;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.8), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.0), weight: 20),
    ]).animate(_controller);
  }

  void _triggerAnimation() {
    if (!_isAnimating) {
      setState(() => _isAnimating = true);
      _controller.reset();
      _controller.forward().then((_) {
        setState(() => _isAnimating = false);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _triggerAnimation();
        widget.onTap?.call();
      },
      child: RotationTransition(
        turns: AlwaysStoppedAnimation(-20 / 360), // Slight diagonal tilt
        child: ScaleTransition(
          scale: _animation,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _LightningPainter(
              color: widget.color,
              isAnimating: _isAnimating,
              random: _random,
            ),
          ),
        ),
      ),
    );
  }
}

class _LightningPainter extends CustomPainter {
  final Color color;
  final bool isAnimating;
  final Random random;

  _LightningPainter({
    required this.color,
    required this.isAnimating,
    required this.random,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color,
          Colors.white,
          color,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    // Main lightning path
    final path = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width * 0.7, size.height * 0.4)
      ..lineTo(size.width * 0.5, size.height * 0.4)
      ..lineTo(size.width * 0.8, size.height)
      ..lineTo(size.width * 0.5, size.height * 0.6)
      ..lineTo(size.width * 0.3, size.height * 0.6)
      ..close();

    canvas.drawPath(path, paint);

    // Add electric sparks when animating
    if (isAnimating) {
      final sparkPaint = Paint()
        // ignore: deprecated_member_use
        ..color = Colors.white.withOpacity(0.7)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < 8; i++) {
        final startX = size.width * (0.4 + random.nextDouble() * 0.2);
        final startY = size.height * (0.3 + random.nextDouble() * 0.4);
        final endX = startX + (random.nextDouble() * 10 - 5);
        final endY = startY + (random.nextDouble() * 10 - 5);

        canvas.drawLine(
          Offset(startX, startY),
          Offset(endX, endY),
          sparkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}