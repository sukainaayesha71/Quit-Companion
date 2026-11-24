import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/craving/controllers/alternatives_controller.dart';
import 'package:quit_companion/features/craving/controllers/craving_log_controller.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/craving/presentation/screens/high_risk_screen.dart';
import 'package:quit_companion/features/crisis_support/presentation/widgets/professional_support_prompt.dart';
import 'package:quit_companion/features/craving/presentation/screens/widgets/risk_result_banner.dart';

const _moodLabels = {
  Mood.stressed: 'Stressed',
  Mood.bored: 'Bored',
  Mood.sad: 'Sad',
  Mood.happy: 'Happy',
  Mood.social: 'Social',
};

const _moodIcons = {
  Mood.stressed: Icons.warning_amber_rounded,
  Mood.bored: Icons.sentiment_dissatisfied_outlined,
  Mood.sad: Icons.sentiment_very_dissatisfied_outlined,
  Mood.happy: Icons.sentiment_satisfied_outlined,
  Mood.social: Icons.groups_outlined,
};

const _triggerLabels = {
  TriggerCategory.stress: 'Stress',
  TriggerCategory.afterMeal: 'After Meal',
  TriggerCategory.socialPressure: 'Social Pressure',
  TriggerCategory.boredom: 'Boredom',
  TriggerCategory.other: 'Other',
};

const _triggerIcons = {
  TriggerCategory.stress: Icons.psychology_outlined,
  TriggerCategory.afterMeal: Icons.restaurant_outlined,
  TriggerCategory.socialPressure: Icons.groups_outlined,
  TriggerCategory.boredom: Icons.sentiment_neutral_outlined,
  TriggerCategory.other: Icons.more_horiz,
};

const _locationOptions = [
  'Home',
  'Work',
  'School',
  'Social Gathering',
  'Outdoors',
  'In Transit',
  'Other',
];

const _activityOptions = [
  'Working/studying',
  'Eating',
  'Drinking coffee/tea',
  'Taking a break',
  'Socializing',
  'Driving/commuting',
  'Relaxing/watching TV',
  'Exercising',
  'Other',
];

/// FR5/FR6 (Module 3): Log Craving screen. Visual source of truth is the
/// approved reference, docs/UI_Design/log craving 6.png — intensity
/// slider, mood/trigger chips, location/activity dropdowns, optional
/// notes, submit. Reuses AppColors/AppTheme so it reads as the same app as
/// Modules 1-2.
class LogCravingScreen extends StatefulWidget {
  final String userId;
  final CravingLogController controller;
  final AlternativesController alternativesController;

  const LogCravingScreen({
    super.key,
    required this.userId,
    required this.controller,
    required this.alternativesController,
  });

  @override
  State<LogCravingScreen> createState() => _LogCravingScreenState();
}

// Mood-slider dimensions (Open Decision 6, backend AI/ML plan 2026-08-17)
// — one per EMASENS_ML affect column the full_ema relapse-risk model uses.
// See backend/ml/pipeline/feature_mapping.py for the exact app-field ->
// EMASENS-column mapping. Order matches that file's mood-dimension list.
const _moodSliderLabels = {
  'moodHappy': 'Happy',
  'moodExcited': 'Excited',
  'moodEnthusiastic': 'Enthusiastic',
  'moodContented': 'Contented',
  'moodCalm': 'Calm',
  'moodIrritable': 'Irritable',
  'moodAnxious': 'Anxious',
  'moodStressed': 'Stressed',
  'moodSad': 'Sad',
  'moodBored': 'Bored',
};

class _LogCravingScreenState extends State<LogCravingScreen> {
  double _intensity = 5;
  Mood? _mood;
  TriggerCategory? _trigger;
  String? _location;
  String? _activity;
  final _notesController = TextEditingController();
  bool _showValidationError = false;
  final Map<String, double> _recoveryContext = {};
  bool? _nicotineUsedSinceLastCheckin;

  // Mood-slider ratings (0-10), all default to the same neutral midpoint
  // the intensity slider already uses.
  final Map<String, double> _moodSliders = {
    for (final key in _moodSliderLabels.keys) key: 5,
  };

