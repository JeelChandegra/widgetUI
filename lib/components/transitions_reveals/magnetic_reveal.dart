import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A floating text pill shown before the magnetic pull.
///
/// [position] is normalized: (-1, -1) is the top-left edge of the widget,
/// (1, 1) the bottom-right edge, (0, 0) the center.
class MagneticLabel {
  const MagneticLabel({
    required this.text,
    required this.position,
    this.rotation = 0,
    this.floatCycles = 1,
    this.floatAmplitude = 10,
    this.phase = 0,
  });

  final String text;
  final Offset position;

  /// Resting tilt in radians.
  final double rotation;

  /// Whole number of float loops per idle period (higher = faster).
  /// Integers keep the loop seamless.
  final int floatCycles;

  /// Float distance in logical pixels (scaled for screen size).
  final double floatAmplitude;

  /// Phase offset in radians, so items don't move in sync.
  final double phase;
}

/// An icon / image tile revealed from the center after the labels vanish.
///
/// [position] uses the same normalized coordinates as [MagneticLabel].
class MagneticIcon {
  const MagneticIcon({
    required this.child,
    required this.position,
    this.size = 72,
    this.rotation = 0,
    this.floatCycles = 1,
    this.floatAmplitude = 6,
    this.phase = 0,
  });

  /// Convenience for local asset images. No network involved.
  factory MagneticIcon.asset(
      String assetPath, {
        required Offset position,
        double size = 72,
        double rotation = 0,
        int floatCycles = 1,
        double floatAmplitude = 6,
        double phase = 0,
      }) {
    return MagneticIcon(
      child: Image.asset(assetPath, fit: BoxFit.cover),
      position: position,
      size: size,
      rotation: rotation,
      floatCycles: floatCycles,
      floatAmplitude: floatAmplitude,
      phase: phase,
    );
  }

  /// Any widget. It is clipped to a rounded square and fills the tile.
  final Widget child;
  final Offset position;

  /// Tile edge length in logical pixels (scaled for screen size).
  final double size;
  final double rotation;
  final int floatCycles;
  final double floatAmplitude;
  final double phase;
}

/// Lets a parent restart the animation.
class MagneticRevealController {
  VoidCallback? _replay;

  void replay() => _replay?.call();
}

/// Floating labels -> magnetic pull into the center -> staggered spring
/// reveal of icons -> gentle idle floating.
///
/// Pure Flutter. No packages, no network.
class MagneticReveal extends StatefulWidget {
  const MagneticReveal({
    super.key,
    required this.labels,
    required this.icons,
    this.controller,
    this.autoPlay = true,
    this.holdDuration = const Duration(milliseconds: 1300),
    this.convergeDuration = const Duration(milliseconds: 900),
    this.revealDelay = Duration.zero,
    this.iconStagger = const Duration(milliseconds: 110),
    this.iconDuration = const Duration(milliseconds: 800),
    this.idlePeriod = const Duration(seconds: 8),
    this.convergeCurve = Curves.easeInCubic,
    this.revealCurve = Curves.easeOutBack,
    this.showBackground = true,
    this.backgroundGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE9E4FF), Color(0xFFFFE3EC), Color(0xFFDDF1FF)],
    ),
    this.labelColor = Colors.white,
    this.labelTextStyle = const TextStyle(
      color: Color(0xFF2B2B3A),
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    this.labelPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.labelShadows = const [
      BoxShadow(color: Color(0x1F000000), blurRadius: 14, offset: Offset(0, 6)),
    ],
    this.iconCornerRatio = 0.26,
    this.iconShadows = const [
      BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8)),
    ],
  });

  final List<MagneticLabel> labels;
  final List<MagneticIcon> icons;
  final MagneticRevealController? controller;
  final bool autoPlay;

  /// How long labels float before being pulled in.
  final Duration holdDuration;

  /// How long the magnetic pull takes.
  final Duration convergeDuration;

  /// Extra pause between labels vanishing and the first icon appearing.
  final Duration revealDelay;

  /// Delay between consecutive icons.
  final Duration iconStagger;

  /// Time each icon takes to pop out to its place.
  final Duration iconDuration;

  /// Length of one idle float loop.
  final Duration idlePeriod;

  final Curve convergeCurve;

  /// Use an overshooting curve (easeOutBack, elasticOut) for the spring pop.
  final Curve revealCurve;

  final bool showBackground;
  final Gradient? backgroundGradient;

  final Color labelColor;
  final TextStyle labelTextStyle;
  final EdgeInsets labelPadding;
  final List<BoxShadow> labelShadows;

  /// Icon corner radius as a fraction of its size.
  final double iconCornerRatio;
  final List<BoxShadow> iconShadows;

  @override
  State<MagneticReveal> createState() => _MagneticRevealState();
}

