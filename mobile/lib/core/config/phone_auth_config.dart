class PhoneAuthConfig {
  static const provider = String.fromEnvironment(
    'PHONE_AUTH_PROVIDER',
    defaultValue: 'whatsapp',
  );
  static const deliveryChannel = provider == 'whatsapp' ? 'WhatsApp' : 'SMS';
}
