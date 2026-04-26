import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class CustomButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool secondary;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.secondary = false,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (widget.onPressed == null || widget.isLoading) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;
    final textColor =
        widget.secondary ? AppColors.onSurfaceColor : AppColors.onSecondaryColor;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: disabled ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: disabled ? 0.6 : 1,
          child: Container(
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: widget.secondary ? null : AppColors.accentGradient,
              color: widget.secondary ? AppColors.surfaceMuted : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: widget.secondary ? null : AppColors.accentShadow,
            ),
            alignment: Alignment.center,
            child: widget.isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.black,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: textColor),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
