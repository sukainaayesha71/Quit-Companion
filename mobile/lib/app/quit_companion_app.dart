import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quit_companion/core/config/otp_backend_config.dart';
import 'package:quit_companion/features/goals/controllers/ai_plan_controller.dart';
import 'package:quit_companion/features/craving/controllers/alternatives_controller.dart';
import 'package:quit_companion/features/auth/controllers/auth_controller.dart';
import 'package:quit_companion/features/auth/data/account_deletion_repository.dart';
import 'package:quit_companion/features/auth/data/biometric_lock_service.dart';
import 'package:quit_companion/features/community/controllers/community_controller.dart';
import 'package:quit_companion/features/craving/controllers/craving_log_controller.dart';
import 'package:quit_companion/features/dashboard/controllers/dashboard_controller.dart';
import 'package:quit_companion/features/rewards/controllers/gamification_controller.dart';
import 'package:quit_companion/features/health_bot/controllers/health_bot_controller.dart';
import 'package:quit_companion/features/journal/controllers/journal_controller.dart';
import 'package:quit_companion/features/knowledge/controllers/knowledge_hub_controller.dart';
import 'package:quit_companion/features/onboarding/controllers/onboarding_controller.dart';
import 'package:quit_companion/features/profile/controllers/profile_controller.dart';
import 'package:quit_companion/features/relapse/controllers/relapse_controller.dart';
import 'package:quit_companion/features/reminders/controllers/reminder_controller.dart';
import 'package:quit_companion/features/tracking/controllers/track_controller.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/knowledge/data/article_bookmark_repository.dart';
import 'package:quit_companion/features/auth/data/auth_repository.dart';
import 'package:quit_companion/features/rewards/data/badge_repository.dart';
import 'package:quit_companion/features/community/data/community_post_repository.dart';
import 'package:quit_companion/features/craving/data/craving_log_repository.dart';
import 'package:quit_companion/features/craving/data/offline_craving_log_repository.dart';
import 'package:quit_companion/features/goals/data/coaching_client.dart';
import 'package:quit_companion/features/auth/data/firebase_auth_repository.dart';
import 'package:quit_companion/features/knowledge/data/firestore_article_bookmark_repository.dart';
import 'package:quit_companion/features/rewards/data/firestore_badge_repository.dart';
import 'package:quit_companion/features/community/data/firestore_community_post_repository.dart';
import 'package:quit_companion/features/craving/data/firestore_craving_log_repository.dart';
import 'package:quit_companion/features/craving/data/firestore_habit_alternative_attempt_repository.dart';
import 'package:quit_companion/features/health_bot/data/firestore_health_bot_repository.dart';
import 'package:quit_companion/features/journal/data/firestore_journal_repository.dart';
import 'package:quit_companion/features/craving/data/habit_alternative_attempt_repository.dart';
import 'package:quit_companion/features/tracking/data/firestore_usage_log_repository.dart';
import 'package:quit_companion/features/profile/data/firestore_user_repository.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_chat_session_store.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_repository.dart';
import 'package:quit_companion/features/health_bot/data/http_health_bot_client.dart';
import 'package:quit_companion/features/health_bot/domain/health_bot_user_context.dart';
import 'package:quit_companion/features/relapse/data/http_relapse_prediction_client.dart';
import 'package:quit_companion/features/journal/data/journal_repository.dart';
import 'package:quit_companion/features/reminders/data/local_reminder_notification_service.dart';
import 'package:quit_companion/features/reminders/data/notification_event_client.dart';
import 'package:quit_companion/features/relapse/data/relapse_prediction_client.dart';
import 'package:quit_companion/features/reminders/data/reminder_notification_service.dart';
import 'package:quit_companion/features/reminders/data/reminder_settings_repository.dart';
import 'package:quit_companion/features/reminders/data/shared_prefs_reminder_settings_repository.dart';
import 'package:quit_companion/features/tracking/data/usage_log_repository.dart';
import 'package:quit_companion/features/profile/data/user_repository.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/features/onboarding/domain/quit_date_calculator.dart';
import 'package:quit_companion/features/relapse/domain/restart_plan_calculator.dart';
import 'package:quit_companion/features/goals/domain/weekly_plan_calculator.dart';
import 'package:quit_companion/features/auth/presentation/screens/login_screen.dart';
import 'package:quit_companion/features/auth/presentation/screens/register_screen.dart';
import 'package:quit_companion/features/auth/presentation/screens/welcome_screen.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/consent_screen.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/gender_selection_screen.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/goal_selection_screen.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/onboarding_complete_screen.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/product_quantity_screen.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/product_selection_screen.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/reminders/data/high_risk_checkin_scheduler.dart';

