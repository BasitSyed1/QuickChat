import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/smooth_route.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_header_visual.dart';
import 'signup_screen.dart';

class SigninScreen extends ConsumerStatefulWidget {
  const SigninScreen({super.key});

  @override
  ConsumerState<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends ConsumerState<SigninScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.enterEmailAndPassword)),
      );
      return;
    }

    await ref.read(authProvider.notifier).signIn(email, password);
    if (!mounted) return;

    final state = ref.read(authProvider);
    state.whenOrNull(
      data: (user) {
        if (user != null) {
          Navigator.pushReplacement(
            context,
            SmoothRoute(const HomeScreen()),
          );
        }
      },
      error: (e, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.surfaceColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const AuthHeaderVisual(),
              const SizedBox(height: 28),
              Text(
                AppStrings.welcomeBack,
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: AppColors.onSurfaceColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.loginToStart,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 36),
              CustomTextField(
                controller: _emailController,
                placeholder: AppStrings.email,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline_rounded,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: _passwordController,
                placeholder: AppStrings.password,
                obscureText: _obscurePassword,
                prefixIcon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  splashRadius: 20,
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.onSurfaceMuted,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    'Forgot password?',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.secondaryVariantColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CustomButton(
                label: AppStrings.signIn,
                isLoading: isLoading,
                onPressed: _onSignIn,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppStrings.dontHaveAccount,
                    style: GoogleFonts.poppins(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        SmoothRoute(const SignupScreen()),
                      );
                    },
                    child: Text(
                      AppStrings.signUp,
                      style: GoogleFonts.poppins(
                        color: AppColors.secondaryVariantColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
