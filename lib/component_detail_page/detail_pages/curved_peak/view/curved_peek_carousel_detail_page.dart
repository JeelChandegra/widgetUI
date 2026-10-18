import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:widget_ui/app_common/widget/component_preview.dart';
import 'package:widget_ui/app_common/widget/customize_panel.dart';
import 'package:widget_ui/app_common/widget/props_table.dart';
import 'package:widget_ui/components/carousel/curved_peek.dart';

import '../../../../app_common/widget/installation_widget.dart';

// Update these imports to match the folder structure used by your component
// showcase. They follow the same convention as the other detail pages.

class CurvedPeekCarouselDetailPage extends StatefulWidget {
  const CurvedPeekCarouselDetailPage({super.key});

  @override
  State<CurvedPeekCarouselDetailPage> createState() =>
      _CurvedPeekCarouselDetailPageState();
}

class _CurvedPeekCarouselDetailPageState
    extends State<CurvedPeekCarouselDetailPage> {
  final CurvedPeekCarouselController _controller =
      CurvedPeekCarouselController();

  double _height = 380;
  double _viewportFraction = 0.4  ;
  double _itemSpacing = 8;
  double _lift = 50;
  double _tilt = 0.12;
  double _minScale = 0.85;
  double _minOpacity = 0.6;
  double _indicatorSpacing = 20;
  int _initialIndex = 0;
  int _autoPlayIntervalSeconds = 4;
  int _autoPlayDurationMs = 600;

  bool _enableTapToFocus = true;
  bool _enableHaptics = false;
  bool _autoPlay = true;
  bool _showIndicator = true;

  Color _indicatorActiveColor = const Color(0xFF6750A4);
  Color _indicatorInactiveColor = const Color(0x556750A4);

  static const List<_CarouselDemoItem> _items = [
    _CarouselDemoItem(
      title: 'Design',
      subtitle: 'Plan the experience',
      icon: Icons.brush_rounded,
      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    ),
    _CarouselDemoItem(
      title: 'Backend',
      subtitle: 'Build the foundation',
      icon: Icons.storage_rounded,
      colors: [Color(0xFF0EA5E9), Color(0xFF14B8A6)],
    ),
    _CarouselDemoItem(
      title: 'Frontend',
      subtitle: 'Create the interface',
      icon: Icons.widgets_rounded,
      colors: [Color(0xFFF97316), Color(0xFFEF4444)],
    ),
    _CarouselDemoItem(
      title: 'Testing',
      subtitle: 'Check every detail',
      icon: Icons.bug_report_rounded,
      colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
    ),
    _CarouselDemoItem(
      title: 'Release',
      subtitle: 'Ship with confidence',
      icon: Icons.rocket_launch_rounded,
      colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
    ),
  ];

  void _resetSettings() {
    setState(() {
      _height = 380;
      _viewportFraction = 0.78;
      _itemSpacing = 8;
      _lift = 50;
      _tilt = 0;
      _minScale = 0.85;
      _minOpacity = 0.6;
      _indicatorSpacing = 20;
      _initialIndex = 0;
      _autoPlayIntervalSeconds = 4;
      _autoPlayDurationMs = 600;
      _enableTapToFocus = true;
      _enableHaptics = false;
      _autoPlay = false;
      _showIndicator = true;
      _indicatorActiveColor = const Color(0xFF6750A4);
      _indicatorInactiveColor = const Color(0x556750A4);
    });
    _controller.jumpTo(0);
  }

  String get _usage => '''
final controller = CurvedPeekCarouselController();

CurvedPeekCarousel(
  controller: controller,
  itemCount: items.length,
  height: 380,
  viewportFraction: 0.78,
  itemSpacing: 8,
  lift: 50,
  tilt: 0.12,
  autoPlay: true,
  itemBuilder: (context, index) => YourCard(item: items[index]),
  onPageChanged: (index) {
    debugPrint('Current page: \$index');
  },
);
''';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComponentPreviewPanel(
          fileName: 'curved_peek_carousel.dart',
          sourceAsset: 'assets/component/curved_peek_carousel/curved_peek_carousel.txt',
          usage: _usage,
          previewMinHeight: 460,
          preview: _buildPreview(),
        ),
        const SizedBox(height: 20),
        _buildCustomizationPanel(context),
        const SizedBox(height: 24),
        InstallationWidget(),
        const SizedBox(height: 24),
        PropsTable(
          props: const [
            PropSpec(
              name: 'itemCount',
              type: 'int',
              defaultValue: 'required',
              description: 'Number of pages/items in the carousel.',
            ),
            PropSpec(
              name: 'itemBuilder',
              type: 'IndexedWidgetBuilder',
              defaultValue: 'required',
              description: 'Builds the widget displayed for each index.',
            ),
            PropSpec(
              name: 'controller',
              type: 'CurvedPeekCarouselController?',
              defaultValue: 'null',
              description: 'Controls the current page programmatically.',
            ),
            PropSpec(
              name: 'height',
              type: 'double',
              defaultValue: '380',
              description: 'Height of the carousel viewport.',
            ),
            PropSpec(
              name: 'initialIndex',
              type: 'int',
              defaultValue: '0',
              description: 'Initial focused item index.',
            ),
            PropSpec(
              name: 'viewportFraction',
              type: 'double',
              defaultValue: '0.78',
              description: 'Fraction of the viewport occupied by each page.',
            ),
            PropSpec(
              name: 'itemSpacing',
              type: 'double',
              defaultValue: '8',
              description: 'Horizontal padding around each item.',
            ),
            PropSpec(
              name: 'lift',
              type: 'double',
              defaultValue: '50',
              description: 'Vertical lift applied to side items.',
            ),
            PropSpec(
              name: 'tilt',
              type: 'double',
              defaultValue: '0.12',
              description: 'Rotation in radians applied to side items.',
            ),
            PropSpec(
              name: 'minScale',
              type: 'double',
              defaultValue: '0.85',
              description: 'Minimum scale for items away from the center.',
            ),
            PropSpec(
              name: 'minOpacity',
              type: 'double',
              defaultValue: '0.6',
              description: 'Minimum opacity for side items.',
            ),
            PropSpec(
              name: 'physics',
              type: 'ScrollPhysics',
              defaultValue: 'BouncingScrollPhysics()',
              description: 'Scroll physics used by the PageView.',
            ),
            PropSpec(
              name: 'clipBehavior',
              type: 'Clip',
              defaultValue: 'Clip.none',
              description: 'Controls clipping of lifted and tilted items.',
            ),
            PropSpec(
              name: 'enableTapToFocus',
              type: 'bool',
              defaultValue: 'true',
              description: 'Allows tapping a side item to focus it.',
            ),
            PropSpec(
              name: 'enableHaptics',
              type: 'bool',
              defaultValue: 'false',
              description: 'Triggers a selection haptic when the page changes.',
            ),
            PropSpec(
              name: 'onPageChanged',
              type: 'ValueChanged<int>?',
              defaultValue: 'null',
              description: 'Called when the focused page changes.',
            ),
            PropSpec(
              name: 'autoPlay',
              type: 'bool',
              defaultValue: 'false',
              description: 'Automatically advances through the items.',
            ),
            PropSpec(
              name: 'autoPlayInterval',
              type: 'Duration',
              defaultValue: '4 seconds',
              description: 'Time between autoplay page changes.',
            ),
            PropSpec(
              name: 'autoPlayDuration',
              type: 'Duration',
              defaultValue: '600 milliseconds',
              description: 'Duration of each autoplay animation.',
            ),
            PropSpec(
              name: 'autoPlayCurve',
              type: 'Curve',
              defaultValue: 'Curves.easeInOutCubic',
              description: 'Animation curve used by autoplay.',
            ),
            PropSpec(
              name: 'showIndicator',
              type: 'bool',
              defaultValue: 'true',
              description: 'Shows or hides the page indicator.',
            ),
            PropSpec(
              name: 'indicatorSpacing',
              type: 'double',
              defaultValue: '20',
              description: 'Space between the carousel and indicator.',
            ),
            PropSpec(
              name: 'indicatorBuilder',
              type: 'CurvedPeekIndicatorBuilder?',
              defaultValue: 'null',
              description: 'Builds a custom page indicator.',
            ),
            PropSpec(
              name: 'indicatorActiveColor',
              type: 'Color?',
              defaultValue: 'Theme primary',
              description: 'Color of the active indicator.',
            ),
            PropSpec(
              name: 'indicatorInactiveColor',
              type: 'Color?',
              defaultValue: 'onSurface at 25% opacity',
              description: 'Color of inactive indicators.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Center(
      child: SizedBox(
        height: _height + (_showIndicator ? _indicatorSpacing + 12 : 0),
        child: CurvedPeekCarousel(
          key: ValueKey(
            'carousel-$_viewportFraction-$_initialIndex-$_autoPlay-$_showIndicator',
          ),
          controller: _controller,
          itemCount: _items.length,
          initialIndex: _initialIndex,
          height: _height,
          viewportFraction: _viewportFraction,
          itemSpacing: _itemSpacing,
          lift: _lift,
          tilt: _tilt,
          minScale: _minScale,
          minOpacity: _minOpacity,
          enableTapToFocus: _enableTapToFocus,
          enableHaptics: _enableHaptics,
          autoPlay: _autoPlay,
          autoPlayInterval: Duration(seconds: _autoPlayIntervalSeconds),
          autoPlayDuration: Duration(milliseconds: _autoPlayDurationMs),
          showIndicator: _showIndicator,
          indicatorSpacing: _indicatorSpacing,
          indicatorActiveColor: _indicatorActiveColor,
          indicatorInactiveColor: _indicatorInactiveColor,
          onPageChanged: (index) {
            // Keep the preview interactive; the widget itself manages the index.
          },
          itemBuilder: (context, index) => _CarouselDemoCard(
            item: _items[index],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomizationPanel(BuildContext context) {
    return CustomizationPanel(
      onUpdate: () => setState(() {}),
      onReset: _resetSettings,
      sections: [
        CustomizationSection('LAYOUT', [
          SliderControl(
            label: 'Height',
            value: _height,
            min: 220,
            max: 500,
            onChanged: (value) => setState(() => _height = value),
          ),
          SliderControl(
            label: 'Viewport',
            value: _viewportFraction,
            min: 0.25,
            max: 1,
            onChanged: (value) =>
                setState(() => _viewportFraction = value),
          ),
          SliderControl(
            label: 'Item spacing',
            value: _itemSpacing,
            min: 0,
            max: 32,
            onChanged: (value) => setState(() => _itemSpacing = value),
          ),
          SliderControl(
            label: 'Initial index',
            value: _initialIndex.toDouble(),
            min: 0,
            max: (_items.length - 1).toDouble(),
            onChanged: (value) =>
                setState(() => _initialIndex = value.round()),
          ),
        ]),
        CustomizationSection('3D EFFECTS', [
          SliderControl(
            label: 'Lift',
            value: _lift,
            min: 0,
            max: 100,
            onChanged: (value) => setState(() => _lift = value),
          ),
          SliderControl(
            label: 'Tilt',
            value: _tilt,
            min: 0,
            max: 0.5,
            onChanged: (value) => setState(() => _tilt = value),
          ),
          SliderControl(
            label: 'Min scale',
            value: _minScale,
            min: 0.5,
            max: 1,
            onChanged: (value) => setState(() => _minScale = value),
          ),
          SliderControl(
            label: 'Min opacity',
            value: _minOpacity,
            min: 0.1,
            max: 1,
            onChanged: (value) => setState(() => _minOpacity = value),
          ),
        ]),
        CustomizationSection('ANIMATION', [
          SwitchControl(
            label: 'Autoplay',
            value: _autoPlay,
            onChanged: (value) => setState(() => _autoPlay = value),
          ),
          SliderControl(
            label: 'interval (s)',
            value: _autoPlayIntervalSeconds.toDouble(),
            min: 1,
            max: 10,
            onChanged: (value) =>
                setState(() => _autoPlayIntervalSeconds = value.round()),
          ),
          SliderControl(
            label: 'duration(ms)',
            value: _autoPlayDurationMs.toDouble(),
            min: 200,
            max: 1500,
            onChanged: (value) =>
                setState(() => _autoPlayDurationMs = value.round()),
          ),
        ]),
        CustomizationSection('BEHAVIOR', [
          SwitchControl(
            label: 'Tap to focus',
            value: _enableTapToFocus,
            onChanged: (value) =>
                setState(() => _enableTapToFocus = value),
          ),
          SwitchControl(
            label: 'Haptic feedback',
            value: _enableHaptics,
            onChanged: (value) => setState(() => _enableHaptics = value),
          ),
        ]),
        CustomizationSection('INDICATOR', [
          SwitchControl(
            label: 'Show indicator',
            value: _showIndicator,
            onChanged: (value) => setState(() => _showIndicator = value),
          ),
          SliderControl(
            label: 'Indicator space',
            value: _indicatorSpacing,
            min: 0,
            max: 40,
            onChanged: (value) =>
                setState(() => _indicatorSpacing = value),
          ),

        ]),
      ],
    );
  }
}

class _CarouselDemoItem {
  const _CarouselDemoItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
}


class _CarouselDemoCard extends StatelessWidget {
  const _CarouselDemoCard({required this.item});

  final _CarouselDemoItem item;

  @override
  Widget build(BuildContext context) {
    final accent = item.colors.first;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            item.colors.first,
            item.colors.last,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 28,
            spreadRadius: -4,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Decorative ambient glow
          Positioned(
            top: -55,
            right: -45,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Subtle decorative ring
          Positioned(
            top: -38,
            right: -25,
            child: Container(
              width: 135,
              height: 135,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 1.2,
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon container
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(
                    item.icon,
                    color: Colors.white,
                    size: 27,
                  ),
                ),

                const Spacer(),

                // Category indicator
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'FEATURED COMPONENT',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Title
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.12,
                    letterSpacing: -0.7,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 9),

                // Description
                Text(
                  item.subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    height: 1.55,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 18),

                // Bottom divider and arrow
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

