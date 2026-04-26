import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String placeholder;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final IconData? prefixIcon;
  final TextCapitalization textCapitalization;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.suffix,
    this.prefixIcon,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused
              ? AppColors.secondaryVariantColor
              : AppColors.borderColor,
          width: _focused ? 1.4 : 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color:
                      AppColors.secondaryColor.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        obscureText: widget.obscureText,
        cursorColor: AppColors.secondaryVariantColor,
        style: GoogleFonts.poppins(
          fontSize: 16,
          color: AppColors.onSurfaceColor,
        ),
        decoration: InputDecoration(
          hintText: widget.placeholder,
          hintStyle: GoogleFonts.poppins(
            color: AppColors.onSurfaceMuted,
            fontSize: 15,
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon,
                  size: 20, color: AppColors.onSurfaceMuted)
              : null,
          suffixIcon: widget.suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: widget.suffix,
                )
              : null,
        ),
      ),
    );
  }
}
