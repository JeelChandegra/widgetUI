import 'dart:async';
import 'package:flutter/material.dart';

import 'column_widget.dart';
import 'controller.dart';
import 'editors.dart';
import 'models.dart';
import 'ops.dart';
import 'options.dart';
import 'theme.dart';
import 'toolbar.dart';

typedef KanbanTaskBuilder = Widget Function(BuildContext context, KanbanTask task);
typedef KanbanColumnBuilder = Widget Function(BuildContext context, KanbanColumn column);

/// An animated Kanban board with immutable models, drag-and-drop, filtering,
/// local undo/redo history, and optional create/edit/delete dialogs.
///
/// The widget owns an internal copy of [columns]. Whenever it changes,
/// [onChanged] is called. Supplying new [columns] from the parent replaces the
/// current data (use this to synchronize server updates).
class AnimatedKanbanBoard extends StatefulWidget {
  const AnimatedKanbanBoard({
    super.key,
    required this.columns,
    this.onChanged,
    this.controller,
    this.options = const KanbanBoardOptions(),
    this.theme = const KanbanThemeData(),
    this.availableAssignees = const [],
    this.availableLabels = const [],
    this.taskBuilder,
    this.emptyBuilder,
    this.height,
    this.readOnly = false,
  });

  final List<KanbanColumn> columns;
  final ValueChanged<List<KanbanColumn>>? onChanged;
  final KanbanBoardController? controller;
  final KanbanBoardOptions options;
  final KanbanThemeData theme;
  final List<KanbanAssignee> availableAssignees;
  final List<String> availableLabels;
  final KanbanTaskBuilder? taskBuilder;
  final WidgetBuilder? emptyBuilder;
  final double? height;
  final bool readOnly;

  @override
  State<AnimatedKanbanBoard> createState() => _AnimatedKanbanBoardState();
}

