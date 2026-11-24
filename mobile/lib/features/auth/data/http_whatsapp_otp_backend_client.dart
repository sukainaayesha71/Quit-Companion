import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:quit_companion/features/auth/data/whatsapp_otp_backend_client.dart';

/// Real implementation — calls the FastAPI backend's /auth/phone endpoints.
class HttpWhatsAppOtpBackendClient implements WhatsAppOtpBackendClient {
  final String baseUrl;
  final http.Client _httpClient;

  HttpWhatsAppOtpBackendClient({required this.baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static const _defaultSendError =
      'Could not send verification code. Please try again.';
  static const _defaultVerifyError = 'Invalid or expired verification code.';

  @override
  Future<void> sendOtp(String phoneNumber) async {
    final http.Response response;
    try {
      response = await _httpClient.post(
        Uri.parse('$baseUrl/auth/phone/send-otp'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phoneNumber}),
      );
    } catch (_) {
      throw WhatsAppOtpException(
        'Could not reach the verification service. Check your connection.',
      );
    }
    if (response.statusCode != 200) {
      throw WhatsAppOtpException(_extractDetail(response) ?? _defaultSendError);
    }
  }

  @override
  Future<String> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    final http.Response response;
    try {
      response = await _httpClient.post(
        Uri.parse('$baseUrl/auth/phone/verify-otp'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phoneNumber, 'otp': otp}),
      );
    } catch (_) {
      throw WhatsAppOtpException(
        'Could not reach the verification service. Check your connection.',
      );
    }
    if (response.statusCode != 200) {
      throw WhatsAppOtpException(
        _extractDetail(response) ?? _defaultVerifyError,
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['firebase_token'] as String?;
    if (token == null || token.isEmpty) {
      throw WhatsAppOtpException('Verification failed. Please try again.');
    }
    return token;
  }

  String? _extractDetail(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = data['detail'];
      return detail is String ? detail : null;
    } catch (_) {
      return null;
    }
  }
}
