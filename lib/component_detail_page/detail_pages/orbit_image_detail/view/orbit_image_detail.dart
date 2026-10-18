import 'package:widget_ui/app_common/responsive_split.dart';
import 'package:widget_ui/app_common/widget/customize_panel.dart';
import 'package:widget_ui/app_common/widget/installation_widget.dart';
import 'package:widget_ui/components/carousel/orbit_images.dart';

import '../../../../app_common/export.dart';
import '../../../../app_common/widget/component_preview.dart';
import '../../../../app_common/widget/props_table.dart';

class OrbitImageDetail extends StatefulWidget {
  const OrbitImageDetail({super.key});

  @override
  State<OrbitImageDetail> createState() => _OrbitImageDetailState();
}

class _OrbitImageDetailState extends State<OrbitImageDetail> {
  // Defaults, also used by reset.
  static const _defaultShape = OrbitShape.ellipse;
  static const _defaultRadiusX = 140.0;
  static const _defaultRadiusY = 80.0;
  static const _defaultRadius = 110.0;
  static const _defaultItemSize = 48.0;
  static const _defaultRotation = -8.0;
  static const _defaultDurationSeconds = 20.0;
  static const _defaultDirection = OrbitDirection.normal;
  static const _defaultShowPath = true;
  static const _defaultFill = true;
  static const _defaultPaused = false;

  OrbitShape shape = _defaultShape;
  double radiusX = _defaultRadiusX;
  double radiusY = _defaultRadiusY;
  double radius = _defaultRadius;
  double itemSize = _defaultItemSize;
  double rotation = _defaultRotation;
  double durationSeconds = _defaultDurationSeconds;
  OrbitDirection direction = _defaultDirection;
  bool showPath = _defaultShowPath;
  bool fill = _defaultFill;
  bool paused = _defaultPaused;

  void resetSettings() {
    setState(() {
      shape = _defaultShape;
      radiusX = _defaultRadiusX;
      radiusY = _defaultRadiusY;
      radius = _defaultRadius;
      itemSize = _defaultItemSize;
      rotation = _defaultRotation;
      durationSeconds = _defaultDurationSeconds;
      direction = _defaultDirection;
      showPath = _defaultShowPath;
      fill = _defaultFill;
      paused = _defaultPaused;
    });
  }

