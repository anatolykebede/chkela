import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/open_telegram.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/subscription_data.dart';
import '../../data/app_remote_config.dart';

class SubscriptionPaymentSheet {
  SubscriptionPaymentSheet._();

  static BuildContext _sheetContext(BuildContext context) {
    return rootNavigatorKey.currentContext ?? context;
  }

  static Future<SubscriptionPaymentMethod?> showMethodPicker({
    required BuildContext context,
    required int totalPrice,
    required BillingPeriod billingPeriod,
  }) {
    return showModalBottomSheet<SubscriptionPaymentMethod>(
      context: _sheetContext(context),
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => PaymentMethodPickerSheet(
        totalPrice: totalPrice,
        billingPeriod: billingPeriod,
      ),
    );
  }

  static Future<PaymentCheckoutResult?> showCheckout({
    required BuildContext context,
    required SubscriptionPaymentMethod method,
    required int totalPrice,
    required BillingPeriod billingPeriod,
  }) {
    return showModalBottomSheet<PaymentCheckoutResult>(
      context: _sheetContext(context),
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => PaymentCheckoutSheet(
        method: method,
        totalPrice: totalPrice,
        billingPeriod: billingPeriod,
      ),
    );
  }
}

class PaymentCheckoutResult {
  const PaymentCheckoutResult({
    required this.method,
    this.receiptPath,
  });

  final SubscriptionPaymentMethod method;
  final String? receiptPath;
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius + 4),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: child,
      ),
    );
  }
}

class PaymentMethodLogo extends StatelessWidget {
  const PaymentMethodLogo({
    super.key,
    required this.method,
    this.size = 50,
    this.backgroundColor = Colors.white,
    this.borderRadius = 14,
    this.padding = 6,
  });