class QuitCompanionApp extends StatelessWidget {
  // Default to the real Firebase-backed repositories (project: quit-companion).
  // Tests inject FakeAuthRepository/FakeUserRepository here instead of hitting
  // live Firebase — see test/app_flow_test.dart.
  final AuthRepository? authRepository;
  final UserRepository? userRepository;
  final UsageLogRepository? usageLogRepository;
  final CravingLogRepository? cravingLogRepository;
  final RelapsePredictionClient? relapsePredictionClient;
  final JournalRepository? journalRepository;
  final HealthBotClient? healthBotClient;
  final HealthBotRepository? healthBotRepository;
  final HabitAlternativeAttemptRepository? habitAlternativeAttemptRepository;
  final BadgeRepository? badgeRepository;
  final CommunityPostRepository? communityPostRepository;
  final ArticleBookmarkRepository? articleBookmarkRepository;
  final ReminderSettingsRepository? reminderSettingsRepository;
  final ReminderNotificationService? reminderNotificationService;
  final NotificationEventClient? notificationEventClient;
  final BiometricLockService biometricLockService;
  final AccountDeletionRepository accountDeletionRepository;

  const QuitCompanionApp({
    super.key,
    this.authRepository,
    this.userRepository,
    this.usageLogRepository,
    this.cravingLogRepository,
    this.relapsePredictionClient,
    this.journalRepository,
    this.healthBotClient,
    this.healthBotRepository,
    this.habitAlternativeAttemptRepository,
    this.badgeRepository,
    this.communityPostRepository,
    this.articleBookmarkRepository,
    this.reminderSettingsRepository,
    this.reminderNotificationService,
    this.notificationEventClient,
    this.biometricLockService = const UnavailableBiometricLockService(),
    this.accountDeletionRepository =
        const UnconfiguredAccountDeletionRepository(),
  });

