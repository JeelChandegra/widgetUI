// icon_globe_single.dart
// Single-file version: IconGlobe widget + GlobeController + GlobeStyle + demo.
// Copy this file to lib/main.dart and run it. No extra packages needed.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';


/// Visual look of the globe: how items shrink and fade with depth, plus an
/// optional soft halo behind the sphere.
@immutable
class GlobeStyle {
  const GlobeStyle({
    this.minScale = 0.55,
    this.maxScale = 1.0,
    this.minOpacity = 0.25,
    this.maxOpacity = 1.0,
    this.glowColor,
    this.glowOpacity = 0.0,
  })  : assert(minScale > 0 && maxScale >= minScale),
        assert(minOpacity >= 0 && maxOpacity <= 1 && maxOpacity >= minOpacity),
        assert(glowOpacity >= 0 && glowOpacity <= 1);

  /// Scale of items at the very back of the sphere.
  final double minScale;

  /// Scale of items at the very front of the sphere.
  final double maxScale;

  /// Opacity of items at the very back.
  final double minOpacity;

  /// Opacity of items at the very front.
  final double maxOpacity;

  /// Colour of the soft radial halo drawn behind the globe. Null = no halo.
  final Color? glowColor;

  /// Strength of the halo (0 to 1).
  final double glowOpacity;

  /// Subtle look for dark backgrounds, with a cool blue halo.
  const GlobeStyle.dark()
      : this(
    minScale: 0.5,
    minOpacity: 0.2,
    glowColor: const Color(0xFF6C8CFF),
    glowOpacity: 0.18,
  );

  /// Softer fade for light backgrounds.
  const GlobeStyle.light()
      : this(
    minScale: 0.6,
    minOpacity: 0.3,
    glowColor: const Color(0xFF3B5BDB),
    glowOpacity: 0.10,
  );

  /// Strong depth fade with a vivid teal halo.
  const GlobeStyle.neon()
      : this(
    minScale: 0.45,
    minOpacity: 0.12,
    glowColor: const Color(0xFF00FFC6),
    glowOpacity: 0.28,
  );

  GlobeStyle copyWith({
    double? minScale,
    double? maxScale,
    double? minOpacity,
    double? maxOpacity,
    Color? glowColor,
    double? glowOpacity,
  }) =>
      GlobeStyle(
        minScale: minScale ?? this.minScale,
        maxScale: maxScale ?? this.maxScale,
        minOpacity: minOpacity ?? this.minOpacity,
        maxOpacity: maxOpacity ?? this.maxOpacity,
        glowColor: glowColor ?? this.glowColor,
        glowOpacity: glowOpacity ?? this.glowOpacity,
      );

  @override
  bool operator ==(Object other) =>
      other is GlobeStyle &&
          other.minScale == minScale &&
          other.maxScale == maxScale &&
          other.minOpacity == minOpacity &&
          other.maxOpacity == maxOpacity &&
          other.glowColor == glowColor &&
          other.glowOpacity == glowOpacity;

  @override
  int get hashCode =>
      Object.hash(minScale, maxScale, minOpacity, maxOpacity, glowColor, glowOpacity);
}

/// Internal interface implemented by the globe's state.
abstract interface class GlobeHost {
  void pause();
  void resume();
  void setSpeed(double radiansPerSecond);
  void rotateTo(int index, Duration duration, Curve curve);
  int get frontIndex;
}

/// Controls an `IconGlobe` from outside the widget tree.
///
/// Create it, pass it to the globe. It holds no resources, so there is
/// nothing to dispose.
class GlobeController {
  GlobeHost? _host;

  void attach(GlobeHost host) => _host = host;

  void detach(GlobeHost host) {
    if (identical(_host, host)) _host = null;
  }

  /// Whether a globe is currently using this controller.
  bool get isAttached => _host != null;

  /// Index of the item currently closest to the viewer, or null if detached.
  int? get frontIndex => _host?.frontIndex;

  /// Stops the idle spin (dragging still works).
  void pause() => _host?.pause();

  /// Resumes the idle spin.
  void resume() => _host?.resume();

  /// Overrides the idle rotation speed (radians per second).
  void setSpeed(double radiansPerSecond) => _host?.setSpeed(radiansPerSecond);

