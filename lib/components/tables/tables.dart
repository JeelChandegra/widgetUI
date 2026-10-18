// animated_data_table.dart
//
// AnimatedDataTable: a fully themeable, animated table. Flutter SDK only.
//
// Quick start (default look = premium dark preset from the reference):
//
//   AnimatedDataTable<Food>(
//     items: foods,
//     rowKey: (f) => f.id,
//     onDelete: (f) => setState(() => foods.remove(f)), // table animates it out
//     columns: [
//       AnimatedDataColumn<Food>(
//         id: 'food', label: 'Food',
//         valueText: (f) => f.name,
//         sortValue: (f) => f.name,
//         width: const AnimatedDataColumnWidth.flex(flex: 2),
//       ),
//       AnimatedDataColumn<Food>(
//         id: 'qty', label: 'Quantity', secondary: true,
//         valueText: (f) => f.quantity, sortValue: (f) => f.quantity,
//       ),
//       AnimatedDataColumn<Food>(
//         id: 'kcal', label: 'Calories', secondary: true,
//         alignment: Alignment.centerRight,
//         valueText: (f) => '${f.calories}', sortValue: (f) => f.calories,
//       ),
//     ],
//   )
//
// Theming layers (later wins, only set what you want to change):
//   1. Preset by Theme.of(context).brightness (AnimatedDataTableTheme.dark/light)
//   2. ThemeData.extensions: [AnimatedDataTableTheme(...)]   (app-wide)
//   3. AnimatedDataTable(theme: AnimatedDataTableTheme(...))  (per table)
//   4. Per column: AnimatedDataColumn(textStyle, textColor, padding, ...)
//   5. Per row: rowDecorationBuilder
//   6. Per cell: AnimatedDataColumn.cellBuilder
//
// Example overrides:
//   theme: AnimatedDataTableTheme(
//     colors: AnimatedDataTableColors(background: Color(0xFF101820)),
//     layout: AnimatedDataTableLayout(rowHeight: 48, density: AnimatedDataDensity.compact),
//     animation: AnimatedDataTableAnimation(enabled: false),
//   )
//   theme: AnimatedDataTableTheme.fromColorScheme(Theme.of(context).colorScheme)
//
// Needs a bounded width. Height is intrinsic (works inside ListView/Column).

import 'dart:math' as math;

import 'package:flutter/material.dart';

// ===========================================================================
// Theme
// ===========================================================================

enum AnimatedDataDensity {
  compact(0.8),
  standard(1),
  spacious(1.2);

  const AnimatedDataDensity(this.scale);
  final double scale;
}

TextStyle? _mergeStyle(TextStyle? a, TextStyle? b) => a == null ? b : a.merge(b);

/// Every color. All nullable: unset values fall back to the dark/light preset.
@immutable
class AnimatedDataTableColors {
  const AnimatedDataTableColors({
    this.pageBackground,
    this.background,
    this.headerBackground,
    this.primaryText,
    this.secondaryText,
    this.headerText,
    this.sortActive,
    this.sortInactive,
    this.divider,
    this.rowHover,
    this.rowSelected,
    this.rowPressed,
    this.border,
    this.deleteIcon,
    this.actionIcon,
    this.loadingIndicator,
    this.emptyIcon,
    this.emptyText,
    this.stripe,
  });

  /// Not painted by the table. Handy for the page/scaffold behind it.
  final Color? pageBackground;
  final Color? background;
  final Color? headerBackground;
  final Color? primaryText;
  final Color? secondaryText;
  final Color? headerText;
  final Color? sortActive;
  final Color? sortInactive;
  final Color? divider;
  final Color? rowHover;
  final Color? rowSelected;
  final Color? rowPressed;
  final Color? border;
  final Color? deleteIcon;
  final Color? actionIcon;
  final Color? loadingIndicator;
  final Color? emptyIcon;
  final Color? emptyText;

  /// Background of odd rows when `layout.stripedRows` is on.
  final Color? stripe;

  static const dark = AnimatedDataTableColors(
    pageBackground: Color(0xFF0B0B0D),
    background: Color(0xFF171719),
    headerBackground: Color(0x00000000),
    primaryText: Color(0xFFECECEE),
    secondaryText: Color(0xFF9A9A9F),
    headerText: Color(0xFF8A8A8E),
    sortActive: Color(0xFFF2F2F4),
    sortInactive: Color(0xFF6B6B70),
    divider: Color(0xFF29292B),
    rowHover: Color(0x0AFFFFFF),
    rowSelected: Color(0x14FFFFFF),
    rowPressed: Color(0x1AFFFFFF),
    border: Color(0xFF262629),
    deleteIcon: Color(0xFFFF2638),
    actionIcon: Color(0xFF8A8A8E),
    loadingIndicator: Color(0xFFECECEE),
    emptyIcon: Color(0xFF5A5A5F),
    emptyText: Color(0xFF8A8A8E),
    stripe: Color(0x08FFFFFF),
  );

  static const light = AnimatedDataTableColors(
    pageBackground: Color(0xFFF5F5F7),
    background: Color(0xFFFFFFFF),
    headerBackground: Color(0x00000000),
    primaryText: Color(0xFF1C1C1E),
    secondaryText: Color(0xFF6E6E73),
    headerText: Color(0xFF6E6E73),
    sortActive: Color(0xFF1C1C1E),
    sortInactive: Color(0xFFA1A1A6),
    divider: Color(0xFFE8E8EA),
    rowHover: Color(0x0A000000),
    rowSelected: Color(0x12000000),
    rowPressed: Color(0x18000000),
    border: Color(0xFFE5E5E7),
    deleteIcon: Color(0xFFFF2638),
    actionIcon: Color(0xFF6E6E73),
    loadingIndicator: Color(0xFF1C1C1E),
    emptyIcon: Color(0xFFC7C7CC),
    emptyText: Color(0xFF8E8E93),
    stripe: Color(0x06000000),
  );

