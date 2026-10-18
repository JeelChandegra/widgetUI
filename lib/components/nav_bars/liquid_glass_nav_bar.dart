

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/services.dart';

import '../../app_common/export.dart';

import 'dart:ui';
import 'package:flutter/material.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        extendBody: true,
        backgroundColor: const Color(0xFFF7F8FC),
        body: Stack(
          children: [
            // Background gradient
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF7F8FC),
                      Color(0xFFE9EDFF),
                      Color(0xFFFCEEF5),
                    ],
                  ),
                ),
              ),
            ),

            // Purple glow
            Positioned(
              top: 100,
              left: -80,
              child: _GlowCircle(
                size: 230,
                color: const Color(0xFF9B8AFF).withOpacity(0.22),
              ),
            ),

            // Pink glow
            Positioned(
              top: 320,
              right: -100,
              child: _GlowCircle(
                size: 260,
                color: const Color(0xFFFF9FC8).withOpacity(0.20),
              ),
            ),

            // Blue glow
            Positioned(
              bottom: 80,
              left: 70,
              child: _GlowCircle(
                size: 180,
                color: const Color(0xFF79C8FF).withOpacity(0.18),
              ),
            ),

            // Main content
            SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _index,
                children: const [
                  _DemoPage(
                    title: 'Discover',
                    subtitle: 'A little space for inspiration.',
                    icon: Icons.auto_awesome_rounded,
                    color: Color(0xFF7968E8),
                  ),
                  _DemoPage(
                    title: 'Explore',
                    subtitle: 'Find something extraordinary.',
                    icon: Icons.explore_rounded,
                    color: Color(0xFF3585D8),
                  ),
                  _DemoPage(
                    title: 'Your Favorites',
                    subtitle: 'Everything you love, in one place.',
                    icon: Icons.favorite_rounded,
                    color: Color(0xFFE56A9B),
                  ),
                  _DemoPage(
                    title: 'Your Profile',
                    subtitle: 'Make this space your own.',
                    icon: Icons.person_rounded,
                    color: Color(0xFF4C9F8A),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: LiquidGlassNavBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: const [
            LiquidGlassNavItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            LiquidGlassNavItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore_rounded),
              label: 'Explore',
            ),
            LiquidGlassNavItem(
              icon: Icon(Icons.favorite_border_rounded),
              activeIcon: Icon(Icons.favorite_rounded),
              label: 'Saved',
            ),
            LiquidGlassNavItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

class _DemoPage extends StatelessWidget {
  const _DemoPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MONDAY, OCTOBER 16',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: Color(0xFF85869A),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: Color(0xFF202137),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF77788E),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),

          // Featured card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.68),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.9),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.08),
                  blurRadius: 35,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Icon(
                    icon,
                    size: 30,
                    color: color,
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'A more beautiful way',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF25253B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Smooth transitions, soft colors, and a liquid glass navigation experience.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFF77788E),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Designed for simplicity',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF55566D),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          const Text(
            'SWIPE THROUGH YOUR SPACE',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9697AA),
            ),
          ),
        ],
      ),
    );
  }
}
// ============================================================================
// 1. Item model
// ============================================================================

/// Describes a single destination in a [LiquidGlassNavBar].
@immutable
class LiquidGlassNavItem {
  const LiquidGlassNavItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.badge,
    this.semanticLabel,
  });

  /// Icon shown when the item is not selected. Usually an `Icon(...)`.
  ///
  /// The bar wraps it in an [IconTheme] that animates the color and size, so
  /// don't hard-code a color on the icon if you want it to animate.
  final Widget icon;

  /// Text shown below the icon (when `showLabels` is true) and used as the
  /// default accessibility label.
  final String label;

  /// Optional icon shown while selected (e.g. a filled variant).
  final Widget? activeIcon;

  /// Optional badge (e.g. a small dot or count) anchored to the icon's
  /// top-right corner.
  final Widget? badge;

  /// Overrides [label] for screen readers.
  final String? semanticLabel;
}

// ============================================================================
// 2. Navigation bar
// ============================================================================