  /// Smoothly rotates the globe so item [index] faces the viewer.
  void rotateTo(
      int index, {
        Duration duration = const Duration(milliseconds: 900),
        Curve curve = Curves.easeOutCubic,
      }) =>
      _host?.rotateTo(index, duration, curve);
}

/// How items are spread over the sphere.
enum GlobeDistribution {
  /// Evenly spaced (Fibonacci sphere). Looks best.
  fibonacci,

  /// Random, seeded by [IconGlobe.seed].
  random,
}

/// A draggable, auto-rotating 3D globe of widgets.
///
/// ```dart
/// IconGlobe.icons(
///   icons: [Icons.flutter_dash, Icons.cloud, Icons.code],
///   style: GlobeStyle.dark(),
/// )
/// ```
class IconGlobe extends StatefulWidget {
  /// Globe from a list of widgets (icons, images, SVGs, text...).
  IconGlobe({
    Key? key,
    required List<Widget> items,
    double? radius,
    double itemSize = 44,
    GlobeDistribution distribution = GlobeDistribution.fibonacci,
    double perspective = 0.6,
    bool autoRotate = true,
    double rotationSpeed = 0.45,
    double rotationTilt = 0.35,
    double friction = 2.5,
    bool draggable = true,
    bool pauseOnHover = false,
    double hoverScale = 1.25,
    GlobeStyle style = const GlobeStyle(),
    GlobeController? controller,
    ValueChanged<int>? onItemTap,
    ValueChanged<int>? onFrontItemChanged,
    bool respectReduceMotion = true,
    String? semanticLabel,
    int seed = 7,
  }) : this._(
    itemCount: items.length,
    itemBuilder: (_, i) => items[i],
    radius: radius,
    itemSize: itemSize,
    distribution: distribution,
    perspective: perspective,
    autoRotate: autoRotate,
    rotationSpeed: rotationSpeed,
    rotationTilt: rotationTilt,
    friction: friction,
    draggable: draggable,
    pauseOnHover: pauseOnHover,
    hoverScale: hoverScale,
    style: style,
    controller: controller,
    onItemTap: onItemTap,
    onFrontItemChanged: onFrontItemChanged,
    respectReduceMotion: respectReduceMotion,
    semanticLabel: semanticLabel,
    seed: seed,
    key: key,
  );

  /// Globe built lazily, for large or dynamic lists.
  const IconGlobe.builder({
    Key? key,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    double? radius,
    double itemSize = 44,
    GlobeDistribution distribution = GlobeDistribution.fibonacci,
    double perspective = 0.6,
    bool autoRotate = true,
    double rotationSpeed = 0.45,
    double rotationTilt = 0.35,
    double friction = 2.5,
    bool draggable = true,
    bool pauseOnHover = false,
    double hoverScale = 1.25,
    GlobeStyle style = const GlobeStyle(),
    GlobeController? controller,
    ValueChanged<int>? onItemTap,
    ValueChanged<int>? onFrontItemChanged,
    bool respectReduceMotion = true,
    String? semanticLabel,
    int seed = 7,
  }) : this._(
    itemCount: itemCount,
    itemBuilder: itemBuilder,
    radius: radius,
    itemSize: itemSize,
    distribution: distribution,
    perspective: perspective,
    autoRotate: autoRotate,
    rotationSpeed: rotationSpeed,
    rotationTilt: rotationTilt,
    friction: friction,
    draggable: draggable,
    pauseOnHover: pauseOnHover,
    hoverScale: hoverScale,
    style: style,
    controller: controller,
    onItemTap: onItemTap,
    onFrontItemChanged: onFrontItemChanged,
    respectReduceMotion: respectReduceMotion,
    semanticLabel: semanticLabel,
    seed: seed,
    key: key,
  );