  /// Derives the main colors from a [ColorScheme]; the rest use the preset.
  factory AnimatedDataTableColors.fromColorScheme(ColorScheme s) => AnimatedDataTableColors(
    pageBackground: s.surface,
    background: s.surfaceContainer,
    headerText: s.onSurfaceVariant,
    primaryText: s.onSurface,
    secondaryText: s.onSurfaceVariant,
    sortActive: s.onSurface,
    sortInactive: s.outline,
    divider: s.outlineVariant,
    border: s.outlineVariant,
    rowHover: s.onSurface.withValues(alpha: 0.05),
    rowSelected: s.primary.withValues(alpha: 0.12),
    rowPressed: s.onSurface.withValues(alpha: 0.10),
    deleteIcon: s.error,
    actionIcon: s.onSurfaceVariant,
    loadingIndicator: s.primary,
    emptyIcon: s.outline,
    emptyText: s.onSurfaceVariant,
    stripe: s.onSurface.withValues(alpha: 0.03),
  );

  AnimatedDataTableColors merge(AnimatedDataTableColors? o) => o == null
      ? this
      : AnimatedDataTableColors(
          pageBackground: o.pageBackground ?? pageBackground,
          background: o.background ?? background,
          headerBackground: o.headerBackground ?? headerBackground,
          primaryText: o.primaryText ?? primaryText,
          secondaryText: o.secondaryText ?? secondaryText,
          headerText: o.headerText ?? headerText,
          sortActive: o.sortActive ?? sortActive,
          sortInactive: o.sortInactive ?? sortInactive,
          divider: o.divider ?? divider,
          rowHover: o.rowHover ?? rowHover,
          rowSelected: o.rowSelected ?? rowSelected,
          rowPressed: o.rowPressed ?? rowPressed,
          border: o.border ?? border,
          deleteIcon: o.deleteIcon ?? deleteIcon,
          actionIcon: o.actionIcon ?? actionIcon,
          loadingIndicator: o.loadingIndicator ?? loadingIndicator,
          emptyIcon: o.emptyIcon ?? emptyIcon,
          emptyText: o.emptyText ?? emptyText,
          stripe: o.stripe ?? stripe,
        );
}

/// Text styles. Colors come from [AnimatedDataTableColors] unless the style
/// sets its own. Styles merge: `TextStyle(fontSize: 16)` keeps other defaults.
@immutable
class AnimatedDataTableTypography {
  const AnimatedDataTableTypography({this.fontFamily, this.header, this.primary, this.secondary, this.status, this.action, this.headerUppercase});

  /// Applied to every style that has no family of its own.
  final String? fontFamily;
  final TextStyle? header;
  final TextStyle? primary;
  final TextStyle? secondary;

  /// For status labels / badges ([AnimatedDataBadge]).
  final TextStyle? status;

  /// For action buttons in custom cells.
  final TextStyle? action;
  final bool? headerUppercase;

  static const base = AnimatedDataTableTypography(
    header: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, letterSpacing: 0.8, height: 1.2),
    primary: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, letterSpacing: -0.1, height: 1.3),
    secondary: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w400, height: 1.3),
    status: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2),
    action: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    headerUppercase: true,
  );

  /// Project-wide typography from a [TextTheme].
  factory AnimatedDataTableTypography.fromTextTheme(TextTheme t) => AnimatedDataTableTypography(
    header: t.labelSmall,
    primary: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    secondary: t.bodyMedium,
    status: t.labelMedium,
    action: t.labelLarge,
  );

  AnimatedDataTableTypography merge(AnimatedDataTableTypography? o) => o == null
      ? this
      : AnimatedDataTableTypography(
          fontFamily: o.fontFamily ?? fontFamily,
          header: _mergeStyle(header, o.header),
          primary: _mergeStyle(primary, o.primary),
          secondary: _mergeStyle(secondary, o.secondary),
          status: _mergeStyle(status, o.status),
          action: _mergeStyle(action, o.action),
          headerUppercase: o.headerUppercase ?? headerUppercase,
        );
}

/// Sizes, spacing, radii.
@immutable
class AnimatedDataTableLayout {
  const AnimatedDataTableLayout({
    this.borderRadius,
    this.cellPadding,
    this.rowHeight,
    this.headerHeight,
    this.borderWidth,
    this.dividerWidth,
    this.columnSpacing,
    this.density,
    this.stripedRows,
    this.showLastDivider,
    this.iconSize,
    this.iconSpacing,
    this.actionButtonSize,
    this.actionColumnWidth,
    this.leadingWidth,
  });

  /// Individual corners supported (`BorderRadius.only(...)`).
  final BorderRadius? borderRadius;

  /// Horizontal and vertical padding of every cell.
  final EdgeInsets? cellPadding;
  final double? rowHeight;
  final double? headerHeight;

  /// Outer border thickness. 0 = no border.
  final double? borderWidth;
  final double? dividerWidth;
  final double? columnSpacing;

  /// Scales row/header height and horizontal padding.
  final AnimatedDataDensity? density;
  final bool? stripedRows;
  final bool? showLastDivider;
  final double? iconSize;

  /// Gap between header label and sort icon.
  final double? iconSpacing;
  final double? actionButtonSize;
  final double? actionColumnWidth;
  final double? leadingWidth;

  static const base = AnimatedDataTableLayout(
    borderRadius: BorderRadius.all(Radius.circular(16)),
    cellPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    rowHeight: 57,
    headerHeight: 52,
    borderWidth: 1,
    dividerWidth: 1,
    columnSpacing: 0,
    density: AnimatedDataDensity.standard,
    stripedRows: false,
    showLastDivider: false,
    iconSize: 18,
    iconSpacing: 6,
    actionButtonSize: 36,
    actionColumnWidth: 64,
    leadingWidth: 48,
  );

