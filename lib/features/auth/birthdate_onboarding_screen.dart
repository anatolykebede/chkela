import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import 'auth_provider.dart';
import 'onboarding_widgets.dart';

class BirthdateOnboardingScreen extends ConsumerStatefulWidget {
  const BirthdateOnboardingScreen({super.key});

  @override
  ConsumerState<BirthdateOnboardingScreen> createState() =>
      _BirthdateOnboardingScreenState();
}

class _BirthdateOnboardingScreenState
    extends ConsumerState<BirthdateOnboardingScreen> {
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _dayCtrl;
  late final FixedExtentScrollController _yearCtrl;

  late int _month; // 1-12
  late int _day;
  late int _year;

  static const _minYear = 1985;
  static const _maxYear = 2015;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(authProvider).birthdate ??
        DateTime(2000, 10, 8);
    _month = initial.month;
    _day = initial.day.clamp(1, _daysInMonth(initial.year, initial.month));
    _year = initial.year.clamp(_minYear, _maxYear);

    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
    _yearCtrl = FixedExtentScrollController(
      initialItem: _maxYear - _year,
    );
  }

  @override
  void dispose() {
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  List<int> get _years =>
      List.generate(_maxYear - _minYear + 1, (i) => _maxYear - i);

  void _clampDay() {
    final maxDay = _daysInMonth(_year, _month);
    if (_day > maxDay) {
      _day = maxDay;
      if (_dayCtrl.hasClients) {
        _dayCtrl.jumpToItem(_day - 1);
      }
    }
  }

  DateTime get _selected => DateTime(_year, _month, _day);

  void _continue() {
    HapticFeedback.selectionClick();
    ref.read(authProvider.notifier).setBirthdate(_selected);
    context.push('/onboarding/interests');
  }

  @override
  Widget build(BuildContext context) {
    final itemStyle = GoogleFonts.inter(
      fontSize: 17,
      fontWeight: FontWeight.w500,
      color: AppColors.textMuted,
    );
    final selectedStyle = GoogleFonts.inter(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: OnboardingColors.accent,
    );

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgress(step: 3, total: 4),
            const SizedBox(height: 36),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'BIRTHDATE?',
                textAlign: TextAlign.center,
                style: onboardingTitleStyle(),
              ),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 44,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: OnboardingColors.accentDeep.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: ListWheelScrollView.useDelegate(
                              controller: _monthCtrl,
                              itemExtent: 44,
                              perspective: 0.003,
                              diameterRatio: 1.4,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (i) {
                                setState(() {
                                  _month = i + 1;
                                  _clampDay();
                                });
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 12,
                                builder: (context, index) {
                                  final selected = index == _month - 1;
                                  return Center(
                                    child: Text(
                                      _months[index],
                                      style: selected
                                          ? selectedStyle
                                          : itemStyle,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: ListWheelScrollView.useDelegate(
                              key: ValueKey('day-$_year-$_month'),
                              controller: _dayCtrl,
                              itemExtent: 44,
                              perspective: 0.003,
                              diameterRatio: 1.4,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (i) {
                                setState(() => _day = i + 1);
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: _daysInMonth(_year, _month),
                                builder: (context, index) {
                                  final selected = index == _day - 1;
                                  return Center(
                                    child: Text(
                                      (index + 1).toString().padLeft(2, '0'),
                                      style: selected
                                          ? selectedStyle
                                          : itemStyle,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: ListWheelScrollView.useDelegate(
                              controller: _yearCtrl,
                              itemExtent: 44,
                              perspective: 0.003,
                              diameterRatio: 1.4,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (i) {
                                setState(() {
                                  _year = _years[i];
                                  _clampDay();
                                });
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: _years.length,
                                builder: (context, index) {
                                  final selected = _years[index] == _year;
                                  return Center(
                                    child: Text(
                                      '${_years[index]}',
                                      style: selected
                                          ? selectedStyle
                                          : itemStyle,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: OnboardingPillButton(
                label: 'Continue',
                emphasized: true,
                onPressed: _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
