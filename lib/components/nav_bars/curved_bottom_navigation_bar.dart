

import 'package:flutter/services.dart';

import '../../app_common/export.dart';

class BottomNavDemoScreen extends StatefulWidget {
  const BottomNavDemoScreen({super.key});

  @override
  State<BottomNavDemoScreen> createState() => _BottomNavDemoScreenState();
}

class _BottomNavDemoScreenState extends State<BottomNavDemoScreen> {
  int _index = 1;

  static const _items = [
    CurvedNavItem(icon: Icons.grid_view_rounded, label: 'Home'),
    CurvedNavItem(icon: Icons.format_list_bulleted_rounded, label: 'Tasks'),
    CurvedNavItem(icon: Icons.swap_horiz_rounded, label: 'Transfer'),
    CurvedNavItem(icon: Icons.wallet_outlined, label: 'Wallet'),
    CurvedNavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  static const _titles = ['Home', 'Tasks', 'Transfer', 'Wallet', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // notch shows the red page behind the bar

      bottomNavigationBar: CurvedBottomNavBar(
        items: _items,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}




// curved_bottom_nav_bar.dart
//
// Reusable animated bottom navigation bar. A true cut-out notch (whatever is
// behind the bar shows through) glides to the selected item, carrying a
// floating circle with the active icon.
//
// Requires Flutter >= 3.0. No third-party packages.
//
// Usage:
//
//   Scaffold(
//     extendBody: true, // lets the notch show the page behind the bar
//     bottomNavigationBar: CurvedBottomNavBar(
//       currentIndex: _index,
//       onTap: (i) => setState(() => _index = i),
//       items: const [
//         CurvedNavItem(icon: Icons.grid_view_rounded, label: 'Home'),
//         CurvedNavItem(icon: Icons.format_list_bulleted_rounded, label: 'Tasks'),
//         CurvedNavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
//       ],
//     ),
//   );



/// One destination of [CurvedBottomNavBar].
class CurvedNavItem {
  const CurvedNavItem({
    required this.icon,
    this.activeIcon,
    this.label,
  });

  final IconData icon;

  /// Icon shown inside the floating circle. Falls back to [icon].
  final IconData? activeIcon;

  /// Used for accessibility (screen readers). Not drawn.
  final String? label;
}

class CurvedBottomNavBar extends StatelessWidget {
  const CurvedBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.height = 64,
    this.barColor = Colors.white,
    this.circleColor = Colors.white,
    this.selectedIconColor = const Color(0xFF111111),
    this.unselectedIconColor = const Color(0xFF9CA3AF),
    this.iconSize = 24,
    this.circleRadius = 28,
    this.notchDepth = 40,
    this.notchWidth = 112,
    this.circleGap = 6,
    this.cornerRadius = 0,
    this.elevation = 10,
    this.shadowColor = const Color(0x55000000),
    this.duration = const Duration(milliseconds: 450),
    this.curve = Curves.easeInOutCubic,
    this.enableHaptics = true,
    this.useSafeArea = true,
  })  : assert(items.length >= 2, 'Need at least 2 items'),
        assert(currentIndex >= 0 && currentIndex < items.length),
        assert(circleRadius > 0),
        assert(notchDepth > 0),
        assert(notchWidth > circleRadius * 2);

  final List<CurvedNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Height of the white bar (without safe-area inset).
  final double height;

  final Color barColor;
  final Color circleColor;
  final Color selectedIconColor;
  final Color unselectedIconColor;
  final double iconSize;

  /// Radius of the floating circle.
  final double circleRadius;

  /// How deep the notch cuts into the bar.
  final double notchDepth;

  /// Total width of the notch opening at the top edge of the bar.
  final double notchWidth;

  /// Gap between circle bottom and notch bottom.
  final double circleGap;

  /// Rounded top corners of the bar.
  final double cornerRadius;

  final double elevation;
  final Color shadowColor;

  /// Slide animation.
  final Duration duration;
  final Curve curve;

  final bool enableHaptics;

  /// Add bottom system inset (gesture bar / home indicator) to the bar.
  final bool useSafeArea;

  void _handleTap(int index) {
    if (index != currentIndex && enableHaptics) {
      HapticFeedback.selectionClick();
    }
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = useSafeArea ? MediaQuery.paddingOf(context).bottom : 0.0;

    // Room above the bar for the circle + shadow.
    final overflow = 2 * circleRadius - notchDepth + circleGap;
    final topInset = (overflow > 0 ? overflow : 0.0) + 6;

    final totalHeight = topInset + height + bottomInset;
    final circleTop = topInset + notchDepth - 2 * circleRadius - circleGap;

    return SizedBox(
      height: totalHeight,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final itemWidth = width / items.length;

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(end: currentIndex.toDouble()),
            duration: duration,
            curve: curve,
            builder: (context, pos, _) {
              final centerX = (pos + 0.5) * itemWidth;
              final shown = pos.round().clamp(0, items.length - 1);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Bar with cut-out notch.
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _NotchedBarPainter(
                        centerX: centerX,
                        topInset: topInset,
                        depth: notchDepth,
                        notchWidth: notchWidth,
                        cornerRadius: cornerRadius,
                        color: barColor,
                        shadowColor: shadowColor,
                        elevation: elevation,
                      ),
                    ),
                  ),

                  // 2. Floating circle that follows the notch.
                  Positioned(
                    left: centerX - circleRadius,
                    top: circleTop,
                    width: circleRadius * 2,
                    height: circleRadius * 2,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: circleColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: shadowColor,
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(
                                  scale: animation,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                ),
                            child: Icon(
                              items[shown].activeIcon ?? items[shown].icon,
                              key: ValueKey<int>(shown),
                              color: selectedIconColor,
                              size: iconSize,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. Tap targets + idle icons.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: topInset,
                    height: height,
                    child: Row(
                      children: List.generate(items.length, (i) {
                        // 0 at the notch, 1 once one slot away.
                        final distance = (pos - i).abs().clamp(0.0, 1.0);
                        final item = items[i];

                        return Expanded(
                          child: Semantics(
                            button: true,
                            selected: i == currentIndex,
                            label: item.label,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _handleTap(i),
                              child: Center(
                                child: Opacity(
                                  opacity: distance,
                                  child: Icon(
                                    item.icon,
                                    color: unselectedIconColor,
                                    size: iconSize,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _NotchedBarPainter extends CustomPainter {
  const _NotchedBarPainter({
    required this.centerX,
    required this.topInset,
    required this.depth,
    required this.notchWidth,
    required this.cornerRadius,
    required this.color,
    required this.shadowColor,
    required this.elevation,
  });

  final double centerX;
  final double topInset;
  final double depth;
  final double notchWidth;
  final double cornerRadius;
  final Color color;
  final Color shadowColor;
  final double elevation;

  @override
  void paint(Canvas canvas, Size size) {
    final top = topInset;
    final hw = notchWidth / 2;

    final bar = Path()
      ..addRRect(
        RRect.fromLTRBAndCorners(
          0,
          top,
          size.width,
          size.height,
          topLeft: Radius.circular(cornerRadius),
          topRight: Radius.circular(cornerRadius),
        ),
      );

    // Closed bowl shape. Subtracted from the bar => real cut-out.
    final notch = Path()
      ..moveTo(centerX - hw, top - 2)
      ..lineTo(centerX - hw, top)
      ..cubicTo(
        centerX - hw * 0.45, top,
        centerX - hw * 0.55, top + depth,
        centerX, top + depth,
      )
      ..cubicTo(
        centerX + hw * 0.55, top + depth,
        centerX + hw * 0.45, top,
        centerX + hw, top,
      )
      ..lineTo(centerX + hw, top - 2)
      ..close();

    final path = Path.combine(PathOperation.difference, bar, notch);

    if (elevation > 0) {
      canvas.drawShadow(path, shadowColor, elevation, false);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _NotchedBarPainter old) =>
      old.centerX != centerX ||
          old.topInset != topInset ||
          old.depth != depth ||
          old.notchWidth != notchWidth ||
          old.cornerRadius != cornerRadius ||
          old.color != color ||
          old.shadowColor != shadowColor ||
          old.elevation != elevation;
}





