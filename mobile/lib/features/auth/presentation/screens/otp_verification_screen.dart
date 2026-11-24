import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/config/phone_auth_config.dart';
import 'package:flutter/services.dart';
import 'package:quit_companion/features/auth/controllers/phone_auth_controller.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// FR1: OTP entry/verification step of the Phone Authentication flow.
/// Always receives an already-live PhoneAuthController (created by whichever
/// screen initiated Send OTP) so the pending verification session carries
/// over — this screen never creates its own controller.
class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final PhoneAuthController phoneAuthController;
  final void Function(String userId) onVerified;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.phoneAuthController,
    required this.onVerified,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  String _code = '';

  @override
  void initState() {
    super.initState();
    widget.phoneAuthController.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.phoneAuthController.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.phoneAuthController;
    final textTheme = Theme.of(context).textTheme;
    final isBusy =
        controller.status == PhoneAuthStatus.sendingOtp ||
        controller.status == PhoneAuthStatus.verifying;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 64,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: AppColors.sageLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.sms_outlined,
                              color: AppColors.sageDark,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Enter OTP',
                          style: textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the 6-digit OTP sent to ${widget.phoneNumber} on ${PhoneAuthConfig.deliveryChannel}.',
                          style: textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        _OtpBoxes(
                          onChanged: (code) => setState(() => _code = code),
                        ),
                        if (controller.status == PhoneAuthStatus.error &&
                            controller.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            controller.errorMessage!,
                            key: const Key('otp_error_text'),
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 28),
                        ElevatedButton(
                          key: const Key('otp_verify_button'),
                          onPressed: isBusy
                              ? null
                              : () async {
                                  final success = await controller.verifyOtp(
                                    _code,
                                  );
                                  if (success && controller.userId != null) {
                                    widget.onVerified(controller.userId!);
                                  }
                                },
                          child: controller.status == PhoneAuthStatus.verifying
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Verify'),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            key: const Key('otp_resend_button'),
                            onPressed: controller.canResend && !isBusy
                                ? () => controller.resendOtp()
                                : null,
                            child: Text(
                              controller.canResend
                                  ? "Didn't get a code? Resend"
                                  : 'Resend code in ${controller.resendCooldownSeconds}s',
                              key: const Key('otp_resend_label'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OtpBoxes extends StatefulWidget {
  final ValueChanged<String> onChanged;
  const _OtpBoxes({required this.onChanged});

  @override
  State<_OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<_OtpBoxes> {
  static const _length = 6;
  late final List<TextEditingController> _controllers = List.generate(
    _length,
    (_) => TextEditingController(),
  );
  late final List<FocusNode> _focusNodes = List.generate(
    _length,
    (_) => FocusNode(),
  );

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(_controllers.map((c) => c.text).join());

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_length, (index) {
        return SizedBox(
          width: 44,
          height: 56,
          child: TextField(
            key: Key('otp_digit_field_$index'),
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            maxLength: 1,
            decoration: const InputDecoration(
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
            style: Theme.of(context).textTheme.headlineSmall,
            onChanged: (value) {
              if (value.isNotEmpty && index < _length - 1) {
                _focusNodes[index + 1].requestFocus();
              } else if (value.isEmpty && index > 0) {
                _focusNodes[index - 1].requestFocus();
              }
              _emit();
            },
          ),
        );
      }),
    );
  }
}
