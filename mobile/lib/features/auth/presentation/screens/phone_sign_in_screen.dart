import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/config/phone_auth_config.dart';
import 'package:flutter/services.dart';
import 'package:quit_companion/features/auth/controllers/phone_auth_controller.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/auth/presentation/screens/widgets/auth_hero_header.dart';

/// FR1: minimal phone-number entry step for the Phone/OTP sign-in path.
/// Reuses the existing PhoneAuthController.sendOtp() unchanged and hands
/// off to the existing OtpVerificationScreen (see main.dart) — this screen
/// only exists because the old Email/Phone AuthMethodToggle that used to
/// house the phone field was intentionally removed from Login/Register
/// (2026-08-16 decision); no new auth logic is introduced here.
class PhoneSignInScreen extends StatefulWidget {
  final PhoneAuthController controller;
  final void Function(String phoneNumber) onOtpSent;
  final VoidCallback onBack;
  final bool isRegistration;

  const PhoneSignInScreen({
    super.key,
    required this.controller,
    required this.onOtpSent,
    required this.onBack,
    this.isRegistration = false,
  });

  @override
  State<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends State<PhoneSignInScreen> {
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phoneAuth = widget.controller;
    final isBusy = phoneAuth.status == PhoneAuthStatus.sendingOtp;

    return Scaffold(
      backgroundColor: AppColors.heroHill,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthHeroHeader(
                      heading: widget.isRegistration
                          ? 'Register with Phone'
                          : 'Sign In with Phone',
                      subheading:
                          'Enter your number to receive an OTP on ${PhoneAuthConfig.deliveryChannel}.',
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  key: const Key('phone_sign_in_back_button'),
                                  onPressed: widget.onBack,
                                  icon: const Icon(Icons.arrow_back, size: 18),
                                  label: const Text('Back'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: AppColors.sage,
                                    width: 1.2,
                                  ),
                                ),
                                child: TextField(
                                  key: const Key('phone_sign_in_number_field'),
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9+]'),
                                    ),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Phone Number',
                                    hintText: '+14155552671',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                  ),
                                ),
                              ),
                              if (phoneAuth.status == PhoneAuthStatus.error &&
                                  phoneAuth.errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  phoneAuth.errorMessage!,
                                  key: const Key('phone_sign_in_error_text'),
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              ElevatedButton(
                                key: const Key('phone_sign_in_send_otp_button'),
                                onPressed: isBusy
                                    ? null
                                    : () async {
                                        final phoneNumber = _phoneController
                                            .text
                                            .trim();
                                        final success = await phoneAuth.sendOtp(
                                          phoneNumber: phoneNumber,
                                        );
                                        if (success) {
                                          widget.onOtpSent(phoneNumber);
                                        }
                                      },
                                child: isBusy
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Send OTP'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
