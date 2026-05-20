import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/user_prefs.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/custom_button.dart';

/// Lets the user pick a status message (WhatsApp-style "About / Status").
/// Pick from common presets or write a custom one. Persisted locally via
/// [UserPrefs] so it survives across sessions.
class StatusSheet extends StatefulWidget {
  final String initial;
  final String initialEmoji;
  final void Function(String text, String emoji) onSaved;

  const StatusSheet({
    super.key,
    required this.initial,
    required this.initialEmoji,
    required this.onSaved,
  });

  static const _emojis = ['💬', '🟢', '🌙', '🏃', '📚', '🎮', '☕', '🎧', '✈️', '❤️'];

  @override
  State<StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<StatusSheet> {
  late final TextEditingController _controller;
  late String _emoji;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
    _emoji = widget.initialEmoji;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    HapticFeedback.lightImpact();
    final text = _controller.text.trim();
    final value = text.isEmpty ? UserPrefs.defaultStatus : text;
    await UserPrefs.setStatus(value, emoji: _emoji);
    if (!mounted) return;
    widget.onSaved(value, _emoji);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Update status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Row(
              children: [
                Text(_emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: 90,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      color: AppColors.onSurfaceColor,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      hintText: 'Tell people what you\'re up to…',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.onSurfaceMuted,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Pick an emoji',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: StatusSheet._emojis.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final e = StatusSheet._emojis[i];
                final selected = e == _emoji;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _emoji = e);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.secondaryColor.withValues(alpha: 0.2)
                          : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppColors.secondaryVariantColor
                            : AppColors.borderColor,
                        width: selected ? 1.4 : 1,
                      ),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 18)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Quick picks',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: UserPrefs.quickStatuses.map((s) {
              final selected = s == _controller.text.trim();
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _controller.text = s;
                    _controller.selection = TextSelection.collapsed(
                      offset: s.length,
                    );
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.secondaryColor.withValues(alpha: 0.18)
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.secondaryVariantColor
                          : AppColors.borderColor,
                    ),
                  ),
                  child: Text(
                    s,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? AppColors.secondaryVariantColor
                          : AppColors.onSurfaceColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          CustomButton(
            label: 'Save status',
            onPressed: _save,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
