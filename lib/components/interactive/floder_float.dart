// folder_float.dart
//
// A folder that opens on hover/tap and releases floating "note" pills.
// Pills drift, bounce off each other and the invisible walls, and can be
// dragged / thrown. Flutter port of the React `FolderFloat` component.
//
// - Zero dependencies (tiny built-in physics instead of matter-js).
// - Pills render in the nearest [Overlay] (so they can float outside the
//   widget bounds and still receive pointer events). Needs a MaterialApp /
//   WidgetsApp / Navigator above it, like Tooltip or DropdownButton do.
// - Requires Flutter >= 3.10 (OverlayPortal).

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// What opens the folder. Tapping the folder always toggles it, on every
/// platform; [hover] additionally opens it on mouse hover.
enum FolderFloatTrigger { hover, tap }

/// One floating note.
@immutable
class FolderFloatItem<T> {
  const FolderFloatItem({required this.label, required this.value});

  final String label;
  final T value;
}

class FolderFloat<T> extends StatefulWidget {
  const FolderFloat({
    super.key,
    required this.items,
    this.label = 'Design feedback',
    this.sublabel,
    this.trigger = FolderFloatTrigger.hover,
    this.defaultOpen = false,
    this.closeOnSelect = true,
    this.physics = true,
    this.drift = 0.5,
    this.onSelect,
    this.onOpenChange,
    this.folderColor = const Color(0xFF3F3F46),
    this.frontColor = const Color(0xFF52525B),
    this.paperColor = const Color(0xFFF5F5F5),
    this.itemColor = const Color(0xFFF5F5F5),
    this.itemTextColor = const Color(0xFF18181B),
    this.labelColor = const Color(0xFFF5F5F5),
    this.itemTextStyle,
    this.width = 200,
    this.height = 148,
    this.radius = 14,
    this.spread = 180,
    this.lift = 26,
    this.tilt = 8,
    this.flapAngle = 34,
    this.restAngle = 16,
    this.openDuration = const Duration(milliseconds: 520),
    this.stagger = const Duration(milliseconds: 45),
    this.bounce = 0.3,
  });

  /// Convenience for plain string notes. Value == label.
  static FolderFloat<String> fromLabels({
    Key? key,
    required List<String> labels,
    String label = 'Design feedback',
    String? sublabel,
    FolderFloatTrigger trigger = FolderFloatTrigger.hover,
    bool defaultOpen = false,
    bool closeOnSelect = true,
    bool physics = true,
    double drift = 0.5,
    void Function(String value, int index)? onSelect,
    ValueChanged<bool>? onOpenChange,
  }) {
    return FolderFloat<String>(
      key: key,
      items: [for (final l in labels) FolderFloatItem(label: l, value: l)],
      label: label,
      sublabel: sublabel,
      trigger: trigger,
      defaultOpen: defaultOpen,
      closeOnSelect: closeOnSelect,
      physics: physics,
      drift: drift,
      onSelect: onSelect,
      onOpenChange: onOpenChange,
    );
  }

  final List<FolderFloatItem<T>> items;

  /// Text on the folder front.
  final String label;

  /// Small text under [label]. Defaults to "N notes".
  final String? sublabel;

  final FolderFloatTrigger trigger;
  final bool defaultOpen;

  /// Close the folder after a note is picked.
  final bool closeOnSelect;

  /// Enable floating / collision / drag physics once the open animation ends.
  /// Disabled automatically when the OS requests reduced motion.
  final bool physics;

  /// Strength of the idle drift (0 = still).
  final double drift;

  final void Function(T value, int index)? onSelect;
  final ValueChanged<bool>? onOpenChange;

  final Color folderColor;
  final Color frontColor;
  final Color paperColor;
  final Color itemColor;
  final Color itemTextColor;
  final Color labelColor;

  /// Merged over the default 13px / w500 note style.
  final TextStyle? itemTextStyle;

  final double width;
  final double height;
  final double radius;

  /// Half-width of the area notes spread across.
  final double spread;

  /// Gap between folder top and first row of notes.
  final double lift;

  /// Max random tilt of each note, in degrees.
  final double tilt;

  /// Front flap angle when open / closed, in degrees.
  final double flapAngle;
  final double restAngle;

  final Duration openDuration;

