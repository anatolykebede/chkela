import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';
import 'auth_provider.dart';
import 'auth_shell.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  static const _length = 4;

  /// One field so backspace / paste work without tapping each box.
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _resendTimer;
  int _resendSeconds = 30;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
    _startResendCooldown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _digits {
    final raw = _controller.text.replaceAll(RegExp(r'\D'), '');
    return raw.length > _length ? raw.substring(0, _length) : raw;
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    final ok = await ref.read(authProvider.notifier).verifyOtp(_digits);
    if (!mounted) return;
    if (!ok) return;

    final auth = ref.read(authProvider);
    if (auth.grade != null) {
      ref.read(selectedGradeProvider.notifier).state = auth.grade!;
    }
    if (auth.isAuthenticated) {
      context.go('/home');
    } else {
      context.go(auth.onboardingPath);
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    HapticFeedback.selectionClick();
    final ok = await ref.read(authProvider.notifier).resendOtp();
    if (!mounted) return;
    if (ok) {
      _controller.clear();
      _focusNode.requestFocus();
      _startResendCooldown();
      setState(() {});
    }
  }

  void _onCodeChanged(String value) {
    ref.read(authProvider.notifier).clearError();
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final clipped =
        digits.length > _length ? digits.substring(0, _length) : digits;
    if (clipped != value) {
      _controller.value = TextEditingValue(
        text: clipped,
        selection: TextSelection.collapsed(offset: clipped.length),
      );
    }
    setState(() {});
    if (clipped.length == _length) _verify();
  }

  void _focusInput() {
    _focusNode.requestFocus();
    // Keep caret at the end so backspace removes the last digit.
    final len = _digits.length;
    _controller.selection = TextSelection.collapsed(offset: len);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final phone = auth.pendingPhone;
    if (phone == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return const Scaffold(backgroundColor: AppColors.bgBase);
    }

    final display = AuthNotifier.displayPhone(phone);
    final digits = _digits;
    final ready = digits.length == _length;
    final activeIndex = digits.length >= _length ? _length - 1 : digits.length;

    return AuthShell(
      topBar: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: AuthPrimaryButton(
          label: 'Verify',
          loading: auth.isBusy,
          onPressed: ready ? _verify : null,
        ),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chkela', style: authBrandStyle(size: 28)),
            const SizedBox(height: 28),
            Text(
              'Check your messages',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We sent a 4-digit code to $display',
              style: authBodyStyle(),
            ),
            const SizedBox(height: 36),
            Stack(
              children: [
                // Real input (invisible). One field = natural backspace.
                Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    enableSuggestions: false,
                    style: const TextStyle(color: Colors.transparent),
                    cursorColor: Colors.transparent,
                    showCursor: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(_length),
                    ],
                    onChanged: _onCodeChanged,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ),
                Row(
                  children: List.generate(_length, (index) {
                    final filled = index < digits.length;
                    final focused =
                        _focusNode.hasFocus && index == activeIndex;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index == _length - 1 ? 0 : 8,
                        ),
                        child: GestureDetector(
                          onTap: _focusInput,
                          child: Container(
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.bgElevated,
                              borderRadius: BorderRadius.circular(
                                HomeLayout.cardRadius,
                              ),
                              border: Border.all(
                                color: focused
                                    ? AppColors.accent.withValues(alpha: 0.55)
                                    : AppColors.border,
                                width: focused ? 1 : 0.5,
                              ),
                            ),
                            child: Text(
                              filled ? digits[index] : '',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                auth.errorMessage!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.danger,
                ),
              ),
            ],
            const SizedBox(height: 20),
            TextButton(
              onPressed: _resendSeconds == 0 && !auth.isBusy ? _resend : null,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _resendSeconds > 0
                    ? 'Resend in ${_resendSeconds}s'
                    : 'Resend code',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _resendSeconds > 0
                      ? AppColors.textMuted
                      : AppColors.accentText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