/// Controls whether the backdrop blur is used.
enum LiquidGlassBlurMode {
  /// Blur is on, unless the user has enabled high-contrast mode.
  auto,

  /// Always blur.
  enabled,

  /// Never blur; use a more opaque translucent surface instead.
  disabled,
}

/// A premium, iOS-inspired "Liquid Glass" bottom navigation bar.
///
/// Features: backdrop blur, specular sheen, gradient hairline border, soft
/// shadow, a liquid indicator that stretches while it travels, drag-to-switch,
/// haptics, safe-area handling and a graceful non-blurred fallback.
///
/// For the glass to show content behind it, place the bar in
/// `Scaffold.bottomNavigationBar` and set `Scaffold.extendBody: true`.
class LiquidGlassNavBar extends StatefulWidget {
  const LiquidGlassNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.height = 68,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12),
    this.padding = const EdgeInsets.all(6),
    this.maxWidth = 520,
    this.borderRadius = 34,
    this.blurSigma = 24,
    this.glassOpacity = 0.28,
    this.fallbackOpacity = 0.82,
    this.tintColor,
    this.selectedColor,
    this.unselectedColor,
    this.indicatorColor,
    this.borderColor,
    this.shadowColor,
    this.showLabels = true,
    this.iconSize = 24,
    this.labelStyle,
    this.animationDuration = const Duration(milliseconds: 420),
    this.animationCurve = Curves.easeOutCubic,
    this.blurMode = LiquidGlassBlurMode.auto,
    this.enableDrag = true,
    this.enableHaptics = true,
    this.useSafeArea = true,
  })  : assert(items.length >= 2 && items.length <= 6,
  'Provide between 2 and 6 items.'),
        assert(currentIndex >= 0 && currentIndex < items.length,
        'currentIndex is out of range.');

  /// Destinations (2–6).
  final List<LiquidGlassNavItem> items;

  /// Index of the selected item. You own this state.
  final int currentIndex;

  /// Called when an item is tapped or a drag settles on a new item.
  final ValueChanged<int> onTap;

  /// Height of the glass bar itself (excluding margin and safe area).
  final double height;

  /// Space around the bar. Bottom safe-area inset is added on top of this.
  final EdgeInsetsGeometry margin;

  /// Inner padding between the bar edge and the items/indicator.
  final EdgeInsets padding;

  /// Maximum bar width; keeps the bar tidy on tablets and desktop.
  final double maxWidth;

  /// Corner radius of the bar.
  final double borderRadius;

  /// Gaussian blur strength applied to content behind the bar.
  final double blurSigma;

  /// Opacity of the glass tint when blur is active (0–1).
  final double glassOpacity;

  /// Opacity of the tint when blur is off, so the bar stays legible.
  final double fallbackOpacity;

  /// Glass tint. Defaults to white (light theme) or dark gray (dark theme).
  final Color? tintColor;

  /// Selected item color. Defaults to iOS blue.
  final Color? selectedColor;

  /// Unselected item color. Defaults adapt to the theme brightness.
  final Color? unselectedColor;

  /// Fill of the sliding indicator. Defaults to a soft tint of [selectedColor].
  final Color? indicatorColor;

  /// Solid border color. When null, a light-catching gradient border is used.
  final Color? borderColor;

  /// Shadow color. Defaults adapt to the theme brightness.
  final Color? shadowColor;

  /// Whether labels are shown under icons.
  final bool showLabels;

  /// Icon size.
  final double iconSize;

  /// Base label style (color and weight are animated on top of it).
  final TextStyle? labelStyle;

  /// Duration of the indicator, icon and label transitions.
  final Duration animationDuration;

  /// Curve of the indicator transition.
  final Curve animationCurve;

  /// Blur behavior; see [LiquidGlassBlurMode].
  final LiquidGlassBlurMode blurMode;

  /// Allows dragging a finger across the bar to switch items.
  final bool enableDrag;

  /// Plays a light selection haptic when the selected item changes.
  final bool enableHaptics;

  /// Adds the device's bottom/side safe-area insets around the bar.
  final bool useSafeArea;

  @override
  State<LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

