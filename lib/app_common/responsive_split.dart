import 'package:flutter/material.dart';

/// Two panels side by side on wide screens, stacked on narrow ones.
class ResponsiveSplit extends StatelessWidget {
  const ResponsiveSplit({
    super.key,
    required this.primary,
    required this.secondary,
    this.primaryFlex = 7,
    this.secondaryFlex = 3,
    this.breakpoint = 900,
    this.spacing = 20,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final Widget primary;
  final Widget secondary;
  final int primaryFlex;
  final int secondaryFlex;

  /// Width at or above which the panels sit side by side.
  final double breakpoint;
  final double spacing;

  /// Vertical alignment when side by side.
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= breakpoint;

        if (wide) {
          return Row(
            crossAxisAlignment: crossAxisAlignment,
            spacing: spacing,
            children: [
              Expanded(flex: primaryFlex, child: primary),
              Expanded(flex: secondaryFlex, child: secondary),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing,
          children: [primary, secondary],
        );
      },
    );
  }
}