// code_highlighter.dart
//
// Tiny, dependency-free syntax highlighter for the docs site.
// Languages: Dart, YAML (pubspec snippets), plain text.
//
//   final span = CodeHighlighter.highlight(
//     code,
//     language: CodeLanguage.dart,
//     theme: CodeTheme.dark,
//     baseStyle: GoogleFonts.jetBrainsMono(fontSize: 12, height: 1.55),
//   );
//   SelectableText.rich(span);
//
// Regex based, so it is not a real parser. It handles keywords, types,
// functions, named arguments, strings (with $interpolation), numbers,
// annotations and comments, which is plenty for component snippets.

import 'package:flutter/material.dart';

enum CodeLanguage { dart, yaml, plain }

/// Colors used by [CodeHighlighter]. Create your own for another look.
@immutable
class CodeTheme {
  const CodeTheme({
    this.text = const Color(0xFFD4D4D4),
    this.keyword = const Color(0xFFC4A7FF),
    this.string = const Color(0xFF9FE3B0),
    this.number = const Color(0xFFF5C07A),
    this.type = const Color(0xFF7DD3FC),
    this.function = const Color(0xFFF9A8D4),
    this.property = const Color(0xFFA5B4FC),
    this.annotation = const Color(0xFFFDBA74),
    this.comment = const Color(0xFF6B7280),
    this.lineNumber = const Color(0xFF4B5563),
  });

  final Color text;
  final Color keyword;
  final Color string;
  final Color number;

  /// Class / enum / type names (Capitalized identifiers).
  final Color type;

  /// Function and method calls.
  final Color function;

  /// Named arguments (`size:`) and YAML keys.
  final Color property;
  final Color annotation;
  final Color comment;
  final Color lineNumber;

  /// Calm dark palette that fits a black UI.
  static const CodeTheme dark = CodeTheme();
}

class CodeHighlighter {
  const CodeHighlighter._();

  /// Returns a [TextSpan] tree ready for `Text.rich` / `SelectableText.rich`.
  static TextSpan highlight(
      String code, {
        CodeLanguage language = CodeLanguage.dart,
        CodeTheme theme = CodeTheme.dark,
        required TextStyle baseStyle,
      }) {
    final children = switch (language) {
      CodeLanguage.dart => _dart(code, theme),
      CodeLanguage.yaml => _yaml(code, theme),
      CodeLanguage.plain => <InlineSpan>[TextSpan(text: code)],
    };
    return TextSpan(
      style: baseStyle.copyWith(color: theme.text),
      children: children,
    );
  }

  // -------------------------------------------------------------------------
  // Dart
  // -------------------------------------------------------------------------

  // \x27 = ' and \x22 = " so the pattern can live in a raw string.
  static final RegExp _dartRe = RegExp(
    r'(?<comment>//.*|/\*[\s\S]*?\*/)'
    r'|(?<string>r?\x27\x27\x27[\s\S]*?\x27\x27\x27'
    r'|r?\x22\x22\x22[\s\S]*?\x22\x22\x22'
    r'|r\x27[^\x27\n]*\x27'
    r'|r\x22[^\x22\n]*\x22'
    r'|\x27(?:\\.|[^\x27\\\n])*\x27'
    r'|\x22(?:\\.|[^\x22\\\n])*\x22)'
    r'|(?<annotation>@[A-Za-z_]\w*)'
    r'|(?<number>\b0x[0-9a-fA-F]+\b|\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b)'
    r'|(?<word>[A-Za-z_]\w*)',
  );

  static final RegExp _interp = RegExp(r'\$\{[^}]*\}|\$[A-Za-z_]\w*');
  static final RegExp _typeName = RegExp(r'^_*[A-Z]');

  static const Set<String> _literals = {'true', 'false', 'null'};

  static const Set<String> _keywords = {
    'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case',
    'catch', 'class', 'const', 'continue', 'covariant', 'default', 'deferred',
    'do', 'dynamic', 'else', 'enum', 'export', 'extends', 'extension',
    'external', 'factory', 'final', 'finally', 'for', 'get', 'hide', 'if',
    'implements', 'import', 'in', 'interface', 'is', 'late', 'library',
    'mixin', 'new', 'on', 'operator', 'part', 'required', 'rethrow', 'return',
    'sealed', 'set', 'show', 'static', 'super', 'switch', 'sync', 'this',
    'throw', 'try', 'typedef', 'var', 'void', 'when', 'while', 'with', 'yield',
  };