  /// Shortcut: a globe of [IconData] icons.
  IconGlobe.icons({
    Key? key,
    required List<IconData> icons,
    Color? iconColor,
    double? radius,
    double itemSize = 44,
    GlobeDistribution distribution = GlobeDistribution.fibonacci,
    double perspective = 0.6,
    bool autoRotate = true,
    double rotationSpeed = 0.45,
    double rotationTilt = 0.35,
    double friction = 2.5,
    bool draggable = true,
    bool pauseOnHover = false,
    double hoverScale = 1.25,
    GlobeStyle style = const GlobeStyle(),
    GlobeController? controller,
    ValueChanged<int>? onItemTap,
    ValueChanged<int>? onFrontItemChanged,
    bool respectReduceMotion = true,
    String? semanticLabel,
    int seed = 7,
  }) : this._(
    itemCount: icons.length,
    itemBuilder: (context, i) => Icon(
      icons[i],
      size: itemSize * 0.7,
      color: iconColor ?? IconTheme.of(context).color,
    ),
    radius: radius,
    itemSize: itemSize,
    distribution: distribution,
    perspective: perspective,
    autoRotate: autoRotate,
    rotationSpeed: rotationSpeed,
    rotationTilt: rotationTilt,
    friction: friction,
    draggable: draggable,
    pauseOnHover: pauseOnHover,
    hoverScale: hoverScale,
    style: style,
    controller: controller,
    onItemTap: onItemTap,
    onFrontItemChanged: onFrontItemChanged,
    respectReduceMotion: respectReduceMotion,
    semanticLabel: semanticLabel,
    seed: seed,
    key: key,
  );

  /// Shortcut: a globe of images (asset, network, file, memory...).
  ///
  /// ```dart
  /// IconGlobe.images(images: [
  ///   const AssetImage('assets/a.png'),
  ///   const NetworkImage('https://example.com/b.png'),
  /// ])
  /// ```
  IconGlobe.images({
    Key? key,
    required List<ImageProvider> images,
    bool circular = true,
    BoxFit fit = BoxFit.cover,
    double? radius,
    double itemSize = 56,
    GlobeDistribution distribution = GlobeDistribution.fibonacci,
    double perspective = 0.6,
    bool autoRotate = true,
    double rotationSpeed = 0.45,
    double rotationTilt = 0.35,
    double friction = 2.5,
    bool draggable = true,
    bool pauseOnHover = false,
    double hoverScale = 1.25,
    GlobeStyle style = const GlobeStyle(),
    GlobeController? controller,
    ValueChanged<int>? onItemTap,
    ValueChanged<int>? onFrontItemChanged,
    bool respectReduceMotion = true,
    String? semanticLabel,
    int seed = 7,
  }) : this._(
    itemCount: images.length,
    itemBuilder: (context, i) {
      final img = Image(
        image: images[i],
        width: itemSize * 0.9,
        height: itemSize * 0.9,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.broken_image_outlined, size: itemSize * 0.5),
      );
      return circular ? ClipOval(child: img) : ClipRRect(
        borderRadius: BorderRadius.circular(itemSize * 0.18),
        child: img,
      );
    },
    radius: radius,
    itemSize: itemSize,
    distribution: distribution,
    perspective: perspective,
    autoRotate: autoRotate,
    rotationSpeed: rotationSpeed,
    rotationTilt: rotationTilt,
    friction: friction,
    draggable: draggable,
    pauseOnHover: pauseOnHover,
    hoverScale: hoverScale,
    style: style,
    controller: controller,
    onItemTap: onItemTap,
    onFrontItemChanged: onFrontItemChanged,
    respectReduceMotion: respectReduceMotion,
    semanticLabel: semanticLabel,
    seed: seed,
    key: key,
  );

  const IconGlobe._({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.radius,
    required this.itemSize,
    required this.distribution,
    required this.perspective,
    required this.autoRotate,
    required this.rotationSpeed,
    required this.rotationTilt,
    required this.friction,
    required this.draggable,
    required this.pauseOnHover,
    required this.hoverScale,
    required this.style,
    required this.controller,
    required this.onItemTap,
    required this.onFrontItemChanged,
    required this.respectReduceMotion,
    required this.semanticLabel,
    required this.seed,
  })  : assert(itemSize > 0),
        assert(perspective >= 0 && perspective < 1.8),
        assert(friction > 0);

  /// Number of items on the sphere.
  final int itemCount;

  /// Builds the widget for each item.
  final IndexedWidgetBuilder itemBuilder;

  /// Sphere radius in logical pixels. Null = fit the available space.
  final double? radius;

  /// Box size reserved for each item at scale 1.
  final double itemSize;

  /// Layout of items on the sphere.
  final GlobeDistribution distribution;

  /// Strength of the 3D perspective (0 = flat, ~1 = dramatic).
  final double perspective;

  /// Whether the globe spins on its own.
  final bool autoRotate;

  /// Idle spin speed in radians per second.
  final double rotationSpeed;

  /// Tilt of the idle spin axis in radians (0 = pure horizontal spin).
  final double rotationTilt;

  /// How quickly motion settles after a drag. Higher = stops sooner.
  final double friction;

  /// Whether dragging rotates the globe.
  final bool draggable;

  /// Pause the idle spin while a mouse pointer hovers (web / desktop).
  final bool pauseOnHover;

  /// Scale applied to an item while hovered.
  final double hoverScale;

  /// Depth fade, scale range and halo.
  final GlobeStyle style;

  /// Optional controller for pause / resume / rotateTo.
  final GlobeController? controller;

  /// Called with the item index when an item is tapped.
  final ValueChanged<int>? onItemTap;

  /// Called when a different item becomes the front-most one.
  final ValueChanged<int>? onFrontItemChanged;

  /// Disable idle spin when the OS "reduce motion" setting is on.
  final bool respectReduceMotion;

  /// Accessibility label for the whole globe.
  final String? semanticLabel;

  /// Seed for [GlobeDistribution.random].
  final int seed;

  @override
  State<IconGlobe> createState() => _IconGlobeState();
}

