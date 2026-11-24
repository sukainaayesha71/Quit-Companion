import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Keeps cards readable on narrow displays and with larger system text.
/// [fixedExtent] reserves room for images, icons, padding and gaps; text
/// receives additional height using the device's actual text scaler.
class ResponsiveGrid extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int maxColumns;
  final double minItemWidth;
  final double fixedExtent;
  final double fontSize;
  final int textLines;
  final double spacing;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;

  const ResponsiveGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.maxColumns = 3,
    this.minItemWidth = 88,
    this.fixedExtent = 70,
    this.fontSize = 12,
    this.textLines = 3,
    this.spacing = 12,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
    this.padding,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context);
      final width =
          constraints.maxWidth -
          (padding?.resolve(Directionality.of(context)).horizontal ?? 0);
      final readableWidth =
          minItemWidth * math.max(1, scale.scale(fontSize) / fontSize);
      final columns = ((width + spacing) / (readableWidth + spacing))
          .floor()
          .clamp(1, maxColumns);
      final textHeight = scale.scale(fontSize) * 1.5 * textLines;
      return GridView.builder(
        padding: padding ?? EdgeInsets.zero,
        shrinkWrap: shrinkWrap,
        physics: physics,
        itemCount: itemCount,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          mainAxisExtent: fixedExtent + textHeight,
        ),
        itemBuilder: itemBuilder,
      );
    },
  );
}
