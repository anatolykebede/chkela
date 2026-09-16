import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'home_mock_data.dart';

const subscriptionCurrency = 'ETB';
const gradeMonthlyPrice = 79;
const allGradesBundlePrice = 199;

enum SubscriptionPlanType { bundle, individual }

enum BillingPeriod { monthly, sixMonth, yearly }

enum SubscriptionPaymentMethod { cbe, chapa }

const cbeTransferAccountName = 'Chkela Education PLC';
const cbeTransferAccountNumber = '1000456789012';

const paymentSupportTelegramUsername = 'chkelaadmin';
const paymentSupportTelegramHandle = '@$paymentSupportTelegramUsername';
const paymentSupportTelegramDeepLink =
    'tg://resolve?domain=$paymentSupportTelegramUsername';
const paymentSupportTelegramUrl = 'https://t.me/$paymentSupportTelegramUsername';

const cbePaymentSteps = [
  'Open CBE mobile banking and transfer the exact amount to the account below.',
  'Take a screenshot or photo of your payment receipt.',
  'Tap Attach receipt and choose the image from your gallery.',
  'Tap Submit — we\'ll verify and activate your plan in a sec.',
];

extension SubscriptionPaymentMethodX on SubscriptionPaymentMethod {
  String get label => switch (this) {
        SubscriptionPaymentMethod.cbe => 'CBE',
        SubscriptionPaymentMethod.chapa => 'Chapa',
      };

  String get title => switch (this) {
        SubscriptionPaymentMethod.cbe => 'CBE Bank Transfer',
        SubscriptionPaymentMethod.chapa => 'Chapa Checkout',
      };

  String get pickerBadge => switch (this) {
        SubscriptionPaymentMethod.cbe => 'BANK',
        SubscriptionPaymentMethod.chapa => 'ONLINE',
      };

  String get logoAsset => switch (this) {
        SubscriptionPaymentMethod.cbe => 'assets/payment/cbe_logo.svg',
        SubscriptionPaymentMethod.chapa => 'assets/payment/chapa_logo.svg',
      };

  IconData get icon => switch (this) {
        SubscriptionPaymentMethod.cbe => Icons.account_balance_rounded,
        SubscriptionPaymentMethod.chapa => Icons.bolt_rounded,
      };

  Color get accent => switch (this) {
        SubscriptionPaymentMethod.cbe => const Color(0xFF7B2D8E),
        SubscriptionPaymentMethod.chapa => const Color(0xFF0BAF8F),
      };

  Color get accentSoft => switch (this) {
        SubscriptionPaymentMethod.cbe => const Color(0xFF2A1235),
        SubscriptionPaymentMethod.chapa => const Color(0xFF0A2E26),
      };
}

class BillingPeriodOption {
  const BillingPeriodOption({
    required this.period,
    required this.label,
    required this.months,
    required this.discountPercent,
  });

  final BillingPeriod period;
  final String label;
  final int months;
  final int discountPercent;
}

const billingPeriodOptions = [
  BillingPeriodOption(
    period: BillingPeriod.monthly,
    label: 'Monthly',
    months: 1,
    discountPercent: 0,
  ),
  BillingPeriodOption(
    period: BillingPeriod.sixMonth,
    label: '6 months',
    months: 6,
    discountPercent: 10,
  ),
  BillingPeriodOption(
    period: BillingPeriod.yearly,
    label: 'Year',
    months: 12,
    discountPercent: 20,
  ),
];

BillingPeriodOption billingOptionFor(BillingPeriod period) {
  return billingPeriodOptions.firstWhere((option) => option.period == period);
}

int bundleOriginalMonthlyPrice() => grades.length * gradeMonthlyPrice;

int bundleSavingsPercent() {
  final original = bundleOriginalMonthlyPrice();
  if (original <= 0) return 0;
  return (((original - allGradesBundlePrice) / original) * 100).round();
}

int individualMonthlyPrice(Set<String> selectedGrades) =>
    selectedGrades.length * gradeMonthlyPrice;

int monthlyBasePrice({
  required SubscriptionPlanType planType,
  required Set<String> selectedGrades,
}) {
  if (planType == SubscriptionPlanType.bundle) return allGradesBundlePrice;
  return individualMonthlyPrice(selectedGrades);
}

int priceForBillingPeriod(int monthlyBase, BillingPeriod period) {
  final option = billingOptionFor(period);
  return ((monthlyBase * option.months) * (100 - option.discountPercent) / 100)
      .round();
}

