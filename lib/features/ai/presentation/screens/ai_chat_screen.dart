import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/time_format.dart';
import '../../domain/entities/ai_message.dart';
import '../providers/ai_provider.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showJumpToBottom = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final shouldShow = _scrollController.position.pixels > 200;
    if (shouldShow != _showJumpToBottom) {
      setState(() => _showJumpToBottom = shouldShow);
    }
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _controller.clear();
    await ref.read(aiChatProvider.notifier).send(text);
    _jumpToBottom();
  }

  void _confirmClear() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceColor,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear conversation?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        content: Text(
          'All messages with the AI assistant will be deleted from this device.',
          style: GoogleFonts.poppins(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(aiChatProvider.notifier).clear();
              Navigator.pop(ctx);
            },
            child: Text(
              'Clear',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: AppColors.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiChatProvider);
    final hasText = _controller.text.trim().isNotEmpty;
    final canSend = hasText && !state.sending;
    final topInset = MediaQuery.of(context).padding.top;

    ref.listen<AiChatState>(aiChatProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
        ref.read(aiChatProvider.notifier).dismissError();
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surfaceMuted,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(topInset + 68),
          child: _AiHeader(
            topInset: topInset,
            isThinking: state.sending,
            hasMessages: state.messages.isNotEmpty,
            onClear: _confirmClear,
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: state.messages.isEmpty
                      ? const _AiEmpty()
                      : _AiMessagesList(
                          messages: state.messages,
                          isThinking: state.sending,
                          controller: _scrollController,
                        ),
                ),
                _AiComposer(
                  controller: _controller,
                  canSend: canSend,
                  isSending: state.sending,
                  onSend: _send,
                ),
              ],
            ),
            Positioned(
              right: 14,
              bottom: 86,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 200),
                offset: _showJumpToBottom ? Offset.zero : const Offset(0, 1.4),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _showJumpToBottom ? 1 : 0,
                  child: Material(
                    color: AppColors.surfaceColor,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _jumpToBottom,
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.onSurfaceColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiHeader extends StatelessWidget {
  final double topInset;
  final bool isThinking;
  final bool hasMessages;
  final VoidCallback onClear;

  const _AiHeader({
    required this.topInset,
    required this.isThinking,
    required this.hasMessages,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.darkGradient),
      padding: EdgeInsets.only(top: topInset),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                shape: BoxShape.circle,
                boxShadow: AppColors.accentShadow,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'AI Assistant',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    isThinking ? 'Thinking…' : 'Always available',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (hasMessages)
              IconButton(
                tooltip: 'Clear conversation',
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white, size: 20),
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}

class _AiMessagesList extends StatelessWidget {
  final List<AiMessage> messages;
  final bool isThinking;
  final ScrollController controller;

  const _AiMessagesList({
    required this.messages,
    required this.isThinking,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final reversed = List<AiMessage>.from(messages.reversed);
    final itemCount = reversed.length + (isThinking ? 1 : 0);
    return ListView.builder(
      reverse: true,
      controller: controller,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (isThinking && index == 0) {
          return const _TypingBubble();
        }
        final msg = reversed[isThinking ? index - 1 : index];
        return _AiBubble(message: msg);
      },
    );
  }
}

class _AiBubble extends StatelessWidget {
  final AiMessage message;
  const _AiBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AiRole.user;
    final radius = const Radius.circular(18);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onLongPress: () {
                HapticFeedback.mediumImpact();
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message copied'),
                    duration: Duration(milliseconds: 1200),
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isUser ? AppColors.accentGradient : null,
                  color: isUser ? null : AppColors.surfaceColor,
                  borderRadius: BorderRadius.only(
                    topLeft: radius,
                    topRight: radius,
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
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
                    Text(
                      message.content,
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        color:
                            isUser ? Colors.black : AppColors.onSurfaceColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      TimeFormat.bubbleTime(message.createdAt),
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        color: isUser
                            ? Colors.black.withValues(alpha: 0.55)
                            : AppColors.onSurfaceMuted,
                      ),
                    ),
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

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final phase = (_ctrl.value + i * 0.18) % 1.0;
                  final scale =
                      0.6 + 0.6 * (0.5 + 0.5 * (1 - (phase - 0.5).abs() * 2));
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.secondaryVariantColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AiComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool canSend;
  final bool isSending;
  final VoidCallback onSend;

  const _AiComposer({
    required this.controller,
    required this.canSend,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 50),
                decoration: BoxDecoration(
                  color: AppColors.surfaceColor,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: AppColors.softShadow,
                ),
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  minLines: 1,
                  maxLines: 5,
                  cursorColor: AppColors.secondaryVariantColor,
                  decoration: InputDecoration(
                    hintText: 'Ask the AI anything…',
                    hintStyle: GoogleFonts.poppins(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    color: AppColors.onSurfaceColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedScale(
              duration: const Duration(milliseconds: 180),
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
                            Icons.send_rounded,
                            color: Colors.black,
                          ),
                    onPressed: canSend ? onSend : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiEmpty extends StatelessWidget {
  const _AiEmpty();

  static const _suggestions = [
    'Explain quantum entanglement simply',
    'Give me 3 study tips for finals',
    'Write a short poem about coding',
    'Plan a 5-day trip to Tokyo',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              shape: BoxShape.circle,
              boxShadow: AppColors.accentShadow,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 38,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Hi, I\'m your AI assistant',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ask me anything — homework, ideas, recipes, code.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < _suggestions.length; i++)
                _StaggeredFade(
                  delay: Duration(milliseconds: 120 + i * 90),
                  child: _SuggestionChip(text: _suggestions[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaggeredFade extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _StaggeredFade({required this.child, required this.delay});

  @override
  State<_StaggeredFade> createState() => _StaggeredFadeState();
}

class _StaggeredFadeState extends State<_StaggeredFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curved,
      builder: (_, child) {
        return Opacity(
          opacity: curved.value,
          child: Transform.translate(
            offset: Offset(0, (1 - curved.value) * 8),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _SuggestionChip extends ConsumerWidget {
  final String text;
  const _SuggestionChip({required this.text});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.surfaceColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          ref.read(aiChatProvider.notifier).send(text);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceColor,
            ),
          ),
        ),
      ),
    );
  }
}
