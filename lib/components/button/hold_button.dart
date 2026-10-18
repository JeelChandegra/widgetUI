// hold_button.dart
//
// Press-and-hold confirm button. A wavy liquid fill sweeps across while the
// user holds; when it reaches the end `onHold` fires. Release early and the
// fill drains back. A quick tap fires `onTap` instead.
//
// Flutter port of the React `HoldButton` component. Zero dependencies.
//
// Input: mouse, touch and keyboard (hold Space / Enter, Esc cancels).
// Place it anywhere with loose constraints (Row, Center, Align, Wrap...).
// Under tight constraints (e.g. directly as a Scaffold body) it stretches.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum HoldButtonSize { sm, md, lg }

enum HoldButtonFillDirection { right, up }

enum _Phase { idle, holding, done }

enum _Input { pointer, key }

class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    this.label = 'Hold to delete',
    this.doneLabel = 'Deleted',
    this.icon,
    this.doneIcon,
    this.backgroundColor = const Color(0xFF27272A),
    this.fillColor = const Color(0xFF5227FF),
    this.textColor = const Color(0xFFF5F5F5),
    this.fillTextColor = const Color(0xFFFFFFFF),
    this.textStyle,
    this.size = HoldButtonSize.md,
    this.radius = 14,
    this.fillDirection = HoldButtonFillDirection.right,
    this.holdTime = const Duration(milliseconds: 2000),
    this.releaseTime = const Duration(milliseconds: 200),
    this.pressScale = 0.97,
    this.wave = true,
    this.waveAmplitude = 6,
    this.glow = true,
    this.resetAfter = const Duration(milliseconds: 1200),
    this.enabled = true,
    this.onHold,
    this.onTap,
  });

  /// Idle text.
  final String label;

  /// Text shown after the hold completes.
  final String doneLabel;

  /// Optional leading icons. Colors follow the text color of each layer.
  final Widget? icon;
  final Widget? doneIcon;

  final Color backgroundColor;
  final Color fillColor;
  final Color textColor;

  /// Text color on top of the fill.
  final Color fillTextColor;

  /// Merged over the default style for [size].
  final TextStyle? textStyle;

  final HoldButtonSize size;
  final double radius;
  final HoldButtonFillDirection fillDirection;

  /// How long the user must hold.
  final Duration holdTime;

  /// How fast the fill drains when released early.
  final Duration releaseTime;

  /// Scale while pressed with pointer (mouse / touch).
  final double pressScale;

  /// Wavy leading edge on the fill.
  final bool wave;
  final double waveAmplitude;

  /// Colored glow while holding + pulse ring on completion.
  final bool glow;

  /// Time in the "done" state before returning to idle. Zero = stay done.
  final Duration resetAfter;

  final bool enabled;

  /// Fired once when the full hold completes.
  final VoidCallback? onHold;

  /// Fired when released within 250ms (a quick tap).
  final VoidCallback? onTap;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

const Duration _tapMax = Duration(milliseconds: 250);
const double _hitPad = 10;

