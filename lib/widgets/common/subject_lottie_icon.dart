import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../data/study_subjects.dart';

/// Renders a subject's Lottie animation, or falls back to [StudySubject.icon].
class SubjectLottieIcon extends StatelessWidget {
  const SubjectLottieIcon({
    super.key,
    required this.subject,
    required this.size,
    this.fallbackColor,
    this.fit = BoxFit.contain,
  });

  final StudySubject subject;
  final double size;
  final Color? fallbackColor;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final asset = subject.lottieAsset;
    if (asset == null) {
      if (subject.badgeLabel != null) {
        return Text(
          subject.badgeLabel!,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: size * 0.55,
            fontWeight: FontWeight.w800,
            color: fallbackColor ?? subject.iconColor,
            height: 1,
          ),
        );
      }
      return Icon(
        subject.icon,
        size: size * 0.55,
        color: fallbackColor ?? subject.iconColor,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        asset,
        fit: fit,
        alignment: Alignment.center,
        repeat: true,
        animate: true,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            subject.icon,
            size: size * 0.55,
            color: fallbackColor ?? subject.iconColor,
          );
        },
      ),
    );
  }
}
