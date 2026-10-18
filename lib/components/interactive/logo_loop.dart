// logo_loop.dart
//
// LogoLoop: an infinite, seamless marquee of logos / widgets. Scrolls
// horizontally (left / right) or vertically (up / down), eases to a stop (or
// to `hoverSpeed`) while hovered, optionally fades the edges and scales a
// logo under the cursor.
//
// Flutter port of the React `LogoLoop` component. Zero dependencies
// (Flutter SDK only), no Riverpod, no Overlay required.
//
// Requirements
// - Horizontal (default): needs a bounded width (or pass `width`). Height is
//   intrinsic (logoHeight, plus 20% when `scaleOnHover`). If you give it a
//   tight height, the track sticks to the top like the React version.
// - Vertical (`up` / `down`): needs a bounded height, the loop fills it. Width
//   is intrinsic unless `width` is set.
// - Content outside the widget bounds is clipped (React relies on the parent's
//   `overflow: hidden` for this).
//
// Behavior
// - Velocity eases toward the target with the same smoothing as React
//   (tau 0.25 s). The offset is wrapped modulo one sequence width, enough
//   copies are built to cover the viewport (+2 headroom).
// - Hover (mouse only) eases to `hoverSpeed`; `pauseOnHover` maps to 0.
// - Items with `href` or `onTap` are focusable links: Enter / Space activate,
//   focus ring only for keyboard focus, 0.8 opacity on hover.
// - Motion stops when animations are disabled (reduced motion) or a screen
//   reader is active; the loop then shows its first sequence, static.
// - The animation runs on a Ticker. Only the transform repaints per frame,
//   the widget tree is not rebuilt.

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Scroll direction of a [LogoLoop].
enum LogoLoopDirection {
  /// Content moves to the left (horizontal loop).
  left,

  /// Content moves to the right (horizontal loop).
  right,

  /// Content moves up (vertical loop).
  up,

  /// Content moves down (vertical loop).
  down,
}

/// Builds a custom item. Replaces the default image / node rendering (the
/// gap, text style and icon theme are still applied around it).
typedef LogoLoopItemBuilder = Widget Function(
    BuildContext context,
    LogoLoopItem item,
    int index,
    );

/// One entry of a [LogoLoop]. Provide exactly one of [node] or [image].
@immutable
class LogoLoopItem {
  const LogoLoopItem({
    this.node,
    this.image,
    this.alt,
    this.title,
    this.semanticLabel,
    this.href,
    this.onTap,
    this.width,
    this.height,
  }) : assert(
  (node != null) != (image != null),
  'Provide exactly one of `node` or `image`.',
  );

  /// Any widget, usually an [Icon]. Sized by the loop's icon theme
  /// (`size` = logoHeight) and colored by [LogoLoop.iconColor].
  final Widget? node;

  /// Image shown at `logoHeight`, width follows the aspect ratio.
  final ImageProvider? image;

  /// Accessibility text for [image] items.
  final String? alt;

  /// Fallback accessibility text (React `title`). No hover tooltip is shown.
  final String? title;

  /// Accessibility text for [node] items (React `ariaLabel`).
  final String? semanticLabel;

  /// Marks the item as a link. Flutter cannot open URLs without a package, so
  /// handle the tap in [onTap] or [LogoLoop.onItemTap] and use `href` there.
  final String? href;

  /// Called when the item is activated (tap, Enter, Space, screen reader).
  /// Giving it also makes the item a link.
  final VoidCallback? onTap;

  /// Intrinsic image width hint. With [height], reserves the aspect ratio
  /// while the image loads. Not used for sizing otherwise.
  final double? width;

  /// Intrinsic image height hint, see [width].
  final double? height;
}

const double _smoothTau = 0.25;
const int _minCopies = 2;
const int _copyHeadroom = 2;
const Cubic _scaleCurve = Cubic(0.4, 0, 0.2, 1);
const Duration _scaleDuration = Duration(milliseconds: 300);
const Duration _linkFade = Duration(milliseconds: 200);
const Color _fadeLight = Color(0xFFFFFFFF);
const Color _fadeDark = Color(0xFF0B0B0B);
const Map<ShortcutActivator, Intent> _activateKeys = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
};

/// Infinite logo marquee. See the file header for requirements.
class LogoLoop extends StatefulWidget {
  const LogoLoop({
    super.key,
    required this.logos,
    this.speed = 120,
    this.direction = LogoLoopDirection.left,
    this.width,
    this.logoHeight = 28,
    this.gap = 32,
    this.pauseOnHover,
    this.hoverSpeed,
    this.fadeOut = false,
    this.fadeOutColor,
    this.scaleOnHover = false,
    this.renderItem,
    this.semanticLabel = 'Partner logos',
    this.iconColor,
    this.textStyle,
    this.pauseOnFocus = true,
    this.onItemTap,
  });

