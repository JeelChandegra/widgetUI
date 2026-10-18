import 'package:flutter/material.dart';
import 'models.dart';
import 'options.dart';
import 'theme.dart';

class KanbanTaskCard extends StatefulWidget {
  const KanbanTaskCard({
    super.key,
    required this.task,
    required this.theme,
    required this.options,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
    this.onToggleChecklist,
    this.dragHandle,
  });
  final KanbanTask task;
  final KanbanThemeData theme;
  final KanbanBoardOptions options;
  final VoidCallback? onTap, onEdit, onDelete, onDuplicate;
  final ValueChanged<String>? onToggleChecklist;
  final Widget? dragHandle;
  @override
  State<KanbanTaskCard> createState() => _KanbanTaskCardState();
}

class _KanbanTaskCardState extends State<KanbanTaskCard> {
  bool _hovered = false;
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final th = widget.theme;
    final overdue = t.isOverdue();
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: th.cardColor,
          borderRadius: BorderRadius.circular(th.cardRadius),
          border: Border.all(color: overdue ? th.overdueColor.withAlpha(110) : th.cardBorderColor),
          boxShadow: _hovered ? th.cardHoverShadow : th.cardShadow,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(th.cardRadius),
          onTap: widget.onTap ?? (widget.options.enableTaskExpansion ? () => setState(() => _expanded = !_expanded) : null),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      margin: const EdgeInsets.only(right: 8, top: 1),
                      decoration: BoxDecoration(color: th.priorityColor(t.priority), borderRadius: BorderRadius.circular(4)),
                    ),
                    Expanded(
                      child: Text(t.title, style: th.titleStyle.copyWith(color: th.textColor)),
                    ),
                    if (widget.dragHandle != null) widget.dragHandle!,
                    if (widget.onEdit != null || widget.onDelete != null || widget.onDuplicate != null)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 160),
                        icon: Icon(Icons.more_horiz, size: 19, color: th.secondaryTextColor),
                        onSelected: (v) {
                          if (v == 'edit') widget.onEdit?.call();
                          if (v == 'duplicate') widget.onDuplicate?.call();
                          if (v == 'delete') widget.onDelete?.call();
                        },
                        itemBuilder: (_) => [
                          if (widget.onEdit != null) const PopupMenuItem(value: 'edit', child: Text('Edit task')),
                          if (widget.onDuplicate != null) const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                          if (widget.onDelete != null) const PopupMenuItem(value: 'delete', child: Text('Delete task')),
                        ],
                      ),
                  ],
                ),
                if ((t.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    t.description!,
                    maxLines: _expanded ? null : 2,
                    overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: th.bodyStyle.copyWith(color: th.secondaryTextColor),
                  ),
                ],

                if (t.labels.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: t.labels.map<Widget>((label) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: th.accentColor.withAlpha(18), borderRadius: BorderRadius.circular(6)),
                        child: Text(label, style: th.labelStyle.copyWith(color: th.accentColor)),
                      );
                    }).toList(),
                  ),
                ],
                if (t.checklist.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.checklist, size: 15, color: th.secondaryTextColor),
                      const SizedBox(width: 5),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: t.checklistProgress,
                            minHeight: 4,
                            backgroundColor: th.columnBorderColor,
                            color: th.accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '${t.checklist.where((i) => i.done).length}/${t.checklist.length}',
                        style: th.labelStyle.copyWith(color: th.secondaryTextColor),
                      ),
                    ],
                  ),
                  if (_expanded)
                    ...t.checklist.map(
                      (item) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: item.done,
                        title: Text(item.title, style: th.bodyStyle),
                        onChanged: widget.onToggleChecklist == null ? null : (_) => widget.onToggleChecklist!(item.id),
                      ),
                    ),
                ],
                if (_expanded && t.metadata.isNotEmpty) ...[
                  const Divider(height: 20),
                  ...t.metadata.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${e.key}: ${e.value ?? ''}', style: th.bodyStyle.copyWith(color: th.secondaryTextColor)),
                    ),
                  ),
                ],
                if (t.assignee != null || t.dueDate != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (t.assignee != null) ...[
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: th.accentColor.withAlpha(24),
                          child: Text(
                            t.assignee!.initials,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: th.accentColor),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t.assignee!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: th.labelStyle.copyWith(color: th.secondaryTextColor),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (t.dueDate != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule, size: 13, color: overdue ? th.overdueColor : th.secondaryTextColor),
                            const SizedBox(width: 4),
                            Text(
                              '${t.dueDate!.day}/${t.dueDate!.month}/${t.dueDate!.year}',
                              style: th.labelStyle.copyWith(color: overdue ? th.overdueColor : th.secondaryTextColor),
                            ),
                          ],
                        ),
                    ],
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
