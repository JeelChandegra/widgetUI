import 'package:flutter/animation.dart';

class KanbanBoardOptions {
  const KanbanBoardOptions({
    this.showToolbar = true, this.enableSearch = true, this.enableFilters = true,
    this.enableViewSwitcher = true, this.enableUndoRedo = true, this.undoLimit = 100,
    this.enableDrag = true, this.dragHandleOnly = false, this.showDragHandle = false,
    this.dragScale = 1.03, this.dragRotation = 0.025, this.enableAutoScroll = true,
    this.edgeScrollThreshold = 72, this.maxScrollSpeed = 900,
    this.enableColumnReorder = true, this.columnCollapsible = true,
    this.enableTaskExpansion = true, this.enableSwipeActions = false,
    this.allowAddTask = true, this.allowEditTask = true, this.allowDeleteTask = true,
    this.allowAddColumn = true, this.allowEditColumn = true, this.allowDeleteColumn = true,
    this.animationDuration = const Duration(milliseconds: 240),
    this.animationCurve = Curves.easeOutCubic,
  });
  final bool showToolbar, enableSearch, enableFilters, enableViewSwitcher, enableUndoRedo;
  final int undoLimit;
  final bool enableDrag, dragHandleOnly, showDragHandle;
  final double dragScale, dragRotation;
  final bool enableAutoScroll;
  final double edgeScrollThreshold, maxScrollSpeed;
  final bool enableColumnReorder, columnCollapsible, enableTaskExpansion, enableSwipeActions;
  final bool allowAddTask, allowEditTask, allowDeleteTask, allowAddColumn, allowEditColumn, allowDeleteColumn;
  final Duration animationDuration;
  final Curve animationCurve;
  bool get handleVisible => showDragHandle || dragHandleOnly;
}
