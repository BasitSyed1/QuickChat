import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  final bool onDark;

  const BrandLogo({super.key, this.size = 56, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: AppColors.accentShadow,
      ),
      child: Icon(
        Icons.chat_bubble_rounded,
        size: size * 0.5,
        color: onDark ? Colors.black : Colors.black87,
      ),
    );
  }
}
