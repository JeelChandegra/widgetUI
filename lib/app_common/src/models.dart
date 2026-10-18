import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

enum KanbanPriority {
  low('Low'), medium('Medium'), high('High'), urgent('Urgent');
  const KanbanPriority(this.label);
  final String label;
}

@immutable
class KanbanChecklistItem {
  const KanbanChecklistItem({required this.id, required this.title, this.done = false});
  final String id;
  final String title;
  final bool done;
  KanbanChecklistItem copyWith({String? title, bool? done}) =>
      KanbanChecklistItem(id: id, title: title ?? this.title, done: done ?? this.done);
  @override
  bool operator ==(Object other) => other is KanbanChecklistItem && other.id == id && other.title == title && other.done == done;
  @override
  int get hashCode => Object.hash(id, title, done);
}

@immutable
class KanbanAssignee {
  const KanbanAssignee({required this.id, required this.name, this.avatarUrl});
  final String id;
  final String name;
  final String? avatarUrl;
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
  @override
  bool operator ==(Object other) => other is KanbanAssignee && other.id == id && other.name == name && other.avatarUrl == avatarUrl;
  @override
  int get hashCode => Object.hash(id, name, avatarUrl);
}

@immutable
class KanbanTask {
  const KanbanTask({
    required this.id, required this.title, this.description,
    this.priority = KanbanPriority.medium, this.labels = const [],
    this.assignee, this.dueDate, this.checklist = const [], this.metadata = const {},
  });
  final String id;
  final String title;
  final String? description;
  final KanbanPriority priority;
  final List<String> labels;
  final KanbanAssignee? assignee;
  final DateTime? dueDate;
  final List<KanbanChecklistItem> checklist;
  final Map<String, Object?> metadata;
  bool get isComplete => checklist.isNotEmpty && checklist.every((i) => i.done);
  double get checklistProgress => checklist.isEmpty ? 0 : checklist.where((i) => i.done).length / checklist.length;
  bool isOverdue({DateTime? now}) {
    final due = dueDate;
    if (due == null || isComplete) return false;
    final n = now ?? DateTime.now();
    return DateTime(due.year, due.month, due.day).isBefore(DateTime(n.year, n.month, n.day));
  }
  KanbanTask copyWith({
    String? id, String? title, String? description, bool clearDescription = false,
    KanbanPriority? priority, List<String>? labels, KanbanAssignee? assignee,
    bool clearAssignee = false, DateTime? dueDate, bool clearDueDate = false,
    List<KanbanChecklistItem>? checklist, Map<String, Object?>? metadata,
  }) => KanbanTask(
    id: id ?? this.id, title: title ?? this.title,
    description: clearDescription ? null : (description ?? this.description),
    priority: priority ?? this.priority, labels: labels ?? this.labels,
    assignee: clearAssignee ? null : (assignee ?? this.assignee),
    dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
    checklist: checklist ?? this.checklist, metadata: metadata ?? this.metadata,
  );
  @override
  bool operator ==(Object other) => identical(this, other) || other is KanbanTask &&
    other.id == id && other.title == title && other.description == description &&
    other.priority == priority && listEquals(other.labels, labels) &&
    other.assignee == assignee && other.dueDate == dueDate &&
    listEquals(other.checklist, checklist) && mapEquals(other.metadata, metadata);
  @override
  int get hashCode => Object.hash(id, title, description, priority, Object.hashAll(labels), assignee, dueDate, Object.hashAll(checklist), Object.hashAll(metadata.entries.map((e) => Object.hash(e.key, e.value))));
}

@immutable
class KanbanColumn {
  const KanbanColumn({
    required this.id, required this.title, this.color, this.tasks = const [],
    this.taskLimit, this.collapsed = false, this.width,
  });
  final String id;
  final String title;
  final Color? color;
  final List<KanbanTask> tasks;
  final int? taskLimit;
  final bool collapsed;
  final double? width;
  bool get isFull => taskLimit != null && tasks.length >= taskLimit!;
  KanbanColumn copyWith({
    String? title, Color? color, List<KanbanTask>? tasks, int? taskLimit,
    bool clearTaskLimit = false, bool? collapsed, double? width, bool clearWidth = false,
  }) => KanbanColumn(
    id: id, title: title ?? this.title, color: color ?? this.color,
    tasks: tasks ?? this.tasks, taskLimit: clearTaskLimit ? null : (taskLimit ?? this.taskLimit),
    collapsed: collapsed ?? this.collapsed, width: clearWidth ? null : (width ?? this.width),
  );
  @override
  bool operator ==(Object other) => identical(this, other) || other is KanbanColumn &&
    other.id == id && other.title == title && other.color == color &&
    listEquals(other.tasks, tasks) && other.taskLimit == taskLimit &&
    other.collapsed == collapsed && other.width == width;
  @override
  int get hashCode => Object.hash(id, title, color, Object.hashAll(tasks), taskLimit, collapsed, width);
}
