import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Visual settings for [ReelStepper]. Defaults give the dark, monospace look.
class ReelStepperStyle {
  const ReelStepperStyle({
    this.backgroundColor = const Color(0xFF161616),
    this.borderColor = const Color(0xFF2A2A2A),
    this.arrowColor = const Color(0xFF737373),
    this.arrowHoverColor = Colors.white,
    this.labelStyle = const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Color(0xFFA3A3A3)),
    this.valueStyle = const TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
    this.height = 46,
    this.borderRadius = 10,
    this.itemHeight = 20,
    this.windowWidth = 84,
    this.horizontalPadding = 16,
    this.arrowSize = 17,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color arrowColor;
  final Color arrowHoverColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  /// Height of the whole field.
  final double height;
  final double borderRadius;

  /// Height of one row in the reel. The window shows exactly one row.
  final double itemHeight;

  /// Width of the window that shows the current value.
  final double windowWidth;
  final double horizontalPadding;
  final double arrowSize;

  ReelStepperStyle copyWith({
    Color? backgroundColor,
    Color? borderColor,
    Color? arrowColor,
    Color? arrowHoverColor,
    TextStyle? labelStyle,
    TextStyle? valueStyle,
    double? height,
    double? borderRadius,
    double? itemHeight,
    double? windowWidth,
    double? horizontalPadding,
    double? arrowSize,
  }) {
    return ReelStepperStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      arrowColor: arrowColor ?? this.arrowColor,
      arrowHoverColor: arrowHoverColor ?? this.arrowHoverColor,
      labelStyle: labelStyle ?? this.labelStyle,
      valueStyle: valueStyle ?? this.valueStyle,
      height: height ?? this.height,
      borderRadius: borderRadius ?? this.borderRadius,
      itemHeight: itemHeight ?? this.itemHeight,
      windowWidth: windowWidth ?? this.windowWidth,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      arrowSize: arrowSize ?? this.arrowSize,
    );
  }
}

/// A "dropdown" without a menu. Left and right arrows step through [items],
/// and the value rolls vertically inside a small window, like a slot reel.
///
/// The widget is controlled: keep the selected index in your own state and
/// update it from [onChanged]. It works with any type of item.
///
/// ```dart
/// ReelStepper<String>(
///   label: 'Preset',
///   items: const ['Liquid', 'Glass', 'Elastic', 'Magnetic', 'Orbit'],
///   index: _index,
///   onChanged: (i) => setState(() => _index = i),
/// )
/// ```
///
/// Users can also swipe horizontally on the value to step.
class ReelStepper<T> extends StatelessWidget {
  ReelStepper({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
    this.label,
    this.itemLabel,
    this.itemBuilder,
    this.wrap = true,
    this.duration = const Duration(milliseconds: 420),
    this.curve = const Cubic(0.2, 0.9, 0.3, 1.25),
    this.enableHaptics = false,
    this.style = const ReelStepperStyle(),
    this.semanticLabel,
  }) : assert(items.isNotEmpty, 'items must not be empty'),
       assert(index >= 0 && index < items.length, 'index is out of range');

  /// The options to step through.
  final List<T> items;

  /// Index of the selected item.
  final int index;

  /// Called with the new index when the user steps.
  final ValueChanged<int> onChanged;

  /// Text shown on the left.
  final String? label;

  /// Converts an item to text. Defaults to `item.toString()`.
  final String Function(T item)? itemLabel;

  /// Builds a custom widget for an item instead of plain text.
  /// It must fit inside one row ([ReelStepperStyle.itemHeight]).
  final Widget Function(BuildContext context, T item)? itemBuilder;

  /// When true, stepping past the last item goes to the first, and the reel
  /// rolls back through every item. When false, the arrows stop at the ends.
  final bool wrap;

  /// Length of the roll animation.
  final Duration duration;

  /// Curve of the roll animation. The default overshoots slightly.
  final Curve curve;

  /// Plays a light selection click on every step.
  final bool enableHaptics;

  final ReelStepperStyle style;
  final String? semanticLabel;

  String _labelOf(T item) => itemLabel?.call(item) ?? item.toString();

  void _go(int delta) {
    var next = index + delta;
    if (wrap) {
      next = (next + items.length) % items.length;
    } else {
      next = next.clamp(0, items.length - 1);
    }
    if (next == index) return;
    if (enableHaptics) HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final s = style;
    final canPrev = wrap || index > 0;
    final canNext = wrap || index < items.length - 1;

    final reel = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: index.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, pos, _) {
        return ClipRect(
          child: SizedBox(
            width: s.windowWidth,
            height: s.itemHeight,
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: s.itemHeight * items.length,
              child: Transform.translate(
                offset: Offset(0, -pos * s.itemHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: s.windowWidth,
                        height: s.itemHeight,
                        child: Center(
                          child:
                              itemBuilder?.call(context, item) ??
                              Text(_labelOf(item), style: s.valueStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    return Semantics(
      label: semanticLabel ?? label,
      value: _labelOf(items[index]),
      onIncrease: canNext ? () => _go(1) : null,
      onDecrease: canPrev ? () => _go(-1) : null,
      child: Container(
        height: s.height,
        padding: EdgeInsets.symmetric(horizontal: s.horizontalPadding),
        decoration: BoxDecoration(
          color: s.backgroundColor,
          border: Border.all(color: s.borderColor),
          borderRadius: BorderRadius.circular(s.borderRadius),
        ),
        child: Row(
          children: [
            if (label != null) Text(label!, style: s.labelStyle),
            const Spacer(),
            _StepArrow(icon: Icons.chevron_left, tooltip: 'Previous', enabled: canPrev, style: s, onTap: () => _go(-1)),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -200) {
                  _go(1);
                } else if (v > 200) {
                  _go(-1);
                }
              },
              child: reel,
            ),
            _StepArrow(icon: Icons.chevron_right, tooltip: 'Next', enabled: canNext, style: s, onTap: () => _go(1)),
          ],
        ),
      ),
    );
  }
}

class _StepArrow extends StatefulWidget {
  const _StepArrow({required this.icon, required this.tooltip, required this.enabled, required this.style, required this.onTap});

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final ReelStepperStyle style;
  final VoidCallback onTap;

  @override
  State<_StepArrow> createState() => _StepArrowState();
}

class _StepArrowState extends State<_StepArrow> {
  bool _hover = false;
  bool _down = false;

  void _set({bool? hover, bool? down}) {
    setState(() {
      _hover = hover ?? _hover;
      _down = down ?? _down;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    final base = _hover && widget.enabled ? s.arrowHoverColor : s.arrowColor;
    final color = widget.enabled ? base : base.withValues(alpha: 0.3);

    return Semantics(
      button: true,
      label: widget.tooltip,
      enabled: widget.enabled,
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => _set(hover: true),
        onExit: (_) => _set(hover: false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.enabled ? (_) => _set(down: true) : null,
          onTapUp: (_) => _set(down: false),
          onTapCancel: () => _set(down: false),
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedScale(
            scale: _down ? 0.75 : 1,
            duration: const Duration(milliseconds: 120),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: color),
                duration: const Duration(milliseconds: 150),
                builder: (context, c, _) => Icon(widget.icon, size: s.arrowSize, color: c),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
