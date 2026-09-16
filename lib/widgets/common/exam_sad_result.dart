import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Sad-face Lottie overlay pinned to the top of the exam results screen.
class ExamSadResultLottie extends StatelessWidget {
  const ExamSadResultLottie({super.key});

  static const _assetPath = 'assets/lottie/new sad face.json';

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.translate(
        offset: const Offset(0, -10),
        child: SizedBox(
          height: 156,
          width: double.infinity,
          child: Lottie.asset(
            _assetPath,
            fit: BoxFit.contain,
            repeat: true,
            delegates: LottieDelegates(
              values: [
                ValueDelegate.opacity(const ['Shadow'], value: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
