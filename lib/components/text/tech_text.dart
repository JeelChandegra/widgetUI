// TechText - Flutter port of the React Bits <TechText /> canvas component.
//
// No external dependencies. Needs Flutter >= 3.27 (uses Color.withValues).
// Give the widget bounded width + height (e.g. SizedBox(height: 480)).
//
// Usage:
//   const SizedBox(
//     width: double.infinity,
//     height: 480,
//     child: TechText(text: 'React Bits'),
//   )

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum TechTextReveal { letter, area, none }

enum TechTextLineStyle { dashed, solid }

class TechText extends StatefulWidget {
  const TechText({
    super.key,
    this.text = 'React Bits',
    this.fontFamily,
    this.fontWeight = FontWeight.w600,
    this.fontSize = 150,
    this.letterSpacing = -0.05, // em factor, same as web version
    this.color = Colors.white,
    this.accentColor = Colors.white,
    this.reach = 200,
    this.softness = 0.7,
    this.dashLength = 4,
    this.dashGap = 2,
    this.strokeWidth = 1.5,
    this.lineStyle = TechTextLineStyle.dashed,
    this.reveal = TechTextReveal.letter,
    this.specks = 15,
    this.selection = true,
    this.labels = true,
    this.draggable = true,
    this.sweep = true,
    this.speed = 1,
  });

  final String text;
  final String? fontFamily;
  final FontWeight fontWeight;
  final double fontSize;
  final double letterSpacing;
  final Color color;
  final Color accentColor;
  final double reach;
  final double softness;
  final double dashLength;
  final double dashGap;
  final double strokeWidth;
  final TechTextLineStyle lineStyle;
  final TechTextReveal reveal;
  final int specks;
  final bool selection;
  final bool labels;
  final bool draggable;
  final bool sweep;
  final double speed;

  @override
  State<TechText> createState() => _TechTextState();
}

const double _kSpring = 320;
const double _kDamping = 22;
const int _kFalloffSteps = 8;

double _approach(double current, double target, double dt, double seconds) =>
    current + (target - current) * (1 - math.exp(-dt / seconds));

double _hyp(double a, double b) => math.sqrt(a * a + b * b);

int _imul(int a, int b) {
  a &= 0xFFFFFFFF;
  b &= 0xFFFFFFFF;
  final lo = (a & 0xFFFF) * b;
  final hi = ((((a >> 16) * b) & 0xFFFF) << 16);
  return (lo + hi) & 0xFFFFFFFF;
}

double _noise(List<int> values) {
  var h = 2166136261;
  for (final v in values) {
    h = _imul(h ^ (v & 0xFFFFFFFF), 16777619);
    h ^= h >> 13;
    h = _imul(h, 0x5bd1e995);
    h ^= h >> 15;
  }
  return (h & 0xFFFFFFFF) / 4294967296;
}

String _signed(int v) => v > 0 ? '+$v' : (v < 0 ? '\u2212${-v}' : '0');

Color _a(Color c, double alpha) => c.withValues(alpha: (c.a * alpha).clamp(0.0, 1.0));

double _clamp01(double v) => v.clamp(0.0, 1.0).toDouble();

class _Glyph {
  _Glyph({
    required this.char,
    required this.index,
    required this.x,
    required this.box,
    required this.layerRect,
    required this.fill,
    required this.stroke,
    required this.clear,
  });

  final String char;
  final int index;
  final double x;
  final Rect box;
  final Rect layerRect;
  final TextPainter fill;
  final TextPainter stroke;
  final TextPainter clear;
  double ox = 0, oy = 0, vx = 0, vy = 0, outline = 0;

  void dispose() {
    fill.dispose();
    stroke.dispose();
    clear.dispose();
  }
}

class _View {
  _View({
    required this.size,
    required this.baseline,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.textTop,
  });
  final double size, baseline, left, right, top, bottom, textTop;
}

class _Frame {
  double x1 = 0, y1 = 0, x2 = 0, y2 = 0, alpha = 0;
  int index = -1;
}

