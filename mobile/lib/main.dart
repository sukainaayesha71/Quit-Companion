import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:quit_companion/app/quit_companion_app.dart';
import 'package:quit_companion/core/config/firebase_options.dart';
import 'package:quit_companion/core/config/otp_backend_config.dart';
import 'package:quit_companion/features/auth/data/account_deletion_repository.dart';
import 'package:quit_companion/features/auth/data/biometric_lock_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    QuitCompanionApp(
      biometricLockService: SharedPreferencesBiometricLockService(),
      accountDeletionRepository: HttpAccountDeletionRepository(
        baseUrl: OtpBackendConfig.baseUrl,
      ),
    ),
  );
}
