import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class AppHeading extends StatelessWidget {
  final String text;
  final Color? color;

  const AppHeading(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.onSurfaceColor,
        letterSpacing: -0.5,
      ),
    );
  }
}

class AppSubHeading extends StatelessWidget {
  final String text;
  final Color? color;

  const AppSubHeading(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.onSurfaceColor,
      ),
    );
  }
}
