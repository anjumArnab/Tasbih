import 'package:flutter/material.dart';

class AnimatedCircleButton extends StatelessWidget {
  final Animation<double> animation;
  final VoidCallback onTap;
  final IconData icon;
  final double size;
  final double iconSize;
  final double borderWidth;
  final Color borderColor;
  final Color iconColor;
  final Color backgroundColor;

  const AnimatedCircleButton({
    super.key,
    required this.animation,
    required this.onTap,
    required this.icon,
    this.size = 80.0,
    this.iconSize = 30.0,
    this.borderWidth = 3.0,
    this.borderColor = Colors.black87,
    this.iconColor = Colors.black87,
    this.backgroundColor = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: animation.value,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: borderWidth),
              ),
              child: Icon(icon, color: iconColor, size: iconSize),
            ),
          ),
        );
      },
    );
  }
}