class _HoldButtonState extends State<HoldButton>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _p = AnimationController(vsync: this);
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  final FocusNode _focus = FocusNode(debugLabel: 'HoldButton');
  final Stopwatch _clock = Stopwatch();

  _Phase _phase = _Phase.idle;
  _Input? _input;
  int? _pointer;
  Rect? _rect;
  Timer? _resetTimer;

  bool _hover = false;
  bool _focused = false;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _p.addStatusListener((s) {
      if (s == AnimationStatus.completed &&
          _p.value >= 1 &&
          _phase == _Phase.holding) {
        _complete();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(covariant HoldButton old) {
    super.didUpdateWidget(old);
    if (!widget.enabled && _phase == _Phase.holding) {
      _release(drifted: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _phase == _Phase.holding) {
      _pointer = null;
      _release(drifted: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resetTimer?.cancel();
    _p.dispose();
    _pulse.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---- state machine ------------------------------------------------------

  void _go(_Phase phase, [_Input? input]) {
    if (!mounted) return;
    setState(() {
      _phase = phase;
      _input = input;
    });
  }

  bool _begin(_Input input) {
    if (!widget.enabled || _phase != _Phase.idle) return false;
    _resetTimer?.cancel();
    _clock
      ..reset()
      ..start();
    _go(_Phase.holding, input);
    _p.animateTo(1, duration: widget.holdTime, curve: Curves.linear);
    return true;
  }

  void _release({bool drifted = false}) {
    if (_phase != _Phase.holding) return;
    final held = _clock.elapsed;
    _go(_Phase.idle);
    _p.animateTo(0, duration: widget.releaseTime, curve: Curves.easeOutCubic);
    if (!drifted && held < _tapMax) widget.onTap?.call();
  }

  void _complete() {
    if (_phase != _Phase.holding) return;
    _go(_Phase.done, _input);
    if (widget.glow && !_reduce) _pulse.forward(from: 0);
    widget.onHold?.call();
    if (widget.resetAfter > Duration.zero) {
      _resetTimer = Timer(widget.resetAfter, () {
        if (!mounted) return;
        _go(_Phase.idle);
        _p.animateTo(0,
            duration: widget.releaseTime, curve: Curves.easeOutCubic);
      });
    }
  }

  // ---- input --------------------------------------------------------------

  void _onDown(PointerDownEvent e) {
    if (_pointer != null) return;
    if (e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryButton) {
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if (!_begin(_Input.pointer)) return;
    _pointer = e.pointer;
    _rect = box.localToGlobal(Offset.zero) & box.size;
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    final r = _rect;
    if (r == null) return;
    if (!r.inflate(_hitPad).contains(e.position)) {
      _pointer = null;
      _release(drifted: true);
    }
  }

  void _onUp(PointerEvent e, {bool cancel = false}) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _release(drifted: cancel);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      if (_input == _Input.key && _phase == _Phase.holding) {
        _release(drifted: true);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter) {
      if (e is KeyDownEvent) {
        _begin(_Input.key);
      } else if (e is KeyUpEvent && _input == _Input.key) {
        _release();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- build --------------------------------------------------------------

  ({double h, double padH, double font}) get _spec => switch (widget.size) {
    HoldButtonSize.sm => (h: 36, padH: 16, font: 13),
    HoldButtonSize.md => (h: 44, padH: 22, font: 15),
    HoldButtonSize.lg => (h: 52, padH: 28, font: 17),
  };

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    final w = widget;
    final done = _phase == _Phase.done;
    final wave = (w.wave && !_reduce) ? w.waveAmplitude : 0.0;
    final cycles = w.holdTime.inMilliseconds / 1100;

    final style = DefaultTextStyle.of(context)
        .style
        .merge(
      TextStyle(
        fontSize: spec.font,
        fontWeight: FontWeight.w500,
        letterSpacing: spec.font * 0.01,
        height: 1,
        decoration: TextDecoration.none,
      ),
    )
        .merge(w.textStyle);

    Widget label(Color color) => _Label(
      label: w.label,
      doneLabel: w.doneLabel,
      icon: w.icon,
      doneIcon: w.doneIcon,
      done: done,
      color: color,
      style: style,
    );

    final hoverBg = (_hover && w.enabled)
        ? Color.lerp(w.backgroundColor, Colors.white, 0.08)!
        : w.backgroundColor;

    final showRing = _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

    final stack = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _BasePainter(hoverBg, w.radius)),
        ),
        // sizing layer: idle-colored label
        Container(
          height: spec.h,
          padding: EdgeInsets.symmetric(horizontal: spec.padH),
          alignment: Alignment.center,
          child: label(w.textColor),
        ),
        // fill layer: same label, fill colors, clipped by the wavy edge
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(w.radius),
              child: ClipPath(
                clipper: _FillClipper(
                  progress: _p,
                  up: w.fillDirection == HoldButtonFillDirection.up,
                  wave: wave,
                  cycles: cycles,
                ),
                child: ColoredBox(
                  color: w.fillColor,
                  child: Center(child: label(w.fillTextColor)),
                ),
              ),
            ),
          ),
        ),
        if (showRing)
          Positioned(
            left: -5,
            top: -5,
            right: -5,
            bottom: -5,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(w.radius + 5),
                  border: Border.all(color: w.fillColor, width: 2),
                ),
              ),
            ),
          ),
      ],
    );

    final glowing = AnimatedBuilder(
      animation: Listenable.merge([_p, _pulse]),
      child: stack,
      builder: (context, child) {
        final shadows = <BoxShadow>[];
        if (w.glow) {
          shadows.add(BoxShadow(
            color: w.fillColor.withValues(alpha: 0.7 * _p.value),
            offset: const Offset(0, 10),
            blurRadius: 32,
            spreadRadius: -6,
          ));
          final t = _pulse.value;
          if (t > 0 && t < 1) {
            shadows.add(BoxShadow(
              color: w.fillColor.withValues(alpha: 0.55 * (1 - t)),
              spreadRadius: 14 * Curves.easeOutCubic.transform(t),
            ));
          }
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(w.radius),
            boxShadow: shadows,
          ),
          child: child,
        );
      },
    );

    final pressed =
        _phase == _Phase.holding && _input == _Input.pointer && !_reduce;

    return Semantics(
      button: true,
      enabled: w.enabled,
      label: w.label,
      hint:
      'Press and hold for ${(w.holdTime.inMilliseconds / 1000).toStringAsFixed(1)} seconds to confirm',
      onLongPress: w.enabled ? _complete : null,
      excludeSemantics: true,
      child: Focus(
        focusNode: _focus,
        canRequestFocus: w.enabled,
        onKeyEvent: _onKey,
        onFocusChange: (f) => setState(() => _focused = f),
        child: MouseRegion(
          cursor: w.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onDown,
            onPointerMove: _onMove,
            onPointerUp: _onUp,
            onPointerCancel: (e) => _onUp(e, cancel: true),
            child: Opacity(
              opacity: w.enabled ? 1 : 0.5,
              child: AnimatedScale(
                scale: pressed ? w.pressScale : 1,
                duration: const Duration(milliseconds: 160),
                curve: const Cubic(0.23, 1, 0.32, 1),
                child: glowing,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Idle + done labels stacked and cross-faded. Sized by the wider of the two
/// so the button does not jump when the text changes.
class _Label extends StatelessWidget {
  const _Label({
    required this.label,
    required this.doneLabel,
    required this.icon,
    required this.doneIcon,
    required this.done,
    required this.color,
    required this.style,
  });

  final String label;
  final String doneLabel;
  final Widget? icon;
  final Widget? doneIcon;
  final bool done;
  final Color color;
  final TextStyle style;

  Widget _row(Widget? icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[icon, const SizedBox(width: 8)],
        Text(text, maxLines: 1, softWrap: false),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const fade = Duration(milliseconds: 200);
    return DefaultTextStyle(
      style: style.copyWith(color: color),
      child: IconTheme(
        data: IconThemeData(color: color, size: (style.fontSize ?? 15) * 1.2),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedOpacity(
              opacity: done ? 0 : 1,
              duration: fade,
              child: _row(icon, label),
            ),
            AnimatedOpacity(
              opacity: done ? 1 : 0,
              duration: fade,
              child: _row(doneIcon, doneLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _BasePainter extends CustomPainter {
  _BasePainter(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.drawRRect(rrect, Paint()..color = color);
    // 1px top highlight (the CSS inset shadow)
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 1),
      Paint()..color = const Color(0x0FFFFFFF),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BasePainter old) =>
      old.color != color || old.radius != radius;
}

/// Clips the fill layer to a region bounded by a scrolling sine edge.
/// `right`: edge sweeps left -> right. `up`: edge sweeps bottom -> top.
class _FillClipper extends CustomClipper<Path> {
  _FillClipper({
    required this.progress,
    required this.up,
    required this.wave,
    required this.cycles,
  }) : super(reclip: progress);

  final Animation<double> progress;
  final bool up;
  final double wave;
  final double cycles;

  @override
  Path getClip(Size size) {
    final p = progress.value;
    final a = wave;
    final amp = a * 0.5;
    final path = Path();

    if (!up) {
      // edge travels from -a (hidden) to w + a (fully covered)
      final edge = -a + p * (size.width + 2 * a);
      final period = size.height * 2 / 3;
      final shift = p * cycles * size.height;
      path.moveTo(0, 0);
      for (double y = 0; y < size.height; y += 2) {
        path.lineTo(
          edge + amp * math.sin(2 * math.pi * (y + shift) / period),
          y,
        );
      }
      path.lineTo(
        edge +
            amp * math.sin(2 * math.pi * (size.height + shift) / period),
        size.height,
      );
      path.lineTo(0, size.height);
      path.close();
    } else {
      final edge = size.height + a - p * (size.height + 2 * a);
      final period = size.width;
      final shift = p * cycles * size.width;
      path.moveTo(0, size.height);
      for (double x = 0; x < size.width; x += 2) {
        path.lineTo(
          x,
          edge + amp * math.sin(2 * math.pi * (x + shift) / period),
        );
      }
      path.lineTo(
        size.width,
        edge + amp * math.sin(2 * math.pi * (size.width + shift) / period),
      );
      path.lineTo(size.width, size.height);
      path.close();
    }
    return path;
  }

  @override
  bool shouldReclip(_FillClipper old) =>
      old.up != up || old.wave != wave || old.cycles != cycles;
}