class _MagneticRevealState extends State<MagneticReveal>
    with TickerProviderStateMixin {
  static const double _idleBlendMs = 600;

  late final AnimationController _timeline;
  late final AnimationController _idle;
  late _Timing _timing;

  @override
  void initState() {
    super.initState();
    _timing = _Timing.from(widget);
    _timeline = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _timing.totalMs.round()),
    );
    _idle = AnimationController(vsync: this, duration: widget.idlePeriod)
      ..repeat();
    widget.controller?._replay = replay;
    if (widget.autoPlay) _timeline.forward();
  }

  @override
  void didUpdateWidget(covariant MagneticReveal old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._replay = null;
      widget.controller?._replay = replay;
    }
    _timing = _Timing.from(widget);
    _timeline.duration = Duration(milliseconds: _timing.totalMs.round());
    if (old.idlePeriod != widget.idlePeriod) {
      _idle
        ..duration = widget.idlePeriod
        ..repeat();
    }
  }

  void replay() => _timeline.forward(from: 0);

  @override
  void dispose() {
    widget.controller?._replay = null;
    _timeline.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.sizeOf(context);
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : media.width;
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : media.height;
        final ui = (math.min(w, h) / 400).clamp(0.6, 1.5).toDouble();
        final half = Offset(w / 2, h / 2);

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              for (final label in widget.labels)
                IgnorePointer(
                  child: _LabelItem(
                    label: label,
                    timeline: _timeline,
                    idle: _idle,
                    timing: _timing,
                    half: half,
                    ui: ui,
                    convergeCurve: widget.convergeCurve,
                    child: _buildPill(label),
                  ),
                ),
              for (var i = 0; i < widget.icons.length; i++)
                _IconItem(
                  icon: widget.icons[i],
                  index: i,
                  timeline: _timeline,
                  idle: _idle,
                  timing: _timing,
                  half: half,
                  ui: ui,
                  revealCurve: widget.revealCurve,
                  child: _buildTile(widget.icons[i]),
                ),
            ],
          ),
        );
      },
    );

    if (!widget.showBackground) return content;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: widget.backgroundGradient),
      child: content,
    );
  }

  Widget _buildPill(MagneticLabel label) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.labelColor,
        borderRadius: BorderRadius.circular(999),
        boxShadow: widget.labelShadows,
      ),
      child: Padding(
        padding: widget.labelPadding,
        child: Text(label.text, style: widget.labelTextStyle),
      ),
    );
  }

  Widget _buildTile(MagneticIcon icon) {
    final radius = BorderRadius.circular(icon.size * widget.iconCornerRatio);
    return SizedBox(
      width: icon.size,
      height: icon.size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: widget.iconShadows,
        ),
        child: ClipRRect(borderRadius: radius, child: icon.child),
      ),
    );
  }
}

/// Precomputed timeline in milliseconds.
class _Timing {
  const _Timing({
    required this.holdMs,
    required this.convergeMs,
    required this.revealStartMs,
    required this.staggerMs,
    required this.iconMs,
    required this.totalMs,
  });

