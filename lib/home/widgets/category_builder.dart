import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:widget_ui/app_common/app_colors.dart';
import 'package:widget_ui/app_common/custom_text.dart';
import 'package:widget_ui/home/provider/home_provider.dart';

class CategoryTabs extends ConsumerWidget {
  const CategoryTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoryProvider);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ComponentCategory.values.map((cat) {
        final isSel = cat == selected;
        return GestureDetector(
          onTap: () => ref.read(selectedCategoryProvider.notifier).set(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSel ? const Color(0xFF1C1C1C) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSel ? const Color(0x1AFFFFFF) : Colors.transparent,
              ),
            ),
            child: Text(
              cat.label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                color: isSel ? Colors.white : const Color(0xFF8A8A8A),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}