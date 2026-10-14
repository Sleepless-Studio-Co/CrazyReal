import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

class ContrastIssue {
  ContrastIssue(this.text, this.fg, this.bg, this.ratio, this.required);

  final String text;
  final Color fg;
  final Color bg;
  final double ratio;
  final double required;

  String _hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';

  @override
  String toString() => '"$text" ${_hex(fg)} on ${_hex(bg)}: '
      '${ratio.toStringAsFixed(2)}:1 < ${required.toStringAsFixed(1)}:1';
}

/// Colour painted behind [element]: composites ancestor fills (ColoredBox,
/// DecoratedBox, Material, PhysicalModel...) until an opaque one is found.
Color backgroundOf(Element element) {
  final layers = <Color>[];
  element.visitAncestorElements((ancestor) {
    final color = _fillOf(ancestor);
    if (color != null && color.a > 0) {
      layers.add(color);
      if (color.a >= 0.999) return false;
    }
    return true;
  });
  var result =
      layers.isNotEmpty && layers.last.a >= 0.999 ? layers.last : Colors.white;
  for (final layer in layers.reversed
      .skip(layers.isNotEmpty && layers.last.a >= 0.999 ? 1 : 0)) {
    result = Color.alphaBlend(layer, result);
  }
  return result;
}

Color? _fillOf(Element element) {
  final widget = element.widget;
  if (widget is ColoredBox) return widget.color;
  if (widget is DecoratedBox && widget.decoration is BoxDecoration) {
    final d = widget.decoration as BoxDecoration;
    // For gradients, judge against the gradient colour that contrasts least
    // with dark text, i.e. its darkest stop (callers check both directions).
    return d.color ?? _worstGradientStop(d.gradient);
  }
  if (widget is PhysicalModel) return widget.color;
  if (widget is PhysicalShape) return widget.color;
  return null;
}

Color? _worstGradientStop(Gradient? gradient) {
  if (gradient == null || gradient.colors.isEmpty) return null;
  final colors = [...gradient.colors]
    ..sort((a, b) => a.computeLuminance().compareTo(b.computeLuminance()));
  // Mid-luminance stop is the hardest case for both light and dark text.
  return colors[colors.length ~/ 2];
}

/// Checks every visible text and icon on screen against its background.
/// Text needs 4.5:1 (3:1 when large), icons 3:1 (WCAG 1.4.3 / 1.4.11).
List<ContrastIssue> auditContrast(WidgetTester tester) {
  final issues = <ContrastIssue>[];
  for (final element in find.byType(RichText).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderParagraph || !render.hasSize || render.size.isEmpty)
      continue;
    if (_isHiddenOrOverMedia(element)) continue;
    final bg = backgroundOf(element);
    void visit(InlineSpan span, TextStyle? inherited) {
      final style = inherited?.merge(span.style) ?? span.style;
      if (span is TextSpan) {
        final text = span.text ?? '';
        final color = style?.color;
        if (text.trim().isNotEmpty && color != null && color.a > 0.05) {
          final fg = Color.alphaBlend(color, bg);
          final isIcon = (style?.fontFamily ?? '').contains('MaterialIcons');
          final size = style?.fontSize ?? 14;
          final bold = (style?.fontWeight ?? FontWeight.normal).index >=
              FontWeight.w700.index;
          final large = size >= 24 || (bold && size >= 18.66);
          final required = isIcon || large ? 3.0 : 4.5;
          final ratio = contrastRatio(fg, bg);
          if (ratio + 0.005 < required) {
            issues.add(ContrastIssue(
                isIcon ? 'icon U+${text.runes.first.toRadixString(16)}' : text,
                fg,
                bg,
                ratio,
                required));
          }
        }
        span.children?.forEach((c) => visit(c, style));
      }
    }

    visit(render.text, null);
  }
  return issues;
}

/// Text drawn on top of a photo/video (inside a Stack next to media) or
/// faded out is not judged against the paper background.
bool _isHiddenOrOverMedia(Element element) {
  var hidden = false;
  element.visitAncestorElements((a) {
    final w = a.widget;
    if (w is Opacity && w.opacity < 0.05) hidden = true;
    if (w is Offstage && w.offstage) hidden = true;
    if (w is Visibility && !w.visible) hidden = true;
    if (w is Stack) {
      var hasMedia = false;
      a.visitChildElements((c) {
        if (c.widget is Image || c.widget is Hero) hasMedia = true;
      });
      if (hasMedia) hidden = true;
    }
    return !hidden;
  });
  return hidden;
}

Future<void> expectReadable(WidgetTester tester, String screen) async {
  final issues = auditContrast(tester);
  expect(issues, isEmpty,
      reason: '$screen has unreadable text:\n${issues.join('\n')}');
}