  /// ML integration fix (2026-11-23): sliders the user actually moved. Only
  /// these are saved/sent; the others are genuinely unanswered (null).
  final Set<String> _ratedMoods = {};

  /// Recovery check-in: shown open on every craving log; the user may skip.
  bool _checkInSkipped = false;

  double? _rated(String key) =>
      _ratedMoods.contains(key) ? _moodSliders[key] : null;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_mood == null ||
        _trigger == null ||
        _location == null ||
        _activity == null) {
      setState(() => _showValidationError = true);
      return;
    }
    setState(() => _showValidationError = false);
    await widget.controller.submitCraving(
      userId: widget.userId,
      intensity: _intensity.round(),
      mood: _mood!,
      triggerCategory: _trigger!,
      locationContext: _location!,
      activity: _activity!,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      moodHappy: _rated('moodHappy'),
      moodExcited: _rated('moodExcited'),
      moodEnthusiastic: _rated('moodEnthusiastic'),
      moodContented: _rated('moodContented'),
      moodCalm: _rated('moodCalm'),
      moodIrritable: _rated('moodIrritable'),
      moodAnxious: _rated('moodAnxious'),
      moodStressed: _rated('moodStressed'),
      moodSad: _rated('moodSad'),
      moodBored: _rated('moodBored'),
      // Skipped or unanswered check-in questions are sent as missing.
      recoveryContext: _checkInSkipped ? const {} : Map.of(_recoveryContext),
      nicotineUsedSinceLastCheckin: _checkInSkipped
          ? null
          : _nicotineUsedSinceLastCheckin,
    );
    if (!mounted) return;
    // SRDS 4.2: gentle professional-support prompt after repeated high
    // anxiety/sadness ratings. Shown before any high-risk redirect so the
    // user sees it once, on this screen, and the existing flow resumes
    // unchanged afterwards whichever option they pick.
    if (widget.controller.status == CravingLogStatus.success &&
        widget.controller.suggestProfessionalSupport) {
      widget.controller.markProfessionalSupportPromptShown();
      await ProfessionalSupportPrompt.show(context);
      if (!mounted) return;
    }
    // High risk (FR5) goes to the approved 6a destination (SRDS
    // Get_Habit_Alternatives) instead of the plain inline banner —
    // pushReplacement so its back/skip both return straight to Dashboard
    // with a single pop, matching the approved design's single exit.
    if (widget.controller.status == CravingLogStatus.success &&
        widget.controller.lastRiskLevel == RelapseRiskLevel.high) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HighRiskScreen(
            userId: widget.userId,
            triggerCategory: _trigger!,
            mood: _mood!,
            controller: widget.alternativesController,
            predictionSource: widget.controller.lastPredictionSource,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.controller.status;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(onClose: () => Navigator.of(context).maybePop()),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                // High risk navigates away in _handleSubmit before this
                // would ever be seen — the RiskResultBanner is only for
                // Medium/Low ("Log Saved. Keep going!" per SRDS §5.5.2).
                child:
                    status == CravingLogStatus.success &&
                        widget.controller.lastRiskLevel != RelapseRiskLevel.high
                    ? RiskResultBanner(
                        riskLevel: widget.controller.lastRiskLevel!,
                        assessmentPending: widget.controller.assessmentPending,
                        predictionSource:
                            widget.controller.lastPredictionSource,
                        onDone: () => Navigator.of(context).maybePop(),
                      )
                    : _buildForm(status),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ML integration fix (2026-11-23): the recovery check-in is offered on
  /// every craving log (previously a collapsed, easily-missed tile). Its
  /// four answers are what the experimental ML estimate relies on most.
  /// Skipping never blocks saving; skipped or unanswered questions are sent
  /// as missing, never as guesses.
  Widget _buildRecoveryCheckIn() {
    return Container(
      key: const Key('craving_checkin_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sageLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recovery check-in (optional)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Four quick questions. Answering them helps the experimental ML '
            'risk estimate; skipped questions are left blank, not guessed.',
            key: Key('craving_checkin_explanation'),
            style: TextStyle(fontSize: 12.5, height: 1.35),
          ),
          if (_checkInSkipped) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Skipped — nothing will be sent for these questions.',
                    key: Key('craving_checkin_skipped_text'),
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                TextButton(
                  key: const Key('craving_checkin_answer_button'),
                  onPressed: () => setState(() => _checkInSkipped = false),
                  child: const Text('Answer check-in'),
                ),
              ],
            ),
          ] else ...[
            for (final item in const {
              'motivation_imp': 'Motivation to stay nicotine-free',
              'confidence_imp': 'Confidence in staying nicotine-free',
              'pain_imp': 'Physical discomfort',
            }.entries)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    '${item.value}: ${_recoveryContext[item.key]?.round().toString() ?? "not answered"}',
                    key: Key('craving_checkin_label_${item.key}'),
                  ),
                  Slider(
                    key: Key('craving_checkin_slider_${item.key}'),
                    value: _recoveryContext[item.key] ?? 5,
                    min: 0,
                    max: 10,
                    divisions: 10,
                    onChanged: (value) =>
                        setState(() => _recoveryContext[item.key] = value),
                  ),
                ],
              ),
            DropdownButtonFormField<double>(
              key: const Key('craving_checkin_availability'),
              isExpanded: true,
              initialValue: _recoveryContext['cigarette_availability_imp'],
              decoration: const InputDecoration(
                labelText: 'Cigarette availability right now',
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Not available')),
                DropdownMenuItem(
                  value: 2,
                  child: Text('Available with difficulty'),
                ),
                DropdownMenuItem(value: 3, child: Text('Easily available')),
              ],
              onChanged: (value) => setState(() {
                if (value != null) {
                  _recoveryContext['cigarette_availability_imp'] = value;
                }
              }),
            ),
            const SizedBox(height: 8),
            const Text('Have you used nicotine since your previous check-in?'),
            Wrap(
              spacing: 12,
              children: [
                ChoiceChip(
                  label: const Text('Yes'),
                  selected: _nicotineUsedSinceLastCheckin == true,
                  onSelected: (_) =>
                      setState(() => _nicotineUsedSinceLastCheckin = true),
                ),
                ChoiceChip(
                  label: const Text('No'),
                  selected: _nicotineUsedSinceLastCheckin == false,
                  onSelected: (_) =>
                      setState(() => _nicotineUsedSinceLastCheckin = false),
                ),
              ],
            ),
            const Text(
              'Unanswered fields stay empty. This does not automatically log a relapse or reset your streak.',
              style: TextStyle(fontSize: 12),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('craving_checkin_skip_button'),
                onPressed: () => setState(() {
                  _checkInSkipped = true;
                  _recoveryContext.clear();
                  _nicotineUsedSinceLastCheckin = null;
                }),
                child: const Text('Skip check-in'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForm(CravingLogStatus status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: const Text(
                'How intense is it?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.terracotta,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_intensity.round()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.terracotta,
            inactiveTrackColor: AppColors.border,
            thumbColor: AppColors.terracotta,
            overlayColor: AppColors.terracotta.withValues(alpha: 0.15),
          ),
          child: Slider(
            key: const Key('craving_intensity_slider'),
            value: _intensity,
            min: 1,
            max: 10,
            divisions: 9,
            label: '${_intensity.round()}',
            onChanged: (value) => setState(() => _intensity = value),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'How are you feeling?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: Mood.values
              .map(
                (mood) => _Chip(
                  chipKey: Key('craving_mood_${mood.name}'),
                  label: _moodLabels[mood]!,
                  icon: _moodIcons[mood]!,
                  selected: _mood == mood,
                  onTap: () => setState(() => _mood = mood),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        const Text(
          'Rate your mood',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                'Only the moods you rate are saved. Untouched sliders are '
                'left blank, not counted as 5.',
                key: const Key('craving_mood_rating_note'),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ),
            if (_ratedMoods.isNotEmpty)
              TextButton(
                key: const Key('craving_mood_clear_button'),
                onPressed: () => setState(() {
                  _ratedMoods.clear();
                  for (final key in _moodSliders.keys) {
                    _moodSliders[key] = 5;
                  }
                }),
                child: const Text('Clear mood ratings'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ..._moodSliderLabels.entries.map(
          (entry) => _MoodSlider(
            sliderKey: Key('craving_mood_slider_${entry.key}'),
            label: entry.value,
            value: _moodSliders[entry.key]!,
            rated: _ratedMoods.contains(entry.key),
            onChanged: (value) => setState(() {
              _moodSliders[entry.key] = value;
              _ratedMoods.add(entry.key);
            }),
          ),
        ),
        const SizedBox(height: 16),
        _buildRecoveryCheckIn(),
        const SizedBox(height: 20),
        const Text(
          'What triggered it?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: TriggerCategory.values
              .map(
                (trigger) => _Chip(
                  chipKey: Key('craving_trigger_${trigger.name}'),
                  label: _triggerLabels[trigger]!,
                  icon: _triggerIcons[trigger]!,
                  selected: _trigger == trigger,
                  onTap: () => setState(() => _trigger = trigger),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _Dropdown(
                dropdownKey: const Key('craving_location_dropdown'),
                hint: 'Location',
                value: _location,
                options: _locationOptions,
                onChanged: (value) => setState(() => _location = value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Dropdown(
                dropdownKey: const Key('craving_activity_dropdown'),
                hint: 'Activity',
                value: _activity,
                options: _activityOptions,
                onChanged: (value) => setState(() => _activity = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('craving_notes_field'),
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Anything else? (optional)',
          ),
        ),
        if (_showValidationError) ...[
          const SizedBox(height: 16),
          const Text(
            'Please select a mood, trigger, location, and activity.',
            key: Key('craving_validation_error'),
            style: TextStyle(color: AppColors.error, fontSize: 14),
          ),
        ],
        if (status == CravingLogStatus.error &&
            widget.controller.errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.controller.errorMessage!,
            key: const Key('craving_error_text'),
            style: const TextStyle(color: AppColors.error, fontSize: 14),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          key: const Key('craving_submit_button'),
          onPressed: status == CravingLogStatus.submitting
              ? null
              : _handleSubmit,
          child: status == CravingLogStatus.submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: const Text(
                  'Log a Craving',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                key: const Key('craving_close_button'),
                onPressed: onClose,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.close, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 16),
          height: 110,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.sageLight,
                AppColors.sage.withValues(alpha: 0.55),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.hourglass_top_rounded,
              color: AppColors.sageDark,
              size: 36,
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact mood-rating slider (0-10) — same SliderTheme/color language as
/// the intensity slider above, just laid out one line tighter per row
/// since there are ten of these.
class _MoodSlider extends StatelessWidget {
  final Key sliderKey;
  final String label;
  final double value;
  final bool rated;
  final ValueChanged<double> onChanged;

  const _MoodSlider({
    required this.sliderKey,
    required this.label,
    required this.value,
    required this.onChanged,
    this.rated = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.sageDark,
              inactiveTrackColor: AppColors.border,
              thumbColor: rated ? AppColors.sageDark : AppColors.border,
              overlayColor: AppColors.sageDark.withValues(alpha: 0.15),
            ),
            child: Slider(
              key: sliderKey,
              value: value,
              min: 0,
              max: 10,
              divisions: 10,
              label: '${value.round()}',
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 24,
          child: Text(
            rated ? '${value.round()}' : '–',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final Key chipKey;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.chipKey,
    required this.label,
    required this.icon,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.terracotta : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.terracotta : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppColors.sageDark,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final Key dropdownKey;
  final String hint;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _Dropdown({
    required this.dropdownKey,
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: dropdownKey,
      initialValue: value,
      hint: Text(hint),
      // isExpanded + overflow: without these, DropdownButtonFormField renders
      // its selected/item Text unconstrained inside an internal Row — at
      // real device widths (two of these side by side), "Social Gathering"
      // doesn't fit and throws a RenderFlex overflow (confirmed on the
      // Realme device). isExpanded makes the button use its full allotted
      // width; ellipsis truncates instead of overflowing if it's still tight.
      isExpanded: true,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: options
          .map(
            (option) => DropdownMenuItem(
              value: option,
              child: Text(option, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
