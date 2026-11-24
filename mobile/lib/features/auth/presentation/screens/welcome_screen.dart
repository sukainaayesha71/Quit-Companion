import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:quit_companion/core/theme/app_theme.dart';

/// First screen of the app. This reproduces docs/UI_Design
/// "welcome screen 1" using the reference's own artwork as the source of
/// truth: `assets/images/welcome_hero_full.png` is that exact 768x1376
/// screenshot with only the two baked-in text/button regions erased, so
/// the illustration (logo, silhouette, broken cigarette, smoke, leaves,
/// arms, hands, legs) renders pixel-for-pixel instead of being
/// hand-approximated. It's shown full-bleed behind real Text/Button
/// widgets positioned at the fractions measured directly on that
/// reference image, so the title, subtitle, and the two small
/// rounded-rectangle Register/Log In buttons land exactly where they do
/// in the screenshot on any screen height (verified against the Samsung
/// S10+).
class WelcomeScreen extends StatelessWidget {
  final VoidCallback onRegisterTap;
  final VoidCallback onLoginTap;

  const WelcomeScreen({
    super.key,
    required this.onRegisterTap,
    required this.onLoginTap,
  });

  /// Tagline exactly as in docs/UI_Design "welcome screen 1", including
  /// its line break after "nicotine-free".
  static const welcomeTagline =
      'Your journey to a nicotine-free\nlife starts here.';

  // Fractions below are measured directly off docs/UI_Design
  // "welcome screen 1" (a 768x1376 PNG): pixel row/column ÷ image
  // height/width. Keeping them as fractions (not fixed dp) is what makes
  // the composition hold up on the S10+'s different aspect ratio.
  static const double _titleTop = 658 / 1376;
  static const double _brandingSidePadding = 24;

  /// Minimum space kept between the branding block and the Register button.
  static const double _brandingGap = 12;
  static const double _registerTop = 982 / 1376;
  static const double _registerHeight = 85 / 1376;
  static const double _loginTop = 1090 / 1376;
  static const double _loginHeight = 90 / 1376;
  static const double _buttonWidthFraction = 444 / 768;
  static const double _buttonElevation = 3;
  static const Color _buttonShadow = Color(0x40000000);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Transparent status bar so the full-bleed hero image (and the logo
    // mark near the very top of it) shows through completely, matching
    // the reference's edge-to-edge composition instead of being covered
    // by an opaque system bar.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/welcome_hero_full.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                final buttonWidth = constraints.maxWidth * _buttonWidthFraction;

                return Stack(
                  children: [
                    // One branding block: title, then the tagline directly
                    // underneath, centred together. It is confined to the
                    // band between the title line and the Register button
                    // and scales down (never overlaps the buttons) on
                    // short screens or with very large system text.
                    Positioned(
                      key: const Key('welcome_branding'),
                      top: h * _titleTop,
                      left: _brandingSidePadding,
                      right: _brandingSidePadding,
                      height: h * (_registerTop - _titleTop) - _brandingGap,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width:
                              constraints.maxWidth - 2 * _brandingSidePadding,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Quit Companion',
                                key: const Key('welcome_title'),
                                style: textTheme.headlineLarge,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                welcomeTagline,
                                key: const Key('welcome_tagline'),
                                // Design: dark, regular-weight tagline
                                // (bodyLarge is textPrimary, 16 sp).
                                style: textTheme.bodyLarge?.copyWith(
                                  height: 1.35,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: h * _registerTop,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SizedBox(
                          width: buttonWidth,
                          height: h * _registerHeight,
                          child: ElevatedButton(
                            key: const Key('welcome_register_button'),
                            onPressed: onRegisterTap,
                            // Design: terracotta pill with a soft drop
                            // shadow (theme colours/shape kept).
                            style: ElevatedButton.styleFrom(
                              elevation: _buttonElevation,
                              shadowColor: _buttonShadow,
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('Register'),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: h * _loginTop,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SizedBox(
                          width: buttonWidth,
                          height: h * _loginHeight,
                          child: OutlinedButton(
                            key: const Key('welcome_login_button'),
                            onPressed: onLoginTap,
                            // Design: white pill, sage outline and text,
                            // soft drop shadow.
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              elevation: _buttonElevation,
                              shadowColor: _buttonShadow,
                              foregroundColor: AppColors.sageDark,
                              side: const BorderSide(
                                color: AppColors.sage,
                                width: 1.5,
                              ),
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Log In'),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