  static List<InlineSpan> _dart(String code, CodeTheme t) {
    final spans = <InlineSpan>[];
    var last = 0;

    for (final m in _dartRe.allMatches(code)) {
      if (m.start > last) {
        spans.add(TextSpan(text: code.substring(last, m.start)));
      }
      final text = m.group(0)!;

      if (m.namedGroup('comment') != null) {
        spans.add(TextSpan(
          text: text,
          style: TextStyle(color: t.comment, fontStyle: FontStyle.italic),
        ));
      } else if (m.namedGroup('string') != null) {
        spans.addAll(_string(text, t));
      } else if (m.namedGroup('annotation') != null) {
        spans.add(TextSpan(text: text, style: TextStyle(color: t.annotation)));
      } else if (m.namedGroup('number') != null) {
        spans.add(TextSpan(text: text, style: TextStyle(color: t.number)));
      } else {
        final color = _wordColor(text, code, m.end, t);
        spans.add(color == null
            ? TextSpan(text: text)
            : TextSpan(text: text, style: TextStyle(color: color)));
      }
      last = m.end;
    }
    if (last < code.length) spans.add(TextSpan(text: code.substring(last)));
    return spans;
  }

  static Color? _wordColor(String w, String code, int end, CodeTheme t) {
    if (_literals.contains(w)) return t.number;
    if (_keywords.contains(w)) return t.keyword;
    if (_typeName.hasMatch(w)) return t.type;

    // named argument: `size: 260` (colon right after the name, not `::`)
    if (end < code.length &&
        code[end] == ':' &&
        !(end + 1 < code.length && code[end + 1] == ':')) {
      return t.property;
    }

    // call: `foo(`  or  `foo (`
    var i = end;
    while (i < code.length && (code[i] == ' ' || code[i] == '\t')) {
      i++;
    }
    if (i < code.length && code[i] == '(') return t.function;
    return null;
  }

  /// Splits a string literal so `$name` and `${expr}` get their own color.
  static List<InlineSpan> _string(String s, CodeTheme t) {
    final base = TextStyle(color: t.string);
    final isRaw =
        s.length > 1 && s[0] == 'r' && (s[1] == "'" || s[1] == '"');
    if (isRaw || !s.contains(r'$')) return [TextSpan(text: s, style: base)];

    final out = <InlineSpan>[];
    var last = 0;
    for (final m in _interp.allMatches(s)) {
      if (m.start > last) {
        out.add(TextSpan(text: s.substring(last, m.start), style: base));
      }
      out.add(TextSpan(
        text: m.group(0),
        style: TextStyle(color: t.property),
      ));
      last = m.end;
    }
    if (last < s.length) {
      out.add(TextSpan(text: s.substring(last), style: base));
    }
    return out;
  }

  // -------------------------------------------------------------------------
  // YAML (pubspec snippets)
  // -------------------------------------------------------------------------

  static final RegExp _yamlRe = RegExp(
    r'(?<comment>#.*)'
    r'|(?<string>\x27[^\x27\n]*\x27|\x22(?:\\.|[^\x22\\\n])*\x22)'
    r'|(?<number>\b\d+(?:\.\d+)*\b)'
    r'|(?<word>[A-Za-z_][\w\-]*)',
  );

  static const Set<String> _yamlLiterals = {
    'true', 'false', 'null', 'yes', 'no',
  };

  static List<InlineSpan> _yaml(String code, CodeTheme t) {
    final spans = <InlineSpan>[];
    var last = 0;

    for (final m in _yamlRe.allMatches(code)) {
      if (m.start > last) {
        spans.add(TextSpan(text: code.substring(last, m.start)));
      }
      final text = m.group(0)!;

      if (m.namedGroup('comment') != null) {
        spans.add(TextSpan(
          text: text,
          style: TextStyle(color: t.comment, fontStyle: FontStyle.italic),
        ));
      } else if (m.namedGroup('string') != null) {
        spans.add(TextSpan(text: text, style: TextStyle(color: t.string)));
      } else if (m.namedGroup('number') != null) {
        spans.add(TextSpan(text: text, style: TextStyle(color: t.number)));
      } else if (m.end < code.length && code[m.end] == ':') {
        spans.add(TextSpan(text: text, style: TextStyle(color: t.property)));
      } else if (_yamlLiterals.contains(text)) {
        spans.add(TextSpan(text: text, style: TextStyle(color: t.number)));
      } else {
        spans.add(TextSpan(text: text));
      }
      last = m.end;
    }
    if (last < code.length) spans.add(TextSpan(text: code.substring(last)));
    return spans;
  }
}