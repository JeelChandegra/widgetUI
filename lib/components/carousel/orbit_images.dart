// orbit_images.dart
//
// OrbitImages: images that travel endlessly along a shape (circle, ellipse,
// square, rectangle, triangle, star, heart, infinity, wave or any SVG path),
// evenly spread or stacked on the start point, with an optional visible path
// and content in the center.
//
// Flutter port of the React `OrbitImages` component (originally by Dominik
// Koch). Zero dependencies (Flutter SDK only), no Riverpod, no Overlay.
//
// Requirements
// - `responsive: true`: needs a bounded width. The widget is the largest
//   square that fits the available width (and height, when bounded), and the
//   whole design (`baseWidth` units) is scaled to fit it.
// - `responsive: false`: a fixed `width` x `height` box. Shape coordinates are
//   used as logical pixels from the box's top-left, so size the box to match
//   `baseWidth` for the shape to be centered.
// - Items and the path are not clipped, they paint outside the box when the
//   shape is larger than it (as in React). Clip with an ancestor if needed.
//
// Behavior
// - Items move along the path at a constant rate; `easing` shapes each lap.
//   Positions are computed in a Flow delegate driven by an
//   AnimationController: only paint runs per frame, no rebuilds.
// - Items stay upright: the whole orbit is rotated by `rotation`, items are
//   counter-rotated.
// - Stops while `paused`, on reduced motion (MediaQuery.disableAnimations)
//   and while the app is in the background.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Shape followed by the images.
enum OrbitShape {
  circle,
  ellipse,
  square,
  rectangle,
  triangle,
  star,
  heart,
  infinity,
  wave,

  /// SVG path data given in [OrbitImages.customPath].
  custom,
}

/// Travel direction along the path.
enum OrbitDirection { normal, reverse }

/// Images orbiting along a shape. See the file header for requirements.
class OrbitImages extends StatefulWidget {
  const OrbitImages({
    super.key,
    this.images = const [],
    this.altPrefix = 'Orbiting image',
    this.shape = OrbitShape.ellipse,
    this.customPath,
    this.baseWidth = 1400,
    this.radiusX = 700,
    this.radiusY = 170,
    this.radius = 300,
    this.starPoints = 5,
    this.starInnerRatio = 0.5,
    this.rotation = -8,
    this.duration = const Duration(seconds: 40),
    this.itemSize = 64,
    this.direction = OrbitDirection.normal,
    this.fill = true,
    this.width = 100,
    this.height = 100,
    this.showPath = false,
    this.pathColor = const Color.fromRGBO(0, 0, 0, 0.1),
    this.pathWidth = 2,
    this.easing = Curves.linear,
    this.paused = false,
    this.centerContent,
    this.responsive = false,
    this.semanticLabel,
  });

  /// Images to orbit, e.g. `NetworkImage(url)` or `AssetImage(path)`.
  /// Each is drawn in an `itemSize` square, fitted (contain) and centered.
  final List<ImageProvider> images;

  /// Accessibility text of each image is "`altPrefix` N". Only used when
  /// [semanticLabel] is set (otherwise the orbit is hidden from assistive
  /// technology, like React's `aria-hidden`).
  final String altPrefix;

  /// Shape followed by the images.
  final OrbitShape shape;

  /// SVG path data for [OrbitShape.custom], in `baseWidth` units. Supports
  /// M L H V C S Q T A Z (absolute and relative). Falls back to a circle when
  /// null, empty or unparsable.
  final String? customPath;

  /// Size of the square design space all shape coordinates live in.
  final double baseWidth;

  /// Horizontal radius of ellipse, rectangle, infinity and wave.
  final double radiusX;

  /// Vertical radius of ellipse, rectangle, infinity (and wave amplitude).
  final double radiusY;

  /// Radius of circle, square, triangle, star and heart.
  final double radius;

  /// Number of star tips.
  final int starPoints;

  /// Inner radius of the star as a fraction of [radius].
  final double starInnerRatio;

  /// Rotation of the whole orbit in degrees. Images stay upright.
  final double rotation;

  /// Time of one lap.
  final Duration duration;

  /// Edge length of each image's square.
  final double itemSize;

  /// Travel direction.
  final OrbitDirection direction;

  /// Spread images evenly along the path (otherwise they all start together).
  final bool fill;

  /// Box width when not [responsive]. Null fills the available width.
  final double? width;

  /// Box height when not [responsive]. Null uses the width.
  final double? height;

