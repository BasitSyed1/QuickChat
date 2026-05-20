import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';

enum AttachmentKind {
  photo,
  camera,
  document,
  audio,
  location,
  contact,
  poll,
  gift,
}

class _AttachmentOption {
  final AttachmentKind kind;
  final IconData icon;
  final String label;
  final Color color;

  const _AttachmentOption({
    required this.kind,
    required this.icon,
    required this.label,
    required this.color,
  });
}

/// Dummy attachment menu — picking an option just sends a placeholder text
/// message. Wire to a real picker by replacing the [_AttachmentOption.kind]
/// branch in the chat detail screen.
class AttachmentsSheet extends StatelessWidget {
  final void Function(AttachmentKind kind) onPick;

  const AttachmentsSheet({super.key, required this.onPick});

  static const _options = <_AttachmentOption>[
    _AttachmentOption(
      kind: AttachmentKind.photo,
      icon: Icons.photo_library_rounded,
      label: 'Photo',
      color: Color(0xFF6FB1FC),
    ),
    _AttachmentOption(
      kind: AttachmentKind.camera,
      icon: Icons.photo_camera_rounded,
      label: 'Camera',
      color: Color(0xFFFF7E7E),
    ),
    _AttachmentOption(
      kind: AttachmentKind.document,
      icon: Icons.description_rounded,
      label: 'Document',
      color: Color(0xFF9F77FB),
    ),
    _AttachmentOption(
      kind: AttachmentKind.audio,
      icon: Icons.music_note_rounded,
      label: 'Audio',
      color: Color(0xFFFFB020),
    ),
    _AttachmentOption(
      kind: AttachmentKind.location,
      icon: Icons.location_on_rounded,
      label: 'Location',
      color: Color(0xFF34C759),
    ),
    _AttachmentOption(
      kind: AttachmentKind.contact,
      icon: Icons.person_rounded,
      label: 'Contact',
      color: Color(0xFF5EDB72),
    ),
    _AttachmentOption(
      kind: AttachmentKind.poll,
      icon: Icons.poll_rounded,
      label: 'Poll',
      color: Color(0xFFE573D7),
    ),
    _AttachmentOption(
      kind: AttachmentKind.gift,
      icon: Icons.card_giftcard_rounded,
      label: 'Gift',
      color: Color(0xFFEF5350),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: 44,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: AppColors.borderColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Text(
            'Share something',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick a type to add to your message',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 18,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: _options.map((opt) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  onPick(opt.kind);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: opt.color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(opt.icon, color: opt.color, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      opt.label,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
