// props_table.dart
//
// Reusable API table for component docs: Name | Type | Default | Description.
//
//   PropsTable(
//     props: const [
//       PropSpec(
//         name: 'size',
//         type: 'double',
//         defaultValue: '256',
//         description: 'Width and height of the card area.',
//       ),
//       PropSpec(
//         name: 'slides',
//         type: 'List<CarouselSlide>?',
//         description: 'Defaults to six photos.',
//         group: 'Content',
//       ),
//     ],
//   )
//
// - Wide: real columns. Narrow (< breakpoint): stacked entries.
// - Type chips are tinted by kind (bool, number, String, Color, Widget...).
// - `backticks` in descriptions render as inline code.
// - Hover a row to reveal a copy-name button. Optional live search.
// - Optional group headings (set `group` on props).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _panelBg = Color(0xFF0B0B0B);
const Color _inner = Color(0xFF000000);
const Color _border = Color(0x1AFFFFFF);
const Color _divider = Color(0x0FFFFFFF);
const Color _muted = Color(0xFF8A8A8A);
const Color _body = Color(0xFFA1A1A1);

/// One documented property.
@immutable
class PropSpec {
  const PropSpec({
    required this.name,
    required this.type,
    this.defaultValue,
    this.description = '',
    this.required = false,
    this.group,
    this.typeColor,
    this.defaultColor,
  });

  final String name;
  final String type;

  /// Shown as code. Null renders an em dash.
  final String? defaultValue;

  /// Supports `inline code` with backticks.
  final String description;
  final bool required;

  /// Heading shown above the first prop of each group.
  final String? group;

  /// Override the automatic chip color.
  final Color? typeColor;

  /// Color swatch for the default value. Usually not needed: color literals
  /// such as `Color(0xFF3F3F46)`, `Colors.white` or `#3F3F46` are detected
  /// from [defaultValue] automatically.
  final Color? defaultColor;
}

class PropsTable extends StatefulWidget {
  const PropsTable({
    super.key,
    required this.props,
    this.title = 'Props',
    this.showSearch,
    this.breakpoint = 680,
  });

  final List<PropSpec> props;
  final String title;

  /// Search box. Default: shown when there are more than 6 props.
  final bool? showSearch;

  /// Below this width the table switches to stacked entries.
  final double breakpoint;

  @override
  State<PropsTable> createState() => _PropsTableState();
}

class _PropsTableState extends State<PropsTable> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<PropSpec> get _filtered {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return widget.props;
    return widget.props
        .where((p) =>
    p.name.toLowerCase().contains(q) ||
        p.type.toLowerCase().contains(q) ||
        p.description.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final showSearch = widget.showSearch ?? widget.props.length > 6;
    final rows = _filtered;

    return Container(
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= widget.breakpoint;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TitleBar(
                title: widget.title,
                count: widget.props.length,
                controller: showSearch ? _query : null,
                onChanged: () => setState(() {}),
              ),
              Container(height: 1, color: _border),
              if (wide) const _ColumnHeader(),
              if (wide) Container(height: 1, color: _border),
              if (rows.isEmpty)
                _Empty(
                  query: _query.text.trim(),
                  onClear: () => setState(_query.clear),
                )
              else
                ..._buildRows(rows, wide),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildRows(List<PropSpec> rows, bool wide) {
    final out = <Widget>[];
    String? lastGroup;
    for (var i = 0; i < rows.length; i++) {
      final p = rows[i];
      if (p.group != null && p.group != lastGroup) {
        out.add(_GroupLabel(p.group!));
      }
      lastGroup = p.group ?? lastGroup;

      out.add(wide ? _WideRow(prop: p) : _StackedRow(prop: p));

      final isLast = i == rows.length - 1;
      final nextStartsGroup =
          !isLast && rows[i + 1].group != null && rows[i + 1].group != lastGroup;
      if (!isLast && !nextStartsGroup) {
        out.add(Container(height: 1, color: _divider));
      }
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// header pieces
// ---------------------------------------------------------------------------

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.title,
    required this.count,
    required this.controller,
    required this.onChanged,
  });

  final String title;
  final int count;
  final TextEditingController? controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.jetBrainsMono(fontSize: 10, color: _muted),
            ),
          ),
          const Spacer(),
          if (controller != null)
            SizedBox(
              width: 220,
              child: _SearchBox(controller: controller!, onChanged: onChanged),
            ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _inner,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 14, color: _muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              cursorColor: Colors.white,
              cursorWidth: 1.2,
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: Colors.white),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Filter props',
                hintStyle:
                GoogleFonts.jetBrainsMono(fontSize: 11, color: _muted),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            InkResponse(
              onTap: () {
                controller.clear();
                onChanged();
              },
              radius: 12,
              child: const Icon(Icons.close_rounded, size: 13, color: _muted),
            ),
        ],
      ),
    );
  }
}