class _TechTextState extends State<TechText> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);

  Duration _lastElapsed = Duration.zero;
  Size _size = Size.zero;
  double _dpr = 1;
  bool _reduced = false;
  String? _defaultFamily;
  MouseCursor _cursor = MouseCursor.defer;

  String _layoutKey = '';
  _View? _view;
  List<_Glyph> _glyphs = [];
  ui.Shader? _dashShader;

  double _presence = 0;
  double _clock = 0;
  double _pulse = 0;
  bool _placed = false;
  int _dragging = -1;
  double _px = 0, _py = 0;
  bool _pInside = false;
  double _grabX = 0, _grabY = 0;
  double _lensX = 0, _lensY = 0;
  final _Frame _frame = _Frame();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _wake();
  }

  @override
  void didUpdateWidget(covariant TechText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _repaint.value++;
    _wake();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    for (final g in _glyphs) {
      g.dispose();
    }
    super.dispose();
  }

  void _wake() {
    if (!mounted) return;
    if (!_ticker.isTicking) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
  }

  // ---------------------------------------------------------------- layout

  // Flutter exposes no glyph ink metrics, so ink box is estimated per char.
  double _ascent(String c, double size) {
    if (RegExp(r'[0-9]').hasMatch(c)) return 0.72 * size;
    final isLetter = c.toLowerCase() != c.toUpperCase();
    if (!isLetter) return 0.72 * size;
    if (c != c.toLowerCase()) return 0.72 * size;
    return 'bdfhklt'.contains(c) ? 0.74 * size : 0.52 * size;
  }

  double _descent(String c, double size) {
    if ('gjpqy'.contains(c)) return 0.22 * size;
    if (c == 'Q' || c == ',' || c == ';') return 0.12 * size;
    return 0;
  }

  _View _ensureLayout(Size size) {
    final s = widget;
    final family = (s.fontFamily == null || s.fontFamily!.isEmpty) ? _defaultFamily : s.fontFamily;
    final key = [
      s.text,
      family,
      s.fontWeight.value,
      s.fontSize,
      s.letterSpacing,
      s.color.toARGB32(),
      s.dashLength,
      s.dashGap,
      s.strokeWidth,
      s.lineStyle.index,
      size.width,
      size.height,
    ].join('|');
    if (key == _layoutKey && _view != null) return _view!;
    _layoutKey = key;

    TextStyle styleFor(double sz, {Paint? fg, bool spacing = true}) => TextStyle(
      fontFamily: family,
      fontWeight: s.fontWeight,
      fontSize: sz,
      letterSpacing: spacing ? s.letterSpacing * sz : 0,
      color: fg == null ? s.color : null,
      foreground: fg,
    );
    TextPainter tp(String t, TextStyle st) => TextPainter(
      text: TextSpan(text: t, style: st),
      textDirection: TextDirection.ltr,
    )..layout();

    final chars = s.text.characters.toList();

    // pass 1: fit to box
    final probe = tp(s.text, styleFor(s.fontSize));
    final inkW = math.max(1.0, probe.width - s.letterSpacing * s.fontSize);
    probe.dispose();
    var asc0 = 0.0, desc0 = 0.0;
    for (final c in chars) {
      asc0 = math.max(asc0, _ascent(c, s.fontSize));
      desc0 = math.max(desc0, _descent(c, s.fontSize));
    }
    final inkH = math.max(1.0, asc0 + desc0);
    final fit = math.min(1.0, math.min(size.width * 0.9 / inkW, size.height * 0.66 / inkH));
    final sz = s.fontSize * fit;

    // pass 2: real layout
    final main = tp(s.text, styleFor(sz));
    final inkW2 = main.width - s.letterSpacing * sz;
    var asc = 0.0, desc = 0.0;
    for (final c in chars) {
      asc = math.max(asc, _ascent(c, sz));
      desc = math.max(desc, _descent(c, sz));
    }
    final inkH2 = asc + desc;
    final left = (size.width - inkW2) / 2;
    final baselineDist = main.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final baseline = (size.height - inkH2) / 2 + asc;
    final textTop = baseline - baselineDist;

    final view = _View(
      size: sz,
      baseline: baseline,
      left: left,
      right: left + inkW2,
      top: baseline - asc,
      bottom: baseline + desc,
      textTop: textTop,
    );

    final previous = _glyphs;
    final next = <_Glyph>[];
    final pad = s.strokeWidth * 2 + 4;
    var utf16 = 0;
    for (var i = 0; i < chars.length; i++) {
      final c = chars[i];
      final start = utf16;
      utf16 += c.length;
      if (c.trim().isEmpty) continue;
      final gx = left + main.getOffsetForCaret(TextPosition(offset: start), Rect.zero).dx;
      final fill = tp(c, styleFor(sz, spacing: false));
      final stroke = tp(
        c,
        styleFor(
          sz,
          spacing: false,
          fg: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s.strokeWidth * 2
            ..strokeJoin = StrokeJoin.round
            ..color = s.color,
        ),
      );
      final clear = tp(
        c,
        styleFor(sz, spacing: false, fg: Paint()..blendMode = BlendMode.clear),
      );
      final gw = fill.width;
      final glyph = _Glyph(
        char: c,
        index: i,
        x: gx,
        box: Rect.fromLTRB(gx, baseline - _ascent(c, sz), gx + gw, baseline + _descent(c, sz)),
        layerRect: Rect.fromLTWH(gx, textTop, gw, fill.height).inflate(pad),
        fill: fill,
        stroke: stroke,
        clear: clear,
      );
      if (next.length < previous.length && previous[next.length].char == c) {
        glyph.ox = previous[next.length].ox;
        glyph.oy = previous[next.length].oy;
      }
      next.add(glyph);
    }
    main.dispose();
    for (final g in previous) {
      g.dispose();
    }
    _glyphs = next;
    _view = view;
    _dragging = -1;
    _frame.index = -1;

    if (s.lineStyle == TechTextLineStyle.dashed) {
      final dash = math.max(1.0, s.dashLength);
      final gap = math.max(1.0, s.dashGap);
      final p = dash + gap;
      // Flutter has no glyph paths -> no true dash-along-outline.
      // Hatch mask (45deg) over the outline gives dashed look instead.
      _dashShader = ui.Gradient.linear(
        Offset.zero,
        Offset(p, 0),
        const [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF), Color(0x00FFFFFF)],
        [0, dash / p, dash / p, 1],
        TileMode.repeated,
        Matrix4.rotationZ(math.pi / 4).storage,
      );
    } else {
      _dashShader = null;
    }
    return view;
  }

  int _glyphAt(double x, double y) {
    final v = _view;
    if (v == null || y < v.top - 24 || y > v.bottom + 24) return -1;
    var best = -1;
    var bestDistance = double.infinity;
    for (var i = 0; i < _glyphs.length; i++) {
      final g = _glyphs[i];
      final x1 = g.box.left + g.ox;
      final x2 = g.box.right + g.ox;
      final d = x < x1 ? x1 - x : (x > x2 ? x - x2 : 0.0);
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return bestDistance < 28 ? best : -1;
  }

  // ------------------------------------------------------------------ tick

  void _onTick(Duration elapsed) {
    final s = widget;
    final dt = ((elapsed - _lastElapsed).inMicroseconds / 1e6).clamp(0.001, 0.05).toDouble();
    _lastElapsed = elapsed;
    if (_size.isEmpty) return; // wait for first paint
    final view = _ensureLayout(_size);

    final sweeping = s.sweep && !_reduced && !_pInside && _dragging < 0;
    if (sweeping) _clock += dt * s.speed;
    _pulse += dt;
    var tx = _px, ty = _py;
    if (sweeping) {
      tx = view.left + (view.right - view.left) * (0.5 - 0.5 * math.cos(_clock * 0.45));
      ty = view.top + (view.bottom - view.top) * (0.45 + 0.1 * math.sin(_clock * 0.8));
    }
    final active = _pInside || sweeping || _dragging >= 0;
    if (active && !_placed) {
      _lensX = tx;
      _lensY = ty;
    }
    if (active) {
      final lag = _pInside ? 0.05 : 0.22;
      _lensX = _approach(_lensX, tx, dt, lag);
      _lensY = _approach(_lensY, ty, dt, lag);
    }
    _placed = active;
    final areaTarget = (s.reveal == TechTextReveal.area && active && _dragging < 0) ? 1.0 : 0.0;
    _presence = _approach(_presence, areaTarget, dt, 0.16);

    var moving = false;
    for (var i = 0; i < _glyphs.length; i++) {
      final g = _glyphs[i];
      if (i == _dragging) {
        g.ox = _approach(g.ox, _px - _grabX, dt, 0.03);
        g.oy = _approach(g.oy, _py - _grabY, dt, 0.03);
        g.vx = 0;
        g.vy = 0;
        moving = true;
        continue;
      }
      if (g.ox.abs() < 0.05 && g.oy.abs() < 0.05 && _hyp(g.vx, g.vy) < 0.5) {
        g.ox = g.oy = g.vx = g.vy = 0;
        continue;
      }
      g.vx += (-_kSpring * g.ox - _kDamping * g.vx) * dt;
      g.vy += (-_kSpring * g.oy - _kDamping * g.vy) * dt;
      g.ox += g.vx * dt;
      g.oy += g.vy * dt;
      moving = true;
    }

    final focus = _dragging >= 0 ? _dragging : (active ? _glyphAt(_lensX, _lensY) : -1);
    if (focus >= 0 && s.selection) {
      final g = _glyphs[focus];
      final bx1 = g.box.left + g.ox - 6;
      final by1 = g.box.top + g.oy - 6;
      final bx2 = g.box.right + g.ox + 6;
      final by2 = g.box.bottom + g.oy + 6;
      if (_frame.index < 0 || _frame.alpha < 0.02) {
        _frame.x1 = bx1;
        _frame.y1 = by1;
        _frame.x2 = bx2;
        _frame.y2 = by2;
      }
      final glide = focus == _dragging ? 0.02 : 0.08;
      _frame.x1 = _approach(_frame.x1, bx1, dt, glide);
      _frame.y1 = _approach(_frame.y1, by1, dt, glide);
      _frame.x2 = _approach(_frame.x2, bx2, dt, glide);
      _frame.y2 = _approach(_frame.y2, by2, dt, glide);
      _frame.index = focus;
    }
    _frame.alpha = _approach(_frame.alpha, (focus >= 0 && s.selection) ? 1 : 0, dt, 0.1);

    for (var i = 0; i < _glyphs.length; i++) {
      final g = _glyphs[i];
      final target = (s.reveal == TechTextReveal.letter && i == focus && i != _dragging) ? 1.0 : 0.0;
      g.outline = _approach(g.outline, target, dt, 0.09);
      if ((g.outline - target).abs() > 0.002) {
        moving = true;
      } else {
        g.outline = target;
      }
    }

    if (s.draggable) {
      final c = _dragging >= 0
          ? SystemMouseCursors.grabbing
          : (focus >= 0 && _pInside ? SystemMouseCursors.grab : MouseCursor.defer);
      if (c != _cursor) setState(() => _cursor = c);
    }

    _repaint.value++;

    final settling = moving ||
        (_presence - areaTarget).abs() > 0.002 ||
        (_frame.alpha > 0.01 && _frame.alpha < 0.99);
    if (!(active || settling)) _ticker.stop();
  }

  // ----------------------------------------------------------------- paint

  void _drawFillGlyph(Canvas canvas, _Glyph g, double opacity) {
    final pos = Offset(g.x + g.ox, _view!.textTop + g.oy);
    if (opacity >= 0.999) {
      g.fill.paint(canvas, pos);
      return;
    }
    canvas.saveLayer(
      g.layerRect.shift(Offset(g.ox, g.oy)),
      Paint()..color = Colors.white.withValues(alpha: _clamp01(opacity)),
    );
    g.fill.paint(canvas, pos);
    canvas.restore();
  }

  void _drawOutline(Canvas canvas, _Glyph g, double dx, double dy, double opacity) {
    if (opacity <= 0.001) return;
    final rect = g.layerRect.shift(Offset(dx, dy));
    final pos = Offset(g.x + dx, _view!.textTop + dy);
    canvas.saveLayer(rect, Paint()..color = Colors.white.withValues(alpha: _clamp01(opacity)));
    g.stroke.paint(canvas, pos);
    g.clear.paint(canvas, pos); // punch fill out -> outside-only outline
    final dash = _dashShader;
    if (dash != null) {
      canvas.drawRect(rect, Paint()
        ..shader = dash
        ..blendMode = BlendMode.dstIn);
    }
    canvas.restore();
  }

  ui.Gradient _falloff(Offset c, double r, double strength, double softness) {
    final inner = _clamp01(1 - softness);
    final colors = <Color>[Color.fromRGBO(0, 0, 0, _clamp01(strength))];
    final stops = <double>[0];
    if (inner > 0.995) {
      colors
        ..add(Color.fromRGBO(0, 0, 0, _clamp01(strength)))
        ..add(const Color(0x00000000));
      stops
        ..add(0.995)
        ..add(1);
    } else {
      for (var i = 0; i <= _kFalloffSteps; i++) {
        final t = i / _kFalloffSteps;
        final eased = t * t * (3 - 2 * t);
        stops.add(inner + (1 - inner) * t);
        colors.add(Color.fromRGBO(0, 0, 0, _clamp01(strength * (1 - eased))));
      }
    }
    return ui.Gradient.radial(c, r, colors, stops);
  }

  void _paint(Canvas canvas, Size size) {
    _size = size;
    final s = widget;
    _ensureLayout(size);

    // ghost outline at home position while letter displaced
    for (final g in _glyphs) {
      final moved = _hyp(g.ox, g.oy);
      if (moved > 1) _drawOutline(canvas, g, 0, 0, math.min(1.0, moved / 24) * 0.55);
    }

    final area = _presence > 0.001;
    final bounds = Offset.zero & size;
    if (area) canvas.saveLayer(bounds, Paint());
    for (final g in _glyphs) {
      if (g.outline < 0.999) _drawFillGlyph(canvas, g, 1 - g.outline);
      if (g.outline > 0.001) _drawOutline(canvas, g, g.ox, g.oy, g.outline);
    }
    if (area) {
      final c = Offset(_lensX, _lensY);
      canvas.drawRect(
        Rect.fromCircle(center: c, radius: s.reach),
        Paint()
          ..shader = _falloff(c, s.reach, _presence, s.softness)
          ..blendMode = BlendMode.dstOut,
      );
      canvas.restore();

      final lensRect = Rect.fromCircle(center: c, radius: s.reach);
      canvas.saveLayer(bounds, Paint()..color = Colors.white.withValues(alpha: _clamp01(_presence)));
      for (final g in _glyphs) {
        if (g.layerRect.shift(Offset(g.ox, g.oy)).overlaps(lensRect)) {
          _drawOutline(canvas, g, g.ox, g.oy, 1);
        }
      }
      canvas.drawRect(
        lensRect,
        Paint()
          ..shader = _falloff(c, s.reach, 1, s.softness)
          ..blendMode = BlendMode.dstIn,
      );
      canvas.restore();
    }

    _paintFrame(canvas, s);
  }

  double _crisp(double v) => ((v * _dpr).round() + 0.5) / _dpr;

  List<double> _perimeterPoint(double distance, double w, double h) {
    final total = 2 * (w + h);
    var d = ((distance % total) + total) % total;
    if (d < w) return [_frame.x1 + d, _frame.y1, 0, -1];
    d -= w;
    if (d < h) return [_frame.x2, _frame.y1 + d, 1, 0];
    d -= h;
    if (d < w) return [_frame.x2 - d, _frame.y2, 0, 1];
    d -= w;
    return [_frame.x1, _frame.y2 - d, -1, 0];
  }

  void _paintSpecks(Canvas canvas, TechText s, double a) {
    final w = _frame.x2 - _frame.x1;
    final h = _frame.y2 - _frame.y1;
    if (w < 2 || h < 2) return;
    final perimeter = 2 * (w + h);
    final seed = _frame.index + 1;
    const grid = 3;
    final strokeP = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fillP = Paint()..style = PaintingStyle.fill;

    for (var k = 0; k < s.specks; k++) {
      final period = 0.5 + _noise([seed, k, 11]) * 1.2;
      final t = _pulse / period + _noise([seed, k, 17]);
      final cycle = t.floor();
      final life = t - cycle;
      if (life > 0.7) continue;
      final pt = _perimeterPoint(_noise([seed, k, cycle]) * perimeter, w, h);
      final px = pt[0], py = pt[1], nx = pt[2], ny = pt[3];
      final pick = _noise([seed, k, cycle, 2]);
      final size = pick < 0.46 ? 2 : pick < 0.7 ? 3 : pick < 0.84 ? 5 : pick < 0.94 ? 8 : 11;
      final large = size >= 8;
      final out = (large ? 9 : 4) + (_noise([seed, k, cycle, 1]) * 5).floor() * grid;
      final x = _frame.x1 + ((px + nx * out - _frame.x1) / grid).round() * grid;
      final y = _frame.y1 + ((py + ny * out - _frame.y1) / grid).round() * grid;
      final tone = _noise([seed, k, cycle, 3]);
      final blink = (life < 0.06 || (life > 0.32 && life < 0.36)) ? 0.35 : 1.0;
      final alpha = a * (large ? 0.3 + 0.4 * tone : 0.3 + 0.6 * tone) * blink;
      final left = (x - size / 2).roundToDouble();
      final top = (y - size / 2).roundToDouble();
      if (tone < 0.26 || (large && tone < 0.78)) {
        strokeP.color = _a(s.accentColor, alpha);
        canvas.drawRect(Rect.fromLTWH(left + 0.5, top + 0.5, size.toDouble(), size.toDouble()), strokeP);
        if (large && tone > 0.5) {
          fillP.color = _a(s.accentColor, alpha);
          canvas.drawRect(Rect.fromLTWH(x.roundToDouble() - 1, y.roundToDouble() - 1, 2, 2), fillP);
        }
      } else {
        fillP.color = _a(s.accentColor, alpha);
        canvas.drawRect(Rect.fromLTWH(left, top, size.toDouble(), size.toDouble()), fillP);
      }
    }

    const tail = [0.95, 0.55, 0.32, 0.16];
    for (var j = 0; j < 2; j++) {
      final head = (_pulse * 0.42 * s.speed + j * 0.5) * perimeter;
      for (var i = 0; i < 4; i++) {
        final pt = _perimeterPoint(head - i * 6, w, h);
        final size = i == 0 ? 3.0 : 2.0;
        fillP.color = _a(s.accentColor, a * tail[i]);
        canvas.drawRect(
          Rect.fromLTWH((pt[0] - size / 2).roundToDouble(), (pt[1] - size / 2).roundToDouble(), size, size),
          fillP,
        );
      }
    }
  }

  void _paintFrame(Canvas canvas, TechText s) {
    if (_frame.index < 0 || _frame.index >= _glyphs.length || _frame.alpha < 0.01) return;
    final glyph = _glyphs[_frame.index];
    final a = _frame.alpha;
    final x1 = _crisp(_frame.x1), y1 = _crisp(_frame.y1);
    final x2 = _crisp(_frame.x2), y2 = _crisp(_frame.y2);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fill = Paint()..style = PaintingStyle.fill;

    final moved = _hyp(glyph.ox, glyph.oy);
    if (moved > 1) {
      final hx = (glyph.box.left + glyph.box.right) / 2;
      final hy = (glyph.box.top + glyph.box.bottom) / 2;
      line.color = _a(s.accentColor, 0.45 * a);
      final p = Offset(hx, hy);
      final q = Offset(hx + glyph.ox, hy + glyph.oy);
      final delta = q - p;
      final len = delta.distance;
      if (len > 0) {
        final dir = delta / len;
        var d = 0.0;
        while (d < len) {
          canvas.drawLine(p + dir * d, p + dir * math.min(d + 3, len), line);
          d += 7;
        }
      }
      fill.color = _a(s.accentColor, 0.7 * a);
      canvas.drawRect(Rect.fromLTWH(hx.roundToDouble() - 2, hy.roundToDouble() - 2, 4, 4), fill);
    }

    line.color = _a(s.accentColor, 0.5 * a);
    canvas.drawRect(Rect.fromLTRB(x1, y1, x2, y2), line);

    fill.color = _a(s.accentColor, 0.95 * a);
    for (final c in [Offset(x1, y1), Offset(x2, y1), Offset(x2, y2), Offset(x1, y2)]) {
      canvas.drawRect(Rect.fromLTWH(c.dx.roundToDouble() - 2, c.dy.roundToDouble() - 2, 5, 5), fill);
    }

    if (s.specks > 0) _paintSpecks(canvas, s, a);

    if (!s.labels) return;
    final label = moved > 1
        ? '${_signed(glyph.ox.round())}, ${_signed((-glyph.oy).round())}'
        : '${glyph.char}  ${(glyph.box.width).round()} \u00d7 ${(glyph.box.height).round()}';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: const ['Menlo', 'Consolas', 'Courier New'],
          fontSize: 10,
          color: _a(s.accentColor, 0.62 * a),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(_frame.x1.roundToDouble(), _frame.y1.roundToDouble() - 7 - tp.height));
    tp.dispose();
  }

  // --------------------------------------------------------------- pointer

  void _locate(PointerEvent e) {
    _px = e.localPosition.dx;
    _py = e.localPosition.dy;
  }

  void _onMove(PointerEvent e) {
    _locate(e);
    _pInside = true;
    _wake();
  }

  void _onEnter(PointerEvent e) => _onMove(e);

  void _onExit(PointerEvent e) {
    if (_dragging >= 0) return;
    _pInside = false;
    _wake();
  }

  void _onDown(PointerDownEvent e) {
    _locate(e);
    _pInside = true;
    if (widget.draggable && (e.kind != PointerDeviceKind.mouse || e.buttons == kPrimaryButton)) {
      final i = _glyphAt(_px, _py);
      if (i >= 0) {
        _dragging = i;
        _grabX = _px - _glyphs[i].ox;
        _grabY = _py - _glyphs[i].oy;
      }
    }
    _wake();
  }

  void _onUp(PointerEvent e) {
    if (_dragging >= 0) {
      _dragging = -1;
      _pInside = e.kind == PointerDeviceKind.mouse && (Offset.zero & _size).contains(e.localPosition);
    } else if (e.kind != PointerDeviceKind.mouse) {
      _pInside = false;
    }
    _wake();
  }

  @override
  Widget build(BuildContext context) {
    _defaultFamily = DefaultTextStyle.of(context).style.fontFamily;
    _dpr = MediaQuery.devicePixelRatioOf(context);
    _reduced = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      image: true,
      label: widget.text,
      child: MouseRegion(
        cursor: _cursor,
        onEnter: _onEnter,
        onExit: _onExit,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerHover: _onMove,
          onPointerMove: _onMove,
          onPointerDown: _onDown,
          onPointerUp: _onUp,
          onPointerCancel: _onUp,
          child: RepaintBoundary(
            child: SizedBox.expand(
              child: CustomPaint(painter: _TechPainter(this)),
            ),
          ),
        ),
      ),
    );
  }
}

class _TechPainter extends CustomPainter {
  _TechPainter(this.state) : super(repaint: state._repaint);
  final _TechTextState state;

  @override
  void paint(Canvas canvas, Size size) => state._paint(canvas, size);

  @override
  bool shouldRepaint(covariant _TechPainter oldDelegate) => false;
}