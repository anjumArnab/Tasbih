// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class AnimatedCircleButton extends StatelessWidget {
  final Animation<double> animation;
  final VoidCallback onTap;
  final IconData icon;
  final double size;
  final double iconSize;

  const AnimatedCircleButton({
    super.key,
    required this.animation,
    required this.onTap,
    required this.icon,
    this.size = 80.0,
    this.iconSize = 30.0,
  });

  static const Color primaryColor = Color(0xFF0F4C75);
  static const Color secondaryColor = Color(0xFF3282B8);
  static const Color accentColor = Color(0xFF00A8CC);
  static const Color backgroundColor = Color(0xFFF8FBFF);

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
                gradient: const LinearGradient(
                  colors: [accentColor, secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: iconSize),
            ),
          ),
        );
      },
    );
  }
}
