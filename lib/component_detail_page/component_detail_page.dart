import 'package:go_router/go_router.dart';
import 'package:widget_ui/app_common/widget/custom_side_bar.dart';
import 'package:widget_ui/component_detail_page/provider/component_detail_provider.dart';
import 'package:widget_ui/component_detail_page/widgets/command_palette.dart';

import '../app_common/export.dart';
// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const Color _cdpBg = Color(0xFF0B0B0B);
const Color _cdpBorder = Color(0x1AFFFFFF);
const Color _cdpMuted = Color(0xFF8A8A8A);

class ComponentDetailPage extends ConsumerStatefulWidget {
  const ComponentDetailPage({super.key});

  @override
  ConsumerState<ComponentDetailPage> createState() =>
      _ComponentDetailPageState();
}

class _ComponentDetailPageState extends ConsumerState<ComponentDetailPage> {
  static const double _sidebarWidth = 280;
  static const double _appBarHeight = 56;

  bool _sidebarCollapsed = false;

  void _openPalette(BuildContext context) {
    showCommandPalette(
      context: context,
      sections: ref.read(sidebarSectionsProvider),
      onSelect: (item) {
        ref.read(selectedComponentProvider.notifier).set(item.id);
        // Ensure sidebar is open so user can see the selection highlighted
        if (_sidebarCollapsed) setState(() => _sidebarCollapsed = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedId =
        ref.watch(selectedComponentProvider) ?? 'card-carousel';
    final components = ref.watch(componentEntriesProvider);

    final selectedComponent = components
            .where((c) => c.slug == selectedId || c.title == selectedId)
            .firstOrNull ??
        components.firstOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            // ══════════════════════════════════════════════════════════════
            // APP BAR
            // ══════════════════════════════════════════════════════════════
            _CdpAppBar(
              height: _appBarHeight,
              sidebarCollapsed: _sidebarCollapsed,
              onMenuTap: () =>
                  setState(() => _sidebarCollapsed = !_sidebarCollapsed),
              componentName: selectedComponent?.title,
              onSearchTap: () => _openPalette(context),
            ),

            // ══════════════════════════════════════════════════════════════
            // BODY ROW (sidebar + content)
            // ══════════════════════════════════════════════════════════════
            Expanded(
              child: Row(
                children: [
                  // Sidebar — zero size when collapsed
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: Alignment.centerLeft,
                    child: ComponentSidebar(
                      width: _sidebarWidth,
                      isCollapsed: _sidebarCollapsed,
                      onToggleCollapse: () => setState(
                          () => _sidebarCollapsed = !_sidebarCollapsed),
                      sections: ref.watch(sidebarSectionsProvider),
                      selectedId: selectedId,
                      onSelect: (item) {
                        ref
                            .read(selectedComponentProvider.notifier)
                            .set(item.id);
                      },
                      header: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => context.go('/'),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_back_rounded,
                                    size: 16, color: Color(0xFF8A8A8A)),
                                const SizedBox(width: 8),
                                Text(
                                  'Back to Home',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFF8A8A8A)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Content
                  Expanded(
                    child: selectedComponent != null
                        ? SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              _sidebarCollapsed ? 24 : 56,
                              32,
                              32,
                              32,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedComponent.title,
                                  style: GoogleFonts.inter(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  selectedComponent.subtitle,
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: const Color(0xFF8A8A8A)),
                                ),
                                const SizedBox(height: 24),
                                Center(child: selectedComponent.screen()),
                              ],
                            ),
                          )
                        : Center(
                            child: Text(
                              'Select a component from the sidebar',
                              style: GoogleFonts.inter(
                                  color: const Color(0xFF8A8A8A),
                                  fontSize: 14),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// App Bar
// ============================================================================

class _CdpAppBar extends StatelessWidget {
  const _CdpAppBar({
    required this.height,
    required this.sidebarCollapsed,
    required this.onMenuTap,
    required this.componentName,
    required this.onSearchTap,
  });

  final double height;
  final bool sidebarCollapsed;
  final VoidCallback onMenuTap;
  final String? componentName;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: _cdpBg,
        border: Border(bottom: BorderSide(color: _cdpBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // ── Left: toggle + brand ───────────────────────────────────────
          _CdpMenuToggle(collapsed: sidebarCollapsed, onTap: onMenuTap),
          const SizedBox(width: 14),
          _CdpBrand(componentName: componentName),

          // ── Center: search trigger ─────────────────────────────────────
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _CdpSearchTrigger(onTap: onSearchTap),
              ),
            ),
          ),

          // balance spacer matching brand width
          const SizedBox(width: 180),
        ],
      ),
    );
  }
}

// ── Toggle button ────────────────────────────────────────────────────────────

class _CdpMenuToggle extends StatelessWidget {
  const _CdpMenuToggle({required this.collapsed, required this.onTap});

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: collapsed ? 'Open sidebar' : 'Close sidebar',
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: Icon(
            collapsed ? Icons.menu_rounded : Icons.menu_open_rounded,
            key: ValueKey(collapsed),
            size: 20,
            color: _cdpMuted,
          ),
        ),
      ),
    );
  }
}

// ── Brand ────────────────────────────────────────────────────────────────────

class _CdpBrand extends StatelessWidget {
  const _CdpBrand({required this.componentName});

  final String? componentName;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon box
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Center(
            child:
                Icon(Icons.widgets_rounded, size: 16, color: Colors.black),
          ),
        ),
        const SizedBox(width: 10),
        // App name + breadcrumb
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'WidgetUI',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (componentName != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('/',
                    style:
                        GoogleFonts.inter(fontSize: 14, color: _cdpMuted)),
              ),
              Text(
                componentName!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFCCCCCC),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Search trigger button ─────────────────────────────────────────────────────

class _CdpSearchTrigger extends StatefulWidget {
  const _CdpSearchTrigger({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_CdpSearchTrigger> createState() => _CdpSearchTriggerState();
}

class _CdpSearchTriggerState extends State<_CdpSearchTrigger> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? const Color(0x33FFFFFF)
                  : const Color(0x1AFFFFFF),
            ),
            boxShadow: _hovered
                ? [const BoxShadow(color: Color(0x0AFFFFFF), blurRadius: 8)]
                : [],
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 15,
                color: _hovered ? Colors.white54 : _cdpMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Search components…',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _cdpMuted,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0x1AFFFFFF)),
                  color: const Color(0xFF1A1A1A),
                ),
                child: Text(
                  '⌘ K',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, color: _cdpMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
