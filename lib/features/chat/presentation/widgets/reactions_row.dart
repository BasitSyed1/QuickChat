import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';

/// Small badge that displays the emoji reactions stacked on top of a message
/// bubble. Tapping it removes the most-recent reaction. Used by the chat
/// detail screen.
class ReactionsRow extends StatelessWidget {
  final List<String> emojis;
  final bool alignEnd;
  final VoidCallback? onTap;

  const ReactionsRow({
    super.key,
    required this.emojis,
    this.alignEnd = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (emojis.isEmpty) return const SizedBox.shrink();
    final grouped = <String, int>{};
    for (final e in emojis) {
      grouped.update(e, (v) => v + 1, ifAbsent: () => 1);
    }
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: GestureDetector(
          onTap: () {
            if (onTap != null) {
              HapticFeedback.selectionClick();
              onTap!();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: AppColors.borderColor.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: grouped.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.key, style: const TextStyle(fontSize: 14)),
                      if (e.value > 1) ...[
                        const SizedBox(width: 2),
                        Text(
                          '${e.value}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick-pick emoji bar shown above the action sheet when long-pressing a
/// message. Includes a "more" tail for the rare case the user wants something
/// outside the top six.
class ReactionPickerBar extends StatelessWidget {
  static const reactions = <String>['👍', '❤️', '😂', '😮', '😢', '🙏'];

  final void Function(String emoji) onPick;
  final VoidCallback? onMore;

  const ReactionPickerBar({super.key, required this.onPick, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...reactions.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onPick(e);
                },
                child: Text(
                  e,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
          ),
          if (onMore != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: GestureDetector(
                onTap: onMore,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: AppColors.onSurfaceColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
