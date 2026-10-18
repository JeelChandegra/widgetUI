// component_preview_panel.dart
//
// Reusable panel for component detail pages:
//   top bar  : file name, Like, Share, device switcher, [Preview | Code | Usage]
//   body     : live preview (resizable to desktop / tablet / phone),
//              full source, or usage snippet
//
// Tabs appear only for the content you pass:
//   preview            -> "Preview"
//   sourceAsset/source -> "Code"
//   usage              -> "Usage"
//
// Device switcher: the preview is laid out at 100% / 768px / 390px width and
// MediaQuery.size is overridden to match, so responsive widgets react.
// Code is syntax highlighted by code_highlighter.dart.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'code_highlighter.dart';

const Color _panelBg = Color(0xFF0B0B0B);
const Color _innerBg = Color(0xFF000000);
const Color _border = Color(0x1AFFFFFF);
const Color _muted = Color(0xFF8A8A8A);

enum PreviewPanelTab {
  preview('Preview'),
  code('Code'),
  usage('Usage');

  const PreviewPanelTab(this.label);
  final String label;
}

/// Width presets for the preview.
enum PreviewDevice {
  desktop('Desktop', Icons.desktop_windows_outlined, null),
  tablet('Tablet', Icons.tablet_mac_outlined, 768),
  phone('Phone', Icons.smartphone_rounded, 390);

  const PreviewDevice(this.label, this.icon, this.width);
  final String label;
  final IconData icon;

  /// Null = fill the panel.
  final double? width;
}

class ComponentPreviewPanel extends StatefulWidget {
  const ComponentPreviewPanel({
    super.key,
    required this.preview,
    this.fileName = 'component.dart',
    this.usage,
    this.sourceAsset,
    this.source,
    this.usageLanguage = CodeLanguage.dart,
    this.sourceLanguage = CodeLanguage.dart,
    this.codeTheme = CodeTheme.dark,
    this.lineNumbers = true,
    this.initialTab = PreviewPanelTab.preview,
    this.previewMinHeight = 400,
    this.codeHeight = 400,
    this.previewPadding = const EdgeInsets.all(16),
    this.trailing,
    this.onTabChanged,
    this.showDeviceSwitcher = true,
    this.initialDevice = PreviewDevice.desktop,
    this.onDeviceChanged,
    this.showLike = true,
    this.initialLiked = false,
    this.likeCount,
    this.onLikeChanged,
    this.showShare = true,
    this.shareUrl,
    this.onShare,
  }) : assert(
  sourceAsset == null || source == null,
  'Pass either sourceAsset or source, not both.',
  );

  /// The live widget shown in the Preview tab.
  final Widget preview;

  /// Shown in the top bar, left side.
  final String fileName;

  /// Usage snippet. Hides the Usage tab when null.
  final String? usage;

  /// Asset path of the full source (e.g. `assets/code/foo.dart.txt`).
  /// Must be declared in pubspec.yaml. Hides the Code tab when both
  /// [sourceAsset] and [source] are null.
  final String? sourceAsset;

  /// Full source as a string (alternative to [sourceAsset]).
  final String? source;

  /// Highlight language for the Usage / Code tabs.
  final CodeLanguage usageLanguage;
  final CodeLanguage sourceLanguage;

  /// Colors of the highlighted code.
  final CodeTheme codeTheme;

  final bool lineNumbers;

  final PreviewPanelTab initialTab;
  final double previewMinHeight;
  final double codeHeight;
  final EdgeInsetsGeometry previewPadding;

  /// Extra widget placed before the tabs (icon buttons, theme toggle...).
  final Widget? trailing;

  final ValueChanged<PreviewPanelTab>? onTabChanged;

  // ---- device switcher ----------------------------------------------------

  /// Desktop / Tablet / Phone buttons (Preview tab only).
  final bool showDeviceSwitcher;
  final PreviewDevice initialDevice;
  final ValueChanged<PreviewDevice>? onDeviceChanged;

  // ---- like ---------------------------------------------------------------

  final bool showLike;
  final bool initialLiked;

