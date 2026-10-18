import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

enum CarouselPreset { cylinder, wheel, panorama }

enum CarouselIntro { none, fade, rise, spin }

enum CarouselAutoplay { none, drift, step }

/// For [CarouselPreset.wheel] (vertical) `left` = up, `right` = down.
enum CarouselDirection { left, right }

@immutable
class CircularCarouselItem {
  const CircularCarouselItem({
    required this.image,
    this.alt,
    this.title,
    this.subtitle,
  });

  factory CircularCarouselItem.asset(String path,
      {String? alt, String? title, String? subtitle}) =>
      CircularCarouselItem(
          image: AssetImage(path), alt: alt, title: title, subtitle: subtitle);

  factory CircularCarouselItem.network(String url,
      {String? alt, String? title, String? subtitle}) =>
      CircularCarouselItem(
          image: NetworkImage(url), alt: alt, title: title, subtitle: subtitle);

  final ImageProvider image;
  final String? alt;
  final String? title;
  final String? subtitle;
}

/// Optional programmatic control.
class CircularCarouselController {
  _CircularCarouselState? _state;

  void next() => _state?._stepBy(-1);
  void previous() => _state?._stepBy(1);
  void animateToItem(int index) => _state?._focusItem(index);
  int get activeIndex => _state?._activeItem ?? 0;
}

class CircularCarousel extends StatefulWidget {
  CircularCarousel({
    super.key,
    required this.items,
    this.preset = CarouselPreset.cylinder,
    this.intro = CarouselIntro.rise,
    this.cardWidth = 220,
    this.aspectRatio = 1,
    this.speed = 14,
    this.captions = true,
    this.gap = 24,
    this.tilt = 0,
    this.curve,
    this.perspective = 2400,
    this.autoplay = CarouselAutoplay.drift,
    this.interval = 3,
    this.direction = CarouselDirection.left,
    this.momentum = 0.6,
    this.snap = true,
    this.pauseOnHover = true,
    this.focusOnClick = true,
    this.draggable = true,
    this.parallax = 0,
    this.stretch = 0,
    this.fadeColor = Colors.black,
    this.depthFade = 0.5,
    this.innerShade = 0.4,
    this.cornerRadius = 12,
    this.minTiles = 12,
    this.curveSegments = 6,
    this.captionStyle,
    this.controller,
    this.onActiveChanged,
  }) : assert(items.isNotEmpty, 'items must not be empty');

  final List<CircularCarouselItem> items;
  final CarouselPreset preset;
  final CarouselIntro intro;

  /// Card width in logical px.
  final double cardWidth;

  /// width / height.
  final double aspectRatio;

  /// Drift speed, degrees per second.
  final double speed;
  final bool captions;

  /// Space between cards along ring, px. Sets ring radius.
  final double gap;

  /// Ring tilt, degrees (positive = top leans away).
  final double tilt;

  /// 0 flat cards .. 1 cards follow cylinder. null = preset default.
  final double? curve;

  /// Camera distance, px. Bigger = flatter.
  final double perspective;
  final CarouselAutoplay autoplay;

  /// Seconds between steps (autoplay: step).
  final double interval;
  final CarouselDirection direction;

  /// 0..1. Fling inertia. 0 = no fling.
  final double momentum;

  /// Settle on a card after drag / fling.
  final bool snap;
  final bool pauseOnHover;
  final bool focusOnClick;
  final bool draggable;

  /// 0..1. Photo slides inside frame as card moves.
  final double parallax;

  /// 0..1. Front cards grow taller (up to stretch * 20%).
  final double stretch;
  final Color fadeColor;

  /// 0..1. Far cards fade toward [fadeColor].
  final double depthFade;

  /// 0..1. Black overlay on far-side (inner) faces.
  final double innerShade;
  final double cornerRadius;

  /// Ring filled by repeating items until at least this many cards.
  final int minTiles;

  /// Slices per card when curved. Lower = faster.
  final int curveSegments;
  final TextStyle? captionStyle;
  final CircularCarouselController? controller;

  /// Called with item index (not tile index) when front card changes.
  final ValueChanged<int>? onActiveChanged;

  @override
  State<CircularCarousel> createState() => _CircularCarouselState();
}