  /// Items to loop.
  final List<LogoLoopItem> logos;

  /// Logical pixels per second. A negative value reverses the direction.
  final double speed;

  /// Scroll direction.
  final LogoLoopDirection direction;

  /// Fixed width in logical pixels. Null fills the available width
  /// (horizontal) or shrinks to the content (vertical).
  final double? width;

  /// Height of every logo, also the icon size and font size of [node]s.
  final double logoHeight;

  /// Space after each item.
  final double gap;

  /// Null or true: stop on hover (unless [hoverSpeed] is set).
  /// False: ignore hover.
  final bool? pauseOnHover;

  /// Speed while hovered. Overrides [pauseOnHover].
  final double? hoverSpeed;

  /// Fade the two ends of the loop into [fadeOutColor].
  final bool fadeOut;

  /// Edge fade color. Default: white, or #0B0B0B when the platform is dark.
  final Color? fadeOutColor;

  /// Scale the hovered logo to 1.2x (default rendering only).
  final bool scaleOnHover;

  /// Custom item renderer.
  final LogoLoopItemBuilder? renderItem;

  /// Accessibility label of the whole loop (React `ariaLabel`).
  final String semanticLabel;

  /// Color of icons, text and focus rings. Default: ambient [IconTheme]
  /// color, black if none (React inherits `currentColor`).
  final Color? iconColor;

  /// Text style merged over the default (`fontSize: logoHeight`, `height: 1`)
  /// for text inside [LogoLoopItem.node]s and custom items.
  final TextStyle? textStyle;

  /// Also ease to a stop while a link has keyboard focus (not in React).
  final bool pauseOnFocus;

  /// Called after [LogoLoopItem.onTap] when a link item is activated.
  final ValueChanged<LogoLoopItem>? onItemTap;

  @override
  State<LogoLoop> createState() => _LogoLoopState();
}

