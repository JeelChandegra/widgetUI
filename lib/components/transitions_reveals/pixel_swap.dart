// pixel_swap.dart
//
// PixelSwap: swaps between two pieces of content through a grid of "pixels".
// Every pixel is a small window onto the incoming content, locked to the same
// origin, that grows (optionally spinning and fading in) with a per-pixel
// delay taken from a pattern (random, center, spiral...). When the last pixel
// lands, the incoming content becomes the visible layer.
//
// Flutter port of the React `PixelSwap` component. Zero dependencies
// (Flutter SDK only), no Riverpod, no Overlay required.
//
// Requirements
// - Needs a bounded width. Height comes from `aspectRatio` (default 16 / 10).
//   Wrap it in Center / SizedBox to size it.
// - Both contents are laid out at the widget's full size (like the React
//   `inset: 0` layers) and must not depend on being in an Overlay.
//
// Behavior
// - `trigger`: hover (mouse hover or keyboard focus; a tap toggles on touch),
//   click (tap, Enter, Space) or manual (drive it with `active`).
// - `active` makes the widget controlled, otherwise it keeps its own state.
//   A change requested mid-transition is applied after the running one ends.
// - The incoming content is captured once as an image at the start of each
//   transition (the React version clones its DOM, which is also a static
//   copy). A single painter then draws every pixel from that image, so the
//   cost does not grow with the content's complexity and nothing rebuilds per
//   frame (the painter is driven by an AnimationController).
// - Grid size is capped at 220 pixels: a smaller `pixelSize` is scaled up.
// - Reduced motion (MediaQuery.disableAnimations): swaps instantly.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Order in which the pixels appear.
enum PixelSwapPattern {
  random,
  center,
  edges,
  leftToRight,
  rightToLeft,
  topToBottom,
  bottomToTop,
  diagonal,
  spiral,
}

/// What toggles the swap.
enum PixelSwapTrigger {
  /// Mouse hover or keyboard focus. On touch screens a tap toggles.
  hover,

  /// Tap, Enter or Space toggles.
  click,

  /// No built-in interaction. Use [PixelSwap.active].
  manual,
}

const int _maxPixels = 220;
const int _steps = 14;

/// Swaps between [firstContent] and [secondContent] through a pixel grid.
class PixelSwap extends StatefulWidget {
  const PixelSwap({
    super.key,
    required this.firstContent,
    required this.secondContent,
    this.pixelSize = 64,
    this.gap = 0,
    this.pixelRadius = 0,
    this.pixelSpin = 0,
    this.pixelScale = 0.35,
    this.fade = true,
    this.duration = const Duration(milliseconds: 1400),
    this.pixelDuration = const Duration(milliseconds: 450),
    this.pattern = PixelSwapPattern.random,
    this.randomness = 0,
    this.easing = const Cubic(0.22, 1, 0.36, 1),
    this.trigger = PixelSwapTrigger.hover,
    this.initialActive = false,
    this.active,
    this.onActiveChange,
    this.onComplete,
    this.aspectRatio = 16 / 10,
    this.borderRadius = BorderRadius.zero,
    this.semanticLabel,
  });

  /// Content shown while inactive.
  final Widget firstContent;

  /// Content shown while active.
  final Widget secondContent;

  /// Pixel edge length in logical pixels (min 8). Scaled up if the grid would
  /// exceed 220 pixels.
  final double pixelSize;

  /// Space between pixels at the start of the animation.
  final double gap;

  /// Corner radius of each pixel in percent of its size (0 - 50).
  final double pixelRadius;

  /// Initial rotation of each pixel in degrees, unwinding to 0.
  final double pixelSpin;

  /// Starting scale of each pixel relative to its final size (0.05 - 1).
  final double pixelScale;

  /// Fade each pixel in while it grows.
  final bool fade;

  /// Total duration of the swap (min 200 ms).
  final Duration duration;

  /// Duration of a single pixel (60 ms up to [duration]).
  final Duration pixelDuration;