  AnimatedDataTableLayout merge(AnimatedDataTableLayout? o) => o == null
      ? this
      : AnimatedDataTableLayout(
          borderRadius: o.borderRadius ?? borderRadius,
          cellPadding: o.cellPadding ?? cellPadding,
          rowHeight: o.rowHeight ?? rowHeight,
          headerHeight: o.headerHeight ?? headerHeight,
          borderWidth: o.borderWidth ?? borderWidth,
          dividerWidth: o.dividerWidth ?? dividerWidth,
          columnSpacing: o.columnSpacing ?? columnSpacing,
          density: o.density ?? density,
          stripedRows: o.stripedRows ?? stripedRows,
          showLastDivider: o.showLastDivider ?? showLastDivider,
          iconSize: o.iconSize ?? iconSize,
          iconSpacing: o.iconSpacing ?? iconSpacing,
          actionButtonSize: o.actionButtonSize ?? actionButtonSize,
          actionColumnWidth: o.actionColumnWidth ?? actionColumnWidth,
          leadingWidth: o.leadingWidth ?? leadingWidth,
        );
}

/// Durations, curve and per-animation switches.
@immutable
class AnimatedDataTableAnimation {
  const AnimatedDataTableAnimation({
    this.enabled,
    this.curve,
    this.rowEntrance,
    this.rowDeletion,
    this.sorting,
    this.tableAppearance,
    this.rowEntranceDuration,
    this.rowDeletionDuration,
    this.sortDuration,
    this.tableAppearanceDuration,
    this.hoverDuration,
    this.pressedDuration,
    this.entranceStagger,
  });

  /// Global switch. Also off when the OS asks for reduced motion.
  final bool? enabled;
  final Curve? curve;
  final bool? rowEntrance;
  final bool? rowDeletion;
  final bool? sorting;
  final bool? tableAppearance;
  final Duration? rowEntranceDuration;
  final Duration? rowDeletionDuration;
  final Duration? sortDuration;
  final Duration? tableAppearanceDuration;
  final Duration? hoverDuration;
  final Duration? pressedDuration;

  /// Delay between rows on the first appearance.
  final Duration? entranceStagger;

  static const base = AnimatedDataTableAnimation(
    enabled: true,
    curve: Curves.easeOutCubic,
    rowEntrance: true,
    rowDeletion: true,
    sorting: true,
    tableAppearance: true,
    rowEntranceDuration: Duration(milliseconds: 320),
    rowDeletionDuration: Duration(milliseconds: 240),
    sortDuration: Duration(milliseconds: 380),
    tableAppearanceDuration: Duration(milliseconds: 420),
    hoverDuration: Duration(milliseconds: 140),
    pressedDuration: Duration(milliseconds: 80),
    entranceStagger: Duration(milliseconds: 35),
  );

  AnimatedDataTableAnimation merge(AnimatedDataTableAnimation? o) => o == null
      ? this
      : AnimatedDataTableAnimation(
          enabled: o.enabled ?? enabled,
          curve: o.curve ?? curve,
          rowEntrance: o.rowEntrance ?? rowEntrance,
          rowDeletion: o.rowDeletion ?? rowDeletion,
          sorting: o.sorting ?? sorting,
          tableAppearance: o.tableAppearance ?? tableAppearance,
          rowEntranceDuration: o.rowEntranceDuration ?? rowEntranceDuration,
          rowDeletionDuration: o.rowDeletionDuration ?? rowDeletionDuration,
          sortDuration: o.sortDuration ?? sortDuration,
          tableAppearanceDuration: o.tableAppearanceDuration ?? tableAppearanceDuration,
          hoverDuration: o.hoverDuration ?? hoverDuration,
          pressedDuration: o.pressedDuration ?? pressedDuration,
          entranceStagger: o.entranceStagger ?? entranceStagger,
        );
}

/// Complete table theme. Usable as a [ThemeExtension]:
/// `ThemeData(extensions: [AnimatedDataTableTheme(...)])`.
@immutable
class AnimatedDataTableTheme extends ThemeExtension<AnimatedDataTableTheme> {
  const AnimatedDataTableTheme({
    this.colors = const AnimatedDataTableColors(),
    this.typography = const AnimatedDataTableTypography(),
    this.layout = const AnimatedDataTableLayout(),
    this.animation = const AnimatedDataTableAnimation(),
  });

  final AnimatedDataTableColors colors;
  final AnimatedDataTableTypography typography;
  final AnimatedDataTableLayout layout;
  final AnimatedDataTableAnimation animation;

  static const dark = AnimatedDataTableTheme(
    colors: AnimatedDataTableColors.dark,
    typography: AnimatedDataTableTypography.base,
    layout: AnimatedDataTableLayout.base,
    animation: AnimatedDataTableAnimation.base,
  );

  static const light = AnimatedDataTableTheme(
    colors: AnimatedDataTableColors.light,
    typography: AnimatedDataTableTypography.base,
    layout: AnimatedDataTableLayout.base,
    animation: AnimatedDataTableAnimation.base,
  );

  /// Colors (and optionally typography) from Flutter's theme objects.
  factory AnimatedDataTableTheme.fromColorScheme(ColorScheme scheme, {TextTheme? textTheme}) => AnimatedDataTableTheme(
    colors: AnimatedDataTableColors.fromColorScheme(scheme),
    typography: textTheme == null ? const AnimatedDataTableTypography() : AnimatedDataTableTypography.fromTextTheme(textTheme),
  );

  AnimatedDataTableTheme merge(AnimatedDataTableTheme? o) => o == null
      ? this
      : AnimatedDataTableTheme(
          colors: colors.merge(o.colors),
          typography: typography.merge(o.typography),
          layout: layout.merge(o.layout),
          animation: animation.merge(o.animation),
        );

