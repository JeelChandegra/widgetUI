import 'package:flutter/material.dart';
import 'models.dart';
import 'options.dart';
import 'task_card.dart';
import 'theme.dart';

class KanbanColumnWidget extends StatelessWidget {
  const KanbanColumnWidget({
    super.key, required this.column, required this.theme, required this.options,
    required this.tasks, required this.onAddTask, required this.onEditColumn,
    required this.onDeleteColumn, required this.onEditTask, required this.onDeleteTask,
    required this.onDuplicateTask, required this.onToggleChecklist,
    required this.onAcceptTask, required this.onReorderTask, this.compact = false,
  });
  final KanbanColumn column;
  final KanbanThemeData theme;
  final KanbanBoardOptions options;
  final List<KanbanTask> tasks;
  final VoidCallback? onAddTask, onEditColumn, onDeleteColumn;
  final ValueChanged<KanbanTask> onEditTask, onDeleteTask, onDuplicateTask;
  final void Function(String taskId, String checklistId) onToggleChecklist;
  final void Function(String taskId, int index) onAcceptTask;
  final void Function(String taskId, int index) onReorderTask;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = column.color ?? theme.accentColor;
    final width = column.collapsed ? 64 : (column.width ?? (compact ? theme.compactColumnWidth : theme.columnWidth));
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => options.enableDrag && !column.isFull,
      onAcceptWithDetails: (d) => onAcceptTask(d.data, tasks.length),
      builder: (context, candidates, rejected) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: options.animationDuration,
          width: width.toDouble(),
          decoration: BoxDecoration(
            color: hovering ? accent.withAlpha(13) : theme.columnBackground,
            borderRadius: BorderRadius.circular(theme.columnRadius),
            border: Border.all(color: hovering ? accent : theme.columnBorderColor, width: hovering ? 1.5 : 1),
          ),
          child: column.collapsed
              ? RotatedBox(quarterTurns: 3, child: Center(child: Text('${column.title}  ${tasks.length}', style: theme.titleStyle)))
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
                    child: Row(children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(column.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.titleStyle.copyWith(color: theme.textColor))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: theme.columnBorderColor.withAlpha(120), borderRadius: BorderRadius.circular(8)), child: Text('${tasks.length}', style: theme.labelStyle.copyWith(color: theme.secondaryTextColor))),
                      if (options.columnCollapsible) IconButton(visualDensity: VisualDensity.compact, tooltip: 'Collapse column', onPressed: () {}, icon: Icon(Icons.keyboard_arrow_up, size: 18, color: theme.secondaryTextColor)),
                      if (onEditColumn != null || onDeleteColumn != null) PopupMenuButton<String>(
                        padding: EdgeInsets.zero, icon: Icon(Icons.more_horiz, size: 18, color: theme.secondaryTextColor),
                        onSelected: (v) { if (v == 'edit') onEditColumn?.call(); if (v == 'delete') onDeleteColumn?.call(); },
                        itemBuilder: (_) => [
                          if (onEditColumn != null) const PopupMenuItem(value: 'edit', child: Text('Edit column')),
                          if (onDeleteColumn != null) const PopupMenuItem(value: 'delete', child: Text('Delete column')),
                        ],
                      ),
                    ]),
                  ),
                  if (column.taskLimit != null)
                    Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (tasks.length / column.taskLimit!).clamp(0.0, 1.0), minHeight: 3, backgroundColor: theme.columnBorderColor, color: tasks.length >= column.taskLimit! ? theme.overdueColor : accent))),
                  Expanded(child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => SizedBox(height: theme.cardSpacing),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      Widget buildTaskCard() => KanbanTaskCard(
                        key: ValueKey(task.id),
                        task: task,
                        theme: theme,
                        options: options,
                        onEdit: options.allowEditTask ? () => onEditTask(task) : null,
                        onDelete: options.allowDeleteTask ? () => onDeleteTask(task) : null,
                        onDuplicate: options.allowAddTask ? () => onDuplicateTask(task) : null,
                        onToggleChecklist: (id) => onToggleChecklist(task.id, id),
                        dragHandle: options.handleVisible ? const Icon(Icons.drag_indicator, size: 18) : null,
                      );

                      if (!options.enableDrag) {
                        return buildTaskCard();
                      }

                      return DragTarget<String>(
                        onWillAcceptWithDetails: (d) => d.data != task.id,
                        onAcceptWithDetails: (d) => onReorderTask(d.data, index),
                        builder: (context, candidates, rejected) {
                          final isHovered = candidates.isNotEmpty;
                          return AnimatedPadding(
                            duration: options.animationDuration,
                            padding: isHovered ? const EdgeInsets.only(top: 10) : EdgeInsets.zero,
                            child: Draggable<String>(
                              data: task.id,
                              dragAnchorStrategy: pointerDragAnchorStrategy,
                              feedback: Material(
                                color: Colors.transparent,
                                child: SizedBox(
                                  width: (width - 16).toDouble(),
                                  child: Opacity(opacity: 0.92, child: buildTaskCard()),
                                ),
                              ),
                              childWhenDragging: Opacity(opacity: 0.25, child: buildTaskCard()),
                              child: buildTaskCard(),
                            ),
                          );
                        },
                      );
                    },
                  )),
                  if (options.allowAddTask && onAddTask != null)
                    Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: InkWell(
                      borderRadius: BorderRadius.circular(8), onTap: onAddTask,
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Row(children: [Icon(Icons.add, size: 17, color: theme.secondaryTextColor), const SizedBox(width: 6), Text('Add task', style: theme.bodyStyle.copyWith(color: theme.secondaryTextColor))])),
                    )),
                ]),
        );
      },
    );
  }
}
