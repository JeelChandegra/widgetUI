import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Visual settings for [ElasticSlider]. Defaults give the dark, monospace look.
class ElasticSliderStyle {
  const ElasticSliderStyle({
    this.backgroundColor = const Color(0xFF161616),
    this.borderColor = const Color(0xFF2A2A2A),
    this.thumbColor = Colors.white,
    this.tickColor = const Color(0xFF3A3A3A),
    this.labelStyle = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      color: Color(0xFFA3A3A3),
    ),
    this.valueStyle = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    this.height = 46,
    this.borderRadius = 10,
    this.thumbWidth = 6,
    this.thumbHeight = 24,
    this.maxHeightShrink = 9,
    this.tickHeight = 16,
    this.trackStartInset = 110,
    this.trackEndInset = 70,
    this.horizontalPadding = 16,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color thumbColor;
  final Color tickColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  /// Total height of the slider.
  final double height;
  final double borderRadius;

  /// Resting size of the thumb pill.
  final double thumbWidth;
  final double thumbHeight;

  /// How much shorter the thumb gets when fully stretched.
  final double maxHeightShrink;
  final double tickHeight;

  /// Space reserved on the left (for the label) and right (for the value).
  /// Set [trackStartInset] smaller when you do not use a label.
  final double trackStartInset;
  final double trackEndInset;

  /// Distance of the label and value from the left and right edges.
  final double horizontalPadding;

  ElasticSliderStyle copyWith({
    Color? backgroundColor,
    Color? borderColor,
    Color? thumbColor,
    Color? tickColor,
    TextStyle? labelStyle,
    TextStyle? valueStyle,
    double? height,
    double? borderRadius,
    double? thumbWidth,
    double? thumbHeight,
    double? maxHeightShrink,
    double? tickHeight,
    double? trackStartInset,
    double? trackEndInset,
    double? horizontalPadding,
  }) {
    return ElasticSliderStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      thumbColor: thumbColor ?? this.thumbColor,
      tickColor: tickColor ?? this.tickColor,
      labelStyle: labelStyle ?? this.labelStyle,
      valueStyle: valueStyle ?? this.valueStyle,
      height: height ?? this.height,
      borderRadius: borderRadius ?? this.borderRadius,
      thumbWidth: thumbWidth ?? this.thumbWidth,
      thumbHeight: thumbHeight ?? this.thumbHeight,
      maxHeightShrink: maxHeightShrink ?? this.maxHeightShrink,
      tickHeight: tickHeight ?? this.tickHeight,
      trackStartInset: trackStartInset ?? this.trackStartInset,
      trackEndInset: trackEndInset ?? this.trackEndInset,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
    );
  }
}

/// A range slider whose thumb is elastic.
///
/// While you drag, the thumb lags behind your finger and stretches into a long
/// pill that reaches from its current position to the finger. When you let go
/// it settles into a normal pill at the target value.
///
/// The widget is controlled: keep the value in your own state and update it
/// from [onChanged].
///
/// ```dart
/// ElasticSlider(
///   label: 'Parallax',
///   value: _parallax,
///   onChanged: (v) => setState(() => _parallax = v),
/// )
/// ```
class ElasticSlider extends StatefulWidget {
  const ElasticSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.tickCount,
    this.valueFormatter,
    this.followSpeed = 10.5,
    this.style = const ElasticSliderStyle(),
    this.semanticLabel,
  })  : assert(max > min),
        assert(divisions == null || divisions > 0),
        assert(tickCount == null || tickCount >= 2);

  /// Current value, between [min] and [max].
  final double value;

  /// Called whenever the user picks a new value.
  final ValueChanged<double> onChanged;

  /// Called when a drag or tap begins.
  final ValueChanged<double>? onChangeStart;

  /// Called when a drag or tap ends.
  final ValueChanged<double>? onChangeEnd;

  final double min;
  final double max;

  /// When set, the value snaps to this many equal steps.
  final int? divisions;

  /// Text shown on the left.
  final String? label;

  /// Number of tick marks. Defaults to `divisions + 1`, or 11 without divisions.
  final int? tickCount;

  /// Formats the value shown on the right. Defaults to two decimals.
  final String Function(double value)? valueFormatter;

  /// How quickly the thumb catches up with the target, per second.
  /// Higher is snappier. The default of 10.5 matches a lerp of 0.16 at 60 fps.
  final double followSpeed;

  final ElasticSliderStyle style;
  final String? semanticLabel;

  @override
  State<ElasticSlider> createState() => _ElasticSliderState();
}

