// command_palette.dart
//
// A premium command-palette overlay triggered from the app-bar search button.
// • Keyboard: ↑ ↓ navigate · Enter open · Esc close
// • Animated: backdrop fade + blur, card slide-up entrance, per-item stagger
// • Search highlights matched text in results
// • Section headers group items; clicking selects the component

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:widget_ui/app_common/widget/custom_side_bar.dart';

// ─── public API ──────────────────────────────────────────────────────────────

/// Opens the command palette as a full-screen dialog overlay.
void showCommandPalette({
  required BuildContext context,
  required List<SidebarSection> sections,
  required ValueChanged<SidebarItem> onSelect,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: false, // we handle dismiss ourselves
    barrierLabel: 'CommandPalette',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, animation, _) => _CommandPaletteDialog(
      sections: sections,
      animation: animation,
      onSelect: (item) {
        Navigator.of(ctx).pop();
        onSelect(item);
      },
      onClose: () => Navigator.of(ctx).pop(),
    ),
  );
}

// ─── internal data model ─────────────────────────────────────────────────────

class _Entry {
  const _Entry._({
    required this.isItem,
    this.sectionTitle,
    this.item,
    this.itemSection,
  });

  factory _Entry.section(String title) =>
      _Entry._(isItem: false, sectionTitle: title);

  factory _Entry.item(SidebarItem item, String section) =>
      _Entry._(isItem: true, item: item, itemSection: section);

  final bool isItem;
  final String? sectionTitle;
  final SidebarItem? item;
  final String? itemSection;
}

// ─── dialog ──────────────────────────────────────────────────────────────────

class _CommandPaletteDialog extends StatefulWidget {
  const _CommandPaletteDialog({
    required this.sections,
    required this.animation,
    required this.onSelect,
    required this.onClose,
  });

  final List<SidebarSection> sections;
  final Animation<double> animation;
  final ValueChanged<SidebarItem> onSelect;
  final VoidCallback onClose;

  @override
  State<_CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<_CommandPaletteDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _query = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scroll = ScrollController();

  List<_Entry> _entries = [];
  int _selectedEntry = -1; // index into _entries, always an item row