class _LiquidGlassNavBarState extends State<LiquidGlassNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late double _from;
  late double _to;
  double? _drag;
  int _dragIndex = -1;

  @override
  void initState() {
    super.initState();
    _from = _to = widget.currentIndex.toDouble();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant LiquidGlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex &&
        _drag == null &&
        _to != widget.currentIndex.toDouble()) {
      _animateTo(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Fractional position of the indicator (0 = first item).
  double get _position {
    if (_drag != null) return _drag!;
    final t = widget.animationCurve.transform(_controller.value);
    return lerpDouble(_from, _to, t)!;
  }

  void _animateTo(int index) {
    _from = _position;
    _to = index.toDouble();
    _drag = null;
    _controller
      ..duration = widget.animationDuration
      ..forward(from: 0);
  }

  void _handleTap(int index) {
    if (widget.enableHaptics && index != widget.currentIndex) {
      HapticFeedback.selectionClick();
    }
    widget.onTap(index);
  }

  void _onDragStart() {
    _controller.stop();
    setState(() {
      _drag = _position;
      _dragIndex = widget.currentIndex;
    });
  }

  void _onDragUpdate(DragUpdateDetails d, double itemWidth) {
    final maxIndex = widget.items.length - 1;
    final x = d.localPosition.dx - widget.padding.left;
    final pos = (x / itemWidth - 0.5).clamp(0.0, maxIndex.toDouble());
    final nearest = pos.round();
    if (widget.enableHaptics && nearest != _dragIndex) {
      HapticFeedback.selectionClick();
      _dragIndex = nearest;
    }
    setState(() => _drag = pos.toDouble());
  }

  void _onDragEnd() {
    final pos = _drag;
    if (pos == null) return;
    final index = pos.round().clamp(0, widget.items.length - 1);
    setState(() {
      _from = pos;
      _to = index.toDouble();
      _drag = null;
    });
    _controller
      ..duration = widget.animationDuration
      ..forward(from: 0);
    if (index != widget.currentIndex) widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blurOn = switch (widget.blurMode) {
      LiquidGlassBlurMode.enabled => true,
      LiquidGlassBlurMode.disabled => false,
      LiquidGlassBlurMode.auto => !MediaQuery.highContrastOf(context),
    };

    final selected = widget.selectedColor ??
        (isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF));
    final unselected = widget.unselectedColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.62)
            : Colors.black.withValues(alpha: 0.55));
    final tint =
        widget.tintColor ?? (isDark ? const Color(0xFF2C2C2E) : Colors.white);
    final fillAlpha = blurOn ? widget.glassOpacity : widget.fallbackOpacity;
    final shadowColor = widget.shadowColor ??
        Colors.black.withValues(alpha: isDark ? 0.45 : 0.16);

    final borderColors = widget.borderColor != null
        ? [widget.borderColor!, widget.borderColor!]
        : [
      Colors.white.withValues(alpha: isDark ? 0.38 : 0.90),
      Colors.white.withValues(alpha: isDark ? 0.06 : 0.20),
      Colors.white.withValues(alpha: isDark ? 0.20 : 0.55),
    ];

    final sheen = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: isDark ? 0.16 : 0.50),
        Colors.white.withValues(alpha: 0.03),
        Colors.white.withValues(alpha: isDark ? 0.06 : 0.20),
      ],
      stops: const [0, 0.5, 1],
    );

    final indicatorRadius = math.max(
      0.0,
      math.min(
        widget.borderRadius - widget.padding.top,
        (widget.height - widget.padding.vertical) / 2,
      ),
    );

    final n = widget.items.length;

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - widget.padding.horizontal) / n;

        Widget body = Padding(
          padding: widget.padding,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final pos = _position;
              final dist = (_to - _from).abs();
              final stretch = _drag != null
                  ? 0.14
                  : math.sin(math.pi * _controller.value) *
                  math.min(dist, 2.0) *
                  0.16;
              final indicatorWidth = (itemWidth - 4) * (1 + stretch);
              final center = (pos + 0.5) * itemWidth;

              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: center - indicatorWidth / 2,
                    width: indicatorWidth,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(indicatorRadius),
                          color: widget.indicatorColor ??
                              selected.withValues(alpha: isDark ? 0.24 : 0.15),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white
                                  .withValues(alpha: isDark ? 0.14 : 0.45),
                              Colors.white.withValues(alpha: 0.02),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white
                                .withValues(alpha: isDark ? 0.18 : 0.55),
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < n; i++)
                        SizedBox(
                          width: itemWidth,
                          child: _NavItemView(
                            item: widget.items[i],
                            selection:
                            (1 - (pos - i).abs()).clamp(0.0, 1.0).toDouble(),
                            isSelected: i == widget.currentIndex,
                            selectedColor: selected,
                            unselectedColor: unselected,
                            iconSize: widget.iconSize,
                            showLabel: widget.showLabels,
                            labelStyle: widget.labelStyle,
                            switchDuration: widget.animationDuration * 0.6,
                            onTap: () => _handleTap(i),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        );

        if (widget.enableDrag) {
          body = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _onDragStart(),
            onHorizontalDragUpdate: (d) => _onDragUpdate(d, itemWidth),
            onHorizontalDragEnd: (_) => _onDragEnd(),
            onHorizontalDragCancel: _onDragEnd,
            child: body,
          );
        }
        return body;
      },
    );

    final glass = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: BackdropFilter(
        enabled: blurOn,
        filter: ImageFilter.blur(
          sigmaX: widget.blurSigma,
          sigmaY: widget.blurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint.withValues(alpha: fillAlpha),
            gradient: sheen,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              content,
              IgnorePointer(
                child: CustomPaint(
                  painter: _GlassBorderPainter(
                    radius: widget.borderRadius,
                    colors: borderColors,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Widget bar = SizedBox(
      height: widget.height,
      child: CustomPaint(
        painter: _GlassShadowPainter(
          radius: widget.borderRadius,
          color: shadowColor,
        ),
        child: glass,
      ),
    );

    bar = Padding(
      padding: widget.margin,
      child: Align(
        heightFactor: 1,
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxWidth),
          child: bar,
        ),
      ),
    );

    if (widget.useSafeArea) {
      bar = SafeArea(top: false, child: bar);
    }

    return RepaintBoundary(
      child: MediaQuery.withClampedTextScaling(
        minScaleFactor: 1,
        maxScaleFactor: 1.25,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          child: bar,
        ),
      ),
    );
  }
}

