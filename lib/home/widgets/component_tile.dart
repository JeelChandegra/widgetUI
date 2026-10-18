import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:widget_ui/app_common/custom_text.dart';
import 'package:widget_ui/home/provider/home_provider.dart';

class ComponentTile extends ConsumerWidget {
  final String title;
  final String subtitle;
  final Widget? preview;
  final List<String> tags;
  final VoidCallback? onCopy;
  final ComponentCategory category;

  const ComponentTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.preview,
    this.tags = const ['Flutter', 'React Native'],
    this.onCopy,
    required this.category,
  });

  static const Color _cardBg = Color(0xFF0B0B0B);
  static const Color _innerBg = Color(0xFF000000);
  static const Color _border = Color(0x1AFFFFFF);
  static const Color _muted = Color(0xFF8A8A8A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preview
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: _innerBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox.expand(child: preview ?? const SizedBox()),
            ),
          ),
          const SizedBox(height: 16),

          // Title + copy
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: CustomText(
                  text: title,
                  style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onCopy,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.copy_rounded, size: 15, color: _muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Subtitle
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.jetBrainsMono(fontSize: 12, height: 1.5, color: _muted),
          ),

          // Push tags to bottom
          const Spacer(),

          // Tags
          Wrap(spacing: 8, runSpacing: 8, children: tags.map(_chip).toList()),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      child: Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: _muted)),
    );
  }
}
