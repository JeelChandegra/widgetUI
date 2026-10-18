import 'package:flutter/material.dart';
import 'models.dart';

Color kanbanAlpha(Color color, double opacity) => color.withAlpha((opacity * 255).round().clamp(0, 255).toInt());

@immutable
class KanbanThemeData {
  const KanbanThemeData({
    this.boardBackground = const Color(0xFFFFFFFF), this.boardPadding = const EdgeInsets.all(16),
    this.columnBackground = const Color(0xFFF7F8FA), this.columnBorderColor = const Color(0xFFE5E7EB),
    this.columnRadius = 16, this.columnWidth = 300, this.compactColumnWidth = 240, this.columnSpacing = 14,
    this.cardColor = const Color(0xFFFFFFFF), this.cardBorderColor = const Color(0xFFE5E7EB),
    this.cardRadius = 12, this.cardSpacing = 8,
    this.cardShadow = const [BoxShadow(color: Color(0x0F101828), blurRadius: 3, offset: Offset(0, 1))],
    this.cardHoverShadow = const [BoxShadow(color: Color(0x1A101828), blurRadius: 16, offset: Offset(0, 6))],
    this.cardDragShadow = const [BoxShadow(color: Color(0x33101828), blurRadius: 28, offset: Offset(0, 16))],
    this.textColor = const Color(0xFF111827), this.secondaryTextColor = const Color(0xFF6B7280),
    this.mutedColor = const Color(0xFF9CA3AF), this.accentColor = const Color(0xFF4F46E5),
    this.overdueColor = const Color(0xFFDC2626), this.invalidDropColor = const Color(0xFFDC2626),
    this.priorityColors = const {
      KanbanPriority.low: Color(0xFF94A3B8), KanbanPriority.medium: Color(0xFF3B82F6),
      KanbanPriority.high: Color(0xFFF59E0B), KanbanPriority.urgent: Color(0xFFEF4444),
    },
    this.titleStyle = const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3),
    this.bodyStyle = const TextStyle(fontSize: 12.5, height: 1.4),
    this.labelStyle = const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.2),
  });
  final Color boardBackground, columnBackground, columnBorderColor, cardColor, cardBorderColor;
  final EdgeInsets boardPadding;
  final double columnRadius, columnWidth, compactColumnWidth, columnSpacing, cardRadius, cardSpacing;
  final List<BoxShadow> cardShadow, cardHoverShadow, cardDragShadow;
  final Color textColor, secondaryTextColor, mutedColor, accentColor, overdueColor, invalidDropColor;
  final Map<KanbanPriority, Color> priorityColors;
  final TextStyle titleStyle, bodyStyle, labelStyle;
  Color priorityColor(KanbanPriority p) => priorityColors[p] ?? accentColor;
  KanbanThemeData copyWith({
    Color? boardBackground, EdgeInsets? boardPadding, Color? columnBackground, Color? columnBorderColor,
    double? columnRadius, double? columnWidth, double? compactColumnWidth, double? columnSpacing,
    Color? cardColor, Color? cardBorderColor, double? cardRadius, double? cardSpacing,
    List<BoxShadow>? cardShadow, List<BoxShadow>? cardHoverShadow, List<BoxShadow>? cardDragShadow,
    Color? textColor, Color? secondaryTextColor, Color? mutedColor, Color? accentColor,
    Color? overdueColor, Color? invalidDropColor, Map<KanbanPriority, Color>? priorityColors,
    TextStyle? titleStyle, TextStyle? bodyStyle, TextStyle? labelStyle,
  }) => KanbanThemeData(
    boardBackground: boardBackground ?? this.boardBackground, boardPadding: boardPadding ?? this.boardPadding,
    columnBackground: columnBackground ?? this.columnBackground, columnBorderColor: columnBorderColor ?? this.columnBorderColor,
    columnRadius: columnRadius ?? this.columnRadius, columnWidth: columnWidth ?? this.columnWidth,
    compactColumnWidth: compactColumnWidth ?? this.compactColumnWidth, columnSpacing: columnSpacing ?? this.columnSpacing,
    cardColor: cardColor ?? this.cardColor, cardBorderColor: cardBorderColor ?? this.cardBorderColor,
    cardRadius: cardRadius ?? this.cardRadius, cardSpacing: cardSpacing ?? this.cardSpacing,
    cardShadow: cardShadow ?? this.cardShadow, cardHoverShadow: cardHoverShadow ?? this.cardHoverShadow,
    cardDragShadow: cardDragShadow ?? this.cardDragShadow, textColor: textColor ?? this.textColor,
    secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor, mutedColor: mutedColor ?? this.mutedColor,
    accentColor: accentColor ?? this.accentColor, overdueColor: overdueColor ?? this.overdueColor,
    invalidDropColor: invalidDropColor ?? this.invalidDropColor, priorityColors: priorityColors ?? this.priorityColors,
    titleStyle: titleStyle ?? this.titleStyle, bodyStyle: bodyStyle ?? this.bodyStyle, labelStyle: labelStyle ?? this.labelStyle,
  );
}
