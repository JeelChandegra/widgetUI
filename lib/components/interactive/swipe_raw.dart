// swipe_row.dart
//
// iOS-style swipe-to-reveal list row. Drag the row sideways to reveal action
// buttons. A long swipe past `commitAt` "commits" the primary (first) action:
// the primary block spreads across the whole row, the row flies off and then
// collapses to zero height, and `onCommit` fires.
//
// Flutter port of the React `SwipeRow` component. Zero dependencies.
//
// Notes
// - The row fills the available width. Give it a bounded width (ListView,
//   Column, SizedBox, ConstrainedBox...).
// - After `onCommit` the row stays collapsed. Remove it from your data, or
//   give it a new Key to bring it back.
// - Input: mouse, touch, keyboard (Left/Right arrows, Enter/Space toggle,
//   Esc closes, Delete/Backspace commits primary while open), and screen
//   reader custom actions (one per action).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

enum SwipeRowDirection {
  /// Swipe left to reveal actions on the right edge.
  left,

  /// Swipe right to reveal actions on the left edge.
  right,
}

/// One action in the drawer. The first action in the list is the primary
/// (full-swipe / commit) action.
@immutable
class SwipeRowAction {
  const SwipeRowAction({
    required this.id,
    required this.label,
    this.icon,
    this.color,
    this.dismiss = false,
    this.onSelect,
  });

  final String id;
  final String label;

  /// Icon above the label. Primary action defaults to a trash icon.
  final Widget? icon;

  /// Background of a secondary action. Defaults to `drawerColor`.
  /// (The primary action always uses `actionColor`.)
  final Color? color;

  /// A secondary action with `dismiss: true` also removes the row
  /// (fly off + collapse + `onCommit`), like the primary action does.
  final bool dismiss;

  /// Called when this action is chosen (after `onAction`).
  final VoidCallback? onSelect;
}

enum _Phase { idle, committing, collapsing }

const double _flick = 110;
const double _vmax = 1500;
const double _decel = 0.998;
const Cubic _easeOut = Cubic(0.23, 1, 0.32, 1);

final SpringDescription _springUi =
SpringDescription.withDurationAndBounce(duration:  Duration(milliseconds: 300), bounce: 0);

double _rubber(double o, double dim, double c) =>
    (o * dim * c) / (dim + c * o.abs());

double _unrubber(double y, double dim, double c) =>
    (y * dim) / (c * math.max(1, dim - y.abs()));

double _project(double v) => (v / 1000) * _decel / (1 - _decel);

Color _onColor(Color bg) {
  final lum = (bg.r * 255 * 299 + bg.g * 255 * 587 + bg.b * 255 * 114) / 1000;
  return lum >= 150 ? const Color(0xFF111111) : Colors.white;
}

class SwipeRow extends StatefulWidget {
  const SwipeRow({
    super.key,
    required this.child,
    this.actions = const [SwipeRowAction(id: 'delete', label: 'Delete')],
    this.actionColor = const Color(0xFFE5484D),
    this.drawerColor = const Color(0xFF3F3F46),
    this.rowColor = const Color(0xFF27272A),
    this.textColor = const Color(0xFFF5F5F5),
    this.height = 64,
    this.radius = 16,
    this.actionWidth = 80,
    this.direction = SwipeRowDirection.left,
    this.snapBounce = 0.2,
    this.resistance = 0.55,
    this.collapse = const Duration(milliseconds: 200),
    this.commitAt = 0.6,
    this.fullSwipe = true,
    this.enabled = true,
    this.open,
    this.onOpenChange,
    this.onAction,
    this.onCommit,
    this.closeOnAction = true,
    this.haptic = true,
    this.label = 'List item',
    this.spacing = 0,
  });

  /// Row content. Laid out in a padded Row, vertically centered.
  final Widget child;

  final List<SwipeRowAction> actions;

  /// Background of the primary action / full-swipe block.
  final Color actionColor;

  /// Background behind secondary actions.
  final Color drawerColor;
  final Color rowColor;
  final Color textColor;

  final double height;
  final double radius;