  /// Draw the path.
  final bool showPath;

  /// Color of the path line.
  final Color pathColor;

  /// Width of the path line in logical pixels.
  final double pathWidth;

  /// Easing applied to each lap.
  final Curve easing;

  /// Freeze the motion.
  final bool paused;

  /// Widget shown in the center, above the images.
  final Widget? centerContent;

  /// Scale the `baseWidth` design to the available width.
  final bool responsive;

  /// Exposes the orbit to screen readers with this label. Null hides it.
  final String? semanticLabel;

  @override
  State<OrbitImages> createState() => _OrbitImagesState();
}

class _OrbitImagesState extends State<OrbitImages>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller =
  AnimationController(vsync: this, duration: widget.duration);

  late _PathWalker _walker;
  late Path _path;
  bool _reduce = false;
  bool _appActive = true;

  // ---- lifecycle ----------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _buildPath();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _sync();
  }

  @override
  void didUpdateWidget(covariant OrbitImages old) {
    super.didUpdateWidget(old);
    final w = widget;
    if (old.shape != w.shape ||
        old.customPath != w.customPath ||
        old.baseWidth != w.baseWidth ||
        old.radiusX != w.radiusX ||
        old.radiusY != w.radiusY ||
        old.radius != w.radius ||
        old.starPoints != w.starPoints ||
        old.starInnerRatio != w.starInnerRatio) {
      _buildPath();
    }
    if (old.duration != w.duration) {
      _controller.duration = w.duration;
      if (_controller.isAnimating) _controller.repeat();
    }
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden &&
        state != AppLifecycleState.detached;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  // ---- motion -------------------------------------------------------------

  void _sync() {
    final w = widget;
    final run = !w.paused &&
        !_reduce &&
        _appActive &&
        w.images.isNotEmpty &&
        w.duration > Duration.zero;
    if (run) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  void _buildPath() {
    final w = widget;
    final c = w.baseWidth / 2;
    var path = switch (w.shape) {
      OrbitShape.circle => _circle(c, c, w.radius),
      OrbitShape.ellipse => _ellipse(c, c, w.radiusX, w.radiusY),
      OrbitShape.square => _rectangle(c, c, w.radius * 2, w.radius * 2),
      OrbitShape.rectangle => _rectangle(c, c, w.radiusX * 2, w.radiusY * 2),
      OrbitShape.triangle => _triangle(c, c, w.radius * 2),
      OrbitShape.star => _star(c, c, w.radius, w.radius * w.starInnerRatio, w.starPoints),
      OrbitShape.heart => _heart(c, c, w.radius * 2),
      OrbitShape.infinity => _infinity(c, c, w.radiusX * 2, w.radiusY * 2),
      OrbitShape.wave => _wave(c, c, w.radiusX * 2, w.radiusY, 3),
      OrbitShape.custom => (w.customPath != null && w.customPath!.isNotEmpty)
          ? _parseSvgPath(w.customPath!)
          : _circle(c, c, w.radius),
    };
    var walker = _PathWalker(path);
    if (walker.total <= 0) {
      path = _circle(c, c, w.radius);
      walker = _PathWalker(path);
    }
    _path = path;
    _walker = walker;
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: LayoutBuilder(
        builder: (context, c) {
          final double boxW;
          final double boxH;
          if (w.responsive) {
            // A square that fits the available width and height, so the
            // box size, path and item positions all use the same numbers.
            var side = c.hasBoundedWidth ? c.maxWidth : w.baseWidth;
            if (c.hasBoundedHeight) side = math.min(side, c.maxHeight);
            boxW = boxH = side;
          } else {
            boxW = c.constrainWidth(w.width ?? (c.hasBoundedWidth ? c.maxWidth : w.baseWidth));
            boxH = c.constrainHeight(w.height ?? boxW);
          }

          // The wrapper that is rotated: the whole design when responsive,
          // the box itself otherwise.
          final wrapW = w.responsive ? w.baseWidth : boxW;
          final wrapH = w.responsive ? w.baseWidth : boxH;
          final scale = w.responsive ? boxW / w.baseWidth : 1.0;
          final pivot = Offset(wrapW / 2, wrapH / 2);
          final center = Offset(boxW / 2, boxH / 2);

          final delegate = _OrbitDelegate(
            progress: _controller,
            walker: _walker,
            easing: w.easing,
            sign: w.direction == OrbitDirection.reverse ? -1 : 1,
            fill: w.fill,
            itemPx: w.itemSize * scale,
            rotation: w.rotation,
            scale: scale,
            pivot: pivot,
            center: center,
          );

          final items = <Widget>[
            for (var i = 0; i < w.images.length; i++)
              RepaintBoundary(
                child: Semantics(
                  image: true,
                  label: '${w.altPrefix} ${i + 1}',
                  child: Image(
                    image: w.images[i],
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
          ];

          Widget orbit = Stack(
            clipBehavior: Clip.none,
            children: [
              if (w.showPath)
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _PathPainter(
                          path: _path,
                          color: w.pathColor,
                          // Stroke is in design units, like the SVG in React.
                          strokeWidth: w.pathWidth / (w.responsive ? scale : 1),
                          rotation: w.rotation,
                          scale: scale,
                          pivot: pivot,
                          base: w.baseWidth,
                          wrap: Size(wrapW, wrapH),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: RepaintBoundary(
                  child: Flow(
                    delegate: delegate,
                    clipBehavior: Clip.none,
                    children: items,
                  ),
                ),
              ),
            ],
          );

          orbit = w.semanticLabel == null
              ? ExcludeSemantics(child: orbit)
              : Semantics(container: true, label: w.semanticLabel, child: orbit);

          return SizedBox(
            width: boxW,
            height: boxH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: orbit),
                if (w.centerContent != null)
                  Positioned.fill(child: Center(child: w.centerContent)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Places every image on the path each frame, with no rebuild or relayout.
class _OrbitDelegate extends FlowDelegate {
  _OrbitDelegate({
    required this.progress,
    required this.walker,
    required this.easing,
    required this.sign,
    required this.fill,
    required this.itemPx,
    required this.rotation,
    required this.scale,
    required this.pivot,
    required this.center,
  })  : _cos = math.cos(rotation * math.pi / 180),
        _sin = math.sin(rotation * math.pi / 180),
        super(repaint: progress);

  final Animation<double> progress;
  final _PathWalker walker;
  final Curve easing;
  final int sign;
  final bool fill;
  final double itemPx;
  final double rotation;
  final double scale;
  final Offset pivot;
  final Offset center;
  final double _cos;
  final double _sin;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tight(Size.square(itemPx));

  @override
  bool shouldRelayout(covariant _OrbitDelegate old) => old.itemPx != itemPx;

  @override
  void paintChildren(FlowPaintingContext context) {
    final count = context.childCount;
    if (count == 0) return;
    // Same math as the React version: progress runs 0..100 (or 0..-100).
    final p = sign * 100 * easing.transform(progress.value);
    final half = itemPx / 2;

    for (var i = 0; i < count; i++) {
      final itemOffset = fill ? (i / count) * 100 : 0;
      final percent = (((p + itemOffset) % 100) + 100) % 100;
      final pt = walker.pointAt(percent / 100);

      // Rotate about the wrapper pivot, then scale about the box center.
      final dx = pt.dx - pivot.dx;
      final dy = pt.dy - pivot.dy;
      final rx = dx * _cos - dy * _sin;
      final ry = dx * _sin + dy * _cos;
      final x = center.dx + scale * rx;
      final y = center.dy + scale * ry;

      context.paintChild(i, transform: Matrix4.translationValues(x - half, y - half, 0));
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitDelegate old) =>
      old.progress != progress ||
          old.walker != walker ||
          old.easing != easing ||
          old.sign != sign ||
          old.fill != fill ||
          old.itemPx != itemPx ||
          old.rotation != rotation ||
          old.scale != scale ||
          old.pivot != pivot ||
          old.center != center;
}

/// Draws the path with the same transform chain as the React SVG: fit the
/// design into the wrapper (viewBox "meet"), rotate about the wrapper center,
/// scale about the box center.
class _PathPainter extends CustomPainter {
  _PathPainter({
    required this.path,
    required this.color,
    required this.strokeWidth,
    required this.rotation,
    required this.scale,
    required this.pivot,
    required this.base,
    required this.wrap,
  });

  final Path path;
  final Color color;
  final double strokeWidth;
  final double rotation;
  final double scale;
  final Offset pivot;
  final double base;
  final Size wrap;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = math.min(wrap.width, wrap.height) / base;
    final fitDx = (wrap.width - base * fit) / 2;
    final fitDy = (wrap.height - base * fit) / 2;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.rotate(rotation * math.pi / 180);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.translate(fitDx, fitDy);
    canvas.scale(fit);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = color
        ..strokeWidth = strokeWidth,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PathPainter old) =>
      old.path != path ||
          old.color != color ||
          old.strokeWidth != strokeWidth ||
          old.rotation != rotation ||
          old.scale != scale ||
          old.pivot != pivot ||
          old.base != base ||
          old.wrap != wrap;
}

/// Position along a path by fraction of its total length.
class _PathWalker {
  _PathWalker(Path path) : this._(path.computeMetrics().toList());

  _PathWalker._(this._metrics)
      : total = _metrics.fold<double>(0, (sum, m) => sum + m.length);

  final List<PathMetric> _metrics;
  final double total;

  Offset pointAt(double t) {
    if (total <= 0) return Offset.zero;
    var d = t * total;
    for (final m in _metrics) {
      if (d <= m.length) {
        return m.getTangentForOffset(d)?.position ?? Offset.zero;
      }
      d -= m.length;
    }
    final last = _metrics.last;
    return last.getTangentForOffset(last.length)?.position ?? Offset.zero;
  }
}

// ---- shapes (same geometry and start points as the React version) ---------

Path _ellipse(double cx, double cy, double rx, double ry) {
  final r = Radius.elliptical(rx, ry);
  return Path()
    ..moveTo(cx - rx, cy)
    ..arcToPoint(Offset(cx + rx, cy), radius: r, largeArc: true, clockwise: false)
    ..arcToPoint(Offset(cx - rx, cy), radius: r, largeArc: true, clockwise: false);
}

Path _circle(double cx, double cy, double r) => _ellipse(cx, cy, r, r);

Path _rectangle(double cx, double cy, double w, double h) {
  final hw = w / 2;
  final hh = h / 2;
  return Path()
    ..moveTo(cx - hw, cy - hh)
    ..lineTo(cx + hw, cy - hh)
    ..lineTo(cx + hw, cy + hh)
    ..lineTo(cx - hw, cy + hh)
    ..close();
}

Path _triangle(double cx, double cy, double size) {
  final height = size * math.sqrt(3) / 2;
  final hs = size / 2;
  return Path()
    ..moveTo(cx, cy - height / 1.5)
    ..lineTo(cx + hs, cy + height / 3)
    ..lineTo(cx - hs, cy + height / 3)
    ..close();
}

Path _star(double cx, double cy, double outerR, double innerR, int points) {
  final step = math.pi / points;
  final path = Path();
  for (var i = 0; i < 2 * points; i++) {
    final r = i.isEven ? outerR : innerR;
    final angle = i * step - math.pi / 2;
    final x = cx + r * math.cos(angle);
    final y = cy + r * math.sin(angle);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  return path..close();
}

Path _heart(double cx, double cy, double size) {
  final s = size / 30;
  return Path()
    ..moveTo(cx, cy + 12 * s)
    ..cubicTo(cx - 20 * s, cy - 5 * s, cx - 12 * s, cy - 18 * s, cx, cy - 8 * s)
    ..cubicTo(cx + 12 * s, cy - 18 * s, cx + 20 * s, cy - 5 * s, cx, cy + 12 * s);
}

Path _infinity(double cx, double cy, double w, double h) {
  final hw = w / 2;
  final hh = h / 2;
  return Path()
    ..moveTo(cx, cy)
    ..cubicTo(cx + hw * 0.5, cy - hh, cx + hw, cy - hh, cx + hw, cy)
    ..cubicTo(cx + hw, cy + hh, cx + hw * 0.5, cy + hh, cx, cy)
    ..cubicTo(cx - hw * 0.5, cy + hh, cx - hw, cy + hh, cx - hw, cy)
    ..cubicTo(cx - hw, cy - hh, cx - hw * 0.5, cy - hh, cx, cy);
}

Path _wave(double cx, double cy, double w, double amplitude, int waves) {
  final path = Path();
  final segs = waves * 20;
  final hw = w / 2;
  for (var i = 0; i <= segs; i++) {
    final x = cx - hw + (w * i) / segs;
    final y = cy + math.sin((i / segs) * waves * 2 * math.pi) * amplitude;
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  for (var i = segs; i >= 0; i--) {
    final x = cx - hw + (w * i) / segs;
    final y = cy - math.sin((i / segs) * waves * 2 * math.pi) * amplitude;
    path.lineTo(x, y);
  }
  return path..close();
}

// ---- SVG path data parser (for `customPath`) ------------------------------

final RegExp _numberRe = RegExp(r'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');

/// Parses SVG path data (M L H V C S Q T A Z, absolute and relative).
/// Stops at the first malformed token and returns what was parsed so far.
Path _parseSvgPath(String d) {
  final path = Path();
  final n = d.length;
  var i = 0;
  var x = 0.0, y = 0.0; // current point
  var sx = 0.0, sy = 0.0; // start of the sub-path
  var qx = 0.0, qy = 0.0; // last control point
  var cmd = '';
  var last = '';

  void skip() {
    while (i < n) {
      final c = d.codeUnitAt(i);
      if (c == 32 || c == 44 || c == 9 || c == 10 || c == 13) {
        i++;
      } else {
        break;
      }
    }
  }

  double number() {
    skip();
    final m = _numberRe.matchAsPrefix(d, i);
    if (m == null) throw const FormatException('number expected');
    i = m.end;
    return double.parse(m[0]!);
  }

  bool flag() {
    skip();
    if (i >= n) throw const FormatException('flag expected');
    final c = d[i];
    if (c != '0' && c != '1') throw const FormatException('flag expected');
    i++;
    return c == '1';
  }

  bool isLetter(int c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122);

  try {
    while (true) {
      skip();
      if (i >= n) break;
      if (isLetter(d.codeUnitAt(i))) {
        cmd = d[i];
        i++;
      } else if (cmd.isEmpty || cmd == 'z' || cmd == 'Z') {
        break;
      }

      final rel = cmd.codeUnitAt(0) >= 97;
      final ox = rel ? x : 0.0;
      final oy = rel ? y : 0.0;
      final up = cmd.toUpperCase();

      switch (up) {
        case 'M':
          final nx = number() + ox;
          final ny = number() + oy;
          path.moveTo(nx, ny);
          x = sx = nx;
          y = sy = ny;
          cmd = rel ? 'l' : 'L'; // further pairs are implicit line-tos
          break;
        case 'L':
          final nx = number() + ox;
          final ny = number() + oy;
          path.lineTo(nx, ny);
          x = nx;
          y = ny;
          break;
        case 'H':
          final nx = number() + ox;
          path.lineTo(nx, y);
          x = nx;
          break;
        case 'V':
          final ny = number() + oy;
          path.lineTo(x, ny);
          y = ny;
          break;
        case 'C':
          final x1 = number() + ox, y1 = number() + oy;
          final x2 = number() + ox, y2 = number() + oy;
          final ex = number() + ox, ey = number() + oy;
          path.cubicTo(x1, y1, x2, y2, ex, ey);
          qx = x2;
          qy = y2;
          x = ex;
          y = ey;
          break;
        case 'S':
          final x1 = (last == 'C' || last == 'S') ? 2 * x - qx : x;
          final y1 = (last == 'C' || last == 'S') ? 2 * y - qy : y;
          final x2 = number() + ox, y2 = number() + oy;
          final ex = number() + ox, ey = number() + oy;
          path.cubicTo(x1, y1, x2, y2, ex, ey);
          qx = x2;
          qy = y2;
          x = ex;
          y = ey;
          break;
        case 'Q':
          final x1 = number() + ox, y1 = number() + oy;
          final ex = number() + ox, ey = number() + oy;
          path.quadraticBezierTo(x1, y1, ex, ey);
          qx = x1;
          qy = y1;
          x = ex;
          y = ey;
          break;
        case 'T':
          final x1 = (last == 'Q' || last == 'T') ? 2 * x - qx : x;
          final y1 = (last == 'Q' || last == 'T') ? 2 * y - qy : y;
          final ex = number() + ox, ey = number() + oy;
          path.quadraticBezierTo(x1, y1, ex, ey);
          qx = x1;
          qy = y1;
          x = ex;
          y = ey;
          break;
        case 'A':
          final rx = number().abs();
          final ry = number().abs();
          final rot = number();
          final large = flag();
          final sweep = flag();
          final ex = number() + ox, ey = number() + oy;
          if (rx == 0 || ry == 0) {
            path.lineTo(ex, ey);
          } else {
            path.arcToPoint(
              Offset(ex, ey),
              radius: Radius.elliptical(rx, ry),
              rotation: rot,
              largeArc: large,
              clockwise: sweep,
            );
          }
          x = ex;
          y = ey;
          break;
        case 'Z':
          path.close();
          x = sx;
          y = sy;
          break;
        default:
          throw FormatException('unknown command $cmd');
      }
      last = up;
    }
  } on FormatException {
    // Keep the part that parsed.
  }
  return path;
}