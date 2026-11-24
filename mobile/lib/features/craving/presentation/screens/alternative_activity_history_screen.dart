import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/craving/controllers/alternatives_controller.dart';
import 'package:quit_companion/features/craving/data/habit_alternative_library.dart';
import 'package:quit_companion/features/craving/models/habit_alternative_attempt.dart';

class AlternativeActivityHistoryScreen extends StatefulWidget {
  final String userId;
  final AlternativesController controller;

  const AlternativeActivityHistoryScreen({
    super.key,
    required this.userId,
    required this.controller,
  });

  @override
  State<AlternativeActivityHistoryScreen> createState() =>
      _AlternativeActivityHistoryScreenState();
}

class _AlternativeActivityHistoryScreenState
    extends State<AlternativeActivityHistoryScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    Future.microtask(() => widget.controller.loadAttemptHistory(widget.userId));
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('activity_history_back_button'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: const Text(
                      'Activity History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildHistory(controller)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory(AlternativesController controller) {
    if (controller.isHistoryLoading) {
      return const Center(
        key: Key('activity_history_loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (controller.historyErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            controller.historyErrorMessage!,
            key: const Key('activity_history_error'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      );
    }
    if (controller.attemptHistory.isEmpty) {
      return const Center(
        key: Key('activity_history_empty'),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Your tried activities will appear here.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      key: const Key('activity_history_list'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: controller.attemptHistory.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final attempt = controller.attemptHistory[index];
        return Column(
          children: [
            _AttemptCard(attempt: attempt),
            if (attempt.outcomeHelped == null)
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(child: const Text('Did this help?')),
                  TextButton(
                    onPressed: () => controller.recordOutcome(
                      userId: widget.userId,
                      helped: true,
                      attemptId: attempt.attemptId,
                    ),
                    child: const Text('Yes'),
                  ),
                  TextButton(
                    onPressed: () => controller.recordOutcome(
                      userId: widget.userId,
                      helped: false,
                      attemptId: attempt.attemptId,
                    ),
                    child: const Text('No'),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _AttemptCard extends StatelessWidget {
  final HabitAlternativeAttempt attempt;

  const _AttemptCard({required this.attempt});

  @override
  Widget build(BuildContext context) {
    final alternative = habitAlternativeLibrary.where(
      (item) => item.alternativeId == attempt.alternativeId,
    );
    final title = alternative.isEmpty
        ? attempt.alternativeId
        : alternative.first.title;
    final outcome = switch (attempt.outcomeHelped) {
      true => 'Helped',
      false => 'Did not help',
      null => 'No outcome recorded',
    };

    return Container(
      key: Key('activity_history_attempt_${attempt.attemptId}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatDateTime(attempt.attemptedAt),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Outcome: $outcome',
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime dateTime) {
  final date = dateTime.toLocal();
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$year-$month-$day at $hour:$minute';
}
