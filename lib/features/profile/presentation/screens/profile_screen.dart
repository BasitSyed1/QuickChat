import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/app_sheets.dart';
import '../../../../core/utils/smooth_route.dart';
import '../../../../core/widgets/edit_profile_sheet.dart';
import '../../../../core/widgets/logout_dialog.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/auth_gate.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;

    void openEditSheet() {
      AppSheets.show(
        context,
        EditProfileSheet(
          initialName: user?.name ?? '',
          initialBio: user?.bio ?? '',
          onSave: (name, bio) {
            ref.read(authProvider.notifier).updateCurrentUser(name, bio);
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceColor,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
              decoration: const BoxDecoration(
                gradient: AppColors.darkGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(36),
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.accentGradient,
                          boxShadow: AppColors.accentShadow,
                        ),
                        child: const CircleAvatar(
                          radius: 46,
                          backgroundColor: AppColors.primarySoft,
                          child: Icon(Icons.person_rounded,
                              size: 46, color: Colors.white),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: openEditSheet,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primaryColor,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? 'Guest',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.bio ?? 'Hey there! I am using QuickChat.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mail_outline_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        Text(
                          user?.email ?? '—',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _StatsRow(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _ProfileTile(
                      icon: Icons.edit_rounded,
                      label: AppStrings.editProfile,
                      onTap: openEditSheet,
                    ),
                    _divider(),
                    _ProfileTile(
                      icon: Icons.settings_rounded,
                      label: AppStrings.settings,
                      onTap: () {},
                    ),
                    _divider(),
                    _ProfileTile(
                      icon: Icons.notifications_none_rounded,
                      label: 'Notifications',
                      onTap: () {},
                    ),
                    _divider(),
                    _ProfileTile(
                      icon: Icons.group_add_rounded,
                      label: AppStrings.inviteFriends,
                      onTap: () {},
                    ),
                    _divider(),
                    _ProfileTile(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & Support',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.errorColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _ProfileTile(
                  icon: Icons.logout_rounded,
                  label: AppStrings.logout,
                  iconColor: AppColors.errorColor,
                  labelColor: AppColors.errorColor,
                  showTrailing: false,
                  onTap: () {
                    LogoutDialog.show(
                      context,
                      onLogout: () async {
                        await ref.read(authProvider.notifier).signOut();
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          SmoothRoute(const AuthGate()),
                          (_) => false,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Divider(
        color: AppColors.dividerColor.withValues(alpha: 0.6),
        height: 1,
        indent: 56,
      );
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _StatCard(label: 'Chats', value: '128', icon: Icons.chat_rounded),
          const SizedBox(width: 12),
          _StatCard(
              label: 'Friends', value: '54', icon: Icons.people_alt_rounded),
          const SizedBox(width: 12),
          _StatCard(label: 'Calls', value: '37', icon: Icons.call_rounded),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondaryColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 16, color: AppColors.secondaryVariantColor),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceColor,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;
  final bool showTrailing;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
    this.showTrailing = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.secondaryVariantColor)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? AppColors.secondaryVariantColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: labelColor ?? AppColors.onSurfaceColor,
                  ),
                ),
              ),
              if (showTrailing)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.onSurfaceMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
