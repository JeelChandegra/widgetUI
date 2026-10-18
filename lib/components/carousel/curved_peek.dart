// curved_peek_carousel.dart
//
// A reusable, animated carousel: one focused item in the center, neighbours
// peeking from both sides, lifted + tilted to form a curved "arc".
//
// Requires Flutter >= 3.27 (uses Color.withValues). No third-party packages.
//
// Usage:
//
//   final controller = CurvedPeekCarouselController();
//
//   CurvedPeekCarousel(
//     controller: controller,
//     itemCount: items.length,
//     height: 400,
//     autoPlay: true,
//     itemBuilder: (context, index) => MyCard(item: items[index]),
//     onPageChanged: (i) => debugPrint('page $i'),
//   );

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Builds the indicator shown under the carousel.
typedef CurvedPeekIndicatorBuilder = Widget Function(
    BuildContext context,
    int itemCount,
    int currentIndex,
    );

/// Imperative handle for [CurvedPeekCarousel].
class CurvedPeekCarouselController {
  _CurvedPeekCarouselState? _state;

  bool get isAttached => _state != null;

  /// Currently focused item index.
  int get currentIndex => _state?._currentIndex ?? 0;

  Future<void> animateTo(
      int index, {
        Duration duration = const Duration(milliseconds: 450),
        Curve curve = Curves.easeOutCubic,
      }) async {
    final state = _state;
    if (state == null || !state._pageController.hasClients) return;
    await state._pageController.animateToPage(
      index.clamp(0, state.widget.itemCount - 1),
      duration: duration,
      curve: curve,
    );
  }

  void jumpTo(int index) {
    final state = _state;
    if (state == null || !state._pageController.hasClients) return;
    state._pageController.jumpToPage(index.clamp(0, state.widget.itemCount - 1));
  }

  Future<void> next({
    Duration duration = const Duration(milliseconds: 450),
    Curve curve = Curves.easeOutCubic,
  }) =>
      animateTo(currentIndex + 1, duration: duration, curve: curve);

  Future<void> previous({
    Duration duration = const Duration(milliseconds: 450),
    Curve curve = Curves.easeOutCubic,
  }) =>
      animateTo(currentIndex - 1, duration: duration, curve: curve);
}

class CurvedPeekCarousel extends StatefulWidget {
  const CurvedPeekCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.height = 380,
    this.initialIndex = 0,
    this.viewportFraction = 0.78,
    this.itemSpacing = 8,
    this.lift = 50,
    this.tilt = 0.12,
    this.minScale = 0.85,
    this.minOpacity = 0.6,
    this.physics = const BouncingScrollPhysics(),
    this.clipBehavior = Clip.none,
    this.enableTapToFocus = true,
    this.enableHaptics = false,
    this.onPageChanged,
    this.autoPlay = false,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.autoPlayDuration = const Duration(milliseconds: 600),
    this.autoPlayCurve = Curves.easeInOutCubic,
    this.showIndicator = true,
    this.indicatorSpacing = 20,
    this.indicatorBuilder,
    this.indicatorActiveColor,
    this.indicatorInactiveColor,
  })  : assert(itemCount >= 0),
        assert(viewportFraction > 0 && viewportFraction <= 1),
        assert(minScale > 0 && minScale <= 1),
        assert(minOpacity >= 0 && minOpacity <= 1),
        assert(initialIndex >= 0);

  /// Number of items.
  final int itemCount;

  /// Builds each item. Built once per index, animation applied around it.
  final IndexedWidgetBuilder itemBuilder;

  /// Optional controller for next / previous / animateTo.
  final CurvedPeekCarouselController? controller;

  /// Height of the carousel area. Leave room for [lift] so nothing clips.
  final double height;

  final int initialIndex;

  /// Fraction of width the focused item takes. Lower = more peek.
  final double viewportFraction;

  /// Horizontal gap added around each item.
  final double itemSpacing;

  /// How far (logical px) side items rise above the center item.
  final double lift;

  /// Outward rotation (radians) of side items. 0 = no tilt.
  final double tilt;

  /// Scale of fully off-center items. 1 = no scaling.
  final double minScale;

  /// Opacity of fully off-center items. 1 = no fade.
  final double minOpacity;

  final ScrollPhysics physics;

  /// Keep [Clip.none] so lifted / tilted items are not cut off.
  final Clip clipBehavior;

  /// Tap a side item to bring it to center.
  final bool enableTapToFocus;

  /// Light haptic tick when focused item changes.
  final bool enableHaptics;

  final ValueChanged<int>? onPageChanged;

  final bool autoPlay;
  final Duration autoPlayInterval;
  final Duration autoPlayDuration;
  final Curve autoPlayCurve;

  final bool showIndicator;
  final double indicatorSpacing;

  /// Replace the default pill indicator.
  final CurvedPeekIndicatorBuilder? indicatorBuilder;
  final Color? indicatorActiveColor;
  final Color? indicatorInactiveColor;

  @override
  State<CurvedPeekCarousel> createState() => _CurvedPeekCarouselState();
}