class _Spin {
  _Spin(this.ax, this.ay, this.angle, this.duration, this.curve);
  final double ax, ay, angle;
  final double duration;
  final Curve curve;
  double t = 0;
  double prev = 0;
}

class _IconGlobeState extends State<IconGlobe>
    with SingleTickerProviderStateMixin
    implements GlobeHost {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  // Row-major 3x3 rotation matrix.
  final Float64List _r = Float64List.fromList(const [1, 0, 0, 0, 1, 0, 0, 0, 1]);
  int _rotations = 0;

  Float64List _pts = Float64List(0);
  Float64List _xs = Float64List(0);
  Float64List _ys = Float64List(0);
  Float64List _zs = Float64List(0);
  List<int> _order = <int>[];
  int _count = 0;

  // Angular velocity (rad/s) around world axes.
  double _wx = 0, _wy = 0, _wz = 0;

  bool _dragging = false;
  bool _hovering = false;
  bool _paused = false;
  bool _reduceMotion = false;
  double? _speedOverride;
  Duration _last = Duration.zero;
  int _front = -1;
  double _radiusPx = 100;
  final Stopwatch _dragWatch = Stopwatch();
  _Spin? _spin;

  @override
  void initState() {
    super.initState();
    _buildPoints();
    widget.controller?.attach(this);
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateFront();
    });
  }

  @override
  void didUpdateWidget(IconGlobe old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.detach(this);
      widget.controller?.attach(this);
    }
    if (old.itemCount != widget.itemCount ||
        old.distribution != widget.distribution ||
        old.seed != widget.seed) {
      _buildPoints();
      _front = -1;
      _updateFront();
      _frame.value++;
    }
  }

  @override
  void dispose() {
    widget.controller?.detach(this);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- points

  void _buildPoints() {
    final n = widget.itemCount;
    _count = n;
    final pts = Float64List(n * 3);
    if (widget.distribution == GlobeDistribution.fibonacci) {
      final golden = math.pi * (3 - math.sqrt(5));
      for (var i = 0; i < n; i++) {
        final y = 1 - 2 * (i + 0.5) / n;
        final r = math.sqrt(math.max(0.0, 1 - y * y));
        final theta = golden * i;
        pts[i * 3] = math.cos(theta) * r;
        pts[i * 3 + 1] = y;
        pts[i * 3 + 2] = math.sin(theta) * r;
      }
    } else {
      final rnd = math.Random(widget.seed);
      for (var i = 0; i < n; i++) {
        final y = rnd.nextDouble() * 2 - 1;
        final r = math.sqrt(math.max(0.0, 1 - y * y));
        final theta = rnd.nextDouble() * math.pi * 2;
        pts[i * 3] = math.cos(theta) * r;
        pts[i * 3 + 1] = y;
        pts[i * 3 + 2] = math.sin(theta) * r;
      }
    }
    _pts = pts;
    _xs = Float64List(n);
    _ys = Float64List(n);
    _zs = Float64List(n);
    _order = List<int>.generate(n, (i) => i);
  }

  // ------------------------------------------------------------------ math

  /// R = Q * R, where Q is a rotation of [angle] around the unit axis.
  void _rotate(double ax, double ay, double az, double angle) {
    if (angle == 0) return;
    final c = math.cos(angle), s = math.sin(angle), k = 1 - c;
    final q0 = c + ax * ax * k, q1 = ax * ay * k - az * s, q2 = ax * az * k + ay * s;
    final q3 = ay * ax * k + az * s, q4 = c + ay * ay * k, q5 = ay * az * k - ax * s;
    final q6 = az * ax * k - ay * s, q7 = az * ay * k + ax * s, q8 = c + az * az * k;
    final r = _r;
    final r0 = r[0], r1 = r[1], r2 = r[2];
    final r3 = r[3], r4 = r[4], r5 = r[5];
    final r6 = r[6], r7 = r[7], r8 = r[8];
    r[0] = q0 * r0 + q1 * r3 + q2 * r6;
    r[1] = q0 * r1 + q1 * r4 + q2 * r7;
    r[2] = q0 * r2 + q1 * r5 + q2 * r8;
    r[3] = q3 * r0 + q4 * r3 + q5 * r6;
    r[4] = q3 * r1 + q4 * r4 + q5 * r7;
    r[5] = q3 * r2 + q4 * r5 + q5 * r8;
    r[6] = q6 * r0 + q7 * r3 + q8 * r6;
    r[7] = q6 * r1 + q7 * r4 + q8 * r7;
    r[8] = q6 * r2 + q7 * r5 + q8 * r8;
    if (++_rotations % 240 == 0) _orthonormalize();
  }

  /// Removes floating point drift so the matrix stays a pure rotation.
  void _orthonormalize() {
    final r = _r;
    var n = math.sqrt(r[0] * r[0] + r[1] * r[1] + r[2] * r[2]);
    r[0] /= n;
    r[1] /= n;
    r[2] /= n;
    final d = r[0] * r[3] + r[1] * r[4] + r[2] * r[5];
    r[3] -= d * r[0];
    r[4] -= d * r[1];
    r[5] -= d * r[2];
    n = math.sqrt(r[3] * r[3] + r[4] * r[4] + r[5] * r[5]);
    r[3] /= n;
    r[4] /= n;
    r[5] /= n;
    r[6] = r[1] * r[5] - r[2] * r[4];
    r[7] = r[2] * r[3] - r[0] * r[5];
    r[8] = r[0] * r[4] - r[1] * r[3];
  }

  void _project() {
    final r = _r, p = _pts;
    for (var i = 0; i < _count; i++) {
      final px = p[i * 3], py = p[i * 3 + 1], pz = p[i * 3 + 2];
      _xs[i] = r[0] * px + r[1] * py + r[2] * pz;
      _ys[i] = r[3] * px + r[4] * py + r[5] * pz;
      _zs[i] = r[6] * px + r[7] * py + r[8] * pz;
    }
    _order.sort((a, b) => _zs[a].compareTo(_zs[b]));
  }

  void _updateFront() {
    if (_count == 0) return;
    final r = _r, p = _pts;
    var best = 0;
    var bestZ = -2.0;
    for (var i = 0; i < _count; i++) {
      final z = r[6] * p[i * 3] + r[7] * p[i * 3 + 1] + r[8] * p[i * 3 + 2];
      if (z > bestZ) {
        bestZ = z;
        best = i;
      }
    }
    if (best != _front) {
      _front = best;
      widget.onFrontItemChanged?.call(best);
    }
  }

  // ------------------------------------------------------------------ tick

  bool get _autoActive =>
      widget.autoRotate &&
          !_paused &&
          !_reduceMotion &&
          !(widget.pauseOnHover && _hovering);

  void _onTick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    dt = dt.clamp(0.0, 0.05);
    if (dt <= 0) return;

    var moved = false;
    final spin = _spin;
    if (spin != null) {
      spin.t += dt;
      final p = (spin.t / spin.duration).clamp(0.0, 1.0);
      final e = spin.curve.transform(p);
      _rotate(spin.ax, spin.ay, 0, spin.angle * (e - spin.prev));
      spin.prev = e;
      if (p >= 1) _spin = null;
      moved = true;
    } else if (!_dragging) {
      final speed = _speedOverride ?? widget.rotationSpeed;
      final tilt = widget.rotationTilt;
      final auto = _autoActive;
      final tx = auto ? math.sin(tilt) * speed : 0.0;
      final ty = auto ? math.cos(tilt) * speed : 0.0;
      final k = 1 - math.exp(-widget.friction * dt);
      _wx += (tx - _wx) * k;
      _wy += (ty - _wy) * k;
      _wz += (0 - _wz) * k;
      final w = math.sqrt(_wx * _wx + _wy * _wy + _wz * _wz);
      if (w > 1e-4) {
        _rotate(_wx / w, _wy / w, _wz / w, w * dt);
        moved = true;
      }
    }
    if (moved) {
      _updateFront();
      _frame.value++;
    }
  }

  // --------------------------------------------------------------- gesture

  void _onPanStart(DragStartDetails d) {
    _dragging = true;
    _spin = null;
    _dragWatch
      ..reset()
      ..start();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final dist = d.delta.distance;
    if (dist == 0) return;
    final dt = math.max(_dragWatch.elapsedMicroseconds / 1e6, 0.004);
    _dragWatch
      ..reset()
      ..start();
    final angle = dist / _radiusPx;
    final ax = -d.delta.dy / dist;
    final ay = d.delta.dx / dist;
    _rotate(ax, ay, 0, angle);
    final w = (angle / dt).clamp(0.0, 14.0);
    _wx = _wx * 0.5 + ax * w * 0.5;
    _wy = _wy * 0.5 + ay * w * 0.5;
    _wz *= 0.5;
    _updateFront();
    _frame.value++;
  }

  void _onPanEnd(DragEndDetails d) {
    _dragging = false;
    // Held still before release: no fling.
    if (_dragWatch.elapsedMilliseconds > 100) {
      _wx = _wy = _wz = 0;
    }
    _dragWatch.stop();
  }

  // ------------------------------------------------------------ controller

  @override
  void pause() => _paused = true;

  @override
  void resume() => _paused = false;

  @override
  void setSpeed(double radiansPerSecond) => _speedOverride = radiansPerSecond;

  @override
  int get frontIndex => _front;

  @override
  void rotateTo(int index, Duration duration, Curve curve) {
    if (index < 0 || index >= _count) return;
    final r = _r, p = _pts;
    final px = p[index * 3], py = p[index * 3 + 1], pz = p[index * 3 + 2];
    final vx = r[0] * px + r[1] * py + r[2] * pz;
    final vy = r[3] * px + r[4] * py + r[5] * pz;
    final vz = r[6] * px + r[7] * py + r[8] * pz;
    // Axis = v x (0,0,1) = (vy, -vx, 0)
    var ax = vy, ay = -vx;
    final sinA = math.sqrt(ax * ax + ay * ay);
    double angle;
    if (sinA < 1e-6) {
      if (vz > 0) return; // already facing the viewer
      ax = 0;
      ay = 1;
      angle = math.pi;
    } else {
      ax /= sinA;
      ay /= sinA;
      angle = math.atan2(sinA, vz);
    }
    _wx = _wy = _wz = 0;
    _spin = _Spin(ax, ay, angle, math.max(duration.inMicroseconds / 1e6, 0.001), curve);
  }

  // ----------------------------------------------------------------- build

  double _resolveSide(BoxConstraints c) {
    final w = c.hasBoundedWidth ? c.maxWidth : null;
    final h = c.hasBoundedHeight ? c.maxHeight : null;
    if (w != null && h != null) return math.min(w, h);
    if (w != null) return w;
    if (h != null) return h;
    final r = widget.radius;
    if (r != null) return r * 2 + widget.itemSize * widget.style.maxScale;
    return 320;
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = widget.respectReduceMotion &&
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    final style = widget.style;

    Widget globe = LayoutBuilder(builder: (context, c) {
      final side = _resolveSide(c);
      final radius = widget.radius ??
          math.max(8.0, side / 2 - widget.itemSize * style.maxScale * 0.6);
      _radiusPx = radius;
      final glow = style.glowColor;

      final children = List<Widget>.generate(
        widget.itemCount,
            (i) => _GlobeItem(
          size: widget.itemSize,
          hoverScale: widget.hoverScale,
          onTap: widget.onItemTap == null ? null : () => widget.onItemTap!(i),
          child: widget.itemBuilder(context, i),
        ),
      );

      return SizedBox(
        width: side,
        height: side,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (glow != null && style.glowOpacity > 0)
              IgnorePointer(
                child: SizedBox.square(
                  dimension: radius * 2.3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        glow.withAlpha((255 * style.glowOpacity).round()),
                        glow.withAlpha(0),
                      ]),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: RepaintBoundary(
                child: Flow(
                  delegate: _GlobeFlowDelegate(
                    state: this,
                    repaint: _frame,
                    radius: radius,
                    itemSize: widget.itemSize,
                    perspective: widget.perspective,
                    style: style,
                  ),
                  children: children,
                ),
              ),
            ),
          ],
        ),
      );
    });

    if (widget.draggable) {
      globe = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: () => _dragging = false,
        child: globe,
      );
    }

    return Semantics(
      label: widget.semanticLabel,
      container: widget.semanticLabel != null,
      child: MouseRegion(
        onEnter: (_) => _hovering = true,
        onExit: (_) => _hovering = false,
        child: globe,
      ),
    );
  }
}

