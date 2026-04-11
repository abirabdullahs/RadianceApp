import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;

import '../../student/notes/note_markdown_style.dart';

class MixedContentRenderer extends StatelessWidget {
  const MixedContentRenderer({
    super.key,
    required this.content,
  });

  final String content;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: content,
      selectable: false,
      styleSheet: bengaliNoteMarkdownStyleSheet(context),
      builders: {
        'latex': LatexElementBuilder(),
      },
      extensionSet: md.ExtensionSet(
        <md.BlockSyntax>[
          ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
          LatexBlockSyntax(),
        ],
        <md.InlineSyntax>[
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
          LatexInlineSyntax(),
        ],
      ),
    );
  }
}