  static const List<ImageProvider> _images = [
    NetworkImage('https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=300'),
    NetworkImage('https://images.unsplash.com/photo-1519904981063-b0cf448d479e?w=300'),
    NetworkImage('https://images.unsplash.com/photo-1533628635777-112b2239b1c7?w=300'),
    NetworkImage('https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=300'),
    NetworkImage('https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=300'),
    NetworkImage('https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=300'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 20,
      children: [
        ResponsiveSplit(
          breakpoint: 900,
          primaryFlex: 7,
          secondaryFlex: 3,
          primary: ComponentPreviewPanel(
            fileName: 'orbit_images.dart',
            sourceAsset: 'assets/component/carousel/orbit_images.txt',
            usage: _usage,
            likeCount: 96,
            onLikeChanged: (liked) => debugPrint('liked: $liked'),
            shareUrl: 'https://yoursite.com/components/orbit-images',
            initialDevice: PreviewDevice.desktop,
            previewMinHeight: 450,
            preview: OrbitImages(
              images: _images,
              shape: shape,
              radiusX: radiusX,
              radiusY: radiusY,
              radius: radius,
              itemSize: itemSize,
              rotation: rotation,
              duration: Duration(seconds: durationSeconds.toInt()),
              direction: direction,
              fill: fill,
              paused: paused,
              showPath: showPath,
              pathColor: AppColors.white.withValues(alpha: 0.2),
              pathWidth: 1.5,
              baseWidth: 360,
              width: 360,
              height: 360,
            ),
          ),
          secondary: CustomizationPanel(
            onUpdate: () => setState(() {}),
            onReset: resetSettings,
            sections: [
              CustomizationSection('SHAPE & GEOMETRY', [
                ReelControl<OrbitShape>(
                  label: 'Shape',
                  value: shape,
                  options: const [
                    OrbitShape.ellipse,
                    OrbitShape.circle,
                    OrbitShape.square,
                    OrbitShape.rectangle,
                    OrbitShape.triangle,
                    OrbitShape.star,
                    OrbitShape.heart,
                    OrbitShape.infinity,
                    OrbitShape.wave,
                  ],
                  getLabel: (s) => s.name[0].toUpperCase() + s.name.substring(1),
                  onChanged: (v) => shape = v,
                ),
                SliderControl(
                  label: 'Radius X',
                  value: radiusX,
                  min: 60,
                  max: 170,
                  onChanged: (v) => radiusX = v,
                ),
                SliderControl(
                  label: 'Radius Y',
                  value: radiusY,
                  min: 40,
                  max: 150,
                  onChanged: (v) => radiusY = v,
                ),
                SliderControl(
                  label: 'Radius',
                  value: radius,
                  min: 50,
                  max: 160,
                  onChanged: (v) => radius = v,
                ),
              ]),
              CustomizationSection('LAYOUT', [
                SliderControl(
                  label: 'Item Size',
                  value: itemSize,
                  min: 24,
                  max: 72,
                  onChanged: (v) => itemSize = v,
                ),
                SliderControl(
                  label: 'Rotation',
                  value: rotation,
                  min: -180,
                  max: 180,
                  onChanged: (v) => rotation = v,
                ),
              ]),
              CustomizationSection('ANIMATION', [
                SliderControl(
                  label: 'Duration',
                  value: durationSeconds,
                  min: 5,
                  max: 60,
                  suffix: 's',
                  onChanged: (v) => durationSeconds = v,
                ),
                ReelControl<OrbitDirection>(
                  label: 'Direction',
                  value: direction,
                  options: OrbitDirection.values,
                  getLabel: (d) => d.name[0].toUpperCase() + d.name.substring(1),
                  onChanged: (v) => direction = v,
                ),
                SwitchControl(
                  label: 'Even Spread',
                  value: fill,
                  onChanged: (v) => fill = v,
                ),
                SwitchControl(
                  label: 'Paused',
                  value: paused,
                  onChanged: (v) => paused = v,
                ),
              ]),
              CustomizationSection('VISIBILITY', [
                SwitchControl(
                  label: 'Show Path',
                  value: showPath,
                  onChanged: (v) => showPath = v,
                ),
              ]),
            ],
          ),
        ),
        InstallationWidget(),
        PropsTable(
          props: const [
            PropSpec(
              name: 'images',
              type: 'List<ImageProvider>',
              defaultValue: 'const []',
              description: 'Images to orbit along the shape. Drawn in an itemSize square, fitted and centered.',
              group: 'Content',
            ),
            PropSpec(
              name: 'centerContent',
              type: 'Widget?',
              description: 'Optional widget shown in the center of the orbit, above the orbiting images.',
              group: 'Content',
            ),
            PropSpec(
              name: 'altPrefix',
              type: 'String',
              defaultValue: "'Orbiting image'",
              description: 'Prefix for accessibility image labels when semanticLabel is configured.',
              group: 'Accessibility',
            ),
            PropSpec(
              name: 'semanticLabel',
              type: 'String?',
              description: 'Exposes the orbit to screen readers with this label. When null, excluded from semantics.',
              group: 'Accessibility',
            ),
            PropSpec(
              name: 'shape',
              type: 'OrbitShape',
              defaultValue: 'OrbitShape.ellipse',
              description: 'Geometric path shape (circle, ellipse, square, rectangle, triangle, star, heart, infinity, wave, custom).',
              group: 'Shape',
            ),
            PropSpec(
              name: 'customPath',
              type: 'String?',
              description: 'SVG path string for OrbitShape.custom, formatted in baseWidth units.',
              group: 'Shape',
            ),
            PropSpec(
              name: 'radiusX',
              type: 'double',
              defaultValue: '700',
              description: 'Horizontal radius of ellipse, rectangle, infinity, and wave.',
              group: 'Shape',
            ),
            PropSpec(
              name: 'radiusY',
              type: 'double',
              defaultValue: '170',
              description: 'Vertical radius of ellipse, rectangle, infinity, and wave amplitude.',
              group: 'Shape',
            ),
            PropSpec(
              name: 'radius',
              type: 'double',
              defaultValue: '300',
              description: 'Radius for circle, square, triangle, star, and heart shapes.',
              group: 'Shape',
            ),
            PropSpec(
              name: 'starPoints',
              type: 'int',
              defaultValue: '5',
              description: 'Number of tips when using OrbitShape.star.',
              group: 'Shape',
            ),
            PropSpec(
              name: 'starInnerRatio',
              type: 'double',
              defaultValue: '0.5',
              description: 'Inner radius ratio of the star relative to radius.',
              group: 'Shape',
            ),
            PropSpec(
              name: 'baseWidth',
              type: 'double',
              defaultValue: '1400',
              description: 'Size of the square design space in which shape coordinates live.',
              group: 'Layout',
            ),
            PropSpec(
              name: 'width',
              type: 'double?',
              defaultValue: '100',
              description: 'Box width when not responsive. Null fills the available width.',
              group: 'Layout',
            ),
            PropSpec(
              name: 'height',
              type: 'double?',
              defaultValue: '100',
              description: 'Box height when not responsive. Null matches width.',
              group: 'Layout',
            ),
            PropSpec(
              name: 'responsive',
              type: 'bool',
              defaultValue: 'false',
              description: 'When true, automatically scales the design space to fit the available box size.',
              group: 'Layout',
            ),
            PropSpec(
              name: 'itemSize',
              type: 'double',
              defaultValue: '64',
              description: 'Edge length (width and height) of each orbiting image item.',
              group: 'Layout',
            ),
            PropSpec(
              name: 'rotation',
              type: 'double',
              defaultValue: '-8',
              description: 'Rotation of the entire orbit path in degrees. Images stay upright.',
              group: 'Layout',
            ),
            PropSpec(
              name: 'duration',
              type: 'Duration',
              defaultValue: 'Duration(seconds: 40)',
              description: 'Duration for completing one full lap around the orbit.',
              group: 'Animation',
            ),
            PropSpec(
              name: 'direction',
              type: 'OrbitDirection',
              defaultValue: 'OrbitDirection.normal',
              description: 'Travel direction along the path (normal or reverse).',
              group: 'Animation',
            ),
            PropSpec(
              name: 'easing',
              type: 'Curve',
              defaultValue: 'Curves.linear',
              description: 'Easing curve applied to each lap.',
              group: 'Animation',
            ),
            PropSpec(
              name: 'fill',
              type: 'bool',
              defaultValue: 'true',
              description: 'Whether images are evenly distributed along the path or clustered at the start.',
              group: 'Animation',
            ),
            PropSpec(
              name: 'paused',
              type: 'bool',
              defaultValue: 'false',
              description: 'Freezes orbit motion when true.',
              group: 'Animation',
            ),
            PropSpec(
              name: 'showPath',
              type: 'bool',
              defaultValue: 'false',
              description: 'Whether to render the outline of the orbit trajectory.',
              group: 'Appearance',
            ),
            PropSpec(
              name: 'pathColor',
              type: 'Color',
              defaultValue: 'Color.fromRGBO(0, 0, 0, 0.1)',
              description: 'Stroke color of the orbit path line.',
              group: 'Appearance',
            ),
            PropSpec(
              name: 'pathWidth',
              type: 'double',
              defaultValue: '2',
              description: 'Stroke width of the path line in logical pixels.',
              group: 'Appearance',
            ),
          ],
        ),
      ],
    );
  }
}

const _usage = '''
OrbitImages(
  images: const [
    NetworkImage('https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=300'),
    NetworkImage('https://images.unsplash.com/photo-1519904981063-b0cf448d479e?w=300'),
    NetworkImage('https://images.unsplash.com/photo-1533628635777-112b2239b1c7?w=300'),
    NetworkImage('https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=300'),
    NetworkImage('https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=300'),
    NetworkImage('https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=300'),
  ],
  shape: OrbitShape.ellipse,
  radiusX: 140,
  radiusY: 80,
  itemSize: 48,
  rotation: -8,
  duration: const Duration(seconds: 20),
  showPath: true,
  baseWidth: 360,
  width: 360,
  height: 360,
)
''';