  // stagger animation
  late AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _rebuild('');
    _staggerCtrl.forward();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _searchFocus.requestFocus());
    HardwareKeyboard.instance.addHandler(_onGlobalKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onGlobalKey);
    _staggerCtrl.dispose();
    _query.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── build flat entry list ─────────────────────────────────────────────────

  void _rebuild(String q) {
    final entries = <_Entry>[];
    for (final section in widget.sections) {
      final items = q.isEmpty
          ? section.items
          : section.items
              .where((i) =>
                  i.label.toLowerCase().contains(q) ||
                  i.keywords.any((k) => k.toLowerCase().contains(q)))
              .toList();
      if (items.isEmpty) continue;
      entries.add(_Entry.section(section.title));
      for (final item in items) {
        entries.add(_Entry.item(item, section.title));
      }
    }
    _entries = entries;
    final firstItem = entries.indexWhere((e) => e.isItem);
    _selectedEntry = firstItem;
  }

  // ── keyboard ──────────────────────────────────────────────────────────────

  bool _onGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _moveSelection(1);
        return true;
      case LogicalKeyboardKey.arrowUp:
        _moveSelection(-1);
        return true;
      case LogicalKeyboardKey.enter:
        _selectCurrent();
        return true;
      case LogicalKeyboardKey.escape:
        widget.onClose();
        return true;
      default:
        return false;
    }
  }

  List<int> get _itemIndices =>
      [for (int i = 0; i < _entries.length; i++) if (_entries[i].isItem) i];

  void _moveSelection(int delta) {
    final indices = _itemIndices;
    if (indices.isEmpty) return;
    final cur = indices.indexOf(_selectedEntry);
    final next = (cur + delta).clamp(0, indices.length - 1);
    setState(() => _selectedEntry = indices[next]);
    _scrollToSelected();
  }

  void _selectCurrent() {
    if (_selectedEntry < 0 || _selectedEntry >= _entries.length) return;
    final entry = _entries[_selectedEntry];
    if (entry.isItem && entry.item != null) widget.onSelect(entry.item!);
  }

  void _scrollToSelected() {
    double offset = 0;
    for (int i = 0; i < _selectedEntry && i < _entries.length; i++) {
      offset += _entries[i].isItem ? 54 : 38;
    }
    _scroll.animateTo(
      (offset - 80).clamp(0.0, double.infinity),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
    );
  }

  // ── animations ────────────────────────────────────────────────────────────

  Animation<double> get _backdropAnim => CurvedAnimation(
        parent: widget.animation,
        curve: Curves.easeOut,
      );

  Animation<Offset> get _slideAnim => Tween<Offset>(
        begin: const Offset(0, -0.035),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: widget.animation,
        curve: Curves.easeOutCubic,
      ));

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _backdropAnim,
      child: Material(
        color: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: const Color(0x88000000),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: Center(
                child: SlideTransition(
                  position: _slideAnim,
                  child: FadeTransition(
                    opacity: _backdropAnim,
                    child: GestureDetector(
                      onTap: () {}, // absorb taps so backdrop doesn't close
                      child: _buildPaletteCard(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaletteCard() {
    return Container(
      width: 560,
      constraints: const BoxConstraints(maxHeight: 520),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0xDD000000),
            blurRadius: 80,
            spreadRadius: -8,
            offset: Offset(0, 32),
          ),
          BoxShadow(
            color: Color(0x18FFFFFF),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSearchRow(),
            const _Divider(),
            Flexible(child: _buildResults()),
            const _Divider(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── search row ────────────────────────────────────────────────────────────

  Widget _buildSearchRow() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: Color(0xFF666666)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _query,
              focusNode: _searchFocus,
              cursorColor: Colors.white,
              cursorWidth: 1.5,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search components…',
                hintStyle: GoogleFonts.inter(
                  fontSize: 15,
                  color: const Color(0xFF555555),
                ),
              ),
              onChanged: (v) {
                setState(() {
                  _rebuild(v.trim().toLowerCase());
                  _staggerCtrl
                    ..reset()
                    ..forward();
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          if (_query.text.isNotEmpty)
            _IconButton(
              icon: Icons.close_rounded,
              onTap: () => setState(() {
                _query.clear();
                _rebuild('');
                _staggerCtrl
                  ..reset()
                  ..forward();
              }),
            )
          else
            _KeyBadge(label: 'ESC', onTap: widget.onClose),
        ],
      ),
    );
  }

  // ── results ───────────────────────────────────────────────────────────────

  Widget _buildResults() {
    if (_entries.isEmpty) return _buildEmpty();

    int itemIndex = 0; // running counter for stagger delay

    return Scrollbar(
      controller: _scroll,
      thumbVisibility: false,
      thickness: 3,
      radius: const Radius.circular(3),
      child: ListView.builder(
        controller: _scroll,
        shrinkWrap: true,
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        itemCount: _entries.length,
        itemBuilder: (ctx, i) {
          final entry = _entries[i];

          if (!entry.isItem) {
            return _SectionHeader(title: entry.sectionTitle!);
          }

          final delay = itemIndex++ * 0.06;
          final start = delay.clamp(0.0, 0.85);
          final end = (start + 0.35).clamp(0.0, 1.0);
          final itemAnim = CurvedAnimation(
            parent: _staggerCtrl,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          );

          return _ItemRow(
            item: entry.item!,
            sectionName: entry.itemSection!,
            selected: i == _selectedEntry,
            query: _query.text.trim().toLowerCase(),
            animation: itemAnim,
            onTap: () => widget.onSelect(entry.item!),
            onHover: (on) {
              if (on) setState(() => _selectedEntry = i);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded,
              size: 32, color: Color(0xFF333333)),
          const SizedBox(height: 14),
          Text(
            'No results for "${_query.text.trim()}"',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF555555),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different keyword.',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF3A3A3A)),
          ),
        ],
      ),
    );
  }

  // ── footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF0D0D0D),
      child: Row(
        children: [
          _FooterHint(icon: Icons.arrow_upward_rounded, label: ''),
          const SizedBox(width: 3),
          _FooterHint(icon: Icons.arrow_downward_rounded, label: 'Navigate'),
          const SizedBox(width: 14),
          _FooterHint(icon: Icons.keyboard_return_rounded, label: 'Open'),
          const SizedBox(width: 14),
          _FooterHint(icon: Icons.close, label: 'Close'),
          const Spacer(),
          Text(
            'WidgetUI',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: const Color(0xFF3A3A3A),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── sub-widgets ─────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: Color(0x1AFFFFFF));
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          letterSpacing: 1.4,
          color: const Color(0xFF444444),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.sectionName,
    required this.selected,
    required this.query,
    required this.animation,
    required this.onTap,
    required this.onHover,
  });

  final SidebarItem item;
  final String sectionName;
  final bool selected;
  final String query;
  final Animation<double> animation;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  List<InlineSpan> _highlight(TextStyle base, TextStyle hi) {
    final text = item.label;
    final q = query;
    if (q.isEmpty) return [TextSpan(text: text, style: base)];
    final i = text.toLowerCase().indexOf(q);
    if (i < 0) return [TextSpan(text: text, style: base)];
    return [
      if (i > 0) TextSpan(text: text.substring(0, i), style: base),
      TextSpan(text: text.substring(i, i + q.length), style: hi),
      TextSpan(text: text.substring(i + q.length), style: base),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.inter(
      fontSize: 13.5,
      color: selected ? Colors.white : const Color(0xFF999999),
      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
    );
    final hi = base.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      backgroundColor: const Color(0x22FFFFFF),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(animation),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => onHover(true),
          onExit: (_) => onHover(false),
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF1C1C1C)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? const Color(0x22FFFFFF)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  // ── icon box ─────────────────────────────────────────
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF2C2C2C)
                          : const Color(0xFF181818),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: selected
                            ? const Color(0x33FFFFFF)
                            : const Color(0x14FFFFFF),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.widgets_outlined,
                        size: 14,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF555555),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ── label ─────────────────────────────────────────────
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: _highlight(base, hi)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ── section chip ──────────────────────────────────────
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: const Color(0x14FFFFFF),
                      ),
                    ),
                    child: Text(
                      sectionName,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: selected
                            ? const Color(0xFF888888)
                            : const Color(0xFF555555),
                      ),
                    ),
                  ),
                  // ── enter badge (selected only) ───────────────────────
                  AnimatedSize(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    child: selected
                        ? Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(5),
                                border:
                                    Border.all(color: const Color(0x14FFFFFF)),
                              ),
                              child: const Icon(
                                Icons.keyboard_return_rounded,
                                size: 11,
                                color: Color(0xFF555555),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── tiny shared widgets ─────────────────────────────────────────────────────

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: const Color(0xFF666666)),
      ),
    );
  }
}

class _KeyBadge extends StatelessWidget {
  const _KeyBadge({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0x14FFFFFF)),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: const Color(0xFF555555),
          ),
        ),
      ),
    );
  }
}

class _FooterHint extends StatelessWidget {
  const _FooterHint({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0x14FFFFFF)),
          ),
          child: Icon(icon, size: 11, color: const Color(0xFF444444)),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF444444),
            ),
          ),
        ],
      ],
    );
  }
}
