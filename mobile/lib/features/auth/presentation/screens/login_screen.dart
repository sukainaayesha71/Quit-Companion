import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quit_companion/features/auth/controllers/auth_controller.dart';
import 'package:quit_companion/features/auth/data/biometric_lock_service.dart';
import 'package:quit_companion/features/auth/data/recent_email_store.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/auth/presentation/screens/widgets/auth_hero_header.dart';
import 'package:quit_companion/features/auth/presentation/screens/widgets/secured_by_firebase_row.dart';
import 'package:quit_companion/features/auth/presentation/screens/widgets/social_sign_in_divider.dart';

class LoginScreen extends StatefulWidget {
  final void Function(String userId, String email) onLoggedIn;
  final VoidCallback? onRegisterTap;
  final VoidCallback? onPhoneSignInTap;
  final RecentEmailStore? recentEmailStore;
  final BiometricLockService biometricLockService;

  const LoginScreen({
    super.key,
    required this.onLoggedIn,
    this.onRegisterTap,
    this.onPhoneSignInTap,
    this.recentEmailStore,
    this.biometricLockService = const UnavailableBiometricLockService(),
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _biometricLoginAvailable = false;
  bool _biometricLoginBusy = false;
  String? _biometricError;
  List<String> _recentEmails = const [];

  RecentEmailStore get _emailStore =>
      widget.recentEmailStore ?? RecentEmailStore();

  @override
  void initState() {
    super.initState();
    _loadRecentEmails();
    _loadBiometricLoginAvailability();
  }

  Future<void> _loadRecentEmails() async {
    try {
      final emails = await _emailStore.getRecentEmails();
      if (mounted) setState(() => _recentEmails = emails);
    } catch (_) {
      // Best-effort convenience only — ignore failures.
    }
  }

  Future<void> _loadBiometricLoginAvailability() async {
    try {
      final hasSavedSignIn = await widget.biometricLockService.hasSavedSignIn();
      final canAuthenticate =
          hasSavedSignIn && await widget.biometricLockService.canAuthenticate();
      if (mounted) {
        setState(() => _biometricLoginAvailable = canAuthenticate);
      }
    } catch (error) {
      debugPrint('Could not check fingerprint sign-in availability: $error');
    }
  }

  Future<void> _signInWithBiometric() async {
    if (_biometricLoginBusy) return;
    if (!_biometricLoginAvailable) {
      setState(() {
        _biometricError =
            'Sign in with email and password, then enable fingerprint sign-in in Profile > Privacy & Security.';
      });
      return;
    }
    setState(() {
      _biometricLoginBusy = true;
      _biometricError = null;
    });
    try {
      final credentials = await widget.biometricLockService
          .authenticateForSignIn();
      if (credentials == null || !mounted) return;

      final authController = context.read<AuthController>();
      final success = await authController.login(
        email: credentials.email,
        password: credentials.password,
      );
      if (success && mounted) {
        unawaited(
          _emailStore.addRecentEmail(credentials.email).catchError((_) {}),
        );
        widget.onLoggedIn(authController.userId!, credentials.email);
      }
    } on BiometricLockException catch (error) {
      if (mounted) setState(() => _biometricError = error.message);
    } catch (error) {
      debugPrint('Fingerprint sign-in failed: $error');
      if (mounted) {
        setState(() {
          _biometricError = 'Fingerprint sign-in failed. Try your password.';
        });
      }
    } finally {
      if (mounted) setState(() => _biometricLoginBusy = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    context.read<AuthController>().clearError();
    final resetSent = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _ForgotPasswordDialog(initialEmail: _emailController.text.trim()),
    );
    if (resetSent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an account exists for that email, a password reset link has been sent.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  void _clearAuthError() {
    final auth = context.read<AuthController>();
    if (auth.status == AuthStatus.error) auth.clearError();
  }

  Future<void> _submitEmailPassword() async {
    final authController = context.read<AuthController>();
    if (authController.status == AuthStatus.error) {
      authController.clearError();
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final success = await authController.login(
      email: email,
      password: password,
    );
    if (!success || !mounted) return;

    unawaited(_emailStore.addRecentEmail(email).catchError((_) {}));
    try {
      await widget.biometricLockService.refreshCredentialsAfterLogin(
        userId: authController.userId!,
        email: email,
        password: password,
      );
    } catch (error) {
      debugPrint('Could not refresh saved biometric credentials: $error');
    }
    if (mounted) widget.onLoggedIn(authController.userId!, email);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

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
                    const AuthHeroHeader(
                      heading: 'Welcome Back',
                      subheading: 'Log in to continue your journey.',
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Form(
                                key: _formKey,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: _buildFields(auth),
                                ),
                              ),
                              if (widget.onRegisterTap != null) ...[
                                const SizedBox(height: 20),
                                Center(
                                  child: TextButton(
                                    key: const Key('login_register_link'),
                                    onPressed: widget.onRegisterTap,
                                    child: Text.rich(
                                      TextSpan(
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.normal,
                                        ),
                                        children: [
                                          const TextSpan(
                                            text: "Don't have an account? ",
                                          ),
                                          TextSpan(
                                            text: 'Register',
                                            style: TextStyle(
                                              color: AppColors.terracottaDark,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
    );
  }

  List<Widget> _buildFields(AuthController auth) {
    return [
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
              key: const Key('login_email_field'),
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.emailAddress,
              validator: (value) => auth.validateEmail(value ?? ''),
              onChanged: (_) => _clearAuthError(),
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'you@email.com',
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
      const SizedBox(height: 16),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.sage, width: 1.2),
        ),
        child: TextFormField(
          key: const Key('login_password_field'),
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter your password',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.lock_outline
                    : Icons.lock_open_outlined,
                color: AppColors.sageDark,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (value) => auth.validateLoginPassword(value ?? ''),
          onChanged: (_) => _clearAuthError(),
          obscureText: _obscurePassword,
          // Same as registration: the keyboard must not alter the password.
          keyboardType: TextInputType.visiblePassword,
          autocorrect: false,
          enableSuggestions: false,
        ),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          key: const Key('login_forgot_password_link'),
          onPressed: auth.status == AuthStatus.loading || _biometricLoginBusy
              ? null
              : _showForgotPasswordDialog,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.terracottaDark,
          ),
          child: const Text('Forgot Password?'),
        ),
      ),
      if (_biometricError != null ||
          (auth.status == AuthStatus.error && auth.errorMessage != null)) ...[
        const SizedBox(height: 8),
        Text(
          _biometricError ?? auth.errorMessage!,
          key: const Key('login_error_text'),
          style: const TextStyle(color: AppColors.error, fontSize: 14),
        ),
      ],
      const SizedBox(height: 12),
      SecuredByFirebaseRow(
        trailing: IconButton(
          key: const Key('login_biometric_button'),
          tooltip: 'Sign in with fingerprint',
          onPressed: auth.status == AuthStatus.loading || _biometricLoginBusy
              ? null
              : _signInWithBiometric,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.sageLight,
            foregroundColor: AppColors.textSecondary,
            fixedSize: const Size(56, 56),
            shape: const CircleBorder(),
          ),
          icon: _biometricLoginBusy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.sageDark,
                  ),
                )
              : const Icon(Icons.fingerprint_rounded, size: 30),
        ),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        key: const Key('login_submit_button'),
        onPressed: auth.status == AuthStatus.loading || _biometricLoginBusy
            ? null
            : _submitEmailPassword,
        child: auth.status == AuthStatus.loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text('Log In'),
      ),
      const SizedBox(height: 20),
      const SocialSignInDivider(),
      const SizedBox(height: 20),
      GoogleSignInButton(
        key: const Key('login_google_button'),
        loading: auth.status == AuthStatus.loading || _biometricLoginBusy,
        onPressed: () async {
          if (auth.status == AuthStatus.loading || _biometricLoginBusy) return;
          final authController = context.read<AuthController>();
          final result = await authController.signInWithGoogle();
          if (result != null && context.mounted) {
            widget.onLoggedIn(result.userId, result.email);
          }
        },
      ),
      if (widget.onPhoneSignInTap != null) ...[
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            key: const Key('login_phone_sign_in_link'),
            onPressed: _biometricLoginBusy ? null : widget.onPhoneSignInTap,
            child: const Text('Or continue with Phone Number'),
          ),
        ),
      ],
    ];
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;

  const _ForgotPasswordDialog({required this.initialEmail});

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  String? _errorMessage;
  bool _sending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final auth = context.read<AuthController>();
    setState(() {
      _errorMessage = null;
      _sending = true;
    });
    final success = await auth.requestPasswordReset(
      email: _emailController.text,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _errorMessage = success ? null : auth.errorMessage;
    });
    if (success) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset your password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter your account email and we’ll send a password reset link.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('forgot_password_email_field'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            enabled: !_sending,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              key: const Key('forgot_password_error_text'),
              style: const TextStyle(color: AppColors.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('forgot_password_submit_button'),
          onPressed: _sending ? null : _sendResetLink,
          child: _sending
              ? const CircularProgressIndicator()
              : const Text('Send reset link'),
        ),
      ],
    );
  }
}