class _LogoLoopState extends State<LogoLoop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ValueNotifier<double> _offset = ValueNotifier<double>(0);
  final GlobalKey _seqKey = GlobalKey(debugLabel: 'LogoLoop sequence');
  late final Ticker _ticker = createTicker(_onTick);

  Duration? _last;
  double _velocity = 0;
  double _seq = 0;
  bool _hovered = false;
  int _focusedItems = 0;
  bool _still = false;
  bool _appActive = true;

  bool get _vertical =>
      widget.direction == LogoLoopDirection.up ||
          widget.direction == LogoLoopDirection.down;

  double get _targetVelocity {
    final w = widget;
    final dir = _vertical
        ? (w.direction == LogoLoopDirection.up ? 1 : -1)
        : (w.direction == LogoLoopDirection.left ? 1 : -1);
    return w.speed.abs() * dir * (w.speed < 0 ? -1 : 1);
  }

  double? get _hoverTarget {
    final w = widget;
    if (w.hoverSpeed != null) return w.hoverSpeed;
    if (w.pauseOnHover == false) return null;
    return 0;
  }

  // ---- lifecycle ----------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        (MediaQuery.maybeAccessibleNavigationOf(context) ?? false);
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant LogoLoop old) {
    super.didUpdateWidget(old);
    final w = widget;
    if (old.logos != w.logos ||
        old.gap != w.gap ||
        old.logoHeight != w.logoHeight ||
        old.scaleOnHover != w.scaleOnHover ||
        old.renderItem != w.renderItem ||
        old.textStyle != w.textStyle ||
        old.direction != w.direction) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden &&
        state != AppLifecycleState.detached;
    _syncTicker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _offset.dispose();
    super.dispose();
  }

  // ---- animation ----------------------------------------------------------

  void _syncTicker() {
    final run = !_still && _appActive;
    if (run && !_ticker.isActive) {
      _last = null;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
      _last = null;
      _velocity = 0;
    }
  }

  void _onTick(Duration elapsed) {
    final last = _last ?? elapsed;
    _last = elapsed;
    final dt = math.max(0, (elapsed - last).inMicroseconds) /
        Duration.microsecondsPerSecond;

    final hoverSpeed = _hoverTarget;
    var target = _targetVelocity;
    if (_hovered && hoverSpeed != null) {
      target = hoverSpeed;
    } else if (widget.pauseOnFocus && _focusedItems > 0) {
      target = hoverSpeed ?? 0;
    }

    final easing = 1 - math.exp(-dt / _smoothTau);
    _velocity += (target - _velocity) * easing;

    if (_seq > 0) {
      _offset.value = (_offset.value + _velocity * dt) % _seq;
    }
  }

  void _measure() {
    if (!mounted) return;
    final box = _seqKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final size = _vertical ? box.size.height : box.size.width;
    if (size > 0 && (size - _seq).abs() > 0.01) {
      setState(() => _seq = size);
      _offset.value = _offset.value % size;
    }
  }

  void _onItemFocus(bool focused) {
    _focusedItems = math.max(0, _focusedItems + (focused ? 1 : -1));
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final vertical = _vertical;
    final color = w.iconColor ?? IconTheme.of(context).color ?? const Color(0xFF000000);
    final fadeColor = w.fadeOutColor ??
        (MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark
            ? _fadeDark
            : _fadeLight);

    return LayoutBuilder(
      builder: (context, c) {
        var extent = vertical
            ? c.constrainHeight()
            : (w.width != null ? c.constrainWidth(w.width!) : c.constrainWidth());
        if (!extent.isFinite) extent = _seq;

        final copies = _seq > 0
            ? math.max(_minCopies, (extent / _seq).ceil() + _copyHeadroom)
            : _minCopies;

        final sequences = <Widget>[
          for (var i = 0; i < copies; i++) _buildSequence(i, color, vertical),
        ];
        final Widget track = vertical
            ? Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: sequences,
        )
            : Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sequences,
        );

        final pad = w.scaleOnHover ? w.logoHeight * 0.1 : 0.0;
        final moving = AnimatedBuilder(
          animation: _offset,
          child: RepaintBoundary(child: track),
          builder: (context, child) {
            final o = _still ? 0.0 : _offset.value;
            return Transform.translate(
              offset: vertical ? Offset(0, -o) : Offset(-o, 0),
              child: child,
            );
          },
        );

        final clipped = UnconstrainedBox(
          alignment: Alignment.topLeft,
          constrainedAxis: vertical ? Axis.horizontal : Axis.vertical,
          clipBehavior: Clip.hardEdge,
          child: Padding(
            padding: vertical
                ? EdgeInsets.symmetric(horizontal: pad)
                : EdgeInsets.symmetric(vertical: pad),
            child: moving,
          ),
        );

        final fadeSize = (extent * 0.08).clamp(24.0, 120.0).toDouble();
        Widget body = Stack(
          fit: StackFit.passthrough,
          children: [
            clipped,
            if (w.fadeOut) ...[
              _fadeEdge(fadeColor, fadeSize, vertical, true),
              _fadeEdge(fadeColor, fadeSize, vertical, false),
            ],
          ],
        );

        body = SizedBox(
          width: vertical ? w.width : extent,
          height: vertical ? extent : null,
          child: body,
        );

        return Semantics(
          container: true,
          explicitChildNodes: true,
          label: w.semanticLabel,
          child: MouseRegion(
            onEnter: (_) => _hovered = true,
            onExit: (_) => _hovered = false,
            child: NotificationListener<SizeChangedLayoutNotification>(
              onNotification: (_) {
                _measure();
                return true;
              },
              child: body,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSequence(int copy, Color color, bool vertical) {
    final w = widget;
    final items = <Widget>[
      for (var i = 0; i < w.logos.length; i++)
        _LogoItemView(
          key: ValueKey<int>(i),
          loop: w,
          item: w.logos[i],
          index: i,
          color: color,
          reduceMotion: _still,
          onFocusChanged: _onItemFocus,
        ),
    ];
    final Widget seq = vertical
        ? Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: items,
    )
        : Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: items,
    );
    if (copy == 0) {
      return SizeChangedLayoutNotifier(key: _seqKey, child: seq);
    }
    return ExcludeFocus(child: ExcludeSemantics(child: seq));
  }

  Widget _fadeEdge(Color color, double size, bool vertical, bool start) {
    // Transparent end uses the same color at alpha 0, which matches CSS
    // (premultiplied) interpolation instead of fading through grey.
    final clear = color.withValues(alpha: 0);
    final Alignment from;
    final Alignment to;
    if (vertical) {
      from = start ? Alignment.topCenter : Alignment.bottomCenter;
      to = start ? Alignment.bottomCenter : Alignment.topCenter;
    } else {
      from = start ? Alignment.centerLeft : Alignment.centerRight;
      to = start ? Alignment.centerRight : Alignment.centerLeft;
    }
    final gradient = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: from, end: to, colors: [color, clear]),
      ),
    );
    return Positioned(
      left: vertical || start ? 0 : null,
      right: vertical || !start ? 0 : null,
      top: !vertical || start ? 0 : null,
      bottom: !vertical || !start ? 0 : null,
      width: vertical ? null : size,
      height: vertical ? size : null,
      child: IgnorePointer(child: gradient),
    );
  }
}