class _GlobeFlowDelegate extends FlowDelegate {
  _GlobeFlowDelegate({
    required this.state,
    required Listenable repaint,
    required this.radius,
    required this.itemSize,
    required this.perspective,
    required this.style,
  }) : super(repaint: repaint);

  final _IconGlobeState state;
  final double radius;
  final double itemSize;
  final double perspective;
  final GlobeStyle style;

  @override
  Size getSize(BoxConstraints constraints) => constraints.biggest;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tight(Size.square(itemSize));

  @override
  bool shouldRelayout(covariant _GlobeFlowDelegate old) => old.itemSize != itemSize;

  @override
  bool shouldRepaint(covariant _GlobeFlowDelegate old) => true;

  @override
  void paintChildren(FlowPaintingContext context) {
    if (state._count == 0 || context.childCount != state._count) return;
    state._project();
    final cx = context.size.width / 2;
    final cy = context.size.height / 2;
    final half = itemSize / 2;
    final xs = state._xs, ys = state._ys, zs = state._zs;

    for (final i in state._order) {
      final z = zs[i];
      final t = (z + 1) / 2;
      final persp = 1 / (1 - z * perspective * 0.5);
      final s = style.minScale + (style.maxScale - style.minScale) * t;
      final opacity =
          style.minOpacity + (style.maxOpacity - style.minOpacity) * t;
      final px = cx + xs[i] * radius * persp;
      final py = cy + ys[i] * radius * persp;
      context.paintChild(
        i,
        transform: Matrix4(
          s, 0, 0, 0, //
          0, s, 0, 0, //
          0, 0, 1, 0, //
          px - s * half, py - s * half, 0, 1,
        ),
        opacity: opacity,
      );
    }
  }
}

