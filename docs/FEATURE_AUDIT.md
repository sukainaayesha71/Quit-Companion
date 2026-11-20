# Feature audit — 17 November 2026

**Update:** The remaining Android/backend code has since been implemented. See
[ANDROID_COMPLETION.md](ANDROID_COMPLETION.md) for the current implementation,
test results, model improvement and external validation requirements. The
missing-code table below records the earlier baseline, not the current state.

## PDF comparison correction

The original 13-module checklist below is an implementation inventory, **not a
claim of full SRDS compliance**. Subsequent comparison with the supplied
`SRDS_finale.pdf` and `Quit_companion(features).pdf` found additional scope.
The features PDF also includes a 14th Backend & Database module: Firebase,
Firestore collections, FastAPI and prediction/loading code exist, but their
presence does not resolve the gaps below.

| SRDS requirement | Current limitation |
| --- | --- |
| FR5: trained AI relapse prediction using PATH and Perski data | Active predictions use rules; RF/XGBoost are EMASENS research artifacts. No PATH integration or reliable app-compatible ML deployment was demonstrated. The follow-up improvement investigation was interrupted before implementation. |
| FR3/use case 2: backend-generated personalized goal and timeline | Current goals and timelines use local calculators and fixed milestones. |
| FR7/use case 4: AI recommender endpoint and outcome-driven model training | Current alternative ranking is local and uses outcome history; no `/recommend/alternative` endpoint or learned recommender training loop. |
| FR8: WHO/CDC-sourced, medically validated responses | Gemini responses and curated fallback exist; per-response WHO/CDC grounding and medical-advisor validation have not been demonstrated. |
| FR9: points, streaks and badges | Streaks and badges exist; no points ledger or points-awarding system was found. |
| FR11/use case 9: AI-generated restart plan | Restart plans currently use a local deterministic calculator. |
| FR13: 3–5 scheduled daily prompts through FCM | Daily reminders are scheduled locally; FCM delivery code exists but a deployed remote daily scheduler and device delivery timing were not verified. |
| Offline craving capture and later synchronization | No verified app-level offline submission/sync flow; submission performs reads/network work before saving. Firestore caching alone does not prove this requirement. |
| Real-time updates within 500 ms | Community repository uses one-shot `.get()` calls, not real-time listeners; the latency requirement is not demonstrated. |
| Android and iOS | This checkout contains an Android target and no iOS target. |
| Performance and operational requirements | No evidence yet of the specified prediction/recommendation/HealthBot/dashboard latency guarantees, containerized deployment, or automatic restart. |
| Authentication security | `AdminSdkFirebaseIdentityProvider.verify_id_token` decodes unverified tokens if credentials are absent. Credentials are configured locally, but the missing-credential path does not fail closed as secure production authentication requires. |

Most core screens and CRUD workflows are implemented. Full SRDS completion and
production readiness remain outstanding. External validation cannot be
established by passing unit tests alone.

This audit maps the requested scope to the current Flutter/FastAPI source.
“Implemented” means a reachable UI and its supporting code exist; it does not
mean a live third-party service or deployment has been verified. Existing local
changes were preserved. Paths below are relative to the repository root.

| Module | Source evidence | Finding |
| --- | --- | --- |
| 1. Authentication | `mobile/lib/features/auth/`, `mobile/lib/app/quit_companion_app.dart`, `backend/app/otp/` | Implemented; Firebase/provider configuration remains required. |
| 2. Onboarding and profiling | `mobile/lib/features/onboarding/`, `mobile/lib/features/profile/` | Implemented; added nicotine history and onboarding cost capture; fixed the second form submission discarding optional fields. |
| 3. Dashboard | `mobile/lib/features/dashboard/` | Implemented. |
| 4. Craving and habit tracking | `mobile/lib/features/craving/`, `mobile/lib/features/tracking/` | Implemented; added full craving history with confirmed deletion and refreshed statistics. |
| 5. Relapse prediction | `backend/app/relapse/`, `backend/ml/`, `mobile/lib/features/relapse/` | Production scores are rule-based. Random Forest inference is research-only; RF/XGBoost training exists. App-compatible models do not have demonstrated useful predictive performance. |
| 6. HealthBot | `backend/app/healthbot/`, `mobile/lib/features/health_bot/` | Implemented; added labeled rule-based fallback and private history restoration with account-session isolation. Gemini needs backend credentials. |
| 7. Habit alternatives | `mobile/lib/features/craving/controllers/alternatives_controller.dart`, `mobile/lib/features/craving/presentation/screens/alternative_activity_history_screen.dart` | Implemented. |
| 8. Analytics and recovery | `mobile/lib/features/tracking/`, `mobile/lib/features/dashboard/domain/` | Implemented; added completed/helpful habit statistics and savings estimates. |
| 9. Rewards | `mobile/lib/features/rewards/` | Implemented. |
| 10. Community | `mobile/lib/features/community/`, `mobile/firestore.rules` | Implemented. |
| 11. Knowledge Hub | `mobile/lib/features/knowledge/` | Implemented; added saved-articles filtering. |
| 12. Reminders and notifications | `mobile/lib/features/reminders/`, `backend/app/notifications/` | Implemented; real FCM delivery requires platform credentials and deployment. |
| 13. Profile and settings | `mobile/lib/features/profile/` | Implemented; added editable smoking/vaping history. |

