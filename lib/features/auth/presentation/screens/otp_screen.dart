import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/smooth_route.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../home/presentation/screens/home_screen.dart';

/// Six-digit OTP entry screen. This is a UI-complete stub: the verification
/// step happens locally — any non-empty 6-digit code is accepted ("magic
/// code"). Wire this to a real channel (Supabase email-OTP, Twilio, etc.) by
/// swapping the [_verify] body for a network call.
class OtpScreen extends StatefulWidget {
  final String destination;
  final bool replaceOnSuccess;

  const OtpScreen({
    super.key,
    required this.destination,
    this.replaceOnSuccess = false,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _length = 6;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  Timer? _resendTimer;
  int _resendIn = 30;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_length, (_) => TextEditingController());
    _focusNodes = List.generate(_length, (_) => FocusNode());
    _startResendCooldown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendIn--);
      if (_resendIn <= 0) {
        t.cancel();
      }
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length < _length) {
      AppDialogs.toast(context, 'Enter the full 6-digit code',
          icon: Icons.info_outline_rounded);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _verifying = true);
    // Magic verification — accepts any 6-digit code. Replace this with a real
    // backend call (Supabase verifyOtp / Twilio Verify / etc.).
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() => _verifying = false);
    AppDialogs.toast(context, 'Verified!', icon: Icons.verified_rounded);
    if (widget.replaceOnSuccess) {
      Navigator.pushAndRemoveUntil(
        context,
        SmoothRoute(const HomeScreen()),
        (_) => false,
      );
    } else {
      Navigator.of(context).pop(true);
    }
  }

  void _onChange(int index, String value) {
    if (value.length > 1) {
      _autoFill(value);
      return;
    }
    if (value.isNotEmpty && index < _length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
    if (_code.length == _length) _verify();
  }

  void _autoFill(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    for (var i = 0; i < _length; i++) {
      _controllers[i].text = i < digits.length ? digits[i] : '';
    }
    if (digits.length >= _length) {
      _focusNodes.last.unfocus();
      setState(() {});
      _verify();
    } else {
      _focusNodes[digits.length.clamp(0, _length - 1)].requestFocus();
    }
  }

  void _resend() {
    if (_resendIn > 0) return;
    HapticFeedback.lightImpact();
    AppDialogs.toast(
      context,
      'A new code is on its way to ${widget.destination}',
      icon: Icons.mark_email_read_outlined,
    );
    _startResendCooldown();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surfaceColor,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: AppColors.onSurfaceColor,
                    ),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.accentShadow,
                  ),
                  child: const Icon(
                    Icons.mark_email_read_rounded,
                    size: 34,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Verify it\'s you',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: AppColors.onSurfaceColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit code to\n${widget.destination}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.onSurfaceMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_length, (i) {
                    final filled = _controllers[i].text.isNotEmpty;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i == _length - 1 ? 0 : 8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 56,
                          decoration: BoxDecoration(
                            color: filled
                                ? AppColors.secondaryColor
                                    .withValues(alpha: 0.10)
                                : AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: filled
                                  ? AppColors.secondaryVariantColor
                                  : AppColors.borderColor,
                              width: filled ? 1.4 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            cursorColor: AppColors.secondaryVariantColor,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurfaceColor,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                            ),
                            onChanged: (v) => _onChange(i, v),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 22),
                CustomButton(
                  label: _verifying ? 'Verifying…' : 'Verify',
                  isLoading: _verifying,
                  onPressed: _verifying ? null : _verify,
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: _resendIn > 0 ? null : _resend,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Didn\'t get the code? ',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.onSurfaceMuted,
                          ),
                        ),
                        TextSpan(
                          text: _resendIn > 0
                              ? 'Resend in ${_resendIn}s'
                              : 'Resend now',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _resendIn > 0
                                ? AppColors.onSurfaceMuted
                                : AppColors.secondaryVariantColor,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
