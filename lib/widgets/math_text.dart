import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/content/content_api.dart';

/// Renders plain text with optional KaTeX (`$...$` / `$$...$$`) and
/// markdown images:
/// - Bundled figures: `![alt](figures/name.svg)` → `assets/content/figures/`
/// - Uploads / remote: `![alt](/uploads/...)` or `https://...`
class MathText extends StatelessWidget {
  const MathText(
    this.source, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
  });

  final String source;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final parts = _splitContent(source);
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final onlyPlain =
        parts.length == 1 && parts.first is _TextPart && !_hasMath(source);

    if (onlyPlain) {
      return Text(source, style: style, textAlign: textAlign);
    }

    final hasImages = parts.any((p) => p is _ImagePart);
    if (!hasImages) {
      return Text.rich(
        _richSpan(parts, baseStyle),
        textAlign: textAlign,
      );
    }

    // Block figures outside Text.rich so SVGs get real layout bounds.
    final figureWidth = (MediaQuery.sizeOf(context).width - 48).clamp(200.0, 720.0);
    final blocks = <Widget>[];
    var run = <_Part>[];

    void flushRun() {
      if (run.isEmpty) return;
      final onlyBlank = run.every(
        (p) => p is _TextPart && p.text.trim().isEmpty,
      );
      if (!onlyBlank) {
        blocks.add(
          Text.rich(
            _richSpan(List<_Part>.from(run), baseStyle),
            textAlign: textAlign,
          ),
        );
      }
      run = [];
    }

    for (final part in parts) {
      if (part is _ImagePart) {
        flushRun();
        blocks.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Align(
              alignment: textAlign == TextAlign.center
                  ? Alignment.center
                  : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: figureWidth,
                  minHeight: 120,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _ExamFigure(
                    url: part.url,
                    alt: part.alt,
                    style: baseStyle,
                    maxWidth: figureWidth,
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        run.add(part);
      }
    }
    flushRun();

    return Column(
      crossAxisAlignment: textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: blocks,
    );
  }
}

TextSpan _richSpan(List<_Part> parts, TextStyle baseStyle) {
  return TextSpan(
    children: [
      for (final part in parts)
        if (part is _TextPart)
          TextSpan(text: part.text, style: baseStyle)
        else if (part is _MathPart)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: part.display ? 8 : 0,
                horizontal: part.display ? 0 : 2,
              ),
              child: Math.tex(
                part.tex,
                mathStyle: part.display ? MathStyle.display : MathStyle.text,
                textStyle: baseStyle,
                onErrorFallback: (_) => Text(
                  part.display ? '\$\$${part.tex}\$\$' : '\$${part.tex}\$',
                  style: baseStyle.copyWith(color: Colors.redAccent),
                ),
              ),
            ),
          ),
    ],
  );
}

bool _hasMath(String source) =>
    source.contains(r'$') || source.contains(r'\(');

String _absoluteUrl(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final base = contentApiBaseUrl().replaceAll(RegExp(r'/$'), '');
  if (url.startsWith('/')) return '$base$url';
  return '$base/$url';
}

bool _isSvgPath(String path) => path.toLowerCase().split('?').first.endsWith('.svg');

/// `figures/foo.svg` or `/figures/foo.svg` → `assets/content/figures/foo.svg`
String? _bundledFigureAssetPath(String url) {
  var path = url.trim();
  if (path.startsWith('asset:')) {
    return path.substring('asset:'.length);
  }
  if (path.startsWith('/figures/')) path = path.substring(1);
  if (path.startsWith('figures/')) {
    return 'assets/content/$path';
  }
  return null;
}

class _ExamFigure extends StatelessWidget {
  const _ExamFigure({
    required this.url,
    required this.alt,
    required this.style,
    required this.maxWidth,
  });

  final String url;
  final String alt;
  final TextStyle style;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final assetPath = _bundledFigureAssetPath(url);
    if (assetPath != null) {
      if (_isSvgPath(assetPath)) {
        return SvgPicture.asset(
          assetPath,
          width: maxWidth,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => _networkOrFallback(
            url: url.startsWith('/') ? url : '/$url',
            alt: alt,
            style: style,
            maxWidth: maxWidth,
          ),
          // Missing asset → try CMS /figures/ then show alt text.
          errorBuilder: (_, __, ___) => _networkOrFallback(
            url: url.startsWith('/') ? url : '/$url',
            alt: alt,
            style: style,
            maxWidth: maxWidth,
          ),
        );
      }
      return Image.asset(
        assetPath,
        width: maxWidth,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _networkOrFallback(
          url: url.startsWith('/') ? url : '/$url',
          alt: alt,
          style: style,
          maxWidth: maxWidth,
        ),
      );
    }

    return _networkOrFallback(
      url: url,
      alt: alt,
      style: style,
      maxWidth: maxWidth,
    );
  }
}

Widget _networkOrFallback({
  required String url,
  required String alt,
  required TextStyle style,
  required double maxWidth,
}) {
  final remote = _absoluteUrl(url);
  if (_isSvgPath(url)) {
    return SvgPicture.network(
      remote,
      width: maxWidth,
      fit: BoxFit.contain,
      placeholderBuilder: (_) =>
          _FigureFallback(alt: alt, path: url, style: style),
      errorBuilder: (_, __, ___) =>
          _FigureFallback(alt: alt, path: url, style: style),
    );
  }
  return Image.network(
    remote,
    width: maxWidth,
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) =>
        _FigureFallback(alt: alt, path: url, style: style),
  );
}

class _FigureFallback extends StatelessWidget {
  const _FigureFallback({
    required this.alt,
    required this.path,
    required this.style,
  });

  final String alt;
  final String path;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFF3F4F6),
      child: Text(
        alt.isEmpty ? 'Figure unavailable ($path)' : alt,
        style: style.copyWith(color: const Color(0xFF6B7280)),
        textAlign: TextAlign.center,
      ),
    );
  }
}

sealed class _Part {}

class _TextPart extends _Part {
  _TextPart(this.text);
  final String text;
}

class _MathPart extends _Part {
  _MathPart(this.tex, {required this.display});
  final String tex;
  final bool display;
}

class _ImagePart extends _Part {
  _ImagePart(this.url, {this.alt = ''});
  final String url;
  final String alt;
}

List<_Part> _splitContent(String source) {
  final regex = RegExp(
    r'!\[([^\]]*)\]\(([^)]+)\)|\$\$([\s\S]+?)\$\$|\$([^\$\n]+?)\$',
  );
  final parts = <_Part>[];
  var start = 0;
  for (final match in regex.allMatches(source)) {
    if (match.start > start) {
      parts.add(_TextPart(source.substring(start, match.start)));
    }
    final imgAlt = match.group(1);
    final imgUrl = match.group(2);
    final display = match.group(3);
    final inline = match.group(4);
    if (imgUrl != null) {
      parts.add(_ImagePart(imgUrl, alt: imgAlt ?? ''));
    } else {
      final tex = (display ?? inline ?? '').trim();
      if (tex.isEmpty) {
        parts.add(_TextPart(match.group(0)!));
      } else {
        parts.add(_MathPart(tex, display: display != null));
      }
    }
    start = match.end;
  }
  if (start < source.length) {
    parts.add(_TextPart(source.substring(start)));
  }
  if (parts.isEmpty) parts.add(_TextPart(source));
  return parts;
}
