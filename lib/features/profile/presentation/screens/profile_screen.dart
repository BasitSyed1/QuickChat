import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/app_sheets.dart';
import '../../../../core/utils/smooth_route.dart';
import '../../../../core/utils/user_prefs.dart';
import '../../../../core/widgets/edit_profile_sheet.dart';
import '../../../../core/widgets/logout_dialog.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/auth_gate.dart';
import '../widgets/status_sheet.dart';
import 'settings_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _status = UserPrefs.defaultStatus;
  String _statusEmoji = '💬';

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final text = await UserPrefs.getStatus();
    final emoji = await UserPrefs.getStatusEmoji();
    if (!mounted) return;
    setState(() {
      _status = text;
      _statusEmoji = emoji;
    });
  }

  void _openEditSheet(UserModel? user) {
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

  void _openStatusSheet() {
    AppSheets.show(
      context,
      StatusSheet(
        initial: _status,
        initialEmoji: _statusEmoji,
        onSaved: (text, emoji) {
          if (!mounted) return;
          setState(() {
            _status = text;
            _statusEmoji = emoji;
          });
        },
      ),
    );
  }

  void _openSettings() {
    Navigator.push(context, SmoothRoute(const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    final topInset = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surfaceColor,
        body: auth.when(
          loading: () => _ProfileShimmer(topInset: topInset),
          error: (_, _) => _ProfileShimmer(topInset: topInset),
          data: (user) => SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 36),
            child: Column(
              children: [
                _ProfileHeader(
                  user: user,
                  status: _status,
                  statusEmoji: _statusEmoji,
                  onEdit: () => _openEditSheet(user),
                  onStatus: _openStatusSheet,
                ),
                const SizedBox(height: 24),
                _ProfileTileGroup(
                  children: [
                    _ProfileTile(
                      icon: Icons.edit_rounded,
                      label: AppStrings.editProfile,
                      onTap: () => _openEditSheet(user),
                    ),
                    _ProfileTile(
                      icon: Icons.bolt_rounded,
                      label: 'Status',
                      subtitle: '$_statusEmoji  $_status',
                      onTap: _openStatusSheet,
                    ),
                    _ProfileTile(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      subtitle: 'Notifications, privacy, blocked users',
                      onTap: _openSettings,
                    ),
                    _ProfileTile(
                      icon: Icons.info_outline_rounded,
                      label: 'About QuickChat',
                      subtitle: 'Version 1.0.0',
                      onTap: () => _showAboutSheet(context),
                      showDivider: false,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ProfileTileGroup(
                  background: AppColors.errorColor.withValues(alpha: 0.07),
                  children: [
                    _ProfileTile(
                      icon: Icons.logout_rounded,
                      label: AppStrings.logout,
                      iconColor: AppColors.errorColor,
                      labelColor: AppColors.errorColor,
                      showTrailing: false,
                      showDivider: false,
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAboutSheet(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppStrings.appName,
      applicationVersion: '1.0.0',
      applicationLegalese: 'Built with Flutter & Supabase',
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel? user;
  final String status;
  final String statusEmoji;
  final VoidCallback onEdit;
  final VoidCallback onStatus;

  const _ProfileHeader({
    required this.user,
    required this.status,
    required this.statusEmoji,
    required this.onEdit,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final initial = (user?.name?.isNotEmpty ?? false)
        ? user!.name![0].toUpperCase()
        : 'Q';
    final canPop = Navigator.of(context).canPop();
    return Container(
      padding: EdgeInsets.fromLTRB(20, topInset + 6, 20, 32),
      decoration: const BoxDecoration(
        gradient: AppColors.darkGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(36),
        ),
      ),
      child: Column(
        children: [
          if (canPop)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            )
          else
            const SizedBox(height: 20),
          const SizedBox(height: 6),
          Stack(
            children: [
              Hero(
                tag: 'me-avatar',
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.accentGradient,
                    boxShadow: AppColors.accentShadow,
                  ),
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.primarySoft,
                    child: Text(
                      initial,
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onEdit,
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
            user?.name?.isNotEmpty == true ? user!.name! : 'Guest',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          if ((user?.bio ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                user!.bio!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
            ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onStatus,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                color: AppColors.secondaryColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: AppColors.secondaryColor.withValues(alpha: 0.32),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(statusEmoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.edit_rounded,
                    size: 12,
                    color: AppColors.secondaryColor.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
    );
  }
}

class _ProfileTileGroup extends StatelessWidget {
  final List<Widget> children;
  final Color? background;

  const _ProfileTileGroup({required this.children, this.background});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: background ?? AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;
  final bool showTrailing;
  final bool showDivider;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.labelColor,
    this.showTrailing = true,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: (iconColor ?? AppColors.secondaryVariantColor)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor ?? AppColors.secondaryVariantColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: labelColor ?? AppColors.onSurfaceColor,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: AppColors.onSurfaceMuted,
                            ),
                          ),
                        ],
                      ],
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
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 60),
            child: Container(
              height: 1,
              color: AppColors.borderColor.withValues(alpha: 0.4),
            ),
          ),
      ],
    );
  }
}

class _ProfileShimmer extends StatelessWidget {
  final double topInset;
  const _ProfileShimmer({required this.topInset});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, topInset + 28, 20, 32),
            decoration: const BoxDecoration(
              gradient: AppColors.darkGradient,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(36),
              ),
            ),
            child: ShimmerArea(
              baseColor: Colors.white.withValues(alpha: 0.10),
              highlightColor: Colors.white.withValues(alpha: 0.22),
              child: Column(
                children: [
                  const ShimmerBox(
                    width: 96,
                    height: 96,
                    borderRadius: BorderRadius.all(Radius.circular(48)),
                  ),
                  const SizedBox(height: 18),
                  ShimmerBox(
                    width: 140,
                    height: 18,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 10),
                  ShimmerBox(
                    width: 220,
                    height: 12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ShimmerArea(
              child: Column(
                children: List.generate(
                  4,
                  (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ShimmerBox(
                      height: 56,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