/// One logo cell: gap, typography, hover scale, link and semantics.
class _LogoItemView extends StatefulWidget {
  const _LogoItemView({
    super.key,
    required this.loop,
    required this.item,
    required this.index,
    required this.color,
    required this.reduceMotion,
    required this.onFocusChanged,
  });

  final LogoLoop loop;
  final LogoLoopItem item;
  final int index;
  final Color color;
  final bool reduceMotion;
  final ValueChanged<bool> onFocusChanged;

  @override
  State<_LogoItemView> createState() => _LogoItemViewState();
}

class _LogoItemViewState extends State<_LogoItemView> {
  bool _hover = false;

  void _activate() {
    widget.item.onTap?.call();
    widget.loop.onItemTap?.call(widget.item);
  }

  Widget _image(LogoLoopItem item, double h) {
    final hasRatio = item.width != null && item.height != null && item.height! > 0;
    final image = Image(
      image: item.image!,
      height: hasRatio ? null : h,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => SizedBox(height: h),
    );
    if (!hasRatio) return image;
    return SizedBox(width: h * item.width! / item.height!, height: h, child: image);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.loop;
    final item = widget.item;
    final h = l.logoHeight;
    final custom = l.renderItem;
    final isNode = item.node != null;

    Widget content;
    if (custom != null) {
      content = custom(context, item, widget.index);
    } else {
      content = isNode ? item.node! : _image(item, h);
      if (l.scaleOnHover) {
        content = AnimatedScale(
          scale: _hover ? 1.2 : 1.0,
          duration: widget.reduceMotion ? Duration.zero : _scaleDuration,
          curve: _scaleCurve,
          child: content,
        );
      }
      final label = isNode ? (item.semanticLabel ?? item.title) : (item.alt ?? item.title);
      final hasLabel = label != null && label.isNotEmpty;
      final isLink = item.href != null || item.onTap != null;
      if (isLink) {
        content = Semantics(
          container: true,
          link: true,
          focusable: true,
          label: hasLabel ? label : 'logo link',
          onTap: _activate,
          excludeSemantics: true,
          child: _LinkBox(
            color: widget.color,
            onActivate: _activate,
            onFocusChanged: widget.onFocusChanged,
            child: content,
          ),
        );
      } else if (hasLabel) {
        content = Semantics(
          container: true,
          image: !isNode,
          label: label,
          excludeSemantics: true,
          child: content,
        );
      } else if (!isNode) {
        content = ExcludeSemantics(child: content);
      }
      if (l.scaleOnHover) {
        content = MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: content,
        );
      }
    }

    return Padding(
      padding: l.direction == LogoLoopDirection.up ||
          l.direction == LogoLoopDirection.down
          ? EdgeInsets.only(bottom: l.gap)
          : EdgeInsets.only(right: l.gap),
      child: DefaultTextStyle(
        style: TextStyle(
          color: widget.color,
          fontSize: h,
          height: 1,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ).merge(l.textStyle),
        child: IconTheme(
          data: IconThemeData(color: widget.color, size: h),
          child: content,
        ),
      ),
    );
  }
}

/// Link behavior: pointer cursor, 0.8 opacity on hover, Enter / Space,
/// 2 px focus ring (offset 2 px) for keyboard focus only.
class _LinkBox extends StatefulWidget {
  const _LinkBox({
    required this.child,
    required this.color,
    required this.onActivate,
    required this.onFocusChanged,
  });

  final Widget child;
  final Color color;
  final VoidCallback onActivate;
  final ValueChanged<bool> onFocusChanged;

  @override
  State<_LinkBox> createState() => _LinkBoxState();
}

class _LinkBoxState extends State<_LinkBox> {
  bool _hover = false;
  bool _ring = false;

  @override
  void dispose() {
    if (_ring) widget.onFocusChanged(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      shortcuts: _activateKeys,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onActivate();
            return null;
          },
        ),
      },
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) {
        setState(() => _ring = v);
        widget.onFocusChanged(v);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onActivate,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedOpacity(
              opacity: _hover ? 0.8 : 1,
              duration: _linkFade,
              curve: Curves.ease,
              child: widget.child,
            ),
            if (_ring)
              Positioned(
                left: -4,
                top: -4,
                right: -4,
                bottom: -4,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: widget.color, width: 2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}