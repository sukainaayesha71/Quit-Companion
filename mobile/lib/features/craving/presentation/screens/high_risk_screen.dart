import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/craving/controllers/alternatives_controller.dart';
import 'package:quit_companion/features/craving/models/habit_alternative.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/craving/presentation/screens/alternative_detail_screen.dart';
import 'package:quit_companion/features/craving/presentation/screens/widgets/prediction_source_label.dart';
import 'package:quit_companion/features/relapse/data/relapse_prediction_client.dart';

class _AlternativeUiMeta {
  final String tag;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final bool showSparkle;

  const _AlternativeUiMeta({
    required this.tag,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.showSparkle = false,
  });
}

// Presentational-only metadata (icon/color/tag label) keyed by
// HabitAlternative.alternativeId — not SDD content, so it stays local to
// this screen rather than living on the shared HabitAlternative model.
const _uiMeta = {
  'breathing': _AlternativeUiMeta(
    tag: 'Exercise',
    icon: Icons.air_rounded,
    iconBg: AppColors.sageLight,
    iconColor: AppColors.sageDark,
    showSparkle: true,
  ),
  'cold_water': _AlternativeUiMeta(
    tag: 'Quick Fix',
    icon: Icons.water_drop_outlined,
    iconBg: AppColors.sageLight,
    iconColor: AppColors.sageDark,
  ),
  'short_walk': _AlternativeUiMeta(
    tag: 'Exercise',
    icon: Icons.directions_walk_rounded,
    iconBg: AppColors.terracottaLight,
    iconColor: AppColors.terracottaDark,
  ),
  'bubble_pop': _AlternativeUiMeta(
    tag: 'Game',
    icon: Icons.sports_esports_outlined,
    iconBg: AppColors.sageLight,
    iconColor: AppColors.sageDark,
  ),
  'word_puzzle': _AlternativeUiMeta(
    tag: 'Game',
    icon: Icons.extension_outlined,
    iconBg: AppColors.terracottaLight,
    iconColor: AppColors.terracottaDark,
  ),
  'tap_pop': _AlternativeUiMeta(
    tag: 'Game',
    icon: Icons.touch_app_rounded,
    iconBg: AppColors.sageLight,
    iconColor: AppColors.sageDark,
  ),
  'memory_match': _AlternativeUiMeta(
    tag: 'Game',
    icon: Icons.grid_view_rounded,
    iconBg: AppColors.terracottaLight,
    iconColor: AppColors.terracottaDark,
  ),
  'craving_countdown': _AlternativeUiMeta(
    tag: 'Quick Fix',
    icon: Icons.timer_outlined,
    iconBg: AppColors.terracottaLight,
    iconColor: AppColors.terracottaDark,
  ),
};

/// docs/UI_Design/6a.png — the SRDS §5.5.2 pseudocode's
/// `Get_Habit_Alternatives` destination, shown only for a High relapse-risk
/// craving log (FR5). FR7 (Module 7 — Alternatives & Habit Replacement,
/// Mehreen's module) now backs every interactive element here for real:
/// the filter chips actually filter, "Try This" opens
/// AlternativeDetailScreen and logs a real attempt, and the ranking comes
/// from the fixed-library deterministic matcher (see
/// lib/domain/habit_alternative_matcher.dart) instead of the static order
/// this screen originally hard-coded before Module 7 existed. The
/// reference's "80% success rate for you" personalization number is still
/// intentionally omitted rather than fabricated. Ranking adapts using the
/// user's recorded outcomes, while all displayed activity content stays fixed.
class HighRiskScreen extends StatefulWidget {
  final String userId;
  final TriggerCategory triggerCategory;
  final Mood mood;
  final AlternativesController controller;

  /// Set when reached from a scored craving (the Log Craving redirect or the
  /// Dashboard's high-risk alert): that assessment's saved risk level,
  /// shown in the header. Null when browsed from the Alternatives tile, so
  /// no result is shown without an assessment.
  final RelapseRiskLevel? riskLevel;

  /// How that same assessment was produced, as reported by the backend;
  /// shown as "Scored by: ...". Null or unknown shows no source label.
  final PredictionSource? predictionSource;

  const HighRiskScreen({
    super.key,
    required this.userId,
    required this.triggerCategory,
    required this.mood,
    required this.controller,
    this.riskLevel,
    this.predictionSource,
  });

  @override
  State<HighRiskScreen> createState() => _HighRiskScreenState();
}

