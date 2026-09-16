import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/content/content_api.dart';

Widget buildNoteHtmlBody({
  required String html,
  String? sectionAnchor,
  required VoidCallback onLoaded,
  required ValueChanged<String> onError,
  ValueChanged<String>? onExplainSelection,
}) {
  return _IoNoteHtmlBody(
    html: html,
    sectionAnchor: sectionAnchor,
    onLoaded: onLoaded,
    onError: onError,
    onExplainSelection: onExplainSelection,
  );
}

class _IoNoteHtmlBody extends StatefulWidget {
  const _IoNoteHtmlBody({
    required this.html,
    required this.sectionAnchor,
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
  State<_IoNoteHtmlBody> createState() => _IoNoteHtmlBodyState();
}

class _IoNoteHtmlBodyState extends State<_IoNoteHtmlBody> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final base = '${contentApiBaseUrl().replaceAll(RegExp(r'/$'), '')}/';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFAF9FC))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => unawaited(_onPageFinished()),
          onWebResourceError: (error) {
            // CDN/font/script failures must not blank the whole note.
            if (error.isForMainFrame == false) return;
            widget.onError(error.description);
          },
        ),
      );
    if (widget.onExplainSelection != null) {
      _controller.addJavaScriptChannel(
        'ChkelaExplain',
        onMessageReceived: (message) {
          final text = message.message.trim();
          if (text.isEmpty || !mounted) return;
          widget.onExplainSelection!(text);
        },
      );
    }
    unawaited(_controller.loadHtmlString(widget.html, baseUrl: base));
  }

  Future<void> _onPageFinished() async {
    final anchor = widget.sectionAnchor;
    if (anchor != null) {
      await _controller.runJavaScript(
        "document.getElementById('$anchor')?.scrollIntoView({block:'start'});",
      );
    }
    widget.onLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
