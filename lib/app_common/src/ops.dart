import 'models.dart';

typedef KanbanTaskLocation = ({int column, int index});
int _clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

abstract final class KanbanOps {
  static KanbanTaskLocation? locate(List<KanbanColumn> cols, String taskId) {
    for (var c = 0; c < cols.length; c++) {
      final i = cols[c].tasks.indexWhere((t) => t.id == taskId);
      if (i >= 0) return (column: c, index: i);
    }
    return null;
  }
  static int columnIndex(List<KanbanColumn> cols, String id) => cols.indexWhere((c) => c.id == id);
  static List<KanbanColumn> _replace(List<KanbanColumn> cols, int i, KanbanColumn col) {
    final out = List<KanbanColumn>.of(cols); out[i] = col; return out;
  }
  static List<KanbanColumn> moveTask(List<KanbanColumn> cols, String taskId, String toColumnId, int toIndex) {
    final loc = locate(cols, taskId); final to = columnIndex(cols, toColumnId);
    if (loc == null || to < 0) return cols;
    final from = cols[loc.column]; final task = from.tasks[loc.index];
    final crossing = loc.column != to;
    if (crossing && cols[to].isFull) return cols;
    final fromTasks = List<KanbanTask>.of(from.tasks)..removeAt(loc.index);
    if (!crossing) {
      final i = _clampInt(toIndex, 0, fromTasks.length);
      if (i == loc.index) return cols;
      fromTasks.insert(i, task);
      return _replace(cols, loc.column, from.copyWith(tasks: fromTasks));
    }
    final out = List<KanbanColumn>.of(cols);
    out[loc.column] = from.copyWith(tasks: fromTasks);
    final target = List<KanbanTask>.of(cols[to].tasks)..insert(_clampInt(toIndex, 0, cols[to].tasks.length), task);
    out[to] = cols[to].copyWith(tasks: target);
    return out;
  }
  static List<KanbanColumn> addTask(List<KanbanColumn> cols, String columnId, KanbanTask task, {int? index}) {
    if (locate(cols, task.id) != null) return cols;
    final ci = columnIndex(cols, columnId);
    if (ci < 0 || cols[ci].isFull) return cols;
    final tasks = List<KanbanTask>.of(cols[ci].tasks);
    tasks.insert(_clampInt(index ?? tasks.length, 0, tasks.length), task);
    return _replace(cols, ci, cols[ci].copyWith(tasks: tasks));
  }
  static List<KanbanColumn> updateTask(List<KanbanColumn> cols, KanbanTask task) {
    final loc = locate(cols, task.id); if (loc == null || cols[loc.column].tasks[loc.index] == task) return cols;
    final tasks = List<KanbanTask>.of(cols[loc.column].tasks)..[loc.index] = task;
    return _replace(cols, loc.column, cols[loc.column].copyWith(tasks: tasks));
  }
  static List<KanbanColumn> deleteTask(List<KanbanColumn> cols, String taskId) {
    final loc = locate(cols, taskId); if (loc == null) return cols;
    final tasks = List<KanbanTask>.of(cols[loc.column].tasks)..removeAt(loc.index);
    return _replace(cols, loc.column, cols[loc.column].copyWith(tasks: tasks));
  }
  static List<KanbanColumn> duplicateTask(List<KanbanColumn> cols, String taskId, String newId) {
    final loc = locate(cols, taskId);
    if (loc == null || locate(cols, newId) != null) return cols;
    final col = cols[loc.column]; if (col.isFull) return cols;
    final src = col.tasks[loc.index]; final copy = src.copyWith(id: newId, title: '${src.title} (copy)');
    final tasks = List<KanbanTask>.of(col.tasks)..insert(loc.index + 1, copy);
    return _replace(cols, loc.column, col.copyWith(tasks: tasks));
  }
  static List<KanbanColumn> addColumn(List<KanbanColumn> cols, KanbanColumn column, {int? index}) {
    if (cols.any((c) => c.id == column.id)) return cols;
    final out = List<KanbanColumn>.of(cols)..insert(_clampInt(index ?? cols.length, 0, cols.length), column);
    return out;
  }
  static List<KanbanColumn> updateColumn(List<KanbanColumn> cols, KanbanColumn column) {
    final i = columnIndex(cols, column.id); if (i < 0 || cols[i] == column) return cols;
    return _replace(cols, i, column);
  }
  static List<KanbanColumn> deleteColumn(List<KanbanColumn> cols, String columnId) {
    final i = columnIndex(cols, columnId); if (i < 0) return cols;
    return List<KanbanColumn>.of(cols)..removeAt(i);
  }
  static List<KanbanColumn> moveColumn(List<KanbanColumn> cols, String columnId, int toIndex) {
    final i = columnIndex(cols, columnId); if (i < 0) return cols;
    final out = List<KanbanColumn>.of(cols); final col = out.removeAt(i);
    final t = _clampInt(toIndex, 0, out.length); if (t == i) return cols;
    out.insert(t, col); return out;
  }
}
