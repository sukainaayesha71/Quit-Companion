import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression guard for "serverClientId must be provided on Android".
///
/// google_sign_in_android 7.x reads the OAuth Web client ID at runtime from
/// the `default_web_client_id` string that the google-services plugin
/// generates from google-services.json. Release builds shrink resources and
/// removed that string, because it's only looked up by name. Both halves
/// must stay in place.
void main() {
  test('release resource shrinking keeps default_web_client_id', () {
    final keep = File('android/app/src/main/res/raw/google_sign_in_keep.xml');
    expect(keep.existsSync(), isTrue, reason: 'keep file was removed');
    expect(
      keep.readAsStringSync(),
      contains('tools:keep="@string/default_web_client_id"'),
    );
  });

  test('google-services.json provides a Web OAuth client for this app', () {
    final json =
        jsonDecode(
              File('android/app/google-services.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final clients = (json['client'] as List).cast<Map<String, dynamic>>();
    final app = clients.firstWhere(
      (c) =>
          c['client_info']['android_client_info']['package_name'] ==
          'com.quitcompanion.quit_companion',
    );
    final oauthClients = (app['oauth_client'] as List)
        .cast<Map<String, dynamic>>();
    expect(
      oauthClients.any((c) => c['client_type'] == 3),
      isTrue,
      reason:
          'no Web client (client_type 3): enable Google in Firebase Auth and '
          're-download google-services.json',
    );
  });
}
