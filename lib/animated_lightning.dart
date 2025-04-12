import 'package:flutter/material.dart';
import 'dart:math';

class AnimatedLightning extends StatefulWidget {
  final double size;
  final Color color;
  final VoidCallback? onTap;

  const AnimatedLightning({
    super.key,
    this.size = 32,
    this.color = Colors.amber, // Changed to amber for better visibility
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
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 20),
    ]).animate(_controller)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onTap?.call();
        }
      });
  }

  void _triggerAnimation() {
    if (!_isAnimating) {
      setState(() => _isAnimating = true);
      _controller.reset();
      _controller.forward().then((_) {
        if (mounted) {
          setState(() => _isAnimating = false);
        }
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
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(widget.size),
        onTap: _triggerAnimation,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Transform.rotate(
            angle: -20 * (pi / 180),
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _animation.value,
                  child: CustomPaint(
                    painter: _LightningPainter(
                      color: widget.color,
                      isAnimating: _isAnimating,
                      random: _random,
                    ),
                    size: Size(widget.size, widget.size),
                  ),
                );
              },
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
      ..color = color
      ..style = PaintingStyle.fill;

    // Main lightning path - more visible version
    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.05)  // Start higher
      ..lineTo(size.width * 0.65, size.height * 0.35)
      ..lineTo(size.width * 0.5, size.height * 0.35)
      ..lineTo(size.width * 0.75, size.height * 0.95)  // Extend further
      ..lineTo(size.width * 0.5, size.height * 0.65)
      ..lineTo(size.width * 0.25, size.height * 0.65)
      ..close();

    canvas.drawPath(path, paint);

    // Enhanced electric sparks
    if (isAnimating) {
      final sparkPaint = Paint()
        // ignore: deprecated_member_use
        ..color = Colors.white.withOpacity(0.9)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // More sparks radiating from center
      for (int i = 0; i < 12; i++) {
        final startX = size.width * 0.5;
        final startY = size.height * 0.5;
        final angle = random.nextDouble() * 2 * pi;
        final length = random.nextDouble() * size.width * 0.35;
        final endX = startX + cos(angle) * length;
        final endY = startY + sin(angle) * length;
        
        // Draw main spark line
        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), sparkPaint);
        
        // Add small perpendicular lines for more electricity effect
        if (i % 2 == 0) {
          final midX = startX + cos(angle) * length * 0.5;
          final midY = startY + sin(angle) * length * 0.5;
          final perpAngle = angle + pi/2;
          final perpLength = length * 0.3;
          canvas.drawLine(
            Offset(midX, midY),
            Offset(midX + cos(perpAngle) * perpLength, midY + sin(perpAngle) * perpLength),
            sparkPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}