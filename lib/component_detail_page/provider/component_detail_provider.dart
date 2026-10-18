import 'package:widget_ui/app_common/export.dart';
import 'package:widget_ui/app_common/widget/custom_side_bar.dart';
import 'package:widget_ui/component_detail_page/detail_pages/card_carousel_details/view/card_carousel.dart';
import 'package:widget_ui/component_detail_page/detail_pages/carouel/view/carousel_detail_page.dart';
import 'package:widget_ui/component_detail_page/detail_pages/curved_peak/view/curved_peek_carousel_detail_page.dart';
import 'package:widget_ui/components/carousel/carousel.dart';

import '../../components/carousel/card_carousel.dart';
import '../../components/carousel/curved_peek.dart';
import '../../components/carousel/orbit_images.dart';
import '../detail_pages/orbit_image_detail/view/orbit_image_detail.dart';

final selectedComponentProvider =
NotifierProvider<SelectedComponentNotifier, String?>(
  SelectedComponentNotifier.new,
);

class SelectedComponentNotifier extends Notifier<String?> {
  @override
  String? build() => 'card-carousel';

  void set(String? id) => state = id;
}

final sidebarSectionsProvider = Provider<List<SidebarSection>>((ref) {
  return [
    SidebarSection(
      id: 'Carousel',
      title: 'Carousel',
      items: [
        SidebarItem(
          id: 'card-carousel',
          label: 'Card Carousel',
          previewBuilder: (_) => const CardCarousel(
            size: 150,
            showDots: false,
            cardRadius: 20,
            showFavourite: false,
          ),
        ),
        SidebarItem(
          id: 'carousel',
          label: 'Circular Carousel',
          previewBuilder: (_) => SizedBox(
            width: double.infinity,
            height: 120,
            child: IgnorePointer(
              child: CircularCarousel(
                items: [
                  CircularCarouselItem.network(
                    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=500',
                    title: 'Nature',
                  ),
                  CircularCarouselItem.network(
                    'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=500',
                    title: 'Mountains',
                  ),
                  CircularCarouselItem.network(
                    'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=500',
                    title: 'Lake',
                  ),
                ],
                cardWidth: 100,
                aspectRatio: 1,
                gap: 12,
                minTiles: 6,
                captions: false,
                autoplay: CarouselAutoplay.drift,
                intro: CarouselIntro.none,
                draggable: true,
                focusOnClick: false,
              ),
            ),
          ),
        ),
        SidebarItem(
          id: 'curved-peek-carousel',
          label: 'Curved Peek Carousel',
          previewBuilder: (_) => const SizedBox(
            width: double.infinity,
            height: 120,
            child: IgnorePointer(
              child: CurvedPeekCarouselPreview(
                height: 100,
                autoPlay: true,
              ),
            ),
          ),
        ),SidebarItem(
          id: 'orbit-image',
          label: 'Orbit Image Carousel',
          previewBuilder: (_) => const SizedBox(
            width: double.infinity,
            height: 120,
            child: OrbitImages(
              images: const [
                NetworkImage(
                  'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=300',
                ),
                NetworkImage(
                  'https://images.unsplash.com/photo-1519904981063-b0cf448d479e?w=300',
                ),
                NetworkImage(
                  'https://images.unsplash.com/photo-1533628635777-112b2239b1c7?w=300',
                ),
              ],
              shape: OrbitShape.ellipse,
              radiusX: 150,
              radiusY: 90,
              itemSize: 50,
              duration: const Duration(seconds: 20),
              showPath: true,
              width: 350,
              height: 300,
            ),
          ),
        ),
      ],
    ),
  ];
});

class ComponentEntry {
  const ComponentEntry({
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.screen,
  });

  final String slug;
  final String title;
  final String subtitle;
  final Widget Function() screen;
}

final componentEntriesProvider = Provider<List<ComponentEntry>>((ref) {
  return [
    ComponentEntry(
      slug: 'card-carousel',
      title: 'Card Carousel',
      subtitle:
      'A swipeable image carousel with tilted stacked cards, animated pagination dots, and a favourite button.',
      screen: () => const CardCarouselDetails(),
    ),
    ComponentEntry(
      slug: 'carousel',
      title: 'Circular Carousel',
      subtitle:
      'A 3D circular carousel with animated transitions, configurable layout, and autoplay options.',
      screen: () => const CarouselDetailPage(),
    ),
    ComponentEntry(
      slug: 'curved-peek-carousel',
      title: 'Curved Peek Carousel',
      subtitle:
      'An animated carousel with a focused center card, partially visible neighbouring cards, curved lift, tilt, and an optional page indicator.',
      screen: () => const CurvedPeekCarouselDetailPage(),
    ),
    ComponentEntry(
      slug: 'orbit-image',
      title: 'Orbit Image Carousel',
      subtitle:
      'An animated carousel with a focused center card, partially visible neighbouring cards, curved lift, tilt, and an optional page indicator.',
      screen: () => const OrbitImageDetail(),
    ),
  ];
});