// Shared column flex so header and rows line up.
const int _fName = 22;
const int _fType = 22;
const int _fDefault = 14;
const int _fDesc = 42;
const EdgeInsets _rowPad = EdgeInsets.symmetric(horizontal: 16, vertical: 14);

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader();

  @override
  Widget build(BuildContext context) {
    Widget h(String t, int flex) => Expanded(
      flex: flex,
      child: Text(
        t.toUpperCase(),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          letterSpacing: 1.2,
          color: _muted,
        ),
      ),
    );

    return Container(
      color: const Color(0x06FFFFFF),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          h('Name', _fName),
          h('Type', _fType),
          h('Default', _fDefault),
          h('Description', _fDesc),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0x05FFFFFF),
        border: Border.symmetric(horizontal: BorderSide(color: _divider)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          letterSpacing: 1.2,
          color: Colors.white54,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 22, color: _muted),
          const SizedBox(height: 10),
          Text(
            'No props match "$query"',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onClear,
            child: Text(
              'Clear filter',
              style: GoogleFonts.jetBrainsMono(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// rows
// ---------------------------------------------------------------------------

class _WideRow extends StatefulWidget {
  const _WideRow({required this.prop});

  final PropSpec prop;

  @override
  State<_WideRow> createState() => _WideRowState();
}

class _WideRowState extends State<_WideRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.prop;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        container: true,
        label: '${p.name}, ${p.type}, default ${p.defaultValue ?? 'none'}. '
            '${p.description}',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hover ? const Color(0x08FFFFFF) : Colors.transparent,
          padding: _rowPad,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: _fName,
                child: _NameCell(prop: p, showCopy: _hover),
              ),
              Expanded(
                flex: _fType,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _TypeChip(type: p.type, color: p.typeColor),
                  ),
                ),
              ),
              Expanded(
                flex: _fDefault,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _DefaultValue(
                      value: p.defaultValue,
                      color: p.defaultColor,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: _fDesc,
                child: _Description(text: p.description),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StackedRow extends StatelessWidget {
  const _StackedRow({required this.prop});

  final PropSpec prop;

  @override
  Widget build(BuildContext context) {
    final p = prop;
    return Semantics(
      container: true,
      label: '${p.name}, ${p.type}, default ${p.defaultValue ?? 'none'}. '
          '${p.description}',
      child: Padding(
        padding: _rowPad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NameCell(prop: p, showCopy: true),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _TypeChip(type: p.type, color: p.typeColor),
                if (p.defaultValue != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'default',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: _muted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _DefaultValue(
                        value: p.defaultValue,
                        color: p.defaultColor,
                      ),
                    ],
                  ),
              ],
            ),
            if (p.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              _Description(text: p.description),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// cells
// ---------------------------------------------------------------------------

class _NameCell extends StatefulWidget {
  const _NameCell({required this.prop, required this.showCopy});

  final PropSpec prop;
  final bool showCopy;

  @override
  State<_NameCell> createState() => _NameCellState();
}

class _NameCellState extends State<_NameCell> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.prop.name));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prop;
    final visible = widget.showCopy || _copied;
    return Row(
      children: [
        Flexible(
          child: Text(
            p.name,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        if (p.required) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: 'Required',
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFFFCA5A5),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
        const SizedBox(width: 6),
        AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 120),
          child: InkResponse(
            onTap: visible ? _copy : null,
            radius: 12,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 12,
                color: _copied ? const Color(0xFF4ADE80) : _muted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type, this.color});

  final String type;
  final Color? color;

  static Color _auto(String type) {
    final s = type.toLowerCase();
    if (s.startsWith('bool')) return const Color(0xFFC4A7FF);
    if (s.startsWith('double') ||
        s.startsWith('int') ||
        s.startsWith('num') ||
        s.startsWith('duration')) {
      return const Color(0xFFF5C07A);
    }
    if (s.startsWith('string')) return const Color(0xFF9FE3B0);
    if (s.startsWith('color')) return const Color(0xFFF9A8D4);
    if (s.contains('widget')) return const Color(0xFF7DD3FC);
    if (s.contains('callback') ||
        s.contains('valuechanged') ||
        s.contains('function') ||
        s.startsWith('void')) {
      return const Color(0xFFFDBA74);
    }
    if (s.startsWith('list') || s.startsWith('map') || s.startsWith('set')) {
      return const Color(0xFF5EEAD4);
    }
    return const Color(0xFFA5B4FC); // enums and other classes
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? _auto(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.24)),
      ),
      child: Text(
        type,
        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: c, height: 1.2),
      ),
    );
  }
}

class _DefaultValue extends StatelessWidget {
  const _DefaultValue({required this.value, this.color});

