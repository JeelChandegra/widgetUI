// PillNavBar - a floating, glassy bottom navigation bar.
//
// No external dependencies. Needs Flutter >= 3.27 (uses Color.withValues).
//
// How it works: a single animated "position" value (a double between 0 and
// n-1) drives everything. The selected tab widens, its label fades in, and a
// pill indicator glides between tabs. Total width is constant, so nothing
// jumps while animating.
//
// Usage:
//   Scaffold(
//     extendBody: true,
//     bottomNavigationBar: PillNavBar(
//       selectedIndex: _index,
//       onChanged: (i) => setState(() => _index = i),
//       items: const [
//         PillNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
//         PillNavItem(icon: Icons.search_rounded, label: 'Search'),
//         PillNavItem(icon: Icons.notifications_none_rounded, label: 'Alerts', badgeCount: 3),
//         PillNavItem(icon: Icons.person_outline_rounded, label: 'Profile', showBadgeDot: true),
//       ],
//     ),
//   )

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// Describes one destination in a [PillNavBar].
@immutable
class PillNavItem {
  const PillNavItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.badgeCount,
    this.showBadgeDot = false,
    this.semanticLabel,
  });

  final IconData icon;

  /// Optional icon shown while this tab is selected.
  final IconData? activeIcon;

  final String label;

  /// Shows a numeric badge when > 0 (99+ is capped).
  final int? badgeCount;

  /// Shows a small dot badge (ignored when [badgeCount] is shown).
  final bool showBadgeDot;

  /// Overrides [label] for screen readers.
  final String? semanticLabel;
}

