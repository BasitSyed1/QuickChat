import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/screens/home_screen.dart';
import '../providers/auth_provider.dart';
import 'onboarding_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return auth.when(
      data: (user) =>
          user == null ? const OnboardingScreen() : const HomeScreen(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const OnboardingScreen(),
    );
  }
}
