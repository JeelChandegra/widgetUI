import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:widget_ui/app_common/app_colors.dart';
import 'package:widget_ui/app_common/custom_text.dart';
import 'package:widget_ui/component_detail_page/provider/component_detail_provider.dart';
import 'package:widget_ui/components/carousel/carousel.dart';
import 'package:widget_ui/home/widgets/category_builder.dart';

import '../provider/home_provider.dart';
import '../widgets/component_tile.dart';

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key});

  @override
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  static const double _breakpoint = 800;
  static const double _panelMaxWidth = 480;
  static const double _maxContentWidth = 1280;

  // Page gutters (one value used by every section so left/right edges line up)
  static const double _gutterWide = 60;
  static const double _gutterNarrow = 20;

  // Panel colors (match the reference image)
  static const Color _panelBg = Color(0xFF0B0B0B);
  static const Color _innerBg = Color(0xFF000000);
  static const Color _border = Color(0x1AFFFFFF);
  static const Color _track = Color(0xFF262626);
  static const Color _muted = Color(0xFF8A8A8A);

  // Panel state
  bool _showCode = false;
  double _speed = 14; // carousel speed
  double _cardWidth = 50; // carousel card width
  double _gap = 25; // carousel gap

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final components = ref.watch(filteredComponentsProvider);
    final selected = ref.watch(selectedCategoryProvider);
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth >= _breakpoint;
            final double gutter = isWide ? _gutterWide : _gutterNarrow;

            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: gutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHero(isWide),
                        SizedBox(height: isWide ? 24 : 8),
                        _buildBrowseRow(isWide),
                        const SizedBox(height: 40),
                        if (components.isEmpty)
                          _buildEmptyState(selected)
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: components.length,
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 420,
                              mainAxisExtent: 340,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemBuilder: (context, index) {
                              final item = components[index];
                              return GestureDetector(
                                onTap: () {
                                  ref.read(selectedComponentProvider.notifier).set(item.title);
                                  context.go('/components/details');
                                },
                                child: item,
                              );
                            },
                          ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(ComponentCategory selected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 28, color: _muted),
          const SizedBox(height: 14),
          Text(
            'No ${selected.label.toLowerCase()} components found',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Nothing here yet. Try another category.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: _muted),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: () => ref.read(selectedCategoryProvider.notifier).set(ComponentCategory.all),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _border),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text('Show all', style: GoogleFonts.jetBrainsMono(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(bool isWide) {
    if (isWide) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(padding: const EdgeInsets.only(right: 40), child: _buildHeroText(isWide)),
              ),
            ),
            Expanded(child: _buildPreviewPanel(previewHeight: 170, alignment: Alignment.centerRight)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroText(isWide),
          const SizedBox(height: 28),
          _buildPreviewPanel(previewHeight: 170, alignment: Alignment.center),
        ],
      ),
    );
  }

  // "Browse Components" title + category tabs
  Widget _buildBrowseRow(bool isWide) {
    final Widget title = InkWell(
      onTap: () => context.go('/components/details'),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: CustomText(
          text: "Browse Components",
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white),
        ),
      ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          title,
          const SizedBox(width: 24),
          const Expanded(
            child: Align(alignment: Alignment.centerRight, child: CategoryTabs()),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 14),
        const Align(alignment: Alignment.centerLeft, child: CategoryTabs()),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Left side: headline, description, button
  // ---------------------------------------------------------------------------
  Widget _buildHeroText(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomText(
          text: "Animated components for Flutter & React Native",
          style: GoogleFonts.inter(fontSize: isWide ? 44 : 32, fontWeight: FontWeight.w600, letterSpacing: -1.5, height: 1.1, color: AppColors.white),
        ),
        const SizedBox(height: 14),
        CustomText(
          text:
              "Preview live, tweak parameters, copy the code. "
              "Native motion design for production mobile apps.",
          style: GoogleFonts.inter(fontSize: 16, height: 1.5, color: AppColors.grey),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.go('/components/details'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.white,
            foregroundColor: AppColors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Browse components",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.black),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.black),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Right side: the whole preview card (header + preview + sliders)
  // ---------------------------------------------------------------------------
  Widget _buildPreviewPanel({required double previewHeight, required Alignment alignment}) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _panelMaxWidth),
        child: _buildPanelCard(previewHeight),
      ),
    );
  }

  Widget _buildPanelCard(double previewHeight) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPanelHeader(),
          const SizedBox(height: 14),
          Container(height: 1, color: _border),
          const SizedBox(height: 14),
          buildPreviewArea(previewHeight),
          const SizedBox(height: 14),
          _buildControls(),
        ],
      ),
    );
  }

  // Header: dot + file name + Preview/Code toggle
  Widget _buildPanelHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(color: Color(0xFF3A3A3A), shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            "Carousel.dart",
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.jetBrainsMono(fontSize: 12, color: _muted),
          ),
        ),
        const SizedBox(width: 10),
        _buildToggle(),
      ],
    );
  }

  Widget _buildToggle() {
    Widget tab(String label, bool selected, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1C1C1C) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: selected ? _border : Colors.transparent),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? Colors.white : _muted),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _innerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          tab("Preview", !_showCode, () => setState(() => _showCode = false)),
          tab("Code", _showCode, () => setState(() => _showCode = true)),
        ],
      ),
    );
  }

  // Black preview box with the carousel (or code) and the Copy button
  Widget buildPreviewArea(double height) {
    return Container(
      height: height,
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
              child: _showCode
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 52),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: SelectableText(
                          _codeSnippet(),
                          textAlign: TextAlign.left,
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, height: 1.5, color: Colors.white70),
                        ),
                      ),
                    )
                  : _buildCarousel(),
            ),
            Positioned(right: 10, bottom: 10, child: _buildCopyButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyButton() {
    return Material(
      color: const Color(0xFF141414),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: _codeSnippet()));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code copied"), duration: Duration(seconds: 1)));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.copy_rounded, size: 13, color: Colors.white70),
              const SizedBox(width: 6),
              Text("Copy", style: GoogleFonts.jetBrainsMono(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  // Bordered controls panel with three sliders
  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSlider(label: "speed", value: _speed, min: 4, max: 30, onChanged: (v) => setState(() => _speed = v)),
          _buildSlider(label: "width", value: _cardWidth, min: 30, max: 90, onChanged: (v) => setState(() => _cardWidth = v)),
          _buildSlider(label: "gap", value: _gap, min: 0, max: 60, onChanged: (v) => setState(() => _gap = v)),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _muted)),
              Text(
                value.round().toString(),
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: Colors.white,
              inactiveTrackColor: _track,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
              overlayShape: SliderComponentShape.noOverlay,
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: SizedBox(
              height: 18,
              child: Slider(value: value, min: min, max: max, onChanged: onChanged),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Carousel (driven by the slider values)
  // ---------------------------------------------------------------------------
  Widget _buildCarousel() {
    return SizedBox.expand(
      child: CircularCarousel(
        items: const [
          CircularCarouselItem(
            image: AssetImage('assets/images/img1.jpg'),
            alt: 'Mist drifting through a valley',
            title: 'Valley',
            subtitle: 'Landscape',
          ),
          CircularCarouselItem(image: AssetImage('assets/images/img2.jpg'), alt: 'A studio portrait', title: 'Portrait', subtitle: 'Studio'),
          CircularCarouselItem(
            image: AssetImage('assets/images/img3.jpg'),
            alt: 'Glass towers from street level',
            title: 'Towers',
            subtitle: 'Architecture',
          ),
        ],
        preset: CarouselPreset.cylinder,
        intro: CarouselIntro.rise,
        cardWidth: _cardWidth,
        aspectRatio: 1,
        speed: _speed,
        captions: false,
        gap: _gap,
        tilt: -5,
        curve: 1,
        perspective: 3200,
        autoplay: CarouselAutoplay.drift,
        interval: 3,
        direction: CarouselDirection.left,
        momentum: 0.6,
        snap: true,
        pauseOnHover: true,
        focusOnClick: true,
        draggable: true,
        parallax: 0.3,
        stretch: 0.5,
        fadeColor: Colors.black,
        depthFade: 0.55,
        innerShade: 0.6,
        cornerRadius: 12,
      ),
    );
  }

  // Code shown in the "Code" tab and copied by the Copy button
  String _codeSnippet() {
    return '''CircularCarousel(
  items: items,
  preset: CarouselPreset.cylinder,
  intro: CarouselIntro.rise,
  cardWidth: ${_cardWidth.round()},
  speed: ${_speed.round()},
  gap: ${_gap.round()},
  tilt: -5,
  perspective: 3200,
  autoplay: CarouselAutoplay.drift,
  direction: CarouselDirection.left,
  draggable: true,
  cornerRadius: 12,
)''';
  }
}
