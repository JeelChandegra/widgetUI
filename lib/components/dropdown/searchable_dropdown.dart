// premium_dropdown.dart
//
// A polished, reusable dropdown with search for Flutter.
//
// Requires Flutter 3.27+ (OverlayPortal, Color.withValues, PopScope).
// Pure Flutter: no packages, and the widget never does networking itself.
//
// ── Quick start ───────────────────────────────────────────────────────────
//
// Static list:
//   PremiumDropdown<String>(
//     label: 'Country',
//     items: const [
//       DropdownItem(value: 'in', label: 'India', subtitle: 'Asia'),
//       DropdownItem(value: 'us', label: 'United States'),
//     ],
//     selected: _country,
//     onChanged: (item) => setState(() => _country = item),
//   )
//
// API list (loaded once on first open, searched locally):
//   PremiumDropdown<int>(
//     loader: (_) async => (await api.users()).map((u) =>
//         DropdownItem(value: u.id, label: u.name)).toList(),
//   )
//
// API with server-side search (called for every debounced query):
//   PremiumDropdown<int>(
//     remoteSearch: true,
//     loader: (q) async => (await api.search(q)).map((c) =>
//         DropdownItem(value: c.id, label: c.name)).toList(),
//   )
//
// Inside a Form:
//   PremiumDropdown<String>(
//     items: ...,
//     validator: (item) => item == null ? 'Please choose one' : null,
//   )

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

// ════════════════════════════════════════════════════════════════════════════
// Model
// ════════════════════════════════════════════════════════════════════════════

/// One selectable option.
///
/// Two items are equal when [value], [label], [subtitle] and [enabled] match,
/// so it is safe to create items inline on every build.
@immutable
class DropdownItem<T> {
  const DropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.enabled = true,
  });

  /// Identifies the item. Needs a proper `==` (ints, strings, enums, ids).
  final T value;

  final String label;
  final String? subtitle;

  /// Optional avatar / flag / icon shown before the label.
  /// Keep it around 40 px or smaller so it fits the row.
  final Widget? leading;

  final bool enabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is DropdownItem<T> &&
              other.value == value &&
              other.label == label &&
              other.subtitle == subtitle &&
              other.enabled == enabled;

  @override
  int get hashCode => Object.hash(value, label, subtitle, enabled);
}

/// Your API call. Receives the current search text ('' when nothing typed).
/// Throw to show the error state with a retry button.
typedef DropdownLoader<T> = Future<List<DropdownItem<T>>> Function(String query);

enum _Phase { loading, error, ready }

// ════════════════════════════════════════════════════════════════════════════
// Widget
// ════════════════════════════════════════════════════════════════════════════

/// A polished dropdown with search.
///
/// Data modes:
/// * **Static**: pass [items].
/// * **API**: pass [loader]. It is called on first open and the result is
///   cached and searched locally. Set [remoteSearch] to call it again for
///   every (debounced) query so the server does the filtering. Set
///   [reloadOnOpen] to refetch each time the menu opens.
///
/// Works standalone or inside a [Form] ([validator], [autovalidateMode],
/// `FormState.reset()` / `validate()` all work).
///
/// [selected] works controlled (parent updates it from [onChanged]) or
/// uncontrolled (the widget remembers the choice itself).
class PremiumDropdown<T> extends StatefulWidget {
  const PremiumDropdown({
    super.key,
    this.items,
    this.loader,
    this.selected,
    this.onChanged,
    this.label,
    this.hint = 'Select an option',
    this.helperText,
    this.errorText,
    this.validator,
    this.autovalidateMode,
    this.searchable = true,
    this.searchHint = 'Search…',
    this.remoteSearch = false,
    this.reloadOnOpen = false,
    this.debounce = const Duration(milliseconds: 350),
    this.clearable = true,
    this.enabled = true,
    this.maxMenuHeight = 340,
    this.itemHeight = 56,
    this.accentColor,
    this.borderRadius = 16,
    this.fieldHeight = 56,
    this.emptyText = 'No results found',
    this.loadErrorText = "Couldn't load options",
    this.retryText = 'Try again',
    this.onOpen,
    this.onClose,
  }) : assert(items != null || loader != null, 'Provide items or loader');

