import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Fixed-aspect header illustration shared by every onboarding screen from
/// Product Selection through Goal Selection. Each PNG (see
/// mobile/tool/crop_onboarding_assets.py) already has its rounded corners
/// baked in against the app's cream background, so it renders as-is with no
/// extra clipping — same pattern as the existing RegisterHeroHeader.
class OnboardingHeaderIllustration extends StatelessWidget {
  final String asset;
  final double aspectRatio;

  const OnboardingHeaderIllustration({
    super.key,
    required this.asset,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Leave most of the usable viewport for the scrollable form and its
    // Continue button, including when the keyboard or system insets grow.
    final media = MediaQuery.of(context);
    final availableHeight = math.max(
      0.0,
      media.size.height - media.viewInsets.bottom - media.padding.vertical,
    );
    final height = math.min(width / aspectRatio, availableHeight * 0.30);
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(asset, fit: BoxFit.cover),
    );
  }
}