  /// Width of one action button.
  final double actionWidth;
  final SwipeRowDirection direction;

  /// Bounce of the snap spring after a flick (0 = none).
  final double snapBounce;

  /// 0.05 - 1. Lower = heavier rubber-band resistance.
  final double resistance;

  /// Duration of the height collapse after commit.
  final Duration collapse;

  /// Fraction of the row width past which release commits the primary action.
  final double commitAt;

  /// Enable the long-swipe commit.
  final bool fullSwipe;
  final bool enabled;

  /// Controlled open state. Leave null for uncontrolled.
  final bool? open;
  final ValueChanged<bool>? onOpenChange;

  /// Fired when any action is chosen.
  final ValueChanged<SwipeRowAction>? onAction;

  /// Fired after the row has flown off and collapsed. Remove the item here.
  final ValueChanged<SwipeRowAction>? onCommit;

  /// Close the drawer after choosing a non-dismissing action.
  final bool closeOnAction;

  /// Light haptic tick when the full-swipe threshold is crossed (touch only).
  final bool haptic;

  /// Accessibility label for the row.
  final String label;

  /// Space below the row. Collapses together with the row.
  final double spacing;

  @override
  State<SwipeRow> createState() => _SwipeRowState();
}

class _SwipeRowState extends State<SwipeRow> with TickerProviderStateMixin {
  late final AnimationController _x = AnimationController.unbounded(vsync: this);
  late final AnimationController _spread = AnimationController(vsync: this);
  late final AnimationController _landed = AnimationController(vsync: this);
  final FocusNode _focus = FocusNode(debugLabel: 'SwipeRow');
  final Stopwatch _clock = Stopwatch()..start();

  _Phase _phase = _Phase.idle;
  bool _openState = false;
  String _say = '';
  double _w = 360;

  double? _grab; // non-null while a drag is active
  bool _touch = false;
  bool _dragging = false;
  bool _spreadOn = false;
  double? _heading; // target the row is currently animating to
  final List<(int, double)> _hist = [];

  Timer? _foldTimer;
  bool _reduce = false;
  bool _focused = false;

  // ---- derived ------------------------------------------------------------

  double get _s => widget.direction == SwipeRowDirection.left ? -1 : 1;
  double get _a => widget.actionWidth;
  int get _n => widget.actions.length;
  double get _d => _n * _a;
  double get _c => widget.resistance.clamp(0.05, 1.0).toDouble();
  SwipeRowAction? get _primary =>
      widget.actions.isEmpty ? null : widget.actions.first;
  bool get _isOpen => widget.open ?? _openState;
  double get _exposed => _s * _x.value;
  double get _commitPoint => math.max(widget.commitAt * _w, _d + _a / 2);
  bool get _canCommit => widget.fullSwipe && _n > 0 && _commitPoint <= _w;

  double _map(double raw) {
    final W = _w, c = _c, D = _d;
    if (raw < 0) return _rubber(raw, W, c);
    if (raw <= D) return raw;
    if (!_canCommit) return D + _rubber(raw - D, W, c);
    final C = _commitPoint;
    final knee = D + (C - D) / c;
    return raw <= knee ? D + c * (raw - D) : C + _rubber(raw - knee, W, c);
  }

  double _inv(double ex) {
    final W = _w, c = _c, D = _d;
    if (ex < 0) return _unrubber(ex, W, c);
    if (ex <= D) return ex;
    if (!_canCommit) return D + _unrubber(ex - D, W, c);
    final C = _commitPoint;
    final knee = D + (C - D) / c;
    return ex <= C ? D + (ex - D) / c : knee + _unrubber(ex - C, W, c);
  }