class _AnimatedKanbanBoardState extends State<AnimatedKanbanBoard>
    implements KanbanControllerHost {
  late List<KanbanColumn> _columns;
  late KanbanBoardController _controller;
  late bool _ownsController;
  final List<List<KanbanColumn>> _undo = [];
  final List<List<KanbanColumn>> _redo = [];
  final ScrollController _horizontal = ScrollController();
  final ScrollController _listScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _columns = List.of(widget.columns);
    _attachController();
  }

  void _attachController() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? KanbanBoardController();
    _controller.attach(this);
  }

  @override
  void didUpdateWidget(covariant AnimatedKanbanBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _controller.detach(this);
      if (_ownsController) _controller.dispose();
      _attachController();
    }
    if (!identical(oldWidget.columns, widget.columns)) {
      _columns = List.of(widget.columns);
      _undo.clear(); _redo.clear();
    }
  }

  @override
  void dispose() {
    _controller.detach(this);
    if (_ownsController) _controller.dispose();
    _horizontal.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  @override
  bool get canUndo => _undo.isNotEmpty;
  @override
  bool get canRedo => _redo.isNotEmpty;

  List<KanbanColumn> _snapshot(List<KanbanColumn> source) => List.of(source);

  void _commit(List<KanbanColumn> next) {
    if (identical(next, _columns) || _same(next, _columns)) return;
    if (widget.options.enableUndoRedo && widget.options.undoLimit > 0) {
      _undo.add(_snapshot(_columns));
      if (_undo.length > widget.options.undoLimit) _undo.removeAt(0);
      _redo.clear();
    }
    setState(() => _columns = next);
    widget.onChanged?.call(List.unmodifiable(_columns));
    _controller.historyChanged();
  }

  bool _same(List<KanbanColumn> a, List<KanbanColumn> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) { if (a[i] != b[i]) return false; }
    return true;
  }

  @override
  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_snapshot(_columns));
    setState(() => _columns = _undo.removeLast());
    widget.onChanged?.call(List.unmodifiable(_columns));
    _controller.historyChanged();
  }

  @override
  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_snapshot(_columns));
    setState(() => _columns = _redo.removeLast());
    widget.onChanged?.call(List.unmodifiable(_columns));
    _controller.historyChanged();
  }

  List<KanbanTask> _visibleTasks(KanbanColumn c) =>
      c.tasks.where(_controller.filter.matches).toList();

  String _newId(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  Future<KanbanTask?> _editTask([KanbanTask? initial]) => showDialog<KanbanTask>(
    context: context,
    builder: (_) => KanbanTaskEditor(initial: initial, availableAssignees: widget.availableAssignees, availableLabels: widget.availableLabels),
  );

  Future<KanbanColumn?> _editColumn([KanbanColumn? initial]) => showDialog<KanbanColumn>(
    context: context, builder: (_) => KanbanColumnEditor(initial: initial),
  );

  Future<void> _addTask([String? columnId]) async {
    if (widget.readOnly || !widget.options.allowAddTask || _columns.isEmpty) return;
    final task = await _editTask();
    if (!mounted || task == null) return;
    final target = columnId ?? _columns.first.id;
    _commit(KanbanOps.addTask(_columns, target, task));
  }

  Future<void> _editTaskAction(KanbanTask task) async {
    if (widget.readOnly || !widget.options.allowEditTask) return;
    final updated = await _editTask(task);
    if (mounted && updated != null) _commit(KanbanOps.updateTask(_columns, updated));
  }

  Future<void> _addColumn() async {
    if (widget.readOnly || !widget.options.allowAddColumn) return;
    final col = await _editColumn();
    if (mounted && col != null) _commit(KanbanOps.addColumn(_columns, col));
  }

  Future<void> _editColumnAction(KanbanColumn column) async {
    if (widget.readOnly || !widget.options.allowEditColumn) return;
    final updated = await _editColumn(column);
    if (mounted && updated != null) _commit(KanbanOps.updateColumn(_columns, updated));
  }

  Future<void> _deleteTask(KanbanTask task) async {
    if (widget.readOnly || !widget.options.allowDeleteTask) return;
    final yes = await _confirm('Delete task?', '“${task.title}” will be removed from this board.');
    if (yes && mounted) _commit(KanbanOps.deleteTask(_columns, task.id));
  }

  Future<void> _deleteColumn(KanbanColumn column) async {
    if (widget.readOnly || !widget.options.allowDeleteColumn) return;
    final yes = await _confirm('Delete column?', '“${column.title}” and its tasks will be removed.');
    if (yes && mounted) _commit(KanbanOps.deleteColumn(_columns, column.id));
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: Text(title), content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      )) ?? false;

  void _duplicate(KanbanTask task) {
    if (widget.readOnly) return;
    _commit(KanbanOps.duplicateTask(_columns, task.id, _newId('task')));
  }

  void _toggleChecklist(String taskId, String itemId) {
    if (widget.readOnly) return;
    final loc = KanbanOps.locate(_columns, taskId);
    if (loc == null) return;
    final task = _columns[loc.column].tasks[loc.index];
    final checklist = task.checklist.map((i) => i.id == itemId ? i.copyWith(done: !i.done) : i).toList();
    _commit(KanbanOps.updateTask(_columns, task.copyWith(checklist: checklist)));
  }

  void _moveTask(String taskId, String columnId, int index) {
    if (widget.readOnly || !widget.options.enableDrag) return;
    _commit(KanbanOps.moveTask(_columns, taskId, columnId, index));
  }

  Widget _buildListView() {
    final rows = <Widget>[];
    for (final column in _columns) {
      final tasks = _visibleTasks(column);
      if (tasks.isEmpty) continue;
      rows.add(Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text('${column.title}  ·  ${tasks.length}', style: widget.theme.titleStyle)));
      for (final task in tasks) {
        rows.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: widget.taskBuilder?.call(context, task) ?? ListTile(
          tileColor: widget.theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: widget.theme.cardBorderColor)),
          title: Text(task.title), subtitle: task.description == null ? null : Text(task.description!),
          leading: CircleAvatar(radius: 5, backgroundColor: widget.theme.priorityColor(task.priority)),
          trailing: widget.readOnly ? null : IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editTaskAction(task)),
          onTap: widget.options.enableTaskExpansion ? () => _editTaskAction(task) : null,
        )));
      }
    }
    if (rows.isEmpty) return widget.emptyBuilder?.call(context) ?? const Center(child: Text('No tasks match your filters.'));
    return ListView(controller: _listScroll, padding: widget.theme.boardPadding, children: rows);
  }

  @override
  Widget build(BuildContext context) {
    final th = widget.theme;
    final opts = widget.options;
    final content = _columns.isEmpty
      ? (widget.emptyBuilder?.call(context) ?? const Center(child: Text('Add a column to get started.')))
      : _controller.viewMode == KanbanViewMode.list
        ? _buildListView()
        : Scrollbar(
            controller: _horizontal, thumbVisibility: true,
            child: ListView.separated(
              controller: _horizontal, scrollDirection: Axis.horizontal,
              padding: th.boardPadding,
              itemCount: _columns.length,
              separatorBuilder: (_, __) => SizedBox(width: th.columnSpacing),
              itemBuilder: (context, index) {
                final column = _columns[index];
                final tasks = _visibleTasks(column);
                return KanbanColumnWidget(
                  key: ValueKey(column.id),
                  column: column, theme: th, options: opts,
                  compact: _controller.viewMode == KanbanViewMode.compactBoard,
                  tasks: tasks,
                  onAddTask: widget.readOnly ? null : () => _addTask(column.id),
                  onEditColumn: widget.readOnly || !opts.allowEditColumn ? null : () => _editColumnAction(column),
                  onDeleteColumn: widget.readOnly || !opts.allowDeleteColumn ? null : () => _deleteColumn(column),
                  onEditTask: _editTaskAction,
                  onDeleteTask: _deleteTask,
                  onDuplicateTask: _duplicate,
                  onToggleChecklist: _toggleChecklist,
                  onAcceptTask: (id, i) => _moveTask(id, column.id, i),
                  onReorderTask: (id, i) => _moveTask(id, column.id, i),
                );
              },
            ),
          );

    return Material(
      color: th.boardBackground,
      child: Column(children: [
        if (opts.showToolbar) KanbanToolbar(
          controller: _controller, theme: th, columns: _columns,
          showViewSwitcher: opts.enableViewSwitcher,
          showUndoRedo: opts.enableUndoRedo,
          onAddTask: widget.readOnly || !opts.allowAddTask || _columns.isEmpty ? null : () => _addTask(),
          onAddColumn: widget.readOnly || !opts.allowAddColumn ? null : _addColumn,
        ),
        Expanded(child: widget.height == null ? content : SizedBox(height: widget.height, child: content)),
      ]),
    );
  }
}