  /// Starting like count. Null hides the number.
  final int? likeCount;

  /// Fired with the new liked state. Save it to your backend here.
  final ValueChanged<bool>? onLikeChanged;

  // ---- share --------------------------------------------------------------

  final bool showShare;

  /// URL copied by the default share action. Defaults to the current page
  /// address (Uri.base, works on web).
  final String? shareUrl;

  /// Replace the default "copy link". Use it with share_plus on mobile.
  final VoidCallback? onShare;

  @override
  State<ComponentPreviewPanel> createState() => _ComponentPreviewPanelState();
}

class _ComponentPreviewPanelState extends State<ComponentPreviewPanel> {
  late PreviewPanelTab _tab;
  late PreviewDevice _device;
  late bool _liked;
  late int _likes;
  bool _shared = false;
  Future<String>? _sourceFuture;

  List<PreviewPanelTab> get _tabs => [
    PreviewPanelTab.preview,
    if (widget.sourceAsset != null || widget.source != null)
      PreviewPanelTab.code,
    if (widget.usage != null) PreviewPanelTab.usage,
  ];

  @override
  void initState() {
    super.initState();
    _tab = _tabs.contains(widget.initialTab)
        ? widget.initialTab
        : PreviewPanelTab.preview;
    _device = widget.initialDevice;
    _liked = widget.initialLiked;
    _likes = widget.likeCount ?? 0;
    _loadSource();
  }

  @override
  void didUpdateWidget(covariant ComponentPreviewPanel old) {
    super.didUpdateWidget(old);
    if (old.sourceAsset != widget.sourceAsset || old.source != widget.source) {
      _loadSource();
    }
    if (!_tabs.contains(_tab)) _tab = PreviewPanelTab.preview;
  }

  void _loadSource() {
    if (widget.source != null) {
      _sourceFuture = Future.value(widget.source!);
    } else if (widget.sourceAsset != null) {
      _sourceFuture = rootBundle.loadString(widget.sourceAsset!);
    } else {
      _sourceFuture = null;
    }
  }

  void _setTab(PreviewPanelTab t) {
    setState(() => _tab = t);
    widget.onTabChanged?.call(t);
  }

  void _setDevice(PreviewDevice d) {
    setState(() => _device = d);
    widget.onDeviceChanged?.call(d);
  }

  void _toggleLike() {
    setState(() {
      _liked = !_liked;
      if (widget.likeCount != null) _likes += _liked ? 1 : -1;
    });
    widget.onLikeChanged?.call(_liked);
  }