  /// Static data. Ignored when [loader] is set.
  final List<DropdownItem<T>>? items;

  /// Async data source (your API call).
  final DropdownLoader<T>? loader;

  /// Currently selected item.
  final DropdownItem<T>? selected;
  final ValueChanged<DropdownItem<T>?>? onChanged;

  final String? label;
  final String hint;

  /// Small text under the field. Replaced by the error when there is one.
  final String? helperText;

  /// Forces an error message (e.g. from your server). Wins over [validator].
  final String? errorText;

  /// Form validation. Receives the selected item (null when nothing chosen).
  final FormFieldValidator<DropdownItem<T>>? validator;
  final AutovalidateMode? autovalidateMode;

  final bool searchable;
  final String searchHint;

  /// With a [loader]: call it for every search instead of filtering locally.
  final bool remoteSearch;

  /// With a [loader]: fetch again each time the menu opens.
  final bool reloadOnOpen;

  /// Wait time after typing before a remote search fires.
  final Duration debounce;

  final bool clearable;
  final bool enabled;

  /// Max total height of the open menu (it shrinks near screen edges).
  final double maxMenuHeight;

  /// Height of one row in the menu (scales slightly with system text size).
  final double itemHeight;

  /// Highlight / focus color. Defaults to `Theme.colorScheme.primary`.
  final Color? accentColor;
  final double borderRadius;

  /// Minimum height of the closed field.
  final double fieldHeight;

  final String emptyText;
  final String loadErrorText;
  final String retryText;

  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  @override
  State<PremiumDropdown<T>> createState() => _PremiumDropdownState<T>();
}

// ════════════════════════════════════════════════════════════════════════════
// State
// ════════════════════════════════════════════════════════════════════════════