class _CircularCarouselState extends State<CircularCarousel>
    with SingleTickerProviderStateMixin {
  static const _minVelocity = 8.0; // deg/s
  static const _maxVelocity = 900.0;

  late final Ticker _ticker;
  final FocusNode _focus = FocusNode();
  Duration _last = Duration.zero;

  double _angle = 0; // degrees
  double _velocity = 0; // deg/s
  double? _target; // degrees, spring target
  double _stepTimer = 0;
  double _intro = 0; // 0..1

  bool _dragging = false;
  bool _hover = false;
  bool _reduced = false;
  int _lastActive = -1;
  int _activeItem = 0;

  // ---- derived -----------------------------------------------------------

  Axis get _axis =>
      widget.preset == CarouselPreset.wheel ? Axis.vertical : Axis.horizontal;
  bool get _isH => _axis == Axis.horizontal;

  int get _n {
    final len = widget.items.length;
    return (math.max(widget.minTiles, len) / len).ceil() * len;
  }

  double get _cardH => widget.cardWidth / widget.aspectRatio;
  double get _along => _isH ? widget.cardWidth : _cardH;
  double get _cross => _isH ? _cardH : widget.cardWidth;
  double get _radius => _n * (_along + widget.gap) / (2 * math.pi);
  double get _stepDeg => 360.0 / _n;

  /// Sign of angle change for autoplay.
  double get _dir =>
      (widget.direction == CarouselDirection.left ? -1.0 : 1.0) *
          (_isH ? 1.0 : -1.0);

  double get _curve => (widget.curve ??
      (widget.preset == CarouselPreset.panorama ? 0.5 : 1.0))
      .clamp(0.0, 1.0);

  double get _friction =>
      0.8 + 7.0 * (1 - widget.momentum.clamp(0.0, 1.0));

  bool get _paused => (_hover && widget.pauseOnHover) || _reduced;

  static double _rad(double deg) => deg * math.pi / 180;
  static double _deg(double rad) => rad * 180 / math.pi;
  double _snap(double a) => (a / _stepDeg).roundToDouble() * _stepDeg;

  // ---- lifecycle ---------------------------------------------------------

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) _intro = 1;
  }

  @override
  void didUpdateWidget(covariant CircularCarousel old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---- motion ------------------------------------------------------------

  void _onTick(Duration elapsed) {
    final dt = math.min((elapsed - _last).inMicroseconds / 1e6, 0.05);
    _last = elapsed;
    if (dt <= 0) return;

    var dirty = false;
    if (_intro < 1) {
      _intro = math.min(1.0, _intro + dt / 1.3);
      dirty = true;
    }
    if (!_dragging) {
      final before = _angle;
      _advance(dt);
      if (_angle != before) dirty = true;
    }
    if (dirty && mounted) setState(() {});
  }

  void _advance(double dt) {
    // spring toward target
    if (_target != null) {
      final d = _target! - _angle;
      if (d.abs() < 0.02) {
        _angle = _target!;
        _target = null;
      } else {
        _angle += d * (1 - math.exp(-dt * 7));
      }
      return;
    }
    // fling
    if (_velocity.abs() > _minVelocity) {
      _angle += _velocity * dt;
      _velocity *= math.exp(-dt * _friction);
      if (_velocity.abs() <= _minVelocity) {
        _velocity = 0;
        if (widget.snap) _target = _snap(_angle);
      }
      return;
    }
    _velocity = 0;
    if (_paused) return;

    switch (widget.autoplay) {
      case CarouselAutoplay.drift:
        _angle += _dir * widget.speed * dt;
      case CarouselAutoplay.step:
        _stepTimer += dt;
        if (_stepTimer >= widget.interval) {
          _stepTimer = 0;
          _stepBy(_dir > 0 ? 1 : -1);
        }
      case CarouselAutoplay.none:
        break;
    }
  }

  /// sign -1 = next item (front card moves left/up), +1 = previous.
  void _stepBy(int sign) {
    final base = _target ?? _snap(_angle);
    _target = base + sign * _stepDeg;
    _velocity = 0;
  }

  void _focusTile(int tile) {
    final want = -tile * _stepDeg;
    var diff = (want - _angle) % 360;
    if (diff > 180) diff -= 360;
    _target = _angle + diff;
    _velocity = 0;
  }

  void _focusItem(int item) {
    final len = widget.items.length;
    double? best;
    for (var t = item % len; t < _n; t += len) {
      var diff = (-t * _stepDeg - _angle) % 360;
      if (diff > 180) diff -= 360;
      if (best == null || diff.abs() < best.abs()) best = diff;
    }
    if (best != null) {
      _target = _angle + best;
      _velocity = 0;
    }
  }

  // ---- gestures ----------------------------------------------------------

  void _dragStart(DragStartDetails d) {
    _dragging = true;
    _target = null;
    _velocity = 0;
    setState(() {});
  }

  void _dragUpdate(DragUpdateDetails d) {
    final delta = _isH ? d.delta.dx : -d.delta.dy;
    setState(() => _angle += _deg(delta / _radius));
  }

  void _dragEnd(DragEndDetails d) {
    _dragging = false;
    final px = _isH
        ? d.velocity.pixelsPerSecond.dx
        : -d.velocity.pixelsPerSecond.dy;
    final v = _deg(px / _radius).clamp(-_maxVelocity, _maxVelocity);
    if (widget.momentum > 0 && v.abs() > _minVelocity) {
      _velocity = v;
    } else if (widget.snap) {
      _target = _snap(_angle);
    }
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.arrowDown) {
      _stepBy(-1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowUp) {
      _stepBy(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final n = _n;
    final len = widget.items.length;
    final r = _radius;
    final step = _stepDeg;

    final activeTile = (-_angle / step).round() % n;
    final activeItem = activeTile % len;
    _activeItem = activeItem;
    if (activeItem != _lastActive) {
      _lastActive = activeItem;
      final cb = widget.onActiveChanged;
      if (cb != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) cb(activeItem);
        });
      }
    }

    final e = Curves.easeOutCubic.transform(_intro);
    final spinOffset =
    widget.intro == CarouselIntro.spin ? (1 - e) * -140.0 : 0.0;
    final rise = widget.intro == CarouselIntro.rise;

    final root = (Matrix4.identity()..setEntry(3, 2, -1 / widget.perspective)) *
        Matrix4.translationValues(0, rise ? (1 - e) * _cross * 1.5 : 0, 0) *
        Matrix4.rotationX(_rad(widget.tilt));

    final tiles = List.generate(n, (i) {
      final t = _rad(i * step + _angle + spinOffset);
      return (i: i, t: t, c: math.cos(t), s: math.sin(t));
    })
      ..sort((a, b) => a.c.compareTo(b.c)); // far first, near last

    final slices = <Widget>[];
    for (final tile in tiles) {
      final inner = tile.c < 0;
      final base = root *
          (_isH ? Matrix4.rotationY(tile.t) : Matrix4.rotationX(tile.t)) *
          Matrix4.translationValues(0, 0, r) *
          (inner
              ? (_isH ? Matrix4.rotationY(math.pi) : Matrix4.rotationX(math.pi))
              : Matrix4.identity());
      slices.addAll(_tileSlices(
        tile: tile.i,
        sinT: tile.s,
        cosT: tile.c,
        inner: inner,
        base: base,
        isActive: tile.i == activeTile,
      ));
    }

    Widget view = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: slices,
    );

    final mask = _maskFor(widget.preset);
    if (mask != null) {
      view = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          begin: _isH ? Alignment.centerLeft : Alignment.topCenter,
          end: _isH ? Alignment.centerRight : Alignment.bottomCenter,
          colors: const [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
          stops: [0, mask, 1 - mask, 1],
        ).createShader(rect),
        child: view,
      );
    }
    if (e < 1 && widget.intro != CarouselIntro.none) {
      view = Opacity(opacity: e, child: view);
    }

    final item = widget.items[activeItem];
    final label = item.alt ?? item.title ?? '';

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: widget.draggable
            ? (_dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab)
            : MouseCursor.defer,
        onEnter: (_) => _hover = true,
        onExit: (_) => _hover = false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: widget.draggable && _isH ? _dragStart : null,
          onHorizontalDragUpdate: widget.draggable && _isH ? _dragUpdate : null,
          onHorizontalDragEnd: widget.draggable && _isH ? _dragEnd : null,
          onVerticalDragStart: widget.draggable && !_isH ? _dragStart : null,
          onVerticalDragUpdate: widget.draggable && !_isH ? _dragUpdate : null,
          onVerticalDragEnd: widget.draggable && !_isH ? _dragEnd : null,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned.fill(child: view),
                if (widget.captions) _caption(context, item, activeItem),
                Semantics(
                  liveRegion: true,
                  label: '$label ${activeItem + 1} of $len',
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double? _maskFor(CarouselPreset p) => switch (p) {
    CarouselPreset.wheel => 0.18,
    CarouselPreset.panorama => 0.12,
    CarouselPreset.cylinder => null,
  };

  List<Widget> _tileSlices({
    required int tile,
    required double sinT,
    required double cosT,
    required bool inner,
    required Matrix4 base,
    required bool isActive,
  }) {
    final item = widget.items[tile % widget.items.length];
    final r = _radius;
    final a = _along;
    final segs = _curve < 0.001 ? 1 : math.max(1, widget.curveSegments);
    final sliceA = a / segs;
    final overlap = segs > 1 ? 0.75 : 0.0;
    final crossSize =
        _cross * (1 + widget.stretch.clamp(0.0, 1.0) * 0.2 * (1 + cosT) / 2);

    final overscan = a * widget.parallax.clamp(0.0, 1.0) * 0.6;
    final shift = (overscan / 2) * sinT * (_isH ? -1.0 : 1.0);
    final photoA = a + overscan;

    final depth = (widget.depthFade * (1 - cosT) / 2).clamp(0.0, 1.0);
    final sIn = inner ? -1.0 : 1.0;
    final rotSign = (_isH ? 1.0 : -1.0) * sIn;
    final rr = Radius.circular(widget.cornerRadius);

    final tap = widget.focusOnClick && !isActive ? () => _focusTile(tile) : null;

    // Decode near card size, not full resolution.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final provider = ResizeImage(
      item.image,
      width: (widget.cardWidth * dpr * 2).round(),
    );

    return List.generate(segs, (j) {
      final aj = -a / 2 + (j + 0.5) * sliceA;
      final phi = aj / r;
      final lat = aj + (r * math.sin(phi) - aj) * _curve;
      final dz = sIn * _curve * (r * math.cos(phi) - r);
      final rot = rotSign * _curve * phi;

      final m = base *
          (_isH
              ? Matrix4.translationValues(lat, 0, dz) * Matrix4.rotationY(rot)
              : Matrix4.translationValues(0, lat, dz) * Matrix4.rotationX(rot));

      final first = j == 0, last = j == segs - 1;
      final br = _isH
          ? BorderRadius.horizontal(
          left: first ? rr : Radius.zero, right: last ? rr : Radius.zero)
          : BorderRadius.vertical(
          top: first ? rr : Radius.zero, bottom: last ? rr : Radius.zero);

      final startA = -overscan / 2 + shift - j * sliceA;
      final w = _isH ? sliceA + overlap : crossSize;
      final h = _isH ? crossSize : sliceA + overlap;

      return Transform(
        transform: m,
        alignment: Alignment.center,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tap,
          child: SizedBox(
            width: w,
            height: h,
            child: ClipRRect(
              borderRadius: br,
              clipBehavior: (first || last) ? Clip.antiAlias : Clip.hardEdge,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: _isH ? startA : 0,
                    top: _isH ? 0 : startA,
                    width: _isH ? photoA : crossSize,
                    height: _isH ? crossSize : photoA,
                    child: Image(
                      image: provider,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      excludeFromSemantics: true,
                    ),
                  ),
                  if (depth > 0)
                    Positioned.fill(
                      child: ColoredBox(
                          color: widget.fadeColor.withValues(alpha: depth)),
                    ),
                  if (inner && widget.innerShade > 0)
                    Positioned.fill(
                      child: ColoredBox(
                          color: Colors.black.withValues(
                              alpha: widget.innerShade.clamp(0.0, 1.0))),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _caption(BuildContext context, CircularCarouselItem item, int index) {
    final base = DefaultTextStyle.of(context).style.merge(widget.captionStyle);
    final dim = base.color?.withValues(alpha: 0.6);
    final countStyle = base.copyWith(
      fontSize: 12,
      height: 1,
      fontWeight: FontWeight.w400,
      color: base.color?.withValues(alpha: 0.5),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 22,
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 520),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.5), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey(index),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.title != null)
                      Text(item.title!,
                          textAlign: TextAlign.center,
                          style: base.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.35)),
                    if (item.subtitle != null)
                      Text(item.subtitle!,
                          textAlign: TextAlign.center,
                          style: base.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 1.35,
                              color: dim)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRect(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      transitionBuilder: (child, anim) => SlideTransition(
                        position: Tween(
                            begin: const Offset(0, 1), end: Offset.zero)
                            .animate(CurvedAnimation(
                            parent: anim, curve: Curves.easeOutCubic)),
                        child: child,
                      ),
                      child: Text('${index + 1}',
                          key: ValueKey(index), style: countStyle),
                    ),
                  ),
                  Text(' / ${widget.items.length}', style: countStyle),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}