import 'package:url_launcher/url_launcher.dart';

/// Opens the dialer, SMS app or a website for the Crisis Support screen.
/// Behind an interface so widget tests never start a real phone call.
abstract class HelplineLauncher {
  /// Returns false if nothing could handle the request (e.g. a tablet with
  /// no dialer), so the screen can fall back to copying the number.
  Future<bool> call(String number);
  Future<bool> text(String number);
  Future<bool> openWebsite(String url);
}

class UrlHelplineLauncher implements HelplineLauncher {
  const UrlHelplineLauncher();

  @override
  Future<bool> call(String number) => _launch(Uri(scheme: 'tel', path: number));

  @override
  Future<bool> text(String number) => _launch(Uri(scheme: 'sms', path: number));

  @override
  Future<bool> openWebsite(String url) =>
      _launch(Uri.parse(url), mode: LaunchMode.externalApplication);

  Future<bool> _launch(
    Uri uri, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      return false;
    }
  }
}