  @override
  Widget build(BuildContext context) {
    // Shared between DashboardController (Cravings Resisted, FR4) and
    // CravingLogController (Log Craving, FR5/FR6, Module 3) — one Firestore
    // repository instance, same collection.
    final resolvedCravingLogRepository =
        cravingLogRepository ??
        OfflineCravingLogRepository(FirestoreCravingLogRepository());
    // Shared between JournalController and RelapseController (Module 5).
    final resolvedJournalRepository =
        journalRepository ?? FirestoreJournalRepository();
    // Shared between every controller below AND _OnboardingFlow itself,
    // which looks up a signed-in account's existing profile directly to
    // decide whether that account still needs onboarding.
    final resolvedUserRepository = userRepository ?? FirestoreUserRepository();
    final resolvedAuthRepository = authRepository ?? FirebaseAuthRepository();
    final coachingClient = authRepository == null
        ? CoachingClient(baseUrl: OtpBackendConfig.baseUrl)
        : null;
    HabitAlternativeAttemptRepository? resolvedAttemptRepository =
        habitAlternativeAttemptRepository;
    final resolvedNotificationEventClient =
        notificationEventClient ??
        (authRepository == null
            ? HttpNotificationEventClient(baseUrl: OtpBackendConfig.baseUrl)
            : const NoopNotificationEventClient());

    return MultiProvider(
      providers: [
        // One reminder settings store and notification service, shared by
        // the Reminders screen and the FR11/UC9 high-risk check-in
        // scheduler so both read the same setting and drive the same plugin.
        // Lazy providers: LocalReminderNotificationService touches
        // FirebaseMessaging, so it must not be built until first needed
        // (and only once, not on every rebuild of this widget).
        Provider<ReminderSettingsRepository>(
          create: (_) =>
              reminderSettingsRepository ??
              SharedPrefsReminderSettingsRepository(),
        ),
        Provider<ReminderNotificationService>(
          create: (_) =>
              reminderNotificationService ?? LocalReminderNotificationService(),
        ),
        Provider<HighRiskCheckInScheduler>(
          create: (context) => HighRiskCheckInScheduler(
            cravingLogRepository: resolvedCravingLogRepository,
            userRepository: resolvedUserRepository,
            settingsRepository: context.read<ReminderSettingsRepository>(),
            notificationService: context.read<ReminderNotificationService>(),
          ),
        ),
        Provider<CravingLogRepository>(
          create: (_) => resolvedCravingLogRepository,
          dispose: (_, repository) {
            if (repository is OfflineCravingLogRepository) repository.dispose();
          },
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => AuthController(resolvedAuthRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => OnboardingController(
            resolvedUserRepository,
            QuitDateCalculator(),
            coachingClient: coachingClient,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardController(
            resolvedUserRepository,
            usageLogRepository ?? FirestoreUsageLogRepository(),
            resolvedCravingLogRepository,
            DashboardStateCalculator(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => CravingLogController(
            resolvedCravingLogRepository,
            relapsePredictionClient ??
                HttpRelapsePredictionClient(baseUrl: OtpBackendConfig.baseUrl),
            checkInScheduler: context.read<HighRiskCheckInScheduler>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AiPlanController(
            resolvedUserRepository,
            usageLogRepository ?? FirestoreUsageLogRepository(),
            resolvedCravingLogRepository,
            WeeklyPlanCalculator(),
            coachingClient: coachingClient,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => JournalController(resolvedJournalRepository),
        ),
        ChangeNotifierProvider(
          create: (context) => RelapseController(
            resolvedJournalRepository,
            resolvedUserRepository,
            resolvedCravingLogRepository,
            RestartPlanCalculator(),
            coachingClient: coachingClient,
            notificationEventClient: resolvedNotificationEventClient,
            checkInScheduler: context.read<HighRiskCheckInScheduler>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => HealthBotController(
            healthBotClient ??
                HttpHealthBotClient(baseUrl: OtpBackendConfig.baseUrl),
            healthBotRepository ?? FirestoreHealthBotRepository(),
            currentDisplayName: () => resolvedAuthRepository.currentDisplayName,
            chatSessionStore: SharedPreferencesHealthBotChatSessionStore(),
            loadUserContext: (userId) async {
              final user = await resolvedUserRepository.getUser(userId);
              return user == null
                  ? null
                  : healthBotContextFor(user, DateTime.now());
            },
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AlternativesController(
            resolvedAttemptRepository ??=
                FirestoreHabitAlternativeAttemptRepository(),
            coachingClient: coachingClient,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => GamificationController(
            resolvedUserRepository,
            usageLogRepository ?? FirestoreUsageLogRepository(),
            resolvedCravingLogRepository,
            badgeRepository ?? FirestoreBadgeRepository(),
            DashboardStateCalculator(),
            notificationEventClient: resolvedNotificationEventClient,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => CommunityController(
            communityPostRepository ?? FirestoreCommunityPostRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => KnowledgeHubController(
            articleBookmarkRepository ?? FirestoreArticleBookmarkRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ReminderController(
            context.read<ReminderSettingsRepository>(),
            context.read<ReminderNotificationService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => TrackController(
            resolvedCravingLogRepository,
            resolvedJournalRepository,
            resolvedUserRepository,
            attemptRepository: resolvedAttemptRepository ??=
                FirestoreHabitAlternativeAttemptRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ProfileController(resolvedUserRepository),
        ),
      ],
      child: MaterialApp(
        title: 'Quit Companion',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: _OnboardingFlow(
          userRepository: resolvedUserRepository,
          authRepository: resolvedAuthRepository,
          biometricLockService: biometricLockService,
          accountDeletionRepository: accountDeletionRepository,
        ),
      ),
    );
  }
}

enum _Step {
  welcome,
  register,
  login,
  consent,
  restoring,
  biometricGate,
  gender,
  productSelection,
  quantity,
  goal,
  complete,
  loggedIn,
}

class _OnboardingFlow extends StatefulWidget {
  final UserRepository userRepository;
  final AuthRepository authRepository;
  final BiometricLockService biometricLockService;
  final AccountDeletionRepository accountDeletionRepository;

  const _OnboardingFlow({
    required this.userRepository,
    required this.authRepository,
    required this.biometricLockService,
    required this.accountDeletionRepository,
  });

  @override
  State<_OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<_OnboardingFlow>
    with WidgetsBindingObserver {
  late _Step _step;
  String? _loggedInUserId;
  String? _sessionRestoreError;
  ProductType? _selectedProductType;
  String? _selectedUnitLabel;

  bool _isAuthenticatingBiometric = false;
  String? _biometricError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final currentUserId = widget.authRepository.currentUserId;
    _step = currentUserId == null ? _Step.welcome : _Step.restoring;
    if (currentUserId != null) {
      Future.microtask(() => _restoreAuthenticatedSession(currentUserId));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        _step == _Step.loggedIn &&
        !_isAuthenticatingBiometric) {
      _lockIfBiometricEnabled();
    } else if (state == AppLifecycleState.resumed &&
        _step == _Step.biometricGate &&
        !_isAuthenticatingBiometric) {
      _authenticateToUnlock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(_step), child: _buildStep(context)),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case _Step.welcome:
        return WelcomeScreen(
          onRegisterTap: () => setState(() => _step = _Step.register),
          onLoginTap: () => setState(() => _step = _Step.login),
        );
      case _Step.register:
        return RegisterScreen(
          onRegistered: (userId, email, name) {
            context.read<OnboardingController>().startOnboarding(
              userId: userId,
              email: email,
              name: name,
            );
            setState(() => _step = _Step.consent);
          },
          onLoginTap: () {
            context.read<AuthController>().clearError();
            setState(() => _step = _Step.login);
          },
        );
      case _Step.login:
        return LoginScreen(
          biometricLockService: widget.biometricLockService,
          onLoggedIn: (userId, email) => _continueWithAccount(
            userId: userId,
            email: email,
            name: widget.authRepository.currentDisplayName,
          ),
          onRegisterTap: () {
            context.read<AuthController>().clearError();
            setState(() => _step = _Step.register);
          },
        );
      case _Step.loggedIn:
        return DashboardScreen(
          userId: _loggedInUserId ?? '',
          controller: context.read<DashboardController>(),
          cravingLogController: context.read<CravingLogController>(),
          aiPlanController: context.read<AiPlanController>(),
          journalController: context.read<JournalController>(),
          relapseController: context.read<RelapseController>(),
          healthBotController: context.read<HealthBotController>(),
          alternativesController: context.read<AlternativesController>(),
          gamificationController: context.read<GamificationController>(),
          communityController: context.read<CommunityController>(),
          knowledgeHubController: context.read<KnowledgeHubController>(),
          reminderController: context.read<ReminderController>(),
          trackController: context.read<TrackController>(),
          profileController: context.read<ProfileController>(),
          biometricLockService: widget.biometricLockService,
          accountDeletionRepository: widget.accountDeletionRepository,
          onLogout: _logoutToWelcome,
          onAccountDeleted: _accountDeleted,
        );
      case _Step.consent:
        return ConsentScreen(
          onContinue: () => setState(() => _step = _Step.gender),
        );
      case _Step.gender:
        return GenderSelectionScreen(
          onBack: () => setState(() => _step = _Step.consent),
          onContinue: (gender) {
            context.read<OnboardingController>().recordGender(gender);
            setState(() => _step = _Step.productSelection);
          },
        );
      case _Step.productSelection:
        return ProductSelectionScreen(
          initialSelection: _selectedProductType,
          onBack: () => setState(() => _step = _Step.gender),
          onContinue: (type) => setState(() {
            _selectedProductType = type;
            _step = _Step.quantity;
          }),
        );
      case _Step.quantity:
        return ProductQuantityScreen(
          productType: _selectedProductType!,
          onBack: () => setState(() => _step = _Step.productSelection),
          onContinue: (value, unitLabel) {
            // ProductQuantityScreen has already validated and recorded all
            // fields. Recording again here discarded cost and history.
            setState(() {
              _selectedUnitLabel = unitLabel;
              _step = _Step.goal;
            });
          },
        );
      case _Step.goal:
        return GoalSelectionScreen(
          onBack: () => setState(() => _step = _Step.quantity),
          onComplete: () => setState(() => _step = _Step.complete),
        );
      case _Step.complete:
        return OnboardingCompleteScreen(
          unitLabelOverride: _selectedUnitLabel,
          onContinue: () {
            final user = context.read<OnboardingController>().workingUser!;
            setState(() {
              _loggedInUserId = user.userId;
              _step = _Step.loggedIn;
            });
          },
        );
      case _Step.restoring:
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: _sessionRestoreError == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _sessionRestoreError!,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            key: const Key('session_restore_retry_button'),
                            onPressed: () {
                              final userId =
                                  widget.authRepository.currentUserId;
                              if (userId != null) {
                                _restoreAuthenticatedSession(userId);
                              }
                            },
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      case _Step.biometricGate:
        return _BiometricUnlockScreen(
          errorMessage: _biometricError,
          isAuthenticating: _isAuthenticatingBiometric,
          onUnlock: _authenticateToUnlock,
          onSignOut: _logoutToWelcome,
        );
    }
  }

  Future<void> _restoreAuthenticatedSession(String userId) async {
    try {
      final biometricEnabled = await widget.biometricLockService.isEnabledFor(
        userId,
      );
      if (!mounted) return;
      if (biometricEnabled) {
        setState(() {
          _biometricError = null;
          _step = _Step.biometricGate;
        });
        await _authenticateToUnlock();
        return;
      }
      await _continueWithAccount(
        userId: userId,
        email: widget.authRepository.currentEmail ?? '',
        name: widget.authRepository.currentDisplayName,
      );
    } catch (error) {
      debugPrint('Could not read biometric lock settings: $error');
      if (!mounted) return;
      setState(() {
        _sessionRestoreError =
            'Could not verify your security settings. Please try again.';
        _step = _Step.restoring;
      });
    }
  }

  Future<void> _lockIfBiometricEnabled() async {
    final userId = widget.authRepository.currentUserId;
    if (userId == null) return;
    try {
      if (await widget.biometricLockService.isEnabledFor(userId) &&
          mounted &&
          _step == _Step.loggedIn) {
        setState(() {
          _biometricError = null;
          _step = _Step.biometricGate;
        });
      }
    } catch (error) {
      debugPrint('Could not verify biometric lock settings: $error');
      if (!mounted) return;
      setState(() {
        _biometricError =
            'Could not verify your security settings. Try again or sign out.';
        _step = _Step.biometricGate;
      });
    }
  }

  Future<void> _authenticateToUnlock() async {
    if (_isAuthenticatingBiometric) return;
    setState(() {
      _isAuthenticatingBiometric = true;
      _biometricError = null;
    });
    try {
      final authenticated = await widget.biometricLockService.authenticate(
        'Unlock Quit Companion.',
      );
      if (!mounted) return;
      if (!authenticated) {
        setState(() {
          _biometricError = 'Authentication was not completed. Try again.';
        });
        return;
      }
      final userId = widget.authRepository.currentUserId;
      if (userId == null) {
        setState(() => _step = _Step.welcome);
      } else if (_loggedInUserId == userId) {
        setState(() => _step = _Step.loggedIn);
      } else {
        await _continueWithAccount(
          userId: userId,
          email: widget.authRepository.currentEmail ?? '',
          name: widget.authRepository.currentDisplayName,
        );
      }
    } catch (error) {
      debugPrint('Biometric unlock failed: $error');
      if (!mounted) return;
      setState(() {
        _biometricError =
            'Biometric verification failed. Try again or sign out.';
      });
    } finally {
      _isAuthenticatingBiometric = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _logoutToWelcome() async {
    await context.read<ReminderController>().suspendForLogout();
    if (!mounted) return;
    await context.read<AuthController>().logout();
    if (!mounted) return;
    context.read<HealthBotController>().clearSession();
    context.read<DashboardController>().clearSession();
    context.read<GamificationController>().clearSession();
    setState(() {
      _loggedInUserId = null;
      _step = _Step.welcome;
    });
  }

  Future<void> _accountDeleted() async {
    final userId = _loggedInUserId;
    final cravings = context.read<CravingLogRepository>();
    if (userId != null && cravings is OfflineCravingLogRepository) {
      await cravings.clearUser(userId);
    }
    if (!mounted) return;
    final reminderController = context.read<ReminderController>();
    try {
      await widget.biometricLockService.disable();
    } catch (error) {
      debugPrint(
        'Could not clear biometric settings after account deletion: $error',
      );
    }
    try {
      await reminderController.resetForAccountDeletion();
    } catch (error) {
      debugPrint(
        'Could not clear local reminders after account deletion: $error',
      );
    }
    await _logoutToWelcome();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _continueWithAccount({
    required String userId,
    required String email,
    String? name,
    bool updateStep = true,
  }) async {
    if (mounted) {
      setState(() {
        if (updateStep) _step = _Step.restoring;
        _sessionRestoreError = null;
      });
    }
    try {
      final savedUser = await widget.userRepository.getUser(userId);
      if (!mounted) return;
      if (savedUser == null || savedUser.quitDate == null) {
        context.read<OnboardingController>().startOnboarding(
          userId: userId,
          email: savedUser?.email ?? email,
          name: savedUser?.name ?? name,
        );
        setState(() {
          _sessionRestoreError = null;
          _step = _Step.consent;
        });
      } else {
        setState(() {
          _loggedInUserId = userId;
          _sessionRestoreError = null;
          _step = _Step.loggedIn;
        });
      }
    } catch (e) {
      debugPrint(
        'QuitCompanionApp: failed to restore authenticated session: $e',
      );
      if (!mounted) return;
      setState(() {
        _sessionRestoreError =
            'Could not load your profile. Check your connection and try again.';
        _step = _Step.restoring;
      });
    }
  }
}

class _BiometricUnlockScreen extends StatelessWidget {
  final String? errorMessage;
  final bool isAuthenticating;
  final Future<void> Function() onUnlock;
  final Future<void> Function() onSignOut;

  const _BiometricUnlockScreen({
    required this.errorMessage,
    required this.isAuthenticating,
    required this.onUnlock,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fingerprint_rounded, size: 72),
                const SizedBox(height: 16),
                const Text(
                  'Unlock Quit Companion',
                  key: Key('biometric_unlock_title'),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (errorMessage != null) ...[
                  Text(
                    errorMessage!,
                    key: const Key('biometric_unlock_error'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton.icon(
                  key: const Key('biometric_unlock_button'),
                  onPressed: isAuthenticating ? null : () => onUnlock(),
                  icon: isAuthenticating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fingerprint_rounded),
                  label: Text(
                    isAuthenticating ? 'Verifying…' : 'Unlock with biometrics',
                  ),
                ),
                TextButton(
                  key: const Key('biometric_unlock_sign_out_button'),
                  onPressed: isAuthenticating ? null : () => onSignOut(),
                  child: const Text('Sign out and use another account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