  Future<void> _share() async {
    if (widget.onShare != null) {
      widget.onShare!();
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: widget.shareUrl ?? Uri.base.toString()),
    );
    if (!mounted) return;
    setState(() => _shared = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _shared = false);
  }

  // ---- top bar ------------------------------------------------------------

  Widget _actions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLike)
          _LikeButton(
            liked: _liked,
            count: widget.likeCount == null ? null : _likes,
            onTap: _toggleLike,
          ),
        if (widget.showShare)
          IconAction(
            tooltip: _shared
                ? 'Link copied'
                : (widget.onShare != null ? 'Share' : 'Copy link'),
            onTap: _share,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(
                _shared ? Icons.check_rounded : Icons.ios_share_rounded,
                key: ValueKey(_shared),
                size: 16,
                color: _shared ? const Color(0xFF4ADE80) : Colors.white70,
              ),
            ),
          ),
      ],
    );
  }

  Widget _topBar(bool compact, List<PreviewPanelTab> tabs) {
    final onPreview = _tab == PreviewPanelTab.preview;
    final devices = (widget.showDeviceSwitcher && onPreview)
        ? DeviceSwitcher(selected: _device, onChanged: _setDevice)
        : null;
    final hasActions = widget.showLike || widget.showShare;
    final divider = Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: _border,
    );

    final name = Expanded(
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF3A3A3A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              widget.fileName,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(fontSize: 12, color: _muted),
            ),
          ),
        ],
      ),
    );

    final tabsWidget = tabs.length > 1
        ? SegmentedTabs<PreviewPanelTab>(
      values: tabs,
      selected: _tab,
      label: (t) => t.label,
      onChanged: _setTab,
    )
        : null;

    if (!compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            name,
            if (hasActions) _actions(),
            if (hasActions && devices != null) divider,
            if (devices != null) devices,
            if (widget.trailing != null) ...[
              const SizedBox(width: 8),
              widget.trailing!,
            ],
            if (tabsWidget != null) ...[
              const SizedBox(width: 12),
              tabsWidget,
            ],
          ],
        ),
      );
    }

    // compact: two rows
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              name,
              if (tabsWidget != null) ...[
                const SizedBox(width: 12),
                tabsWidget,
              ],
            ],
          ),
          if (hasActions || devices != null || widget.trailing != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (hasActions) _actions(),
                const Spacer(),
                if (widget.trailing != null) ...[
                  widget.trailing!,
                  const SizedBox(width: 8),
                ],
                if (devices != null) devices,
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---- bodies -------------------------------------------------------------

  Widget _previewBody() {
    return LayoutBuilder(
      builder: (context, c) {
        final avail = c.maxWidth;
        final target = _device.width;
        final w = target == null ? avail : math.min(target, avail);
        final clamped = target != null && target > avail;
        final framed = _device != PreviewDevice.desktop;
        final phone = _device == PreviewDevice.phone;
        final mq = MediaQuery.of(context);

        final content = MediaQuery(
          data: mq.copyWith(size: Size(w, mq.size.height)),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.previewMinHeight),
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: phone ? 18 : 0),
                child: widget.preview,
              ),
            ),
          ),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                width: w,
                clipBehavior: Clip.antiAlias,
                decoration: framed
                    ? BoxDecoration(
                  color: _innerBg,
                  borderRadius: BorderRadius.circular(phone ? 28 : 18),
                  border: Border.all(
                    color: const Color(0x2EFFFFFF),
                    width: 1.5,
                  ),
                )
                    : const BoxDecoration(),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    content,
                    if (phone)
                      Positioned(
                        top: 8,
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0x26FFFFFF),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_device != PreviewDevice.desktop) ...[
              const SizedBox(height: 12),
              Text(
                '${_device.label}  \u00B7  ${w.round()}px'
                    '${clamped ? '  (panel is narrower)' : ''}',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: _muted),
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final compact = c.maxWidth < 640;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(compact, tabs),
              Container(height: 1, color: _border),
              Padding(
                padding: widget.previewPadding,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOut,
                  child: KeyedSubtree(
                    key: ValueKey(_tab),
                    child: switch (_tab) {
                      PreviewPanelTab.preview => _previewBody(),
                      PreviewPanelTab.code => _sourceView(),
                      PreviewPanelTab.usage => CodeBlock(
                        code: widget.usage ?? '',
                        height: widget.codeHeight,
                        language: widget.usageLanguage,
                        theme: widget.codeTheme,
                        lineNumbers: widget.lineNumbers,
                      ),
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sourceView() {
    final future = _sourceFuture;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<String>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SizedBox(
            height: widget.codeHeight,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            ),
          );
        }
        if (snap.hasError) {
          return SizedBox(
            height: widget.codeHeight,
            child: Center(
              child: Text(
                'Could not load ${widget.sourceAsset}.\n'
                    'Add it to pubspec assets and restart.',
                textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(fontSize: 12, color: _muted),
              ),
            ),
          );
        }
        return CodeBlock(
          code: snap.data!,
          height: widget.codeHeight,
          language: widget.sourceLanguage,
          theme: widget.codeTheme,
          lineNumbers: widget.lineNumbers,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Public building blocks (usable on their own)
// ---------------------------------------------------------------------------

/// 32px square icon button with hover tint and tooltip.
class IconAction extends StatefulWidget {
  const IconAction({
    super.key,
    required this.child,
    required this.onTap,
    required this.tooltip,
  });

  final Widget child;
  final VoidCallback onTap;
  final String tooltip;

  @override
  State<IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<IconAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Semantics(
          button: true,
          label: widget.tooltip,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              constraints: const BoxConstraints(minWidth: 32),
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: _hover ? const Color(0x14FFFFFF) : Colors.transparent,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.liked,
    required this.count,
    required this.onTap,
  });

  final bool liked;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const rose = Color(0xFFFB7185);
    return IconAction(
      tooltip: liked ? 'Unlike' : 'Like',
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.elasticOut,
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(liked),
              size: 16,
              color: liked ? rose : Colors.white70,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text(
              '$count',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: liked ? rose : Colors.white70,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Desktop / Tablet / Phone icon switcher.
class DeviceSwitcher extends StatelessWidget {
  const DeviceSwitcher({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final PreviewDevice selected;
  final ValueChanged<PreviewDevice> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _innerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final d in PreviewDevice.values)
            Tooltip(
              message: d.width == null
                  ? d.label
                  : '${d.label} \u00B7 ${d.width!.round()}px',
              waitDuration: const Duration(milliseconds: 400),
              child: Semantics(
                button: true,
                selected: d == selected,
                label: d.label,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: d == selected
                          ? const Color(0xFF1C1C1C)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: d == selected ? _border : Colors.transparent,
                      ),
                    ),
                    child: Icon(
                      d.icon,
                      size: 16,
                      color: d == selected ? Colors.white : _muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pill-style segmented toggle.
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _innerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final v in values)
            Semantics(
              button: true,
              selected: v == selected,
              label: label(v),
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: v == selected
                        ? const Color(0xFF1C1C1C)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: v == selected ? _border : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    label(v),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: v == selected ? Colors.white : _muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Syntax-highlighted, selectable code box with line numbers and a Copy
/// button. Scrolls vertically; long lines scroll horizontally while the
/// line-number gutter stays put.
class CodeBlock extends StatefulWidget {
  const CodeBlock({
    super.key,
    required this.code,
    this.height = 400,
    this.language = CodeLanguage.dart,
    this.theme = CodeTheme.dark,
    this.lineNumbers = true,
    this.fontSize = 12,
  });

  final String code;
  final double height;
  final CodeLanguage language;
  final CodeTheme theme;
  final bool lineNumbers;
  final double fontSize;

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  // Own controllers: sharing the PrimaryScrollController with the page
  // would throw "controller attached to multiple scroll views".
  final ScrollController _v = ScrollController();
  final ScrollController _h = ScrollController();

  bool _copied = false;
  late TextSpan _span;
  late String _gutter;
  late TextStyle _base;

  @override
  void initState() {
    super.initState();
    _rebuildSpans();
  }

  @override
  void didUpdateWidget(covariant CodeBlock old) {
    super.didUpdateWidget(old);
    if (old.code != widget.code ||
        old.language != widget.language ||
        old.theme != widget.theme ||
        old.fontSize != widget.fontSize) {
      _rebuildSpans();
    }
  }

  void _rebuildSpans() {
    _base = GoogleFonts.jetBrainsMono(fontSize: widget.fontSize, height: 1.55);
    _span = CodeHighlighter.highlight(
      widget.code,
      language: widget.language,
      theme: widget.theme,
      baseStyle: _base,
    );
    final lines = '\n'.allMatches(widget.code).length + 1;
    _gutter = List.generate(lines, (i) => '${i + 1}').join('\n');
  }

  @override
  void dispose() {
    _v.dispose();
    _h.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: _innerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: Scrollbar(
                controller: _v,
                child: SingleChildScrollView(
                  controller: _v,
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 56),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.lineNumbers)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 14),
                          child: Text(
                            _gutter,
                            textAlign: TextAlign.right,
                            style: _base.copyWith(
                              color: widget.theme.lineNumber,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _h,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(right: 16),
                          child: SelectableText.rich(_span),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: CopyButton(copied: _copied, onTap: _copy),
            ),
          ],
        ),
      ),
    );
  }
}

class CopyButton extends StatelessWidget {
  const CopyButton({super.key, required this.copied, required this.onTap});

  final bool copied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF141414),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 13,
                color: copied ? const Color(0xFF4ADE80) : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                copied ? 'Copied' : 'Copy',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}