class _PremiumDropdownState<T> extends State<PremiumDropdown<T>>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const double _listPad = 6;
  static const double _menuGap = 8;
  static const double _screenMargin = 16;
  static const double _minMenuHeight = 160;
  static const _clearAction = CustomSemanticsAction(label: 'Clear selection');

  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _fieldKey = GlobalKey();
  final _formKey = GlobalKey<FormFieldState<DropdownItem<T>>>();
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  final _fieldFocus = FocusNode(debugLabel: 'PremiumDropdown.field');
  late final FocusNode _searchFocus =
  FocusNode(debugLabel: 'PremiumDropdown.search', onKeyEvent: _onKey);

  late final AnimationController _anim;
  late final Animation<double> _curve;

  // Selection (and its mirror inside the FormField).
  DropdownItem<T>? _selected;
  late final DropdownItem<T>? _initialSelected;
  DropdownItem<T>? _formSynced;
  bool _pushScheduled = false;

  // Data.
  List<DropdownItem<T>> _all = const [];
  List<DropdownItem<T>> _visible = const [];
  List<DropdownItem<T>>? _cache; // result of the empty query
  _Phase _phase = _Phase.ready;
  int _highlight = -1;
  int _requestId = 0;
  Timer? _debounce;

  // Menu geometry.
  bool _isOpen = false;
  bool _openAbove = false;
  double _menuMaxHeight = 340;
  double _menuWidth = 300;
  double _itemExtent = 56;

  // ------------------------------------------------------------ lifecycle

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
    _initialSelected = widget.selected;
    _formSynced = widget.selected;

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _curve = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fieldFocus.addListener(_onFocusChange);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant PremiumDropdown<T> old) {
    super.didUpdateWidget(old);

    if (widget.selected != old.selected) _selected = widget.selected;

    if (_isOpen) {
      if (!widget.enabled) {
        _close();
      } else if (widget.loader == null &&
          !identical(widget.items, old.items)) {
        // Static items changed while open: refresh but keep the highlight.
        final keep = _highlight;
        _all = widget.items ?? const [];
        _applyFilter();
        if (keep >= 0 && keep < _visible.length && _visible[keep].enabled) {
          _highlight = keep;
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _fieldFocus.removeListener(_onFocusChange);
    _anim.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _fieldFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  /// Rotation, window resize, keyboard show/hide: re-measure the open menu.
  @override
  void didChangeMetrics() {
    if (!_isOpen) return;
    _afterFrame(() {
      if (_isOpen) setState(() => _updateGeometry());
    });
  }

  void _afterFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) fn();
    });
  }

  // ------------------------------------------------------------ open / close

  /// Measures the field and decides size and direction of the menu.
  /// Only call from event handlers or post-frame callbacks, never from build.
  void _updateGeometry({bool initial = false}) {
    final box = _fieldKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;

    final view = View.of(context);
    final dpr = view.devicePixelRatio;
    final screen = view.physicalSize / dpr;
    final blockedBottom =
        math.max(view.viewInsets.bottom, view.padding.bottom) / dpr;
    final blockedTop = view.padding.top / dpr;

    final origin = box.localToGlobal(Offset.zero);
    final below = screen.height -
        blockedBottom -
        (origin.dy + box.size.height) -
        _screenMargin -
        _menuGap;
    final above = origin.dy - blockedTop - _screenMargin - _menuGap;

    if (initial) {
      _openAbove = below < widget.maxMenuHeight && above > below;
    } else if (_openAbove) {
      if (above < _minMenuHeight && below > above) _openAbove = false;
    } else {
      if (below < _minMenuHeight && above > below) _openAbove = true;
    }

    final space = _openAbove ? above : below;
    _menuMaxHeight = math.min(widget.maxMenuHeight, math.max(space, _minMenuHeight));
    _menuWidth = box.size.width;
  }

  void _toggle() => _isOpen ? _close() : _open();

  void _open() {
    if (!widget.enabled || _isOpen) return;
    if (_fieldKey.currentContext == null) return;

    _updateGeometry(initial: true);
    _searchCtrl.clear();
    _isOpen = true;
    _portal.show();
    _anim.forward();
    setState(_prepareItems);
    widget.onOpen?.call();

    _afterFrame(() {
      if (!_isOpen) return;
      if (widget.searchable) {
        _searchFocus.requestFocus();
      } else {
        _fieldFocus.requestFocus();
      }
    });
  }

  Future<void> _close({bool restoreFocus = true}) async {
    if (!_isOpen) return;
    _debounce?.cancel();
    _requestId++; // drop any in-flight response

    if (restoreFocus) {
      _searchFocus.unfocus(); // dismisses the soft keyboard right away
      if (FocusManager.instance.highlightMode ==
          FocusHighlightMode.traditional) {
        _fieldFocus.requestFocus();
      }
    }

    setState(() => _isOpen = false);
    widget.onClose?.call();

    await _anim.reverse();
    if (!mounted || _isOpen) return; // re-opened during the animation
    _portal.hide();
    _searchCtrl.clear();
  }

  // ------------------------------------------------------------------- data

  /// Call inside setState.
  void _prepareItems() {
    _highlight = -1;

    if (widget.loader == null) {
      _all = widget.items ?? const [];
      _phase = _Phase.ready;
      _applyFilter();
      _afterFrame(() => _scrollToHighlight(initial: true));
      return;
    }

    final cached = _cache;
    if (cached != null && !widget.reloadOnOpen) {
      _all = cached;
      _phase = _Phase.ready;
      _applyFilter();
      _afterFrame(() => _scrollToHighlight(initial: true));
      return;
    }

    if (cached == null) {
      _all = const [];
      _visible = const [];
    } else {
      _all = cached; // show the old list while refreshing
      _applyFilter();
    }
    unawaited(_fetch(''));
  }

  /// Sets state synchronously (call it inside setState), then loads.
  Future<void> _fetch(String query) async {
    final id = ++_requestId;
    _phase = _Phase.loading;
    try {
      final result = await widget.loader!(query);
      if (!mounted || id != _requestId) return;
      setState(() {
        if (query.isEmpty) _cache = result;
        _all = result;
        _phase = _Phase.ready;
        _applyFilter();
      });
      if (query.isEmpty) {
        _afterFrame(() => _scrollToHighlight(initial: true));
      }
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() => _phase = _Phase.error);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final server = widget.loader != null && widget.remoteSearch;
    if (q.isEmpty || server) {
      _visible = _all;
    } else {
      _visible = _all
          .where((i) =>
      i.label.toLowerCase().contains(q) ||
          (i.subtitle?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    _highlight = _initialHighlight(q);
  }

  int _initialHighlight(String query) {
    final sel = _selected;
    if (sel != null && query.isEmpty) {
      final i = _visible.indexWhere((e) => e.value == sel.value);
      if (i >= 0 && _visible[i].enabled) return i;
    }
    return _visible.indexWhere((e) => e.enabled);
  }

  void _onQuery(String raw) {
    _debounce?.cancel();

    if (widget.loader != null && widget.remoteSearch) {
      setState(() {}); // refresh the clear (×) icon
      _debounce = Timer(widget.debounce, () {
        if (!mounted || !_isOpen) return;
        final q = raw.trim();
        final cached = _cache;
        setState(() {
          if (q.isEmpty && cached != null) {
            _requestId++;
            _all = cached;
            _phase = _Phase.ready;
            _applyFilter();
          } else {
            unawaited(_fetch(q));
          }
        });
      });
    } else {
      setState(_applyFilter);
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  void _clearQuery() {
    _searchCtrl.clear();
    _onQuery('');
    _searchFocus.requestFocus();
  }

  // -------------------------------------------------------------- selection

  void _select(DropdownItem<T> item) {
    if (!item.enabled) return;
    setState(() => _selected = item);
    widget.onChanged?.call(item);
    _close();
  }

  void _selectHighlighted() {
    if (!_isOpen) return;
    if (_highlight >= 0 && _highlight < _visible.length) {
      _select(_visible[_highlight]);
    }
  }

  void _clearSelection() {
    if (_selected == null) return;
    setState(() => _selected = null);
    widget.onChanged?.call(null);
  }

  // ----------------------------------------------------- keyboard / scrolling

  void _move(int dir) {
    final len = _visible.length;
    if (len == 0) return;
    var i = _highlight;
    for (var n = 0; n < len; n++) {
      i = i < 0 ? (dir > 0 ? 0 : len - 1) : (i + dir + len) % len;
      if (_visible[i].enabled) {
        setState(() => _highlight = i);
        _scrollToHighlight();
        return;
      }
    }
  }

  void _scrollToHighlight({bool initial = false}) {
    if (!_scroll.hasClients || _highlight < 0) return;
    final pos = _scroll.position;
    final top = _listPad + _highlight * _itemExtent;
    final bottom = top + _itemExtent;

    double? target;
    if (initial) {
      target = top - (pos.viewportDimension - _itemExtent) / 2;
    } else if (top - _listPad < pos.pixels) {
      target = top - _listPad;
    } else if (bottom + _listPad > pos.pixels + pos.viewportDimension) {
      target = bottom + _listPad - pos.viewportDimension;
    }
    if (target == null) return;

    target = target.clamp(pos.minScrollExtent, pos.maxScrollExtent).toDouble();
    if (initial) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    final isEnter =
        k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter;

    if (!_isOpen) {
      if (isEnter ||
          k == LogicalKeyboardKey.space ||
          k == LogicalKeyboardKey.arrowDown) {
        _open();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (k == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (isEnter || (k == LogicalKeyboardKey.space && !widget.searchable)) {
      _selectHighlighted();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.tab) {
      _close(restoreFocus: false); // let normal focus traversal continue
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  // -------------------------------------------------------------- form sync

  /// Keeps the FormField value and our own selection in step, both ways.
  /// Called from the FormField builder.
  void _syncForm(FormFieldState<DropdownItem<T>> state) {
    final formValue = state.value;
    if (formValue != _formSynced) {
      // Changed from outside, e.g. FormState.reset().
      _selected = formValue;
      _formSynced = formValue;
      _afterFrame(() => widget.onChanged?.call(formValue));
    } else if (_selected != _formSynced && !_pushScheduled) {
      _pushScheduled = true;
      _afterFrame(() {
        _pushScheduled = false;
        final form = _formKey.currentState;
        if (form == null) return;
        _formSynced = _selected;
        form.didChange(_selected);
      });
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.accentColor ?? theme.colorScheme.primary;
    final c = _Palette(theme, accent);

    final scale =
    (MediaQuery.textScalerOf(context).scale(15) / 15).clamp(1.0, 1.4);
    _itemExtent = widget.itemHeight * scale.toDouble();

    return PopScope(
      canPop: !_isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isOpen) _close(); // Android back closes the menu
      },
      child: FormField<DropdownItem<T>>(
        key: _formKey,
        initialValue: _initialSelected,
        validator: widget.validator,
        autovalidateMode: widget.autovalidateMode,
        enabled: widget.enabled,
        builder: (state) {
          _syncForm(state);
          return _buildContent(c, widget.errorText ?? state.errorText);
        },
      ),
    );
  }

  Widget _buildContent(_Palette c, String? error) {
    final note = error ?? widget.helperText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: c.muted,
            ),
          ),
          const SizedBox(height: 8),
        ],
        OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (_) => _buildOverlay(c),
          child: CompositedTransformTarget(
            link: _link,
            child: _buildField(c, error != null),
          ),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
            child: Text(
              note,
              style: TextStyle(
                fontSize: 12.5,
                color: error != null ? c.error : c.muted,
              ),
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------ field

  Widget _buildField(_Palette c, bool hasError) {
    final sel = _selected;
    final active = _isOpen || _fieldFocus.hasFocus;
    final ring = hasError ? c.error : c.accent;
    final canClear = widget.clearable && sel != null && widget.enabled;

    return Focus(
      focusNode: _fieldFocus,
      canRequestFocus: widget.enabled,
      onKeyEvent: _onKey,
      child: Semantics(
        container: true,
        button: true,
        enabled: widget.enabled,
        expanded: _isOpen,
        label: widget.label ?? widget.hint,
        value: sel?.label ?? widget.hint,
        onTap: widget.enabled ? _toggle : null,
        customSemanticsActions:
        canClear ? {_clearAction: _clearSelection} : null,
        excludeSemantics: true,
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.5,
          child: MouseRegion(
            cursor: widget.enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.enabled ? _toggle : null,
              child: AnimatedContainer(
                key: _fieldKey,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                constraints: BoxConstraints(minHeight: widget.fieldHeight),
                padding: const EdgeInsets.only(left: 16, right: 12),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: (active || hasError) ? ring : c.border,
                    width: (active || hasError) ? 1.6 : 1,
                  ),
                  boxShadow: [
                    if (_isOpen)
                      BoxShadow(
                        color: ring.withValues(alpha: 0.20),
                        blurRadius: 20,
                        spreadRadius: 1,
                      )
                    else
                      const BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    if (sel?.leading != null) ...[
                      sel!.leading!,
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        // Default layout centers the text; keep it left.
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.centerLeft,
                          children: [...previous, if (current != null) current],
                        ),
                        child: Text(
                          sel?.label ?? widget.hint,
                          key: ValueKey(sel?.label ?? '__hint__'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight:
                            sel == null ? FontWeight.w400 : FontWeight.w600,
                            color: sel == null ? c.muted : c.text,
                          ),
                        ),
                      ),
                    ),
                    if (canClear)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _clearSelection,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.close_rounded,
                              size: 18, color: c.muted),
                        ),
                      ),
                    AnimatedRotation(
                      turns: _isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 26,
                        color: active ? ring : c.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- menu

  Widget _buildOverlay(_Palette c) {
    final above = _openAbove;
    final radius = BorderRadius.circular(widget.borderRadius + 2);

    final menu = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: _menuMaxHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: radius,
          border: Border.all(color: c.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 32,
              offset: Offset(0, 14),
            ),
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.searchable) _buildSearch(c),
                Flexible(child: _buildBody(c)),
              ],
            ),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        // Tap outside to close.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          width: _menuWidth,
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: above ? Alignment.topLeft : Alignment.bottomLeft,
            followerAnchor: above ? Alignment.bottomLeft : Alignment.topLeft,
            offset: Offset(0, above ? -_menuGap : _menuGap),
            child: AnimatedBuilder(
              animation: _curve,
              child: menu,
              builder: (context, child) {
                final v = _curve.value;
                return Opacity(
                  opacity: v.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, (1 - v) * (above ? 10 : -10)),
                    child: Transform.scale(
                      scale: 0.96 + 0.04 * v,
                      alignment:
                      above ? Alignment.bottomCenter : Alignment.topCenter,
                      child: child,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearch(_Palette c) {
    final loading = _phase == _Phase.loading;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus, // arrow / enter / esc handled via node
            onChanged: _onQuery,
            onSubmitted: (_) => _selectHighlighted(),
            textInputAction: TextInputAction.search,
            autocorrect: false,
            enableSuggestions: false,
            cursorColor: c.accent,
            style: TextStyle(fontSize: 15, color: c.text),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: c.searchFill,
              hintText: widget.searchHint,
              hintStyle: TextStyle(fontSize: 15, color: c.muted),
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: c.muted),
              prefixIconConstraints:
              const BoxConstraints(minWidth: 42, minHeight: 20),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : GestureDetector(
                onTap: _clearQuery,
                child:
                Icon(Icons.close_rounded, size: 18, color: c.muted),
              ),
              suffixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 20),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: c.accent.withValues(alpha: 0.5),
                  width: 1.2,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 2,
          child: loading
              ? LinearProgressIndicator(
            minHeight: 2,
            color: c.accent,
            backgroundColor: Colors.transparent,
          )
              : Align(
            alignment: Alignment.bottomCenter,
            child: Container(height: 1, color: c.border),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(_Palette c) {
    if (_phase == _Phase.loading && _all.isEmpty) {
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: _SkeletonList(color: c.searchFill),
      );
    }

    if (_phase == _Phase.error) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 30, color: c.muted),
            const SizedBox(height: 10),
            Text(
              widget.loadErrorText,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => setState(() {
                unawaited(_fetch(
                    widget.remoteSearch ? _searchCtrl.text.trim() : ''));
              }),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(widget.retryText),
              style: TextButton.styleFrom(foregroundColor: c.accent),
            ),
          ],
        ),
      );
    }

    if (_visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 30, color: c.muted),
            const SizedBox(height: 10),
            Text(
              widget.emptyText,
              style: TextStyle(fontSize: 14.5, color: c.muted),
            ),
          ],
        ),
      );
    }

    final query = _searchCtrl.text.trim();
    return ListView.builder(
      controller: _scroll,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: _listPad),
      itemExtent: _itemExtent,
      itemCount: _visible.length,
      itemBuilder: (context, i) => _buildItem(c, i, query),
    );
  }

  Widget _buildItem(_Palette c, int i, String query) {
    final item = _visible[i];
    final isSelected = _selected != null && _selected!.value == item.value;
    final isHighlighted = i == _highlight && item.enabled;

    final base = TextStyle(
      fontSize: 15,
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      color: isSelected ? c.accent : c.text,
    );
    final hl = base.copyWith(
      color: c.accent,
      fontWeight: FontWeight.w800,
      backgroundColor: c.accent.withValues(alpha: 0.12),
    );

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: item.enabled,
      label: item.subtitle == null
          ? item.label
          : '${item.label}, ${item.subtitle}',
      onTap: item.enabled ? () => _select(item) : null,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: item.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        // onHover (not onEnter) so a list scrolling under a still mouse
        // does not steal the keyboard highlight.
        onHover: (_) {
          if (item.enabled && _highlight != i) setState(() => _highlight = i);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: item.enabled ? () => _select(item) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? c.selectedBg
                    : (isHighlighted ? c.hover : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Opacity(
                opacity: item.enabled ? 1 : 0.4,
                child: Row(
                  children: [
                    if (item.leading != null) ...[
                      item.leading!,
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                                children: _spans(item.label, query, base, hl)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                item.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                TextStyle(fontSize: 12.5, color: c.muted),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_rounded, size: 20, color: c.accent),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Splits [text] so every match of [q] gets the highlight style.
  List<InlineSpan> _spans(String text, String q, TextStyle base, TextStyle hl) {
    if (q.isEmpty || widget.remoteSearch) {
      return [TextSpan(text: text, style: base)];
    }
    final lower = text.toLowerCase();
    final lq = q.toLowerCase();
    // Some Unicode characters change length when lowercased; skip then.
    if (lower.length != text.length) return [TextSpan(text: text, style: base)];

    final out = <InlineSpan>[];
    var start = 0;
    while (true) {
      final idx = lower.indexOf(lq, start);
      if (idx < 0) {
        if (start < text.length) {
          out.add(TextSpan(text: text.substring(start), style: base));
        }
        break;
      }
      if (idx > start) {
        out.add(TextSpan(text: text.substring(start, idx), style: base));
      }
      out.add(TextSpan(text: text.substring(idx, idx + lq.length), style: hl));
      start = idx + lq.length;
    }
    return out;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Helpers
// ════════════════════════════════════════════════════════════════════════════

/// Pulsing placeholder rows shown while the first load is running.
class _SkeletonList extends StatefulWidget {
  const _SkeletonList({required this.color});

  final Color color;

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(begin: 0.45, end: 1)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 4; i++)
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    _bar(width: 32, height: 32, radius: 16),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _bar(height: 12, factor: 0.6 + (i % 2) * 0.2),
                          const SizedBox(height: 7),
                          _bar(height: 9, factor: 0.35),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bar({
    double? width,
    required double height,
    double radius = 6,
    double factor = 1,
  }) {
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(width: width, height: height),
    );
    if (width != null) return box;
    return FractionallySizedBox(
      widthFactor: factor,
      alignment: Alignment.centerLeft,
      child: box,
    );
  }
}

/// Colors derived from the app theme, so light/dark and custom color schemes
/// just work. Only [accent] can be overridden per widget.
class _Palette {
  _Palette(ThemeData theme, this.accent)
      : scheme = theme.colorScheme,
        dark = theme.brightness == Brightness.dark;

  final ColorScheme scheme;
  final bool dark;
  final Color accent;

  Color get surface =>
      dark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest;
  Color get border => scheme.outlineVariant;
  Color get text => scheme.onSurface;
  Color get muted => scheme.onSurfaceVariant;
  Color get error => scheme.error;
  Color get searchFill => scheme.onSurface.withValues(alpha: 0.06);
  Color get hover => scheme.onSurface.withValues(alpha: 0.05);
  Color get selectedBg => accent.withValues(alpha: dark ? 0.22 : 0.10);
}


class CountryDropdownDemo extends StatefulWidget {
  const CountryDropdownDemo({super.key});

  @override
  State<CountryDropdownDemo> createState() => _CountryDropdownDemoState();
}

class _CountryDropdownDemoState extends State<CountryDropdownDemo> {
  DropdownItem<String>? _country;

  static const _countries = <DropdownItem<String>>[
    DropdownItem(value: 'in', label: 'India', subtitle: 'Asia'),
    DropdownItem(value: 'us', label: 'United States', subtitle: 'North America'),
    DropdownItem(
      value: 'de',
      label: 'Germany',
      subtitle: 'Europe',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumDropdown<String>(
              hint: 'Select a country',
              items: _countries,
              selected: _country,

              onChanged: (item) => setState(() => _country = item),
            ),
            const SizedBox(height: 24),

          ],
        ),
      ),
    );
  }
}