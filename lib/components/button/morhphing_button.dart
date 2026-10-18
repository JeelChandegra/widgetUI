  // morphing_button.dart
  //
  // MorphingButton: a pill button that springs open into an email field. Tap it
  // and the bell icon shrinks away, the container grows, an input fades in and
  // the button slides to the right edge as the submit action. Submitting (button
  // or Enter), or tapping outside, collapses it again.
  //
  // Flutter port of the React `MorphingButton` component (Tailwind + framer
  // motion). Zero dependencies (Flutter SDK only), no Riverpod.
  //
  // Requirements
  // - A Material ancestor (MaterialApp / Scaffold / Material) for the TextField.
  // - Needs a bounded width to center in. It takes the full available width
  //   (like the React `w-full` wrapper) and its own height (about 62 + padding).
  // - Light / dark colors follow `Theme.of(context).brightness`. Every color
  //   can be overridden.
  //
  // Behavior
  // - One spring (mass 1.1, stiffness 240, damping 18, same as React) drives the
  //   container width, the button position and size, the label shift, the icon
  //   pop (scale + fade + blur) and the input fade. It runs on an
  //   AnimationController; only the animated subtree rebuilds per frame and the
  //   TextField is built once.
  // - Expanded: the input is focused. Enter / the button submits when the field
  //   is not empty. Esc or a tap outside collapses (the text is kept).
  // - Reduced motion (MediaQuery.disableAnimations): no spring, instant swap.

  import 'dart:math' as math;
  import 'dart:ui' show ImageFilter;

  import 'package:flutter/material.dart';
  import 'package:flutter/physics.dart';
  import 'package:flutter/services.dart';

  const Map<ShortcutActivator, Intent> _activateKeys = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  };

  // Tailwind shadow-sm / shadow-lg / shadow-xl.
  const List<BoxShadow> _shadowSm = [
    BoxShadow(color: Color(0x1A000000), offset: Offset(0, 1), blurRadius: 3),
    BoxShadow(color: Color(0x1A000000), offset: Offset(0, 1), blurRadius: 2, spreadRadius: -1),
  ];
  const List<BoxShadow> _shadowLg = [
    BoxShadow(color: Color(0x1A000000), offset: Offset(0, 10), blurRadius: 15, spreadRadius: -3),
    BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 6, spreadRadius: -4),
  ];
  const List<BoxShadow> _shadowXl = [
    BoxShadow(color: Color(0x1A000000), offset: Offset(0, 20), blurRadius: 25, spreadRadius: -5),
    BoxShadow(color: Color(0x1A000000), offset: Offset(0, 8), blurRadius: 10, spreadRadius: -6),
  ];

  /// A button that morphs into an email input.
  class MorphingButton extends StatefulWidget {
    const MorphingButton({
      super.key,
      this.buttonText = 'Notify Me',
      this.placeholder = 'Email',
      this.onSubmit,
      this.icon = const Icon(Icons.notifications),
      this.expandedWidth = 336,
      this.padding = const EdgeInsets.all(32),
      this.textStyle,
      this.containerColor,
      this.borderColor,
      this.buttonColor,
      this.buttonHoverColor,
      this.expandedButtonColor,
      this.expandedButtonHoverColor,
      this.textColor,
      this.iconColor,
      this.inputColor,
      this.placeholderColor,
    });

    /// Label of the button.
    final String buttonText;

    /// Hint shown in the empty input.
    final String placeholder;

    /// Called with the typed text when the form is submitted. The field is
    /// cleared and the button collapses afterwards.
    final ValueChanged<String>? onSubmit;

    /// Icon shown before the label while collapsed (24 px). Default: a bell.
    final Widget icon;

    /// Width of the expanded container (Tailwind `w-84`). Shrinks to fit when
    /// less space is available.
    final double expandedWidth;

    /// Space around the control (Tailwind `p-8`).
    final EdgeInsetsGeometry padding;

    /// Merged over the label style (20 px, bold, tracking -0.5).
    final TextStyle? textStyle;

    /// Background of the container (both states).
    final Color? containerColor;

    /// Container border.
    final Color? borderColor;

    /// Collapsed button background.
    final Color? buttonColor;

    /// Collapsed button background on hover.
    final Color? buttonHoverColor;

    /// Expanded (submit) button background.
    final Color? expandedButtonColor;

    /// Expanded (submit) button background on hover.
    final Color? expandedButtonHoverColor;

    /// Button label color.
    final Color? textColor;

    /// Color of [icon].
    final Color? iconColor;

    /// Color of the typed text and the cursor.
    final Color? inputColor;

    /// Color of [placeholder].
    final Color? placeholderColor;

    @override
    State<MorphingButton> createState() => _MorphingButtonState();
  }

  class _MorphingButtonState extends State<MorphingButton>
      with SingleTickerProviderStateMixin {
    static const SpringDescription _spring =
    SpringDescription(mass: 1.1, stiffness: 240, damping: 18);
    static const double _border = 1.1;
    static const double _radius = 32;
    static const double _iconSize = 24;

    /// 0 = collapsed, 1 = expanded. Unbounded: the spring overshoots.
    late final AnimationController _p = AnimationController.unbounded(vsync: this)
      ..addStatusListener(_onStatus);
    final TextEditingController _text = TextEditingController();
    final FocusNode _inputFocus = FocusNode(debugLabel: 'MorphingButton input');

    bool _expanded = false;
    bool _hover = false;
    bool _ring = false;
    bool _reduce = false;

    // Cached label measurement.
    double _tw = 0;
    double _th = 28;
    int? _measuredKey;

    // ---- lifecycle ----------------------------------------------------------
    @override
    void initState() {
      super.initState();
      PaintingBinding.instance.systemFonts.addListener(_onFontsChanged);
    }

    @override
    void didChangeDependencies() {
      super.didChangeDependencies();
      _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      _measure();
    }

    @override
    void didUpdateWidget(covariant MorphingButton old) {
      super.didUpdateWidget(old);
      _measure();
    }

    @override
    void dispose() {
      PaintingBinding.instance.systemFonts.removeListener(_onFontsChanged);
      _p.dispose();
      _text.dispose();
      _inputFocus.dispose();
      super.dispose();
    }
    int _fontEpoch = 0;
    TextStyle _labelStyle() => DefaultTextStyle.of(context)
        .style
        .merge(const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.4,
      decoration: TextDecoration.none,
    ))
        .merge(widget.textStyle);

    void _measure() {
      final style = _labelStyle();
      final scaler = MediaQuery.textScalerOf(context);
      final key = Object.hash(widget.buttonText, style, scaler, _fontEpoch);
      if (key == _measuredKey) return;
      _measuredKey = key;
      final tp = TextPainter(
        text: TextSpan(text: widget.buttonText, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      _tw = tp.width.ceilToDouble() + 2; // ceil + tiny safety
      _th = tp.height;
      tp.dispose();
    }

    // ---- state --------------------------------------------------------------

    void _onStatus(AnimationStatus status) {
      // Snap the last fraction of a spring tolerance to the exact target.
      if (status == AnimationStatus.completed) {
        _p.value = _expanded ? 1 : 0;
      }
    }

    void _onFontsChanged() {
      if (!mounted) return;
      setState(() => _fontEpoch++);
    }
    void _drive(double target) {
      if (_reduce) {
        _p.value = target;
        return;
      }
      _p.animateWith(SpringSimulation(_spring, _p.value, target, _p.velocity));
    }

    void _setExpanded(bool next) {
      if (next == _expanded) return;
      setState(() => _expanded = next);
      if (next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _expanded) _inputFocus.requestFocus();
        });
      } else {
        _inputFocus.unfocus();
      }
      _drive(next ? 1 : 0);
    }

    void _submit() {
      widget.onSubmit?.call(_text.text);
      _setExpanded(false);
      _text.clear();
    }

    void _toggle() {
      if (!_expanded) {
        _setExpanded(true);
      } else if (_text.text.isNotEmpty) {
        _submit();
      }
    }

    void _submitFromKeyboard() {
      if (_text.text.isNotEmpty) {
        _submit();
      } else {
        _inputFocus.requestFocus();
      }
    }

    // ---- build --------------------------------------------------------------

    @override
    Widget build(BuildContext context) {
      _measure();
      final w = widget;
      final dark = Theme.of(context).brightness == Brightness.dark;

      final containerColor =
          w.containerColor ?? (dark ? const Color(0xFF1C1C1E) : const Color(0xFFF4F4F4));
      final borderColor =
          w.borderColor ?? (dark ? const Color(0x0DFFFFFF) : const Color(0xA6E7E6E6));
      final buttonBase = _expanded
          ? (w.expandedButtonColor ?? (dark ? const Color(0xFF2C2C2E) : const Color(0xFFFEFEFE)))
          : (w.buttonColor ?? (dark ? const Color(0xFF1C1C1E) : const Color(0xFFF4F4F4)));
      final buttonHover = _expanded
          ? (w.expandedButtonHoverColor ??
          (dark ? const Color(0xFF3A3A3C) : const Color(0xFFFAFAFA)))
          : (w.buttonHoverColor ?? (dark ? const Color(0xFF252529) : const Color(0xFFEBEAEA)));
      final textColor = w.textColor ?? (dark ? Colors.white : Colors.black);
      final iconColor = w.iconColor ?? (dark ? const Color(0xFFFEFEFE) : const Color(0xE6000000));
      final inputColor = w.inputColor ?? (dark ? const Color(0xFFFEFEFE) : const Color(0xFF18181B));
      final placeholderColor =
          w.placeholderColor ?? (dark ? const Color(0xFFB2B2B2) : const Color(0xFFA1A1AA));

      final label = _labelStyle().copyWith(color: textColor);
      final inputStyle = label.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: inputColor,
      );

      // Built once, passed to the animated subtree as a cached child.
      final input = TextField(
        controller: _text,
        focusNode: _inputFocus,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.email],
        autocorrect: false,
        enableSuggestions: false,
        cursorColor: inputColor,
        style: inputStyle,
        decoration: InputDecoration.collapsed(
          hintText: w.placeholder,
          hintStyle: inputStyle.copyWith(color: placeholderColor),
        ),
        onEditingComplete: _submitFromKeyboard,
        onTapOutside: (_) {}, // outside taps are handled by the TapRegion
      );

      final containerShadow = _expanded ? (dark ? _shadowXl : _shadowSm) : null;
      final buttonShadow = _expanded ? (dark ? _shadowLg : _shadowSm) : null;

      return Padding(
        padding: w.padding,
        child: LayoutBuilder(
          builder: (context, cons) {
            final we = cons.hasBoundedWidth
                ? math.min(w.expandedWidth, cons.maxWidth)
                : w.expandedWidth;
            final wc = _tw + 84 + 2 * _border; // collapsed container width
            final boxW = math.max(we, wc);
            final cw = math.max(_iconSize, _th) + 32; // collapsed button height
            final eh = _th + 24; // expanded button height
            final h = cw + 2 * _border;
            final wie = we - 2 * _border; // expanded inner width
            final inputW = math.max(0.0, wie - 8 - (_tw + 40) - 32);

            return Align(
              heightFactor: 1,
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onKeyEvent: (node, e) {
                  if (e is KeyDownEvent &&
                      e.logicalKey == LogicalKeyboardKey.escape &&
                      _expanded) {
                    _setExpanded(false);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: SizedBox(
                  width: boxW,
                  height: h,
                  child: AnimatedBuilder(
                    animation: _p,
                    child: input,
                    builder: (context, inputChild) {
                      final p = _p.value;
                      final pc = p.clamp(0.0, 1.0).toDouble();

                      final width = wc + (we - wc) * p;
                      final left = (boxW - width) / 2;
                      final btnW = (_tw + 84) + ((_tw + 40) - (_tw + 84)) * p;
                      final btnH = cw + (eh - cw) * p;
                      final btnLeft = (wie - 4 - (_tw + 40)) * p;
                      final btnTop = (cw - btnH) / 2;
                      final textX = 60 - 40 * p; // collapsed: 24 + 24 + 12 gap. expanded: 20 (even pad in _tw + 40 button)

                      // Bell: shrinks toward its right edge while fading and
                      // blurring (React: scale 0, opacity 0, blur 4).
                      final iconScale = math.max(0.0, 1 - p);
                      final iconOpacity = (1 - p).clamp(0.0, 1.0).toDouble();
                      final blur = 4 * pc;
                      Widget? icon;
                      if (iconScale > 0.001) {
                        Widget glyph = IconTheme(
                          data: IconThemeData(color: iconColor, size: _iconSize),
                          child: w.icon,
                        );
                        if (blur > 0.05) {
                          glyph = ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: blur,
                              sigmaY: blur,
                              tileMode: TileMode.decal,
                            ),
                            child: glyph,
                          );
                        }
                        icon = Positioned(
                          left: 24,
                          top: (btnH - _iconSize) / 2,
                          width: _iconSize,
                          height: _iconSize,
                          child: Opacity(
                            opacity: iconOpacity,
                            child: Transform.scale(
                              scale: iconScale,
                              alignment: Alignment.centerRight,
                              child: glyph,
                            ),
                          ),
                        );
                      }

                      final content = Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ?icon,
                          Positioned(
                            left: textX,
                            top: (btnH - _th) / 2,
                            child: Text(
                              w.buttonText,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              style: label,
                            ),
                          ),
                          if (_ring)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: textColor, width: 2),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );

                      final button = Semantics(
                        button: true,
                        label: w.buttonText,
                        hint: _expanded ? 'Submit email' : 'Enter your email',
                        expanded: _expanded,
                        onTap: _toggle,
                        excludeSemantics: true,
                        child: FocusableActionDetector(
                          mouseCursor: SystemMouseCursors.click,
                          shortcuts: _activateKeys,
                          actions: <Type, Action<Intent>>{
                            ActivateIntent: CallbackAction<ActivateIntent>(
                              onInvoke: (_) {
                                _toggle();
                                return null;
                              },
                            ),
                          },
                          onShowHoverHighlight: (v) => setState(() => _hover = v),
                          onShowFocusHighlight: (v) => setState(() => _ring = v),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _toggle,
                            child: TweenAnimationBuilder<Color?>(
                              tween: ColorTween(end: _hover ? buttonHover : buttonBase),
                              duration: _reduce ? Duration.zero : const Duration(milliseconds: 300),
                              curve: const Cubic(0.4, 0, 0.2, 1),
                              child: content,
                              builder: (context, color, child) => DecoratedBox(
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: buttonShadow,
                                ),
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      );

                      final container = Container(
                        width: width,
                        height: h,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: containerColor,
                          borderRadius: BorderRadius.circular(_radius),
                          border: Border.all(color: borderColor, width: _border),
                          boxShadow: containerShadow,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (_expanded || p > 0.001)
                              Positioned(
                                left: 20,
                                top: 0,
                                bottom: 0,
                                width: inputW,
                                child: IgnorePointer(
                                  ignoring: !_expanded,
                                  child: ExcludeFocus(
                                    excluding: !_expanded,
                                    child: ExcludeSemantics(
                                      excluding: !_expanded,
                                      child: Opacity(
                                        opacity: pc,
                                        child: Transform.translate(
                                          offset: Offset(_expanded ? -10 * (1 - pc) : 0, 0),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: inputChild,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              left: btnLeft,
                              top: btnTop,
                              width: btnW,
                              height: btnH,
                              child: button,
                            ),
                          ],
                        ),
                      );

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: left,
                            top: 0,
                            child: TapRegion(
                              // Same group as the TextField, so its selection
                              // toolbar counts as "inside".
                              groupId: EditableText,
                              onTapOutside: (_) {
                                if (_expanded) _setExpanded(false);
                              },
                              child: container,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
  }