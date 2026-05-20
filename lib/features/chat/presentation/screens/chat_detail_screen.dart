import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/network_provider.dart';
import '../../../../core/utils/avatar_palette.dart';
import '../../../../core/utils/chat_wallpapers.dart';
import '../../../../core/utils/smooth_route.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/utils/user_prefs.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../call/presentation/screens/call_screen.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/presence_service.dart';
import '../../domain/entities/chat_preview.dart';
import '../providers/chat_provider.dart';
import '../widgets/attachments_sheet.dart';
import '../widgets/reactions_row.dart';
import 'starred_messages_screen.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final UserModel? otherUser;
  const ChatDetailScreen({super.key, required this.otherUser});

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _composerFocus = FocusNode();
  final ChatService _chatService = ChatService();

  String? _conversationId;
  UserModel? _currentUser;
  Stream<List<Map<String, dynamic>>>? _messages;
  List<Map<String, dynamic>> _cachedMessages = const [];
  String? _initError;
  bool _initializing = true;
  bool _showJumpToBottom = false;
  String? _lastIncomingMarked;
  Timer? _readDebounce;
  final Set<String> _animatedIds = <String>{};
  // Locally-rendered messages that haven't yet been mirrored back by the
  // realtime stream. Lets the UI feel instant even when the server lags.
  final List<Map<String, dynamic>> _pending = [];

  // Pro features (local-only)
  Map<String, dynamic>? _replyTo;
  Map<String, List<String>> _reactions = const {};
  Set<String> _starred = const {};
  ChatWallpaper _wallpaper = ChatWallpapers.palettes.first;
  bool _muted = false;
  bool _pinned = false;
  bool _searchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _recordingVoice = false;
  Timer? _recordingTicker;
  int _recordingSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeConversation();
    _messageController.addListener(() {
      if (mounted) setState(() {});
    });
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() => _searchQuery = _searchController.text.trim());
    });
    _scrollController.addListener(_onScroll);
    _loadProState();
  }

  Future<void> _loadProState() async {
    final wallpaperIdx = await UserPrefs.getWallpaper();
    final reactions = await UserPrefs.reactions();
    final starred = await UserPrefs.starredMessageIds();
    if (!mounted) return;
    setState(() {
      _wallpaper = ChatWallpapers.byIndex(wallpaperIdx);
      _reactions = reactions;
      _starred = starred;
    });
  }

  Future<void> _refreshConversationFlags(String cid) async {
    final muted = await UserPrefs.isMuted(cid);
    final pinned = await UserPrefs.isPinned(cid);
    if (!mounted) return;
    setState(() {
      _muted = muted;
      _pinned = pinned;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _conversationId != null) {
      _scheduleMarkRead();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readDebounce?.cancel();
    _recordingTicker?.cancel();
    if (_conversationId != null) {
      _chatService.markConversationRead(_conversationId!);
    }
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final shouldShow = _scrollController.position.pixels > 200;
    if (shouldShow != _showJumpToBottom) {
      setState(() => _showJumpToBottom = shouldShow);
    }
  }

  Future<void> _initializeConversation() async {
    try {
      _currentUser = await _chatService.getCurrentUser();
      if (widget.otherUser == null) {
        throw Exception('No user selected');
      }
      _conversationId = await _chatService.createConversation(
        _currentUser!,
        widget.otherUser!,
      );
      // Pull cached transcript so the chat appears populated immediately.
      final priorCache = _chatService.cachedMessages(_conversationId!);
      if (priorCache != null && mounted) {
        setState(() {
          _cachedMessages = priorCache;
        });
      }
      _messages = _chatService.receiveMessages(_conversationId!);
      _scheduleMarkRead();
      await _refreshConversationFlags(_conversationId!);
      if (mounted) {
        setState(() {
          _initializing = false;
          _initError = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      setState(() {
        _initializing = false;
        _initError = msg;
      });
    }
  }

  void _scheduleMarkRead() {
    _readDebounce?.cancel();
    _readDebounce = Timer(const Duration(milliseconds: 250), () {
      final cid = _conversationId;
      if (cid == null) return;
      _chatService.markConversationRead(cid);
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_conversationId == null || _currentUser == null) {
      AppDialogs.toast(
        context,
        _initError ?? 'Setting up conversation, please wait...',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    if (ref.read(isOfflineProvider)) {
      AppDialogs.toast(
        context,
        'You\'re offline. Connect to the internet to send messages.',
        icon: Icons.wifi_off_rounded,
        color: AppColors.errorColor,
      );
      return;
    }

    HapticFeedback.lightImpact();
    final localId = 'tmp-${DateTime.now().microsecondsSinceEpoch}';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // If replying, prefix the quote into the message body so the receiver
    // sees the context too (no backend change required for the MVP).
    var bodyToSend = text;
    final replyTo = _replyTo;
    if (replyTo != null) {
      final quoteRaw = (replyTo['content'] as String?) ?? '';
      final quote = quoteRaw.length > 120
          ? '${quoteRaw.substring(0, 117)}…'
          : quoteRaw;
      final cleaned = quote.split('\n').map((l) => '> $l').join('\n');
      bodyToSend = '$cleaned\n\n$text';
    }

    setState(() {
      _pending.add({
        'id': localId,
        'localId': localId,
        'senderId': _currentUser!.id,
        'content': bodyToSend,
        'createdAt': nowIso,
        'status': 'sending',
      });
      _messageController.clear();
      _replyTo = null;
    });
    _jumpToBottom();
    _doSend(localId, bodyToSend);
  }

  Future<void> _doSend(String localId, String text) async {
    try {
      final realId = await _chatService.sendMessage(
        _conversationId!,
        _currentUser!,
        text,
      );
      if (!mounted) return;
      setState(() {
        for (final p in _pending) {
          if (p['localId'] == localId) {
            if (realId != null) p['id'] = realId;
            p['status'] = 'sent';
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        for (final p in _pending) {
          if (p['localId'] == localId) p['status'] = 'failed';
        }
      });
      final msg = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  /// Combine the live stream snapshot with locally-pending messages, removing
  /// any pending entry the server has now confirmed (matched by id, or by
  /// content+timestamp window for the brief race before we know the real id).
  List<Map<String, dynamic>> _composeWithPending(
    List<Map<String, dynamic>> live,
  ) {
    if (_pending.isEmpty) return live;
    final liveIds = live.map((m) => m['id']?.toString()).toSet();
    final liveByContent = <String, List<DateTime>>{};
    for (final m in live) {
      if (m['senderId'] != _currentUser?.id) continue;
      final content = m['content'] as String? ?? '';
      final createdAtRaw = m['createdAt'];
      final createdAt = createdAtRaw is String
          ? DateTime.tryParse(createdAtRaw)
          : null;
      if (createdAt == null) continue;
      liveByContent.putIfAbsent(content, () => []).add(createdAt.toUtc());
    }

    final stillPending = <Map<String, dynamic>>[];
    final confirmed = <String>{};
    for (final p in _pending) {
      final pid = p['id']?.toString();
      if (pid != null && liveIds.contains(pid)) {
        confirmed.add(p['localId'] as String);
        continue;
      }
      final content = p['content'] as String? ?? '';
      final createdAtRaw = p['createdAt'];
      final createdAt = createdAtRaw is String
          ? DateTime.tryParse(createdAtRaw)
          : null;
      final times = liveByContent[content];
      if (createdAt != null && times != null) {
        final match = times.any(
          (t) => t.difference(createdAt.toUtc()).abs() <
              const Duration(seconds: 12),
        );
        if (match) {
          confirmed.add(p['localId'] as String);
          continue;
        }
      }
      stillPending.add(p);
    }

    if (confirmed.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _pending.removeWhere((p) => confirmed.contains(p['localId']));
        });
      });
    }

    return [...live, ...stillPending];
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Future<void> _onLongPressMessage(Map<String, dynamic> msg) async {
    HapticFeedback.mediumImpact();
    final isOutgoing = msg['senderId'] == _currentUser?.id;
    final id = msg['id']?.toString();
    final text = (msg['content'] as String?) ?? '';
    final isDeleted = (msg['deletedForEveryone'] as bool? ?? false) ||
        msg['deletedAt'] != null;
    if (id == null) return;
    final isStarred = _starred.contains(id);

    final action = await showCupertinoModalPopup<Object>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: !isDeleted
            ? Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ReactionPickerBar(
                  onPick: (emoji) =>
                      Navigator.pop(context, _ReactionPick(emoji)),
                ),
              )
            : null,
        actions: [
          if (!isDeleted)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, _BubbleAction.reply),
              child: Text(
                'Reply',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          if (!isDeleted)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, _BubbleAction.forward),
              child: Text(
                'Forward',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          if (!isDeleted)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, _BubbleAction.star),
              child: Text(
                isStarred ? 'Unstar' : 'Star',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          if (!isDeleted)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, _BubbleAction.copy),
              child: Text(
                'Copy',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          if (isOutgoing && !isDeleted)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () =>
                  Navigator.pop(context, _BubbleAction.deleteEveryone),
              child: Text(
                'Delete for everyone',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          if (isOutgoing && !isDeleted)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, _BubbleAction.deleteMe),
              child: Text(
                'Delete for me',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(
            AppStrings.cancel,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;

    if (action is _ReactionPick) {
      await _onReact(msg, action.emoji);
      return;
    }
    if (action is! _BubbleAction) return;

    switch (action) {
      case _BubbleAction.reply:
        _setReplyTo(msg);
        break;
      case _BubbleAction.react:
        break;
      case _BubbleAction.star:
        await _toggleStar(msg);
        break;
      case _BubbleAction.forward:
        AppDialogs.toast(context, 'Forward — coming soon',
            icon: Icons.forward_to_inbox_rounded);
        break;
      case _BubbleAction.copy:
        Clipboard.setData(ClipboardData(text: text));
        AppDialogs.toast(context, 'Message copied',
            icon: Icons.copy_rounded);
        break;
      case _BubbleAction.deleteEveryone:
        final ok = await AppDialogs.confirm(
          context,
          title: 'Delete for everyone?',
          message:
              'This message will be removed for both you and the recipient.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!ok || !mounted) return;
        try {
          await _chatService.deleteMessageForEveryone(id);
        } catch (e) {
          if (!mounted) return;
          AppDialogs.info(
            context,
            title: 'Couldn\'t delete',
            message: e is Exception
                ? e.toString().replaceFirst('Exception: ', '')
                : e.toString(),
          );
        }
        break;
      case _BubbleAction.deleteMe:
        final ok = await AppDialogs.confirm(
          context,
          title: 'Delete for me?',
          message: 'This message will be hidden on your device only.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!ok || !mounted) return;
        try {
          await _chatService.deleteMessageForMe(id);
        } catch (e) {
          if (!mounted) return;
          AppDialogs.info(
            context,
            title: 'Couldn\'t delete',
            message: e is Exception
                ? e.toString().replaceFirst('Exception: ', '')
                : e.toString(),
          );
        }
        break;
    }
  }

  Future<void> _startCall(CallMode mode) async {
    HapticFeedback.mediumImpact();
    final other = widget.otherUser;
    if (other == null) return;
    final blocked = other.id != null && await UserPrefs.isBlocked(other.id!);
    if (!mounted) return;
    if (blocked) {
      AppDialogs.toast(
        context,
        'Unblock this user to start a call',
        icon: Icons.block_rounded,
        color: AppColors.errorColor,
      );
      return;
    }
    await Navigator.push(
      context,
      SmoothRoute(CallScreen(otherUser: other, mode: mode)),
    );
  }

  Future<void> _toggleBlock() async {
    HapticFeedback.mediumImpact();
    final other = widget.otherUser;
    final id = other?.id;
    if (id == null) return;
    final isBlocked = await UserPrefs.isBlocked(id);
    if (!mounted) return;
    final ok = await AppDialogs.confirm(
      context,
      title: isBlocked
          ? 'Unblock ${other?.name ?? "this user"}?'
          : 'Block ${other?.name ?? "this user"}?',
      message: isBlocked
          ? 'They will be able to message you again.'
          : 'They won\'t be able to message or call you. Existing messages stay.',
      confirmLabel: isBlocked ? 'Unblock' : 'Block',
      destructive: !isBlocked,
    );
    if (!ok || !mounted) return;
    if (isBlocked) {
      await UserPrefs.unblock(id);
    } else {
      await UserPrefs.block(id);
    }
    if (!mounted) return;
    AppDialogs.toast(
      context,
      isBlocked ? 'User unblocked' : 'User blocked',
      icon: isBlocked ? Icons.check_rounded : Icons.block_rounded,
    );
    // Make sure the dashboard re-renders without the blocked user.
    // ignore: unused_result
    ref.refresh(dashboardProvider);
  }

  void _setReplyTo(Map<String, dynamic>? msg) {
    HapticFeedback.selectionClick();
    setState(() => _replyTo = msg);
    if (msg != null) {
      _composerFocus.requestFocus();
    }
  }

  Future<void> _onReact(Map<String, dynamic> msg, String emoji) async {
    final id = msg['id']?.toString();
    if (id == null) return;
    HapticFeedback.selectionClick();
    await UserPrefs.toggleReaction(id, emoji);
    final updated = await UserPrefs.reactions();
    if (!mounted) return;
    setState(() => _reactions = updated);
  }

  Future<void> _clearReactionsFor(Map<String, dynamic> msg) async {
    final id = msg['id']?.toString();
    if (id == null) return;
    await UserPrefs.clearReactions(id);
    final updated = await UserPrefs.reactions();
    if (!mounted) return;
    setState(() => _reactions = updated);
  }

  Future<void> _toggleStar(Map<String, dynamic> msg) async {
    final id = msg['id']?.toString();
    if (id == null) return;
    HapticFeedback.lightImpact();
    final wasStarred = _starred.contains(id);
    if (wasStarred) {
      await UserPrefs.unstar(id);
    } else {
      await UserPrefs.star(id);
    }
    final updated = await UserPrefs.starredMessageIds();
    if (!mounted) return;
    setState(() => _starred = updated);
    AppDialogs.toast(
      context,
      wasStarred ? 'Unstarred' : 'Starred',
      icon: wasStarred
          ? Icons.star_border_rounded
          : Icons.star_rounded,
    );
  }

  void _openAttachments() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AttachmentsSheet(onPick: _onAttachmentPicked),
    );
  }

  void _onAttachmentPicked(AttachmentKind kind) {
    String placeholder;
    switch (kind) {
      case AttachmentKind.photo:
        placeholder = '📷 Photo (shared via QuickChat)';
        break;
      case AttachmentKind.camera:
        placeholder = '📸 Snapshot (taken just now)';
        break;
      case AttachmentKind.document:
        placeholder = '📄 Document.pdf (1.2 MB)';
        break;
      case AttachmentKind.audio:
        placeholder = '🎵 Audio clip';
        break;
      case AttachmentKind.location:
        placeholder = '📍 Shared location';
        break;
      case AttachmentKind.contact:
        placeholder = '👤 Contact card';
        break;
      case AttachmentKind.poll:
        placeholder = '📊 Poll: What\'s your favorite chat app? 🚀';
        break;
      case AttachmentKind.gift:
        placeholder = '🎁 Sent a gift!';
        break;
    }
    _messageController.text = placeholder;
    _messageController.selection =
        TextSelection.collapsed(offset: placeholder.length);
    _sendMessage();
  }

  void _startVoiceRecording() {
    HapticFeedback.mediumImpact();
    setState(() {
      _recordingVoice = true;
      _recordingSeconds = 0;
    });
    _recordingTicker?.cancel();
    _recordingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordingSeconds++);
    });
  }

  void _cancelVoiceRecording() {
    HapticFeedback.heavyImpact();
    _recordingTicker?.cancel();
    setState(() {
      _recordingVoice = false;
      _recordingSeconds = 0;
    });
  }

  void _sendVoiceRecording() {
    final secs = _recordingSeconds;
    _recordingTicker?.cancel();
    setState(() {
      _recordingVoice = false;
      _recordingSeconds = 0;
    });
    if (secs < 1) {
      AppDialogs.toast(
        context,
        'Hold the mic to record',
        icon: Icons.mic_off_outlined,
      );
      return;
    }
    final mm = (secs ~/ 60).toString().padLeft(2, '0');
    final ss = (secs % 60).toString().padLeft(2, '0');
    _messageController.text = '🎤 Voice message ($mm:$ss)';
    _messageController.selection = TextSelection.collapsed(
      offset: _messageController.text.length,
    );
    _sendMessage();
  }

  Future<void> _openWallpaperPicker() async {
    HapticFeedback.lightImpact();
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return AppBottomSheet(
          title: 'Chat wallpaper',
          child: SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: ChatWallpapers.palettes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final w = ChatWallpapers.palettes[i];
                final selected = w.name == _wallpaper.name;
                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, i),
                  child: SizedBox(
                    width: 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: w.gradient,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? AppColors.secondaryVariantColor
                                    : AppColors.borderColor,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: selected
                                ? const Center(
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.secondaryVariantColor,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          w.name,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    await UserPrefs.setWallpaper(picked);
    if (!mounted) return;
    setState(() => _wallpaper = ChatWallpapers.byIndex(picked));
  }

  Future<void> _togglePin() async {
    final cid = _conversationId;
    if (cid == null) return;
    HapticFeedback.lightImpact();
    if (_pinned) {
      await UserPrefs.unpin(cid);
    } else {
      await UserPrefs.pin(cid);
    }
    await _refreshConversationFlags(cid);
    if (!mounted) return;
    AppDialogs.toast(
      context,
      _pinned ? 'Chat pinned' : 'Chat unpinned',
      icon: _pinned
          ? Icons.push_pin_rounded
          : Icons.push_pin_outlined,
    );
    // ignore: unused_result
    ref.refresh(dashboardProvider);
  }

  Future<void> _toggleMute() async {
    final cid = _conversationId;
    if (cid == null) return;
    HapticFeedback.lightImpact();
    if (_muted) {
      await UserPrefs.unmute(cid);
    } else {
      await UserPrefs.mute(cid);
    }
    await _refreshConversationFlags(cid);
    if (!mounted) return;
    AppDialogs.toast(
      context,
      _muted ? 'Chat muted' : 'Chat unmuted',
      icon: _muted
          ? Icons.notifications_off_rounded
          : Icons.notifications_active_rounded,
    );
  }

  void _toggleSearch() {
    HapticFeedback.selectionClick();
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  Future<void> _onHeaderMore() async {
    HapticFeedback.mediumImpact();
    final cid = _conversationId;
    if (cid == null) return;
    final id = widget.otherUser?.id;
    final isBlocked = id == null ? false : await UserPrefs.isBlocked(id);
    if (!mounted) return;
    final action = await showCupertinoModalPopup<_HeaderAction>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          widget.otherUser?.name ?? 'Chat',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, _HeaderAction.voiceCall),
            child: Text(
              'Voice call',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, _HeaderAction.videoCall),
            child: Text(
              'Video call',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, _HeaderAction.searchInChat),
            child: Text(
              'Search in chat',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, _HeaderAction.wallpaper),
            child: Text(
              'Chat wallpaper',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, _HeaderAction.pin),
            child: Text(
              _pinned ? 'Unpin chat' : 'Pin chat',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, _HeaderAction.mute),
            child: Text(
              _muted ? 'Unmute notifications' : 'Mute notifications',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, _HeaderAction.starred),
            child: Text(
              'Starred messages',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: !isBlocked,
            onPressed: () => Navigator.pop(context, _HeaderAction.block),
            child: Text(
              isBlocked ? 'Unblock user' : 'Block user',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, _HeaderAction.clear),
            child: Text(
              'Delete chat',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(
            AppStrings.cancel,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _HeaderAction.voiceCall:
        await _startCall(CallMode.voice);
        break;
      case _HeaderAction.videoCall:
        await _startCall(CallMode.video);
        break;
      case _HeaderAction.searchInChat:
        _toggleSearch();
        break;
      case _HeaderAction.wallpaper:
        await _openWallpaperPicker();
        break;
      case _HeaderAction.pin:
        await _togglePin();
        break;
      case _HeaderAction.mute:
        await _toggleMute();
        break;
      case _HeaderAction.starred:
        await Navigator.push(
          context,
          SmoothRoute(const StarredMessagesScreen()),
        );
        if (!mounted) return;
        await _loadProState();
        break;
      case _HeaderAction.block:
        await _toggleBlock();
        break;
      case _HeaderAction.clear:
        final ok = await AppDialogs.confirm(
          context,
          title: 'Delete this chat?',
          message:
              'Messages will be removed from your device. The other person can still see them.',
          confirmLabel: 'Delete chat',
          destructive: true,
        );
        if (!ok || !mounted) return;
        try {
          await _chatService.clearConversationForMe(cid);
          if (!mounted) return;
          Navigator.pop(context);
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
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _messageController.text.trim().isNotEmpty;
    final ready = _conversationId != null && _currentUser != null;
    final canSend = hasText && ready && !_initializing;
    final topInset = MediaQuery.of(context).padding.top;
    final headerHeight = topInset + 70;
    final presence = ref.watch(presenceProvider).maybeWhen(
          data: (s) => s,
          orElse: () => PresenceSnapshot.empty,
        );
    final otherId = widget.otherUser?.id;
    final isOnline = otherId != null && presence.onlineIds.contains(otherId);
    final lastSeen = otherId == null ? null : presence.lastSeen[otherId];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surfaceMuted,
        resizeToAvoidBottomInset: true,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(headerHeight),
          child: _ChatHeader(
            otherUser: widget.otherUser,
            topInset: topInset,
            isOnline: isOnline,
            lastSeen: lastSeen,
            muted: _muted,
            pinned: _pinned,
            onMore: _onHeaderMore,
            onSearch: _toggleSearch,
            onVoiceCall: () => _startCall(CallMode.voice),
            onVideoCall: () => _startCall(CallMode.video),
          ),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _composerFocus.unfocus(),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: _wallpaper.gradient),
                ),
              ),
              Positioned.fill(
                child: _ChatBackground(color: _wallpaper.patternColor()),
              ),
              Column(
                children: [
                  if (_searchOpen)
                    _ChatSearchBar(
                      controller: _searchController,
                      onClose: _toggleSearch,
                    ),
                  Expanded(
                    child: _conversationId == null || _messages == null
                        ? (_cachedMessages.isEmpty
                            ? const _MessagesShimmer()
                            : _MessagesList(
                                messages: _filterBySearch(
                                  _composeWithPending(_cachedMessages),
                                ),
                                currentUserId: _currentUser?.id,
                                controller: _scrollController,
                                onLongPress: _onLongPressMessage,
                                onSwipeReply: _setReplyTo,
                                onClearReactions: _clearReactionsFor,
                                animatedIds: _animatedIds,
                                reactions: _reactions,
                                starred: _starred,
                                searchQuery: _searchQuery,
                                wallpaperDark: _wallpaper.dark,
                              ))
                        : StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _messages,
                            builder: (context, snapshot) {
                              final live = snapshot.data ??
                                  (snapshot.connectionState ==
                                              ConnectionState.waiting
                                          ? _cachedMessages
                                          : const <Map<String, dynamic>>[]);
                              final composed = _composeWithPending(live);
                              final filtered = _filterBySearch(composed);

                              if (filtered.isEmpty) {
                                if (snapshot.connectionState ==
                                        ConnectionState.waiting &&
                                    !snapshot.hasData &&
                                    _cachedMessages.isEmpty) {
                                  return const _MessagesShimmer();
                                }
                                if (_searchQuery.isNotEmpty &&
                                    composed.isNotEmpty) {
                                  return const _SearchEmpty();
                                }
                                return const _EmptyMessages();
                              }

                              // Whenever we receive a message from the other
                              // user we mark the convo as read (with debounce).
                              final newestIncoming = _findNewestIncoming(
                                live,
                                _currentUser?.id,
                              );
                              if (newestIncoming != null &&
                                  newestIncoming != _lastIncomingMarked) {
                                _lastIncomingMarked = newestIncoming;
                                _scheduleMarkRead();
                              }

                              return _MessagesList(
                                messages: filtered,
                                currentUserId: _currentUser?.id,
                                controller: _scrollController,
                                onLongPress: _onLongPressMessage,
                                onSwipeReply: _setReplyTo,
                                onClearReactions: _clearReactionsFor,
                                animatedIds: _animatedIds,
                                reactions: _reactions,
                                starred: _starred,
                                searchQuery: _searchQuery,
                                wallpaperDark: _wallpaper.dark,
                              );
                            },
                          ),
                  ),
                  if (_initError != null)
                    _InitErrorBanner(
                      message: _initError!,
                      onRetry: () {
                        setState(() {
                          _initializing = true;
                          _initError = null;
                        });
                        _initializeConversation();
                      },
                    ),
                  if (_replyTo != null)
                    _ReplyPreview(
                      message: _replyTo!,
                      isMine: _replyTo!['senderId'] == _currentUser?.id,
                      onCancel: () => _setReplyTo(null),
                    ),
                  _Composer(
                    controller: _messageController,
                    focusNode: _composerFocus,
                    canSend: canSend,
                    isSending: false,
                    recording: _recordingVoice,
                    recordingSeconds: _recordingSeconds,
                    onSend: _sendMessage,
                    onPickEmoji: _insertEmoji,
                    onAttach: _openAttachments,
                    onVoiceStart: _startVoiceRecording,
                    onVoiceEnd: _sendVoiceRecording,
                    onVoiceCancel: _cancelVoiceRecording,
                  ),
                ],
              ),
              Positioned(
                right: 14,
                bottom: 86,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  offset:
                      _showJumpToBottom ? Offset.zero : const Offset(0, 1.4),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _showJumpToBottom ? 1 : 0,
                    child: _JumpToBottom(onTap: _jumpToBottom),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _findNewestIncoming(
      List<Map<String, dynamic>> messages, String? me) {
    if (me == null) return null;
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m['senderId'] != me) return m['id']?.toString();
    }
    return null;
  }

  List<Map<String, dynamic>> _filterBySearch(
    List<Map<String, dynamic>> messages,
  ) {
    final q = _searchQuery.toLowerCase();
    if (q.isEmpty) return messages;
    return messages.where((m) {
      final c = (m['content'] as String? ?? '').toLowerCase();
      return c.contains(q);
    }).toList();
  }

  void _insertEmoji(String emoji) {
    HapticFeedback.selectionClick();
    final selection = _messageController.selection;
    final text = _messageController.text;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final newText = text.replaceRange(start, end, emoji);
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }
}

enum _BubbleAction { reply, react, star, forward, copy, deleteEveryone, deleteMe }

class _ReactionPick {
  final String emoji;
  const _ReactionPick(this.emoji);
}

enum _HeaderAction {
  voiceCall,
  videoCall,
  searchInChat,
  wallpaper,
  pin,
  mute,
  starred,
  block,
  clear,
}

class _ChatHeader extends StatelessWidget {
  final UserModel? otherUser;
  final double topInset;
  final bool isOnline;
  final DateTime? lastSeen;
  final bool muted;
  final bool pinned;
  final VoidCallback onMore;
  final VoidCallback onSearch;
  final VoidCallback onVoiceCall;
  final VoidCallback onVideoCall;

  const _ChatHeader({
    required this.otherUser,
    required this.topInset,
    required this.isOnline,
    required this.lastSeen,
    required this.muted,
    required this.pinned,
    required this.onMore,
    required this.onSearch,
    required this.onVoiceCall,
    required this.onVideoCall,
  });

  @override
  Widget build(BuildContext context) {
    final initial = (otherUser?.name?.isNotEmpty ?? false)
        ? otherUser!.name![0].toUpperCase()
        : '?';
    final subtitle = isOnline
        ? 'Online'
        : (lastSeen == null
            ? 'End-to-end encrypted'
            : TimeFormat.lastSeen(lastSeen, isOnline: false));
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.darkGradient),
      padding: EdgeInsets.only(top: topInset),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                children: [
                  Hero(
                    tag: otherUser?.id == null
                        ? 'avatar-anon-${otherUser?.email ?? "unknown"}'
                        : 'avatar-${otherUser!.id!}',
                    flightShuttleBuilder: (_, _, _, _, _) => Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                            AvatarPalette.gradient(otherUser?.name ?? ''),
                      ),
                      child: Text(
                        initial,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                            AvatarPalette.gradient(otherUser?.name ?? ''),
                      ),
                      child: Text(
                        initial,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.successColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          otherUser?.name ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (pinned) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.push_pin_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                      if (muted) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.notifications_off_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: Row(
                      key: ValueKey(subtitle),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isOnline)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.secondaryColor
                                      .withValues(alpha: 0.6),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          )
                        else
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 11,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        if (!isOnline) const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: isOnline
                                  ? AppColors.secondaryColor
                                  : Colors.white.withValues(alpha: 0.65),
                              fontWeight: isOnline
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Search',
              padding: const EdgeInsets.symmetric(horizontal: 6),
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 22,
              ),
              onPressed: onSearch,
            ),
            IconButton(
              tooltip: 'Voice call',
              padding: const EdgeInsets.symmetric(horizontal: 6),
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.call_rounded,
                color: Colors.white,
                size: 22,
              ),
              onPressed: onVoiceCall,
            ),
            IconButton(
              tooltip: 'Video call',
              padding: const EdgeInsets.symmetric(horizontal: 6),
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.videocam_rounded,
                color: Colors.white,
                size: 24,
              ),
              onPressed: onVideoCall,
            ),
            IconButton(
              tooltip: 'More',
              padding: const EdgeInsets.symmetric(horizontal: 6),
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Colors.white,
              ),
              onPressed: onMore,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _ChatBackground extends StatelessWidget {
  final Color color;
  const _ChatBackground({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackgroundPainter(color: color),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  static const _icons = [
    Icons.chat_bubble_outline_rounded,
    Icons.favorite_border_rounded,
    Icons.lock_outline_rounded,
    Icons.send_rounded,
  ];

  final Color color;
  _BackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const tile = 88.0;

    for (var y = 0.0, row = 0; y < size.height + tile; y += tile, row++) {
      for (var x = 0.0, col = 0; x < size.width + tile; x += tile, col++) {
        final icon = _icons[(row + col) % _icons.length];
        final dx = x + (row.isEven ? 0 : tile / 2);
        final tp = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              color: color,
              fontSize: 22,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(dx, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _MessagesList extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final String? currentUserId;
  final ScrollController controller;
  final void Function(Map<String, dynamic> msg) onLongPress;
  final void Function(Map<String, dynamic> msg) onSwipeReply;
  final void Function(Map<String, dynamic> msg) onClearReactions;
  final Set<String> animatedIds;
  final Map<String, List<String>> reactions;
  final Set<String> starred;
  final String searchQuery;
  final bool wallpaperDark;

  const _MessagesList({
    required this.messages,
    required this.currentUserId,
    required this.controller,
    required this.onLongPress,
    required this.onSwipeReply,
    required this.onClearReactions,
    required this.animatedIds,
    required this.reactions,
    required this.starred,
    required this.searchQuery,
    required this.wallpaperDark,
  });

  @override
  Widget build(BuildContext context) {
    final reversed = List<Map<String, dynamic>>.from(messages.reversed);

    return ListView.builder(
      reverse: true,
      controller: controller,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      itemCount: reversed.length,
      itemBuilder: (context, index) {
        final msg = reversed[index];
        final isOutgoing = msg['senderId'] == currentUserId;
        final older = index < reversed.length - 1 ? reversed[index + 1] : null;
        final showTail =
            older == null || older['senderId'] != msg['senderId'];

        final createdAtRaw = msg['createdAt'];
        final createdAt = createdAtRaw is String
            ? DateTime.tryParse(createdAtRaw)
            : null;
        final olderRaw = older?['createdAt'];
        final olderAt =
            olderRaw is String ? DateTime.tryParse(olderRaw) : null;
        final showDate = createdAt != null &&
            (olderAt == null || !_sameDay(createdAt, olderAt));

        final id = msg['id']?.toString();
        final isFresh = id != null && !animatedIds.contains(id);
        if (id != null) animatedIds.add(id);
        final text = (msg['content'] as String?) ?? '';
        final readAtRaw = msg['readAt'] as String?;
        final readAt =
            readAtRaw == null ? null : DateTime.tryParse(readAtRaw);
        final deletedForEveryone =
            (msg['deletedForEveryone'] as bool?) ?? false;
        final deletedAt = msg['deletedAt'] as String?;
        final isDeleted = deletedForEveryone || deletedAt != null;

        final pendingStatus = msg['status'] as String?;
        final status = isOutgoing
            ? (pendingStatus == 'sending' || pendingStatus == 'failed'
                ? MessageStatus.sending
                : (readAt != null ? MessageStatus.read : MessageStatus.sent))
            : MessageStatus.sent;

        final msgId = msg['id']?.toString();
        final isStarred = msgId != null && starred.contains(msgId);
        final reactionEmojis = msgId == null
            ? const <String>[]
            : (reactions[msgId] ?? const <String>[]);

        Widget bubble = _MessageBubble(
          text: text,
          isOutgoing: isOutgoing,
          isDeleted: isDeleted,
          showTail: showTail,
          createdAt: createdAt,
          status: status,
          starred: isStarred,
          searchQuery: searchQuery,
          onLongPress: isDeleted ? null : () => onLongPress(msg),
        );
        if (isFresh) {
          bubble = _BubbleEntrance(child: bubble);
        }

        if (!isDeleted) {
          bubble = _SwipeToReply(
            isOutgoing: isOutgoing,
            onTrigger: () => onSwipeReply(msg),
            child: bubble,
          );
        }

        return Column(
          children: [
            bubble,
            if (reactionEmojis.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  top: 2,
                  bottom: 2,
                  left: isOutgoing ? 0 : 14,
                  right: isOutgoing ? 14 : 0,
                ),
                child: ReactionsRow(
                  emojis: reactionEmojis,
                  alignEnd: isOutgoing,
                  onTap: () => onClearReactions(msg),
                ),
              ),
            if (showDate) _DaySeparator(date: createdAt),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }
}

class _BubbleEntrance extends StatefulWidget {
  final Widget child;
  const _BubbleEntrance({required this.child});

  @override
  State<_BubbleEntrance> createState() => _BubbleEntranceState();
}

class _BubbleEntranceState extends State<_BubbleEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    return AnimatedBuilder(
      animation: curve,
      builder: (_, child) {
        final v = curve.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: _controller.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 8),
            child: Transform.scale(
              scale: 0.96 + 0.04 * v,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _DaySeparator extends StatelessWidget {
  final DateTime? date;
  const _DaySeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();
    final local = date!.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final daysAgo = today.difference(that).inDays;
    final label = daysAgo == 0
        ? 'Today'
        : daysAgo == 1
            ? 'Yesterday'
            : DateFormat.yMMMd().format(local);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceMuted,
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isOutgoing;
  final bool isDeleted;
  final bool showTail;
  final DateTime? createdAt;
  final MessageStatus status;
  final bool starred;
  final String searchQuery;
  final VoidCallback? onLongPress;

  const _MessageBubble({
    required this.text,
    required this.isOutgoing,
    required this.isDeleted,
    required this.showTail,
    required this.status,
    required this.starred,
    required this.searchQuery,
    required this.onLongPress,
    this.createdAt,
  });

  /// Split a message body into (quote, body) tuples when it starts with one or
  /// more lines prefixed by "> " — that's the reply-quote convention.
  static (String?, String) _splitQuote(String input) {
    final lines = input.split('\n');
    final quoteLines = <String>[];
    var i = 0;
    while (i < lines.length && lines[i].startsWith('> ')) {
      quoteLines.add(lines[i].substring(2));
      i++;
    }
    if (quoteLines.isEmpty) return (null, input);
    // Skip blank separator line between quote and body if present.
    while (i < lines.length && lines[i].trim().isEmpty) {
      i++;
    }
    return (quoteLines.join('\n'), lines.skip(i).join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    final radius = const Radius.circular(18);
    final timeColor = isOutgoing
        ? Colors.black.withValues(alpha: 0.55)
        : AppColors.onSurfaceMuted;

    final split = isDeleted ? (null, text) : _splitQuote(text);
    final quoteText = split.$1;
    final bodyText = split.$2;
    final mainColor = isOutgoing ? Colors.black : AppColors.onSurfaceColor;

    final body = isDeleted
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.block_rounded,
                size: 14,
                color: isOutgoing
                    ? Colors.black.withValues(alpha: 0.55)
                    : AppColors.onSurfaceMuted,
              ),
              const SizedBox(width: 6),
              Text(
                isOutgoing ? 'You deleted this message' : 'Message deleted',
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontStyle: FontStyle.italic,
                  color: isOutgoing
                      ? Colors.black.withValues(alpha: 0.65)
                      : AppColors.onSurfaceMuted,
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (quoteText != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isOutgoing ? Colors.black : AppColors.onSurfaceColor)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: (isOutgoing
                                ? Colors.black
                                : AppColors.secondaryVariantColor)
                            .withValues(alpha: 0.7),
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    quoteText,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: mainColor.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
              _HighlightedBubbleText(
                text: bodyText,
                query: searchQuery,
                style: GoogleFonts.poppins(
                  fontSize: 14.5,
                  color: mainColor,
                  height: 1.35,
                ),
              ),
            ],
          );

    return Padding(
      padding: EdgeInsets.only(top: showTail ? 8 : 2),
      child: Align(
        alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onLongPress: onLongPress,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isOutgoing && !isDeleted
                      ? AppColors.accentGradient
                      : null,
                  color: isOutgoing && !isDeleted
                      ? null
                      : (isDeleted
                          ? AppColors.surfaceMuted
                          : AppColors.surfaceColor),
                  borderRadius: BorderRadius.only(
                    topLeft: radius,
                    topRight: radius,
                    bottomLeft: Radius.circular(
                        isOutgoing ? 18 : (showTail ? 4 : 18)),
                    bottomRight: Radius.circular(
                        isOutgoing ? (showTail ? 4 : 18) : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    body,
                    if (createdAt != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (starred) ...[
                            Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: isOutgoing
                                  ? Colors.black.withValues(alpha: 0.65)
                                  : AppColors.secondaryVariantColor,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            TimeFormat.bubbleTime(createdAt!),
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              color: timeColor,
                            ),
                          ),
                          if (isOutgoing && !isDeleted) ...[
                            const SizedBox(width: 4),
                            _StatusTicks(
                              status: status,
                              outgoingDarkBubble: true,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusTicks extends StatelessWidget {
  final MessageStatus status;
  final bool outgoingDarkBubble;
  const _StatusTicks({
    required this.status,
    required this.outgoingDarkBubble,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(
          Icons.access_time_rounded,
          size: 13,
          color: Colors.black.withValues(alpha: 0.55),
        );
      case MessageStatus.sent:
        return Icon(
          Icons.done_all_rounded,
          size: 14,
          color: Colors.black.withValues(alpha: 0.55),
        );
      case MessageStatus.read:
        return Icon(
          Icons.done_all_rounded,
          size: 14,
          color: const Color(0xFF1F6FE0), // iMessage-like blue read indicator
        );
    }
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool canSend;
  final bool isSending;
  final bool recording;
  final int recordingSeconds;
  final VoidCallback onSend;
  final void Function(String emoji) onPickEmoji;
  final VoidCallback onAttach;
  final VoidCallback onVoiceStart;
  final VoidCallback onVoiceEnd;
  final VoidCallback onVoiceCancel;

  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.canSend,
    required this.isSending,
    required this.recording,
    required this.recordingSeconds,
    required this.onSend,
    required this.onPickEmoji,
    required this.onAttach,
    required this.onVoiceStart,
    required this.onVoiceEnd,
    required this.onVoiceCancel,
  });

  String _formatSeconds(int s) {
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (recording)
            _RecordingOverlay(
              seconds: recordingSeconds,
              onCancel: onVoiceCancel,
              onSend: onVoiceEnd,
              formatted: _formatSeconds(recordingSeconds),
            )
          else
            _EmojiQuickBar(onPick: onPickEmoji),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _CircleButton(
                  icon: Icons.add_rounded,
                  onPressed: recording ? null : onAttach,
                  tooltip: 'Attach',
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 50),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: !recording,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      minLines: 1,
                      maxLines: 5,
                      cursorColor: AppColors.secondaryVariantColor,
                      cursorWidth: 1.6,
                      cursorRadius: const Radius.circular(2),
                      decoration: InputDecoration(
                        hintText: AppStrings.typeAMessage,
                        hintStyle: GoogleFonts.poppins(
                          color: AppColors.onSurfaceMuted,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: hasText || recording
                      ? _SendButton(
                          key: const ValueKey('send'),
                          canSend: canSend,
                          isSending: isSending,
                          onSend: onSend,
                        )
                      : _VoiceHoldButton(
                          key: const ValueKey('mic'),
                          onStart: onVoiceStart,
                          onEnd: onVoiceEnd,
                          onCancel: onVoiceCancel,
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

class _SendButton extends StatelessWidget {
  final bool canSend;
  final bool isSending;
  final VoidCallback onSend;

  const _SendButton({
    super.key,
    required this.canSend,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      scale: canSend ? 1 : 0.92,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: canSend ? 1 : 0.45,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: canSend ? AppColors.accentGradient : null,
            color: canSend ? null : AppColors.surfaceMuted,
            shape: BoxShape.circle,
            boxShadow: canSend ? AppColors.accentShadow : null,
          ),
          child: IconButton(
            icon: isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(
                    CupertinoIcons.arrow_up,
                    color: Colors.black,
                    size: 22,
                  ),
            onPressed: canSend && !isSending ? onSend : null,
          ),
        ),
      ),
    );
  }
}

class _VoiceHoldButton extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onCancel;

  const _VoiceHoldButton({
    super.key,
    required this.onStart,
    required this.onEnd,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => onStart(),
      onLongPressEnd: (_) => onEnd(),
      onLongPressCancel: onCancel,
      onTap: () {
        // Quick-tap hint for users who don't realise hold-to-record.
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            duration: const Duration(milliseconds: 1400),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: const Text('Hold the mic to record a voice message'),
          ),
        );
      },
      child: Container(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          shape: BoxShape.circle,
          boxShadow: AppColors.accentShadow,
        ),
        child: const Icon(
          Icons.mic_rounded,
          color: Colors.black,
          size: 22,
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: AppColors.softShadow,
        ),
        child: Icon(
          icon,
          size: 22,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _RecordingOverlay extends StatelessWidget {
  final int seconds;
  final String formatted;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  const _RecordingOverlay({
    required this.seconds,
    required this.formatted,
    required this.onCancel,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.errorColor.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          _PulseDot(),
          const SizedBox(width: 10),
          Text(
            'Recording  $formatted',
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.errorColor,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.onSurfaceMuted,
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: seconds < 1 ? null : onSend,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryColor,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Send',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.errorColor.withValues(
              alpha: 0.4 + 0.6 * _c.value,
            ),
          ),
        );
      },
    );
  }
}

class _EmojiQuickBar extends StatelessWidget {
  static const _emojis = [
    '👍', '❤️', '😂', '🔥', '🎉', '😮', '🙏', '👏', '😎', '✨', '💯', '😢',
  ];

  final void Function(String emoji) onPick;
  const _EmojiQuickBar({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _emojis.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final e = _emojis[i];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onPick(e),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.borderColor.withValues(alpha: 0.6),
                  ),
                ),
                child: Text(e, style: const TextStyle(fontSize: 18)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InitErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InitErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.errorColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.errorColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.errorColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Couldn\'t open chat',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceColor,
                  ),
                ),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.errorColor,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(
              'Retry',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JumpToBottom extends StatelessWidget {
  final VoidCallback onTap;
  const _JumpToBottom({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceColor,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.onSurfaceColor,
          ),
        ),
      ),
    );
  }
}

class _MessagesShimmer extends StatelessWidget {
  const _MessagesShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      reverse: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: const [
        MessageBubbleShimmer(isOutgoing: true, widthFactor: 0.42),
        MessageBubbleShimmer(widthFactor: 0.62),
        MessageBubbleShimmer(isOutgoing: true, widthFactor: 0.5),
        MessageBubbleShimmer(widthFactor: 0.4),
        MessageBubbleShimmer(widthFactor: 0.7),
        MessageBubbleShimmer(isOutgoing: true, widthFactor: 0.55),
      ],
    );
  }
}

class _SearchEmpty extends StatelessWidget {
  const _SearchEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.secondaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: AppColors.secondaryVariantColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No matches in this chat',
            style: GoogleFonts.poppins(
              color: AppColors.onSurfaceColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different word or phrase',
            style: GoogleFonts.poppins(
              color: AppColors.onSurfaceMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClose;

  const _ChatSearchBar({required this.controller, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 20,
              color: AppColors.onSurfaceMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                cursorColor: AppColors.secondaryVariantColor,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search in this chat',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13.5,
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: onClose,
              tooltip: 'Close search',
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;
  final VoidCallback onCancel;

  const _ReplyPreview({
    required this.message,
    required this.isMine,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final text = (message['content'] as String?) ?? '';
    final preview =
        text.length > 120 ? '${text.substring(0, 117)}…' : text;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          decoration: BoxDecoration(
            color: AppColors.secondaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: AppColors.secondaryVariantColor,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.reply_rounded,
                size: 16,
                color: AppColors.secondaryVariantColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isMine ? 'Replying to yourself' : 'Replying',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryVariantColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: AppColors.onSurfaceColor,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cancel reply',
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final bool isOutgoing;
  final VoidCallback onTrigger;

  const _SwipeToReply({
    required this.child,
    required this.isOutgoing,
    required this.onTrigger,
  });

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  double _dx = 0;
  static const _triggerAt = 56.0;
  bool _fired = false;

  void _onUpdate(DragUpdateDetails d) {
    final delta = d.primaryDelta ?? 0;
    final reverse = widget.isOutgoing;
    final next = (_dx + (reverse ? -delta : delta)).clamp(0.0, 90.0);
    if (next != _dx) {
      setState(() => _dx = next);
      if (!_fired && next >= _triggerAt) {
        _fired = true;
        HapticFeedback.mediumImpact();
        widget.onTrigger();
      }
    }
  }

  void _reset() {
    setState(() {
      _dx = 0;
      _fired = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dx / _triggerAt).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: (_) => _reset(),
      onHorizontalDragCancel: _reset,
      child: Stack(
        alignment: widget.isOutgoing
            ? Alignment.centerRight
            : Alignment.centerLeft,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12 * progress),
            child: Opacity(
              opacity: progress,
              child: Icon(
                Icons.reply_rounded,
                color: AppColors.secondaryVariantColor,
                size: 20 + 4 * progress,
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(widget.isOutgoing ? -_dx : _dx, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _HighlightedBubbleText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;

  const _HighlightedBubbleText({
    required this.text,
    required this.query,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty || text.isEmpty) {
      return Text(text, style: style);
    }
    final lower = text.toLowerCase();
    final needle = query.toLowerCase();
    final spans = <TextSpan>[];
    var index = 0;
    while (index < text.length) {
      final found = lower.indexOf(needle, index);
      if (found < 0) {
        spans.add(TextSpan(text: text.substring(index)));
        break;
      }
      if (found > index) {
        spans.add(TextSpan(text: text.substring(index, found)));
      }
      spans.add(
        TextSpan(
          text: text.substring(found, found + needle.length),
          style: style.copyWith(
            backgroundColor: AppColors.secondaryColor.withValues(alpha: 0.45),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      index = found + needle.length;
    }
    return RichText(text: TextSpan(style: style, children: spans));
  }
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.secondaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.secondaryVariantColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.noMessagesYet,
            style: GoogleFonts.poppins(
              color: AppColors.onSurfaceColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Say hi to start the conversation',
            style: GoogleFonts.poppins(
              color: AppColors.onSurfaceMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
