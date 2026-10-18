// component_sidebar.dart
//
// Docs-style sidebar: search field on top, then collapsible sections
// (headings) that expand to show their items.
//
// - Search filters live across every section, auto-expands matches and
//   highlights the matching text. Esc clears. "/" focuses the field.
// - Click a heading to expand / collapse. `accordion: true` keeps one open.
// - Selected item is highlighted; its section opens automatically.
// - Works as a fixed desktop column or as the child of a Drawer.
// - Hover an item (mouse) to get a floating mini preview card to the right,
//   like docs sites do. Give items a `previewBuilder` to enable it.
//
// Uses google_fonts (already in your site). Needs a Material ancestor.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _bg = Color(0xFF0B0B0B);
const Color _inner = Color(0xFF000000);
const Color _border = Color(0x1AFFFFFF);
const Color _muted = Color(0xFF8A8A8A);
const Color _selected = Color(0xFF1C1C1C);

@immutable
class SidebarItem {
  const SidebarItem({
    required this.id,
    required this.label,
    this.badge,
    this.keywords = const [],
    this.previewBuilder,
    this.caption,
  });

  final String id;
  final String label;

  /// Tiny chip after the label, e.g. "New".
  final String? badge;

  /// Extra words that also match the search.
  final List<String> keywords;

  /// Builds the mini preview shown in the hover card. Built only while the
  /// card is visible. The widget is laid out in a 360 x 200 box and scaled
  /// down to fit, so pass the same compact demo you use in gallery tiles.
  /// Null = no hover card for this item.
  final WidgetBuilder? previewBuilder;

  /// Small label at the bottom right of the hover card. Defaults to the name
  /// of the section the item lives in.
  final String? caption;
}

@immutable
class SidebarSection {
  const SidebarSection({
    required this.id,
    required this.title,
    required this.items,
    this.icon,
  });

  final String id;
  final String title;
  final List<SidebarItem> items;
  final IconData? icon;
}

class ComponentSidebar extends StatefulWidget {
  const ComponentSidebar({
    super.key,
    required this.sections,
    this.selectedId,
    this.onSelect,
    this.width = 280,
    this.accordion = false,
    this.initiallyExpanded,
    this.searchHint = 'Search components',
    this.header,
    this.footer,
    this.backgroundColor = _bg,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  final List<SidebarSection> sections;
  final String? selectedId;
  final ValueChanged<SidebarItem>? onSelect;
  final double width;

  /// Only one section open at a time.
  final bool accordion;

  /// Section ids open on first build. Default: the section holding
  /// [selectedId], otherwise the first section.
  final Set<String>? initiallyExpanded;

  final String searchHint;

  /// Widget above the search field (logo, title...).
  final Widget? header;

  /// Widget pinned at the bottom (version, links...).
  final Widget? footer;

  final Color backgroundColor;

  /// When true, the sidebar renders as a narrow collapsed rail.
  final bool isCollapsed;

  /// Called when the user taps the collapse / expand toggle button.
  final VoidCallback? onToggleCollapse;

  @override
  State<ComponentSidebar> createState() => _ComponentSidebarState();
}

class _ComponentSidebarState extends State<ComponentSidebar> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _searchFocus = FocusNode(debugLabel: 'SidebarSearch');
  final ScrollController _scroll = ScrollController();
  late Set<String> _open;

  String get _q => _query.text.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _open = {...?widget.initiallyExpanded};
    if (widget.initiallyExpanded == null) {
      final home = _sectionOf(widget.selectedId) ??
          (widget.sections.isNotEmpty ? widget.sections.first.id : null);
      if (home != null) _open.add(home);
    }
    _searchFocus.addListener(() => setState(() {}));
    HardwareKeyboard.instance.addHandler(_onGlobalKey);
  }

  @override
  void didUpdateWidget(covariant ComponentSidebar old) {
    super.didUpdateWidget(old);
    if (widget.selectedId != old.selectedId) {
      final s = _sectionOf(widget.selectedId);
      if (s != null && !_open.contains(s)) {
        setState(() {
          if (widget.accordion) _open.clear();
          _open.add(s);
        });
      }
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onGlobalKey);
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _removeTimer?.cancel();
    _entry?.remove();
    _entry = null;
    _preview.dispose();
    _query.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // "/" focuses the search field unless the user is already typing.
  bool _onGlobalKey(KeyEvent e) {
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.slash) {
      return false;
    }
    if (!mounted || _searchFocus.hasFocus) return false;
    final primary = FocusManager.instance.primaryFocus;
    if (primary?.context?.widget is EditableText) return false;
    _searchFocus.requestFocus();
    return true;
  }

