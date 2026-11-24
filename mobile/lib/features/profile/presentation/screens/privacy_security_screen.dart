import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/auth/data/account_deletion_repository.dart';
import 'package:quit_companion/features/auth/data/biometric_lock_service.dart';

class PrivacySecurityScreen extends StatefulWidget {
  final String? userId;
  final BiometricLockService biometricLockService;
  final AccountDeletionRepository accountDeletionRepository;
  final Future<void> Function()? onAccountDeleted;

  const PrivacySecurityScreen({
    super.key,
    this.userId,
    this.biometricLockService = const UnavailableBiometricLockService(),
    this.accountDeletionRepository =
        const UnconfiguredAccountDeletionRepository(),
    this.onAccountDeleted,
  });

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _passwordSignInSupported = false;
  bool _biometricBusy = false;
  bool _deletingAccount = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final userId = widget.userId;
    if (userId == null) return;
    try {
      final available = await widget.biometricLockService.canAuthenticate();
      final enabled = await widget.biometricLockService.isEnabledFor(userId);
      final passwordSignInSupported = await widget.biometricLockService
          .supportsPasswordSignIn(userId);
      if (!mounted) return;
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
        _passwordSignInSupported = passwordSignInSupported;
      });
    } catch (error) {
      debugPrint('Could not read biometric settings: $error');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load biometric settings.';
      });
    }
  }

  Future<void> _setBiometricEnabled(bool enabled) async {
    final userId = widget.userId;
    if (_biometricBusy || userId == null) return;
    setState(() {
      _biometricBusy = true;
      _errorMessage = null;
    });
    try {
      if (enabled) {
        final available = await widget.biometricLockService.canAuthenticate();
        if (!mounted) return;
        if (!available) {
          setState(() {
            _biometricAvailable = false;
            _errorMessage =
                'Enroll a fingerprint or other biometric on this device first.';
          });
          return;
        }
        final passwordSignInSupported = await widget.biometricLockService
            .supportsPasswordSignIn(userId);
        if (!mounted) return;
        if (!passwordSignInSupported) {
          setState(() {
            _passwordSignInSupported = false;
            _errorMessage =
                'Fingerprint sign-in is currently available for email and password accounts only.';
          });
          return;
        }
        final password = await showDialog<String>(
          context: context,
          builder: (_) => const _BiometricPasswordConfirmationDialog(),
        );
        if (password == null || !mounted) return;
        final enabledSuccessfully = await widget.biometricLockService.enableFor(
          userId,
          password: password,
        );
        if (!enabledSuccessfully) return;
      } else {
        await widget.biometricLockService.disable();
      }
      if (!mounted) return;
      setState(() {
        _biometricAvailable = true;
        _biometricEnabled = enabled;
      });
    } on BiometricLockException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      debugPrint('Could not update biometric settings: $error');
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Could not update biometric settings. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_deletingAccount) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _DeleteAccountConfirmationDialog(),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _deletingAccount = true;
      _errorMessage = null;
    });
    try {
      await widget.accountDeletionRepository.deleteAccount();
    } on AccountDeletionException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
      return;
    } catch (error) {
      debugPrint('Account deletion request failed: $error');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not delete the account. Please try again.';
      });
      return;
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }

    try {
      await widget.biometricLockService.disable();
    } catch (error) {
      debugPrint(
        'Could not clear biometric settings after account deletion: $error',
      );
    }
    await widget.onAccountDeleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Security')),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SwitchListTile(
              key: const Key('biometric_unlock_switch'),
              contentPadding: EdgeInsets.zero,
              value: _biometricEnabled,
              onChanged: _biometricBusy || !_biometricAvailable
                  ? null
                  : _setBiometricEnabled,
              title: const Text('Fingerprint sign-in'),
              subtitle: Text(
                _biometricAvailable
                    ? _passwordSignInSupported
                          ? 'Save your email and password in encrypted device storage. A fingerprint is required before they can be used to sign in.'
                          : 'Fingerprint sign-in is available for email and password accounts only.'
                    : 'Enroll a fingerprint or other biometric on this device to enable sign-in.',
              ),
              secondary: const Icon(Icons.fingerprint_rounded),
            ),
            if (_biometricBusy)
              const LinearProgressIndicator(
                key: Key('privacy_action_progress'),
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                key: const Key('privacy_action_error'),
                style: const TextStyle(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Delete Account',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Permanently delete your account and private data. Your community '
              'posts, replies, likes, and discussions on your posts will also '
              'be deleted. This cannot be undone.',
              key: Key('delete_account_description'),
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('delete_account_button'),
              onPressed: _deletingAccount ? null : _deleteAccount,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              icon: const Icon(Icons.delete_forever_outlined),
              label: Text(
                _deletingAccount ? 'Deleting account…' : 'Delete Account',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BiometricPasswordConfirmationDialog extends StatefulWidget {
  const _BiometricPasswordConfirmationDialog();

  @override
  State<_BiometricPasswordConfirmationDialog> createState() =>
      _BiometricPasswordConfirmationDialogState();
}

class _BiometricPasswordConfirmationDialogState
    extends State<_BiometricPasswordConfirmationDialog> {
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _passwordController.text.isNotEmpty;
    return AlertDialog(
      title: const Text('Enable fingerprint sign-in'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirm your current password. It will be saved in encrypted '
            'storage on this device and used only after fingerprint verification.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('biometric_password_field'),
            controller: _passwordController,
            obscureText: true,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('confirm_biometric_password_button'),
          onPressed: canContinue
              ? () => Navigator.of(context).pop(_passwordController.text)
              : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _DeleteAccountConfirmationDialog extends StatefulWidget {
  const _DeleteAccountConfirmationDialog();

  @override
  State<_DeleteAccountConfirmationDialog> createState() =>
      _DeleteAccountConfirmationDialogState();
}

class _DeleteAccountConfirmationDialogState
    extends State<_DeleteAccountConfirmationDialog> {
  final TextEditingController _confirmationController = TextEditingController();

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = _confirmationController.text == 'DELETE';
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'All private data and your authored community content will be '
            'permanently erased. Type DELETE to confirm.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('delete_account_confirmation_field'),
            controller: _confirmationController,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Type DELETE'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('confirm_delete_account_button'),
          onPressed: canDelete ? () => Navigator.of(context).pop(true) : null,
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Delete permanently'),
        ),
      ],
    );
  }
}