  /// Preset (by brightness) + ThemeData extension + [override].
  static AnimatedDataTableTheme resolve(BuildContext context, [AnimatedDataTableTheme? override]) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return (isDark ? dark : light).merge(theme.extension<AnimatedDataTableTheme>()).merge(override);
  }

  /// Resolved theme of the nearest table. Use inside custom cell builders.
  static AnimatedDataTableTheme of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_ThemeScope>()?.theme ?? resolve(context);

  @override
  AnimatedDataTableTheme copyWith({
    AnimatedDataTableColors? colors,
    AnimatedDataTableTypography? typography,
    AnimatedDataTableLayout? layout,
    AnimatedDataTableAnimation? animation,
  }) => AnimatedDataTableTheme(
    colors: this.colors.merge(colors),
    typography: this.typography.merge(typography),
    layout: this.layout.merge(layout),
    animation: this.animation.merge(animation),
  );

  @override
  AnimatedDataTableTheme lerp(covariant AnimatedDataTableTheme? other, double t) => other == null ? this : (t < 0.5 ? this : other);
}

class _ThemeScope extends InheritedWidget {
  const _ThemeScope({required this.theme, required super.child});
  final AnimatedDataTableTheme theme;

  @override
  bool updateShouldNotify(_ThemeScope old) => old.theme != theme;
}

// ===========================================================================
// Columns
// ===========================================================================

/// Fixed or flexible column width with optional min / max.
@immutable
class AnimatedDataColumnWidth {
  const AnimatedDataColumnWidth.fixed(double width) : fixed = width, flex = 0, min = 0, max = double.infinity;

  const AnimatedDataColumnWidth.flex({this.flex = 1, this.min = 48, this.max = double.infinity}) : fixed = null;

  final double? fixed;
  final double flex;
  final double min;
  final double max;
}

/// State passed to cell builders.
@immutable
class AnimatedDataCellState {
  const AnimatedDataCellState({required this.index, required this.hovered, required this.pressed, required this.selected});
  final int index;
  final bool hovered;
  final bool pressed;
  final bool selected;
}

/// State passed to header builders.
@immutable
class AnimatedDataHeaderState {
  const AnimatedDataHeaderState({required this.sorted, required this.ascending});
  final bool sorted;
  final bool ascending;
}

class AnimatedDataColumn<T> {
  const AnimatedDataColumn({
    required this.id,
    required this.label,
    this.valueText,
    this.cellBuilder,
    this.headerBuilder,
    this.sortValue,
    this.sortable,
    this.width = const AnimatedDataColumnWidth.flex(),
    this.alignment = Alignment.centerLeft,
    this.headerAlignment,
    this.padding,
    this.textStyle,
    this.headerStyle,
    this.textColor,
    this.headerColor,
    this.background,
    this.secondary = false,
  }) : assert(valueText != null || cellBuilder != null, 'Provide valueText or cellBuilder');

  final String id;
  final String label;

  /// Plain text of the cell (also the fallback sort key).
  final String Function(T item)? valueText;

  /// Replaces the default text cell entirely.
  final Widget Function(BuildContext context, T item, AnimatedDataCellState state)? cellBuilder;

  /// Replaces the default header label (sort tap still works).
  final Widget Function(BuildContext context, AnimatedDataHeaderState state)? headerBuilder;

  /// Sort key. Must return values of the same type for every row.
  final Comparable Function(T item)? sortValue;

  /// Defaults to true when [sortValue] is set.
  final bool? sortable;
  final AnimatedDataColumnWidth width;
  final AlignmentGeometry alignment;
  final AlignmentGeometry? headerAlignment;
  final EdgeInsets? padding;

  /// Merged over the primary/secondary style.
  final TextStyle? textStyle;
  final TextStyle? headerStyle;
  final Color? textColor;
  final Color? headerColor;
  final Color? background;

  /// Use the secondary (subdued) text style.
  final bool secondary;

  bool get isSortable => sortable ?? sortValue != null;
}

// ===========================================================================
// Table
// ===========================================================================

class AnimatedDataTable<T extends Object> extends StatefulWidget {
  const AnimatedDataTable({
    super.key,
    required this.items,
    required this.columns,
    this.rowKey,
    this.theme,
    this.onDelete,
    this.deleteIcon,
    this.trailingBuilder,
    this.leadingBuilder,
    this.onRowTap,
    this.selectedKeys,
    this.rowDecorationBuilder,
    this.sortColumnId,
    this.sortAscending = true,
    this.onSortChanged,
    this.loading = false,
    this.loadingBuilder,
    this.emptyBuilder,
    this.emptyText = 'No data',
  });

  final List<T> items;
  final List<AnimatedDataColumn<T>> columns;

  /// Stable identity per item (needed for correct sort/delete animations).
  /// Defaults to the item itself.
  final Object Function(T item)? rowKey;

  /// Per-table overrides, merged over preset + ThemeData extension.
  final AnimatedDataTableTheme? theme;

  /// Shows the default delete button. Remove the item from [items] in your
  /// state; the table animates it out.
  final ValueChanged<T>? onDelete;

  /// Replaces the default trash icon.
  final Widget? deleteIcon;

  /// Replaces the whole trailing action (delete button included).
  final Widget Function(BuildContext context, T item)? trailingBuilder;

  /// Widget in a leading slot before the first column.
  final Widget Function(BuildContext context, T item)? leadingBuilder;
  final ValueChanged<T>? onRowTap;
  final Set<Object>? selectedKeys;

  /// Per-row decoration, e.g. color by status. Hover/selected overlays draw on top.
  final BoxDecoration? Function(T item, int index)? rowDecorationBuilder;

  /// Initial / controlled sort. Changing it from outside updates the table.
  final String? sortColumnId;
  final bool sortAscending;