  /// Delay between consecutive notes popping out.
  final Duration stagger;

  /// Overshoot of the pop-out spring (0 = none).
  final double bounce;

  @override
  State<FolderFloat<T>> createState() => _FolderFloatState<T>();
}

// ---------------------------------------------------------------------------
// internals
// ---------------------------------------------------------------------------

const double _tab = 14;
const double _pad = 14; // pill horizontal padding
const double _pillH = 34;
const double _gap = 12;
const double _row = 52;
const double _dragMin = 4;
const double _zonePad = 8;
const double _perspective = 1 / 600;
const Cubic _easeOut = Cubic(0.23, 1, 0.32, 1);

double _jitter(int i) {
  final x = math.sin(i * 12.9898 + 4.1414) * 43758.5453;
  return x - x.floorToDouble();
}

class _Slot {
  const _Slot(this.x, this.y, this.rot);
  final double x; // center x, relative to anchor
  final double y; // top y, relative to anchor
  final double rot; // degrees
}

class _Body {
  _Body(this.x, this.y, this.w, this.h, this.phase);
  double x, y; // center
  final double w, h;
  double vx = 0, vy = 0;
  final double phase;
}

class _Drag {
  _Drag(this.i, this.pointer, this.start, this.origin);
  final int i;
  final int pointer;
  final Offset start;
  final Offset origin; // body center at pointer down
  Offset total = Offset.zero;
  bool moved = false;
}

