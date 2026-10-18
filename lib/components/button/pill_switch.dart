// pill_switch.dart
//
// Animated toggle switch for the dark, monochrome site theme.
//
//   PillSwitch(value: on, onChanged: (v) => setState(() => on = v))
//
//   PillSwitch(                       // settings row: label left, switch right
//     value: snap,
//     onChanged: (v) => ...,
//     label: 'Snap',
//     description: 'Settle on the nearest card',
//   )
//
// - Spring slide with a slight overshoot, thumb stretches while pressed.
// - Tap, drag the thumb, or Space / Enter when focused.
// - Hover tint, keyboard focus ring, light haptic tick on mobile.
// - `onChanged: null` disables it. Reduced motion is respected.
// - Zero dependencies. Uses the ambient font.

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../app_common/export.dart';

enum PillSwitchSize { sm, md, lg }

class PillSwitch extends StatefulWidget {
  const PillSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.description,
    this.size = PillSwitchSize.md,
    this.activeColor = const Color(0xFFF5F5F5),
    this.inactiveColor = const Color(0xFF1C1C1C),
    this.thumbActiveColor = const Color(0xFF0B0B0B),
    this.thumbInactiveColor = const Color(0xFF8A8A8A),
    this.borderColor = const Color(0x1AFFFFFF),
    this.onIcon,
    this.offIcon,
    this.labelStyle,
    this.descriptionStyle,
    this.haptic = true,
    this.autofocus = false,
    this.semanticLabel,
  });

  final bool value;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;

  /// Optional text. When set the widget becomes a full-width row:
  /// label on the left, switch on the right. Tapping the label toggles.
  final String? label;
  final String? description;

  final PillSwitchSize size;

  /// Track color when on.
  final Color activeColor;

  /// Track color when off.
  final Color inactiveColor;
  final Color thumbActiveColor;
  final Color thumbInactiveColor;
  final Color borderColor;

  /// Tiny icons inside the thumb (use size ~12).
  final Widget? onIcon;
  final Widget? offIcon;

  final TextStyle? labelStyle;
  final TextStyle? descriptionStyle;

  /// Light haptic tick on toggle (mobile only).
  final bool haptic;
  final bool autofocus;

  /// Accessibility label when [label] is null.
  final String? semanticLabel;

  @override
  State<PillSwitch> createState() => _PillSwitchState();
}

class _Dims {
  const _Dims(this.w, this.h, this.pad);
  final double w;
  final double h;
  final double pad;
}

final SpringDescription _spring = SpringDescription.withDurationAndBounce(duration: const Duration(milliseconds: 320), bounce: 0.18);

class _PillSwitchState extends State<PillSwitch> with TickerProviderStateMixin {
  // 0 = off, 1 = on. Unbounded so the spring may overshoot slightly.
  late final AnimationController _t = AnimationController.unbounded(vsync: this, value: widget.value ? 1 : 0);