  /// Called with `(null, true)` when sort is cleared.
  final void Function(String? columnId, bool ascending)? onSortChanged;
  final bool loading;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? emptyBuilder;
  final String emptyText;

  @override
  State<AnimatedDataTable<T>> createState() => _AnimatedDataTableState<T>();
}

class _Entry<T> {
  _Entry(this.key, this.item, this.delay);
  final Object key;
  T item;
  bool removing = false;
  final Duration delay;
}

class _AnimatedDataTableState<T extends Object> extends State<AnimatedDataTable<T>> {
  final List<_Entry<T>> _entries = [];
  String? _sortId;
  bool _asc = true;
  bool _dirty = true;

  @override
  void initState() {
    super.initState();
    _sortId = widget.sortColumnId;
    _asc = widget.sortAscending;
  }

  @override
  void didUpdateWidget(covariant AnimatedDataTable<T> old) {
    super.didUpdateWidget(old);
    _dirty = true;
    if (widget.sortColumnId != old.sortColumnId || widget.sortAscending != old.sortAscending) {
      _sortId = widget.sortColumnId;
      _asc = widget.sortAscending;
    }
  }

  Object _keyOf(T item) => (widget.rowKey ?? (T x) => x)(item);

  /// Diffs [widget.items] against current entries.
  void _sync(Duration stagger, bool animateExit) {
    final first = _entries.isEmpty;
    final old = {for (final e in _entries) e.key: e};
    final next = <_Entry<T>>[];
    final seen = <Object>{};
    var i = 0;
    for (final item in widget.items) {
      final k = _keyOf(item);
      seen.add(k);
      final existing = old[k];
      if (existing != null) {
        existing.item = item;
        existing.removing = false;
        next.add(existing);
      } else {
        final delay = first ? Duration(microseconds: stagger.inMicroseconds * math.min(i, 12)) : Duration.zero;
        next.add(_Entry<T>(k, item, delay));
      }
      i++;
    }
    if (animateExit) {
      for (var j = 0; j < _entries.length; j++) {
        final e = _entries[j];
        if (!seen.contains(e.key)) {
          e.removing = true;
          next.insert(math.min(j, next.length), e);
        }
      }
    }
    _entries
      ..clear()
      ..addAll(next);
  }

  void _onExited(Object key) {
    if (!mounted) return;
    setState(() => _entries.removeWhere((e) => e.key == key && e.removing));
  }

  void _onSort(AnimatedDataColumn<T> col) {
    if (!col.isSortable) return;
    setState(() {
      if (_sortId == col.id) {
        if (_asc) {
          _asc = false;
        } else {
          _sortId = null;
          _asc = true;
        }
      } else {
        _sortId = col.id;
        _asc = true;
      }
    });
    widget.onSortChanged?.call(_sortId, _asc);
  }

  List<_Entry<T>> _ordered() {
    final id = _sortId;
    if (id == null) return _entries;
    final ci = widget.columns.indexWhere((c) => c.id == id);
    if (ci < 0) return _entries;
    final col = widget.columns[ci];
    Comparable keyOf(T x) => col.sortValue?.call(x) ?? col.valueText?.call(x) ?? '';
    final indexed = [for (var i = 0; i < _entries.length; i++) (i, _entries[i])];
    indexed.sort((a, b) {
      var r = Comparable.compare(keyOf(a.$2.item), keyOf(b.$2.item));
      if (!_asc) r = -r;
      return r != 0 ? r : a.$1.compareTo(b.$1); // stable
    });
    return [for (final e in indexed) e.$2];
  }

