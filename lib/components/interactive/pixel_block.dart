// pixel_block.dart — single-file, premium LED-matrix pixel typography for Flutter.
//
// Drop this file into your project (e.g. lib/pixel_block.dart) and either:
//   • run it directly:  flutter run -t lib/pixel_block.dart
//   • or reuse the widgets (PixelText, PixelChar, PixelDisplay, PixelStyle,
//     PixelFont) and delete the DEMO section at the bottom.
//
// Quick use:
//   PixelDisplay(
//     accent: PixelPalette.green,
//     child: PixelText('HELLO\nWORLD', autoFit: true,
//       style: const PixelStyle(activeColor: PixelPalette.green,
//         gradientEnd: PixelPalette.cyan, animation: PixelAnimation.ripple)),
//   )

import 'dart:math' as math;

import 'package:flutter/material.dart';

// ============================================================
// pixel_font
// ============================================================

/// A bitmap font. Each glyph is [rows] integers; each integer is a bitmask of
/// [columns] bits, where the most significant bit is the left-most pixel.
///
/// ```dart
/// // Register your own glyphs on top of the built-in font:
/// final font = PixelFont.classic.extend({
///   '€': [0x0E, 0x11, 0x1E, 0x1E, 0x1E, 0x11, 0x0E],
/// });
/// ```
@immutable
class PixelFont {
  PixelFont({required this.columns, required this.rows, required Map<String, List<int>> glyphs, List<int>? fallback})
    : glyphs = Map.unmodifiable(glyphs),
      blank = List<int>.filled(rows, 0, growable: false),
      fallback = fallback ?? List<int>.filled(rows, 0);

  final int columns;
  final int rows;
  final Map<String, List<int>> glyphs;

  /// Shown for characters the font does not contain (graceful degradation).
  final List<int> fallback;

  /// An all-off glyph.
  final List<int> blank;

  /// Looks up a glyph. Falls back to the upper-case form, then [fallback].
  List<int> glyphFor(String ch) => glyphs[ch] ?? glyphs[ch.toUpperCase()] ?? fallback;

  /// Whether pixel ([row], [col]) of [glyph] is lit.
  bool isOn(List<int> glyph, int row, int col) => ((glyph[row] >> (columns - 1 - col)) & 1) == 1;

  /// Returns a copy with [extra] glyphs added or overriding existing ones.
  PixelFont extend(Map<String, List<int>> extra) => PixelFont(columns: columns, rows: rows, glyphs: {...glyphs, ...extra}, fallback: fallback);

