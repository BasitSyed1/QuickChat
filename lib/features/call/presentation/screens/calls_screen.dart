import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calls',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          AppStrings.recentCalls,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: const Icon(Icons.search_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                  ),
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: 10,
                    separatorBuilder: (_, _) => Divider(
                      color: AppColors.dividerColor.withValues(alpha: 0.6),
                      height: 24,
                      indent: 64,
                    ),
                    itemBuilder: (_, i) => _CallTile(missed: i % 4 == 0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallTile extends StatelessWidget {
  final bool missed;
  const _CallTile({this.missed = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.secondaryColor.withValues(alpha: 0.18),
          child: Text(
            'J',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryVariantColor,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'John Doe',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceColor,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    missed
                        ? Icons.call_missed_rounded
                        : Icons.call_made_rounded,
                    size: 14,
                    color: missed
                        ? AppColors.errorColor
                        : AppColors.successColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Yesterday, 8:30 PM',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.secondaryColor.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.call_rounded,
            color: AppColors.secondaryVariantColor,
            size: 18,
          ),
        ),
      ],
    );
  }
}