class _GlobeItem extends StatefulWidget {
  const _GlobeItem({
    required this.size,
    required this.hoverScale,
    required this.onTap,
    required this.child,
  });

  final double size;
  final double hoverScale;
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_GlobeItem> createState() => _GlobeItemState();
}

class _GlobeItemState extends State<_GlobeItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _hovered ? widget.hoverScale : 1,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// USE CASE / DEMO
// ======================================================================

/// Your own data model: what each globe item represents.
class GlobeItem {
  const GlobeItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.metadata = const {},
    this.imageUrl,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Map<String, String> metadata;

  /// Optional photo/logo. If set, the globe shows it instead of [icon].
  final String? imageUrl;
}

const items = <GlobeItem>[
  GlobeItem(
    icon: Icons.flutter_dash,
    title: 'Flutter',
    subtitle: 'UI toolkit for every screen',
    metadata: {'Language': 'Dart', 'Type': 'Framework', 'Since': '2017'},
  ),
  GlobeItem(
    icon: Icons.local_fire_department,
    title: 'Firebase',
    subtitle: 'Backend without the servers',
    metadata: {'Type': 'BaaS', 'Auth': 'Yes', 'Database': 'Firestore'},
  ),
  GlobeItem(
    icon: Icons.cloud,
    title: 'Cloud',
    subtitle: 'Scale on demand',
    metadata: {'Type': 'Infra', 'Regions': '30+'},
  ),
  GlobeItem(
    icon: Icons.android,
    title: 'Android',
    subtitle: 'Mobile platform',
    metadata: {'Language': 'Kotlin', 'Type': 'OS'},
  ),
  GlobeItem(
    icon: Icons.code,
    title: 'Dart',
    subtitle: 'Client-optimised language',
    metadata: {'Typing': 'Static', 'Null safety': 'Sound'},
  ),
  GlobeItem(
    icon: Icons.storage,
    title: 'Database',
    subtitle: 'Persist everything',
    metadata: {'Type': 'Storage', 'Query': 'SQL / NoSQL'},
  ),
  GlobeItem(
    icon: Icons.bug_report,
    title: 'Testing',
    subtitle: 'Catch bugs early',
    metadata: {'Kinds': 'Unit, Widget, Integration'},
  ),
  GlobeItem(
    icon: Icons.security,
    title: 'Security',
    subtitle: 'Protect users and data',
    metadata: {'Focus': 'Auth, Encryption'},
  ),
  GlobeItem(
    icon: Icons.web,
    title: 'Web',
    subtitle: 'Ship to the browser',
    metadata: {'Renderer': 'CanvasKit', 'Type': 'Platform'},
  ),
  GlobeItem(
    icon: Icons.terminal,
    title: 'CLI',
    subtitle: 'Automate your workflow',
    metadata: {'Type': 'Tooling'},
  ),
  GlobeItem(
    icon: Icons.rocket_launch,
    title: 'Deploy',
    subtitle: 'From commit to production',
    metadata: {'Type': 'CI/CD'},
  ),
  GlobeItem(
    icon: Icons.palette,
    title: 'Design',
    subtitle: 'Make it feel premium',
    metadata: {'Focus': 'Motion, Colour, Type'},
  ),
  GlobeItem(
    icon: Icons.api,
    title: 'API',
    subtitle: 'Connect services',
    metadata: {'Style': 'REST / GraphQL'},
  ),
  GlobeItem(
    icon: Icons.speed,
    title: 'Performance',
    subtitle: '60 fps and beyond',
    metadata: {'Tool': 'DevTools'},
  ),
  GlobeItem(
    icon: Icons.person,
    title: 'Aarav',
    subtitle: 'Mobile engineer',
    metadata: {'Team': 'App', 'Location': 'Rajkot'},
    imageUrl: 'https://i.pravatar.cc/150?img=12',
  ),
  GlobeItem(
    icon: Icons.person,
    title: 'Meera',
    subtitle: 'Product designer',
    metadata: {'Team': 'Design', 'Location': 'Ahmedabad'},
    imageUrl: 'https://i.pravatar.cc/150?img=47',
  ),
];

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: const DemoPage(),
  );
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final controller = GlobeController();
  int front = 0;
  bool paused = false;

  @override
  Widget build(BuildContext context) {
    final item = items[front];
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Text('Tech Globe',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Drag to spin, tap an icon to bring it forward',
                style: TextStyle(color: Colors.white54)),

            // ---- THE CALL ------------------------------------------------
            Expanded(
              child: Center(
                child: IconGlobe.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) => items[i].imageUrl != null
                      ? ClipOval(
                    child: Image.network(
                      items[i].imageUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                          items[i].icon,
                          color: Colors.white,
                          size: 30),
                    ),
                  )
                      : Icon(items[i].icon, color: Colors.white, size: 30),
                  style: const GlobeStyle.dark(),
                  controller: controller,
                  semanticLabel: 'Rotating globe of technology icons',
                  onFrontItemChanged: (i) => setState(() => front = i),
                  onItemTap: (i) => controller.rotateTo(i),
                ),
              ),
            ),
            // --------------------------------------------------------------

            // Title, subtitle and metadata of the front item.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _InfoCard(key: ValueKey(front), item: item),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    paused ? controller.resume() : controller.pause();
                    setState(() => paused = !paused);
                  },
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                  label: Text(paused ? 'Resume' : 'Pause'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () =>
                      controller.rotateTo(math.Random().nextInt(items.length)),
                  child: const Text('Random'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({super.key, required this.item});
  final GlobeItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF15151A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (item.imageUrl != null)
              CircleAvatar(
                radius: 14,
                backgroundImage: NetworkImage(item.imageUrl!),
              )
            else
              Icon(item.icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(item.title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Text(item.subtitle, style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in item.metadata.entries)
                Chip(
                  label: Text('${e.key}: ${e.value}',
                      style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.white10,
                  side: BorderSide.none,
                ),
            ],
          ),
        ],
      ),
    );
  }
}