  /// The built-in 5×7 font: A–Z, 0–9, punctuation and a few symbols.
  /// Lower-case letters map to their upper-case glyphs.
  static final PixelFont classic = PixelFont(
    columns: 5,
    rows: 7,
    fallback: const [0x1F, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1F], // hollow box
    glyphs: const {
      ' ': [0, 0, 0, 0, 0, 0, 0],
      'A': [0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
      'B': [0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E],
      'C': [0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E],
      'D': [0x1C, 0x12, 0x11, 0x11, 0x11, 0x12, 0x1C],
      'E': [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F],
      'F': [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10],
      'G': [0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0F],
      'H': [0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
      'I': [0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E],
      'J': [0x07, 0x02, 0x02, 0x02, 0x02, 0x12, 0x0C],
      'K': [0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11],
      'L': [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F],
      'M': [0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11],
      'N': [0x11, 0x11, 0x19, 0x15, 0x13, 0x11, 0x11],
      'O': [0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
      'P': [0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10],
      'Q': [0x0E, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0D],
      'R': [0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11],
      'S': [0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E],
      'T': [0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04],
      'U': [0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
      'V': [0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04],
      'W': [0x11, 0x11, 0x11, 0x15, 0x15, 0x1B, 0x11],
      'X': [0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11],
      'Y': [0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x04],
      'Z': [0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F],
      '0': [0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E],
      '1': [0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E],
      '2': [0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F],
      '3': [0x1F, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0E],
      '4': [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02],
      '5': [0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E],
      '6': [0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E],
      '7': [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],
      '8': [0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E],
      '9': [0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C],
      '!': [4, 4, 4, 4, 4, 0, 4],
      '?': [0x0E, 0x11, 0x01, 0x02, 0x04, 0, 4],
      '.': [0, 0, 0, 0, 0, 0x0C, 0x0C],
      ',': [0, 0, 0, 0, 0x0C, 4, 8],
      ':': [0, 0x0C, 0x0C, 0, 0x0C, 0x0C, 0],
      ';': [0, 0x0C, 0x0C, 0, 0x0C, 4, 8],
      '-': [0, 0, 0, 0x1F, 0, 0, 0],
      '_': [0, 0, 0, 0, 0, 0, 0x1F],
      '+': [0, 4, 4, 0x1F, 4, 4, 0],
      '=': [0, 0, 0x1F, 0, 0x1F, 0, 0],
      '/': [1, 1, 2, 4, 8, 0x10, 0x10],
      '\\': [0x10, 0x10, 8, 4, 2, 1, 1],
      '(': [2, 4, 8, 8, 8, 4, 2],
      ')': [8, 4, 2, 2, 2, 4, 8],
      "'": [4, 4, 8, 0, 0, 0, 0],
      '"': [0x0A, 0x0A, 0x0A, 0, 0, 0, 0],
      '*': [0, 4, 0x15, 0x0E, 0x15, 4, 0],
      '#': [0x0A, 0x0A, 0x1F, 0x0A, 0x1F, 0x0A, 0x0A],
      '@': [0x0E, 0x11, 0x17, 0x15, 0x17, 0x10, 0x0E],
      '&': [0x0C, 0x12, 0x14, 8, 0x15, 0x12, 0x0D],
      '%': [0x18, 0x19, 2, 4, 8, 0x13, 3],
      '\$': [4, 0x0F, 0x14, 0x0E, 5, 0x1E, 4],
      '<': [2, 4, 8, 0x10, 8, 4, 2],
      '>': [8, 4, 2, 1, 2, 4, 8],
      '[': [0x0E, 8, 8, 8, 8, 8, 0x0E],
      ']': [0x0E, 2, 2, 2, 2, 2, 0x0E],
      '{': [3, 4, 4, 8, 4, 4, 3],
      '}': [0x18, 4, 4, 2, 4, 4, 0x18],
      '^': [4, 0x0A, 0x11, 0, 0, 0, 0],
      '~': [0, 0, 8, 0x15, 2, 0, 0],
      '|': [4, 4, 4, 4, 4, 4, 4],
      '♥': [0, 0x0A, 0x1F, 0x1F, 0x0E, 4, 0],
      '★': [4, 4, 0x1F, 0x0E, 0x0E, 0x11, 0],
    },
  );
}

// ============================================================
// pixel_style
// ============================================================

/// Shape of each individual pixel block.
enum PixelShape { square, rounded, circle }

/// How pixels animate when a character appears or changes.
enum PixelAnimation { none, cascade, scan, ripple, random }

/// Ready-made accent colours.
abstract class PixelPalette {
  static const cyan = Color(0xFF19F3FF);
  static const green = Color(0xFF39FF7A);
  static const magenta = Color(0xFFFF2BD6);
  static const amber = Color(0xFFFFB020);
  static const red = Color(0xFFFF4D4D);
  static const violet = Color(0xFFA78BFA);
  static const all = [cyan, green, magenta, amber, red, violet];
}

const Object _unset = Object();

/// Immutable visual configuration shared by [PixelChar] and [PixelText].
@immutable
class PixelStyle {
  const PixelStyle({
    this.pixelSize = 14,
    this.gapRatio = 0.16,
    this.letterSpacing = 1.2,
    this.lineSpacing = 1.6,
    this.activeColor = PixelPalette.cyan,
    this.gradientEnd,
    this.inactiveColor,
    this.glow = 0.6,
    this.shape = PixelShape.rounded,
    this.animation = PixelAnimation.cascade,
    this.duration = const Duration(milliseconds: 700),
    this.shimmer = false,
    this.repeat = false,
    this.repeatDelay = const Duration(seconds: 2),
  });

  /// Edge length of one pixel block, in logical pixels.
  final double pixelSize;

  /// Space between pixels, as a fraction of [pixelSize].
  final double gapRatio;

  /// Space between characters, in pixel units.
  final double letterSpacing;

  /// Space between lines, in pixel units.
  final double lineSpacing;

  final Color activeColor;

  /// If set, lit pixels blend from [activeColor] to this colour across the text.
  final Color? gradientEnd;

  /// Colour of unlit pixels. Defaults to a faint tint of [activeColor].
  final Color? inactiveColor;

  /// Glow intensity, 0 (off) to 1 (strong).
  final double glow;
  final PixelShape shape;
  final PixelAnimation animation;
  final Duration duration;

  final bool repeat;

  /// How long the fully-lit text is held before it animates out.
  final Duration repeatDelay;

  /// Gentle, continuous brightness shimmer on lit pixels.
  final bool shimmer;

  PixelStyle copyWith({
    double? pixelSize,
    double? gapRatio,
    double? letterSpacing,
    double? lineSpacing,
    Color? activeColor,
    Object? gradientEnd = _unset, // pass null explicitly to clear
    Object? inactiveColor = _unset,
    double? glow,
    PixelShape? shape,
    PixelAnimation? animation,
    Duration? duration,
    bool? shimmer,
    bool? repeat,
    Duration? repeatDelay,
  }) => PixelStyle(
    pixelSize: pixelSize ?? this.pixelSize,
    gapRatio: gapRatio ?? this.gapRatio,
    letterSpacing: letterSpacing ?? this.letterSpacing,
    lineSpacing: lineSpacing ?? this.lineSpacing,
    activeColor: activeColor ?? this.activeColor,
    gradientEnd: identical(gradientEnd, _unset) ? this.gradientEnd : gradientEnd as Color?,
    inactiveColor: identical(inactiveColor, _unset) ? this.inactiveColor : inactiveColor as Color?,
    glow: glow ?? this.glow,
    shape: shape ?? this.shape,
    animation: animation ?? this.animation,
    duration: duration ?? this.duration,
    shimmer: shimmer ?? this.shimmer,
    repeat: repeat ?? this.repeat,
    repeatDelay: repeatDelay ?? this.repeatDelay,
  );

  @override
  bool operator ==(Object other) =>
      other is PixelStyle &&
      other.pixelSize == pixelSize &&
      other.gapRatio == gapRatio &&
      other.letterSpacing == letterSpacing &&
      other.lineSpacing == lineSpacing &&
      other.activeColor == activeColor &&
      other.gradientEnd == gradientEnd &&
      other.inactiveColor == inactiveColor &&
      other.glow == glow &&
      other.shape == shape &&
      other.animation == animation &&
      other.duration == duration &&
      other.repeat == repeat &&
      other.repeatDelay == repeatDelay &&
      other.shimmer == shimmer;
  int get hashCode => Object.hash(
    pixelSize,
    gapRatio,
    letterSpacing,
    lineSpacing,
    activeColor,
    gradientEnd,
    inactiveColor,
    glow,
    shape,
    animation,
    duration,
    shimmer,
    repeat,
    repeatDelay,
  );
}

// ============================================================
// pixel_char
// ============================================================

/// A single animated pixel-matrix character, drawn with one [CustomPainter]
/// (no per-pixel widgets), so even long strings stay smooth.
///
/// When [char] changes, only the pixels that differ animate.
class PixelChar extends StatefulWidget {
  const PixelChar(
    this.char, {
    super.key,
    this.style = const PixelStyle(),
    this.font,
    this.shimmer,
    this.gradientStart = 0,
    this.gradientEnd = 1,
    this.delay = Duration.zero,
    this.seed = 0,
  });

  final String char;
  final PixelStyle style;

  /// Defaults to [PixelFont.classic].
  final PixelFont? font;

  /// Optional shared looping animation driving the shimmer effect.
  final Animation<double>? shimmer;

  /// Position of this glyph along the text gradient (0..1).
  final double gradientStart, gradientEnd;

  /// Wait before the animation starts (used to stagger characters).
  final Duration delay;
  final int seed;

  @override
  State<PixelChar> createState() => _PixelCharState();
}

class _PixelCharState extends State<PixelChar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.style.duration);
  late PixelFont _font;
  late List<int> _from, _to;
  late List<double> _delays;

  int _gen = 0; // bumped on every restart so stale loops stop themselves

  @override
  void initState() {
    super.initState();
    _font = widget.font ?? PixelFont.classic;
    _to = _font.glyphFor(widget.char);
    _from = _font.blank;
    _delays = _makeDelays();
    _start();
  }

  @override
  void didUpdateWidget(PixelChar old) {
    super.didUpdateWidget(old);
    final f = widget.font ?? PixelFont.classic;
    _c.duration = widget.style.duration;
    if (old.char != widget.char || f != _font) {
      _from = (f == _font) ? _to : f.blank;
      _font = f;
      _to = f.glyphFor(widget.char);
      _delays = _makeDelays();
      _start();
    } else {
      if (old.style.animation != widget.style.animation) {
        _delays = _makeDelays();
      }
      if (old.style.repeat != widget.style.repeat || old.style.animation != widget.style.animation) {
        _from = _font.blank;
        _to = _font.glyphFor(widget.char);
        _start();
      }
    }
  }

  void _start() {
    final gen = ++_gen;
    if (widget.style.animation == PixelAnimation.none) {
      _c.value = 1;
      return;
    }
    _c.value = 0;
    _loop(gen);
  }

  /// Intro, then (if [PixelStyle.repeat]) hold → outro → intro → …
  Future<void> _loop(int gen) async {
    bool ok() => mounted && gen == _gen;
    Future<bool> wait(Duration d) async {
      if (d > Duration.zero) await Future.delayed(d);
      return ok();
    }

    if (!await wait(widget.delay)) return;
    await _c.forward(from: 0);

    while (ok() && widget.style.repeat) {
      if (!await wait(widget.style.repeatDelay)) return;

      // Outro: lit glyph → blank.
      setState(() {
        _c.value = 0;
        _from = _font.glyphFor(widget.char);
        _to = _font.blank;
      });
      await _c.forward(from: 0);
      if (!await wait(const Duration(milliseconds: 250))) return;

      // Intro again, keeping the per-character stagger.
      setState(() {
        _c.value = 0;
        _from = _font.blank;
        _to = _font.glyphFor(widget.char);
      });
      if (!await wait(widget.delay)) return;
      await _c.forward(from: 0);
    }
  }

  /// Normalised (0..1) start offset for every pixel, per animation style.
  List<double> _makeDelays() {
    final rows = _font.rows, cols = _font.columns;
    final rnd = math.Random(widget.seed * 977 + widget.char.hashCode);
    final cy = (rows - 1) / 2, cx = (cols - 1) / 2;
    final maxD = math.sqrt(cy * cy + cx * cx);
    return List<double>.generate(rows * cols, (i) {
      final r = i ~/ cols, c = i % cols;
      switch (widget.style.animation) {
        case PixelAnimation.cascade:
          return (r + c) / (rows + cols - 2);
        case PixelAnimation.scan:
          return c / (cols - 1);
        case PixelAnimation.ripple:
          return math.sqrt((r - cy) * (r - cy) + (c - cx) * (c - cx)) / maxD;
        case PixelAnimation.random:
          return rnd.nextDouble();
        case PixelAnimation.none:
          return 0;
      }
    });
  }

  @override
  void dispose() {
    _gen++;
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.style.pixelSize, gap = p * widget.style.gapRatio;
    final size = Size(_font.columns * p + (_font.columns - 1) * gap, _font.rows * p + (_font.rows - 1) * gap);
    return RepaintBoundary(
      child: CustomPaint(
        size: size,
        painter: _PixelPainter(
          t: _c,
          shimmer: widget.shimmer,
          from: _from,
          to: _to,
          delays: _delays,
          font: _font,
          style: widget.style,
          gs: widget.gradientStart,
          ge: widget.gradientEnd,
        ),
      ),
    );
  }
}

class _PixelPainter extends CustomPainter {
  _PixelPainter({
    required this.t,
    required this.shimmer,
    required this.from,
    required this.to,
    required this.delays,
    required this.font,
    required this.style,
    required this.gs,
    required this.ge,
  }) : super(repaint: shimmer == null ? t : Listenable.merge([t, shimmer]));

  final Animation<double> t;
  final Animation<double>? shimmer;
  final List<int> from, to;
  final List<double> delays;
  final PixelFont font;
  final PixelStyle style;
  final double gs, ge;

  static Color _a(Color c, double a) => c.withAlpha((a.clamp(0.0, 1.0) * 255).round());

  void _draw(Canvas canvas, Rect r, Paint p) {
    switch (style.shape) {
      case PixelShape.square:
        canvas.drawRect(r, p);
      case PixelShape.rounded:
        canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * .24)), p);
      case PixelShape.circle:
        canvas.drawOval(r, p);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cols = font.columns, rows = font.rows;
    final p = style.pixelSize, step = p * (1 + style.gapRatio);
    final base = style.activeColor, end = style.gradientEnd;
    final offPaint = Paint()..color = style.inactiveColor ?? _a(base, 0.085);
    final fill = Paint();
    final glowPaint = Paint();
    if (style.glow > 0) {
      glowPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, p * (0.35 + style.glow * 0.5));
    }
    final tt = t.value, sh = shimmer?.value;
    final instant = style.animation == PixelAnimation.none;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(c * step, r * step, p, p);
        _draw(canvas, rect, offPaint); // always-visible grid