class PillNavBar extends StatelessWidget {
  PillNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 64,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12),
    this.padding = const EdgeInsets.all(6),
    this.borderRadius = 32,
    this.backgroundColor,
    this.borderColor,
    this.activeColor,
    this.inactiveColor,
    this.indicatorColor,
    this.indicatorGradient,
    this.badgeColor,
    this.glow = true,
    this.blur = 18,
    this.shadows,
    this.iconSize = 24,
    this.labelStyle,
    this.expandFactor = 2.2,
    this.itemGap = 4,
    this.duration = const Duration(milliseconds: 420),
    this.curve = Curves.easeOutCubic,
    this.haptics = true,
    this.allowDrag = true,
    this.safeArea = true,
  })  : assert(items.length >= 2, 'Provide at least 2 items'),
        assert(selectedIndex >= 0 && selectedIndex < items.length),
        assert(expandFactor >= 1);

  final List<PillNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Total bar height, including [padding].
  final double height;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  final Color? backgroundColor;
  final Color? borderColor;

  /// Icon + label color on top of the indicator.
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? indicatorColor;
  final Gradient? indicatorGradient;
  final Color? badgeColor;

  /// Soft colored glow under the indicator.
  final bool glow;

  /// Backdrop blur sigma. Use 0 for a solid bar.
  final double blur;
  final List<BoxShadow>? shadows;
  final double iconSize;
  final TextStyle? labelStyle;

  /// How many "units" wide the selected tab is compared to others.
  final double expandFactor;
  final double itemGap;
  final Duration duration;

  /// Avoid overshooting curves (easeOutBack etc.), the position is clamped.
  final Curve curve;
  final bool haptics;

  /// Lets the user slide a finger across the bar to switch tabs.
  final bool allowDrag;

  /// Adds bottom safe-area padding (home indicator).
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;

    final active = activeColor ?? scheme.onPrimary;
    final inactive = inactiveColor ?? scheme.onSurface.withValues(alpha: 0.62);
    final pill = indicatorColor ?? scheme.primary;
    final bg = backgroundColor ?? scheme.surface.withValues(alpha: blur > 0 ? 0.78 : 1);
    final edge = borderColor ?? scheme.outlineVariant.withValues(alpha: 0.5);
    final badge = badgeColor ?? scheme.error;
    final radius = BorderRadius.circular(borderRadius);
    final text = const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1)
        .merge(labelStyle);

    final n = items.length;

    Widget content = LayoutBuilder(
      builder: (context, box) {
        final innerW = box.maxWidth;
        final unit = innerW / (n + expandFactor - 1);

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: selectedIndex.toDouble()),
          duration: reduceMotion ? Duration.zero : duration,
          curve: curve,
          builder: (context, rawPos, _) {
            final pos = rawPos.clamp(0.0, n - 1.0).toDouble();

            // emphasis per tab: 1 when selected, 0 when far away
            final emphasis = List<double>.generate(
              n,
                  (i) => (1 - (pos - i).abs()).clamp(0.0, 1.0).toDouble(),
            );

            // geometry (mirrored for RTL)
            final lefts = List<double>.filled(n, 0);
            final widths = List<double>.filled(n, 0);
            var run = 0.0;
            for (var i = 0; i < n; i++) {
              final w = unit * (1 + (expandFactor - 1) * emphasis[i]);
              widths[i] = w;
              lefts[i] = rtl ? innerW - run - w : run;
              run += w;
            }

            // indicator = interpolation between the two nearest tabs
            final a = pos.floor();
            final b = (a + 1).clamp(0, n - 1);
            final t = pos - a;
            final indLeft = lefts[a] + (lefts[b] - lefts[a]) * t;
            final indWidth = widths[a] + (widths[b] - widths[a]) * t;

            void select(int i) {
              if (i == selectedIndex) return;
              if (haptics) HapticFeedback.selectionClick();
              onChanged(i);
            }

            int? hit(double dx) {
              for (var i = 0; i < n; i++) {
                if (dx >= lefts[i] && dx <= lefts[i] + widths[i]) return i;
              }
              return null;
            }

            void drag(DragUpdateDetails d) {
              final i = hit(d.localPosition.dx);
              if (i != null) select(i);
            }

            final inset = itemGap / 2;

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: allowDrag ? drag : null,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: indLeft + inset,
                    width: (indWidth - itemGap).clamp(0.0, double.infinity),
                    top: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: indicatorGradient == null ? pill : null,
                        gradient: indicatorGradient,
                        borderRadius: BorderRadius.circular(borderRadius),
                        boxShadow: glow
                            ? [
                          BoxShadow(
                            color: pill.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                            : null,
                      ),
                    ),
                  ),
                  for (var i = 0; i < n; i++)
                    Positioned(
                      left: lefts[i] + inset,
                      width: (widths[i] - itemGap).clamp(0.0, double.infinity),
                      top: 0,
                      bottom: 0,
                      child: _NavTile(
                        item: items[i],
                        selected: i == selectedIndex,
                        emphasis: emphasis[i],
                        activeColor: active,
                        inactiveColor: inactive,
                        badgeColor: badge,
                        iconSize: iconSize,
                        labelStyle: text,
                        onTap: () => select(i),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    Widget bar = SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: shadows ??
              [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: _maybeBlur(
            blur,
            DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: radius,
                border: Border.all(color: edge),
              ),
              child: Padding(padding: padding, child: content),
            ),
          ),
        ),
      ),
    );

    bar = Padding(padding: margin, child: bar);
    if (safeArea) bar = SafeArea(top: false, child: bar);
    return Material(type: MaterialType.transparency, child: bar);
  }

  static Widget _maybeBlur(double sigma, Widget child) {
    if (sigma <= 0) return child;
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.emphasis,
    required this.activeColor,
    required this.inactiveColor,
    required this.badgeColor,
    required this.iconSize,
    required this.labelStyle,
    required this.onTap,
  });

  final PillNavItem item;
  final bool selected;
  final double emphasis;
  final Color activeColor;
  final Color inactiveColor;
  final Color badgeColor;
  final double iconSize;
  final TextStyle labelStyle;
  final VoidCallback onTap;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  Widget _badge() {
    final item = widget.item;
    final count = item.badgeCount ?? 0;
    if (count > 0) {
      return Container(
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.badgeColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            height: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: widget.badgeColor, shape: BoxShape.circle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final e = widget.emphasis;
    final color = Color.lerp(widget.inactiveColor, widget.activeColor, e)!;
    final hasBadge = (item.badgeCount ?? 0) > 0 || item.showBadgeDot;

    Widget icon = Icon(
      e > 0.5 && item.activeIcon != null ? item.activeIcon : item.icon,
      size: widget.iconSize,
      color: color,
    );
    if (hasBadge) {
      icon = Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          PositionedDirectional(top: -4, end: -6, child: _badge()),
        ],
      );
    }

    final label = ClipRect(
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: e,
        child: Opacity(
          opacity: e,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: Text(
              item.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: widget.labelStyle.copyWith(color: color),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: widget.selected,
      label: item.semanticLabel ?? item.label,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => _setDown(true),
          onTapUp: (_) => _setDown(false),
          onTapCancel: () => _setDown(false),
          child: AnimatedScale(
            scale: _down ? 0.93 : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [icon, Flexible(child: label)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}



class PillNavBarPreview extends StatefulWidget {
  const PillNavBarPreview({super.key});

  @override
  State<PillNavBarPreview> createState() => _PillNavBarPreviewState();
}

class _PillNavBarPreviewState extends State<PillNavBarPreview> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0A), // dark card background
      alignment: Alignment.center,
      child: PillNavBar(
        selectedIndex: _index,
        onChanged: (i) => setState(() => _index = i),
        safeArea: false,
        margin: const EdgeInsets.symmetric(horizontal: 16),

        // dark styling
        backgroundColor: const Color(0xFF161616).withValues(alpha: 0.85),
        borderColor: Colors.white.withValues(alpha: 0.08),
        inactiveColor: Colors.white54,
        activeColor: Colors.white,
        indicatorGradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF00B0FF)]),
        indicatorColor: const Color(0xFF7C4DFF), // used for the glow
        badgeColor: const Color(0xFFFF4D6D),
        shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 30, offset: const Offset(0, 12))],

        items: const [
          PillNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
          PillNavItem(icon: Icons.search_rounded, label: 'Search'),
          PillNavItem(icon: Icons.notifications_none_rounded, label: 'Alerts', badgeCount: 3),
          PillNavItem(icon: Icons.person_outline_rounded, label: 'Profile', showBadgeDot: true),
        ],
      ),
    );
  }
}