  final String? value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          '\u2014',
          style: GoogleFonts.jetBrainsMono(fontSize: 12, color: _muted),
        ),
      );
    }

    final swatch = color ?? _parseColor(value!);
    final label = swatch != null ? _colorLabel(swatch) : value!;

    return Tooltip(
      message: value!,
      waitDuration: const Duration(milliseconds: 500),
      child: Container(
        padding: EdgeInsets.fromLTRB(swatch != null ? 5 : 7, 3, 7, 3),
        decoration: BoxDecoration(
          color: const Color(0x0FFFFFFF),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (swatch != null) ...[
              _Swatch(color: swatch),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: Colors.white70,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// color swatch + parsing
// ---------------------------------------------------------------------------

/// Small rounded color box. A checkerboard shows through transparent colors.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0x40FFFFFF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (color.a < 1) CustomPaint(painter: _CheckerPainter()),
            ColoredBox(color: color),
          ],
        ),
      ),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 3.5;
    final light = Paint()..color = const Color(0xFFBDBDBD);
    final dark = Paint()..color = const Color(0xFF6B6B6B);
    canvas.drawRect(Offset.zero & size, light);
    for (var y = 0; y * cell < size.height; y++) {
      for (var x = 0; x * cell < size.width; x++) {
        if ((x + y).isOdd) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), dark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// "#3F3F46", "#3F3F46 \u00B7 50%" or "transparent".
String _colorLabel(Color c) {
  final argb = c.toARGB32();
  final a = (argb >> 24) & 0xFF;
  if (a == 0) return 'transparent';
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  if (a == 255) return '#$rgb';
  return '#$rgb \u00B7 ${(a / 255 * 100).round()}%';
}

const Map<String, int> _namedColors = {
  'white': 0xFFFFFFFF,
  'black': 0xFF000000,
  'transparent': 0x00000000,
  'white70': 0xB3FFFFFF,
  'white60': 0x99FFFFFF,
  'white54': 0x8AFFFFFF,
  'white38': 0x62FFFFFF,
  'white30': 0x4DFFFFFF,
  'white24': 0x3DFFFFFF,
  'white12': 0x1FFFFFFF,
  'white10': 0x1AFFFFFF,
  'black87': 0xDD000000,
  'black54': 0x8A000000,
  'black45': 0x73000000,
  'black38': 0x61000000,
  'black26': 0x42000000,
  'black12': 0x1F000000,
  'red': 0xFFF44336,
  'pink': 0xFFE91E63,
  'purple': 0xFF9C27B0,
  'deepPurple': 0xFF673AB7,
  'indigo': 0xFF3F51B5,
  'blue': 0xFF2196F3,
  'cyan': 0xFF00BCD4,
  'teal': 0xFF009688,
  'green': 0xFF4CAF50,
  'yellow': 0xFFFFEB3B,
  'amber': 0xFFFFC107,
  'orange': 0xFFFF9800,
  'grey': 0xFF9E9E9E,
};

/// Understands the color literals people write in docs:
///   Color(0xFF3F3F46)   const Color(0x1AFFFFFF)
///   Color.fromARGB(255, 63, 63, 70)   Color.fromRGBO(63, 63, 70, 0.5)
///   Colors.white   Colors.white70   #3F3F46   #3F3F4680 (CSS RRGGBBAA)
/// Returns null when [input] is not a color.
Color? _parseColor(String input) {
  var s = input.trim();
  if (s.startsWith('const ')) s = s.substring(6).trim();

  final hex = RegExp(r'^Color\(\s*0x([0-9a-fA-F]{8})\s*\)$').firstMatch(s);
  if (hex != null) return Color(int.parse(hex.group(1)!, radix: 16));

  final css = RegExp(r'^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$').firstMatch(s);
  if (css != null) {
    final rgb = int.parse(css.group(1)!, radix: 16);
    final a = css.group(2) == null ? 0xFF : int.parse(css.group(2)!, radix: 16);
    return Color((a << 24) | rgb);
  }

  final argb = RegExp(
    r'^Color\.fromARGB\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)$',
  ).firstMatch(s);
  if (argb != null) {
    int g(int i) => int.parse(argb.group(i)!).clamp(0, 255);
    return Color.fromARGB(g(1), g(2), g(3), g(4));
  }

  final rgbo = RegExp(
    r'^Color\.fromRGBO\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)$',
  ).firstMatch(s);
  if (rgbo != null) {
    int g(int i) => int.parse(rgbo.group(i)!).clamp(0, 255);
    final o = (double.tryParse(rgbo.group(4)!) ?? 1).clamp(0.0, 1.0);
    return Color.fromRGBO(g(1), g(2), g(3), o);
  }

  final named = RegExp(r'^Colors\.(\w+)$').firstMatch(s);
  if (named != null) {
    final v = _namedColors[named.group(1)!];
    if (v != null) return Color(v);
  }
  return null;
}

class _Description extends StatelessWidget {
  const _Description({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.inter(fontSize: 13, height: 1.55, color: _body);
    final code = GoogleFonts.jetBrainsMono(
      fontSize: 11.5,
      color: Colors.white,
      backgroundColor: const Color(0x14FFFFFF),
    );

    // `inline code` -> mono chip
    final parts = text.split('`');
    final spans = <InlineSpan>[
      for (var i = 0; i < parts.length; i++)
        TextSpan(text: parts[i], style: i.isOdd ? code : base),
    ];
    return Text.rich(TextSpan(children: spans, style: base));
  }
}