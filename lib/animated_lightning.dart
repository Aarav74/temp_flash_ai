import 'package:flutter/material.dart';

class AnimatedLightning extends StatefulWidget {
  final double size;
  final Color color;
  
  const AnimatedLightning({
    super.key,
    this.size = 32,
    this.color = Colors.yellow,
  });

  @override
  State<AnimatedLightning> createState() => _AnimatedLightningState();
}

class _AnimatedLightningState extends State<AnimatedLightning> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: LightningIcon(
        size: widget.size,
        color: widget.color,
      ),
    );
  }
}

class LightningIcon extends StatelessWidget {
  final double size;
  final Color color;

  const LightningIcon({
    super.key,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.flash_on,
      size: size,
      color: color,
    );
  }
} 
