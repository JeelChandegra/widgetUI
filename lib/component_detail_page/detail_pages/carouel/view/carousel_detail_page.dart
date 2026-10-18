import 'package:widget_ui/app_common/widget/component_preview.dart';
import 'package:widget_ui/app_common/widget/customize_panel.dart';
import 'package:widget_ui/app_common/widget/installation_widget.dart';
import 'package:widget_ui/app_common/widget/props_table.dart';
import 'package:widget_ui/components/carousel/carousel.dart';

import '../../../../app_common/export.dart';

class CarouselDetailPage extends ConsumerStatefulWidget {
  const CarouselDetailPage({super.key});

  @override
  ConsumerState<CarouselDetailPage> createState() => _CarouselDetailPageState();
}

class _CarouselDetailPageState extends ConsumerState<CarouselDetailPage> {
  late final List<CircularCarouselItem> items;

  // Carousel configuration
  double cardWidth = 220;
  double aspectRatio = 1.2;
  double gap = 24;
  double speed = 10;
  double tilt = 0;
  double perspective = 2400;
  double depthFade = 0.5;
  double innerShade = 0.4;
  double stretch = 0.2;
  double parallax = 0.2;
  double cornerRadius = 16;
  double momentum = 0.6;
  double interval = 3;

  double minTiles = 12;

  bool captions = true;
  bool draggable = true;
  bool pauseOnHover = true;
  bool snap = true;
  bool focusOnClick = true;

  CarouselPreset preset = CarouselPreset.cylinder;
  CarouselIntro intro = CarouselIntro.rise;
  CarouselAutoplay autoplay = CarouselAutoplay.drift;
  CarouselDirection direction = CarouselDirection.left;

  @override
  void initState() {
    super.initState();

    items = [
      CircularCarouselItem.network(
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=500',
        title: 'Nature',
        subtitle: 'Explore the outdoors',
      ),
      CircularCarouselItem.network(
        'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=500',
        title: 'Mountains',
        subtitle: 'Discover new heights',
      ),
      CircularCarouselItem.network('https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=500', title: 'Lake', subtitle: 'Find your calm'),
    ];
  }