int subscriptionTotalPrice({
  required SubscriptionPlanType planType,
  required BillingPeriod period,
  required Set<String> selectedGrades,
}) {
  return priceForBillingPeriod(
    monthlyBasePrice(planType: planType, selectedGrades: selectedGrades),
    period,
  );
}

int undiscountedTotalPrice({
  required SubscriptionPlanType planType,
  required BillingPeriod period,
  required Set<String> selectedGrades,
}) {
  final monthlyBase =
      monthlyBasePrice(planType: planType, selectedGrades: selectedGrades);
  return monthlyBase * billingOptionFor(period).months;
}

String billingPeriodSuffix(BillingPeriod period) {
  switch (period) {
    case BillingPeriod.monthly:
      return 'per month';
    case BillingPeriod.sixMonth:
      return 'per 6 month';
    case BillingPeriod.yearly:
      return 'per year';
  }
}

String unlockContentMessage({
  required SubscriptionPlanType planType,
  required Set<String> selectedGrades,
}) {
  if (planType == SubscriptionPlanType.bundle) {
    return "You'll unlock all the Grade 9–12 content.";
  }

  final sorted = selectedGrades.toList()..sort();
  if (sorted.isEmpty) {
    return 'Select a grade to see what you will unlock.';
  }
  if (sorted.length == 1) {
    return "You'll unlock all the ${sorted.first} content.";
  }

  return "You'll unlock all the ${sorted.join(', ')} content.";
}

String billingPeriodSummary(BillingPeriod period) {
  switch (period) {
    case BillingPeriod.monthly:
      return 'Monthly billing';
    case BillingPeriod.sixMonth:
      return '6-month billing';
    case BillingPeriod.yearly:
      return 'Yearly billing';
  }
}

class GradeSubscriptionOption {
  const GradeSubscriptionOption({
    required this.grade,
    required this.subjectCount,
    required this.topicCount,
  });

  final String grade;
  final int subjectCount;
  final int topicCount;
}

const gradeSubscriptionOptions = [
  GradeSubscriptionOption(grade: 'Grade 9', subjectCount: 6, topicCount: 142),
  GradeSubscriptionOption(grade: 'Grade 10', subjectCount: 6, topicCount: 158),
  GradeSubscriptionOption(
    grade: 'Grade 11 · Natural',
    subjectCount: 6,
    topicCount: 171,
  ),
  GradeSubscriptionOption(
    grade: 'Grade 11 · Social',
    subjectCount: 6,
    topicCount: 171,
  ),
  GradeSubscriptionOption(
    grade: 'Grade 12 · Natural',
    subjectCount: 6,
    topicCount: 186,
  ),
  GradeSubscriptionOption(
    grade: 'Grade 12 · Social',
    subjectCount: 6,
    topicCount: 186,
  ),
];

String formatPrice(int amount) => '$subscriptionCurrency $amount';

String knownGradeCopy(
  Set<String> selectedGrades,
  SubscriptionPlanType planType,
) {
  if (planType == SubscriptionPlanType.individual &&
      selectedGrades.length == 1) {
    return 'Suggested for you — unlock every subject in ${selectedGrades.first}.';
  }
  return 'Full access to every subject in your paid grade.';
}

class SubscriptionWalkthroughStep {
  const SubscriptionWalkthroughStep({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

const subscriptionWalkthroughSteps = [
  SubscriptionWalkthroughStep(
    title: 'Notes & flashcards',
    subtitle: 'Chapter notes and flashcard decks for every topic.',
    icon: Icons.menu_book_outlined,
  ),
  SubscriptionWalkthroughStep(
    title: 'Flashcards',
    subtitle: 'Review key concepts with spaced repetition decks.',
    icon: Icons.style_outlined,
  ),
  SubscriptionWalkthroughStep(
    title: 'Exams & matric papers',
    subtitle: 'Chapter exams and past matric questions by year.',
    icon: Icons.fact_check_outlined,
  ),
  SubscriptionWalkthroughStep(
    title: 'AI study guider',
    subtitle: 'Explanations and help tailored to your syllabus.',
    icon: Icons.auto_awesome_outlined,
  ),
];

Color gradeAccentFor(String grade) {
  if (grade.startsWith('Grade 9')) return AppColors.teal;
  if (grade.startsWith('Grade 10')) return AppColors.accentText;
  if (grade.startsWith('Grade 11')) return AppColors.amber;
  if (grade.startsWith('Grade 12')) return AppColors.info;
  return AppColors.accentText;
}
