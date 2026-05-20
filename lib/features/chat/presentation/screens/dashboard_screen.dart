import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/avatar_palette.dart';
import '../../../../core/utils/chat_prefs.dart';
import '../../../../core/utils/smooth_route.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/utils/user_prefs.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../ai/presentation/screens/ai_chat_screen.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../data/services/presence_service.dart';
import '../../domain/entities/chat_preview.dart';
import '../providers/chat_provider.dart';
import 'chat_detail_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';
  bool _showWelcome = false;
  Set<String> _blockedIds = const <String>{};
  Set<String> _pinnedIds = const <String>{};
  Set<String> _mutedIds = const <String>{};
  Set<String> _archivedIds = const <String>{};
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(() {
      final value = _searchController.text.trim().toLowerCase();
      if (value != _query) setState(() => _query = value);
    });
    _checkWelcome();
    _loadBlocked();
    _loadConversationFlags();
  }

  Future<void> _loadBlocked() async {
    final ids = await UserPrefs.blockedIds();
    if (!mounted) return;
    setState(() => _blockedIds = ids);
  }

  Future<void> _loadConversationFlags() async {
    final results = await Future.wait([
      UserPrefs.pinnedConversations(),
      UserPrefs.mutedConversations(),
      UserPrefs.archivedConversations(),
    ]);
    if (!mounted) return;
    setState(() {
      _pinnedIds = results[0];
      _mutedIds = results[1];
      _archivedIds = results[2];
    });
  }

  Future<void> _checkWelcome() async {
    final dismissed = await ChatPrefs.isWelcomeDismissed();
    if (!mounted || dismissed) return;
    setState(() => _showWelcome = true);
  }

  Future<void> _dismissWelcome() async {
    setState(() => _showWelcome = false);
    await ChatPrefs.dismissWelcome();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(presenceServiceProvider).markOffline();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(presenceServiceProvider).connect();
      _loadBlocked();
      _loadConversationFlags();
      // ignore: unused_result
      ref.refresh(dashboardProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _openChat(UserModel user) async {
    _searchFocus.unfocus();
    await Navigator.push(
      context,
      SmoothRoute(ChatDetailScreen(otherUser: user)),
    );
    if (!mounted) return;
    _loadBlocked();
    _loadConversationFlags();
    // ignore: unused_result
    ref.refresh(dashboardProvider);
  }

  Future<void> _openProfile() async {
    HapticFeedback.lightImpact();
    _searchFocus.unfocus();
    await Navigator.push(context, SmoothRoute(const ProfileScreen()));
    if (!mounted) return;
    _loadBlocked();
    // ignore: unused_result
    ref.refresh(dashboardProvider);
  }

  DashboardData _applyBlocked(DashboardData data) {
    if (_blockedIds.isEmpty) return data;
    final chats = data.activeChats
        .where((c) => c.otherUser.id == null ||
            !_blockedIds.contains(c.otherUser.id))
        .toList();
    final users = data.availableUsers
        .where((u) => u.id == null || !_blockedIds.contains(u.id))
        .toList();
    return DashboardData(activeChats: chats, availableUsers: users);
  }

  _DashboardSections _splitSections(DashboardData data) {
    final pinned = <ChatPreview>[];
    final recent = <ChatPreview>[];
    final archived = <ChatPreview>[];
    for (final c in data.activeChats) {
      final cid = c.conversationId;
      if (cid != null && _archivedIds.contains(cid)) {
        archived.add(c);
      } else if (cid != null && _pinnedIds.contains(cid)) {
        pinned.add(c);
      } else {
        recent.add(c);
      }
    }
    return _DashboardSections(
      pinned: pinned,
      recent: recent,
      archived: archived,
      mutedIds: _mutedIds,
    );
  }

  Future<void> _onChatLongPress(ChatPreview preview) async {
    HapticFeedback.mediumImpact();
    final cid = preview.conversationId;
    if (cid == null) {
      _confirmClearConversation(preview);
      return;
    }
    final pinned = _pinnedIds.contains(cid);
    final muted = _mutedIds.contains(cid);
    final archived = _archivedIds.contains(cid);
    final action = await showCupertinoModalPopup<_RowAction>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          preview.otherUser.name ?? 'Chat',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, _RowAction.pin),
            child: Text(
              pinned ? 'Unpin' : 'Pin to top',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, _RowAction.mute),
            child: Text(
              muted ? 'Unmute' : 'Mute notifications',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, _RowAction.archive),
            child: Text(
              archived ? 'Unarchive' : 'Archive',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, _RowAction.delete),
            child: Text(
              'Delete chat',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            AppStrings.cancel,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _RowAction.pin:
        if (pinned) {
          await UserPrefs.unpin(cid);
        } else {
          await UserPrefs.pin(cid);
        }
        break;
      case _RowAction.mute:
        if (muted) {
          await UserPrefs.unmute(cid);
        } else {
          await UserPrefs.mute(cid);
        }
        break;
      case _RowAction.archive:
        if (archived) {
          await UserPrefs.unarchive(cid);
        } else {
          await UserPrefs.archive(cid);
        }
        break;
      case _RowAction.delete:
        _confirmClearConversation(preview);
        return;
    }
    await _loadConversationFlags();
  }

  Widget _renderDashboard({
    required AsyncValue<DashboardData> dashboardAsync,
    required DashboardData? cached,
    required PresenceSnapshot presence,
  }) {
    final live = dashboardAsync.value;
    final raw = live ?? cached;
    final data = raw == null ? null : _applyBlocked(raw);

    if (data != null) {
      final sections = _splitSections(data);
      return _DashboardBody(
        data: data,
        sections: sections,
        showArchived: _showArchived,
        onToggleArchived: () =>
            setState(() => _showArchived = !_showArchived),
        query: _query,
        presence: presence,
        showWelcome: _showWelcome,
        onDismissWelcome: _dismissWelcome,
        onRefresh: () async {
          HapticFeedback.selectionClick();
          await _loadBlocked();
          await _loadConversationFlags();
          // ignore: unused_result
          await ref.refresh(dashboardProvider.future);
        },
        onTapUser: _openChat,
        onChatLongPress: _onChatLongPress,
      );
    }

    return dashboardAsync.when(
      loading: () => const _DashboardLoading(),
      error: (e, _) => _DashboardError(
        onRetry: () async {
          // ignore: unused_result
          await ref.refresh(dashboardProvider.future);
        },
      ),
      data: (_) => const _DashboardLoading(),
    );
  }

  Future<void> _confirmClearConversation(ChatPreview preview) async {
    HapticFeedback.mediumImpact();
    final ok = await AppDialogs.confirm(
      context,
      title: 'Delete chat with ${preview.otherUser.name ?? "this user"}?',
      message:
          'Messages will be removed from your device. The other person can still see them.',
      confirmLabel: 'Delete chat',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final cid = preview.conversationId;
    if (cid == null) return;
    try {
      await ref.read(chatServiceProvider).clearConversationForMe(cid);
      if (!mounted) return;
      // ignore: unused_result
      await ref.refresh(dashboardProvider.future);
    } catch (e) {
      if (!mounted) return;
      AppDialogs.info(
        context,
        title: 'Couldn\'t delete chat',
        message: e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final cachedDashboard = ref.watch(cachedDashboardProvider);
    final authUser = ref.watch(authProvider).value;
    final presence = ref.watch(presenceProvider).maybeWhen(
          data: (s) => s,
          orElse: () => PresenceSnapshot.empty,
        );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primaryColor,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _searchFocus.unfocus(),
          child: Container(
            decoration: const BoxDecoration(gradient: AppColors.darkGradient),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DashboardHeader(
                    user: authUser,
                    onlineCount: presence.onlineIds.length,
                    onProfileTap: _openProfile,
                  ),
                  const SizedBox(height: 16),
                  _SearchBar(
                    controller: _searchController,
                    focusNode: _searchFocus,
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(36),
                          topRight: Radius.circular(36),
                        ),
                      ),
                      child: _renderDashboard(
                        dashboardAsync: dashboardAsync,
                        cached: cachedDashboard,
                        presence: presence,
                      ),
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

enum _RowAction { pin, mute, archive, delete }

class _DashboardSections {
  final List<ChatPreview> pinned;
  final List<ChatPreview> recent;
  final List<ChatPreview> archived;
  final Set<String> mutedIds;

  const _DashboardSections({
    required this.pinned,
    required this.recent,
    required this.archived,
    required this.mutedIds,
  });
}

class _DashboardHeader extends StatelessWidget {
  final UserModel? user;
  final int onlineCount;
  final VoidCallback onProfileTap;
  const _DashboardHeader({
    this.user,
    this.onlineCount = 0,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user?.name?.split(' ').first ?? AppStrings.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (onlineCount > 0) _OnlineCountChip(count: onlineCount),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ProfileAvatarButton(
            user: user,
            onTap: onProfileTap,
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _ProfileAvatarButton extends StatelessWidget {
  final UserModel? user;
  final VoidCallback onTap;

  const _ProfileAvatarButton({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial = (user?.name?.isNotEmpty ?? false)
        ? user!.name![0].toUpperCase()
        : 'Q';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Hero(
        tag: 'me-avatar',
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.accentGradient,
            boxShadow: AppColors.accentShadow,
          ),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryColor,
            child: Text(
              initial,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnlineCountChip extends StatelessWidget {
  final int count;
  const _OnlineCountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(color: AppColors.secondaryColor),
          const SizedBox(width: 6),
          Text(
            '$count online',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const double _baseSize = 8;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _baseSize + 8,
      height: _baseSize + 8,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t).clamp(0, 1),
                child: Container(
                  width: _baseSize + (t * 8),
                  height: _baseSize + (t * 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.4),
                  ),
                ),
              ),
              Container(
                width: _baseSize,
                height: _baseSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  const _SearchBar({required this.controller, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              CupertinoIcons.search,
              size: 18,
              color: Colors.white.withValues(alpha: 0.65),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.search,
                cursorColor: AppColors.secondaryColor,
                cursorWidth: 1.6,
                cursorRadius: const Radius.circular(2),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.2,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search chats and people',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13.5,
                    color: Colors.white.withValues(alpha: 0.55),
                    height: 1.2,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, _) {
                if (value.text.isEmpty) return const SizedBox(width: 12);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      controller.clear();
                      HapticFeedback.selectionClick();
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.clear,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final DashboardData data;
  final _DashboardSections sections;
  final bool showArchived;
  final VoidCallback onToggleArchived;
  final String query;
  final PresenceSnapshot presence;
  final bool showWelcome;
  final VoidCallback onDismissWelcome;
  final Future<void> Function() onRefresh;
  final void Function(UserModel) onTapUser;
  final void Function(ChatPreview) onChatLongPress;

  const _DashboardBody({
    required this.data,
    required this.sections,
    required this.showArchived,
    required this.onToggleArchived,
    required this.query,
    required this.presence,
    required this.showWelcome,
    required this.onDismissWelcome,
    required this.onRefresh,
    required this.onTapUser,
    required this.onChatLongPress,
  });

  bool _matchesUser(UserModel u) {
    if (query.isEmpty) return true;
    return (u.name ?? '').toLowerCase().contains(query) ||
        (u.email ?? '').toLowerCase().contains(query);
  }

  bool _matchesChat(ChatPreview c) {
    if (query.isEmpty) return true;
    return _matchesUser(c.otherUser) ||
        (c.lastMessage ?? '').toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = query.isNotEmpty;
    final pinnedFiltered = sections.pinned.where(_matchesChat).toList();
    final recentFiltered = sections.recent.where(_matchesChat).toList();
    final archivedFiltered = sections.archived.where(_matchesChat).toList();
    final filteredUsers = data.availableUsers.where(_matchesUser).toList();
    final visibleChats = isSearching
        ? [...pinnedFiltered, ...recentFiltered, ...archivedFiltered]
        : [...pinnedFiltered, ...recentFiltered];

    if (data.isEmpty) {
      return RefreshIndicator(
        color: AppColors.secondaryVariantColor,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: const [
            SizedBox(height: 80),
            _EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No people here yet',
              subtitle: 'Once someone joins, they\'ll show up here',
            ),
          ],
        ),
      );
    }

    if (isSearching && visibleChats.isEmpty && filteredUsers.isEmpty) {
      return RefreshIndicator(
        color: AppColors.secondaryVariantColor,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: const [
            SizedBox(height: 60),
            _EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matches',
              subtitle: 'Try a different name or message',
            ),
          ],
        ),
      );
    }

    final totalUnread =
        recentFiltered.fold<int>(0, (sum, c) => sum + c.unreadCount);

    Widget renderRow(ChatPreview c) => _ChatRow(
          preview: c,
          query: query,
          isOnline: c.otherUser.id != null &&
              presence.onlineIds.contains(c.otherUser.id!),
          pinned: c.conversationId != null &&
              sections.pinned.any(
                  (p) => p.conversationId == c.conversationId),
          muted: c.conversationId != null &&
              sections.mutedIds.contains(c.conversationId),
          archived: c.conversationId != null &&
              sections.archived.any(
                  (a) => a.conversationId == c.conversationId),
          onTap: () => onTapUser(c.otherUser),
          onLongPress: () => onChatLongPress(c),
        );

    return RefreshIndicator(
      color: AppColors.secondaryVariantColor,
      onRefresh: onRefresh,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (!isSearching) ...[
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SizeTransition(sizeFactor: anim, child: child),
                ),
                child: showWelcome
                    ? _WelcomeBanner(
                        key: const ValueKey('welcome'),
                        onDismiss: onDismissWelcome,
                      )
                    : const SizedBox.shrink(key: ValueKey('welcome-empty')),
              ),
            ),
            if (showWelcome) const SizedBox(height: 14),
            const _AiAssistantCard(),
            const SizedBox(height: 18),
            if (sections.archived.isNotEmpty)
              _ArchivedHeader(
                count: sections.archived.length,
                expanded: showArchived,
                onTap: onToggleArchived,
              ),
            if (sections.archived.isNotEmpty && showArchived) ...[
              const SizedBox(height: 6),
              ...sections.archived.map(renderRow),
              const SizedBox(height: 18),
            ],
            if (sections.archived.isNotEmpty && !showArchived)
              const SizedBox(height: 12),
          ],
          if (!isSearching && pinnedFiltered.isNotEmpty) ...[
            _SectionLabel(
              title: 'Pinned',
              count: pinnedFiltered.length,
              icon: Icons.push_pin_rounded,
            ),
            const SizedBox(height: 6),
            ...pinnedFiltered.map(renderRow),
            const SizedBox(height: 18),
          ],
          if (recentFiltered.isNotEmpty || isSearching) ...[
            _SectionLabel(
              title: isSearching ? 'Chats' : AppStrings.recentChats,
              count: isSearching ? visibleChats.length : recentFiltered.length,
              accentCount: isSearching ? 0 : totalUnread,
            ),
            const SizedBox(height: 6),
            if (isSearching)
              ...visibleChats.map(renderRow)
            else
              ...recentFiltered.map(renderRow),
          ],
          if (filteredUsers.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SectionLabel(
              title: isSearching ? 'People' : 'Available people',
              count: filteredUsers.length,
            ),
            const SizedBox(height: 8),
            ...filteredUsers.map(
              (u) => _UserRow(
                user: u,
                query: query,
                isOnline: u.id != null && presence.onlineIds.contains(u.id!),
                onTap: () => onTapUser(u),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ArchivedHeader extends StatelessWidget {
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  const _ArchivedHeader({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.archive_rounded,
                  size: 18,
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Archived',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceColor,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppColors.onSurfaceMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiAssistantCard extends StatefulWidget {
  const _AiAssistantCard();

  @override
  State<_AiAssistantCard> createState() => _AiAssistantCardState();
}

class _AiAssistantCardState extends State<_AiAssistantCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            SmoothRoute(const AiChatScreen()),
          );
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_ctrl.value);
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryColor,
                    AppColors.primarySoft,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.secondaryColor
                      .withValues(alpha: 0.18 + 0.20 * t),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondaryColor
                        .withValues(alpha: 0.10 + 0.20 * t),
                    blurRadius: 18 + 16 * t,
                    spreadRadius: t * 1.5,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Row(
            children: [
              _AnimatedAiBadge(controller: _ctrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'AI Assistant',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                AppColors.secondaryColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'NEW',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AppColors.secondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ask anything — homework, ideas, code',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.secondaryColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  const _WelcomeBanner({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.secondaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.secondaryColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              gradient: AppColors.accentGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              size: 18,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Welcome to QuickChat',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your messages are end-to-end encrypted. '
                  'Try the AI assistant below — ask anything.',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    height: 1.35,
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            iconSize: 18,
            color: AppColors.onSurfaceMuted,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: count.toDouble()),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (_, value, _) {
        final shown = value.round();
        return Container(
          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppColors.accentShadow,
          ),
          alignment: Alignment.center,
          child: Text(
            shown > 99 ? '99+' : '$shown',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedAiBadge extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedAiBadge({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: controller,
            builder: (_, _) {
              final t = Curves.easeInOut.transform(controller.value);
              return Container(
                width: 52 + 6 * t,
                height: 52 + 6 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondaryColor
                      .withValues(alpha: 0.10 + 0.10 * t),
                ),
              );
            },
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              shape: BoxShape.circle,
              boxShadow: AppColors.accentShadow,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 26,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final int count;
  final int accentCount;
  final IconData? icon;

  const _SectionLabel({
    required this.title,
    required this.count,
    this.accentCount = 0,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.onSurfaceMuted),
            const SizedBox(width: 6),
          ],
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceColor,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: accentCount > 0
                ? Container(
                    key: ValueKey(accentCount),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.accentShadow,
                    ),
                    child: Text(
                      '$accentCount unread',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final ChatPreview preview;
  final String query;
  final bool isOnline;
  final bool pinned;
  final bool muted;
  final bool archived;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChatRow({
    required this.preview,
    required this.query,
    required this.isOnline,
    this.pinned = false,
    this.muted = false,
    this.archived = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final user = preview.otherUser;
    final lastMessage = preview.lastMessage;
    final lastTime = preview.lastMessageAt;
    final isOwnLast = preview.lastMessageMine;
    final unread = preview.unreadCount;
    final hasUnread = unread > 0;
    final deleted = preview.lastMessageDeleted;

    return Dismissible(
      key: ValueKey('chat-${preview.conversationId ?? user.id ?? user.email}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onLongPress();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.more_horiz_rounded,
              color: AppColors.onSurfaceMuted,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'Options',
              style: GoogleFonts.poppins(
                color: AppColors.onSurfaceMuted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            onLongPress();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Row(
              children: [
                _Avatar(
                  name: user.name,
                  size: 52,
                  isOnline: isOnline,
                  heroTag: user.id == null ? null : 'avatar-${user.id}',
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: _HighlightedText(
                              text: user.name ?? 'Unknown',
                              query: query,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: archived
                                    ? AppColors.onSurfaceMuted
                                    : AppColors.onSurfaceColor,
                              ),
                            ),
                          ),
                          if (pinned) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.push_pin_rounded,
                              size: 13,
                              color: AppColors.onSurfaceMuted,
                            ),
                          ],
                          if (muted) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.notifications_off_rounded,
                              size: 13,
                              color: AppColors.onSurfaceMuted,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (isOwnLast && !deleted && lastMessage != null) ...[
                            _MiniStatusIcon(status: preview.lastMessageStatus),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: deleted
                                ? Text(
                                    isOwnLast
                                        ? 'You deleted this message'
                                        : 'Message deleted',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.onSurfaceMuted,
                                    ),
                                  )
                                : _HighlightedText(
                                    text:
                                        lastMessage ?? 'Tap to start chatting',
                                    query: query,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: hasUnread
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: hasUnread
                                          ? AppColors.onSurfaceColor
                                          : AppColors.onSurfaceMuted,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (lastTime != null)
                      Text(
                        TimeFormat.chatListTime(lastTime),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.w400,
                          color: hasUnread
                              ? AppColors.secondaryVariantColor
                              : AppColors.onSurfaceMuted,
                        ),
                      ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: hasUnread
                          ? _UnreadBadge(
                              key: ValueKey('unread-${user.id}-$unread'),
                              count: unread,
                            )
                          : const SizedBox(height: 20),
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
}

class _MiniStatusIcon extends StatelessWidget {
  final MessageStatus status;
  const _MiniStatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(
          Icons.access_time_rounded,
          size: 13,
          color: AppColors.onSurfaceMuted,
        );
      case MessageStatus.sent:
        return Icon(
          Icons.done_all_rounded,
          size: 14,
          color: AppColors.onSurfaceMuted,
        );
      case MessageStatus.read:
        return Icon(
          Icons.done_all_rounded,
          size: 14,
          color: AppColors.secondaryVariantColor,
        );
    }
  }
}

class _UserRow extends StatelessWidget {
  final UserModel user;
  final String query;
  final bool isOnline;
  final VoidCallback onTap;

  const _UserRow({
    required this.user,
    required this.query,
    required this.isOnline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Row(
            children: [
              _Avatar(
                name: user.name,
                size: 44,
                isOnline: isOnline,
                heroTag: user.id == null ? null : 'avatar-${user.id}',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HighlightedText(
                      text: user.name ?? 'Unknown',
                      query: query,
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _HighlightedText(
                      text: user.email ?? '',
                      query: query,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  size: 14,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    var index = 0;
    while (index < text.length) {
      final found = lower.indexOf(query, index);
      if (found < 0) {
        spans.add(TextSpan(text: text.substring(index)));
        break;
      }
      if (found > index) {
        spans.add(TextSpan(text: text.substring(index, found)));
      }
      spans.add(TextSpan(
        text: text.substring(found, found + query.length),
        style: style.copyWith(
          color: AppColors.secondaryVariantColor,
          fontWeight: FontWeight.w700,
          backgroundColor:
              AppColors.secondaryColor.withValues(alpha: 0.20),
        ),
      ));
      index = found + query.length;
    }
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: style, children: spans),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? name;
  final double size;
  final bool isOnline;
  final String? heroTag;
  const _Avatar({
    required this.name,
    this.size = 48,
    this.isOnline = false,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final initial = (name?.isNotEmpty ?? false) ? name![0].toUpperCase() : '?';
    final core = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AvatarPalette.gradient(name ?? ''),
      ),
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          heroTag != null
              ? Hero(
                  tag: heroTag!,
                  flightShuttleBuilder: (_, _, _, _, _) => core,
                  child: core,
                )
              : core,
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
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
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: List.generate(7, (_) => const ChatRowShimmer()),
    );
  }
}

class _DashboardError extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _DashboardError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 38,
            color: AppColors.onSurfaceMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'Couldn\'t load your chats',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceColor,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondaryVariantColor,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'Try again',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.secondaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 36,
            color: AppColors.secondaryVariantColor,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.onSurfaceMuted,
          ),
        ),
      ],
    );
  }
}