  /// Order in which the pixels appear.
  final PixelSwapPattern pattern;

  /// 0 - 1. Blends the pattern order with random order.
  final double randomness;

  /// Easing of each pixel. CSS `ease`, `ease-in`, `ease-out`, `ease-in-out`
  /// and `linear` map to [Curves.ease], [Curves.easeIn], [Curves.easeOut],
  /// [Curves.easeInOut] and [Curves.linear].
  final Curve easing;

  /// What toggles the swap.
  final PixelSwapTrigger trigger;

  /// Initial state when uncontrolled.
  final bool initialActive;

  /// Controlled state. Null keeps the state inside the widget.
  final bool? active;

  /// Fired when the trigger requests a new state, before the animation runs.
  final ValueChanged<bool>? onActiveChange;

  /// Fired when a swap has finished, with the state now shown.
  final ValueChanged<bool>? onComplete;

  /// Width / height of the widget.
  final double aspectRatio;

  /// Clips the widget with rounded corners.
  final BorderRadius borderRadius;

  /// Accessibility label of the whole widget.
  final String? semanticLabel;

  @override
  State<PixelSwap> createState() => _PixelSwapState();
}

enum _Phase { idle, capturing, animating }

class _PixelSwapState extends State<PixelSwap> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addStatusListener(_onStatus);
  final List<GlobalKey> _layerKeys = [
    GlobalKey(debugLabel: 'PixelSwap first'),
    GlobalKey(debugLabel: 'PixelSwap second'),
  ];

  late bool _internalActive = widget.initialActive;
  late bool _shownActive = widget.active ?? widget.initialActive;
  _Phase _phase = _Phase.idle;
  bool _to = false;
  int _token = 0;
  _Run? _run;
  _PixelPainter? _painter;
  ui.Image? _snapshot;
  Size _box = Size.zero;
  bool _reduce = false;
  double _dpr = 1;
  PointerDeviceKind _lastKind = PointerDeviceKind.mouse;

  bool get _desired => widget.active ?? _internalActive;

  // ---- lifecycle ----------------------------------------------------------

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
  }

  @override
  void didUpdateWidget(covariant PixelSwap old) {
    super.didUpdateWidget(old);
    // Fields only: build runs right after this.
    _maybeStart();
  }

  @override
  void dispose() {
    _token++;
    _controller.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  // ---- transition ---------------------------------------------------------

  /// Starts a transition if the desired state differs from the shown one.
  /// Only changes fields, the caller is responsible for rebuilding.
  void _maybeStart() {
    if (_phase != _Phase.idle) return;
    final to = _desired;
    if (to == _shownActive) return;
    final w = widget;
    _to = to;
    final token = ++_token;
    // Config is frozen here so later prop changes never alter a running swap.
    _run = (_reduce || _box.isEmpty)
        ? null
        : _Run.create(
      box: _box,
      pixelSize: w.pixelSize,
      gap: w.gap,
      pixelRadius: w.pixelRadius,
      pixelSpin: w.pixelSpin,
      pixelScale: w.pixelScale,
      fade: w.fade,
      easing: w.easing,
      duration: w.duration,
      pixelDuration: w.pixelDuration,
      pattern: w.pattern,
      randomness: w.randomness,
    );
    // The incoming layer is painted (off screen) for one frame, then captured.
    _phase = _Phase.capturing;
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture(token));
  }

  Future<void> _capture(int token) async {
    if (!mounted || token != _token) return;
    final run = _run;
    if (run == null) {
      _finish(token);
      return;
    }
    final boundary = _layerKeys[_to ? 1 : 0].currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      _finish(token);
      return;
    }
    final ui.Image image;
    try {
      image = await boundary.toImage(pixelRatio: _dpr);
    } catch (_) {
      if (mounted && token == _token) _finish(token);
      return;
    }
    if (!mounted || token != _token) {
      image.dispose();
      return;
    }
    setState(() {
      _snapshot = image;
      _painter = _PixelPainter(run: run, image: image, progress: _controller);
      _phase = _Phase.animating;
    });
    _controller.duration = Duration(milliseconds: run.totalMs.round());
    _controller.forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _phase == _Phase.animating) {
      _finish(_token);
    }
  }

  void _finish(int token) {
    if (!mounted || token != _token) return;
    final to = _to;
    final old = _snapshot;
    setState(() {
      _shownActive = to;
      _phase = _Phase.idle;
      _run = null;
      _painter = null;
      _snapshot = null;
      _maybeStart();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
    widget.onComplete?.call(to);
  }

  // ---- interaction --------------------------------------------------------

  void _requestActive(bool next) {
    if (widget.active == null) {
      setState(() {
        _internalActive = next;
        _maybeStart();
      });
    }
    widget.onActiveChange?.call(next);
  }

  void _toggle() => _requestActive(!_desired);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.space) {
      _toggle();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final trigger = w.trigger;

    return AspectRatio(
      aspectRatio: w.aspectRatio,
      child: LayoutBuilder(
        builder: (context, c) {
          _box = c.biggest;
          final painter = _painter;

          Widget tree = ClipRRect(
            borderRadius: w.borderRadius,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _layer(0, c.biggest),
                _layer(1, c.biggest),
                if (_phase == _Phase.animating && painter != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: CustomPaint(painter: painter),
                      ),
                    ),
                  ),
              ],
            ),
          );

          if (trigger != PixelSwapTrigger.manual) {
            tree = Listener(
              onPointerDown: (e) => _lastKind = e.kind,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (trigger == PixelSwapTrigger.click ||
                      _lastKind == PointerDeviceKind.touch) {
                    _toggle();
                  }
                },
                child: tree,
              ),
            );
            if (trigger == PixelSwapTrigger.hover) {
              tree = MouseRegion(
                onEnter: (_) => _requestActive(true),
                onExit: (_) => _requestActive(false),
                child: tree,
              );
            }
            tree = Focus(
              onFocusChange: trigger == PixelSwapTrigger.hover ? _requestActive : null,
              onKeyEvent: trigger == PixelSwapTrigger.click ? _onKey : null,
              child: tree,
            );
          }

          return Semantics(
            button: trigger == PixelSwapTrigger.click,
            focusable: trigger != PixelSwapTrigger.manual,
            label: w.semanticLabel,
            // Screen-reader alternative to hover: activate toggles the swap.
            onTap: trigger == PixelSwapTrigger.manual ? null : _toggle,
            child: tree,
          );
        },
      ),
    );
  }

  /// One content layer. Both stay mounted (state is kept). The hidden one is
  /// not painted, except for one frame, parked below the clip, while its
  /// snapshot is taken.
  Widget _layer(int index, Size box) {
    final shown = index == (_shownActive ? 1 : 0);
    final incoming = _phase == _Phase.capturing && index == (_to ? 1 : 0);
    final painted = shown || incoming;
    return Positioned(
      key: ValueKey<int>(index),
      left: 0,
      top: shown ? 0 : box.height + 16,
      width: box.width,
      height: box.height,
      child: ExcludeSemantics(
        excluding: !shown,
        child: ExcludeFocus(
          excluding: !shown,
          child: IgnorePointer(
            ignoring: !shown,
            child: Offstage(
              offstage: !painted,
              child: RepaintBoundary(
                key: _layerKeys[index],
                child: index == 0 ? widget.firstContent : widget.secondContent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- grid -----------------------------------------------------------------

double _clamp(double v, double lo, double hi) => math.min(math.max(v, lo), hi);

double _noise(double seed) {
  final v = math.sin(seed * 127.1 + 311.7) * 43758.5453;
  return v - v.floorToDouble();
}

/// Pattern order in 0..1, or null for pure random.
double? _order(PixelSwapPattern p, double x, double y) {
  switch (p) {
    case PixelSwapPattern.random:
      return null;
    case PixelSwapPattern.center:
      return math.sqrt(math.pow(x - 0.5, 2) + math.pow(y - 0.5, 2)) / math.sqrt1_2;
    case PixelSwapPattern.edges:
      return math.min(math.min(x, 1 - x), math.min(y, 1 - y)) * 2;
    case PixelSwapPattern.leftToRight:
      return x;
    case PixelSwapPattern.rightToLeft:
      return 1 - x;
    case PixelSwapPattern.topToBottom:
      return y;
    case PixelSwapPattern.bottomToTop:
      return 1 - y;
    case PixelSwapPattern.diagonal:
      return (x + y) / 2;
    case PixelSwapPattern.spiral:
      final angle = (math.atan2(y - 0.5, x - 0.5) + math.pi) / (math.pi * 2);
      final radius = math.sqrt(math.pow(x - 0.5, 2) + math.pow(y - 0.5, 2)) / math.sqrt1_2;
      return (angle + radius) % 1;
  }
}

/// Pixels grow slightly past their own box so gaps and rounded corners close
/// completely by the end.
double _coverScale(double size, double gap, double radius) {
  final p = _clamp(radius, 0, 50) / 100;
  final corner = math.sqrt1_2 / (math.sqrt2 * (0.5 - p) + p);
  return ((size + gap) / size) * math.max(1, corner);
}

class _PixelGrid {
  _PixelGrid(this.size, this.gap, this.width, this.height, this.cx, this.cy, this.offset);

  final double size;
  final double gap;
  final double width;
  final double height;

  /// Pixel centers, in the widget's coordinate space.
  final Float64List cx;
  final Float64List cy;

  /// Appearance order in 0..1.
  final Float64List offset;

  int get count => cx.length;

  static _PixelGrid build({
    required double width,
    required double height,
    required int pixelSize,
    required int gap,
    required PixelSwapPattern pattern,
    required double randomness,
  }) {
    var size = pixelSize;
    var columns = math.max(1, ((width + gap) / (size + gap)).ceil());
    var rows = math.max(1, ((height + gap) / (size + gap)).ceil());

    if (columns * rows > _maxPixels) {
      size = (size * math.sqrt((columns * rows) / _maxPixels)).ceil();
      columns = math.max(1, ((width + gap) / (size + gap)).ceil());
      rows = math.max(1, ((height + gap) / (size + gap)).ceil());
    }

    // Overhang the box so edge pixels stay square instead of being cut short.
    final stride = size + gap;
    final originX = (width - (columns * stride - gap)) / 2;
    final originY = (height - (rows * stride - gap)) / 2;
    final mix = _clamp(randomness, 0, 1);
    final n = columns * rows;
    final cx = Float64List(n);
    final cy = Float64List(n);
    final offset = Float64List(n);

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final index = row * columns + column;
        final x = columns <= 1 ? 0.5 : column / (columns - 1);
        final y = rows <= 1 ? 0.5 : row / (rows - 1);
        final base = _order(pattern, x, y);
        final random = _noise(index + 1.0);
        cx[index] = originX + column * stride + size / 2;
        cy[index] = originY + row * stride + size / 2;
        offset[index] = base == null ? random : base * (1 - mix) + random * mix;
      }
    }
    return _PixelGrid(size.toDouble(), gap.toDouble(), width, height, cx, cy, offset);
  }
}

/// Everything a running transition needs, frozen when it starts.
class _Run {
  _Run({
    required this.grid,
    required this.endScale,
    required this.startScale,
    required this.spinRad,
    required this.clip,
    required this.eased,
    required this.opacity,
    required this.totalMs,
    required this.pixelMs,
    required this.spread,
  });

  final _PixelGrid grid;
  final double endScale;
  final double startScale;
  final double spinRad;

  /// Pixel shape, centered on the origin.
  final RRect clip;

  /// Easing and opacity sampled at 15 keyframes (like the React version),
  /// linearly interpolated in between.
  final Float64List eased;
  final Float64List opacity;
  final double totalMs;
  final double pixelMs;
  final double spread;

  static _Run create({
    required Size box,
    required double pixelSize,
    required double gap,
    required double pixelRadius,
    required double pixelSpin,
    required double pixelScale,
    required bool fade,
    required Curve easing,
    required Duration duration,
    required Duration pixelDuration,
    required PixelSwapPattern pattern,
    required double randomness,
  }) {
    final grid = _PixelGrid.build(
      width: box.width,
      height: box.height,
      pixelSize: math.max(8, pixelSize.round()),
      gap: math.max(0, gap.round()),
      pattern: pattern,
      randomness: randomness,
    );
    final totalMs = math.max(200, duration.inMilliseconds).toDouble();
    final pixelMs = _clamp(pixelDuration.inMilliseconds.toDouble(), 60, totalMs);
    final endScale = _coverScale(grid.size, grid.gap, pixelRadius);

    final eased = Float64List(_steps + 1);
    final opacity = Float64List(_steps + 1);
    for (var step = 0; step <= _steps; step++) {
      final e = easing.transform(step / _steps);
      eased[step] = e;
      opacity[step] = fade ? math.min(1.0, e * 1.6) : 1.0;
    }

    final radius = grid.size * _clamp(pixelRadius, 0, 50) / 100;
    // Square pixels get a hair of overlap so anti-aliased seams never show.
    final pad = radius <= 0 ? 0.5 : 0.0;
    final side = grid.size + pad * 2;

    return _Run(
      grid: grid,
      endScale: endScale,
      startScale: _clamp(pixelScale, 0.05, 1) * endScale,
      spinRad: pixelSpin * math.pi / 180,
      clip: RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: side, height: side),
        Radius.circular(radius),
      ),
      eased: eased,
      opacity: opacity,
      totalMs: totalMs,
      pixelMs: pixelMs,
      spread: math.max(0.0, totalMs - pixelMs),
    );
  }
}

/// Draws every pixel window from the captured image of the incoming content.
/// Each pixel clips a scaled / rotated shape, then undoes that transform
/// before drawing, so the content itself never moves or scales.
class _PixelPainter extends CustomPainter {
  _PixelPainter({required this.run, required this.image, required this.progress})
      : _src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        _dst = Rect.fromLTWH(0, 0, run.grid.width, run.grid.height),
        super(repaint: progress);

  final _Run run;
  final ui.Image image;
  final Animation<double> progress;
  final Rect _src;
  final Rect _dst;
  final Paint _paint = Paint()..filterQuality = FilterQuality.low;

  @override
  void paint(Canvas canvas, Size size) {
    final g = run.grid;
    final t = progress.value * run.totalMs;
    final eased = run.eased;
    final opacity = run.opacity;

    for (var i = 0; i < g.count; i++) {
      final p = _clamp((t - g.offset[i] * run.spread) / run.pixelMs, 0, 1);
      final f = p * _steps;
      var k = f.floor();
      if (k >= _steps) k = _steps - 1;
      final frac = f - k;
      final e = eased[k] + (eased[k + 1] - eased[k]) * frac;
      final o = opacity[k] + (opacity[k + 1] - opacity[k]) * frac;
      if (o <= 0) continue;

      final scale = run.startScale + (run.endScale - run.startScale) * e;
      final angle = run.spinRad * (1 - e);
      final cx = g.cx[i];
      final cy = g.cy[i];

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);
      canvas.scale(scale);
      canvas.clipRRect(run.clip);
      canvas.scale(1 / scale);
      canvas.rotate(-angle);
      canvas.translate(-cx, -cy);
      _paint.color = Color.fromRGBO(255, 255, 255, o);
      canvas.drawImageRect(image, _src, _dst, _paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PixelPainter old) =>
      old.run != run || old.image != image;
}