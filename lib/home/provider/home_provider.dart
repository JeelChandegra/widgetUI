import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widget_ui/components/button/hold_button.dart';
import 'package:widget_ui/components/button/morhphing_button.dart';
import 'package:widget_ui/components/carousel/card_carousel.dart';
import 'package:widget_ui/components/carousel/carousel.dart';
import 'package:widget_ui/components/carousel/orbit_images.dart';
import 'package:widget_ui/components/dropdown/searchable_dropdown.dart';
import 'package:widget_ui/components/interactive/floder_float.dart';
import 'package:widget_ui/components/interactive/logo_loop.dart';
import 'package:widget_ui/components/interactive/pixel_block.dart';
import 'package:widget_ui/components/interactive/swipe_raw.dart';
import 'package:widget_ui/components/interactive/tag_selector.dart';
import 'package:widget_ui/components/nav_bars/curved_bottom_navigation_bar.dart';
import 'package:widget_ui/components/nav_bars/liquid_glass_nav_bar.dart';
import 'package:widget_ui/components/nav_bars/pill_nav_bar.dart';
import 'package:widget_ui/components/tables/tables.dart';
import 'package:widget_ui/components/text/decrypted_text.dart';
import 'package:widget_ui/components/text/masked_heading.dart';
import 'package:widget_ui/components/text/tech_text.dart';
import 'package:widget_ui/components/transitions_reveals/magnetic_reveal.dart';
import 'package:widget_ui/components/transitions_reveals/pixel_swap.dart';
import 'package:widget_ui/home/widgets/component_tile.dart';

import '../../app_common/export.dart';
import '../../components/carousel/curved_peek.dart';

enum ComponentCategory {
  all('All'),
  text('Text'),
  carousel('Carousel'),
  navigation('Navigation'),
  transitionReveal('Transition Reveal'),
  interactive('Interactive'),
  buttons('Button'),
  table('Tables'),
  dropDown('Dropdowns');

  final String label;
  const ComponentCategory(this.label);
}

final catProvider = Provider<List<String>>((ref) {
  return ["Text", "Carousel", "Video", "Audio"];
});

final countProvider = NotifierProvider<CountNotifier, int>(CountNotifier.new);

class CountNotifier extends Notifier<int> {
  @override
  int build() => 0; // 0 = first item selected by default

  void set(int val) {
    state = val;
  }
}

final selectedCategoryProvider = NotifierProvider<SelectedCategoryNotifier, ComponentCategory>(SelectedCategoryNotifier.new);

class SelectedCategoryNotifier extends Notifier<ComponentCategory> {
  @override
  ComponentCategory build() => ComponentCategory.all;

  void set(ComponentCategory c) => state = c;
}

