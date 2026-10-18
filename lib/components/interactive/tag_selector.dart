import 'package:flutter/material.dart';

/// A single selectable tag.
@immutable
class TagItem {
  final String id;
  final String label;

  const TagItem({required this.id, required this.label});

  @override
  bool operator ==(Object other) => other is TagItem && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// Reusable animated tag selector.
///
/// Features:
/// - Select and remove tags
/// - Animated layout changes
/// - Responsive wrapping
/// - Light and dark theme support
/// - Customizable colors, padding, and width
/// - Optional selection callback
class TagsWidget extends StatefulWidget {
  final List<TagItem>? tags;
  final List<TagItem> initialSelectedTags;
  final ValueChanged<List<TagItem>>? onChanged;

  final String title;
  final double? width;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final double runSpacing;

  final Color? selectedContainerColor;
  final Color? availableContainerColor;
  final Color? selectedTagColor;
  final Color? availableTagColor;
  final Color? borderColor;
  final Color? textColor;
  final Color? iconColor;

  final double animationDuration;
  final bool showTitle;
  final bool showAvailableTagsWhenEmpty;
  final double? height;

  const TagsWidget({
    super.key,
    this.tags,
    this.initialSelectedTags = const [],
    this.onChanged,
    this.title = 'TAGS',
    this.width,
    this.maxWidth = 340,
    this.padding = const EdgeInsets.all(24),
    this.spacing = 8,
    this.runSpacing = 8,
    this.selectedContainerColor,
    this.availableContainerColor,
    this.selectedTagColor,
    this.availableTagColor,
    this.borderColor,
    this.textColor,
    this.iconColor,
    this.animationDuration = 300,
    this.showTitle = true,
    this.showAvailableTagsWhenEmpty = true, this.height,
  });

  static const List<TagItem> defaultTags = [
    TagItem(id: 'javascript', label: 'Javascript'),
    TagItem(id: 'express', label: 'Express'),
    TagItem(id: 'vue', label: 'Vue'),
    TagItem(id: 'jest', label: 'Jest'),
    TagItem(id: 'next', label: 'Next'),
    TagItem(id: 'typescript', label: 'Typescript'),
    TagItem(id: 'redis', label: 'Redis'),
    TagItem(id: 'git', label: 'Git'),
    TagItem(id: 'node', label: 'Node'),
  ];

  @override
  State<TagsWidget> createState() => _TagsWidgetState();
}

class _TagsWidgetState extends State<TagsWidget> {
  late List<TagItem> _selectedTags;

  List<TagItem> get _tags => widget.tags ?? TagsWidget.defaultTags;

  List<TagItem> get _availableTags {
    final selectedIds = _selectedTags.map((tag) => tag.id).toSet();

    return _tags.where((tag) => !selectedIds.contains(tag.id)).toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedTags = _unique(widget.initialSelectedTags);
  }

  List<TagItem> _unique(List<TagItem> tags) {
    final ids = <String>{};
    return tags.where((tag) => ids.add(tag.id)).toList();
  }

  @override
  void didUpdateWidget(covariant TagsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Keep selected tags valid when the supplied tag list changes.
    if (oldWidget.tags != widget.tags) {
      final validIds = _tags.map((tag) => tag.id).toSet();

      _selectedTags = _selectedTags.where((tag) => validIds.contains(tag.id)).toList();
    }
  }

  void _addTag(TagItem tag) {
    if (_selectedTags.any((item) => item.id == tag.id)) return;

    setState(() {
      _selectedTags = [..._selectedTags, tag];
    });

    widget.onChanged?.call(List.unmodifiable(_selectedTags));
  }

  void _removeTag(TagItem tag) {
    setState(() {
      _selectedTags.removeWhere((item) => item.id == tag.id);
    });

    widget.onChanged?.call(List.unmodifiable(_selectedTags));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = widget.borderColor ?? (isDark ? const Color(0xFF303030) : const Color(0xFFE5E5E5));

    final selectedContainerColor = widget.selectedContainerColor ?? (isDark ? const Color(0xFF171717) : const Color(0xFFFEFEFE));

    final availableContainerColor = widget.availableContainerColor ?? (isDark ? const Color(0xFF171717) : Colors.white);

    final selectedTagColor = widget.selectedTagColor ?? (isDark ? const Color(0xFF262626) : Colors.white);

    final availableTagColor = widget.availableTagColor ?? (isDark ? const Color(0xFF404040) : const Color(0xFFF4F4FB));

    final textColor = widget.textColor ?? (isDark ? const Color(0xFFE5E5E5) : const Color(0xFF404040));

    final iconColor = widget.iconColor ?? (isDark ? Colors.grey.shade400 : Colors.grey.shade500);

    final duration = Duration(milliseconds: widget.animationDuration.round());
    final content =Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.width ?? widget.maxWidth),
        child: SizedBox(
          width: widget.width,
          child: Padding(
            padding: widget.padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showTitle) ...[
                  AnimatedSize(
                    duration: duration,
                    curve: Curves.easeInOut,
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: textColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Selected tags container.
                AnimatedSize(
                  duration: duration,
                  curve: Curves.easeInOut,
                  child: Container(
                    key: const ValueKey('selected-tags-container'),
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: selectedContainerColor,
                      border: Border.all(color: borderColor, width: 1.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _selectedTags.map((tag) {
                        return _buildSelectedTag(
                          tag: tag,
                          duration: duration,
                          backgroundColor: selectedTagColor,
                          borderColor: borderColor,
                          textColor: textColor,
                          iconColor: iconColor,
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Available tags container.
                AnimatedSize(
                  duration: duration,
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _availableTags.isEmpty
                      ? const SizedBox.shrink()
                      : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: availableContainerColor,
                      border: Border.all(color: borderColor, width: 1.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Wrap(
                      spacing: widget.spacing,
                      runSpacing: widget.runSpacing,
                      children: _availableTags.map((tag) {
                        return _buildAvailableTag(tag: tag, duration: duration, backgroundColor: availableTagColor, textColor: textColor);
                      }).toList(),
                    ),
                  ),
                ),

                if (_availableTags.isEmpty && _selectedTags.isEmpty && widget.showAvailableTagsWhenEmpty) const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
    return widget.height == null
        ? content
        : SizedBox(
      height: widget.height,
      child: content,
    ); ;
  }

  Widget _buildSelectedTag({
    required TagItem tag,
    required Duration duration,
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
    required Color iconColor,
  }) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: Container(
        key: ValueKey(tag.id),
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: 12, top: 7, bottom: 7),
                child: Text(
                  tag.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Remove ${tag.label}',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: const EdgeInsets.all(4),
              onPressed: () => _removeTag(tag),
              icon: Icon(Icons.close_rounded, size: 19, color: iconColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableTag({required TagItem tag, required Duration duration, required Color backgroundColor, required Color textColor}) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: Material(
        key: ValueKey(tag.id),
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _addTag(tag),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Text(
              tag.label,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }
}
