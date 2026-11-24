import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/craving/controllers/alternatives_controller.dart';
import 'package:quit_companion/features/craving/models/habit_alternative.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/games/presentation/screens/breathing_bubble_game_screen.dart';
import 'package:quit_companion/features/games/presentation/screens/bubble_pop_game_screen.dart';
import 'package:quit_companion/features/games/presentation/screens/craving_countdown_game_screen.dart';
import 'package:quit_companion/features/games/presentation/screens/memory_match_game_screen.dart';
import 'package:quit_companion/features/games/presentation/screens/tap_and_pop_game_screen.dart';
import 'package:quit_companion/features/games/presentation/screens/word_search_game_screen.dart';
import 'package:quit_companion/features/craving/presentation/screens/alternative_activity_history_screen.dart';

/// Every alternativeId with a real playable game screen — deliberately
/// independent of AlternativeCategory, since a game can replace an
/// alternative of any category (Breathing Bubble replaces an `exercise`
/// alternative, not a `game` one).
const _gameScreenIds = {
  'bubble_pop',
  'word_puzzle',
  'breathing',
  'tap_pop',
  'memory_match',
  'craving_countdown',
};

/// FR7 "Try This" destination (SRDS UC4 steps 7-9: brief instruction, user
/// attempts it, outcome feedback requested). No approved mockup exists for
/// this screen — same documented gap every prior module hit for a
/// no-reference detail/compose screen (Module 4's "My Quit Plan", Module 5's
/// add-journal-entry) — so this is a plain layout reusing existing
/// card/typography conventions, not a pixel-matched design.
///
/// SRDS UC4 step 9 asks for outcome feedback "after 5 minutes"; this repo
/// has no push/reminder infrastructure (no `firebase_messaging` dependency
/// anywhere — the same exclusion every prior module applied to FCM), so
/// the Yes/No feedback is offered immediately on this screen instead of a
/// timed follow-up prompt — a documented deviation, not a silent one.
class AlternativeDetailScreen extends StatefulWidget {
  final String userId;
  final HabitAlternative alternative;
  final TriggerCategory triggerCategory;
  final Mood mood;
  final AlternativesController controller;

  const AlternativeDetailScreen({
    super.key,
    required this.userId,
    required this.alternative,
    required this.triggerCategory,
    required this.mood,
    required this.controller,
  });

  @override
  State<AlternativeDetailScreen> createState() =>
      _AlternativeDetailScreenState();
}

class _AlternativeDetailScreenState extends State<AlternativeDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.controller.selectAlternative(
      userId: widget.userId,
      alternative: widget.alternative,
      triggerCategory: widget.triggerCategory,
      mood: widget.mood,
    );
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _openGame(BuildContext context, String alternativeId) {
    final Widget gameScreen = switch (alternativeId) {
      'bubble_pop' => const BubblePopGameScreen(),
      'word_puzzle' => const WordSearchGameScreen(),
      'breathing' => const BreathingBubbleGameScreen(),
      'tap_pop' => const TapAndPopGameScreen(),
      'memory_match' => const MemoryMatchGameScreen(),
      'craving_countdown' => const CravingCountdownGameScreen(),
      _ => throw StateError(
        'No game screen wired up for alternativeId "$alternativeId".',
      ),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => gameScreen));
  }

  void _openActivityHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlternativeActivityHistoryScreen(
          userId: widget.userId,
          controller: widget.controller,
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alternative = widget.alternative;
    final feedbackMessage = widget.controller.feedbackMessage;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  key: const Key('alternative_detail_back_button'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.sageLight,
                    shape: const CircleBorder(),
                  ),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                alternative.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                alternative.description,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  alternative.instructions,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
              if (_gameScreenIds.contains(alternative.alternativeId)) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const Key('alternative_detail_play_button'),
                  onPressed: () =>
                      _openGame(context, alternative.alternativeId),
                  child: const Text('Play'),
                ),
              ],
              const SizedBox(height: 28),
              const Text(
                'Did this help?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('alternative_detail_helped_yes'),
                      onPressed: () => widget.controller.recordOutcome(
                        userId: widget.userId,
                        helped: true,
                      ),
                      child: const Text('Yes'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('alternative_detail_helped_no'),
                      onPressed: () => widget.controller.recordOutcome(
                        userId: widget.userId,
                        helped: false,
                      ),
                      child: const Text('No'),
                    ),
                  ),
                ],
              ),
              if (feedbackMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  feedbackMessage,
                  key: const Key('alternative_detail_feedback_message'),
                  style: const TextStyle(
                    color: AppColors.sageDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              OutlinedButton.icon(
                key: const Key('alternative_detail_activity_history'),
                onPressed: () => _openActivityHistory(context),
                icon: const Icon(Icons.history),
                label: const Text('Activity History'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