class _CurvedPeekCarouselState extends State<CurvedPeekCarousel> {
  late PageController _pageController;
  late int _currentIndex;
  Timer? _autoPlayTimer;
  bool _userInteracting = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = _safeInitialIndex();
    _pageController = _createController();
    widget.controller?._state = this;
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant CurvedPeekCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }

    if (oldWidget.viewportFraction != widget.viewportFraction) {
      _pageController.dispose();
      _pageController = _createController();
    }

    if (_currentIndex >= widget.itemCount && widget.itemCount > 0) {
      _currentIndex = widget.itemCount - 1;
    }

    if (oldWidget.autoPlay != widget.autoPlay ||
        oldWidget.autoPlayInterval != widget.autoPlayInterval) {
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    widget.controller?._state = null;
    _pageController.dispose();
    super.dispose();
  }

  int _safeInitialIndex() {
    if (widget.itemCount == 0) return 0;
    return widget.initialIndex.clamp(0, widget.itemCount - 1);
  }

  PageController _createController() => PageController(
    viewportFraction: widget.viewportFraction,
    initialPage: _currentIndex,
  );

  double get _page {
    if (_pageController.hasClients && _pageController.position.haveDimensions) {
      return _pageController.page ?? _currentIndex.toDouble();
    }
    return _currentIndex.toDouble();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (!widget.autoPlay || widget.itemCount < 2) return;

    _autoPlayTimer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted || _userInteracting || !_pageController.hasClients) return;
      final next = (_currentIndex + 1) % widget.itemCount;
      _pageController.animateToPage(
        next,
        duration: widget.autoPlayDuration,
        curve: widget.autoPlayCurve,
      );
    });
  }

  void _handlePageChanged(int index) {
    if (widget.enableHaptics) HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    widget.onPageChanged?.call(index);
  }

  bool _handleScroll(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _userInteracting = true;
    } else if (n is ScrollEndNotification) {
      _userInteracting = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return SizedBox(height: widget.height);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScroll,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.itemCount,
              physics: widget.physics,
              clipBehavior: widget.clipBehavior,
              onPageChanged: _handlePageChanged,
              itemBuilder: (context, index) {
                // Built once; only the transform wrapper updates per frame.
                final child = Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.itemSpacing),
                  child: widget.itemBuilder(context, index),
                );

                return AnimatedBuilder(
                  animation: _pageController,
                  child: child,
                  builder: (context, child) {
                    final page = _page;
                    final signed = (index - page).clamp(-1.0, 1.0);
                    final distance = signed.abs();

                    final scale = 1 - distance * (1 - widget.minScale);
                    final opacity = 1 - distance * (1 - widget.minOpacity);

                    Widget item = child!;

                    if (widget.enableTapToFocus && page.round() != index) {
                      item = GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                        ),
                        child: AbsorbPointer(child: item),
                      );
                    }

                    return Center(
                      child: Transform.translate(
                        offset: Offset(0, -distance * widget.lift),
                        child: Transform.rotate(
                          angle: signed * widget.tilt,
                          child: Transform.scale(
                            scale: scale,
                            child: Opacity(opacity: opacity, child: item),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        if (widget.showIndicator) ...[
          SizedBox(height: widget.indicatorSpacing),
          widget.indicatorBuilder?.call(
            context,
            widget.itemCount,
            _currentIndex,
          ) ??
              _PillIndicator(
                count: widget.itemCount,
                current: _currentIndex,
                activeColor: widget.indicatorActiveColor ??
                    Theme.of(context).colorScheme.primary,
                inactiveColor: widget.indicatorInactiveColor ??
                    Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.25),
              ),
        ],
      ],
    );
  }
}

class _PillIndicator extends StatelessWidget {
  const _PillIndicator({
    required this.count,
    required this.current,
    required this.activeColor,
    required this.inactiveColor,
  });

  final int count;
  final int current;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}



/// Self-contained demo of [CurvedPeekCarousel] for use as a ComponentTile preview.
/// Owns its own controller + data, so no outside state is needed.
class CurvedPeekCarouselPreview extends StatefulWidget {
  const CurvedPeekCarouselPreview({
    super.key,
    this.height = 180,
    this.autoPlay = true,
  });

  final double height;
  final bool autoPlay;

  @override
  State<CurvedPeekCarouselPreview> createState() =>
      _CurvedPeekCarouselPreviewState();
}

class _CurvedPeekCarouselPreviewState extends State<CurvedPeekCarouselPreview> {
  final CurvedPeekCarouselController _controller =
  CurvedPeekCarouselController();

  static const List<_PreviewItem> _items = [
    _PreviewItem('Design', Icons.brush_rounded,
        [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
    _PreviewItem('Backend', Icons.storage_rounded,
        [Color(0xFF0EA5E9), Color(0xFF14B8A6)]),
    _PreviewItem('Frontend', Icons.widgets_rounded,
        [Color(0xFFF97316), Color(0xFFEF4444)]),
    _PreviewItem('Testing', Icons.bug_report_rounded,
        [Color(0xFFEC4899), Color(0xFFF43F5E)]),
    _PreviewItem('Release', Icons.rocket_launch_rounded,
        [Color(0xFF22C55E), Color(0xFF16A34A)]),
  ];

  @override
  Widget build(BuildContext context) {
    return CurvedPeekCarousel(
      controller: _controller,
      itemCount: _items.length,
      initialIndex: 1,
      height: widget.height,
      viewportFraction: 0.45, // 0.2 = too small, side cards barely visible
      itemSpacing: 2,
      lift: 24,
      tilt: 0.1,
      minScale: 0.85,
      minOpacity: 0.6,
      showIndicator: false,
      autoPlay: widget.autoPlay,
      autoPlayInterval: const Duration(seconds: 3),
      itemBuilder: (context, index) => _PreviewCard(item: _items[index]),
    );
  }
}

class _PreviewItem {
  const _PreviewItem(this.title, this.icon, this.colors);

  final String title;
  final IconData icon;
  final List<Color> colors;
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.item});

  final _PreviewItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: item.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: Colors.white, size: 26),
          const Spacer(),
          Text(
            item.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}