import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/user_prefs.dart';

/// Local-only list of starred message ids. Star/unstar happens from the chat
/// detail screen; this view just renders what we have so the user can revisit
/// them. Content is intentionally minimal — message bodies aren't cached here
/// because they live encrypted inside the conversation cache.
class StarredMessagesScreen extends StatefulWidget {
  const StarredMessagesScreen({super.key});

  @override
  State<StarredMessagesScreen> createState() => _StarredMessagesScreenState();
}

class _StarredMessagesScreenState extends State<StarredMessagesScreen> {
  bool _loading = true;
  List<String> _ids = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ids = await UserPrefs.starredMessageIds();
    if (!mounted) return;
    setState(() {
      _ids = ids.toList();
      _loading = false;
    });
  }

  Future<void> _unstar(String id) async {
    HapticFeedback.lightImpact();
    await UserPrefs.unstar(id);
    if (!mounted) return;
    setState(() => _ids = _ids.where((x) => x != id).toList());
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
        body: Column(
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(8, topInset + 6, 16, 22),
              decoration: const BoxDecoration(
                gradient: AppColors.darkGradient,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Starred',
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
                      Icons.star_rounded,
                      color: AppColors.secondaryColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _ids.isEmpty
                      ? const _Empty()
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                          itemCount: _ids.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _StarredTile(
                            id: _ids[i],
                            onUnstar: () => _unstar(_ids[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarredTile extends StatelessWidget {
  final String id;
  final VoidCallback onUnstar;
  const _StarredTile({required this.id, required this.onUnstar});

  @override
  Widget build(BuildContext context) {
    final short = id.length > 10 ? '${id.substring(0, 8)}…' : id;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondaryColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.star_rounded,
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
                  'Message $short',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Open the chat to view this message',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Unstar',
            onPressed: onUnstar,
            icon: const Icon(
              Icons.star_rounded,
              color: AppColors.secondaryVariantColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

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
              Icons.star_border_rounded,
              size: 36,
              color: AppColors.secondaryVariantColor,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No starred messages',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              'Long-press a message and tap Star to keep it here for later.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
