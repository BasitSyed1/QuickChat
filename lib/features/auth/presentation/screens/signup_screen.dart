import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/smooth_route.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../domain/entities/user_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_header_visual.dart';
import 'signin_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.enterAllFields)),
      );
      return;
    }

    await ref.read(authProvider.notifier).signUp(
          UserModel(name: name, email: email, password: password),
        );
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
              const AuthHeaderVisual(height: 160),
              const SizedBox(height: 24),
              Text(
                AppStrings.createAccount,
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: AppColors.onSurfaceColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.signUpToStart,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 32),
              CustomTextField(
                controller: _nameController,
                placeholder: AppStrings.fullName,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                prefixIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 28),
              CustomButton(
                label: AppStrings.createAccount,
                isLoading: isLoading,
                onPressed: _onSignUp,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppStrings.alreadyHaveAccount,
                    style: GoogleFonts.poppins(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        SmoothRoute(const SigninScreen()),
                      );
                    },
                    child: Text(
                      AppStrings.signIn,
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
