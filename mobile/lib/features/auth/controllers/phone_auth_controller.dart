import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/auth/data/phone_auth_repository.dart';

enum PhoneAuthStatus { idle, sendingOtp, otpSent, verifying, success, error }

/// FR1: Firebase Phone Authentication state machine — phone number ->
/// send OTP -> verify OTP -> authenticated userId. Mirrors AuthController's
/// status/errorMessage shape, plus resend-cooldown tracking.
class PhoneAuthController extends ChangeNotifier {
  final PhoneAuthRepository _repository;
  final Duration cooldownDuration;
  final Duration tickInterval;

  PhoneAuthController(
    this._repository, {
    this.cooldownDuration = const Duration(seconds: 30),
    this.tickInterval = const Duration(seconds: 1),
  });

  PhoneAuthStatus status = PhoneAuthStatus.idle;
  String? errorMessage;
  String? userId;

  String? _verificationId;
  int? _resendToken;
  String? _phoneNumber;

  Timer? _cooldownTimer;
  Duration _remainingCooldown = Duration.zero;
  int get resendCooldownSeconds =>
      (_remainingCooldown.inMilliseconds / 1000).ceil();

  static final _phonePattern = RegExp(r'^\+[1-9]\d{7,14}$');

  /// Strips everything except digits and a single leading '+'. A clean
  /// E.164 number (e.g. +923357606070) passes through byte-for-byte; this
  /// only matters for input that picked up stray formatting characters
  /// (spaces, dashes, parens) from a numeric keypad, which would otherwise
  /// fail the digits-only pattern below or reach Firebase malformed.
  String normalizePhoneNumber(String phoneNumber) {
    final trimmed = phoneNumber.trim();
    if (trimmed.isEmpty) return trimmed;
    final hasLeadingPlus = trimmed.startsWith('+');
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return hasLeadingPlus ? '+$digitsOnly' : digitsOnly;
  }

  String? validatePhoneNumber(String phoneNumber) {
    final normalized = normalizePhoneNumber(phoneNumber);
    if (normalized.isEmpty) return 'Phone number is required.';
    if (!_phonePattern.hasMatch(normalized)) {
      return 'Enter a valid phone number in international format (e.g. +14155552671).';
    }
    return null;
  }

  String? validateOtp(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return 'Enter the verification code.';
    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) return 'Enter the 6-digit code.';
    return null;
  }

  bool get canResend =>
      _remainingCooldown <= Duration.zero &&
      status != PhoneAuthStatus.sendingOtp &&
      status != PhoneAuthStatus.verifying;

  Future<bool> sendOtp({
    required String phoneNumber,
    bool isResend = false,
  }) async {
    final normalized = normalizePhoneNumber(phoneNumber);
    final validationError = validatePhoneNumber(normalized);
    if (validationError != null) {
      errorMessage = validationError;
      status = PhoneAuthStatus.error;
      notifyListeners();
      return false;
    }
    status = PhoneAuthStatus.sendingOtp;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _repository.sendOtp(
        phoneNumber: normalized,
        forceResendingToken: isResend ? _resendToken : null,
      );
      _verificationId = result.verificationId;
      _resendToken = result.resendToken;
      _phoneNumber = normalized;
      status = PhoneAuthStatus.otpSent;
      notifyListeners();
      _startCooldown();
      return true;
    } on PhoneAuthException catch (e) {
      errorMessage = e.message;
      status = PhoneAuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendOtp() {
    final phoneNumber = _phoneNumber;
    if (phoneNumber == null || !canResend) return Future.value(false);
    return sendOtp(phoneNumber: phoneNumber, isResend: true);
  }

  Future<bool> verifyOtp(String smsCode) async {
    final validationError = validateOtp(smsCode);
    if (validationError != null) {
      errorMessage = validationError;
      status = PhoneAuthStatus.error;
      notifyListeners();
      return false;
    }
    final verificationId = _verificationId;
    if (verificationId == null) {
      errorMessage = 'Verification session expired. Please request a new code.';
      status = PhoneAuthStatus.error;
      notifyListeners();
      return false;
    }
    status = PhoneAuthStatus.verifying;
    errorMessage = null;
    notifyListeners();
    try {
      userId = await _repository.verifyOtp(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      status = PhoneAuthStatus.success;
      notifyListeners();
      return true;
    } on PhoneAuthException catch (e) {
      errorMessage = e.message;
      status = PhoneAuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _remainingCooldown = cooldownDuration;
    notifyListeners();
    _cooldownTimer = Timer.periodic(tickInterval, (timer) {
      _remainingCooldown -= tickInterval;
      if (_remainingCooldown <= Duration.zero) {
        _remainingCooldown = Duration.zero;
        timer.cancel();
      }
      notifyListeners();
    });
  }

  /// Full reset — abandons any in-progress OTP session. Called when the
  /// user switches away from the Phone tab or navigates between
  /// Register/Login, so a stale session/error never leaks into a fresh
  /// attempt (same reasoning as AuthController.clearError()).
  void reset() {
    _cooldownTimer?.cancel();
    _remainingCooldown = Duration.zero;
    _verificationId = null;
    _resendToken = null;
    _phoneNumber = null;
    userId = null;
    status = PhoneAuthStatus.idle;
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