## Detailed scope

### 1. User Authentication and Account Management

- User registration: `register_screen.dart`, Firebase email/password registration.
- Email/password login: `login_screen.dart`, verified-email enforcement.
- Google sign-in: native account selection and Firebase credential exchange.
- Phone authentication: Firebase SMS flow and WhatsApp backend repository.
- OTP verification: code entry, validation, resend cooldown, verification endpoints.
- Forgot password: reset-email dialog and repository method.
- Password validation: inline length/lowercase/numeric requirements.
- Logout: Firebase/Google logout and return to welcome screen.
- Session management: restored Firebase session, profile lookup, optional biometric unlock; HealthBot state now clears on logout.

### 2. User Onboarding and Profiling

- User name and personal information: registration name, gender/avatar selection, profile editor.
- Nicotine usage information: product selection and product-specific consumption screen.
- Smoking/vaping history: optional `nicotineHistory`, collected during onboarding and editable in profile.
- Daily consumption: baseline usage input and usage logs.
- Quit-date selection: cold-turkey, gradual, and date-based strategies.
- Profile creation: `OnboardingController` and private Firestore user document.
- Profile update: name, gender, product, baseline, cost, motivation, challenges, previous attempts, nicotine history.

### 3. Dashboard

- Personalized greeting: saved account/profile name.
- Daily overview: countdown or nicotine-free state.
- Nicotine-free days: effective quit/restart date calculation.
- Money saved: saved baseline and cost; taper estimates use usage logs.
- Health recovery: product-aware milestones and timeline.
- Quick access: craving, alternatives, plan, journal, HealthBot, community, knowledge, rewards and settings navigation.
- Progress summary: dashboard statistics, weekly trend and milestone cards.

### 4. Craving and Habit Tracking

- Log craving: validated submission and private Firestore persistence.
- Intensity: 1–10 selection.
- Mood: categorical selection and optional affect sliders.
- Trigger: stress, after meal, social pressure, boredom, other.
- Location context: separately stored place.
- Activity tracking: separately stored activity plus alternative attempts.
- Craving history: Track → View and manage craving history, newest first, full entry details.
- Log management: confirmed deletion scoped to the owning user's collection; reloads counts and prediction history.

### 5. AI/ML Relapse Prediction

- Risk scoring: authenticated backend prediction endpoint.
- Low/medium/high: categorical response and risk UI.
- Random Forest: training/evaluation code and tracked research inference artifact.
- XGBoost: training/evaluation pipeline; generated artifacts are intentionally ignored by Git.
- EMASENS: feature mapping and RDS loader; added checksum-verified pinned download command `python -m ml.fetch_data`.
- Personalized feedback: risk result and high-risk alternatives ranked by the user's trigger, mood and completed attempt outcomes.
- Prediction history: dated risk history in Track and risk level on each craving entry.

**Limitation:** `RELAPSE_PREDICTOR_MODE=rule_based` remains the production default.
The recorded app-compatible RF ROC-AUC is 0.5032 and XGBoost ROC-AUC is 0.4779.
Training a model is not evidence that its predictions are useful. The stronger
full-EMA research models require additional inputs beyond the app's current
fields. See `backend/ml/README.md` and the tracked artifact metadata. No model
was promoted to production as part of this audit.

### 6. HealthBot — AI Health Assistant

- Chat interface: user/bot bubbles, text input and suggested prompts.
- Gemini responses: server-side API request with structured output validation.
- Recovery guidance, health questions and craving advice: generated responses within the configured scope and curated fallback topics.
- Emergency detection: local pre-generation checks and fixed escalation response.
- Rule-based fallback: used for absent Gemini credentials, request failures, and invalid responses; explicitly labeled as general guidance with AI unavailable.
- Conversation history: latest 100 exchanges restored in chronological order from the signed-in user's private collection; emergency flag persisted; stale asynchronous replies cannot cross logout sessions.

### 7. Habit Alternatives

- Alternative activities: fixed curated library plus distraction mini-games.
- Healthy suggestions: trigger/mood matching and completed-attempt outcome ranking.
- Distraction activities: breathing, walking and other suggestions/games.
- Attempts: selected activities persisted per user.
- Completed attempts: outcome feedback saved; “helped” and “did not help” both count as completed feedback.
- History: alternative activity history screen.