        final fromOn = font.isOn(from, r, c), toOn = font.isOn(to, r, c);
        if (!fromOn && !toOn) continue;

        final local = instant ? 1.0 : ((tt - delays[r * cols + c] * 0.55) / 0.45).clamp(0.0, 1.0);
        final e = Curves.easeOutCubic.transform(local);
        final a0 = fromOn ? 1.0 : 0.0, a1 = toOn ? 1.0 : 0.0;
        var inten = a0 + (a1 - a0) * e;
        var scale = 1.0, flash = 0.0;
        if (toOn && !fromOn) {
          scale = 0.2 + 0.8 * Curves.easeOutBack.transform(local);
          flash = math.sin(math.pi * local);
        }
        if (sh != null && toOn && local >= 1) {
          inten *= 0.84 + 0.16 * math.sin(2 * math.pi * (sh + ((r * 7 + c * 13) % 11) / 11));
        }
        if (inten <= 0.01) continue;

        var color = base;
        if (end != null) {
          final g = gs + (cols == 1 ? 0 : c / (cols - 1)) * (ge - gs);
          color = Color.lerp(base, end, g.clamp(0.0, 1.0))!;
        }
        final rr = scale == 1 ? rect : Rect.fromCenter(center: rect.center, width: p * scale, height: p * scale);

