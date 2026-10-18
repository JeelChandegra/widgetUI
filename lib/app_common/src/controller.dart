import 'package:flutter/foundation.dart';
import 'models.dart';

enum KanbanViewMode { board, compactBoard, list }

@immutable
class KanbanFilter {
  const KanbanFilter({this.query = '', this.priorities = const {}, this.assigneeIds = const {}, this.labels = const {}});
  static const empty = KanbanFilter();
  final String query;
  final Set<KanbanPriority> priorities;
  final Set<String> assigneeIds;
  final Set<String> labels;
  bool get isActive => query.trim().isNotEmpty || priorities.isNotEmpty || assigneeIds.isNotEmpty || labels.isNotEmpty;
  int get facetCount => (priorities.isNotEmpty ? 1 : 0) + (assigneeIds.isNotEmpty ? 1 : 0) + (labels.isNotEmpty ? 1 : 0);
  bool matches(KanbanTask t) {
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty && !t.title.toLowerCase().contains(q) && !(t.description ?? '').toLowerCase().contains(q)) return false;
    if (priorities.isNotEmpty && !priorities.contains(t.priority)) return false;
    if (assigneeIds.isNotEmpty && !(t.assignee != null && assigneeIds.contains(t.assignee!.id))) return false;
    if (labels.isNotEmpty && !t.labels.any(labels.contains)) return false;
    return true;
  }
  KanbanFilter copyWith({String? query, Set<KanbanPriority>? priorities, Set<String>? assigneeIds, Set<String>? labels}) =>
    KanbanFilter(query: query ?? this.query, priorities: priorities ?? this.priorities, assigneeIds: assigneeIds ?? this.assigneeIds, labels: labels ?? this.labels);
  @override
  bool operator ==(Object other) => other is KanbanFilter && other.query == query &&
    setEquals(other.priorities, priorities) && setEquals(other.assigneeIds, assigneeIds) && setEquals(other.labels, labels);
  @override
  int get hashCode => Object.hash(query, Object.hashAllUnordered(priorities), Object.hashAllUnordered(assigneeIds), Object.hashAllUnordered(labels));
}

abstract interface class KanbanControllerHost {
  bool get canUndo;
  bool get canRedo;
  void undo();
  void redo();
}

class KanbanBoardController extends ChangeNotifier {
  KanbanBoardController({KanbanViewMode viewMode = KanbanViewMode.board, KanbanFilter filter = KanbanFilter.empty})
      : _viewMode = viewMode, _filter = filter;
  KanbanViewMode _viewMode;
  KanbanFilter _filter;
  KanbanControllerHost? _host;
  KanbanViewMode get viewMode => _viewMode;
  set viewMode(KanbanViewMode v) { if (v == _viewMode) return; _viewMode = v; notifyListeners(); }
  KanbanFilter get filter => _filter;
  set filter(KanbanFilter f) { if (f == _filter) return; _filter = f; notifyListeners(); }
  void clearFilter() => filter = KanbanFilter.empty;
  bool get canUndo => _host?.canUndo ?? false;
  bool get canRedo => _host?.canRedo ?? false;
  void undo() => _host?.undo();
  void redo() => _host?.redo();
  void attach(KanbanControllerHost host) => _host = host;
  void detach(KanbanControllerHost host) { if (identical(_host, host)) _host = null; }
  void historyChanged() => notifyListeners();
}