  List<double> _resolveWidths(double avail, List<AnimatedDataColumn<T>> cols) {
    final w = List<double>.filled(cols.length, 0);
    final open = <int>[];
    var remaining = avail;
    for (var i = 0; i < cols.length; i++) {
      final f = cols[i].width.fixed;
      if (f != null) {
        w[i] = f;
        remaining -= f;
      } else {
        open.add(i);
      }
    }
    double flexSum() => math.max(0.0001, open.fold<double>(0, (s, i) => s + cols[i].width.flex));

    var changed = true;
    while (changed && open.isNotEmpty) {
      changed = false;
      final unit = math.max(0.0, remaining) / flexSum();
      for (final i in open) {
        final cw = cols[i].width;
        final v = unit * cw.flex;
        if (v < cw.min) {
          w[i] = cw.min;
          remaining -= cw.min;
          open.remove(i);
          changed = true;
          break;
        }
        if (v > cw.max) {
          w[i] = cw.max;
          remaining -= cw.max;
          open.remove(i);
          changed = true;
          break;
        }
      }
    }
    if (open.isNotEmpty) {
      final unit = math.max(0.0, remaining) / flexSum();
      for (final i in open) {
        w[i] = unit * cols[i].width.flex;
      }
    }
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final th = AnimatedDataTableTheme.resolve(context, widget.theme);
    final c = th.colors;
    final ty = th.typography;
    final lay = th.layout;
    final an = th.animation;

    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final on = (an.enabled ?? true) && !reduce;
    Duration dur(Duration? v, bool? flag) => on && (flag ?? true) ? (v ?? Duration.zero) : Duration.zero;
    final curve = an.curve ?? Curves.easeOutCubic;
    final entranceD = dur(an.rowEntranceDuration, an.rowEntrance);
    final exitD = dur(an.rowDeletionDuration, an.rowDeletion);
    final sortD = dur(an.sortDuration, an.sorting);
    final appearD = dur(an.tableAppearanceDuration, an.tableAppearance);
    final hoverD = dur(an.hoverDuration, true);
    final pressD = dur(an.pressedDuration, true);
    final stagger = dur(an.entranceStagger, an.rowEntrance);

    if (_dirty) {
      _sync(stagger, exitD > Duration.zero);
      _dirty = false;
    }

    // ---- metrics ----------------------------------------------------------
    final scale = (lay.density ?? AnimatedDataDensity.standard).scale;
    final hScale = 0.5 + 0.5 * scale;
    final rowH = (lay.rowHeight ?? 57) * scale;
    final headerH = (lay.headerHeight ?? 52) * scale;
    final p = lay.cellPadding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    final cellPad = EdgeInsets.fromLTRB(p.left * hScale, p.top, p.right * hScale, p.bottom);
    final bw = lay.borderWidth ?? 1;
    final dw = lay.dividerWidth ?? 1;
    final spacing = lay.columnSpacing ?? 0;
    final iconSize = lay.iconSize ?? 18;
    final cols = widget.columns;
    final hasLeading = widget.leadingBuilder != null;
    final hasTrailing = widget.trailingBuilder != null || widget.onDelete != null;
    final leadW = hasLeading ? (lay.leadingWidth ?? 48) : 0.0;
    final trailW = hasTrailing ? (lay.actionColumnWidth ?? 64) : 0.0;
    final extras = leadW + trailW + spacing * math.max(0, cols.length - 1);

    // ---- styles -----------------------------------------------------------
    TextStyle styled(TextStyle? s, Color? color) {
      var r = s ?? const TextStyle();
      r = r.copyWith(fontFamily: r.fontFamily ?? ty.fontFamily);
      return r.color == null ? r.copyWith(color: color) : r;
    }

    final headerStyle = styled(ty.header, c.headerText);
    final primaryStyle = styled(ty.primary, c.primaryText);
    final secondaryStyle = styled(ty.secondary, c.secondaryText);

    final ordered = _ordered();
    final count = ordered.length;

    // ---- header -----------------------------------------------------------
    Widget headerCell(AnimatedDataColumn<T> col, double width) {
      final active = _sortId == col.id;
      final sortable = col.isSortable;
      final color = active ? c.sortActive! : (col.headerColor ?? headerStyle.color!);
      var style = headerStyle.merge(col.headerStyle);
      if (active) style = style.copyWith(fontWeight: FontWeight.w700);

      final IconData icon = !active ? Icons.swap_vert_rounded : (_asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);

      Widget content;
      if (col.headerBuilder != null) {
        content = col.headerBuilder!(context, AnimatedDataHeaderState(sorted: active, ascending: _asc));
      } else {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: hoverD,
              style: style.copyWith(color: color),
              child: Text((ty.headerUppercase ?? true) ? col.label.toUpperCase() : col.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (sortable) ...[
              SizedBox(width: lay.iconSpacing ?? 6),
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: active ? c.sortActive : c.sortInactive),
                duration: hoverD,
                builder: (_, v, __) => Icon(icon, size: iconSize * 0.7, color: v),
              ),
            ],
          ],
        );
      }

      Widget cell = SizedBox(
        width: width,
        height: headerH,
        child: Padding(
          padding: col.padding ?? cellPad,
          child: Align(alignment: col.headerAlignment ?? col.alignment, child: content),
        ),
      );
      if (sortable) {
        cell = MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _onSort(col), child: cell),
        );
      }
      return cell;
    }

    // ---- body -------------------------------------------------------------
    Widget actionFor(BuildContext ctx, T item) {
      if (widget.trailingBuilder != null) return widget.trailingBuilder!(ctx, item);
      final delColor = c.deleteIcon!;
      return _ActionButton(
        size: lay.actionButtonSize ?? 36,
        hoverColor: delColor.withValues(alpha: 0.12),
        duration: hoverD,
        semanticLabel: 'Delete',
        onTap: () => widget.onDelete!(item),
        child: widget.deleteIcon != null
            ? IconTheme(
                data: IconThemeData(color: delColor, size: iconSize),
                child: widget.deleteIcon!,
              )
            : Icon(Icons.delete_outline_rounded, color: delColor, size: iconSize),
      );
    }

    Widget dataCell(BuildContext ctx, AnimatedDataColumn<T> col, T item, double width, AnimatedDataCellState state) {
      var style = (col.secondary ? secondaryStyle : primaryStyle).merge(col.textStyle);
      if (col.textColor != null) style = style.copyWith(color: col.textColor);
      final Widget child = col.cellBuilder != null
          ? col.cellBuilder!(ctx, item, state)
          : Text(col.valueText!(item), maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
      Widget cell = Padding(
        padding: col.padding ?? cellPad,
        child: Align(
          alignment: col.alignment,
          child: DefaultTextStyle(style: style, child: child),
        ),
      );
      if (col.background != null) cell = ColoredBox(color: col.background!, child: cell);
      return SizedBox(width: width, child: cell);
    }

    Widget rowContent(BuildContext ctx, _Entry<T> e, int index, List<double> widths, bool hovered, bool pressed) {
      final selected = widget.selectedKeys?.contains(e.key) ?? false;
      final striped = (lay.stripedRows ?? false) && index.isOdd;
      final overlay = pressed && widget.onRowTap != null
          ? c.rowPressed
          : selected
          ? c.rowSelected
          : hovered
          ? c.rowHover
          : (striped ? c.stripe : null);
      final isLast = index == count - 1 && !(lay.showLastDivider ?? false);
      final custom = widget.rowDecorationBuilder?.call(e.item, index);
      final state = AnimatedDataCellState(index: index, hovered: hovered, pressed: pressed, selected: selected);

      return DecoratedBox(
        decoration: custom ?? const BoxDecoration(),
        child: AnimatedContainer(
          duration: pressed ? pressD : hoverD,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: overlay,
            border: isLast || dw <= 0
                ? null
                : Border(
                    bottom: BorderSide(color: c.divider!, width: dw),
                  ),
          ),
          child: Row(
            children: [
              if (hasLeading)
                SizedBox(
                  width: leadW,
                  child: Center(child: widget.leadingBuilder!(ctx, e.item)),
                ),
              for (var j = 0; j < cols.length; j++) ...[
                if (j > 0 && spacing > 0) SizedBox(width: spacing),
                dataCell(ctx, cols[j], e.item, widths[j], state),
              ],
              if (hasTrailing)
                SizedBox(
                  width: trailW,
                  child: Center(child: actionFor(ctx, e.item)),
                ),
            ],
          ),
        ),
      );
    }

    Widget body(double contentW, List<double> widths) {
      if (widget.loading) {
        return SizedBox(
          height: rowH * 3,
          width: contentW,
          child: Center(
            child:
                widget.loadingBuilder?.call(context) ??
                SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: c.loadingIndicator)),
          ),
        );
      }
      if (ordered.isEmpty) {
        return SizedBox(
          height: rowH * 3,
          width: contentW,
          child: Center(
            child:
                widget.emptyBuilder?.call(context) ??
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined, size: 32, color: c.emptyIcon),
                    const SizedBox(height: 10),
                    Text(widget.emptyText, style: secondaryStyle.copyWith(color: c.emptyText)),
                  ],
                ),
          ),
        );
      }
      return AnimatedContainer(
        duration: sortD,
        curve: curve,
        width: contentW,
        height: rowH * count,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedPositioned(
                key: ValueKey<Object>(ordered[i].key),
                duration: sortD,
                curve: curve,
                top: i * rowH,
                left: 0,
                width: contentW,
                height: rowH,
                child: _RowShell(
                  removing: ordered[i].removing,
                  delay: ordered[i].delay,
                  entranceDuration: entranceD,
                  exitDuration: exitD,
                  curve: curve,
                  onExited: () => _onExited(ordered[i].key),
                  onTap: widget.onRowTap == null ? null : () => widget.onRowTap!(ordered[i].item),
                  builder: (ctx, hovered, pressed) => rowContent(ctx, ordered[i], i, widths, hovered, pressed),
                ),
              ),
          ],
        ),
      );
    }

    // ---- assemble ---------------------------------------------------------
    final table = LayoutBuilder(
      builder: (context, cons) {
        final outer = cons.hasBoundedWidth ? cons.maxWidth : 640.0;
        final inner = math.max(0.0, outer - 2 * bw);
        final widths = _resolveWidths(inner - extras, cols);
        final total = widths.fold<double>(0, (s, v) => s + v) + extras;
        final contentW = math.max(inner, total);

        final header = Container(
          width: contentW,
          height: headerH,
          decoration: BoxDecoration(
            color: c.headerBackground,
            border: dw > 0
                ? Border(
                    bottom: BorderSide(color: c.divider!, width: dw),
                  )
                : null,
          ),
          child: Row(
            children: [
              if (hasLeading) SizedBox(width: leadW),
              for (var j = 0; j < cols.length; j++) ...[if (j > 0 && spacing > 0) SizedBox(width: spacing), headerCell(cols[j], widths[j])],
              if (hasTrailing) SizedBox(width: trailW),
            ],
          ),
        );

        Widget content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [header, body(contentW, widths)],
        );
        if (total > inner + 0.5) {
          content = SingleChildScrollView(scrollDirection: Axis.horizontal, child: content);
        }

        return Container(
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: lay.borderRadius,
            border: bw > 0 ? Border.all(color: c.border!, width: bw) : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: DefaultTextStyle(style: primaryStyle, child: content),
          ),
        );
      },
    );

    return _ThemeScope(
      theme: th,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: appearD == Duration.zero ? 1.0 : 0.0, end: 1.0),
        duration: appearD,
        curve: curve,
        child: table,
        builder: (_, v, child) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child),
        ),
      ),
    );
  }
}