  void resetSettings() {
    setState(() {
      cardWidth = 220;
      aspectRatio = 1.2;
      gap = 24;
      speed = 10;
      tilt = 0;
      perspective = 2400;
      depthFade = 0.5;
      innerShade = 0.4;
      stretch = 0.2;
      parallax = 0.2;
      cornerRadius = 16;
      momentum = 0.6;
      interval = 3;
      minTiles = 12;

      captions = true;
      draggable = true;
      pauseOnHover = true;
      snap = true;
      focusOnClick = true;

      preset = CarouselPreset.cylinder;
      intro = CarouselIntro.rise;
      autoplay = CarouselAutoplay.drift;
      direction = CarouselDirection.left;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 20,
      children: [
        // LIVE PREVIEW
        SizedBox(
          height: 580,
          child: ComponentPreviewPanel(
            usage: _usage,
            sourceAsset: "assets/component/carousel/circular_carosel.txt",
            preview: SizedBox(
              height: 420,
              width: double.infinity,
              child: CircularCarousel(
                items: items,
                preset: preset,
                cardWidth: cardWidth,
                aspectRatio: aspectRatio,
                gap: gap,
                minTiles: minTiles.round(),
                captions: captions,
                autoplay: autoplay,
                speed: speed,
                interval: interval,
                intro: intro,
                direction: direction,
                draggable: draggable,
                pauseOnHover: pauseOnHover,
                snap: snap,
                focusOnClick: focusOnClick,
                momentum: momentum,
                cornerRadius: cornerRadius,
                tilt: tilt,
                perspective: perspective,
                depthFade: depthFade,
                innerShade: innerShade,
                stretch: stretch,
                parallax: parallax,
                onActiveChanged: (index) {
                  debugPrint('Active carousel item: ${items[index].title}');
                },
              ),
            ),
          ),
        ),

        // CUSTOMIZATION (reusable widget)
        CustomizationPanel(
          onUpdate: () => setState(() {}),
          onReset: resetSettings,
          sections: [
            CustomizationSection('LAYOUT', [
              SliderControl(label: 'Width', value: cardWidth, min: 100, max: 350, onChanged: (v) => cardWidth = v),
              SliderControl(label: 'Ratio', value: aspectRatio, min: 0.5, max: 2, onChanged: (v) => aspectRatio = v),
              SliderControl(label: 'Gap', value: gap, min: 0, max: 80, onChanged: (v) => gap = v),
              SliderControl(label: 'Radius', value: cornerRadius, min: 0, max: 40, onChanged: (v) => cornerRadius = v),
              SliderControl(label: 'Tiles', value: minTiles, min: 3, max: 30, onChanged: (v) => minTiles = v),
            ]),
            CustomizationSection('3D EFFECTS', [
              SliderControl(label: 'Tilt', value: tilt, min: -30, max: 30, onChanged: (v) => tilt = v),
              SliderControl(label: 'Perspective', value: perspective, min: 500, max: 4000, onChanged: (v) => perspective = v),
              SliderControl(label: 'Depth Fade', value: depthFade, min: 0, max: 1, onChanged: (v) => depthFade = v),
              SliderControl(label: 'Inner Shade', value: innerShade, min: 0, max: 1, onChanged: (v) => innerShade = v),
              SliderControl(label: 'Stretch', value: stretch, min: 0, max: 1, onChanged: (v) => stretch = v),
              SliderControl(label: 'Parallax', value: parallax, min: 0, max: 1, onChanged: (v) => parallax = v),
            ]),
            CustomizationSection('ANIMATION', [
              ReelControl<CarouselPreset>(label: 'Preset', value: preset, options: CarouselPreset.values, onChanged: (v) => preset = v),
              ReelControl<CarouselIntro>(label: 'Intro', value: intro, options: CarouselIntro.values, onChanged: (v) => intro = v),
              ReelControl<CarouselAutoplay>(label: 'Autoplay', value: autoplay, options: CarouselAutoplay.values, onChanged: (v) => autoplay = v),
              ReelControl<CarouselDirection>(label: 'Direction', value: direction, options: CarouselDirection.values, onChanged: (v) => direction = v),
              SliderControl(label: 'Speed', value: speed, min: 1, max: 60, onChanged: (v) => speed = v),
              SliderControl(label: 'Interval', value: interval, min: 0.5, max: 10, onChanged: (v) => interval = v),
              SliderControl(label: 'Momentum', value: momentum, min: 0, max: 1, onChanged: (v) => momentum = v),
            ]),
            CustomizationSection('BEHAVIOR', [
              SwitchControl(label: 'Show Captions', value: captions, onChanged: (v) => captions = v),
              SwitchControl(label: 'Draggable', value: draggable, onChanged: (v) => draggable = v),
              SwitchControl(label: 'Pause on Hover', value: pauseOnHover, onChanged: (v) => pauseOnHover = v),
              SwitchControl(label: 'Snap to Card', value: snap, onChanged: (v) => snap = v),
              SwitchControl(label: 'Focus on Click', value: focusOnClick, onChanged: (v) => focusOnClick = v),
            ]),
          ],
        ),
        InstallationWidget(),

        // PROPS TABLE

        PropsTable(
          props: const [
            PropSpec(
              name: 'items',
              type: 'List<CircularCarouselItem>',
              description: 'Items displayed around the carousel.',
              group: 'Content',
            ),
            PropSpec(
              name: 'preset',
              type: 'CarouselPreset',
              defaultValue: 'cylinder',
              description: 'Carousel arrangement: cylinder, wheel, or panorama.',
              group: 'Layout',
            ),
            PropSpec(
              name: 'cardWidth',
              type: 'double',
              defaultValue: '220',
              description: 'Width of each carousel card.',
              group: 'Layout',
            ),
            PropSpec(
              name: 'aspectRatio',
              type: 'double',
              defaultValue: '1',
              description: 'Card width divided by card height.',
              group: 'Layout',
            ),
            PropSpec(
              name: 'gap',
              type: 'double',
              defaultValue: '24',
              description: 'Spacing between cards along the carousel ring.',
              group: 'Layout',
            ),
            PropSpec(
              name: 'tilt',
              type: 'double',
              defaultValue: '0',
              description: 'Tilt of the carousel ring in degrees.',
              group: '3D Effects',
            ),
            PropSpec(
              name: 'perspective',
              type: 'double',
              defaultValue: '2400',
              description: 'Camera distance; higher values produce a flatter effect.',
              group: '3D Effects',
            ),
            PropSpec(
              name: 'depthFade',
              type: 'double',
              defaultValue: '0.5',
              description: 'Controls fading of cards farther from the viewer.',
              group: '3D Effects',
            ),
            PropSpec(
              name: 'innerShade',
              type: 'double',
              defaultValue: '0.4',
              description: 'Controls shading on the inner faces of cards.',
              group: '3D Effects',
            ),
            PropSpec(
              name: 'stretch',
              type: 'double',
              defaultValue: '0',
              description: 'Controls additional height of front-facing cards.',
              group: '3D Effects',
            ),
            PropSpec(
              name: 'parallax',
              type: 'double',
              defaultValue: '0',
              description: 'Controls image movement inside the card during rotation.',
              group: '3D Effects',
            ),
            PropSpec(
              name: 'autoplay',
              type: 'CarouselAutoplay',
              defaultValue: 'drift',
              description: 'Autoplay behavior: none, drift, or step.',
              group: 'Animation',
            ),
            PropSpec(
              name: 'speed',
              type: 'double',
              defaultValue: '14',
              description: 'Drift speed in degrees per second.',
              group: 'Animation',
            ),
            PropSpec(
              name: 'interval',
              type: 'double',
              defaultValue: '3',
              description: 'Seconds between autoplay steps.',
              group: 'Animation',
            ),
            PropSpec(
              name: 'direction',
              type: 'CarouselDirection',
              defaultValue: 'left',
              description: 'Direction of autoplay movement.',
              group: 'Animation',
            ),
            PropSpec(
              name: 'captions',
              type: 'bool',
              defaultValue: 'true',
              description: 'Whether captions are displayed.',
              group: 'Visibility',
            ),
            PropSpec(
              name: 'draggable',
              type: 'bool',
              defaultValue: 'true',
              description: 'Allows the user to drag the carousel.',
              group: 'Interaction',
            ),
            PropSpec(
              name: 'snap',
              type: 'bool',
              defaultValue: 'true',
              description: 'Settles on a card after dragging or flinging.',
              group: 'Interaction',
            ),
            PropSpec(
              name: 'focusOnClick',
              type: 'bool',
              defaultValue: 'true',
              description: 'Focuses a card when it is clicked.',
              group: 'Interaction',
            ),
            PropSpec(
              name: 'momentum',
              type: 'double',
              defaultValue: '0.6',
              description: 'Controls fling inertia from 0 to 1.',
              group: 'Interaction',
            ),
            PropSpec(
              name: 'cornerRadius',
              type: 'double',
              defaultValue: '12',
              description: 'Corner radius of each card.',
              group: 'Appearance',
            ),
            PropSpec(
              name: 'minTiles',
              type: 'int',
              defaultValue: '12',
              description: 'Minimum number of repeated tiles around the ring.',
              group: 'Layout',
            ),
            PropSpec(
              name: 'intro',
              type: 'CarouselIntro',
              defaultValue: 'rise',
              description: 'Intro animation: none, fade, rise, or spin.',
              group: 'Animation',
            ),
            PropSpec(
              name: 'onActiveChanged',
              type: 'ValueChanged<int>?',
              description: 'Called when the front-facing item changes.',
              group: 'Callbacks',
            ),
          ],
        ),
      ],


    );
  }
  final _usage = '''
CircularCarousel(
  items: [
    CircularCarouselItem.network(
      'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=500',
      title: 'Nature',
      subtitle: 'Explore the outdoors',
    ),
    CircularCarouselItem.network(
      'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=500',
      title: 'Mountains',
      subtitle: 'Discover new heights',
    ),
    CircularCarouselItem.network(
      'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=500',
      title: 'Lake',
      subtitle: 'Find your calm',
    ),
  ],
  preset: CarouselPreset.cylinder,
  cardWidth: 220,
  aspectRatio: 1.2,
  gap: 24,
  captions: true,
  autoplay: CarouselAutoplay.drift,
  onActiveChanged: (index) {
 
  },
)
''';
}