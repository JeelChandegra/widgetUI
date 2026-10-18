import 'package:widget_ui/app_common/export.dart';
import 'package:widget_ui/components/button/pill_switch.dart';

import 'package:widget_ui/components/sliders/elastic_sliders.dart';

import '../../components/stepper/reel_stepper.dart';

// =============================================================================
// CustomizationPanel
//
// A reusable settings panel for component demo pages. Describe the controls as
// data, and the panel lays them out in side-by-side columns (one per section).
//
//   CustomizationPanel(
//     onUpdate: () => setState(() {}),   // called after any control changes
//     onReset: resetSettings,            // optional; hides the button if null
//     sections: [
//       CustomizationSection('LAYOUT', [
//         SliderControl(label: 'Width', value: width, min: 100, max: 350,
//             onChanged: (v) => width = v),
//       ]),
//       CustomizationSection('BEHAVIOR', [
//         SwitchControl(label: 'Draggable', value: draggable,
//             onChanged: (v) => draggable = v),
//       ]),
//     ],
//   )
//
// Control callbacks only need to assign the value. The panel calls [onUpdate]
// right after, which is where you call setState.
// =============================================================================

/// One titled group of controls. It is shown as one column.
class CustomizationSection {
  const CustomizationSection(this.title, this.controls);

  final String title;
  final List<CustomizationControl> controls;
}

/// Base class for everything that can go in a section.
abstract class CustomizationControl {
  const CustomizationControl();

  /// [notify] must be called after the value has been changed.
  Widget build(BuildContext context, VoidCallback notify);
}

/// A numeric slider.
class SliderControl extends CustomizationControl {
  const SliderControl({required this.label, required this.value, required this.min, required this.max, required this.onChanged, this.suffix});

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  /// Optional unit shown after the label, for example `px`.
  final String? suffix;

  @override
  Widget build(BuildContext context, VoidCallback notify) {
    return ElasticSlider(
      label: '$label${suffix == null ? '' : ' ($suffix)'}',
      value: value,

      min: min,
      max: max,
      onChanged: (v) {
        onChanged(v);
        notify();
      },
    );
  }
}

/// An on/off switch.
class SwitchControl extends CustomizationControl {
  const SwitchControl({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, VoidCallback notify) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grey.withOpacity(0.3)),
      ),
      child: PillSwitch(
        value: value,
        label: label,
        onChanged: (v) {
          onChanged(v);
          notify();
        },
      ),
    );
  }
}

/// Pick one option by stepping through it with arrows (a [ReelStepper]).
/// Works with any type, usually an enum: `ReelControl<MyEnum>(options: MyEnum.values, ...)`.
class ReelControl<T> extends CustomizationControl {
  const ReelControl({required this.label, required this.value, required this.options, required this.onChanged, this.getLabel, this.wrap = true});

  final String label;
  final T value;
  final List<T> options;
  final ValueChanged<T> onChanged;

  /// Text for each option. Defaults to `toString()`, or `.name` for enums.
  final String Function(T)? getLabel;

  /// Whether stepping past the last option loops to the first.
  final bool wrap;

  String _labelOf(T v) {
    if (getLabel != null) return getLabel!(v);
    if (v is Enum) return v.name;
    return v.toString();
  }

  @override
  Widget build(BuildContext context, VoidCallback notify) {
    return ReelStepper<T>(
      label: label,
      items: options,
      index: options.indexOf(value),
      itemLabel: _labelOf,
      wrap: wrap,
      style: ReelStepperStyle(
        backgroundColor: AppColors.grey.withOpacity(0.1),
        borderColor: AppColors.grey.withOpacity(0.3),
        windowWidth: 80,
        horizontalPadding: 12,
      ),
      onChanged: (i) {
        onChanged(options[i]);
        notify();
      },
    );
  }
}

/// Escape hatch: put any widget in a section.
class CustomControl extends CustomizationControl {
  const CustomControl(this.builder);

  final Widget Function(BuildContext context, VoidCallback notify) builder;

  @override
  Widget build(BuildContext context, VoidCallback notify) => builder(context, notify);
}

/// The panel itself: header with title and reset button, then the sections as
/// side-by-side columns (4 on wide screens, 2 on medium, 1 on narrow).
class CustomizationPanel extends StatelessWidget {
  const CustomizationPanel({
    super.key,
    required this.sections,
    required this.onUpdate,
    this.title = 'Customization',
    this.onReset,
    this.maxColumns = 4,
    this.minColumnWidth = 240,
    this.columnSpacing = 20,
    this.padding = const EdgeInsets.all(16),
  });

  final List<CustomizationSection> sections;

  /// Called after any control changes its value. Usually `() => setState(() {})`.
  final VoidCallback onUpdate;

  final String title;

  /// If null, the reset button is hidden.
  final VoidCallback? onReset;

  final int maxColumns;
  final double minColumnWidth;
  final double columnSpacing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.grey.withOpacity(0.3)),
        color: AppColors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.grey.withOpacity(0.3))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CustomText(
                  text: title,
                  style: GoogleFonts.jetBrainsMono(fontSize: 14, color: AppColors.white),
                ),
                if (onReset != null)
                  IconButton(
                    tooltip: 'Reset settings',
                    onPressed: onReset,
                    icon: Icon(Icons.refresh, color: AppColors.white),
                  )
                else
                  const SizedBox(height: 48),
              ],
            ),
          ),

          // Sections as columns
          Padding(
            padding: padding,
            child: _SectionColumns(
              maxColumns: maxColumns,
              minColumnWidth: minColumnWidth,
              spacing: columnSpacing,
              children: [for (final section in sections) _SectionColumn(section: section, onUpdate: onUpdate)],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionColumn extends StatelessWidget {
  const _SectionColumn({required this.section, required this.onUpdate});

  final CustomizationSection section;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: CustomText(
            text: section.title,
            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.white.withOpacity(0.55)),
          ),
        ),
        for (final control in section.controls) control.build(context, onUpdate),
      ],
    );
  }
}

/// Equal-width, top-aligned columns that wrap when there isn't enough room.
class _SectionColumns extends StatelessWidget {
  const _SectionColumns({required this.children, required this.maxColumns, required this.minColumnWidth, required this.spacing});

  final List<Widget> children;
  final int maxColumns;
  final double minColumnWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final fit = ((available + spacing) / (minColumnWidth + spacing)).floor().clamp(1, maxColumns).toInt();
        final columns = children.isEmpty ? 1 : fit.clamp(1, children.length).toInt();
        final width = (available - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: 28,
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }
}