// ===========================================================================
// Row shell: entrance / exit animation + hover / pressed tracking
// ===========================================================================

class _RowShell extends StatefulWidget {
  const _RowShell({
    required this.removing,
    required this.delay,
    required this.entranceDuration,
    required this.exitDuration,
    required this.curve,
    required this.onExited,
    required this.onTap,
    required this.builder,
  });

  final bool removing;
  final Duration delay;
  final Duration entranceDuration;
  final Duration exitDuration;
  final Curve curve;
  final VoidCallback onExited;
  final VoidCallback? onTap;
  final Widget Function(BuildContext context, bool hovered, bool pressed) builder;

  @override
  State<_RowShell> createState() => _RowShellState();
}

class _RowShellState extends State<_RowShell> with TickerProviderStateMixin {
  late final AnimationController _in;
  late final AnimationController _out;
  late final Animation<double> _inCurve;
  bool _hover = false;
  bool _down = false;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.entranceDuration;
    _in = AnimationController(vsync: this, duration: total);
    _out = AnimationController(vsync: this, duration: widget.exitDuration);
    final start = total == Duration.zero ? 0.0 : widget.delay.inMicroseconds / total.inMicroseconds;
    _inCurve = CurvedAnimation(
      parent: _in,
      curve: Interval(start, 1, curve: widget.curve),
    );
    if (total == Duration.zero) {
      _in.value = 1;
    } else {
      _in.forward();
    }
    if (widget.removing) _startExit();
  }

  @override
  void didUpdateWidget(covariant _RowShell old) {
    super.didUpdateWidget(old);
    if (widget.removing && !old.removing) _startExit();
  }

  void _startExit() {
    if (widget.exitDuration == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onExited();
      });
      return;
    }
    _out.forward().whenComplete(() {
      if (mounted) widget.onExited();
    });
  }

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    return AnimatedBuilder(
      animation: Listenable.merge([_inCurve, _out]),
      child: IgnorePointer(
        ignoring: widget.removing,
        child: MouseRegion(
          cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() {
            _hover = false;
            _down = false;
          }),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onTapDown: interactive ? (_) => setState(() => _down = true) : null,
            onTapUp: interactive ? (_) => setState(() => _down = false) : null,
            onTapCancel: interactive ? () => setState(() => _down = false) : null,
            child: widget.builder(context, _hover, _down),
          ),
        ),
      ),
      builder: (context, child) {
        final i = _inCurve.value;
        final o = _out.value;
        return Opacity(
          opacity: (i * (1 - o)).clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(12 * o, 8 * (1 - i)), child: child),
        );
      },
    );
  }
}

