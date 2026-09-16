import 'package:flutter/material.dart';

/// Fallback when neither `dart:io` nor `dart:html` is available.
Widget buildNoteHtmlBody({
  required String html,
  String? sectionAnchor,
  required VoidCallback onLoaded,
  required ValueChanged<String> onError,
  ValueChanged<String>? onExplainSelection,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    onError('Note viewer is not supported on this platform.');
  });
  return const SizedBox.expand();
}
