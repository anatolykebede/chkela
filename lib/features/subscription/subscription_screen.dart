import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/payments_api.dart';
import '../../data/referral_api.dart';
import '../../data/subscription_data.dart';
import '../../widgets/common/traveling_border.dart';
import '../auth/auth_provider.dart';
import '../referral/referral_purchase_store.dart';
import 'subscription_access_store.dart';
import 'subscription_payment_sheet.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  SubscriptionPlanType _planType = SubscriptionPlanType.bundle;
  BillingPeriod _billingPeriod = BillingPeriod.monthly;
  late Set<String> _selectedGrades;
  bool _guiderSuppressed = false;
  int _referralDiscountPercent = 0;

  @override
  void initState() {
    super.initState();
    GuiderVisibility.suppressAfterBuild(
      ref,
      () => mounted,
      () => _guiderSuppressed = true,
    );
    _seedFromActiveGrade();
    _loadReferralDiscount();
  }

  Future<void> _loadReferralDiscount() async {
    var percent = await ReferralPurchaseStore.discountPercent();
    final phone = ref.read(authProvider).phoneE164;
    if (phone != null) {
      final remote = await ReferralApi().fetchDiscount(phone);
      if (remote.eligible && remote.discountPercent > 0) {
        percent = remote.discountPercent;
        await ReferralPurchaseStore.markEligible(percent: percent);
      }
    }
    if (!mounted) return;
    setState(() => _referralDiscountPercent = percent);
  }

  void _seedFromActiveGrade() {
    final active = ref.read(selectedGradeProvider);
    final entitlement = subscriptionEntitlementKey(active);
    final known = entitlement != null &&
        gradeSubscriptionOptions.any((o) => o.grade == entitlement);
    if (known) {
      _planType = SubscriptionPlanType.individual;
      _billingPeriod = BillingPeriod.monthly;
      _selectedGrades = {entitlement};
    } else {
      _resetSelections();
    }
  }

  @override
  void dispose() {
    if (_guiderSuppressed) {
      GuiderVisibility.unsuppressSoon(ref);
    }
    super.dispose();
  }

  void _resetSelections() {
    _planType = SubscriptionPlanType.bundle;
    _billingPeriod = BillingPeriod.monthly;
    _selectedGrades = {};
  }

  int get _baseTotalPrice => subscriptionTotalPrice(
        planType: _planType,
        period: _billingPeriod,
        selectedGrades: _selectedGrades,
      );

  int get _totalPrice => applyReferralPurchaseDiscount(
        _baseTotalPrice,
        _referralDiscountPercent,
      );

  int? get _originalTotalPrice {
    final base = _baseTotalPrice;
    final undiscounted = undiscountedTotalPrice(
      planType: _planType,
      period: _billingPeriod,
      selectedGrades: _selectedGrades,
    );
    if (_referralDiscountPercent > 0 && _totalPrice < base) {
      return base > undiscounted ? base : undiscounted;
    }
    return undiscounted > _totalPrice ? undiscounted : null;
  }

  bool get _canSubscribe {
    if (_planType == SubscriptionPlanType.bundle) return true;
    return _selectedGrades.isNotEmpty;
  }

  String get _planSummary {
    final period = billingPeriodSummary(_billingPeriod);
    if (_planType == SubscriptionPlanType.bundle) {
      return 'All grades · $period';
    }
    if (_selectedGrades.length == 1) {
      return '${_selectedGrades.first} · $period';
    }
    final sorted = _selectedGrades.toList()..sort();
    return '${sorted.join(', ')} · $period';
  }

  void _selectBundle() {
    HapticFeedback.selectionClick();
    setState(() {
      _planType = SubscriptionPlanType.bundle;
      _selectedGrades = {};
    });
  }

  void _setBillingPeriod(BillingPeriod period) {
    if (_billingPeriod == period) return;
    HapticFeedback.selectionClick();
    setState(() => _billingPeriod = period);
  }

  void _toggleGrade(String grade) {
    HapticFeedback.selectionClick();
    setState(() {
      final next = Set<String>.from(_selectedGrades);
      if (next.contains(grade)) {
        next.remove(grade);
      } else {
        next.add(grade);
      }

      if (next.isEmpty) {
        _planType = SubscriptionPlanType.bundle;
        _selectedGrades = {};
      } else {
        _planType = SubscriptionPlanType.individual;
        _selectedGrades = next;
      }
    });
  }

  Future<void> _subscribe() async {
    if (!_canSubscribe) return;
    HapticFeedback.mediumImpact();

    final method = await SubscriptionPaymentSheet.showMethodPicker(
      context: context,
      totalPrice: _totalPrice,
      billingPeriod: _billingPeriod,
    );

    if (method == null || !mounted) return;

    final checkout = await SubscriptionPaymentSheet.showCheckout(
      context: context,
      method: method,
      totalPrice: _totalPrice,
      billingPeriod: _billingPeriod,
    );

    if (checkout == null || !mounted) return;
    await _completePayment(checkout);
  }

  Future<void> _completePayment(PaymentCheckoutResult checkout) async {
    HapticFeedback.mediumImpact();
    final charged = _totalPrice;
    final auth = ref.read(authProvider);
    final phone = auth.phoneE164;
    final method = checkout.method;

    if (phone == null || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.bgElevated,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Sign in required to submit a payment.',
            style: HomeTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
          ),
        ),
      );
      return;
    }

    try {
      await PaymentsApi().submitPayment(
        method: method,
        amountEtb: charged,
        plan: _planType == SubscriptionPlanType.bundle
            ? 'bundle'
            : 'grades',
        grades: _planType == SubscriptionPlanType.bundle
            ? List<String>.from(subscriptionEntitlements)
            : _selectedGrades.toList(),
        billingPeriod: _billingPeriod,
        displayName: auth.fullName,
        receiptFile: checkout.receiptPath == null
            ? null
            : File(checkout.receiptPath!),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.bgElevated,
          behavior: SnackBarBehavior.floating,
          content: Text(
            e.toString(),
            style: HomeTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
          ),
        ),
      );
      return;
    }

    if (phone.isNotEmpty && _referralDiscountPercent > 0) {
      final result = await ReferralApi().recordPurchase(
        inviteePhone: phone,
        amountEtb: charged,
      );
      if (result.ok) {
        debugPrint(
          'Referral purchase: ${result.referrerCp} CP to referrer',
        );
      }
    }

    // Access unlocks only after admin approval — sync in case already paid.
    await SubscriptionAccessStore.syncFromServer();
    if (!mounted) return;
    ref.read(subscriptionAccessEpochProvider.notifier).state++;
    final discountNote = _referralDiscountPercent > 0
        ? ' · invite $_referralDiscountPercent% off'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Payment submitted — we\'ll verify and unlock access soon (${formatPrice(charged)} ${billingPeriodSuffix(_billingPeriod)}$discountNote)',
          style: HomeTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savings = bundleSavingsPercent();
    final billingOption = billingOptionFor(_billingPeriod);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      knownGradeCopy(_selectedGrades, _planType),
                      style: HomeTextStyles.bodySmall.copyWith(
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('ALL GRADES BUNDLE', style: HomeTextStyles.sectionLabel),
                    const SizedBox(height: 8),
                    _BundlePlanCard(
                      selected: _planType == SubscriptionPlanType.bundle,
                      billingPeriod: _billingPeriod,
                      savingsPercent: savings,
                      onTap: _selectBundle,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text('PICK GRADES', style: HomeTextStyles.sectionLabel),
                        const Spacer(),
                        Text(
                          'Select one or more',
                          style: HomeTextStyles.bodySmall.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.55,
                      children: [
                        for (final option in gradeSubscriptionOptions)
                          _GradePlanCard(
                            option: option,
                            selected: _planType == SubscriptionPlanType.individual &&
                                _selectedGrades.contains(option.grade),
                            billingPeriod: _billingPeriod,
                            onTap: () => _toggleGrade(option.grade),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _UnlockContentMessage(
                      message: unlockContentMessage(
                        planType: _planType,
                        selectedGrades: _selectedGrades,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text('BILLING PERIOD', style: HomeTextStyles.sectionLabel),
                        if (billingOption.discountPercent > 0) ...[
                          const Spacer(),
                          Text(
                            'Save ${billingOption.discountPercent}%',
                            style: HomeTextStyles.badge.copyWith(
                              fontSize: 9,
                              color: AppColors.teal,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    _BillingPeriodSelector(
                      selected: _billingPeriod,
                      planType: _planType,
                      selectedGrades: _selectedGrades,
                      onChanged: _setBillingPeriod,
                    ),
                  ],
                ),
              ),
            ),
            _SubscribeFooter(
              planSummary: _planSummary,
              totalPrice: _totalPrice,
              originalPrice: _originalTotalPrice,
              billingPeriod: _billingPeriod,
              canSubscribe: _canSubscribe,
              referralDiscountPercent: _referralDiscountPercent,
              onSubscribe: _subscribe,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnlockContentMessage extends StatelessWidget {
  const _UnlockContentMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    const radius = 10.0;

    return RepaintBoundary(
      child: TravelingBorderHighlight(
        accent: AppColors.accentText,
        radius: radius,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(1.5),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          constraints: const BoxConstraints(minHeight: 40),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(radius - 1.5),
          ),
          alignment: Alignment.centerLeft,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              message,
              key: ValueKey<String>(message),
              style: HomeTextStyles.bodySmall.copyWith(
                fontSize: 12,
                height: 1.35,
                color: AppColors.accentText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
                children: [
                  const TextSpan(text: 'Join The '),
                  TextSpan(
                    text: 'Elite',
                    style: GoogleFonts.cinzel(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.amber,
                      letterSpacing: 1.2,
                      height: 1.1,
                    ),
                  ),
                  const TextSpan(text: ' Circle Now'),
                ],
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingPeriodSelector extends StatelessWidget {
  const _BillingPeriodSelector({
    required this.selected,
    required this.planType,
    required this.selectedGrades,
    required this.onChanged,
  });

  final BillingPeriod selected;
  final SubscriptionPlanType planType;
  final Set<String> selectedGrades;
  final ValueChanged<BillingPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        for (var i = 0; i < billingPeriodOptions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _BillingPeriodTab(
              option: billingPeriodOptions[i],
              selected: selected == billingPeriodOptions[i].period,
              price: subscriptionTotalPrice(
                planType: planType,
                period: billingPeriodOptions[i].period,
                selectedGrades: selectedGrades,
              ),
              onTap: () => onChanged(billingPeriodOptions[i].period),
            ),
          ),
        ],
        ],
      ),
    );
  }
}

class _BillingPeriodTab extends StatelessWidget {
  const _BillingPeriodTab({
    required this.option,
    required this.selected,
    required this.price,
    required this.onTap,
  });

  final BillingPeriodOption option;
  final bool selected;
  final int price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.12) : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
          border: Border.all(
            color: selected ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border,
            width: selected ? 1 : 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              option.label,
              style: HomeTextStyles.badge.copyWith(
                fontSize: 10,
                color: selected ? AppColors.accentText : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatPrice(price),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.accentText : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              billingPeriodSuffix(option.period),
              style: HomeTextStyles.bodySmall.copyWith(
                fontSize: 9,
                color: selected ? AppColors.textSecondary : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 11,
              child: Center(
                child: Text(
                  option.discountPercent > 0
                      ? 'Save ${option.discountPercent}%'
                      : '',
                  style: HomeTextStyles.bodySmall.copyWith(
                    fontSize: 8,
                    color: selected ? AppColors.teal : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BundlePlanCard extends StatelessWidget {
  const _BundlePlanCard({
    required this.selected,
    required this.billingPeriod,
    required this.savingsPercent,
    required this.onTap,
  });

  final bool selected;
  final BillingPeriod billingPeriod;
  final int savingsPercent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = subscriptionTotalPrice(
      planType: SubscriptionPlanType.bundle,
      period: billingPeriod,
      selectedGrades: const {},
    );
    final original = undiscountedTotalPrice(
      planType: SubscriptionPlanType.bundle,
      period: billingPeriod,
      selectedGrades: const {},
    );
    final showStrike = original > total;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [AppColors.accentSoft, AppColors.bgElevated]
                : [AppColors.bgElevated, AppColors.bgElevated],
          ),
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.45)
                : AppColors.border,
            width: selected ? 1 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _MiniBadge(label: 'RECOMMENDED', color: AppColors.accent),
                      const SizedBox(width: 6),
                      _MiniBadge(
                        label: 'Save $savingsPercent%',
                        color: AppColors.teal,
                        outlined: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All grades bundle',
                    style: HomeTextStyles.cardTitle.copyWith(fontSize: 14),
                  ),
                  Text(
                    'Grade 9–12 · Natural & Social',
                    style: HomeTextStyles.bodySmall.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? AppColors.accentText : AppColors.textMuted,
                  size: 20,
                ),
                const SizedBox(height: 6),
                Text(
                  formatPrice(total),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentText,
                  ),
                ),
                Text(
                  billingPeriodSuffix(billingPeriod),
                  style: HomeTextStyles.bodySmall.copyWith(fontSize: 9),
                ),
                if (showStrike)
                  Text(
                    formatPrice(original),
                    style: HomeTextStyles.bodySmall.copyWith(
                      fontSize: 9,
                      decoration: TextDecoration.lineThrough,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GradePlanCard extends StatelessWidget {
  const _GradePlanCard({
    required this.option,
    required this.selected,
    required this.billingPeriod,
    required this.onTap,
  });

  final GradeSubscriptionOption option;
  final bool selected;
  final BillingPeriod billingPeriod;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = gradeAccentFor(option.grade);
    final total = subscriptionTotalPrice(
      planType: SubscriptionPlanType.individual,
      period: billingPeriod,
      selectedGrades: {option.grade},
    );

    final gradeNumber = option.grade.replaceAll('Grade ', '');

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.08) : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.4) : AppColors.border,
            width: selected ? 1 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      gradeNumber,
                      style: HomeTextStyles.badge.copyWith(
                        color: accent,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? accent : AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.grade,
                  style: HomeTextStyles.cardTitle.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  formatPrice(total),
                  style: HomeTextStyles.badge.copyWith(
                    color: selected ? accent : AppColors.textPrimary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  billingPeriodSuffix(billingPeriod),
                  style: HomeTextStyles.bodySmall.copyWith(fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.label,
    required this.color,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: outlined ? color.withValues(alpha: 0.12) : color,
        borderRadius: BorderRadius.circular(5),
        border: outlined
            ? Border.all(color: color.withValues(alpha: 0.35), width: 0.5)
            : null,
      ),
      child: Text(
        label,
        style: HomeTextStyles.badge.copyWith(
          fontSize: 8,
          color: outlined ? color : Colors.white,
        ),
      ),
    );
  }
}

class _PayNowButton extends StatefulWidget {
  const _PayNowButton({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_PayNowButton> createState() => _PayNowButtonState();
}

class _PayNowButtonState extends State<_PayNowButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _beat;

  @override
  void initState() {
    super.initState();
    _setupBeat();
  }

  @override
  void didUpdateWidget(covariant _PayNowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _setupBeat();
    }
  }

  void _setupBeat() {
    _beat?.dispose();
    _beat = null;
    if (!widget.enabled) return;

    _beat = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _beat?.dispose();
    super.dispose();
  }

  double _heartbeatScale(double t) {
    if (t < 0.12) return 1.0 + (t / 0.12) * 0.06;
    if (t < 0.22) return 1.06 - ((t - 0.12) / 0.10) * 0.06;
    if (t < 0.34) return 1.0 + ((t - 0.22) / 0.12) * 0.035;
    if (t < 0.42) return 1.035 - ((t - 0.34) / 0.08) * 0.035;
    return 1.0;
  }

  double _glowStrength(double t) {
    final scale = _heartbeatScale(t);
    return ((scale - 1.0) / 0.06).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final button = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: widget.enabled ? AppColors.accent : AppColors.bgElevated,
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        border: Border.all(
          color: widget.enabled
              ? AppColors.accent.withValues(alpha: 0.5)
              : AppColors.border,
          width: 0.5,
        ),
      ),
      child: Text(
        'Pay Now',
        style: HomeTextStyles.badge.copyWith(
          fontSize: 13,
          color: widget.enabled ? Colors.white : AppColors.textMuted,
        ),
      ),
    );

    if (_beat == null) {
      return GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: button,
      );
    }

    return AnimatedBuilder(
      animation: _beat!,
      builder: (context, child) {
        final scale = _heartbeatScale(_beat!.value);
        final glow = _glowStrength(_beat!.value);

        return Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.18 + glow * 0.28),
                  blurRadius: 10 + glow * 10,
                  spreadRadius: glow * 1.5,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: button,
      ),
    );
  }
}

class _SubscribeFooter extends StatelessWidget {
  const _SubscribeFooter({
    required this.planSummary,
    required this.totalPrice,
    required this.originalPrice,
    required this.billingPeriod,
    required this.canSubscribe,
    required this.onSubscribe,
    this.referralDiscountPercent = 0,
  });

  final String planSummary;
  final int totalPrice;
  final int? originalPrice;
  final BillingPeriod billingPeriod;
  final bool canSubscribe;
  final VoidCallback onSubscribe;
  final int referralDiscountPercent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  planSummary,
                  style: HomeTextStyles.bodySmall.copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (referralDiscountPercent > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Invite discount · $referralDiscountPercent% off',
                    style: HomeTextStyles.bodySmall.copyWith(
                      fontSize: 10,
                      color: AppColors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatPrice(totalPrice),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1, left: 3),
                      child: Text(
                        billingPeriodSuffix(billingPeriod),
                        style: HomeTextStyles.bodySmall.copyWith(fontSize: 10),
                      ),
                    ),
                    if (originalPrice != null) ...[
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: Text(
                          formatPrice(originalPrice!),
                          style: HomeTextStyles.bodySmall.copyWith(
                            fontSize: 10,
                            decoration: TextDecoration.lineThrough,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _PayNowButton(
            enabled: canSubscribe,
            onTap: onSubscribe,
          ),
        ],
      ),
    );
  }
}