### 8. Progress Analytics and Health Recovery

- Daily progress: dashboard state and daily usage/craving status.
- Weekly progress: seven-day craving chart and week-over-week comparison.
- Monthly progress: craving/relapse monthly summaries.
- Craving statistics: totals, trigger breakdown, history and risk categories.
- Habit statistics: activities tried, outcomes completed, activities reported helpful.
- Nicotine-free progress: streak and quit/restart calculations.
- Money saved analytics: dashboard savings, Track savings estimate and baseline daily/weekly/30-day spending; based on the user's saved consumption/cost, not measured bank transactions.
- Recovery timeline: product-aware cited milestones.
- Charts: weekly progress and Track trend chart.

### 9. Rewards and Achievements

- Achievement badges and milestone rewards: `badge_checker.dart` and persisted badge awards.
- Nicotine-free milestones: configured streak thresholds.
- Progress rewards: milestone checks from dashboard/rewards loads.
- Earned badges: earned/locked grid.
- Rewards history: dated earned-badge list.

### 10. Community

- Feed and view posts: shared authenticated feed.
- Create posts: new-post form and repository.
- Like posts: per-user like documents and toggle.
- Reply: replies screen and repository.
- Interaction: likes, replies and topic filtering.

### 11. Knowledge Hub

- Educational articles: bundled article library.
- Addiction awareness, recovery guidance and health/wellness: article categories and detail screens.
- Bookmarks: per-account private bookmark documents.
- Saved articles: new Saved Articles filter, combined with category selection.

### 12. Reminders and Notifications

- Daily reminders and craving-management prompts: local EMA schedule and daily-check-in copy.
- Habit reminders: optional category and local schedule.
- Recovery motivation: optional category and local schedule.
- Local notifications: permissions and timezone-aware scheduling.
- FCM push: opt-in token synchronization, authenticated event endpoints, scheduler endpoint, foreground/background handling.

### 13. Profile and Settings

- View profile: avatar/name and progress summary.
- Edit/update personal information: profile editor and shared user repository.
- Account settings: privacy/security, account deletion and optional biometric unlock.
- Notification preferences: reminder settings, frequency and categories.
- Logout: profile action returns to welcome and clears HealthBot session state.

## External setup and remaining verification

- Google sign-in: this machine's debug SHA-1 is `1E:DB:D2:EE:86:F7:07:C2:90:CF:5D:AE:5A:B7:31:09:3F:4B:A1:0E`; the checked config registers a different fingerprint. Add the current fingerprint to Firebase and replace the downloaded Android config, then rebuild. Firebase Console state was not changed by this audit.
- Enable Firebase email/password, Google and Phone providers as needed; verify SMS/WhatsApp delivery on a device. WhatsApp requires Meta authentication-template configuration.
- Run/deploy the backend and use a reachable `OTP_BACKEND_BASE_URL`; `10.0.2.2` is an Android emulator host address, not a physical-device backend address.
- Configure Gemini backend credentials for generated replies. Fallback replies do not require a Gemini key.
- Deploy the Firestore rules and configure Firebase Admin/FCM platform credentials; test push delivery with opted-in devices. Avoid scheduling remote duplicates of reminders already scheduled locally.
- RF/XGBoost research artifacts and raw data are intentionally ignored; regenerate with `python -m ml.fetch_data` and `python -m ml.train`. Useful app-compatible ML performance remains unresolved.
- Automated tests use fake service providers and do not prove live Google/SMS/Gemini/FCM delivery.

## Verification record

- Complete backend suite after training and dependency repair: **204 passed, none skipped**. Existing dependency warnings remain (primarily NumPy/joblib deprecations).
- `flutter analyze --no-pub`: no issues.
- Full mobile suite: 536 passed, two stale recovery-timeline assertions failed. After correcting the assertions to match the existing product-aware timeline, all 39 dashboard/new-feature tests passed. Final HealthBot/new-feature recheck: 24 passed. The entire suite was not rerun after these targeted fixes.
- `python -m ml.fetch_data`: downloaded the 3,341,664-byte archive and verified MD5 `a71897ea6a8fc1f38d9c9d25edf1e48f` before extraction.
- `python -m ml.train`: successfully trained and saved all four models (RF and XGBoost, full-EMA and craving-compatible), feature columns and evaluation metadata. The existing environment had Python 3.14 pandas/pyreadr binaries under Python 3.12; these two packages were reinstalled with compatible wheels.
- Reproduced held-out ROC-AUC: full-EMA RF 0.8525, full-EMA XGBoost 0.8099, craving-compatible RF 0.5032, craving-compatible XGBoost 0.4779. These reproduce the prior recorded results, including their limitations.
- Generated model artifacts: `backend/ml/models/`; evaluation metadata: `backend/ml/outputs/training_metadata.json`. Both remain Git-ignored as intended.