class _NavItemView extends StatelessWidget {
  const _NavItemView({
    required this.item,
    required this.selection,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.iconSize,
    required this.showLabel,
    required this.labelStyle,
    required this.switchDuration,
    required this.onTap,
  });

  final LiquidGlassNavItem item;

  /// 0 (fully unselected) to 1 (indicator centered on this item).
  final double selection;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;
  final double iconSize;
  final bool showLabel;
  final TextStyle? labelStyle;
  final Duration switchDuration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(unselectedColor, selectedColor, selection)!;

    Widget icon = item.icon;
    if (item.activeIcon != null) {
      icon = AnimatedSwitcher(
        duration: switchDuration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey<bool>(selection > 0.5),
          child: selection > 0.5 ? item.activeIcon! : item.icon,
        ),
      );
    }

    icon = IconTheme(
      data: IconThemeData(color: color, size: iconSize),
      child: icon,
    );

    icon = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        icon,
        if (item.badge != null)
          Positioned(top: -4, right: -10, child: item.badge!),
      ],
    );

    final baseStyle = labelStyle ?? const TextStyle(fontSize: 11);

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.semanticLabel ?? item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                offset: Offset(0, showLabel ? -1.5 * selection : 0),
                child: Transform.scale(
                  scale: 1 + 0.10 * selection,
                  child: icon,
                ),
              ),
              if (showLabel) ...[
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: baseStyle.copyWith(
                    color: color,
                    fontWeight: FontWeight.lerp(
                      FontWeight.w500,
                      FontWeight.w700,
                      selection,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws a gradient hairline that mimics light catching the glass edge.
class _GlassBorderPainter extends CustomPainter {
  const _GlassBorderPainter({
    required this.radius,
    required this.colors,
    this.width = 1.0,
  });

  final double radius;
  final List<Color> colors;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect =
    RRect.fromRectAndRadius(rect, Radius.circular(radius)).deflate(width / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GlassBorderPainter old) =>
      old.radius != radius || old.width != width || old.colors != colors;
}

/// Soft shadow that is clipped away *inside* the bar, so it never muddies the
/// translucent glass surface.
class _GlassShadowPainter extends CustomPainter {
  const _GlassShadowPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final outside = Path.combine(
      PathOperation.difference,
      Path()
        ..addRect(Rect.fromLTWH(
            -120, -120, size.width + 240, size.height + 360)),
      Path()..addRRect(rrect),
    );

    canvas.save();
    canvas.clipPath(outside);
    canvas.drawRRect(
      rrect.shift(const Offset(0, 14)),
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawRRect(
      rrect.shift(const Offset(0, 3)),
      Paint()
        ..color = color.withValues(alpha: color.a * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassShadowPainter old) =>
      old.radius != radius || old.color != color;
}

// ============================================================================
// 3. Demo (optional, delete everything below if you only need the component)
// ============================================================================

class LiquidGlassDemoApp extends StatefulWidget {
  const LiquidGlassDemoApp({super.key});

  @override
  State<LiquidGlassDemoApp> createState() => _LiquidGlassDemoAppState();
}

class _LiquidGlassDemoAppState extends State<LiquidGlassDemoApp> {
  ThemeMode _mode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Liquid Glass Nav Bar',
      themeMode: _mode,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: LiquidGlassDemoHome(
        isDark: _mode == ThemeMode.dark,
        onToggleTheme: () => setState(() {
          _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
        }),
      ),
    );
  }
}

class LiquidGlassDemoHome extends StatefulWidget {
  const LiquidGlassDemoHome({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<LiquidGlassDemoHome> createState() => _LiquidGlassDemoHomeState();
}

class _LiquidGlassDemoHomeState extends State<LiquidGlassDemoHome> {
  int _index = 0;

  // Live-customizable properties (shown on the "Customize" tab).
  double _blur = 24;
  double _opacity = 0.28;
  double _radius = 34;
  double _height = 68;
  bool _labels = true;
  bool _blurEnabled = true;
  Color _accent = const Color(0xFF0A84FF);

  static const _items = <LiquidGlassNavItem>[
    LiquidGlassNavItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    LiquidGlassNavItem(
      icon: Icon(Icons.explore_outlined),
      activeIcon: Icon(Icons.explore_outlined),
      label: 'Explore',
    ),
    LiquidGlassNavItem(
      icon: Icon(Icons.favorite_border_rounded),
      activeIcon: Icon(Icons.favorite_rounded),
      label: 'Saved',
      badge: _Badge(),
    ),
    LiquidGlassNavItem(
      icon: Icon(Icons.tune_rounded),
      activeIcon: Icon(Icons.tune_rounded),
      label: 'Customize',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Required so page content scrolls *behind* the glass bar.
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _Backdrop(isDark: widget.isDark),
          // IndexedStack keeps each tab's scroll position and state alive.
          IndexedStack(
            index: _index,
            children: [
              const _FeedPage(title: 'Home', seed: 0),
              const _FeedPage(title: 'Explore', seed: 4),
              const _FeedPage(title: 'Saved', seed: 8),
              _CustomizePage(
                isDark: widget.isDark,
                onToggleTheme: widget.onToggleTheme,
                blur: _blur,
                opacity: _opacity,
                radius: _radius,
                height: _height,
                labels: _labels,
                blurEnabled: _blurEnabled,
                accent: _accent,
                onBlur: (v) => setState(() => _blur = v),
                onOpacity: (v) => setState(() => _opacity = v),
                onRadius: (v) => setState(() => _radius = v),
                onHeight: (v) => setState(() => _height = v),
                onLabels: (v) => setState(() => _labels = v),
                onBlurEnabled: (v) => setState(() => _blurEnabled = v),
                onAccent: (c) => setState(() => _accent = c),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: LiquidGlassNavBar(
        items: _items,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedColor: _accent,
        blurSigma: _blur,
        glassOpacity: _opacity,
        borderRadius: _radius,
        height: _height,
        showLabels: _labels,
        blurMode: _blurEnabled
            ? LiquidGlassBlurMode.enabled
            : LiquidGlassBlurMode.disabled,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      color: Colors.redAccent,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.2),
    ),
  );
}

/// Colorful background so the blur and refraction are easy to see.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.isDark});

  final bool isDark;

  Widget _blob(Alignment a, Color c, double size) => Align(
    alignment: a,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.55),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)]
                  : const [Color(0xFFFFE0F0), Color(0xFFD6E4FF), Color(0xFFE3FFF1)],
            ),
          ),
        ),
        _blob(const Alignment(-0.9, -0.6), Colors.pinkAccent, 260),
        _blob(const Alignment(1, -0.1), Colors.cyanAccent, 220),
        _blob(const Alignment(-0.5, 0.8), Colors.deepPurpleAccent, 300),
      ],
    );
  }
}

