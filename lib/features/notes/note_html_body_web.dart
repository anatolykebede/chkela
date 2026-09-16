import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

Widget buildNoteHtmlBody({
  required String html,
  String? sectionAnchor,
  required VoidCallback onLoaded,
  required ValueChanged<String> onError,
  ValueChanged<String>? onExplainSelection,
}) {
  return _WebNoteHtmlBody(
    html: html,
    sectionAnchor: sectionAnchor,
    onLoaded: onLoaded,
    onError: onError,
  );
}

class _WebNoteHtmlBody extends StatefulWidget {
  const _WebNoteHtmlBody({
    required this.html,
    required this.sectionAnchor,
    required this.onLoaded,
    required this.onError,
  });

  final String html;
  final String? sectionAnchor;
  final VoidCallback onLoaded;
  final ValueChanged<String> onError;

  @override
  State<_WebNoteHtmlBody> createState() => _WebNoteHtmlBodyState();
}

class _WebNoteHtmlBodyState extends State<_WebNoteHtmlBody> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType =
        'chkela-note-html-${identityHashCode(this)}-${DateTime.now().microsecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      var htmlDoc = widget.html;
      final anchor = widget.sectionAnchor;
      if (anchor != null && anchor.isNotEmpty) {
        htmlDoc = '''
$htmlDoc
<script>
  window.addEventListener('load', function () {
    var el = document.getElementById('$anchor');
    if (el) el.scrollIntoView({ block: 'start' });
  });
</script>
''';
      }

      final iframe = html.IFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#FAF9FC'
        ..srcdoc = htmlDoc;

      iframe.onLoad.listen((_) {
        widget.onLoaded();
      });

      return iframe;
    });

    // Safety timeout so the spinner never hangs if onLoad is missed.
    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) widget.onLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
