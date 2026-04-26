import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../data/services/chat_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final UserModel? otherUser;
  const ChatDetailScreen({super.key, required this.otherUser});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();

  String? _conversationId;
  UserModel? _currentUser;
  Stream<List<Map<String, dynamic>>>? _messages;

  @override
  void initState() {
    super.initState();
    _initializeConversation();
    _messageController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeConversation() async {
    _currentUser = await _chatService.getCurrentUser();
    if (_currentUser != null && widget.otherUser != null) {
      _conversationId = await _chatService.createConversation(
        _currentUser!,
        widget.otherUser!,
      );
      _messages = _chatService.receiveMessages(_conversationId!);
      if (mounted) setState(() {});
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _conversationId == null || _currentUser == null) return;

    _chatService.sendMessage(_conversationId!, _currentUser!, text);
    _messageController.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _messageController.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(gradient: AppColors.darkGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor:
                            AppColors.secondaryColor.withValues(alpha: 0.2),
                        child: Text(
                          (widget.otherUser?.name?.isNotEmpty ?? false)
                              ? widget.otherUser!.name![0].toUpperCase()
                              : '?',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondaryColor,
                          ),
                        ),
                      ),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.otherUser?.name ?? 'Unknown',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Online',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _appBarIcon(Icons.call_rounded, () {}),
                  _appBarIcon(Icons.videocam_rounded, () {}),
                  _appBarIcon(Icons.more_vert_rounded, () {}),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages == null
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.secondaryVariantColor,
                    ),
                  )
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _messages,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.secondaryVariantColor,
                          ),
                        );
                      }
                      final messages = snapshot.data!;
                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lock_outline_rounded,
                                color: AppColors.onSurfaceMuted,
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppStrings.noMessagesYet,
                                style: GoogleFonts.poppins(
                                  color: AppColors.onSurfaceMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          );
                        }
                      });

                      return ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: messages.length,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 14),
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isOutgoing =
                              msg['senderId'] == _currentUser?.id;
                          final prev = index > 0 ? messages[index - 1] : null;
                          final showTail = prev == null ||
                              prev['senderId'] != msg['senderId'];

                          return _MessageBubble(
                            text: msg['content'] ?? '',
                            isOutgoing: isOutgoing,
                            showTail: showTail,
                          );
                        },
                      );
                    },
                  ),
          ),
          _Composer(
            controller: _messageController,
            canSend: canSend,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  Widget _appBarIcon(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 20),
      onPressed: onTap,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isOutgoing;
  final bool showTail;

  const _MessageBubble({
    required this.text,
    required this.isOutgoing,
    required this.showTail,
  });

  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(18);
    return Padding(
      padding: EdgeInsets.only(top: showTail ? 8 : 2),
      child: Align(
        alignment:
            isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: isOutgoing ? AppColors.accentGradient : null,
              color: isOutgoing ? null : AppColors.surfaceColor,
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
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14.5,
                color: isOutgoing ? Colors.black : AppColors.onSurfaceColor,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.canSend,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                shape: BoxShape.circle,
                boxShadow: AppColors.softShadow,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.onSurfaceMuted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: AppColors.softShadow,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: AppStrings.typeAMessage,
                          hintStyle: GoogleFonts.poppins(
                            color: AppColors.onSurfaceMuted,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          color: AppColors.onSurfaceColor,
                        ),
                        onSubmitted: (_) => onSend(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.emoji_emotions_outlined,
                        color: AppColors.onSurfaceMuted,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                gradient: canSend ? AppColors.accentGradient : null,
                color: canSend ? null : AppColors.primaryColor,
                shape: BoxShape.circle,
                boxShadow: canSend ? AppColors.accentShadow : null,
              ),
              child: IconButton(
                icon: Icon(
                  canSend ? Icons.send_rounded : Icons.mic_rounded,
                  color: canSend ? Colors.black : Colors.white,
                ),
                onPressed: canSend ? onSend : () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
