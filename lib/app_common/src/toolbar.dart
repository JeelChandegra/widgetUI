import 'package:flutter/material.dart';
import 'controller.dart';
import 'models.dart';
import 'theme.dart';

class KanbanToolbar extends StatelessWidget {
  const KanbanToolbar({
    super.key, required this.controller, required this.theme,
    required this.columns, required this.onAddTask, required this.onAddColumn,
    required this.showViewSwitcher, required this.showUndoRedo,
  });
  final KanbanBoardController controller;
  final KanbanThemeData theme;
  final List<KanbanColumn> columns;
  final VoidCallback? onAddTask, onAddColumn;
  final bool showViewSwitcher, showUndoRedo;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Wrap(
          spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (showViewSwitcher) SegmentedButton<KanbanViewMode>(
              segments: const [
                ButtonSegment(value: KanbanViewMode.board, icon: Icon(Icons.view_kanban_outlined), label: Text('Board')),
                ButtonSegment(value: KanbanViewMode.compactBoard, icon: Icon(Icons.view_week_outlined), label: Text('Compact')),
                ButtonSegment(value: KanbanViewMode.list, icon: Icon(Icons.view_list_outlined), label: Text('List')),
              ],
              selected: {controller.viewMode},
              onSelectionChanged: (s) => controller.viewMode = s.first,
            ),
            if (controller.filter.query.isNotEmpty || true)
              SizedBox(width: 210, child: TextField(
                key: const ValueKey('kanban-search'),
                controller: TextEditingController(text: controller.filter.query)..selection = TextSelection.collapsed(offset: controller.filter.query.length),
                onChanged: (q) => controller.filter = controller.filter.copyWith(query: q),
                decoration: InputDecoration(
                  isDense: true, hintText: 'Search tasks…', prefixIcon: const Icon(Icons.search, size: 19),
                  suffixIcon: controller.filter.query.isEmpty ? null : IconButton(icon: const Icon(Icons.close, size: 17), onPressed: () => controller.filter = controller.filter.copyWith(query: '')),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              )),
            PopupMenuButton<KanbanPriority>(
              tooltip: 'Filter priority',
              icon: Badge(isLabelVisible: controller.filter.priorities.isNotEmpty, label: Text('${controller.filter.priorities.length}'), child: const Icon(Icons.filter_list)),
              itemBuilder: (_) => KanbanPriority.values.map((p) => PopupMenuItem(
                value: p,
                child: StatefulBuilder(builder: (context, setState) => CheckboxListTile(
                  dense: true, contentPadding: EdgeInsets.zero, title: Text(p.label),
                  value: controller.filter.priorities.contains(p),
                  onChanged: (v) {
                    final next = Set<KanbanPriority>.of(controller.filter.priorities);
                    if (v == true) { next.add(p); } else { next.remove(p); }
                    controller.filter = controller.filter.copyWith(priorities: next);
                    setState(() {});
                  },
                )),
              )).toList(),
              onSelected: (_) {},
            ),
            if (showUndoRedo) IconButton(tooltip: 'Undo', onPressed: controller.canUndo ? controller.undo : null, icon: const Icon(Icons.undo)),
            if (showUndoRedo) IconButton(tooltip: 'Redo', onPressed: controller.canRedo ? controller.redo : null, icon: const Icon(Icons.redo)),
            if (onAddTask != null) OutlinedButton.icon(onPressed: onAddTask, icon: const Icon(Icons.add, size: 17), label: const Text('New task')),
            if (onAddColumn != null) FilledButton.tonalIcon(onPressed: onAddColumn, icon: const Icon(Icons.view_column_outlined, size: 17), label: const Text('Add column')),
          ],
        ),
      ),
    );
  }
}