// ===========================================================================
// Small parts
// ===========================================================================

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.size,
    required this.hoverColor,
    required this.duration,
    required this.onTap,
    required this.child,
    this.semanticLabel,
  });

  final double size;
  final Color hoverColor;
  final Duration duration;
  final VoidCallback onTap;
  final Widget child;
  final String? semanticLabel;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() {
          _hover = false;
          _down = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          child: AnimatedContainer(
            duration: widget.duration,
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _hover || _down ? widget.hoverColor : const Color(0x00000000), borderRadius: BorderRadius.circular(10)),
            child: AnimatedScale(scale: _down ? 0.9 : 1, duration: widget.duration, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Status pill using the theme's `typography.status`. Use in cell builders.
class AnimatedDataBadge extends StatelessWidget {
  const AnimatedDataBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  final String label;

  /// Accent. Background is this at low opacity, text uses it fully.
  final Color? color;
  final Color? textColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = AnimatedDataTableTheme.of(context);
    final accent = color ?? t.colors.secondaryText!;
    final style = (t.typography.status ?? const TextStyle()).copyWith(fontFamily: t.typography.fontFamily, color: textColor ?? accent);
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: style),
    );
  }
}

class AnimatedDataTableDemo extends StatefulWidget {
  const AnimatedDataTableDemo({super.key});

  @override
  State<AnimatedDataTableDemo> createState() => _AnimatedDataTableDemoState();
}

class _AnimatedDataTableDemoState extends State<AnimatedDataTableDemo> {
  final List<Food> _foods = [
    const Food(id: 1, name: 'Chicken Breast', quantity: '200g', calories: 330, protein: 62, fat: 7.2, carbs: 0),
    const Food(id: 2, name: 'Greek Yogurt', quantity: '200g', calories: 130, protein: 22, fat: 0.8, carbs: 9),
    const Food(id: 3, name: 'Salmon Fillet', quantity: '170g', calories: 350, protein: 39, fat: 20, carbs: 0),
    const Food(id: 4, name: 'Sweet Potato', quantity: '1 medium', calories: 103, protein: 2.3, fat: 0.1, carbs: 24),
    const Food(id: 5, name: 'Brown Rice', quantity: '1 cup', calories: 216, protein: 5, fat: 1.8, carbs: 45),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedDataTable<Food>(
                items: _foods,
                rowKey: (food) => food.id,

                onDelete: (food) {
                  setState(() {
                    _foods.removeWhere((item) => item.id == food.id);
                  });
                },

                theme: const AnimatedDataTableTheme(
                  colors: AnimatedDataTableColors(
                    pageBackground: Color(0xFF0B0B0D),
                    background: Color(0xFF171719),
                    primaryText: Color(0xFFECECEE),
                    secondaryText: Color(0xFF9A9A9F),
                    headerText: Color(0xFF8A8A8E),
                    sortActive: Color(0xFFFFFFFF),
                    sortInactive: Color(0xFF6B6B70),
                    divider: Color(0xFF29292B),
                    border: Color(0xFF262629),
                    deleteIcon: Color(0xFFFF2638),
                    actionIcon: Color(0xFF8A8A8E),
                  ),
                  typography: AnimatedDataTableTypography(
                    primary: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    secondary: TextStyle(fontSize: 13),
                  ),
                  layout: AnimatedDataTableLayout(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    rowHeight: 57,
                    headerHeight: 50,
                    cellPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    actionColumnWidth: 52,
                  ),
                  animation: AnimatedDataTableAnimation(
                    enabled: true,
                    curve: Curves.easeInOutCubic,
                    sortDuration: Duration(milliseconds: 350),
                    rowDeletionDuration: Duration(milliseconds: 240),
                  ),
                ),

                columns: [
                  AnimatedDataColumn<Food>(
                    id: 'food',
                    label: 'Food',
                    valueText: (food) => food.name,
                    sortValue: (food) => food.name,
                    width: const AnimatedDataColumnWidth.flex(flex: 2, min: 150),
                  ),
                  AnimatedDataColumn<Food>(
                    id: 'quantity',
                    label: 'Quantity',
                    valueText: (food) => food.quantity,
                    sortValue: (food) => food.quantity,
                    secondary: true,
                    width: const AnimatedDataColumnWidth.flex(flex: 1.2, min: 100),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const List<Food> _initialFoods = [
    Food(id: 1, name: 'Chicken Breast', quantity: '200g', calories: 330, protein: 62, fat: 7.2, carbs: 0),
    Food(id: 2, name: 'Greek Yogurt', quantity: '200g', calories: 130, protein: 22, fat: 0.8, carbs: 9),
    Food(id: 3, name: 'Salmon Fillet', quantity: '170g', calories: 350, protein: 39, fat: 20, carbs: 0),
    Food(id: 4, name: 'Sweet Potato', quantity: '1 medium', calories: 103, protein: 2.3, fat: 0.1, carbs: 24),
    Food(id: 5, name: 'Brown Rice', quantity: '1 cup', calories: 216, protein: 5, fat: 1.8, carbs: 45),
  ];
}

class Food {
  const Food({
    required this.id,
    required this.name,
    required this.quantity,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  final int id;
  final String name;
  final String quantity;
  final int calories;
  final double protein;
  final double fat;
  final double carbs;
}