        if (style.glow > 0) {
          glowPaint.color = _a(color, inten * style.glow * 0.75 * (1 + flash * 0.6));
          _draw(canvas, rr.inflate(p * 0.12), glowPaint);
        }
        fill.color = _a(color, inten);
        _draw(canvas, rr, fill);
        // Hot core for a premium "lit LED" look.
        fill.color = _a(Color.lerp(color, Colors.white, 0.55 + 0.35 * flash)!, inten * 0.9);
        _draw(canvas, rr.deflate(p * 0.24), fill);
      }
    }
  }

  @override
  bool shouldRepaint(_PixelPainter o) =>
      o.from != from || o.to != to || o.delays != delays || o.font != font || o.style != style || o.gs != gs || o.ge != ge;
}

// ============================================================
// pixel_text
// ============================================================

/// Renders a string as a row (or wrapped rows) of [PixelChar]s.
///
/// ```dart
/// PixelText('HELLO', style: PixelStyle(activeColor: PixelPalette.green));
/// ```
///
/// * `\n` starts a new line.
/// * [autoFit] shrinks pixels so the longest line fits the available width.
/// * Characters keep their state by index, so editing text animates only
///   what changed.
class PixelText extends StatefulWidget {
  const PixelText(
    this.text, {
    super.key,
    this.style = const PixelStyle(),
    this.font,
    this.autoFit = false,
    this.alignment = WrapAlignment.center,
    this.staggerMs = 30,
  });

