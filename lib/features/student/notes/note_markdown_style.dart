import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

/// Markdown + LaTeX notes: theme default uses Roboto + monospace `code`, which
/// breaks Bengali shaping (letters split wrong). Use Hind Siliguri everywhere.
MarkdownStyleSheet bengaliNoteMarkdownStyleSheet(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  TextStyle bn({
    double fontSize = 16,
    FontWeight? weight,
    FontStyle? style,
    Color? color,
    double height = 1.7,
    TextDecoration? decoration,
    Color? backgroundColor,
  }) {
    return GoogleFonts.hindSiliguri(
      fontSize: fontSize,
      fontWeight: weight ?? FontWeight.w400,
      fontStyle: style,
      height: height,
      color: color ?? cs.onSurface,
      decoration: decoration,
      backgroundColor: backgroundColor,
    );
  }

  final body = bn();
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: body,
    h1: bn(fontSize: 28, weight: FontWeight.w800, height: 1.35),
    h2: bn(fontSize: 24, weight: FontWeight.w700, height: 1.35),
    h3: bn(fontSize: 20, weight: FontWeight.w700, height: 1.4),
    h4: bn(fontSize: 18, weight: FontWeight.w700, height: 1.45),
    h5: bn(fontSize: 17, weight: FontWeight.w600, height: 1.5),
    h6: bn(fontSize: 16, weight: FontWeight.w600, height: 1.5),
    em: bn(style: FontStyle.italic),
    strong: bn(weight: FontWeight.w700),
    del: bn(decoration: TextDecoration.lineThrough),
    blockquote: bn(color: cs.onSurfaceVariant),
    img: body,
    checkbox: bn(color: cs.primary, weight: FontWeight.w600),
    // Avoid monospace — it lacks Bengali glyphs and breaks clusters.
    code: bn(
      fontSize: 14,
      height: 1.45,
      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.95),
    ),
    listBullet: body,
    tableHead: bn(weight: FontWeight.w700),
    tableBody: body,
    a: bn(
      color: cs.primary,
      weight: FontWeight.w600,
      decoration: TextDecoration.underline,
    ),
  );
}
