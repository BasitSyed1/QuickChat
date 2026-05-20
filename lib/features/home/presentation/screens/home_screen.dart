import 'package:flutter/material.dart';

import '../../../chat/presentation/screens/dashboard_screen.dart';

/// Thin forwarder retained so signin/signup can keep their import path.
/// The bottom navigation has been removed in favor of the dashboard owning
/// the entire chat surface, with the profile entry living in its app bar.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const DashboardScreen();
}
