import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/core/config/otp_backend_config.dart';

void main() {
  test('defaults to the host address reachable from the Android emulator', () {
    expect(OtpBackendConfig.baseUrl, 'http://10.0.2.2:8000');
  });
}
