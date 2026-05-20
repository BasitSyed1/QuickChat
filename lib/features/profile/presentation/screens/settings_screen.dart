import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/smooth_route.dart';
import '../../../../core/utils/user_prefs.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../chat/presentation/screens/starred_messages_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _loading = true;
  bool _push = true;
  bool _sound = true;
  bool _vibration = true;
  bool _readReceipts = true;
  bool _lastSeenVisible = true;
  bool _enterToSend = false;
  Set<String> _blocked = const <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait<dynamic>([
      UserPrefs.isPushOn(),
      UserPrefs.isSoundOn(),
      UserPrefs.isVibrationOn(),
      UserPrefs.isReadReceiptsOn(),
      UserPrefs.isLastSeenVisible(),
      UserPrefs.isEnterToSendOn(),
      UserPrefs.blockedIds(),
    ]);
    if (!mounted) return;
    setState(() {
      _push = results[0] as bool;
      _sound = results[1] as bool;
      _vibration = results[2] as bool;
      _readReceipts = results[3] as bool;
      _lastSeenVisible = results[4] as bool;
      _enterToSend = results[5] as bool;
      _blocked = (results[6] as Set<String>).toSet();
      _loading = false;
    });
  }

  Future<void> _toggle(
    bool value,
    Future<void> Function(bool) save,
    void Function(bool) apply,
  ) async {
    HapticFeedback.selectionClick();
    apply(value);
    setState(() {});
    await save(value);
  }

  Future<void> _unblock(String id) async {
    HapticFeedback.lightImpact();
    final ok = await AppDialogs.confirm(
      context,
      title: 'Unblock user?',
      message: 'They will be able to message you again.',
      confirmLabel: 'Unblock',
    );
    if (!ok) return;
    await UserPrefs.unblock(id);
    if (!mounted) return;
    setState(() => _blocked = _blocked.where((b) => b != id).toSet());
    AppDialogs.toast(context, 'User unblocked', icon: Icons.check_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surfaceColor,
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: 36, top: 0),
          children: [
            _Header(topInset: topInset),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _Section(
                title: 'Notifications',
                children: [
                  _SwitchTile(
                    icon: Icons.notifications_active_rounded,
                    label: 'Push notifications',
                    subtitle: 'Get notified when you receive messages',
                    value: _push,
                    onChanged: (v) =>
                        _toggle(v, UserPrefs.setPush, (b) => _push = b),
                  ),
                  _SwitchTile(
                    icon: Icons.volume_up_rounded,
                    label: 'Sound',
                    subtitle: 'Play sound on new messages',
                    value: _sound,
                    onChanged: (v) =>
                        _toggle(v, UserPrefs.setSound, (b) => _sound = b),
                  ),
                  _SwitchTile(
                    icon: Icons.vibration_rounded,
                    label: 'Vibration',
                    subtitle: 'Vibrate on new messages',
                    value: _vibration,
                    onChanged: (v) => _toggle(
                      v,
                      UserPrefs.setVibration,
                      (b) => _vibration = b,
                    ),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Privacy',
                children: [
                  _SwitchTile(
                    icon: Icons.done_all_rounded,
                    label: 'Read receipts',
                    subtitle:
                        'Let others know when you read their messages',
                    value: _readReceipts,
                    onChanged: (v) => _toggle(
                      v,
                      UserPrefs.setReadReceipts,
                      (b) => _readReceipts = b,
                    ),
                  ),
                  _SwitchTile(
                    icon: Icons.visibility_outlined,
                    label: 'Last seen',
                    subtitle: 'Share your last seen time',
                    value: _lastSeenVisible,
                    onChanged: (v) => _toggle(
                      v,
                      UserPrefs.setLastSeenVisible,
                      (b) => _lastSeenVisible = b,
                    ),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Chat',
                children: [
                  _SwitchTile(
                    icon: Icons.keyboard_return_rounded,
                    label: 'Enter sends messages',
                    subtitle:
                        'When off, pressing Enter inserts a new line',
                    value: _enterToSend,
                    onChanged: (v) => _toggle(
                      v,
                      UserPrefs.setEnterToSend,
                      (b) => _enterToSend = b,
                    ),
                  ),
                  _ActionTile(
                    icon: Icons.star_rounded,
                    label: 'Starred messages',
                    subtitle: 'Browse messages you\'ve starred',
                    onTap: () => Navigator.push(
                      context,
                      SmoothRoute(const StarredMessagesScreen()),
                    ),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Appearance',
                children: [
                  _ThemeTile(
                    current: ref.watch(themeModeProvider),
                    onChanged: (mode) {
                      HapticFeedback.selectionClick();
                      ref.read(themeModeProvider.notifier).setMode(mode);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Blocked users',
                children: _blocked.isEmpty
                    ? [
                        const _EmptyBlocked(),
                      ]
                    : _blocked
                        .map(
                          (id) => _BlockedTile(
                            id: id,
                            onUnblock: () => _unblock(id),
                            isLast: id == _blocked.last,
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'About',
                children: [
                  _StaticTile(
                    icon: Icons.shield_outlined,
                    label: 'End-to-end encrypted',
                    subtitle: 'All chats are AES-encrypted on-device',
                  ),
                  _StaticTile(
                    icon: Icons.info_outline_rounded,
                    label: 'Version',
                    subtitle: '1.0.0 (build 1)',
                    showDivider: false,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final double topInset;
  const _Header({required this.topInset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(8, topInset + 6, 16, 24),
      decoration: const BoxDecoration(
        gradient: AppColors.darkGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 4),
          Text(
            'Settings',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 0, 8),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceMuted,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  const _SwitchTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.secondaryVariantColor
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: AppColors.secondaryVariantColor,
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
                        color: AppColors.onSurfaceColor,
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
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppColors.secondaryVariantColor,
                activeTrackColor: AppColors.secondaryColor,
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Container(
              height: 1,
              color: AppColors.borderColor.withValues(alpha: 0.4),
            ),
          ),
      ],
    );
  }
}

class _StaticTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool showDivider;

  const _StaticTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.secondaryVariantColor
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: AppColors.secondaryVariantColor,
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
                        color: AppColors.onSurfaceColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

class _BlockedTile extends StatelessWidget {
  final String id;
  final VoidCallback onUnblock;
  final bool isLast;

  const _BlockedTile({
    required this.id,
    required this.onUnblock,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    // Show a shortened id; we don't have the full UserModel here.
    final shortId = id.length > 8 ? '${id.substring(0, 6)}…' : id;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.errorColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.block_rounded,
                  color: AppColors.errorColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User $shortId',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceColor,
                      ),
                    ),
                    Text(
                      'Tap unblock to allow messages again',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onUnblock,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondaryVariantColor,
                ),
                child: Text(
                  'Unblock',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryVariantColor
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      icon,
                      color: AppColors.secondaryVariantColor,
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
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: AppColors.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
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

class _ThemeTile extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeTile({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.secondaryVariantColor
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.brightness_6_rounded,
                  color: AppColors.secondaryVariantColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'System matches your device setting',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final option in const [
                (ThemeMode.system, 'System', Icons.brightness_auto_rounded),
                (ThemeMode.light, 'Light', Icons.light_mode_rounded),
                (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _ThemeChip(
                      label: option.$2,
                      icon: option.$3,
                      selected: current == option.$1,
                      onTap: () => onChanged(option.$1),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.secondaryColor.withValues(alpha: 0.18)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.secondaryVariantColor
                : AppColors.borderColor,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? AppColors.secondaryVariantColor
                  : AppColors.onSurfaceColor,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.secondaryVariantColor
                    : AppColors.onSurfaceColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBlocked extends StatelessWidget {
  const _EmptyBlocked();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.successColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: AppColors.successColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No blocked users — you\'re all clear.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.onSurfaceColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
