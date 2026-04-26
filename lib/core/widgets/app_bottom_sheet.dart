import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class AppBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const AppBottomSheet({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: 44,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: AppColors.borderColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