class _HighRiskScreenState extends State<HighRiskScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    Future.microtask(() {
      if (!mounted) return;
      unawaited(
        widget.controller.loadRecommendations(
          userId: widget.userId,
          triggerCategory: widget.triggerCategory,
          mood: widget.mood,
        ),
      );
    });
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _openDetail(HabitAlternative alternative) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlternativeDetailScreen(
          userId: widget.userId,
          alternative: alternative,
          triggerCategory: widget.triggerCategory,
          mood: widget.mood,
          controller: widget.controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                riskLevel: widget.riskLevel,
                predictionSource: widget.predictionSource,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _FilterChip(
                          chipKey: const Key('high_risk_filter_all'),
                          label: 'All',
                          selected: controller.filter == null,
                          onTap: () => controller.setFilter(null),
                        ),
                        _FilterChip(
                          chipKey: const Key('high_risk_filter_exercises'),
                          label: 'Exercises',
                          selected:
                              controller.filter == AlternativeCategory.exercise,
                          onTap: () => controller.setFilter(
                            AlternativeCategory.exercise,
                          ),
                        ),
                        _FilterChip(
                          chipKey: const Key('high_risk_filter_games'),
                          label: 'Games',
                          selected:
                              controller.filter == AlternativeCategory.game,
                          onTap: () =>
                              controller.setFilter(AlternativeCategory.game),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (controller.isRecommendationsLoading)
                      const Center(
                        key: Key('high_risk_recommendations_loading'),
                        child: CircularProgressIndicator(),
                      )
                    else ...[
                      if (controller.rankingSource != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            controller.rankingSource ==
                                    RecommendationRankingSource
                                        .personalisedModel
                                ? 'Ordered for you by your personalised '
                                      'recommendation model.'
                                : "Ordered on your device with simple rules: "
                                      "the personalised model couldn't be "
                                      'reached right now.',
                            key: const Key('high_risk_ranking_source'),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      if (controller.historyErrorMessage != null)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 14),
                          child: Text(
                            'Showing general suggestions because your activity history could not be loaded.',
                            key: Key('high_risk_history_error'),
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      for (final alternative
                          in controller.filteredRecommendations) ...[
                        _AlternativeCard(
                          alternative: alternative,
                          onTryThis: () => _openDetail(alternative),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        key: const Key('high_risk_skip_link'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Skip for now — back to Dashboard  ↗',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final RelapseRiskLevel? riskLevel;
  final PredictionSource? predictionSource;

  const _Header({this.riskLevel, this.predictionSource});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              key: const Key('high_risk_back_button'),
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.sageLight,
                shape: const CircleBorder(),
              ),
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "You've got this 💪",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Here are a few things that might help right now.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (riskLevel != null || predictionSource?.label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                key: const Key('high_risk_assessment_result'),
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (riskLevel != null) _RiskLevelPill(riskLevel: riskLevel!),
                  if (predictionSource?.label != null)
                    PredictionSourceLabel(source: predictionSource),
                ],
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(top: 16),
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.terracottaLight,
                AppColors.sage.withValues(alpha: 0.55),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.wb_sunny_rounded,
              color: AppColors.terracottaDark,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final Key chipKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.chipKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: chipKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.terracotta : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.terracotta : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _AlternativeCard extends StatelessWidget {
  final HabitAlternative alternative;
  final VoidCallback onTryThis;

  const _AlternativeCard({required this.alternative, required this.onTryThis});

  @override
  Widget build(BuildContext context) {
    final meta = _uiMeta[alternative.alternativeId]!;
    return Container(
      key: Key('high_risk_card_${alternative.alternativeId}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final icon = Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: meta.iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(meta.icon, color: meta.iconColor, size: 24),
              ),
              if (meta.showSparkle)
                const Positioned(
                  right: -2,
                  top: -2,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: AppColors.terracotta,
                  ),
                ),
            ],
          );
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alternative.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                alternative.description,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  meta.tag,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          );
          final action = OutlinedButton(
            key: Key('high_risk_try_this_${alternative.alternativeId}'),
            onPressed: onTryThis,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.terracotta,
              side: const BorderSide(color: AppColors.terracotta),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Try This',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          );
          if (constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(12) > 15) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icon,
                    const SizedBox(width: 14),
                    Expanded(child: content),
                  ],
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }
          return Row(
            children: [
              icon,
              const SizedBox(width: 14),
              Expanded(child: content),
              const SizedBox(width: 8),
              action,
            ],
          );
        },
      ),
    );
  }
}

/// The assessment's saved risk level, in the same pill style as
/// PredictionSourceLabel and the same wording and colours as the Log
/// Craving result card (RiskResultBanner).
class _RiskLevelPill extends StatelessWidget {
  final RelapseRiskLevel riskLevel;

  const _RiskLevelPill({required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (riskLevel) {
      RelapseRiskLevel.low => (
        'Low Risk',
        AppColors.sageDark,
        Icons.check_circle_outline,
      ),
      RelapseRiskLevel.medium => (
        'Medium Risk',
        AppColors.terracottaDark,
        Icons.info_outline,
      ),
      RelapseRiskLevel.high => (
        'High Risk',
        AppColors.error,
        Icons.warning_amber_rounded,
      ),
    };
    return Semantics(
      label: 'Assessment result: $label',
      excludeSemantics: true,
      child: Container(
        key: const Key('high_risk_assessment_level'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
