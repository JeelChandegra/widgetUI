import 'package:flutter/services.dart';
import 'package:widget_ui/app_common/widget/component_preview.dart';

import '../export.dart';

class InstallationWidget extends StatefulWidget {
  const InstallationWidget({super.key});

  @override
  State<InstallationWidget> createState() => _InstallationWidgetState();
}

class _InstallationWidgetState extends State<InstallationWidget> {
  @override
  Widget build(BuildContext context) {
    bool copied = false;

    Future<void> _copy() async {
      // await Clipboard.setData(ClipboardData(text: widget.code));
      if (!mounted) return;
      setState(() => copied = true);
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) setState(() => copied = false);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomText(
          text: "Installation",
          style: GoogleFonts.jetBrainsMono(color: AppColors.white),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grey.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomText(
                text: "flutter pub get card_carousel",
                style: GoogleFonts.jetBrainsMono(color: AppColors.white),
              ),
              CopyButton(copied: copied, onTap: _copy),
            ],
          ),
        ),
      ],
    );
  }
}