  final SubscriptionPaymentMethod method;
  final double size;
  final Color backgroundColor;
  final double borderRadius;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: method.accent.withValues(alpha: 0.2),
        ),
      ),
      child: SvgPicture.asset(
        method.logoAsset,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _PaymentSupportFooter extends StatelessWidget {
  const _PaymentSupportFooter();

  static const _telegramBlue = Color(0xFF26A5E4);
  static const _telegramBlueDark = Color(0xFF1E96D3);

  Future<void> _openTelegram(BuildContext context) async {
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.of(context);
    final config = await AppRemoteConfigStore.loadCachedOrDefaults();
    final launched = await openTelegramSupport(config: config);
    if (launched) return;

    await copyTelegramSupportLink(config: config);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Copied ${config.telegramHandle} — open Telegram to message us',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        shadowColor: _telegramBlue.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        child: InkWell(
          onTap: () => _openTelegram(context),
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
          splashColor: Colors.white.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_telegramBlue, _telegramBlueDark],
              ),
              borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: _telegramBlue.withValues(alpha: 0.38),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                      child: SvgPicture.asset(
                        'assets/payment/telegram_icon.svg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need help?',
                        style: HomeTextStyles.badge.copyWith(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Chat with us on Telegram',
                        style: HomeTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.95),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderStrong,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _AmountHeader extends StatelessWidget {
  const _AmountHeader({
    required this.title,
    required this.totalPrice,
    required this.billingPeriod,
    required this.accent,
  });

  final String title;
  final int totalPrice;
  final BillingPeriod billingPeriod;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Column(
        children: [
          Text(
            title,
            style: HomeTextStyles.cardTitle.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatPrice(totalPrice)} ${billingPeriodSuffix(billingPeriod)}',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentMethodPickerSheet extends StatelessWidget {
  const PaymentMethodPickerSheet({
    super.key,
    required this.totalPrice,
    required this.billingPeriod,
  });

  final int totalPrice;
  final BillingPeriod billingPeriod;

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetHandle(),
          _AmountHeader(
            title: 'Choose payment method',
            totalPrice: totalPrice,
            billingPeriod: billingPeriod,
            accent: AppColors.amber,
          ),
          const SizedBox(height: 8),
          for (final method in SubscriptionPaymentMethod.values)
            _PaymentMethodCard(
              method: method,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop(method);
              },
            ),
          const _PaymentSupportFooter(),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.method,
    required this.onTap,
  });

  final SubscriptionPaymentMethod method;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  method.accentSoft,
                  AppColors.bgElevated,
                ],
              ),
              borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
              border: Border.all(
                color: method.accent.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                PaymentMethodLogo(method: method),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        method.label,
                        style: HomeTextStyles.cardTitle.copyWith(
                          fontSize: 16,
                          color: method.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: method.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: method.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          method.pickerBadge,
                          style: HomeTextStyles.badge.copyWith(
                            fontSize: 8,
                            color: method.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: method.accent,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PaymentCheckoutSheet extends StatelessWidget {
  const PaymentCheckoutSheet({
    super.key,
    required this.method,
    required this.totalPrice,
    required this.billingPeriod,
  });

  final SubscriptionPaymentMethod method;
  final int totalPrice;
  final BillingPeriod billingPeriod;

  @override
  Widget build(BuildContext context) {
    if (method == SubscriptionPaymentMethod.cbe) {
      return CbeCheckoutSheet(
        totalPrice: totalPrice,
        billingPeriod: billingPeriod,
      );
    }
    return ChapaCheckoutSheet(
      totalPrice: totalPrice,
      billingPeriod: billingPeriod,
    );
  }
}

class CbeCheckoutSheet extends StatefulWidget {
  const CbeCheckoutSheet({
    super.key,
    required this.totalPrice,
    required this.billingPeriod,
  });

  final int totalPrice;
  final BillingPeriod billingPeriod;

  @override
  State<CbeCheckoutSheet> createState() => _CbeCheckoutSheetState();
}

class _CbeCheckoutSheetState extends State<CbeCheckoutSheet> {
  final _imagePicker = ImagePicker();
  bool _copied = false;
  File? _receiptFile;

  bool get _canSubmit => _receiptFile != null;

  void _copyAccountNumber() {
    Clipboard.setData(
      const ClipboardData(text: cbeTransferAccountNumber),
    );
    HapticFeedback.lightImpact();
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (!mounted) return;
      if (picked == null) return;
      HapticFeedback.selectionClick();
      setState(() => _receiptFile = File(picked.path));
    } on PlatformException catch (error) {
      if (!mounted) return;
      _showMediaAccessIssue(source, error);
    }
  }

  void _showMediaAccessIssue(ImageSource source, PlatformException error) {
    final isCamera = source == ImageSource.camera;
    final deniedCodes = {
      'camera_access_denied',
      'photo_access_denied',
      'access_denied',
    };
    final isDenied = deniedCodes.contains(error.code);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          isDenied
              ? (isCamera
                  ? 'Camera permission is required to take a receipt photo.'
                  : 'Photo permission is required to attach a receipt.')
              : 'Could not open ${isCamera ? 'camera' : 'gallery'}. Please try again.',
        ),
        action: isDenied
            ? SnackBarAction(
                label: 'Help',
                onPressed: () => _showMediaAccessDialog(source),
              )
            : null,
      ),
    );
  }

  Future<void> _showMediaAccessDialog(ImageSource source) async {
    final isCamera = source == ImageSource.camera;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text(
          isCamera ? 'Camera access required' : 'Photo access required',
          style: HomeTextStyles.cardTitle.copyWith(fontSize: 16),
        ),
        content: Text(
          isCamera
              ? 'When prompted, tap Allow so Chkela can use your camera for the receipt photo.\n\nIf you previously denied access, open Settings → Chkela → Camera and enable it.'
              : 'When prompted, tap Allow so Chkela can access your photos for the receipt.\n\nIf you previously denied access, open Settings → Chkela → Photos and choose Allow.',
          style: HomeTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Got it',
              style: HomeTextStyles.badge.copyWith(
                fontSize: 12,
                color: AppColors.accentText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAttachOptions() async {
    HapticFeedback.selectionClick();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Attach receipt',
                style: HomeTextStyles.cardTitle.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              if (_receiptFile != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger,
                  ),
                  title: const Text(
                    'Remove receipt',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'gallery':
        await _pickReceipt(ImageSource.gallery);
      case 'camera':
        await _pickReceipt(ImageSource.camera);
      case 'remove':
        _removeReceipt();
    }
  }

  void _removeReceipt() {
    HapticFeedback.selectionClick();
    setState(() => _receiptFile = null);
  }

  void _submit() {
    if (!_canSubmit) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(
      PaymentCheckoutResult(
        method: SubscriptionPaymentMethod.cbe,
        receiptPath: _receiptFile?.path,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const method = SubscriptionPaymentMethod.cbe;

    return _SheetShell(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),
            _AmountHeader(
              title: method.title,
              totalPrice: widget.totalPrice,
              billingPeriod: widget.billingPeriod,
              accent: method.accent,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _CbeStepGuide(accent: method.accent),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: method.accentSoft,
                  borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
                  border: Border.all(
                    color: method.accent.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const PaymentMethodLogo(
                      method: SubscriptionPaymentMethod.cbe,
                      size: 56,
                      padding: 8,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cbeTransferAccountNumber,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cbeTransferAccountName,
                            style: HomeTextStyles.bodySmall.copyWith(
                              fontSize: 11,
                              color: method.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _copyAccountNumber,
                      child: Text(
                        _copied ? 'Copied' : 'Copy',
                        style: HomeTextStyles.badge.copyWith(
                          fontSize: 11,
                          color: method.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _CbeReceiptAttachCard(
                accent: method.accent,
                receiptFile: _receiptFile,
                onAttach: _showAttachOptions,
                onRemove: _removeReceipt,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: method.accent,
                    disabledBackgroundColor:
                        method.accent.withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
                    ),
                  ),
                  child: Text(
                    'Submit payment',
                    style: HomeTextStyles.badge.copyWith(
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const _PaymentSupportFooter(),
          ],
        ),
      ),
    );
  }
}

class _CbeStepGuide extends StatelessWidget {
  const _CbeStepGuide({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to pay & submit',
            style: HomeTextStyles.cardTitle.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < cbePaymentSteps.length; i++) ...[
            _CbeStepRow(
              step: i + 1,
              text: cbePaymentSteps[i],
              accent: accent,
              isLast: i == cbePaymentSteps.length - 1,
            ),
            if (i < cbePaymentSteps.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CbeStepRow extends StatelessWidget {
  const _CbeStepRow({
    required this.step,
    required this.text,
    required this.accent,
    required this.isLast,
  });

  final int step;
  final String text;
  final Color accent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.45)),
              ),
              child: Text(
                '$step',
                style: HomeTextStyles.badge.copyWith(
                  fontSize: 11,
                  color: accent,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 18,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: accent.withValues(alpha: 0.2),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: HomeTextStyles.bodySmall.copyWith(
                fontSize: 12,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CbeReceiptAttachCard extends StatelessWidget {
  const _CbeReceiptAttachCard({
    required this.accent,
    required this.receiptFile,
    required this.onAttach,
    required this.onRemove,
  });

  final Color accent;
  final File? receiptFile;
  final VoidCallback onAttach;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasReceipt = receiptFile != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAttach,
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasReceipt ? accent.withValues(alpha: 0.08) : AppColors.bgElevated,
            borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
            border: Border.all(
              color: hasReceipt
                  ? accent.withValues(alpha: 0.5)
                  : AppColors.border,
              width: hasReceipt ? 1.2 : 1,
            ),
          ),
          child: hasReceipt
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: accent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Receipt attached',
                            style: HomeTextStyles.cardTitle.copyWith(
                              fontSize: 13,
                              color: accent,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onRemove,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: AppColors.textMuted,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        receiptFile!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to replace receipt',
                      style: HomeTextStyles.bodySmall.copyWith(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attach receipt',
                            style: HomeTextStyles.cardTitle.copyWith(
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Screenshot or photo from CBE mobile banking',
                            style: HomeTextStyles.bodySmall.copyWith(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: accent,
                      size: 22,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class ChapaCheckoutSheet extends StatelessWidget {
  const ChapaCheckoutSheet({
    super.key,
    required this.totalPrice,
    required this.billingPeriod,
  });

  final int totalPrice;
  final BillingPeriod billingPeriod;

  void _continue(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(
      const PaymentCheckoutResult(method: SubscriptionPaymentMethod.chapa),
    );
  }

  @override
  Widget build(BuildContext context) {
    const method = SubscriptionPaymentMethod.chapa;

    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetHandle(),
          _AmountHeader(
            title: method.title,
            totalPrice: totalPrice,
            billingPeriod: billingPeriod,
            accent: method.accent,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: method.accentSoft,
                borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
                border: Border.all(
                  color: method.accent.withValues(alpha: 0.4),
                ),
              ),
              child: const Center(
                child: PaymentMethodLogo(
                  method: SubscriptionPaymentMethod.chapa,
                  size: 72,
                  padding: 10,
                  borderRadius: 18,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _continue(context),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(
                  'Continue with Chapa',
                  style: HomeTextStyles.badge.copyWith(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: method.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
                  ),
                ),
              ),
            ),
          ),
          const _PaymentSupportFooter(),
        ],
      ),
    );
  }
}

