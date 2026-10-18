import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colors and shape for the picker. Defaults give the dark, monospace look.
class ColorPickerStyle {
  const ColorPickerStyle({
    this.backgroundColor = const Color(0xFF161616),
    this.panelColor = const Color(0xFF0F0F11),
    this.borderColor = const Color(0xFF2A2A2A),
    this.textColor = Colors.white,
    this.mutedColor = const Color(0xFFA3A3A3),
    this.fontFamily = 'monospace',
    this.borderRadius = 10,
  });

  final Color backgroundColor;
  final Color panelColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final String fontFamily;
  final double borderRadius;

  TextStyle text({double size = 13, Color? color, FontWeight? weight}) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        color: color ?? textColor,
        fontWeight: weight,
      );
}

/// Quick-pick colors shown in the swatch row.
const List<Color> kDefaultPresets = [
  Color(0xFFA855F7),
  Color(0xFF7C3AED),
  Color(0xFF6366F1),
  Color(0xFF3B82F6),
  Color(0xFF06B6D4),
  Color(0xFF10B981),
  Color(0xFF84CC16),
  Color(0xFFEAB308),
  Color(0xFFF97316),
  Color(0xFFEF4444),
  Color(0xFFEC4899),
  Color(0xFFF43F5E),
  Colors.white,
  Color(0xFF94A3B8),
  Colors.black,
];

enum ColorFormat { hex, rgb, hsl, flutter }

extension ColorFormatLabel on ColorFormat {
  String get label {
    switch (this) {
      case ColorFormat.hex:
        return 'Hex';
      case ColorFormat.rgb:
        return 'RGB';
      case ColorFormat.hsl:
        return 'HSL';
      case ColorFormat.flutter:
        return 'Flutter';
    }
  }
}

