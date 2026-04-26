import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brand_logo.dart';

class AuthHeaderVisual extends StatelessWidget {
  final double height;

  const AuthHeaderVisual({super.key, this.height = 180});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 220,
            width: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondaryColor.withValues(alpha: 0.25),
                  blurRadius: 80,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
          _ring(160, 1.2),
          _ring(120, 1.4),
          const BrandLogo(size: 72),
        ],
      ),
    );
  }

  Widget _ring(double size, double width) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          width: width,
          color: AppColors.secondaryColor.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}
