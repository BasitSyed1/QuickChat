import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/smooth_route.dart';
import '../../../../core/widgets/custom_button.dart';
import 'signin_screen.dart';
import 'signup_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: const _HeroVisual()),
                const SizedBox(height: 24),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: AppStrings.onboardingTitlePrefix,
                        style: GoogleFonts.poppins(
                          color: AppColors.onPrimaryColor,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          letterSpacing: -0.6,
                        ),
                      ),
                      TextSpan(
                        text: AppStrings.onboardingTitleBrand,
                        style: GoogleFonts.poppins(
                          color: AppColors.secondaryColor,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  AppStrings.onboardingSubtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                CustomButton(
                  label: AppStrings.getStarted,
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      SmoothRoute(const SigninScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        SmoothRoute(const SignupScreen()),
                      );
                    },
                    child: Text.rich(
                      TextSpan(
                        text: AppStrings.dontHaveAccount,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: AppStrings.signUp,
                            style: GoogleFonts.poppins(
                              color: AppColors.secondaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _HeroVisual extends StatefulWidget {
  const _HeroVisual();

  @override
  State<_HeroVisual> createState() => _HeroVisualState();
}

class _HeroVisualState extends State<_HeroVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return SizedBox(
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _glowRing(420, 0.18),
                _ring(300, 1.2),
                _ring(220, 1.4),
                _ring(140, 1.6),
                Container(
                  height: 96,
                  width: 96,
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            AppColors.secondaryColor.withValues(alpha: 0.55),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    size: 44,
                    color: Colors.black,
                  ),
                ),
                _floatingIcon(Icons.videocam_rounded, -120, -90, -0.35),
                _floatingIcon(Icons.mail_rounded, 110, -100, 0.35),
                _floatingIcon(Icons.call_rounded, -130, 80, -0.25),
                _floatingIcon(Icons.mic_rounded, 120, 90, 0.25),
              ],
            ),
          );
        },
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
          color: AppColors.secondaryColor.withValues(alpha: 0.12),
        ),
      ),
    );
  }

  Widget _glowRing(double size, double opacity) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.secondaryColor.withValues(alpha: opacity),
            blurRadius: 200,
            spreadRadius: -60,
          ),
        ],
      ),
    );
  }

  Widget _floatingIcon(IconData icon, double dx, double dy, double angle) {
    final t = _ctrl.value * 2 * 3.1415926;
    final wobble = 6 * (icon.codePoint % 2 == 0 ? 1 : -1);
    return Transform.translate(
      offset: Offset(dx, dy + wobble * (0.5 + 0.5 * (t.remainder(2) - 1))),
      child: Transform.rotate(
        angle: angle,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}
