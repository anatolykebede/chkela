import 'package:flutter/material.dart';

import 'note_html_body_stub.dart'
    if (dart.library.html) 'note_html_body_web.dart'
    if (dart.library.io) 'note_html_body_io.dart';

/// Renders note HTML on the current platform (WebView on mobile, iframe on web).
class NoteHtmlBody extends StatelessWidget {
  const NoteHtmlBody({
    super.key,
    required this.html,
    this.sectionAnchor,
    required this.onLoaded,
    required this.onError,
    this.onExplainSelection,
  });

  final String html;
  final String? sectionAnchor;
  final VoidCallback onLoaded;
  final ValueChanged<String> onError;
  final ValueChanged<String>? onExplainSelection;

  @override
  Widget build(BuildContext context) {
    return buildNoteHtmlBody(
      html: html,
      sectionAnchor: sectionAnchor,
      onLoaded: onLoaded,
      onError: onError,
      onExplainSelection: onExplainSelection,
    );
  }
}