/// Returns `#rrggbb`, or `#rrggbbaa` when [alpha] is true.
String colorToHex(Color c, {bool alpha = false}) {
  String h(double v) => (v * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${h(c.r)}${h(c.g)}${h(c.b)}${alpha ? h(c.a) : ''}';
}

/// Parses `#rgb` or `#rrggbb` (the `#` is optional). Returns null if invalid.
Color? parseHexColor(String input) {
  var s = input.trim().replaceFirst('#', '');
  if (s.length == 3) s = s.split('').map((e) => '$e$e').join();
  if (s.length != 6) return null;
  final v = int.tryParse(s, radix: 16);
  if (v == null) return null;
  return Color(0xFF000000 | v);
}

/// Formats [c] as hex, CSS rgb, CSS hsl, or Flutter `Color(0x...)` code.
String formatColor(Color c, ColorFormat f) {
  final r = (c.r * 255).round();
  final g = (c.g * 255).round();
  final b = (c.b * 255).round();
  final a = c.a;
  if (f == ColorFormat.hex) return colorToHex(c, alpha: a < 1);
  if (f == ColorFormat.rgb) {
    return a < 1
        ? 'rgba($r, $g, $b, ${a.toStringAsFixed(2)})'
        : 'rgb($r, $g, $b)';
  }
  if (f == ColorFormat.hsl) {
    final h = HSLColor.fromColor(c);
    final body = '${h.hue.round()} ${(h.saturation * 100).round()}% '
        '${(h.lightness * 100).round()}%';
    return a < 1 ? 'hsl($body / ${a.toStringAsFixed(2)})' : 'hsl($body)';
  }
  String x(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
  return 'Color(0x${x((a * 255).round())}${x(r)}${x(g)}${x(b)})';
}

bool _sameRgb(Color a, Color b) =>
    (a.toARGB32() & 0xFFFFFF) == (b.toARGB32() & 0xFFFFFF);

double _clamp(double v, [double lo = 0, double hi = 1]) =>
    math.min(hi, math.max(lo, v));

Widget _stagger(
    Animation<double> parent,
    double start,
    double end,
    Widget child,
    ) {
  final e = end > 1 ? 1.0 : end;
  final fade = parent.drive(
    CurveTween(curve: Interval(start, e, curve: Curves.easeOut)),
  );
  final slide = parent
      .drive(CurveTween(curve: Interval(start, e, curve: Curves.easeOutBack)))
      .drive(Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero));
  return FadeTransition(
    opacity: fade,
    child: SlideTransition(position: slide, child: child),
  );
}

/// A collapsible color field. It shows a label, a swatch and the hex value.
/// Tapping it grows a full picker underneath, with the sections arriving one
/// after another.
///
/// The widget is controlled: keep the color in your own state.
///
/// ```dart
/// ColorPickerField(
///   label: 'Depth color',
///   color: _color,
///   onChanged: (c) => setState(() => _color = c),
/// )
/// ```
class ColorPickerField extends StatefulWidget {
  const ColorPickerField({
    super.key,
    required this.color,
    required this.onChanged,
    this.label = 'Color',
    this.presets = kDefaultPresets,
    this.showAlpha = false,
    this.showDepthShades = false,
    this.initiallyExpanded = false,
    this.maxRecent = 8,
    this.initialRecent = const [],
    this.onExpansionChanged,
    this.style = const ColorPickerStyle(),
  });

  final Color color;

  /// Called continuously while the user changes the color.
  final ValueChanged<Color> onChanged;

  final String label;
  final List<Color> presets;

  /// Adds an alpha slider and formats output with transparency.
  final bool showAlpha;

  /// Shows the four layered "depth shades" derived from the current color.
  final bool showDepthShades;

  final bool initiallyExpanded;
  final int maxRecent;
  final List<Color> initialRecent;
  final ValueChanged<bool>? onExpansionChanged;
  final ColorPickerStyle style;

  @override
  State<ColorPickerField> createState() => _ColorPickerFieldState();
}

class _ColorPickerFieldState extends State<ColorPickerField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _size;
  late bool _open;
  late List<Color> _recent;

  @override
  void initState() {
    super.initState();
    _open = widget.initiallyExpanded;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
      reverseDuration: const Duration(milliseconds: 280),
      value: _open ? 1 : 0,
    );
    _size = _ctrl.drive(CurveTween(curve: Curves.easeOutCubic));
    _recent = [...widget.initialRecent];
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _remember(Color c) {
    setState(() {
      _recent.removeWhere((e) => _sameRgb(e, c));
      _recent.insert(0, c);
      if (_recent.length > widget.maxRecent) {
        _recent = _recent.sublist(0, widget.maxRecent);
      }
    });
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _ctrl.forward();
    } else {
      final closing = widget.color; // color at the moment of closing
      _ctrl.reverse().whenCompleteOrCancel(() {
        if (mounted) _remember(closing);
      });
    }
    widget.onExpansionChanged?.call(_open);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    final hexText = colorToHex(widget.color);

    final header = Semantics(
      button: true,
      label: widget.label,
      value: hexText,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Container(
            height: 46,
            padding: const EdgeInsets.fromLTRB(16, 0, 10, 0),
            decoration: BoxDecoration(
              color: s.backgroundColor,
              border: Border.all(color: s.borderColor),
              borderRadius: BorderRadius.circular(s.borderRadius),
            ),
            child: Row(
              children: [
                Text(widget.label, style: s.text(color: s.mutedColor)),
                const Spacer(),
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: widget.color),
                  duration: const Duration(milliseconds: 250),
                  builder: (context, c, _) => Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: s.borderColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: s.panelColor,
                    border: Border.all(color: s.borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(hexText, style: s.text()),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: s.mutedColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final panel = Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: s.panelColor,
          border: Border.all(color: s.borderColor),
          borderRadius: BorderRadius.circular(s.borderRadius + 2),
        ),
        child: ColorPickerPanel(
          color: widget.color,
          onChanged: widget.onChanged,
          // onChangeEnd: _remember,
          presets: widget.presets,
          recent: _recent,
          showAlpha: widget.showAlpha,
          showDepthShades: widget.showDepthShades,
          style: s,
          reveal: _ctrl,
        ),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          AnimatedBuilder(
            animation: _ctrl,
            child: panel,
            builder: (context, child) {
              if (_ctrl.isDismissed) return const SizedBox.shrink();
              return SizeTransition(
                sizeFactor: _size,
                axisAlignment: -1,
                child: child,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The picker itself, without the field. Use it inside a dialog, bottom sheet
/// or any panel of your own.
class ColorPickerPanel extends StatefulWidget {
  const ColorPickerPanel({
    super.key,
    required this.color,
    required this.onChanged,
    this.onChangeEnd,
    this.presets = kDefaultPresets,
    this.recent = const [],
    this.showAlpha = false,
    this.showDepthShades = true,
    this.style = const ColorPickerStyle(),
    this.reveal,
  });

  final Color color;
  final ValueChanged<Color> onChanged;

  /// Called when a drag, tap or text edit finishes. Good moment to save.
  final ValueChanged<Color>? onChangeEnd;

  final List<Color> presets;
  final List<Color> recent;
  final bool showAlpha;
  final bool showDepthShades;
  final ColorPickerStyle style;

  /// Optional 0 to 1 animation that staggers the sections in.
  final Animation<double>? reveal;

  @override
  State<ColorPickerPanel> createState() => _ColorPickerPanelState();
}

class _ColorPickerPanelState extends State<ColorPickerPanel> {
  late HSVColor _hsv;
  ColorFormat _format = ColorFormat.hex;
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _copied = false;
  bool _bad = false;
  double _turns = 0;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.color);
    _text.text = colorToHex(_hsv.toColor());
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant ColorPickerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.color != _hsv.toColor()) {
      _hsv = HSVColor.fromColor(widget.color);
    }
    _syncText();
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus) {
      setState(() => _bad = false);
      _syncText();
      widget.onChangeEnd?.call(_hsv.toColor());
    }
  }

  void _syncText() {
    if (_focus.hasFocus) return;
    final t = colorToHex(_hsv.toColor());
    if (_text.text != t) _text.text = t;
  }

  void _set(HSVColor next) {
    setState(() => _hsv = next);
    widget.onChanged(next.toColor());
    _syncText();
  }

  void _end() => widget.onChangeEnd?.call(_hsv.toColor());

  void _pick(Color c) {
    _set(HSVColor.fromColor(c).withAlpha(_hsv.alpha));
    _end();
  }

  void _randomize() {
    final r = math.Random();
    setState(() => _turns += 1);
    _set(HSVColor.fromAHSV(
      _hsv.alpha,
      r.nextDouble() * 360,
      0.45 + r.nextDouble() * 0.45,
      0.55 + r.nextDouble() * 0.4,
    ));
    _end();
  }

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(text: formatColor(_hsv.toColor(), _format)),
    );
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _copied = false);
  }

  void _onHexTyped(String value) {
    final c = parseHexColor(value);
    setState(() => _bad = c == null && value.length >= 7);
    if (c != null) {
      _set(HSVColor.fromColor(c).withAlpha(_hsv.alpha));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reveal = widget.reveal ?? kAlwaysCompleteAnimation;
    final sections = <Widget>[
      _stagger(
        reveal,
        0.0,
        0.5,
        _ToneArea(
          hsv: _hsv,
          style: widget.style,
          onChanged: _set,
          onEnd: _end,
        ),
      ),
      _stagger(reveal, 0.08, 0.58, _hueRow()),
      if (widget.showAlpha) _stagger(reveal, 0.14, 0.64, _alphaRow()),
      _stagger(reveal, 0.2, 0.7, _formatRow()),
      _stagger(reveal, 0.26, 0.76, _swatches(reveal)),
      if (widget.showDepthShades) _stagger(reveal, 0.34, 0.84, _depth()),
      if (widget.recent.isNotEmpty) _stagger(reveal, 0.42, 0.92, _recent()),
    ];

    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            sections[i],
          ],
        ],
      ),
    );
  }

  Widget _hueRow() {
    final s = widget.style;
    return Row(
      children: [
        _SquareButton(
          style: s,
          onTap: _randomize,
          child: AnimatedRotation(
            turns: _turns,
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutBack,
            child: Icon(Icons.casino_outlined, size: 20, color: s.mutedColor),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GradientSlider(
            value: _hsv.hue / 360,
            gradient: LinearGradient(colors: [
              for (var i = 0; i <= 6; i++)
                HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor(),
            ]),
            onChanged: (v) => _set(_hsv.withHue(_clamp(v * 360, 0, 360))),
            onEnd: _end,
          ),
        ),
      ],
    );
  }

  Widget _alphaRow() {
    final s = widget.style;
    final solid = _hsv.withAlpha(1).toColor();
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text('Alpha', style: s.text(size: 12, color: s.mutedColor)),
        ),
        Expanded(
          child: _GradientSlider(
            value: _hsv.alpha,
            checker: true,
            gradient: LinearGradient(
              colors: [solid.withValues(alpha: 0), solid],
            ),
            onChanged: (v) => _set(_hsv.withAlpha(v)),
            onEnd: _end,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${(_hsv.alpha * 100).round()}%',
            textAlign: TextAlign.right,
            style: s.text(size: 12),
          ),
        ),
      ],
    );
  }

  Widget _formatRow() {
    final s = widget.style;
    final color = _hsv.toColor();

    final chip = _SquareButton(
      style: s,
      width: 72,
      onTap: () {
        setState(() {
          _format = ColorFormat.values[(_format.index + 1) % 4];
        });
        _syncText();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, anim) {
          final incoming = child.key == ValueKey<ColorFormat>(_format);
          final offset = Tween<Offset>(
            begin: Offset(0, incoming ? 0.9 : -0.9),
            end: Offset.zero,
          ).animate(anim);
          return ClipRect(
            child: SlideTransition(
              position: offset,
              child: FadeTransition(opacity: anim, child: child),
            ),
          );
        },
        child: Text(
          _format.label,
          key: ValueKey<ColorFormat>(_format),
          style: s.text(size: 13),
        ),
      ),
    );

    final Widget value = _format == ColorFormat.hex
        ? TextField(
      key: const ValueKey('hex-input'),
      controller: _text,
      focusNode: _focus,
      autocorrect: false,
      enableSuggestions: false,
      cursorColor: s.textColor,
      style: s.text(size: 14),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F#]')),
        LengthLimitingTextInputFormatter(7),
      ],
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: _onHexTyped,
      onSubmitted: (_) => _focus.unfocus(),
      onTapOutside: (_) => _focus.unfocus(),
    )
        : Align(
      key: ValueKey<ColorFormat>(_format),
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(formatColor(color, _format), style: s.text(size: 14)),
      ),
    );

    return Row(
      children: [
        chip,
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: s.backgroundColor,
              border: Border.all(
                color: _bad ? const Color(0xFFE24B4A) : s.borderColor,
              ),
              borderRadius: BorderRadius.circular(s.borderRadius),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: value,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _SquareButton(
          style: s,
          onTap: _copy,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              key: ValueKey<bool>(_copied),
              size: 18,
              color: _copied ? const Color(0xFF7CF4C8) : s.mutedColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _swatches(Animation<double> reveal) {
    final color = _hsv.toColor();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < widget.presets.length; i++)
          _stagger(
            reveal,
            0.26 + i * 0.02,
            0.26 + i * 0.02 + 0.3,
            _Swatch(
              color: widget.presets[i],
              selected: _sameRgb(widget.presets[i], color),
              style: widget.style,
              onTap: () => _pick(widget.presets[i]),
            ),
          ),
      ],
    );
  }

  List<(String, HSVColor)> _layers() {
    final h = _hsv;
    HSVColor shade(double dv, double sat) => h
        .withValue(_clamp(h.value + dv, 0.04, 1))
        .withSaturation(_clamp(h.saturation * sat));
    return [
      ('Far', shade(0.28, 0.55)),
      ('Mid', h),
      ('Near', shade(-0.16, 1)),
      ('Front', shade(-0.3, 1)),
    ];
  }

  Widget _depth() {
    final s = widget.style;
    final layers = _layers();
    final current = _hsv.toColor();
    const heights = [46.0, 52.0, 58.0, 64.0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Depth shades', style: s.text(size: 11, color: s.mutedColor)),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            final cardW = c.maxWidth * 0.34;
            final step = (c.maxWidth - cardW) / 3;
            return SizedBox(
              height: 64,
              child: Stack(
                children: [
                  for (var i = 0; i < layers.length; i++)
                    Positioned(
                      left: step * i,
                      bottom: 0,
                      width: cardW,
                      height: heights[i],
                      child: _DepthCard(
                        label: layers[i].$1,
                        color: layers[i].$2.toColor(),
                        selected: _sameRgb(layers[i].$2.toColor(), current),
                        style: s,
                        onTap: () => _pick(layers[i].$2.toColor()),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _recent() {
    final s = widget.style;
    final current = _hsv.toColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent', style: s.text(size: 11, color: s.mutedColor)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in widget.recent)
              TweenAnimationBuilder<double>(
                key: ValueKey<int>(c.toARGB32()),
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                builder: (context, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: _Swatch(
                  color: c,
                  size: 26,
                  rounded: true,
                  selected: _sameRgb(c, current),
                  style: s,
                  onTap: () => _pick(c),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ToneArea extends StatefulWidget {
  const _ToneArea({
    required this.hsv,
    required this.style,
    required this.onChanged,
    required this.onEnd,
  });

  final HSVColor hsv;
  final ColorPickerStyle style;
  final ValueChanged<HSVColor> onChanged;
  final VoidCallback onEnd;

  @override
  State<_ToneArea> createState() => _ToneAreaState();
}

class _ToneAreaState extends State<_ToneArea> {
  static const double _height = 160;
  bool _drag = false;

  void _update(Offset p, double w) {
    final s = _clamp(p.dx / w);
    final v = _clamp(1 - p.dy / _height);
    widget.onChanged(widget.hsv.withSaturation(s).withValue(v));
  }

  void _finish() {
    if (_drag) setState(() => _drag = false);
    widget.onEnd();
  }

  @override
  Widget build(BuildContext context) {
    final hsv = widget.hsv;
    final solid = hsv.withAlpha(1).toColor();
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final target = Offset(hsv.saturation * w, (1 - hsv.value) * _height);
        return GestureDetector(
          onPanDown: (d) {
            setState(() => _drag = true);
            _update(d.localPosition, w);
          },
          onPanUpdate: (d) => _update(d.localPosition, w),
          onPanEnd: (_) => _finish(),
          onPanCancel: _finish,
          child: SizedBox(
            height: _height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius:
                    BorderRadius.circular(widget.style.borderRadius + 2),
                    child: CustomPaint(painter: _TonePainter(hsv.hue)),
                  ),
                ),
                TweenAnimationBuilder<Offset>(
                  tween: Tween<Offset>(end: target),
                  duration:
                  _drag ? Duration.zero : const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  builder: (context, o, _) => Positioned(
                    left: o.dx - 24,
                    top: o.dy - 24,
                    width: 48,
                    height: 48,
                    child: IgnorePointer(
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutBack,
                          width: _drag ? 32 : 22,
                          height: _drag ? 32 : 22,
                          decoration: BoxDecoration(
                            color: solid,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color:
                                solid.withValues(alpha: _drag ? 0.75 : 0.3),
                                blurRadius: _drag ? 20 : 8,
                                spreadRadius: _drag ? 3 : 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TonePainter extends CustomPainter {
  _TonePainter(this.hue);

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(colors: [Colors.white, hueColor])
            .createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _TonePainter old) => old.hue != hue;
}

class _GradientSlider extends StatefulWidget {
  const _GradientSlider({
    required this.value,
    required this.gradient,
    required this.onChanged,
    required this.onEnd,
    this.checker = false,
  });

  final double value;
  final Gradient gradient;
  final ValueChanged<double> onChanged;
  final VoidCallback onEnd;
  final bool checker;

  @override
  State<_GradientSlider> createState() => _GradientSliderState();
}

class _GradientSliderState extends State<_GradientSlider> {
  bool _drag = false;

  void _emit(double dx, double w) => widget.onChanged(_clamp(dx / w));

  void _finish() {
    if (_drag) setState(() => _drag = false);
    widget.onEnd();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) {
            setState(() => _drag = true);
            _emit(d.localPosition.dx, w);
          },
          onPanUpdate: (d) => _emit(d.localPosition.dx, w),
          onPanEnd: (_) => _finish(),
          onPanCancel: _finish,
          child: SizedBox(
            height: 34,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      height: 14,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (widget.checker)
                              CustomPaint(painter: _CheckerPainter()),
                            DecoratedBox(
                              decoration:
                              BoxDecoration(gradient: widget.gradient),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: widget.value * w),
                  duration:
                  _drag ? Duration.zero : const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  builder: (context, x, _) => Positioned(
                    left: x - 4,
                    top: 0,
                    bottom: 0,
                    width: 8,
                    child: IgnorePointer(
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOutBack,
                          width: 6,
                          height: _drag ? 34 : 26,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: const [
                              BoxShadow(color: Colors.black, spreadRadius: 2),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 7.0;
    final a = Paint()..color = const Color(0xFF2A2A2A);
    final b = Paint()..color = const Color(0xFF191919);
    for (var y = 0; y * cell < size.height; y++) {
      for (var x = 0; x * cell < size.width; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell, cell),
          (x + y).isEven ? a : b,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerPainter old) => false;
}

class _SquareButton extends StatefulWidget {
  const _SquareButton({
    required this.child,
    required this.onTap,
    required this.style,
    this.width = 44,
  });

  final Widget child;
  final VoidCallback onTap;
  final ColorPickerStyle style;
  final double width;

  @override
  State<_SquareButton> createState() => _SquareButtonState();
}

class _SquareButtonState extends State<_SquareButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.92 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: widget.width,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.backgroundColor,
              border: Border.all(
                color: _hover ? const Color(0xFF4A4A50) : s.borderColor,
              ),
              borderRadius: BorderRadius.circular(s.borderRadius),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatefulWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    required this.style,
    this.size = 28,
    this.rounded = false,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final ColorPickerStyle style;
  final double size;
  final bool rounded;

  @override
  State<_Swatch> createState() => _SwatchState();
}

class _SwatchState extends State<_Swatch> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final rounded = widget.rounded;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.8 : (_hover ? 1.12 : 1),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: widget.size,
            height: widget.size,
            padding: EdgeInsets.all(widget.selected ? 3 : 0),
            decoration: BoxDecoration(
              shape: rounded ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: rounded ? BorderRadius.circular(9) : null,
              border: Border.all(
                color: widget.selected ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.color,
                shape: rounded ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: rounded ? BorderRadius.circular(5) : null,
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DepthCard extends StatelessWidget {
  const _DepthCard({
    required this.label,
    required this.color,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final ColorPickerStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(9, 7, 0, 0),
          alignment: Alignment.topLeft,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? Colors.white : style.panelColor,
              width: 2,
            ),
          ),
          child: Text(
            label,
            style: style.text(
              size: 11,
              color: dark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}