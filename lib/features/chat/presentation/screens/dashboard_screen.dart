import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/smooth_route.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../providers/chat_provider.dart';
import 'chat_detail_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DashboardHeader(),
              const SizedBox(height: 18),
              const _SearchBar(),
              const SizedBox(height: 18),
              const _StoriesRow(),
              const SizedBox(height: 18),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppStrings.recentChats,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurfaceColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Icon(
                            Icons.archive_outlined,
                            size: 22,
                            color: AppColors.onSurfaceMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: usersAsync.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.secondaryVariantColor,
                            ),
                          ),
                          error: (error, _) => Center(
                            child: Text(
                              'Error: $error',
                              style: GoogleFonts.poppins(
                                color: AppColors.errorColor,
                              ),
                            ),
                          ),
                          data: (users) {
                            if (users.isEmpty) {
                              return const _EmptyChats();
                            }
                            return RefreshIndicator(
                              color: AppColors.secondaryVariantColor,
                              onRefresh: () =>
                                  ref.refresh(usersProvider.future),
                              child: SlidableAutoCloseBehavior(
                                child: ListView.separated(
                                  padding:
                                      const EdgeInsets.only(top: 8, bottom: 96),
                                  physics: const BouncingScrollPhysics(
                                    parent:
                                        AlwaysScrollableScrollPhysics(),
                                  ),
                                  itemCount: users.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 4),
                                  itemBuilder: (context, index) {
                                    return _ChatRow(user: users[index]);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.accentGradient,
            ),
            child: const CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primarySoft,
              child: Icon(Icons.person_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello there 👋',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              Text(
                AppStrings.appName,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const Spacer(),
          _IconBubble(icon: Icons.notifications_none_rounded, onTap: () {}),
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBubble({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded,
                color: Colors.white.withValues(alpha: 0.6), size: 20),
            const SizedBox(width: 10),
            Text(
              'Search messages, people…',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoriesRow extends StatelessWidget {
  const _StoriesRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 8,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _AddStory();
          }
          return _StoryAvatar(label: 'User $index');
        },
      ),
    );
  }
}

class _AddStory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.secondaryColor.withValues(alpha: 0.5),
              width: 1.4,
            ),
          ),
          child: const Icon(Icons.add_rounded,
              color: AppColors.secondaryColor),
        ),
        const SizedBox(height: 8),
        Text(
          'Your story',
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  final String label;
  const _StoryAvatar({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(2.4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.accentGradient,
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryColor,
            ),
            child: const CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primarySoft,
              child: Icon(Icons.person, color: Colors.white70, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _ChatRow extends StatelessWidget {
  final UserModel user;
  const _ChatRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(user.id ?? user.name),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.6,
        children: [
          _action(
            color: AppColors.errorColor,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
          ),
          _action(
            color: AppColors.secondaryVariantColor,
            icon: Icons.push_pin_outlined,
            label: 'Pin',
            textColor: Colors.black,
          ),
          _action(
            color: AppColors.onSurfaceColor,
            icon: Icons.archive_outlined,
            label: 'Archive',
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              SmoothRoute(ChatDetailScreen(otherUser: user)),
            );
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          AppColors.secondaryColor.withValues(alpha: 0.2),
                      child: Text(
                        (user.name?.isNotEmpty ?? false)
                            ? user.name![0].toUpperCase()
                            : '?',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondaryVariantColor,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.successColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surfaceColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.bio ?? 'Tap to start chatting',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '10:30',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: AppColors.accentGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '2',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
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

  Widget _action({
    required Color color,
    required IconData icon,
    required String label,
    Color textColor = Colors.white,
  }) {
    return Builder(
      builder: (context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Material(
            color: color,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Slidable.of(context)?.close(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: textColor, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.secondaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 36,
              color: AppColors.secondaryVariantColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start a chat to see it here',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}