  // 0 = rest, 1 = pressed (thumb stretches).
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    reverseDuration: const Duration(milliseconds: 180),
  );

  bool _hover = false;
  bool _focusRing = false;
  bool _dragging = false;
  bool _reduce = false;

  bool get _enabled => widget.onChanged != null;

  _Dims get _dims => switch (widget.size) {
    PillSwitchSize.sm => const _Dims(32, 18, 2),
    PillSwitchSize.md => const _Dims(40, 24, 3),
    PillSwitchSize.lg => const _Dims(48, 28, 3),
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(covariant PillSwitch old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_dragging) {
      _moveTo(widget.value ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _t.dispose();
    _press.dispose();
    super.dispose();
  }

  void _moveTo(double target, [double velocity = 0]) {
    if (_reduce) {
      _t.value = target;
      return;
    }
    _t.animateWith(SpringSimulation(_spring, _t.value, target, velocity));
  }

  void _toggle() {
    if (!_enabled) return;
    if (widget.haptic) HapticFeedback.selectionClick();
    widget.onChanged!(!widget.value);
  }

  // ---- drag the thumb -----------------------------------------------------

  double get _travel {
    final d = _dims;
    return d.w - 2 * d.pad - (d.h - 2 * d.pad);
  }

  void _dragStart(DragStartDetails _) {
    if (!_enabled) return;
    _dragging = true;
    _t.stop();
    _press.forward();
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    _t.value = (_t.value + d.delta.dx / _travel).clamp(0.0, 1.0);
  }

  void _dragEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    _press.reverse();
    final target = _t.value >= 0.5;
    if (target != widget.value) {
      if (widget.haptic) HapticFeedback.selectionClick();
      widget.onChanged?.call(target);
    }
    // Settle after the parent had a chance to rebuild with the new value.
    final v = d.velocity.pixelsPerSecond.dx / _travel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _moveTo(widget.value ? 1 : 0, v);
    });
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final sw = _buildSwitch();

    Widget content = sw;
    if (widget.label != null) {
      final theme = Theme.of(context).textTheme;
      content = Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label!,
                  style:
                  widget.labelStyle ??
                      (theme.bodyMedium ?? const TextStyle()).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                ),
                if (widget.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.description!,
                    style: widget.descriptionStyle ?? (theme.bodySmall ?? const TextStyle()).copyWith(fontSize: 12, color: const Color(0xFF8A8A8A)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          sw,
        ],
      );
    }

    return Semantics(
      toggled: widget.value,
      enabled: _enabled,
      label: widget.label ?? widget.semanticLabel,
      onTap: _enabled ? _toggle : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: _enabled,
        autofocus: widget.autofocus,
        mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focusRing = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _toggle();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => _press.forward() : null,
          onTapUp: (_) => _press.reverse(),
          onTapCancel: () {
            if (!_dragging) _press.reverse();
          },
          onTap: _toggle,
          child: Opacity(opacity: _enabled ? 1 : 0.4, child: content),
        ),
      ),
    );
  }

  Widget _buildSwitch() {
    final d = _dims;
    final thumbBase = d.h - 2 * d.pad;

    return GestureDetector(
      onHorizontalDragStart: _dragStart,
      onHorizontalDragUpdate: _dragUpdate,
      onHorizontalDragEnd: _dragEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(d.h / 2 + 2),
          border: Border.all(color: _focusRing ? const Color(0x66FFFFFF) : Colors.transparent, width: 1.5),
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([_t, _press]),
          builder: (context, _) {
            final t = _t.value;
            final tc = t.clamp(0.0, 1.0);
            final p = Curves.easeOut.transform(_press.value);
            final stretch = thumbBase * 0.24 * p;
            final tw = thumbBase + stretch;

            // thumb stays anchored to the side it is moving toward
            final left = d.pad + _travel * t - stretch * tc;

            var track = Color.lerp(widget.inactiveColor, widget.activeColor, tc)!;
            if (_hover && _enabled) {
              track = Color.lerp(track, Colors.white, 0.06)!;
            }
            final thumb = Color.lerp(widget.thumbInactiveColor, widget.thumbActiveColor, tc)!;

            return Container(
              width: d.w,
              height: d.h,
              decoration: BoxDecoration(
                color: track,
                borderRadius: BorderRadius.circular(d.h / 2),
                border: Border.all(color: Color.lerp(widget.borderColor, Colors.transparent, tc)!),
                boxShadow: [BoxShadow(color: widget.activeColor.withValues(alpha: 0.10 * tc), blurRadius: 12)],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: left,
                    top: d.pad - 1, // -1 offsets the 1px border
                    width: tw,
                    height: thumbBase,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: thumb,
                        borderRadius: BorderRadius.circular(thumbBase / 2),
                        boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 2)],
                      ),
                      child: _thumbIcon(tc, thumbBase),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget? _thumbIcon(double tc, double size) {
    if (widget.onIcon == null && widget.offIcon == null) return null;
    final color = Color.lerp(
      widget.thumbActiveColor == widget.thumbInactiveColor ? widget.thumbInactiveColor : widget.inactiveColor,
      widget.activeColor,
      tc,
    )!;
    return Center(
      child: IconTheme(
        data: IconThemeData(color: color, size: size * 0.6),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.offIcon != null) Opacity(opacity: 1 - tc, child: widget.offIcon),
            if (widget.onIcon != null) Opacity(opacity: tc, child: widget.onIcon),
          ],
        ),
      ),
    );
  }
}