  factory _Timing.from(MagneticReveal w) {
    final hold = w.holdDuration.inMilliseconds.toDouble();
    final converge = math.max(1, w.convergeDuration.inMilliseconds).toDouble();
    final revealStart = hold + converge + w.revealDelay.inMilliseconds;
    final stagger = w.iconStagger.inMilliseconds.toDouble();
    final iconMs = math.max(1, w.iconDuration.inMilliseconds).toDouble();
    final count = math.max(0, w.icons.length - 1);
    final total = revealStart +
        count * stagger +
        iconMs +
        _MagneticRevealState._idleBlendMs;
    return _Timing(
      holdMs: hold,
      convergeMs: converge,
      revealStartMs: revealStart,
      staggerMs: stagger,
      iconMs: iconMs,
      totalMs: total,
    );
  }

  final double holdMs;
  final double convergeMs;
  final double revealStartMs;
  final double staggerMs;
  final double iconMs;
  final double totalMs;
}

/// Seamless looping drift (integer cycles per idle period).
Offset _drift(double t, int cycles, double phase, double amp) {
  final a = 2 * math.pi * t * cycles + phase;
  return Offset(math.sin(a) * amp, math.cos(a * 2) * amp * 0.7);
}

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

class _LabelItem extends StatelessWidget {
  const _LabelItem({
    required this.label,
    required this.timeline,
    required this.idle,
    required this.timing,
    required this.half,
    required this.ui,
    required this.convergeCurve,
    required this.child,
  });

  static const double _introMs = 450;

