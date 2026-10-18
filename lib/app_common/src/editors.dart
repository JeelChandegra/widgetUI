import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';

/// Default task create/edit dialog. Supply [initial] to edit an existing task.
class KanbanTaskEditor extends StatefulWidget {
  const KanbanTaskEditor({super.key, this.initial, this.availableAssignees = const [], this.availableLabels = const []});
  final KanbanTask? initial;
  final List<KanbanAssignee> availableAssignees;
  final List<String> availableLabels;

  @override
  State<KanbanTaskEditor> createState() => _KanbanTaskEditorState();
}

class _KanbanTaskEditorState extends State<KanbanTaskEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _description = TextEditingController(text: widget.initial?.description ?? '');
  late final _labels = TextEditingController(text: widget.initial?.labels.join(', ') ?? '');
  late KanbanPriority _priority = widget.initial?.priority ?? KanbanPriority.medium;
  late KanbanAssignee? _assignee = widget.initial?.assignee;
  late DateTime? _dueDate = widget.initial?.dueDate;

  @override
  void dispose() {
    _title.dispose(); _description.dispose(); _labels.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final old = widget.initial;
    Navigator.of(context).pop(KanbanTask(
      id: old?.id ?? 'task_${DateTime.now().microsecondsSinceEpoch}',
      title: _title.text.trim(),
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      priority: _priority,
      labels: _labels.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList(),
      assignee: _assignee,
      dueDate: _dueDate,
      checklist: old?.checklist ?? const [],
      metadata: old?.metadata ?? const {},
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'New task' : 'Edit task'),
      content: SizedBox(width: 420, child: SingleChildScrollView(
        child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: _title, autofocus: true, decoration: const InputDecoration(labelText: 'Title'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a title' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description (optional)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<KanbanPriority>(
            value: _priority, decoration: const InputDecoration(labelText: 'Priority'),
            items: KanbanPriority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(),
            onChanged: (v) { if (v != null) setState(() => _priority = v); },
          ),
          if (widget.availableAssignees.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<KanbanAssignee?>(
              value: _assignee, decoration: const InputDecoration(labelText: 'Assignee', hintText: 'Unassigned'),
              items: [const DropdownMenuItem<KanbanAssignee?>(value: null, child: Text('Unassigned')), ...widget.availableAssignees.map((a) => DropdownMenuItem<KanbanAssignee?>(value: a, child: Text(a.name)))],
              onChanged: (v) => setState(() => _assignee = v),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(controller: _labels, decoration: InputDecoration(labelText: 'Labels', helperText: widget.availableLabels.isEmpty ? 'Separate labels with commas' : 'Available: ${widget.availableLabels.join(', ')}')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(_dueDate == null ? 'No due date' : 'Due ${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}')),
            TextButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_month), label: const Text('Choose')),
            if (_dueDate != null) IconButton(tooltip: 'Clear due date', onPressed: () => setState(() => _dueDate = null), icon: const Icon(Icons.close)),
          ]),
        ])),
      )),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class KanbanColumnEditor extends StatefulWidget {
  const KanbanColumnEditor({super.key, this.initial});
  final KanbanColumn? initial;
  @override
  State<KanbanColumnEditor> createState() => _KanbanColumnEditorState();
}

class _KanbanColumnEditorState extends State<KanbanColumnEditor> {
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _limit = TextEditingController(text: widget.initial?.taskLimit?.toString() ?? '');
  @override
  void dispose() { _title.dispose(); _limit.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'New column' : 'Edit column'),
    content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _title, autofocus: true, decoration: const InputDecoration(labelText: 'Column name')),
      const SizedBox(height: 12),
      TextField(controller: _limit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Task limit (optional)')),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        final title = _title.text.trim();
        if (title.isEmpty) return;
        final parsed = int.tryParse(_limit.text.trim());
        if (_limit.text.trim().isNotEmpty && (parsed == null || parsed < 1)) return;
        final old = widget.initial;
        Navigator.pop(context, KanbanColumn(id: old?.id ?? 'column_${DateTime.now().microsecondsSinceEpoch}', title: title, color: old?.color, tasks: old?.tasks ?? const [], taskLimit: parsed, collapsed: old?.collapsed ?? false, width: old?.width));
      }, child: const Text('Save')),
    ],
  );
}