class _ElasticSliderState extends State<ElasticSlider>
    with SingleTickerProviderStateMixin {
  static const double _epsilon = 0.0005;

  late final Ticker _ticker;
  final ValueNotifier<double> _display = ValueNotifier<double>(0);
  Duration _last = Duration.zero;
  bool _active = false;
  bool _dragging = false;

  double get _range => widget.max - widget.min;

  double get _targetT =>
      ((widget.value - widget.min) / _range).clamp(0.0, 1.0).toDouble();

  @override
  void initState() {
    super.initState();
    _display.value = _targetT;
    _ticker = createTicker(_onTick);
  }

  @override
  void didUpdateWidget(covariant ElasticSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((_display.value - _targetT).abs() > _epsilon && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _display.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = math.min(0.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    final target = _targetT;
    final k = 1 - math.exp(-widget.followSpeed * dt);
    _display.value += (target - _display.value) * k;
    if ((target - _display.value).abs() < _epsilon) {
      _display.value = target;
      _ticker.stop();
    }
  }

  void _begin() {
    if (_active) return;
    _active = true;
    widget.onChangeStart?.call(widget.value);
  }

  void _end() {
    if (!_active) return;
    _active = false;
    widget.onChangeEnd?.call(widget.value);
  }

  void _update(double dx, double trackWidth) {
    final style = widget.style;
    var t = ((dx - style.trackStartInset) / trackWidth).clamp(0.0, 1.0);
    final d = widget.divisions;
    if (d != null) t = (t * d).round() / d;
    final v = widget.min + t * _range;
    if (v != widget.value) widget.onChanged(v);
  }

  void _nudge(double delta) {
    final v = (widget.value + delta).clamp(widget.min, widget.max).toDouble();
    if (v != widget.value) widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    final format = widget.valueFormatter ?? (double v) => v.toStringAsFixed(2);
    final shown = widget.value.clamp(widget.min, widget.max).toDouble();
    final step = widget.divisions != null
        ? _range / widget.divisions!
        : _range / 10;
    final ticks = widget.tickCount ??
        (widget.divisions != null ? widget.divisions! + 1 : 11);

    return Semantics(
      slider: true,
      label: widget.semanticLabel ?? widget.label,
      value: format(shown),
      onIncrease: () => _nudge(step),
      onDecrease: () => _nudge(-step),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
          constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
          final trackWidth =
          math.max(1.0, width - s.trackStartInset - s.trackEndInset);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              _begin();
              _update(d.localPosition.dx, trackWidth);
            },
            onTapUp: (_) => _end(),
            onTapCancel: () {
              if (!_dragging) _end();
            },
            onHorizontalDragStart: (d) {
              _dragging = true;
              _begin();
              _update(d.localPosition.dx, trackWidth);
            },
            onHorizontalDragUpdate: (d) =>
                _update(d.localPosition.dx, trackWidth),
            onHorizontalDragEnd: (_) {
              _dragging = false;
              _end();
            },
            onHorizontalDragCancel: () {
              _dragging = false;
              _end();
            },
            child: SizedBox(
              width: width,
              height: s.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ElasticSliderPainter(
                        display: _display,
                        target: _targetT,
                        style: s,
                        tickCount: ticks,
                      ),
                    ),
                  ),
                  if (widget.label != null)
                    Positioned(
                      left: s.horizontalPadding,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Text(widget.label!, style: s.labelStyle),
                      ),
                    ),
                  Positioned(
                    right: s.horizontalPadding,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Text(format(shown), style: s.valueStyle),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ElasticSliderPainter extends CustomPainter {
  _ElasticSliderPainter({
    required this.display,
    required this.target,
    required this.style,
    required this.tickCount,
  }) : super(repaint: display);

  final ValueListenable<double> display;
  final double target;
  final ElasticSliderStyle style;
  final int tickCount;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final trackWidth =
    math.max(1.0, size.width - style.trackStartInset - style.trackEndInset);

    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Radius.circular(style.borderRadius),
    );
    canvas.drawRRect(box, Paint()..color = style.backgroundColor);
    canvas.drawRRect(
      box,
      Paint()
        ..color = style.borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final tickPaint = Paint()
      ..color = style.tickColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < tickCount; i++) {
      final x = style.trackStartInset + trackWidth * i / (tickCount - 1);
      canvas.drawLine(
        Offset(x, cy - style.tickHeight / 2),
        Offset(x, cy + style.tickHeight / 2),
        tickPaint,
      );
    }

    final targetX = style.trackStartInset + target * trackWidth;
    final laggingX = style.trackStartInset + display.value * trackWidth;
    final stretch = (targetX - laggingX).abs();
    final h = style.thumbHeight - math.min(stretch * 0.08, style.maxHeightShrink);
    final left = math.min(targetX, laggingX) - style.thumbWidth / 2;
    final right = math.max(targetX, laggingX) + style.thumbWidth / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, cy - h / 2, right, cy + h / 2),
        Radius.circular(style.thumbWidth / 2),
      ),
      Paint()..color = style.thumbColor,
    );
  }

  @override
  bool shouldRepaint(covariant _ElasticSliderPainter old) =>
      old.target != target ||
          old.style != style ||
          old.tickCount != tickCount ||
          old.display != display;
}