class _FeedPage extends StatelessWidget {
  const _FeedPage({required this.title, required this.seed});

  final String title;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      bottom: false,
      child: ListView.builder(
        // Leave room so the last card can scroll clear of the bar.
        padding: EdgeInsets.fromLTRB(20, 16, 20, 110 + bottomInset),
        itemCount: 13,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            );
          }
          final base = Colors.primaries[(seed + i) % Colors.primaries.length];
          return Container(
            height: 120,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(20),
            alignment: Alignment.bottomLeft,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                colors: [base.shade400, base.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Text(
              '$title card $i',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CustomizePage extends StatelessWidget {
  const _CustomizePage({
    required this.isDark,
    required this.onToggleTheme,
    required this.blur,
    required this.opacity,
    required this.radius,
    required this.height,
    required this.labels,
    required this.blurEnabled,
    required this.accent,
    required this.onBlur,
    required this.onOpacity,
    required this.onRadius,
    required this.onHeight,
    required this.onLabels,
    required this.onBlurEnabled,
    required this.onAccent,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;
  final double blur, opacity, radius, height;
  final bool labels, blurEnabled;
  final Color accent;
  final ValueChanged<double> onBlur, onOpacity, onRadius, onHeight;
  final ValueChanged<bool> onLabels, onBlurEnabled;
  final ValueChanged<Color> onAccent;

  static const _accents = <Color>[
    Color(0xFF0A84FF),
    Color(0xFFFF375F),
    Color(0xFF30D158),
    Color(0xFFFF9F0A),
    Color(0xFFBF5AF2),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 110 + bottomInset),
        children: [
          Text(
            'Customize',
            style: Theme.of(context)
                .textTheme
                .displaySmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _Panel(
            children: [
              SwitchListTile(
                title: const Text('Dark theme'),
                value: isDark,
                onChanged: (_) => onToggleTheme(),
              ),
              SwitchListTile(
                title: const Text('Show labels'),
                value: labels,
                onChanged: onLabels,
              ),
              SwitchListTile(
                title: const Text('Backdrop blur'),
                subtitle: const Text('Off = translucent fallback'),
                value: blurEnabled,
                onChanged: onBlurEnabled,
              ),
              _SliderTile('Blur sigma', blur, 0, 50, onBlur),
              _SliderTile('Glass opacity', opacity, 0.05, 0.8, onOpacity),
              _SliderTile('Corner radius', radius, 8, 40, onRadius),
              _SliderTile('Height', height, 56, 90, onHeight),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    const Text('Accent'),
                    const Spacer(),
                    for (final c in _accents)
                      GestureDetector(
                        onTap: () => onAccent(c),
                        child: Container(
                          width: 30,
                          height: 30,
                          margin: const EdgeInsets.only(left: 10),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: c == accent
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(children: children),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile(this.label, this.value, this.min, this.max, this.onChanged);

  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
          SizedBox(
            width: 40,
            child: Text(value.toStringAsFixed(value < 1 ? 2 : 0),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}