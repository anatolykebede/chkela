import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import 'auth_provider.dart';
import 'auth_shell.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    final ok = await ref.read(authProvider.notifier).sendOtp(_controller.text);
    if (!mounted) return;
    if (ok) context.push('/otp');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canSubmit =
        _controller.text.replaceAll(RegExp(r'\D'), '').length >= 9;

    return AuthShell(
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: AuthPrimaryButton(
          label: 'Continue',
          loading: auth.isBusy,
          onPressed: canSubmit ? _submit : null,
        ),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chkela', style: authBrandStyle(size: 52)),
            const SizedBox(height: 14),
            Text(
              'Enter your phone number to sign in.',
              style: authBodyStyle(),
            ),
            const SizedBox(height: 48),
            Text('PHONE', style: HomeTextStyles.sectionLabel),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
                border: Border.all(
                  color: _focus.hasFocus
                      ? AppColors.accent.withValues(alpha: 0.55)
                      : AppColors.border,
                  width: _focus.hasFocus ? 1 : 0.5,
                ),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      '+251',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    width: 0.5,
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: AppColors.border,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) {
                        if (canSubmit && !auth.isBusy) _submit();
                      },
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.6,
                      ),
                      cursorColor: AppColors.accentText,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                        _PhoneGroupingFormatter(),
                      ],
                      decoration: InputDecoration(
                        hintText: '9XX XXX XXX',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                auth.errorMessage!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhoneGroupingFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > 10 ? digits.substring(0, 10) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i == 3 || i == 6) buffer.write(' ');
      buffer.write(clipped[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