  // ---- lifecycle ----------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _openState = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(covariant SwipeRow old) {
    super.didUpdateWidget(old);
    if (widget.open != null &&
        (widget.open != old.open || widget.actions.length != old.actions.length) &&
        _phase == _Phase.idle &&
        !_dragging) {
      final target = _isOpen ? _d : 0.0;
      if (_heading != target && (_exposed - target).abs() > 0.5) {
        _settle(target);
      }
    }
  }

  @override
  void dispose() {
    _foldTimer?.cancel();
    _x.dispose();
    _spread.dispose();
    _landed.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---- motion -------------------------------------------------------------

  void _setOpen(bool next) {
    if (next == _isOpen) return;
    setState(() => _openState = next);
    widget.onOpenChange?.call(next);
  }

  void _settle(double target, [double v = 0]) {
    _heading = target;
    final to = _s * target;
    if (_reduce) {
      _x.animateTo(to, duration: const Duration(milliseconds: 200), curve: _easeOut);
      return;
    }
    final flick = v.abs() >= _flick;
    final spring = flick
        ? SpringDescription.withDurationAndBounce(
      duration: const Duration(milliseconds: 300),
      bounce: widget.snapBounce,
    )
        : _springUi;
    final vel = _s * (flick ? v.clamp(-_vmax, _vmax).toDouble() : v);
    _x.animateWith(SpringSimulation(spring, _x.value, to, vel));
  }

  void _animSpring(AnimationController c, double to) {
    c.animateWith(SpringSimulation(_springUi, c.value, to, 0));
  }

  void _setSpread(bool on) {
    if (_spreadOn == on) return;
    _spreadOn = on;
    if (_reduce) {
      _spread.value = on ? 1 : 0;
    } else {
      _animSpring(_spread, on ? 1 : 0);
    }
    if (on && _primary != null) {
      setState(() => _say = 'Release to ${_primary!.label}');
      if (widget.haptic && _touch) HapticFeedback.selectionClick();
    }
  }

  void _commit(SwipeRowAction a, {bool viaKey = false, double v = 0}) {
    final leap = identical(a, _primary);
    setState(() {
      _phase = _Phase.committing;
      _say = a.label;
    });
    _setOpen(false);

    void fold() {
      if (!mounted) return;
      setState(() => _phase = _Phase.collapsing);
      _foldTimer = Timer(widget.collapse, () {
        if (!mounted) return;
        widget.onCommit?.call(a);
        a.onSelect?.call();
      });
    }

    final end = _s * _w;
    if (viaKey || _reduce) {
      if (leap) {
        _spread.value = 1;
        _landed.value = 1;
      }
      if (viaKey) {
        _x.value = end;
        fold();
      } else {
        _x
            .animateTo(end,
            duration: const Duration(milliseconds: 200), curve: _easeOut)
            .whenComplete(fold);
      }
      return;
    }
    if (leap) {
      if (_spread.value < 1) _animSpring(_spread, 1);
      _animSpring(_landed, 1);
    }
    _x
        .animateWith(SpringSimulation(_springUi, _x.value, end, _s * v))
        .whenComplete(fold);
  }

  // ---- drag ---------------------------------------------------------------

  void _onDown(DragDownDetails d) {
    if (!widget.enabled || _n == 0 || _phase != _Phase.idle) return;
    _x.stop();
    _heading = null;
  }

  void _onStart(DragStartDetails d) {
    if (!widget.enabled || _n == 0 || _phase != _Phase.idle) {
      _grab = null;
      return;
    }
    _x.stop();
    _heading = null;
    _touch = d.kind == PointerDeviceKind.touch;
    _hist.clear();
    _grab = _s * d.globalPosition.dx - _inv(_exposed);
    setState(() => _dragging = true);
  }

  void _onUpdate(DragUpdateDetails d) {
    final g = _grab;
    if (g == null) return;
    final ex = _map(_s * d.globalPosition.dx - g);
    _x.value = _s * ex;
    _hist.add((_clock.elapsedMilliseconds, ex));
    if (_hist.length > 4) _hist.removeAt(0);
    _setSpread(_canCommit && ex >= _commitPoint);
  }

  double _velocity() {
    if (_hist.length < 2) return 0;
    if (_clock.elapsedMilliseconds - _hist.last.$1 > 80) return 0;
    final a = _hist.first, b = _hist.last;
    return (b.$2 - a.$2) / math.max(1, b.$1 - a.$1) * 1000;
  }

  void _onEnd(DragEndDetails d) {
    if (_grab == null) return;
    _grab = null;
    setState(() => _dragging = false);
    final ex = _exposed;
    final v = _velocity();
    final p = _primary;
    if (p != null && _canCommit && ex >= _commitPoint) {
      _commit(p, v: v);
      return;
    }
    final D = _d;
    final target = v.abs() >= _flick
        ? (v > 0 ? D : 0.0)
        : (ex + _project(v) > D / 2 ? D : 0.0);
    _setSpread(false);
    _setOpen(target == D && D > 0);
    _settle(target, v);
  }

  void _onCancel() {
    if (_grab != null) {
      _grab = null;
      setState(() => _dragging = false);
      _setSpread(false);
      final target = _exposed > _d / 2 ? _d : 0.0;
      _setOpen(target == _d && _d > 0);
      _settle(target);
    } else if (_heading == null && _phase == _Phase.idle) {
      _settle(_isOpen ? _d : 0);
    }
  }

  void _onTap() {
    if (_phase != _Phase.idle || !_isOpen) return;
    _setOpen(false);
    _settle(0);
  }

  // ---- actions / keyboard -------------------------------------------------

  void _act(SwipeRowAction a, {bool viaKey = false}) {
    if (_phase != _Phase.idle) return;
    widget.onAction?.call(a);
    if (identical(a, _primary) || a.dismiss) {
      _commit(a, viaKey: viaKey);
      return;
    }
    a.onSelect?.call();
    if (!widget.closeOnAction) return;
    _setOpen(false);
    if (viaKey) {
      _heading = 0;
      _x.value = 0;
    } else {
      _settle(0);
    }
  }

  void _openNow() {
    _heading = _d;
    _x.value = _s * _d;
    _setOpen(true);
    setState(() => _say = '$_n actions revealed');
  }

  void _closeNow() {
    _heading = 0;
    _x.value = 0;
    _setOpen(false);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    if (!widget.enabled || _phase != _Phase.idle || _n == 0) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    final left = _s < 0;
    final openKey =
    left ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight;
    final closeKey =
    left ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft;
    final toggle =
        k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space;
    final open = _isOpen;

    if (k == openKey || (toggle && !open)) {
      _openNow();
      return KeyEventResult.handled;
    }
    if (k == closeKey || k == LogicalKeyboardKey.escape || (toggle && open)) {
      _closeNow();
      return KeyEventResult.handled;
    }
    if ((k == LogicalKeyboardKey.delete || k == LogicalKeyboardKey.backspace) &&
        open &&
        _primary != null &&
        _canCommit) {
      _commit(_primary!, viaKey: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final collapsing = _phase == _Phase.collapsing;
    final total = w.height + w.spacing;

    return LayoutBuilder(
      builder: (context, cons) {
        _w = (cons.hasBoundedWidth && cons.maxWidth.isFinite)
            ? cons.maxWidth
            : 360;
        return AnimatedContainer(
          duration: w.collapse,
          curve: _easeOut,
          height: collapsing ? 0 : total,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: total,
              child: AnimatedOpacity(
                opacity: collapsing ? 0 : 1,
                duration: w.collapse,
                curve: _easeOut,
                child: Padding(
                  padding: EdgeInsets.only(bottom: w.spacing),
                  child: _buildRow(context),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRow(BuildContext context) {
    final w = widget;
    final s = _s, A = _a, D = _d;
    final primary = _primary;
    final left = s < 0;
    final showRing = _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

    final stack = AnimatedBuilder(
      animation: Listenable.merge([_x, _spread, _landed]),
      builder: (context, _) {
        final x = _x.value;
        final e = s * x;
        final shift = _spread.value * math.max(0, e - A);
        final landed = _landed.value;
        final open = _isOpen;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // ---- drawer rail (under the surface) ----
            Positioned.fill(
              child: ExcludeFocus(
                excluding: !open,
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    ignoring: !open,
                    child: Transform.translate(
                      offset: Offset(-s * math.max(0, D - e), 0),
                      child: ColoredBox(
                        color: w.drawerColor,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (var i = 1; i < _n; i++)
                              Positioned(
                                top: 0,
                                bottom: 0,
                                width: A,
                                right: left ? i * A : null,
                                left: left ? null : i * A,
                                child: _SecondaryAction(
                                  action: w.actions[i],
                                  drawerColor: w.drawerColor,
                                  onTap: () => _act(w.actions[i]),
                                ),
                              ),
                            if (primary != null)
                              Positioned(
                                top: 0,
                                bottom: 0,
                                width: _w,
                                left: left ? _w - A : null,
                                right: left ? null : _w - A,
                                child: Transform.translate(
                                  offset: Offset(s * shift, 0),
                                  child: ColoredBox(
                                    color: w.actionColor,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned(
                                          top: 0,
                                          bottom: 0,
                                          width: A,
                                          left: left ? 0 : null,
                                          right: left ? null : 0,
                                          child: Transform.translate(
                                            offset: Offset(
                                              -s *
                                                  landed *
                                                  (shift - (_w - A) / 2),
                                              0,
                                            ),
                                            child: _ActionButton(
                                              foreground:
                                              _onColor(w.actionColor),
                                              icon: primary.icon ??
                                                  const Icon(Icons
                                                      .delete_outline_rounded),
                                              label: primary.label,
                                              onTap: () => _act(primary),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ---- sliding surface ----
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(x, 0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragDown: _onDown,
                  onHorizontalDragStart: _onStart,
                  onHorizontalDragUpdate: _onUpdate,
                  onHorizontalDragEnd: _onEnd,
                  onHorizontalDragCancel: _onCancel,
                  onTap: _onTap,
                  child: MouseRegion(
                    cursor: _dragging
                        ? SystemMouseCursors.grabbing
                        : SystemMouseCursors.grab,
                    child: ColoredBox(
                      color: w.rowColor,
                      child: DefaultTextStyle.merge(
                        style: TextStyle(color: w.textColor),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: Padding(
                                padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [Expanded(child: w.child)],
                                ),
                              ),
                            ),
                            if (showRing && _n > 0)
                              Positioned(
                                top: 0,
                                bottom: 0,
                                right: left ? 12 : null,
                                left: left ? null : 12,
                                child: Center(
                                  child: Container(
                                    height: 24,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: w.textColor
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$_n ${_n == 1 ? 'action' : 'actions'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1,
                                        color: w.textColor,
                                        decoration: TextDecoration.none,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // screen-reader announcements
            Positioned(
              left: 0,
              top: 0,
              width: 0,
              height: 0,
              child: Semantics(
                liveRegion: true,
                label: _say,
                child: const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );

    return Semantics(
      container: true,
      label: w.label,
      customSemanticsActions: {
        for (final a in w.actions)

          CustomSemanticsAction(label: a.label): () => _act(a, viaKey: true),
      },
      child: Focus(
        focusNode: _focus,
        canRequestFocus: w.enabled && _n > 0,
        onKeyEvent: _onKey,
        onFocusChange: (f) => setState(() => _focused = f),
        child: Opacity(
          opacity: w.enabled ? 1 : 0.55,
          child: IgnorePointer(
            ignoring: !w.enabled,
            child: SizedBox(
              height: w.height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(w.radius),
                child: ColoredBox(color: w.rowColor, child: stack),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary (non-commit) drawer button.
class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.action,
    required this.drawerColor,
    required this.onTap,
  });

  final SwipeRowAction action;
  final Color drawerColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = action.color ?? drawerColor;
    return ColoredBox(
      color: bg,
      child: _ActionButton(
        foreground: _onColor(bg),
        icon: action.icon,
        label: action.label,
        onTap: onTap,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.foreground,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color foreground;
  final Widget? icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hover = Colors.white.withValues(alpha: 0.08);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        hoverColor: hover,
        focusColor: hover,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Center(
          child: DefaultTextStyle(
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.11,
              height: 1,
              color: foreground,
              decoration: TextDecoration.none,
            ),
            child: IconTheme(
              data: IconThemeData(color: foreground, size: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(height: 4)],
                  Text(label, maxLines: 1, softWrap: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}