  final String text;
  final PixelStyle style;
  final PixelFont? font;
  final bool autoFit;
  final WrapAlignment alignment;

  /// Delay between consecutive characters' animations (capped at 500 ms).
  final int staggerMs;

  @override
  State<PixelText> createState() => _PixelTextState();
}

class _PixelTextState extends State<PixelText> with SingleTickerProviderStateMixin {
  AnimationController? _shimmer;

  @override
  void initState() {
    super.initState();
    _syncShimmer();
  }

  @override
  void didUpdateWidget(PixelText old) {
    super.didUpdateWidget(old);
    _syncShimmer();
  }

  void _syncShimmer() {
    if (widget.style.shimmer) {
      _shimmer ??= AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    } else if (_shimmer != null) {
      _shimmer!.dispose();
      _shimmer = null;
    }
  }

  @override
  void dispose() {
    _shimmer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final font = widget.font ?? PixelFont.classic;
    final s = widget.style;
    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final lines = widget.text.split('\n');
          var px = s.pixelSize;
          if (widget.autoFit && box.maxWidth.isFinite) {
            final longest = lines.fold<int>(1, (m, l) => math.max(m, l.runes.length));
            final unit = font.columns + (font.columns - 1) * s.gapRatio;
            final total = longest * unit + (longest - 1) * s.letterSpacing;
            px = math.min(px, box.maxWidth / total);
          }
          final st = s.copyWith(pixelSize: px);
          final animated = s.animation != PixelAnimation.none;

          final rows = <Widget>[];
          for (var li = 0; li < lines.length; li++) {
            final chars = lines[li].runes.map(String.fromCharCode).toList();
            final n = chars.length;
            if (li > 0) rows.add(SizedBox(height: px * s.lineSpacing));
            if (n == 0) {
              rows.add(SizedBox(height: font.rows * px * (1 + s.gapRatio)));
              continue;
            }
            rows.add(
              Wrap(
                alignment: widget.alignment,
                spacing: px * s.letterSpacing,
                runSpacing: px * s.lineSpacing,
                children: [
                  for (var i = 0; i < n; i++)
                    PixelChar(
                      chars[i],
                      key: ValueKey('$li:$i'),
                      style: st,
                      font: font,
                      shimmer: _shimmer,
                      gradientStart: i / n,
                      gradientEnd: (i + 1) / n,
                      seed: i,
                      delay: animated ? Duration(milliseconds: math.min(i * widget.staggerMs, 500)) : Duration.zero,
                    ),
                ],
              ),
            );
          }
          return Column(mainAxisSize: MainAxisSize.min, children: rows);
        },
      ),
    );
  }
}

// ============================================================
// pixel_display
// ============================================================

/// A premium "LED panel" bezel: deep gradient, inner vignette, faint
/// scanlines and an accent-coloured halo. Wrap a [PixelText] in it.
class PixelDisplay extends StatelessWidget {
  const PixelDisplay({
    super.key,
    required this.child,
    this.accent = const Color(0xFF19F3FF),
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
    this.borderRadius = 22,
    this.scanlines = true,
    this.backgroundColor,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool scanlines;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.zero;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        borderRadius: radius,
        color: backgroundColor ?? const Color(0xFF04060B),  border: Border.all(color: const Color(0xFF1B2536)),

      ),
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft accent light bleeding from the top edge.

            Padding(padding: padding, child: child),
            if (scanlines)
              const Positioned.fill(
                child: IgnorePointer(child: CustomPaint(painter: _Scanlines())),
              ),
            // Vignette.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(radius: 1.05, colors: [Colors.transparent, Colors.black.withAlpha(120)], stops: const [0.65, 1]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Scanlines extends CustomPainter {
  const _Scanlines();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x08FFFFFF);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(_Scanlines old) => false;
}
