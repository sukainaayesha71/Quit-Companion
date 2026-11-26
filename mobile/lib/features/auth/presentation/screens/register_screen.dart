import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:provider/provider.dart';
import 'package:quit_companion/features/auth/controllers/auth_controller.dart';
import 'package:quit_companion/features/auth/data/recent_email_store.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/auth/presentation/screens/widgets/register_hero_header.dart';
import 'package:quit_companion/features/auth/presentation/screens/widgets/register_google_button.dart';
import 'package:quit_companion/features/auth/presentation/screens/widgets/secured_by_firebase_row.dart';
import 'package:quit_companion/features/auth/presentation/screens/widgets/social_sign_in_divider.dart';

class RegisterScreen extends StatefulWidget {
  final void Function(String userId, String email, String? name) onRegistered;
  final VoidCallback? onLoginTap;
  final RecentEmailStore? recentEmailStore;

  const RegisterScreen({
    super.key,
    required this.onRegistered,
    this.onLoginTap,
    this.recentEmailStore,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _agreedToTerms = true;
  String? _verificationEmail;
  List<String> _recentEmails = const [];

  RecentEmailStore get _emailStore =>
      widget.recentEmailStore ?? RecentEmailStore();

  @override
  void initState() {
    super.initState();
    _loadRecentEmails();
  }

  Future<void> _loadRecentEmails() async {
    // Best-effort only: suggestions are a convenience, never a requirement,
    // so a missing/unmocked shared_preferences plugin (e.g. in a widget
    // test that doesn't touch this feature) must not surface as an error.
    try {
      final emails = await _emailStore.getRecentEmails();
      if (mounted) setState(() => _recentEmails = emails);
    } catch (_) {
      // Ignore — the email field just won't show suggestions.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  void _clearAuthError() {
    final auth = context.read<AuthController>();
    if (auth.status == AuthStatus.error) auth.clearError();
  }

  Future<void> _submitRegistration() async {
    final authController = context.read<AuthController>();
    if (authController.status == AuthStatus.error) {
      authController.clearError();
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final success = await authController.register(
      email: email,
      password: _passwordController.text,
      displayName: name.isEmpty ? null : name,
    );
    if (!success || !mounted) return;

    unawaited(_emailStore.addRecentEmail(email).catchError((_) {}));
    setState(() => _verificationEmail = email);
  }

  Widget _buildVerificationNotice() {
    return Padding(
      key: const Key('register_verification_notice'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Column(
        children: [
          const Icon(
            Icons.mark_email_read_outlined,
            color: AppColors.sageDark,
            size: 52,
          ),
          const SizedBox(height: 16),
          const Text(
            'Verify your email',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            "We sent a verification link to $_verificationEmail. Open the link before logging in. If you don't see it, check your spam folder.",
            key: const Key('register_verification_message'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.heroHill,
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const RegisterHeroHeader(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_verificationEmail == null)
                                  Form(
                                    key: _formKey,
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: _buildFields(auth),
                                    ),
                                  )
                                else
                                  _buildVerificationNotice(),
                                if (widget.onLoginTap != null) ...[
                                  const SizedBox(height: 20),
                                  Center(
                                    child: TextButton(
                                      key: const Key('register_login_link'),
                                      onPressed: widget.onLoginTap,
                                      child: _verificationEmail == null
                                          ? Text.rich(
                                              TextSpan(
                                                style: const TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                                children: [
                                                  const TextSpan(
                                                    text:
                                                        'Already have an account? ',
                                                  ),
                                                  TextSpan(
                                                    text: 'Log In',
                                                    style: TextStyle(
                                                      color: AppColors
                                                          .terracottaDark,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : const Text('Go to Log In'),
                                    ),
                                  ),
                                ],
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
      ),
    );
  }

  Widget _pillField({
    required Key fieldKey,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    bool obscureText = false,
    bool isPassword = false,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.sage, width: 1.2),
      ),
      child: TextFormField(
        key: fieldKey,
        controller: controller,
        // Passwords: stop the keyboard from autocorrecting, suggesting or
        // capitalising (it can when "show password" is on), which would
        // silently save a different password than the user typed.
        keyboardType: isPassword ? TextInputType.visiblePassword : keyboardType,
        autocorrect: !isPassword,
        enableSuggestions: !isPassword,
        obscureText: obscureText,
        validator: validator,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
          prefixIcon: Icon(icon, color: AppColors.sageDark, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  List<Widget> _buildFields(AuthController auth) {
    return [
      _pillField(
        fieldKey: const Key('register_name_field'),
        controller: _nameController,
        label: 'Full Name',
        icon: Icons.person_outline,
        onChanged: (_) => _clearAuthError(),
      ),
      const SizedBox(height: 14),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.sage, width: 1.2),
        ),
        child: RawAutocomplete<String>(
          textEditingController: _emailController,
          focusNode: _emailFocusNode,
          optionsBuilder: (value) {
            if (value.text.isEmpty) return _recentEmails;
            return _recentEmails.where(
              (e) => e.toLowerCase().contains(value.text.toLowerCase()),
            );
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              key: const Key('register_email_field'),
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.emailAddress,
              validator: (value) => auth.validateEmail(value ?? ''),
              onChanged: (_) => _clearAuthError(),
              decoration: const InputDecoration(
                hintText: 'Email',
                hintStyle: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
                prefixIcon: Icon(
                  Icons.mail_outline,
                  color: AppColors.sageDark,
                  size: 20,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 160,
                    maxWidth: 392,
                  ),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: options
                        .map(
                          (email) => ListTile(
                            key: Key('recent_email_option_$email'),
                            leading: const Icon(
                              Icons.history,
                              color: AppColors.sageDark,
                            ),
                            title: Text(email),
                            onTap: () => onSelected(email),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 14),
      _pillField(
        fieldKey: const Key('register_password_field'),
        controller: _passwordController,
        label: 'Password',
        icon: Icons.lock_outline,
        obscureText: _obscurePassword,
        isPassword: true,
        validator: (value) => auth.validatePassword(value ?? ''),
        onChanged: (_) => _clearAuthError(),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.sageDark,
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      const SizedBox(height: 6),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'Must be at least 8 characters, with a lowercase letter and a number.',
          key: Key('register_password_hint'),
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ),
      const SizedBox(height: 14),
      InkWell(
        key: const Key('register_terms_checkbox'),
        onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
        child: Row(
          children: [
            Checkbox(
              value: _agreedToTerms,
              onChanged: (v) => setState(() => _agreedToTerms = v ?? true),
              // Local override, not the shared checkboxTheme (used elsewhere,
              // e.g. Consent screen): docs/UI_Design "register screen 3"
              // shows a light outlined box with a green check, not the
              // theme's default solid-sage fill.
              fillColor: const WidgetStatePropertyAll(Colors.white),
              checkColor: AppColors.sageDark,
              side: const BorderSide(color: AppColors.sage, width: 1.5),
            ),
            const Expanded(
              child: Text(
                'I agree to the Terms & Privacy Policy',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      const SecuredByFirebaseRow(
        label: 'Your data is secured by Firebase Authentication',
      ),
      if (auth.status == AuthStatus.error && auth.errorMessage != null) ...[
        const SizedBox(height: 12),
        Text(
          auth.errorMessage!,
          key: const Key('register_error_text'),
          style: const TextStyle(color: AppColors.error, fontSize: 14),
        ),
      ],
      const SizedBox(height: 20),
      ElevatedButton(
        key: const Key('register_submit_button'),
        onPressed: auth.status == AuthStatus.loading
            ? null
            : _submitRegistration,
        child: auth.status == AuthStatus.loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text('Create Account'),
      ),
      const SizedBox(height: 20),
      const SocialSignInDivider(),
      const SizedBox(height: 20),
      RegisterGoogleButton(
        key: const Key('register_google_button'),
        loading: auth.status == AuthStatus.loading,
        onPressed: () async {
          final authController = context.read<AuthController>();
          final result = await authController.signInWithGoogle();
          if (result != null && context.mounted) {
            widget.onRegistered(result.userId, result.email, result.name);
          }
        },
      ),
    ];
  }
}
