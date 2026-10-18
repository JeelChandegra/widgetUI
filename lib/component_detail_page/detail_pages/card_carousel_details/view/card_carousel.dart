import 'package:widget_ui/app_common/responsive_split.dart';
import 'package:widget_ui/app_common/widget/customize_panel.dart';
import 'package:widget_ui/app_common/widget/installation_widget.dart';
import 'package:widget_ui/components/carousel/card_carousel.dart';

import '../../../../app_common/export.dart';
import '../../../../app_common/widget/component_preview.dart';
import '../../../../app_common/widget/props_table.dart';

class CardCarouselDetails extends StatefulWidget {
  const CardCarouselDetails({super.key});

  @override
  State<CardCarouselDetails> createState() => _CardCarouselDetailsState();
}

class _CardCarouselDetailsState extends State<CardCarouselDetails> {
  // Defaults, also used by reset.
  static const _defaultSize = 250.0;
  static const _defaultTilt = -6.0;
  static const _defaultDragThreshold = 120.0;
  static const _defaultShowDots = false;
  static const _defaultShowFav = true;

  double size = _defaultSize;
  double tilt = _defaultTilt;
  double dragThreshold = _defaultDragThreshold;
  bool showdots = _defaultShowDots;
  bool showfav = _defaultShowFav;

  void resetSettings() {
    setState(() {
      size = _defaultSize;
      tilt = _defaultTilt;
      dragThreshold = _defaultDragThreshold;
      showdots = _defaultShowDots;
      showfav = _defaultShowFav;
    });
  }

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
            fileName: 'card_carousel.dart',
            sourceAsset: 'assets/component/carousel/card_carousel.txt',
            usage: _usage,
            likeCount: 128,
            onLikeChanged: (liked) => debugPrint('liked: $liked'),
            shareUrl: 'https://yoursite.com/components/card-carousel',
            initialDevice: PreviewDevice.desktop,
            previewMinHeight: 400,
            preview: CardCarousel(
              size: size,
              tilt: tilt,
              cardRadius: 32,
              showFavourite: showfav,
              iconColor: AppColors.black,
              dragThreshold: dragThreshold,
              showDots: showdots,
              slides: [
                CarouselSlide.network(1, 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600', alt: 'Mountain landscape'),
                CarouselSlide.network(2, 'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=600', alt: 'Lake landscape'),
                CarouselSlide.network(3, 'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=600', alt: 'Lake and mountains'),
              ],
              onChanged: (index) {
                debugPrint('Current slide: $index');
              },
              onFavourite: (index) {
                debugPrint('Favourited slide: $index');
              },
            ),
          ),

          // CUSTOMIZATION (reusable widget)
          secondary: CustomizationPanel(
            onUpdate: () => setState(() {}),
            onReset: resetSettings,
            sections: [
              CustomizationSection('LAYOUT', [
                SliderControl(label: 'Size', value: size, min: 100, max: 300, onChanged: (v) => size = v),
                SliderControl(label: 'Tilt', value: tilt, min: -100, max: 100, onChanged: (v) => tilt = v),
                SliderControl(label: 'Drag Threshold', value: dragThreshold, min: 100, max: 250, onChanged: (v) => dragThreshold = v),
              ]),
              CustomizationSection('VISIBILITY', [
                SwitchControl(label: 'Show Dots', value: showdots, onChanged: (v) => showdots = v),
                SwitchControl(label: 'Show Favourite', value: showfav, onChanged: (v) => showfav = v),
              ]),
            ],
          ),
        ),
        InstallationWidget(),
        PropsTable(
          props: const [
            PropSpec(
              name: 'slides',
              type: 'List<CarouselSlide>?',
              description: 'List of slides to display. Defaults to six landscape photos.',
              group: 'Content',
            ),
            PropSpec(name: 'initialIndex', type: 'int', defaultValue: '0', description: 'Index of the slide shown initially.', group: 'Content'),
            PropSpec(
              name: 'onChanged',
              type: 'ValueChanged<int>?',
              description: 'Called when the active slide changes, with its index.',
              group: 'Callbacks',
            ),
            PropSpec(
              name: 'onFavourite',
              type: 'ValueChanged<int>?',
              description: 'Called when the favourite button is tapped, with the current slide index.',
              group: 'Callbacks',
            ),
            PropSpec(name: 'size', type: 'double', defaultValue: '256', description: 'Width and height of the card area.', group: 'Layout'),
            PropSpec(name: 'tilt', type: 'double', defaultValue: '-6', description: 'Rotation of the entire carousel in degrees.', group: 'Layout'),
            PropSpec(
              name: 'cardTilt',
              type: 'double',
              defaultValue: '-3',
              description: 'Rotation of the front card at rest, in degrees.',
              group: 'Layout',
            ),
            PropSpec(name: 'cardRadius', type: 'double', defaultValue: '40', description: 'Corner radius of the card.', group: 'Layout'),
            PropSpec(
              name: 'dragThreshold',
              type: 'double',
              defaultValue: '120',
              description: 'Horizontal drag distance in pixels required to change slides.',
              group: 'Interaction',
            ),
            PropSpec(
              name: 'dragElastic',
              type: 'double',
              defaultValue: '0.5',
              description: 'Controls how much the card follows the finger during dragging, from 0 to 1.',
              group: 'Interaction',
            ),
            PropSpec(
              name: 'showFavourite',
              type: 'bool',
              defaultValue: 'true',
              description: 'Whether to display the favourite button.',
              group: 'Visibility',
            ),
            PropSpec(
              name: 'favouriteIcon',
              type: 'Widget?',
              description: 'Custom icon displayed inside the favourite button. Defaults to an outlined heart.',
              group: 'Appearance',
            ),
            PropSpec(
              name: 'showPagination',
              type: 'bool',
              defaultValue: 'true',
              description: 'Whether to display the pagination section.',
              group: 'Visibility',
            ),
            PropSpec(
              name: 'showDots',
              type: 'bool',
              defaultValue: 'true',
              description: 'Whether to display pagination dots. Requires showPagination to be true.',
              group: 'Visibility',
            ),
            PropSpec(name: 'cardColor', type: 'Color?', description: 'Background color of the card.', group: 'Appearance'),
            PropSpec(name: 'borderColor', type: 'Color?', description: 'Border color of the card.', group: 'Appearance'),
            PropSpec(name: 'buttonColor', type: 'Color?', description: 'Background color of the favourite button.', group: 'Appearance'),
            PropSpec(name: 'iconColor', type: 'Color?', description: 'Color of the favourite icon.', group: 'Appearance'),
            PropSpec(
              name: 'dotColor',
              type: 'Color',
              defaultValue: 'Color(0xFFCCC7B8)',
              description: 'Color of the pagination dots.',
              group: 'Appearance',
            ),
          ],
        ),
      ],
    );
  }
}

const _usage = '''
CardCarousel(
  size: 260,
  tilt: -6,
  cardTilt: -3,
  cardRadius: 32,
  showFavourite: true,
  showPagination: true,
  dragThreshold: 120,
  slides: [
    CarouselSlide.network(
      1,
      'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600',
      alt: 'Mountain landscape',
    ),
    CarouselSlide.network(
      2,
      'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=600',
      alt: 'Lake landscape',
    ),
    CarouselSlide.network(
      3,
      'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=600',
      alt: 'Lake and mountains',
    ),
  ],
  onChanged: (index) {
    debugPrint('Current slide: \$index');
  },
  onFavourite: (index) {
    debugPrint('Favourited slide: \$index');
  },
)
''';
