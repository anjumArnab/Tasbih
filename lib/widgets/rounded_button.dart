import 'package:flutter/material.dart';

class RoundedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double borderRadius;
  final Color textColor;

  static const Color accentColor = Color(0xFF00A8CC);
  static const Color secondaryColor = Color(0xFF3282B8);

  const RoundedButton({
    super.key,
    required this.text,
    this.onTap,
    this.textColor = Colors.white,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [accentColor, secondaryColor]),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Container(
          padding: padding,
          alignment: Alignment.center,
          child: Text(text, style: TextStyle(color: textColor)),
        ),
      ),
    );
  }
}