final filteredComponentsProvider = Provider<List<ComponentTile>>((ref) {
  final all = ref.watch(componentListProvider);
  final selected = ref.watch(selectedCategoryProvider);

  if (selected == ComponentCategory.all) return all;
  return all.where((c) => c.category == selected).toList();
});
final componentListProvider = Provider<List<ComponentTile>>((ref) {
  return [
    // ComponentTile(
    //   category: ComponentCategory.carousel,
    //   title: 'Circular 3D Carousel',
    //   subtitle: 'An interactive 3D image carousel with cylinder, wheel, and panorama layouts, smooth animations, autoplay, and draggable navigation',
    //   preview: CircularCarousel(
    //     items: [
    //       CircularCarouselItem(
    //         image: AssetImage('assets/images/img1.jpg'),
    //         alt: 'Mist drifting through a valley',
    //         title: 'Valley',
    //         subtitle: 'Landscape',
    //       ),
    //       CircularCarouselItem(image: AssetImage('assets/images/img2.jpg'), alt: 'A studio portrait', title: 'Portrait', subtitle: 'Studio'),
    //       CircularCarouselItem(
    //         image: AssetImage('assets/images/img3.jpg'),
    //         alt: 'Glass towers from street level',
    //         title: 'Towers',
    //         subtitle: 'Architecture',
    //       ),
    //     ],
    //     preset: CarouselPreset.cylinder,
    //     intro: CarouselIntro.rise,
    //     cardWidth: 100,
    //     aspectRatio: 1,
    //     speed: 10,
    //     captions: false,
    //     gap: 10,
    //     tilt: -5,
    //     curve: 1,
    //     perspective: 3200,
    //     autoplay: CarouselAutoplay.drift,
    //     interval: 3,
    //     direction: CarouselDirection.left,
    //     momentum: 0.6,
    //     snap: true,
    //     pauseOnHover: true,
    //     focusOnClick: true,
    //     draggable: true,
    //     parallax: 0.3,
    //     stretch: 0.5,
    //     fadeColor: Colors.black,
    //     depthFade: 0.55,
    //     innerShade: 0.6,
    //     cornerRadius: 12,
    //   ),
    // ),
    // ComponentTile(
    //   title: "Tech Text",
    //   subtitle: "Interactive, draggable text with a blueprint-style scanner reveal",
    //   category: ComponentCategory.text,
    //   preview: TechText(text: "Hi Jeel"),
    // ),
    // ComponentTile(
    //   title: 'Pill Nav Bar',
    //   subtitle: 'Floating glass bottom navigation with a gliding pill indicator',
    //   category: ComponentCategory.navigation,
    //   preview: const PillNavBarPreview(),
    // ),
    // ComponentTile(
    //   title: 'Decrypted Text',
    //   subtitle:
    //       'Scramble-to-reveal text effect, like Matrix decrypt. Hover, tap, view-trigger, sequential or random reveal, start/end/center direction, custom charset, full styling',
    //   category: ComponentCategory.text,
    //   preview: DecryptedText(
    //     text: 'Hover me!',
    //     animateOn: AnimateOn.hover,
    //     sequential: true,
    //     revealDirection: RevealDirection.center,
    //     style: GoogleFonts.jetBrainsMono(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.grey),
    //     encryptedStyle: GoogleFonts.jetBrainsMono(color: Colors.white),
    //   ),
    // ),
    // ComponentTile(
    //   title: 'Masked Heading',
    //   subtitle: 'Big heading text filled with image or video. Mouse parallax, ambient drift, rise / wipe / fade reveal',
    //   category: ComponentCategory.text,
    //   preview: MaskedHeading.image(
    //     text: 'Designed in the details',
    //     image: const NetworkImage('https://picsum.photos/1600/900'),
    //     reveal: MaskedReveal.rise,
    //     trigger: MaskedTrigger.mount,
    //   ),
    // ),
    // ComponentTile(
    //   title: 'Magnetic Reveal',
    //   subtitle: "Floating labels get pulled into the center, then icons spring outward in a staggered reveal",
    //   category: ComponentCategory.transitionReveal,
    //   preview: DemoScreen(),
    // ),
    // ComponentTile(
    //   title: 'Minimal Searchable Dropdown',
    //   subtitle: "Searchable dropdown with API loading, server-side search and keyboard navigation.",
    //   category: ComponentCategory.dropDown,
    //   preview: CountryDropdownDemo(),
    // ),
    // ComponentTile(
    //   title: 'Folder Float',
    //   subtitle: 'Folder that opens on hover or tap and releases draggable floating notes with physics.',
    //   category: ComponentCategory.interactive,
    //   preview: Center(
    //     child: Padding(
    //       padding: const EdgeInsets.only(top: 70),
    //       child: FolderFloat<String>(
    //         width: 180,
    //         height: 104,
    //         spread: 120,
    //         lift: 20,
    //         items: const [
    //           FolderFloatItem(label: 'Try a warmer palette', value: 'palette'),
    //           FolderFloatItem(label: 'Tighten the spacing', value: 'spacing'),
    //         ],
    //         label: 'Design feedback',
    //         trigger: FolderFloatTrigger.hover,
    //         onSelect: (value, index) => debugPrint('$value $index'),
    //       ),
    //     ),
    //   ),
    // ),
    // ComponentTile(
    //   title: 'Hold Button',
    //   subtitle: 'Press and hold to confirm. Wavy liquid fill sweeps across, glow and pulse on completion.',
    //   category: ComponentCategory.buttons,
    //   preview: Center(
    //     child: Container(
    //       height: 40,
    //       width: 180,
    //       child: HoldButton(
    //         onHold: () => debugPrint('confirmed'),
    //         onTap: () => debugPrint('quick tap'),
    //         label: 'Hold to delete',
    //         doneLabel: 'Deleted',
    //         icon: const Icon(Icons.delete),
    //         doneIcon: const Icon(Icons.check),
    //         backgroundColor: const Color(0xFF27272A),
    //         fillColor: const Color(0xFF5227FF),
    //       ),
    //     ),
    //   ),
    // ),
    // ComponentTile(
    //   title: 'Swipe Row',
    //   subtitle: 'Swipe a row to reveal actions. Long swipe commits the primary action, then the row collapses away.',
    //   category: ComponentCategory.interactive,
    //   preview: Center(
    //     child: ConstrainedBox(
    //       constraints: const BoxConstraints(maxWidth: 320),
    //       child: SwipeRow(
    //         actions: const [
    //           SwipeRowAction(id: 'delete', label: 'Delete'),
    //           SwipeRowAction(id: 'archive', label: 'Archive', icon: Icon(Icons.archive_outlined), dismiss: true),
    //         ],
    //         child: const Text('Design review notes'),
    //       ),
    //     ),
    //   ),
    // ),
    // ComponentTile(
    //   title: 'Logo Loop',
    //   subtitle: 'Infinite logo marquee with hover slowdown and edge fade.',
    //   category: ComponentCategory.carousel,
    //   preview: Center(
    //     child: SizedBox(
    //       width: 380,
    //       child: LogoLoop(
    //         logos: techLogos,
    //         logoHeight: 40,
    //         gap: 20,
    //         speed: 40,
    //         scaleOnHover: true,
    //         fadeOut: true,
    //         fadeOutColor: const Color(0xFF000000), // match the tile background
    //       ),
    //     ),
    //   ),
    // ),
    // ComponentTile(
    //   title: 'Pixel Swap',
    //   subtitle: 'Swaps two views through a grid of pixels that scale in.',
    //   category: ComponentCategory.transitionReveal,
    //   preview: Center(
    //     child: SizedBox(
    //       width: 380,
    //       child: PixelSwap(
    //         firstContent: const ColoredBox(
    //           color: Color(0xFF27272A),
    //           child: Center(
    //             child: Text('Click me', style: TextStyle(color: Colors.white, fontSize: 22)),
    //           ),
    //         ),
    //         secondContent: const ColoredBox(
    //           color: Color(0xFF4F46E5),
    //           child: Center(
    //             child: Text('You found me', style: TextStyle(color: Colors.white, fontSize: 22)),
    //           ),
    //         ),
    //         pixelSize: 48,
    //         borderRadius: BorderRadius.circular(16),
    //       ),
    //     ),
    //   ),
    // ),
    // ComponentTile(
    //   title: 'Orbit Images',
    //   subtitle: 'Images orbiting along a shape, from ellipse to custom path.',
    //   category: ComponentCategory.carousel,
    //   preview: Center(
    //     child: SizedBox(
    //       width: 380,
    //       child: OrbitImages(
    //         images: [for (var i = 1; i <= 6; i++) NetworkImage('https://picsum.photos/300/300?grayscale&random=$i')],
    //         responsive: true,
    //         shape: OrbitShape.ellipse,
    //         radiusX: 900,
    //         radiusY: 240,
    //         itemSize: 250,
    //         showPath: true,
    //         pathColor: AppColors.white.withOpacity(0.3),
    //         duration: const Duration(seconds: 30),
    //       ),
    //     ),
    //   ),
    // ),
    ComponentTile(
      title: 'Morphing Button',
      subtitle: 'An animated, spring-powered pill button that smoothly transforms into an email input field with an integrated submit action.',
      category: ComponentCategory.buttons,
      preview: MorphingButton(
        textStyle: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.4,
          decoration: TextDecoration.none,
        ),

        buttonText: 'Notify',
        placeholder: 'Enter your email',
        expandedWidth: 336,
        icon: Icon(Icons.notifications, size: 16),
        onSubmit: (email) {},
      ),
    ),
    ComponentTile(
      title: 'Card Carousel',
      subtitle:
          'A beautiful, swipeable Flutter image carousel featuring tilted stacked cards, spring-based transitions, animated pagination dots, and a glassmorphism favourite button.',
      category: ComponentCategory.carousel,
      preview: CardCarousel(
        size: 110,
        tilt: -6,
        cardTilt: -3,
        cardRadius: 32,
        showFavourite: false,
        showPagination: true,
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
    ComponentTile(
      title: 'Animated Tags Selector',
      subtitle:
          'A reusable, animated tag-selection widget for Flutter that lets users select and remove tags with responsive wrapping, customizable styling, light/dark theme support, and selection callbacks.',
      category: ComponentCategory.interactive,
      preview: TagsWidget(
        showTitle: false,

        maxWidth: double.infinity,
        selectedContainerColor: const Color(0xFF111714),
        availableContainerColor: const Color(0xFF111714),
        selectedTagColor: const Color(0xFF1B2B22),
        availableTagColor: const Color(0xFF1B2B22),
        borderColor: const Color(0xFF00FF00),
        textColor: const Color(0xFFE4F5E9),
        iconColor: const Color(0xFF00FF5B),

        tags: const [
          TagItem(id: 'flutter', label: 'Flutter'),
          TagItem(id: 'dart', label: 'Dart'),
          TagItem(id: 'node', label: 'Node.js'),
        ],
        initialSelectedTags: const [TagItem(id: 'flutter', label: 'Flutter')],
        onChanged: (selectedTags) {
          final selectedIds = selectedTags.map((tag) => tag.id).toList();

          debugPrint('Selected tags: $selectedIds');
        },
      ),
    ),
    ComponentTile(
      title: 'Curved Peek Carousel',
      subtitle:
          'An animated carousel with one focused item in the center and neighbors peeking from both sides, lifted and tilted into a smooth curved arc. Supports auto-play, tap-to-focus, haptics, controller, and custom indicators.',
      category: ComponentCategory.interactive,
      preview: Center(child: const CurvedPeekCarouselPreview(height: 100)),
    ),
    ComponentTile(
      title: 'Curved Bottom Navigation Bar',
      subtitle:
          'An animated bottom navigation bar with a real cut-out notch. The notch and floating icon circle glide to the selected tab, with customizable colors, shape, motion, haptics, and safe-area support.',
      category: ComponentCategory.navigation, // add to enum if missing
      preview: const BottomNavDemoScreen(), // self-contained preview, owns its index
    ),

    ComponentTile(
      title: 'Liquid Glass Navigation Bar',
      subtitle: 'A customizable, animated glassmorphism bottom navigation bar with premium iOS-inspired effects',
      category: ComponentCategory.navigation, // add to enum if missing
      preview: const MainShell(), // self-contained preview, owns its index
    ),
    ComponentTile(
      title: 'Animated Data Table',
      subtitle:
          'A premium, reusable Flutter data table featuring customizable themes, dynamic columns, animated sorting, smooth row transitions, and interactive actions. Supports dark and light themes, custom cell widgets, and responsive horizontal scrolling',
      category: ComponentCategory.navigation, // add to enum if missing
      preview: const AnimatedDataTableDemo(), // self-contained preview, owns its index
    ),
    ComponentTile(
      title: 'Pixel Display',
      subtitle:
          'A customizable Flutter widget featuring a retro pixel-style display with neon accent glow, a dark gradient background, rounded borders, subtle scanlines, and vignette effects. Ideal for gaming interfaces, arcade screens, and futuristic UI designs',
      category: ComponentCategory.navigation, // add to enum if missing
      preview: Center(
        child: PixelText(
          'Widget',
          autoFit: true,
          style: const PixelStyle(
            pixelSize: 16,
            activeColor: PixelPalette.red,
            animation: PixelAnimation.scan,
            shape: PixelShape.rounded,
            repeat: true,
            repeatDelay: Duration(seconds: 3),
            glow: 0.1,
          ),
        ),
      ),
    ), // self-contained preview, owns its index
  ];
});