  final MagneticLabel label;
  final Animation<double> timeline;
  final Animation<double> idle;
  final _Timing timing;
  final Offset half;
  final double ui;
  final Curve convergeCurve;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([timeline, idle]),
      child: child,
      builder: (context, child) {
        final ms = timeline.value * timing.totalMs;
        final c = _clamp01((ms - timing.holdMs) / timing.convergeMs);
        if (c >= 1) return const SizedBox.shrink();

        final e = convergeCurve.transform(c);
        final start = Offset(label.position.dx * half.dx, label.position.dy * half.dy);
        final drift = _drift(
          idle.value,
          label.floatCycles,
          label.phase,
          label.floatAmplitude * ui,
        );
        // Drift fades to zero so every label lands on the exact center.
        final pos = Offset.lerp(start, Offset.zero, e)! + drift * (1 - e);

        final introT = _clamp01(ms / _introMs);
        final intro = Curves.easeOutBack.transform(introT);
        final scale = (1 - e) * (0.7 + 0.3 * intro) * ui;
        final opacity = _clamp01((1 - e * e) * introT);
        final wobble = math.sin(2 * math.pi * idle.value * label.floatCycles + label.phase) * 0.04;
        final rotation = label.rotation + wobble + e * 0.5;

        return Align(
          alignment: Alignment.center,
          child: Transform.translate(
            offset: pos,
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: math.max(scale, 0.0001),
                child: Opacity(opacity: opacity, child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _IconItem extends StatelessWidget {
  const _IconItem({
    required this.icon,
    required this.index,
    required this.timeline,
    required this.idle,
    required this.timing,
    required this.half,
    required this.ui,
    required this.revealCurve,
    required this.child,
  });

  final MagneticIcon icon;
  final int index;
  final Animation<double> timeline;
  final Animation<double> idle;
  final _Timing timing;
  final Offset half;
  final double ui;
  final Curve revealCurve;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([timeline, idle]),
      child: child,
      builder: (context, child) {
        final ms = timeline.value * timing.totalMs;
        final start = timing.revealStartMs + index * timing.staggerMs;
        final t = _clamp01((ms - start) / timing.iconMs);
        if (t <= 0) return const SizedBox.shrink();

        // May overshoot past 1 for the spring effect.
        final p = revealCurve.transform(t);
        final target = Offset(icon.position.dx * half.dx, icon.position.dy * half.dy);

        // Idle float eases in after the icon has landed.
        final idleW = Curves.easeInOut.transform(
          _clamp01((ms - start - timing.iconMs) / _MagneticRevealState._idleBlendMs),
        );
        final drift = _drift(
          idle.value,
          icon.floatCycles,
          icon.phase,
          icon.floatAmplitude * ui,
        );
        final pos = Offset(target.dx * p, target.dy * p) + drift * idleW;

        final scale = (0.1 + 0.9 * p) * ui;
        final opacity = Curves.easeOut.transform(_clamp01(t / 0.35));
        final wobble = math.sin(2 * math.pi * idle.value * icon.floatCycles + icon.phase) * 0.035 * idleW;
        final rotation = icon.rotation * p - 0.4 * (1 - p) + wobble;

        return Align(
          alignment: Alignment.center,
          child: Transform.translate(
            offset: pos,
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: math.max(scale, 0.0001),
                child: Opacity(opacity: opacity, child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}


class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final _controller = MagneticRevealController();

  static const _labels = [
    MagneticLabel(text: 'Design', position: Offset(-0.7, -0.55), rotation: -0.12, floatCycles: 1, phase: 0.0),
    MagneticLabel(text: 'Ideas', position: Offset(0.6, -0.65), rotation: 0.10, floatCycles: 2, phase: 1.2),
    MagneticLabel(text: 'Music', position: Offset(-0.55, 0.05), rotation: 0.08, floatCycles: 1, phase: 2.1),
    MagneticLabel(text: 'Photos', position: Offset(0.7, -0.1), rotation: -0.07, floatCycles: 2, phase: 3.0),
    MagneticLabel(text: 'Travel', position: Offset(-0.65, 0.6), rotation: -0.10, floatCycles: 1, phase: 4.0),
    MagneticLabel(text: 'Notes', position: Offset(0.45, 0.62), rotation: 0.13, floatCycles: 2, phase: 5.1),
    MagneticLabel(text: 'Chat', position: Offset(0.05, -0.8), rotation: 0.05, floatCycles: 1, phase: 0.7),
  ];

  static final _icons = [
    _tile(const Offset(0.0, -0.5), Icons.palette_rounded, const [Color(0xFFFF8A65), Color(0xFFFF5252)], 84, -0.08, 0.0),
    _tile(const Offset(0.62, -0.3), Icons.music_note_rounded, const [Color(0xFFBA68C8), Color(0xFF7E57C2)], 72, 0.10, 1.0),
    _tile(const Offset(0.7, 0.25), Icons.photo_rounded, const [Color(0xFF4FC3F7), Color(0xFF29B6F6)], 76, -0.06, 2.0),
    _tile(const Offset(0.0, 0.55), Icons.flight_rounded, const [Color(0xFF81C784), Color(0xFF26A69A)], 88, 0.07, 3.0),
    _tile(const Offset(-0.62, 0.3), Icons.edit_note_rounded, const [Color(0xFFFFD54F), Color(0xFFFFA726)], 72, -0.10, 4.0),
    _tile(const Offset(-0.7, -0.25), Icons.chat_bubble_rounded, const [Color(0xFFF06292), Color(0xFFEC407A)], 76, 0.06, 5.0),
  ];

  static MagneticIcon _tile(
      Offset position,
      IconData icon,
      List<Color> colors,
      double size,
      double rotation,
      double phase,
      ) {
    return MagneticIcon(
      position: position,
      size: size,
      rotation: rotation,
      phase: phase,
      floatCycles: phase.toInt().isEven ? 1 : 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Center(child: Icon(icon, color: Colors.white, size: size * 0.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MagneticReveal(
        controller: _controller,
        labels: _labels,
        icons: _icons,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _controller.replay,
        child: const Icon(Icons.replay_rounded),
      ),
    );
  }
}
