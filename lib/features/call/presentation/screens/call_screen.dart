import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/avatar_palette.dart';
import '../../../auth/domain/entities/user_model.dart';

enum CallMode { voice, video }

/// Lightweight, fully-local "magic" call screen. There is no real signalling
/// pipeline yet — this is a faithful UI stub that can be wired to a real
/// service later. It simulates: connecting → ringing → in-call (with a running
/// timer and toggleable mic/speaker/video controls) → ended.
class CallScreen extends StatefulWidget {
  final UserModel otherUser;
  final CallMode mode;

  const CallScreen({
    super.key,
    required this.otherUser,
    required this.mode,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with TickerProviderStateMixin {
  static const _ringDuration = Duration(seconds: 4);

  Timer? _ringTimer;
  Timer? _tickTimer;
  late final AnimationController _pulseCtrl;
  late final AnimationController _ringCtrl;

  Duration _elapsed = Duration.zero;
  _CallState _state = _CallState.dialing;
  bool _muted = false;
  bool _speakerOn = false;
  bool _videoOn = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _videoOn = widget.mode == CallMode.video;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _ringTimer = Timer(_ringDuration, () {
      if (!mounted) return;
      setState(() => _state = _CallState.connected);
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed += const Duration(seconds: 1));
      });
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    _ringTimer?.cancel();
    _tickTimer?.cancel();
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  void _endCall() {
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() => _state = _CallState.ended);
    _tickTimer?.cancel();
    _ringTimer?.cancel();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  String get _statusLabel {
    switch (_state) {
      case _CallState.dialing:
        return widget.mode == CallMode.video
            ? 'Video calling…'
            : 'Calling…';
      case _CallState.connected:
        final h = _elapsed.inHours.toString().padLeft(2, '0');
        final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
        final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
        return _elapsed.inHours == 0 ? '$m:$s' : '$h:$m:$s';
      case _CallState.ended:
        return 'Call ended';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _MiniBadge(
                          label: widget.mode == CallMode.video
                              ? 'VIDEO'
                              : 'VOICE',
                          color: widget.mode == CallMode.video
                              ? const Color(0xFF6FB1FC)
                              : AppColors.secondaryColor,
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Minimize',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _Avatar(
                      name: widget.otherUser.name,
                      pulseCtrl: _pulseCtrl,
                      animatePulse: _state == _CallState.dialing,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.otherUser.name ?? 'Unknown',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: Row(
                        key: ValueKey(_statusLabel),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_state == _CallState.dialing)
                            _RingingDots(controller: _ringCtrl),
                          if (_state == _CallState.dialing)
                            const SizedBox(width: 8),
                          Text(
                            _statusLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 14.5,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (_state != _CallState.ended) _buildControls(),
                    if (_state == _CallState.ended)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: Text(
                          'Returning to chat…',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AvatarPalette.gradient(widget.otherUser.name ?? '')
                    .colors
                    .first
                    .withValues(alpha: 0.55),
                Colors.black,
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: BackdropFilterPainter(),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CallButton(
              icon: _muted
                  ? Icons.mic_off_rounded
                  : Icons.mic_rounded,
              label: _muted ? 'Unmute' : 'Mute',
              active: _muted,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _muted = !_muted);
              },
            ),
            _CallButton(
              icon: _speakerOn
                  ? Icons.volume_up_rounded
                  : Icons.volume_down_rounded,
              label: 'Speaker',
              active: _speakerOn,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _speakerOn = !_speakerOn);
              },
            ),
            if (widget.mode == CallMode.video)
              _CallButton(
                icon: _videoOn
                    ? Icons.videocam_rounded
                    : Icons.videocam_off_rounded,
                label: _videoOn ? 'Hide' : 'Show',
                active: !_videoOn,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _videoOn = !_videoOn);
                },
              )
            else
              _CallButton(
                icon: Icons.dialpad_rounded,
                label: 'Keypad',
                active: false,
                onTap: () {
                  HapticFeedback.selectionClick();
                },
              ),
          ],
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _endCall,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.errorColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.errorColor.withValues(alpha: 0.45),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Transform.rotate(
              angle: 2.4,
              child: const Icon(
                Icons.call_end_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'End',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

enum _CallState { dialing, connected, ended }

class _Avatar extends StatelessWidget {
  final String? name;
  final AnimationController pulseCtrl;
  final bool animatePulse;

  const _Avatar({
    required this.name,
    required this.pulseCtrl,
    required this.animatePulse,
  });

  @override
  Widget build(BuildContext context) {
    final initial = (name?.isNotEmpty ?? false) ? name![0].toUpperCase() : '?';
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (animatePulse)
            AnimatedBuilder(
              animation: pulseCtrl,
              builder: (_, _) {
                final t = pulseCtrl.value;
                return Container(
                  width: 130 + 40 * t,
                  height: 130 + 40 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white
                          .withValues(alpha: (1 - t).clamp(0.0, 0.5)),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
          Container(
            width: 130,
            height: 130,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AvatarPalette.gradient(name ?? ''),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Text(
              initial,
              style: GoogleFonts.poppins(
                fontSize: 52,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingingDots extends StatelessWidget {
  final AnimationController controller;
  const _RingingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final t = controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = ((t * 3) - i).clamp(0.0, 1.0);
            final scale = 0.6 + (math.sin(phase * math.pi) * 0.6);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale.clamp(0.6, 1.2),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.secondaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(
              icon,
              color: active ? Colors.black : Colors.white,
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class BackdropFilterPainter extends StatelessWidget {
  const BackdropFilterPainter({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _NoisePainter());
  }
}

class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.02);
    final rng = math.Random(7);
    for (var i = 0; i < 90; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(dx, dy), rng.nextDouble() * 1.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) => false;
}