class _FolderFloatState<T> extends State<FolderFloat<T>>
    with TickerProviderStateMixin {
  late final AnimationController _c;
  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();
  final FocusNode _focus = FocusNode(debugLabel: 'FolderFloat');
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  bool _open = false;
  bool _reduce = false;

  // layout cache (rebuilt each build)
  List<Size> _sizes = const [];
  List<_Slot> _slots = const [];
  Rect _zone = Rect.zero;
  String _measureKey = '';
  TextStyle _pillStyle = const TextStyle();

  // physics
  Ticker? _ticker;
  List<_Body> _bodies = [];
  bool _live = false;
  double _last = -1;
  _Drag? _drag;
  List<Offset>? _frozen; // body centers captured when physics stops

  // interaction visuals
  int _popped = -1;
  int _hovered = -1;
  int _pressed = -1;

  Timer? _liveTimer;
  Timer? _popTimer;
  Timer? _hoverTimer;

  int get _n => widget.items.length;
  double get _openMs => widget.openDuration.inMilliseconds.toDouble();
  double get _staggerMs => widget.stagger.inMilliseconds.toDouble();
  double get _totalMs =>
      math.max(1, _openMs + math.max(0, _n - 1) * _staggerMs);
  bool get _physicsOn => widget.physics && !_reduce;

  @override
  void initState() {
    super.initState();
    _open = widget.defaultOpen;
    _c = AnimationController(vsync: this, value: _open ? 1 : 0);
    _syncDurations();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && _open) {
        _scheduleLive();
      } else if (s == AnimationStatus.dismissed && !_open) {
        if (_portal.isShowing) _portal.hide();
      }
    });
    if (_open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_open) return;
        _portal.show();
        _scheduleLive();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce != _reduce) {
      _reduce = reduce;
      if (_reduce) _stopPhysics();
    }
  }

  @override
  void didUpdateWidget(covariant FolderFloat<T> old) {
    super.didUpdateWidget(old);
    _syncDurations();
    final structural = old.items.length != widget.items.length ||
        old.spread != widget.spread ||
        old.lift != widget.lift ||
        old.tilt != widget.tilt;
    if (structural || (old.physics && !widget.physics)) {
      _stopPhysics();
      _frozen = null;
      if (_open && _c.isCompleted) _scheduleLive();
    }
  }

  void _syncDurations() {
    _c.duration = Duration(milliseconds: _totalMs.round());
    _c.reverseDuration = Duration(
      milliseconds:
      (_openMs * 0.6 + math.max(0, _n - 1) * _staggerMs * 0.5).round(),
    );
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _popTimer?.cancel();
    _hoverTimer?.cancel();
    _ticker?.dispose();
    _c.dispose();
    _tick.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---- open / close -------------------------------------------------------

  void _setOpen(bool next) {
    if (next == _open) return;
    _open = next;
    if (next) {
      _frozen = null;
      if (!_portal.isShowing) _portal.show();
      _c.forward();
    } else {
      _liveTimer?.cancel();
      _stopPhysics();
      _c.reverse();
    }
    widget.onOpenChange?.call(next);
    setState(() {});
  }

  void _hoverIn() {
    _hoverTimer?.cancel();
    _setOpen(true);
  }

  void _hoverOut() {
    _hoverTimer?.cancel();
    // Small grace period so moving folder -> pills doesn't flicker closed.
    _hoverTimer = Timer(const Duration(milliseconds: 60), () {
      if (!mounted || _drag != null) return;
      _setOpen(false);
    });
  }

  void _pick(int i) {
    final item = widget.items[i];
    widget.onSelect?.call(item.value, i);
    _popTimer?.cancel();
    setState(() => _popped = i);
    _popTimer = Timer(const Duration(milliseconds: 320), () {
      if (mounted) setState(() => _popped = -1);
    });
    if (widget.closeOnSelect) _setOpen(false);
  }

  // ---- layout -------------------------------------------------------------

  void _measure() {
    final scaler = MediaQuery.textScalerOf(context);
    final key = '${widget.items.map((e) => e.label).join('|')}'
        '#${_pillStyle.hashCode}#${scaler.hashCode}';
    if (key == _measureKey && _sizes.length == _n) return;
    _measureKey = key;
    _sizes = [
      for (final item in widget.items)
        Size(
          (TextPainter(
            text: TextSpan(text: item.label, style: _pillStyle),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: 1,
          )..layout())
              .width
              .ceilToDouble() +
              _pad * 2,
          _pillH,
        ),
    ];
  }

  void _computeLayout() {
    final spread = widget.spread;
    final rows = <List<int>>[];
    final widths = <double>[];
    var cur = <int>[];
    var cw = 0.0;
    for (var i = 0; i < _n; i++) {
      final pw = _sizes[i].width;
      if (cur.isNotEmpty && cw + _gap + pw > spread * 2) {
        rows.add(cur);
        widths.add(cw);
        cur = [];
        cw = 0;
      }
      cur.add(i);
      cw += (cur.length > 1 ? _gap : 0) + pw;
    }
    if (cur.isNotEmpty) {
      rows.add(cur);
      widths.add(cw);
    }

    final slots = List<_Slot>.filled(_n, const _Slot(0, 0, 0));
    for (var ri = 0; ri < rows.length; ri++) {
      var x = -widths[ri] / 2;
      final shift = (ri.isOdd ? 1 : -1) * math.min(16.0, spread * 0.1);
      for (final i in rows[ri]) {
        final pw = _sizes[i].width;
        final j = _jitter(i);
        slots[i] = _Slot(
          x + pw / 2 + shift + (j - 0.5) * 6,
          -widget.lift - ri * _row - j * 6,
          widget.tilt * (j * 2 - 1),
        );
        x += pw + _gap;
      }
    }
    _slots = slots;

    if (_n == 0) {
      _zone = Rect.zero;
      return;
    }
    var left = -spread - _zonePad;
    var right = spread + _zonePad;
    var top = double.infinity;
    var maxH = 0.0;
    for (var i = 0; i < _n; i++) {
      top = math.min(top, slots[i].y);
      left = math.min(left, slots[i].x - _sizes[i].width / 2);
      right = math.max(right, slots[i].x + _sizes[i].width / 2);
      maxH = math.max(maxH, _sizes[i].height);
    }
    _zone = Rect.fromLTRB(left, top - _zonePad, right, -widget.lift + maxH);
  }

  // ---- physics ------------------------------------------------------------

  void _scheduleLive() {
    _liveTimer?.cancel();
    if (!_physicsOn) return;
    _liveTimer = Timer(const Duration(milliseconds: 80), _startPhysics);
  }

  void _startPhysics() {
    if (!mounted || !_open || _live || !_physicsOn || _n == 0) return;
    _bodies = [
      for (var i = 0; i < _n; i++)
        _Body(
          _slots[i].x,
          _slots[i].y + _sizes[i].height / 2,
          _sizes[i].width,
          _sizes[i].height,
          _jitter(i) * math.pi * 2,
        ),
    ];
    _live = true;
    _last = -1;
    _ticker ??= createTicker(_onTick);
    if (!_ticker!.isActive) _ticker!.start();
    setState(() {});
  }

  void _stopPhysics() {
    _liveTimer?.cancel();
    if (_ticker?.isActive ?? false) _ticker!.stop();
    if (_live) {
      _frozen = [for (final b in _bodies) Offset(b.x, b.y)];
    }
    _bodies = [];
    _live = false;
    _drag = null;
    _pressed = -1;
  }

  void _onTick(Duration elapsed) {
    final now = elapsed.inMicroseconds / 1e6;
    final dt = _last < 0 ? 1 / 60 : math.min(0.032, now - _last);
    _last = now;
    _step(dt, now);
    _tick.value++;
  }

  bool _held(int i) => _drag != null && _drag!.moved && _drag!.i == i;

  void _step(double dt, double t) {
    final accel = widget.drift * 50 * math.min(1.0, t / 2);
    final damp = math.pow(0.92, dt * 60).toDouble();

    for (var i = 0; i < _bodies.length; i++) {
      final b = _bodies[i];
      if (_drag != null && _drag!.i == i) continue;
      b.vx += math.sin(t * 0.9 + b.phase) * accel * dt;
      b.vy += math.cos(t * 1.3 + b.phase * 1.7) * accel * dt;
      b.vx *= damp;
      b.vy *= damp;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
    }

    for (var iter = 0; iter < 2; iter++) {
      for (var i = 0; i < _bodies.length; i++) {
        for (var j = i + 1; j < _bodies.length; j++) {
          _collide(i, j);
        }
      }
    }

    final z = _zone;
    for (var i = 0; i < _bodies.length; i++) {
      final b = _bodies[i];
      final minX = z.left + b.w / 2, maxX = z.right - b.w / 2;
      final minY = z.top + b.h / 2, maxY = z.bottom - b.h / 2;
      if (b.x < minX) {
        b.x = minX;
        if (b.vx < 0) b.vx = -b.vx * 0.55;
      } else if (b.x > maxX) {
        b.x = maxX;
        if (b.vx > 0) b.vx = -b.vx * 0.55;
      }
      if (b.y < minY) {
        b.y = minY;
        if (b.vy < 0) b.vy = -b.vy * 0.55;
      } else if (b.y > maxY) {
        b.y = maxY;
        if (b.vy > 0) b.vy = -b.vy * 0.55;
      }
    }
  }

  void _collide(int ai, int bi) {
    final a = _bodies[ai], b = _bodies[bi];
    final dx = b.x - a.x, dy = b.y - a.y;
    final ox = (a.w + b.w) / 2 - dx.abs();
    final oy = (a.h + b.h) / 2 - dy.abs();
    if (ox <= 0 || oy <= 0) return;
    final ia = _held(ai) ? 0.0 : 1.0;
    final ib = _held(bi) ? 0.0 : 1.0;
    final sum = ia + ib;
    if (sum == 0) return;
    const e = 0.55;
    if (ox < oy) {
      final s = dx < 0 ? -1.0 : 1.0;
      a.x -= s * ox * ia / sum;
      b.x += s * ox * ib / sum;
      final vn = (b.vx - a.vx) * s;
      if (vn < 0) {
        final j = -(1 + e) * vn / sum;
        a.vx -= s * j * ia;
        b.vx += s * j * ib;
      }
    } else {
      final s = dy < 0 ? -1.0 : 1.0;
      a.y -= s * oy * ia / sum;
      b.y += s * oy * ib / sum;
      final vn = (b.vy - a.vy) * s;
      if (vn < 0) {
        final j = -(1 + e) * vn / sum;
        a.vy -= s * j * ia;
        b.vy += s * j * ib;
      }
    }
  }

  // ---- pointer ------------------------------------------------------------

  void _down(PointerDownEvent e, int i) {
    if (_drag != null) return;
    final origin = _live && i < _bodies.length
        ? Offset(_bodies[i].x, _bodies[i].y)
        : Offset.zero;
    _drag = _Drag(i, e.pointer, e.position, origin);
    setState(() => _pressed = i);
  }

  void _move(PointerMoveEvent e, int i) {
    final d = _drag;
    if (d == null || d.i != i || d.pointer != e.pointer) return;
    d.total = e.position - d.start;
    if (!d.moved && d.total.distance >= _dragMin) {
      d.moved = true;
      setState(() {});
    }
    if (!d.moved || !_live || i >= _bodies.length) return;
    final b = _bodies[i];
    final z = _zone;
    final nx = (d.origin.dx + d.total.dx)
        .clamp(z.left + b.w / 2, z.right - b.w / 2)
        .toDouble();
    final ny = (d.origin.dy + d.total.dy)
        .clamp(z.top + b.h / 2, z.bottom - b.h / 2)
        .toDouble();
    // velocity so a flick throws the pill on release
    b.vx = (nx - b.x) * 36;
    b.vy = (ny - b.y) * 36;
    b.x = nx;
    b.y = ny;
  }

  void _up(PointerEvent e, int i, {required bool cancel}) {
    final d = _drag;
    if (d == null || d.i != i || d.pointer != e.pointer) return;
    _drag = null;
    setState(() => _pressed = -1);
    if (!cancel && !d.moved) _pick(i);
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    _pillStyle = DefaultTextStyle.of(context).style.merge(
      TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1,
        color: widget.itemTextColor,
        decoration: TextDecoration.none,
      ).merge(widget.itemTextStyle),
    );
    _measure();
    _computeLayout();

    final hover = widget.trigger == FolderFloatTrigger.hover;

    Widget body = CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _buildOverlay,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _focus.requestFocus();
            _setOpen(!_open);
          },
          child: Semantics(
            button: true,
            expanded: _open,
            label: '${widget.label}, ${_sub()}',
            excludeSemantics: true,
            child: _buildFolder(),
          ),
        ),
      ),
    );

    if (hover) {
      body = MouseRegion(
        opaque: false,
        onEnter: (_) => _hoverIn(),
        onExit: (_) => _hoverOut(),
        child: body,
      );
    }

    return Focus(
      focusNode: _focus,
      onKeyEvent: (_, e) {
        if (e is KeyDownEvent &&
            e.logicalKey == LogicalKeyboardKey.escape &&
            _open) {
          _setOpen(false);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: body,
    );
  }

  String _sub() =>
      widget.sublabel ?? '$_n ${_n == 1 ? 'note' : 'notes'}';

  // ---- folder -------------------------------------------------------------

  Widget _buildFolder() {
    final w = widget.width, h = widget.height, r = widget.radius;
    return SizedBox(
      width: w,
      height: h + _tab,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final fp =
          _easeOut.transform((_c.value * _totalMs / _openMs).clamp(0.0, 1.0));
          final angle =
              lerpDouble(widget.restAngle, widget.flapAngle, fp)! * math.pi / 180;
          final paperOpacity = (fp * 2.5).clamp(0.0, 1.0);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // back + tab
              Positioned.fill(
                child: Transform(
                  origin: Offset(w / 2, h + _tab),
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, _perspective)
                    ..rotateX(-8 * math.pi / 180),
                  child: CustomPaint(
                    painter: _BackPainter(widget.folderColor, r, w),
                  ),
                ),
              ),
              // paper
              Positioned(
                top: _tab + h * 0.10,
                left: w * 0.08,
                right: w * 0.08,
                height: h * 0.50,
                child: Opacity(
                  opacity: paperOpacity,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - fp)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.paperColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
              // front flap
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: h * 0.76,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, _perspective)
                    ..rotateX(angle),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(r),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.6],
                        colors: [
                          Color.lerp(widget.frontColor, Colors.white, 0.08)!,
                          widget.frontColor,
                        ],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x47000000),
                          offset: Offset(0, -10),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.label,
                            style: DefaultTextStyle.of(context).style.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1,
                              color: widget.labelColor,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _sub(),
                            style: DefaultTextStyle.of(context).style.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1,
                              color: widget.labelColor
                                  .withValues(alpha: 0.55),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---- floating pills (overlay) -------------------------------------------

  Widget _buildOverlay(BuildContext context) {
    if (_n == 0) return const SizedBox.shrink();
    final box = _zone.inflate(24);

    Widget content = SizedBox(
      width: box.width,
      height: box.height,
      child: AnimatedBuilder(
        animation: Listenable.merge([_c, _tick]),
        builder: (context, _) {
          final fwd = _c.status == AnimationStatus.forward ||
              _c.status == AnimationStatus.completed;
          final spring =
          Cubic(0.34, 1 + widget.bounce * 1.9, 0.64, 1);
          final pills = <Widget>[];
          for (var i = 0; i < _n; i++) {
            final w = _pill(i, box, _c.value, fwd, spring);
            if (w != null) pills.add(w);
          }
          return Stack(clipBehavior: Clip.none, children: pills);
        },
      ),
    );

    if (widget.trigger == FolderFloatTrigger.hover) {
      // keeps the folder open while pointer travels between pills
      content = MouseRegion(
        opaque: false,
        onEnter: (_) => _hoverIn(),
        onExit: (_) => _hoverOut(),
        child: content,
      );
    }

    return CompositedTransformFollower(
      link: _link,
      showWhenUnlinked: false,
      targetAnchor: Alignment.topCenter,
      followerAnchor: Alignment.topLeft,
      offset: Offset(box.left, box.top + _tab),
      child: content,
    );
  }

  Widget? _pill(int i, Rect box, double v, bool fwd, Cubic spring) {
    final slot = _slots[i];
    final size = _sizes[i];
    final dur = _openMs / _totalMs;
    final delay = i * _staggerMs / _totalMs;
    final lin = ((v - delay) / dur).clamp(0.0, 1.0);
    final opacity = (lin / 0.3).clamp(0.0, 1.0);
    if (opacity <= 0) return null;

    final p = (fwd ? spring : _easeOut).transform(lin);

    Offset c;
    if (_live && i < _bodies.length) {
      c = Offset(_bodies[i].x, _bodies[i].y);
    } else {
      final rest = (_frozen != null && i < _frozen!.length)
          ? _frozen![i]
          : Offset(slot.x, slot.y + size.height / 2);
      c = Offset(
        lerpDouble(0, rest.dx, p)!,
        lerpDouble(44 + size.height / 2, rest.dy, p)!,
      );
    }

    final scale = lerpDouble(0.6, 1, p)!;
    final rot = slot.rot * p * math.pi / 180;
    final interact = _popped == i
        ? 1.1
        : _pressed == i
        ? 0.97
        : (_hovered == i ? 1.05 : 1.0);
    final dragging = _drag != null && _drag!.moved && _drag!.i == i;
    final item = widget.items[i];

    return Positioned(
      left: c.dx - box.left - size.width / 2,
      top: c.dy - box.top - size.height / 2,
      width: size.width,
      height: size.height,
      child: IgnorePointer(
        ignoring: !_open,
        child: Opacity(
          opacity: opacity,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationZ(rot)..scale(scale, scale, 1),
            child: MouseRegion(
              cursor: dragging
                  ? SystemMouseCursors.grabbing
                  : (_live ? SystemMouseCursors.grab : SystemMouseCursors.click),
              onEnter: (_) => setState(() => _hovered = i),
              onExit: (_) {
                if (_hovered == i) setState(() => _hovered = -1);
              },
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => _down(e, i),
                onPointerMove: (e) => _move(e, i),
                onPointerUp: (e) => _up(e, i, cancel: false),
                onPointerCancel: (e) => _up(e, i, cancel: true),
                child: Semantics(
                  button: true,
                  label: item.label,
                  onTap: () => _pick(i),
                  excludeSemantics: true,
                  child: AnimatedScale(
                    scale: interact,
                    duration: const Duration(milliseconds: 160),
                    curve: _easeOut,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.itemColor,
                        borderRadius: BorderRadius.circular(size.height / 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x24000000),
                            offset: Offset(0, 4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          softWrap: false,
                          style: _pillStyle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackPainter extends CustomPainter {
  _BackPainter(this.color, this.radius, this.width);

  final Color color;
  final double radius;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(radius);
    final body = RRect.fromLTRBR(0, _tab, size.width, size.height, r);
    final tab = RRect.fromLTRBAndCorners(
      0,
      0,
      size.width * 0.42,
      _tab + radius,
      topLeft: r,
      topRight: r,
    );
    final path = Path.combine(
      PathOperation.union,
      Path()..addRRect(body),
      Path()..addRRect(tab),
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BackPainter old) =>
      old.color != color || old.radius != radius || old.width != width;
}