  // ---- hover preview ------------------------------------------------------

  static const double _cardW = 304;
  static const double _cardH = 226;

  OverlayEntry? _entry;
  final ValueNotifier<_PreviewData?> _preview =
  ValueNotifier<_PreviewData?>(null);
  Timer? _showTimer;
  Timer? _hideTimer;
  Timer? _removeTimer;

  /// [rect] is the item's global rect on enter, null on exit.
  void _onItemHover(SidebarItem item, Rect? rect) {
    if (rect == null) {
      _showTimer?.cancel();
      _hideTimer?.cancel();
      // grace period so moving from item to item does not flicker
      _hideTimer = Timer(const Duration(milliseconds: 90), _hidePreview);
      return;
    }
    _hideTimer?.cancel();
    if (item.previewBuilder == null) {
      _hidePreview();
      return;
    }
    final data = _dataFor(item, rect);
    if (_entry != null) {
      // card already open: glide to the new item without waiting
      _removeTimer?.cancel();
      _preview.value = data;
      return;
    }
    _showTimer?.cancel();
    _showTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) _showPreview(data);
    });
  }

  _PreviewData _dataFor(SidebarItem item, Rect itemRect) {
    final box = context.findRenderObject() as RenderBox?;
    final side = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : itemRect;
    final screen = MediaQuery.sizeOf(context);
    final maxTop = math.max(12.0, screen.height - _cardH - 12);
    final top =
    (itemRect.center.dy - _cardH / 2).clamp(12.0, maxTop).toDouble();
    String? section;
    for (final s in widget.sections) {
      if (s.items.any((i) => i.id == item.id)) {
        section = s.title;
        break;
      }
    }
    return _PreviewData(
      item: item,
      left: side.right + 12,
      top: top,
      caption: item.caption ?? section ?? '',
    );
  }

  void _showPreview(_PreviewData data) {
    _removeTimer?.cancel();
    _preview.value = data;
    if (_entry != null) return;
    _entry = OverlayEntry(
      builder: (_) => _PreviewOverlay(
        source: _preview,
        cardW: _cardW,
        cardH: _cardH,
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _hidePreview() {
    _showTimer?.cancel();
    if (_entry == null) return;
    _preview.value = null; // starts the fade-out
    _removeTimer?.cancel();
    _removeTimer = Timer(const Duration(milliseconds: 220), () {
      _entry?.remove();
      _entry = null;
    });
  }

  String? _sectionOf(String? itemId) {
    if (itemId == null) return null;
    for (final s in widget.sections) {
      if (s.items.any((i) => i.id == itemId)) return s.id;
    }
    return null;
  }

  bool _matches(SidebarItem i) =>
      i.label.toLowerCase().contains(_q) ||
          i.keywords.any((k) => k.toLowerCase().contains(_q));

  void _toggle(String id) {
    setState(() {
      if (_open.contains(id)) {
        _open.remove(id);
      } else {
        if (widget.accordion) _open.clear();
        _open.add(id);
      }
    });
  }

  void _toggleAll() {
    setState(() {
      if (_open.length == widget.sections.length) {
        _open.clear();
      } else {
        _open = {for (final s in widget.sections) s.id};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ---- collapsed: takes no space at all ----
    if (widget.isCollapsed) return const SizedBox.shrink();

    // ---- expanded sidebar ----
    final q = _q;
    final searching = q.isNotEmpty;

    // filtered view
    final visible = <(SidebarSection, List<SidebarItem>)>[];
    for (final s in widget.sections) {
      if (!searching) {
        visible.add((s, s.items));
        continue;
      }
      final titleHit = s.title.toLowerCase().contains(q);
      final hits = titleHit ? s.items : s.items.where(_matches).toList();
      if (hits.isNotEmpty) visible.add((s, hits));
    }

    return Material(
      color: widget.backgroundColor,
      child: Container(
        width: widget.width,
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: _border)),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- header + collapse button row ----
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    if (widget.header != null)
                      Expanded(
                        child: widget.header!,
                      )
                    else
                      const Spacer(),
                    Tooltip(
                      message: 'Collapse sidebar',
                      child: InkResponse(
                        onTap: widget.onToggleCollapse,
                        radius: 16,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.chevron_left_rounded,
                            size: 18,
                            color: _muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: _SearchField(
                  controller: _query,
                  focusNode: _searchFocus,
                  hint: widget.searchHint,
                  onChanged: (_) => setState(() {}),
                  onClear: () => setState(_query.clear),
                ),
              ),
              if (!searching && widget.sections.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                  child: Row(
                    children: [
                      Text(
                        'COMPONENTS',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          letterSpacing: 1,
                          color: _muted,
                        ),
                      ),
                      const Spacer(),
                      Tooltip(
                        message: _open.length == widget.sections.length
                            ? 'Collapse all'
                            : 'Expand all',
                        child: InkResponse(
                          onTap: _toggleAll,
                          radius: 16,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              _open.length == widget.sections.length
                                  ? Icons.unfold_less_rounded
                                  : Icons.unfold_more_rounded,
                              size: 16,
                              color: _muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: visible.isEmpty
                    ? _EmptyState(
                  query: _query.text.trim(),
                  onClear: () => setState(_query.clear),
                )
                    : Scrollbar(
                  controller: _scroll,
                  thickness: 3,
                  radius: const Radius.circular(3),
                  child: NotificationListener<ScrollStartNotification>(
                    // hide the hover card while the list scrolls
                    onNotification: (_) {
                      _hidePreview();
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final (section, items) = visible[i];
                        return _SectionBlock(
                          section: section,
                          items: items,
                          expanded:
                          searching || _open.contains(section.id),
                          selectedId: widget.selectedId,
                          query: q,
                          onToggle: () {
                            _hidePreview();
                            _toggle(section.id);
                          },
                          onItemHover: _onItemHover,
                          onSelect: (item) {
                            _hidePreview();
                            widget.onSelect?.call(item);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (widget.footer != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _border)),
                  ),
                  child: widget.footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// search
// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    final hasText = controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _inner,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: focused ? const Color(0x40FFFFFF) : _border,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 16, color: _muted),
          const SizedBox(width: 8),
          Expanded(
            child: Focus(
              onKeyEvent: (node, e) {
                if (e is KeyDownEvent &&
                    e.logicalKey == LogicalKeyboardKey.escape) {
                  if (hasText) onClear();
                  focusNode.unfocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                cursorColor: Colors.white,
                cursorWidth: 1.2,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: _muted,
                  ),
                ),
              ),
            ),
          ),
          if (hasText)
            InkResponse(
              onTap: onClear,
              radius: 14,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 14, color: _muted),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _border),
              ),
              child: Text(
                '/',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: _muted),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// section + items
// ---------------------------------------------------------------------------

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.section,
    required this.items,
    required this.expanded,
    required this.selectedId,
    required this.query,
    required this.onToggle,
    required this.onSelect,
    required this.onItemHover,
  });

  final SidebarSection section;
  final List<SidebarItem> items;
  final bool expanded;
  final String? selectedId;
  final String query;
  final VoidCallback onToggle;
  final ValueChanged<SidebarItem> onSelect;
  final void Function(SidebarItem item, Rect? rect) onItemHover;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            label: section.title,
            excludeSemantics: true,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              hoverColor: const Color(0x0AFFFFFF),
              splashColor: Colors.transparent,
              highlightColor: const Color(0x0AFFFFFF),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: const Icon(Icons.chevron_right_rounded,
                          size: 18, color: _muted),
                    ),
                    const SizedBox(width: 4),
                    if (section.icon != null) ...[
                      Icon(section.icon, size: 15, color: _muted),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        section.title,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '${items.length}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
              padding: const EdgeInsets.only(left: 17, top: 2, bottom: 4),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: _border)),
                ),
                padding: const EdgeInsets.only(left: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in items)
                      _ItemTile(
                        item: item,
                        selected: item.id == selectedId,
                        query: query,
                        onTap: () => onSelect(item),
                        onHover: onItemHover,
                      ),
                  ],
                ),
              ),
            )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatefulWidget {
  const _ItemTile({
    required this.item,
    required this.selected,
    required this.query,
    required this.onTap,
    required this.onHover,
  });

  final SidebarItem item;
  final bool selected;
  final String query;
  final VoidCallback onTap;
  final void Function(SidebarItem item, Rect? rect) onHover;

  @override
  State<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<_ItemTile> {
  bool _hover = false;

  void _notify(bool enter) {
    Rect? rect;
    if (enter) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        rect = box.localToGlobal(Offset.zero) & box.size;
      }
    }
    widget.onHover(widget.item, rect);
  }

  List<InlineSpan> _label(TextStyle base, TextStyle hi) {
    final text = widget.item.label;
    final q = widget.query;
    if (q.isEmpty) return [TextSpan(text: text, style: base)];
    final i = text.toLowerCase().indexOf(q);
    if (i < 0) return [TextSpan(text: text, style: base)];
    return [
      TextSpan(text: text.substring(0, i), style: base),
      TextSpan(text: text.substring(i, i + q.length), style: hi),
      TextSpan(text: text.substring(i + q.length), style: base),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    final color = sel
        ? Colors.white
        : (_hover ? const Color(0xFFD4D4D4) : const Color(0xFFA1A1A1));
    final base = GoogleFonts.jetBrainsMono(
      fontSize: 12.5,
      color: color,
      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
    );
    final hi = base.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      backgroundColor: const Color(0x26FFFFFF),
    );

    return Semantics(
      button: true,
      selected: sel,
      label: widget.item.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          setState(() => _hover = true);
          _notify(true);
        },
        onExit: (_) {
          setState(() => _hover = false);
          _notify(false);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: sel
                  ? _selected
                  : (_hover ? const Color(0x0DFFFFFF) : Colors.transparent),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: sel ? _border : Colors.transparent),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 2,
                  height: 14,
                  decoration: BoxDecoration(
                    color: sel ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: _label(base, hi)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.item.badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0x33FFFFFF)),
                    ),
                    child: Text(
                      widget.item.badge!,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 24, color: _muted),
            const SizedBox(height: 12),
            Text(
              'No match for "$query"',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try another word.',
              style: GoogleFonts.inter(fontSize: 12, color: _muted),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onClear,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                'Clear search',
                style: GoogleFonts.jetBrainsMono(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// hover preview card
// ---------------------------------------------------------------------------

class _PreviewData {
  const _PreviewData({
    required this.item,
    required this.left,
    required this.top,
    required this.caption,
  });

  final SidebarItem item;
  final double left;
  final double top;
  final String caption;
}

/// Lives in the Overlay. Fades and slides in, glides between items, fades
/// out when [source] becomes null. Never takes pointer events.
class _PreviewOverlay extends StatefulWidget {
  const _PreviewOverlay({
    required this.source,
    required this.cardW,
    required this.cardH,
  });

  final ValueNotifier<_PreviewData?> source;
  final double cardW;
  final double cardH;

  @override
  State<_PreviewOverlay> createState() => _PreviewOverlayState();
}

class _PreviewOverlayState extends State<_PreviewOverlay> {
  _PreviewData? _last;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _last = widget.source.value;
    widget.source.addListener(_onChange);
    // first frame builds hidden, then animates in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = widget.source.value != null);
    });
  }

  void _onChange() {
    final v = widget.source.value;
    setState(() {
      if (v != null) _last = v;
      _visible = v != null;
    });
  }

  @override
  void dispose() {
    widget.source.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _last;
    if (d == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            left: d.left,
            top: d.top,
            width: widget.cardW,
            height: widget.cardH,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: AnimatedSlide(
                offset: _visible ? Offset.zero : const Offset(-0.04, 0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: _PreviewCard(data: d),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.data});

  final _PreviewData data;

  @override
  Widget build(BuildContext context) {
    final item = data.item;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x26FFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 40,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: KeyedSubtree(
            key: ValueKey(item.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _inner,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        // design size: the demo is laid out here, then scaled
                        child: SizedBox(
                          width: 360,
                          height: 200,
                          child: Center(
                            child: Builder(builder: item.previewBuilder!),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        data.caption,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: _muted,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}