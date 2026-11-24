import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/tracking/controllers/track_controller.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

class CravingHistoryScreen extends StatefulWidget {
  final String userId;
  final TrackController controller;
  const CravingHistoryScreen({
    super.key,
    required this.userId,
    required this.controller,
  });

  @override
  State<CravingHistoryScreen> createState() => _CravingHistoryScreenState();
}

class _CravingHistoryScreenState extends State<CravingHistoryScreen> {
  final Set<String> _deleting = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    Future.microtask(() => widget.controller.loadTrack(widget.userId));
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  Future<void> _delete(CravingLog log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete craving log?'),
        content: const Text(
          'This removes the entry and its risk assessment from your history and statistics.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting.add(log.logId));
    final success = await widget.controller.deleteCraving(log);
    if (!mounted) return;
    setState(() => _deleting.remove(log.logId));
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.errorMessage ?? 'Could not delete craving.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Craving History')),
      body: controller.status == TrackStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : controller.status == TrackStatus.error
          ? Center(
              child: TextButton(
                onPressed: () => controller.loadTrack(widget.userId),
                child: Text('${controller.errorMessage} Tap to retry.'),
              ),
            )
          : controller.cravingHistory.isEmpty
          ? const Center(child: Text('No cravings logged yet.'))
          : RefreshIndicator(
              onRefresh: () => controller.loadTrack(widget.userId),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: controller.cravingHistory.length,
                itemBuilder: (context, index) {
                  final log = controller.cravingHistory[index];
                  final date = log.timestamp.toLocal().toString().substring(
                    0,
                    16,
                  );
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${log.triggerCategory.label} • ${log.cravingIntensity}/10',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                key: Key('delete_craving_${log.logId}'),
                                tooltip: 'Delete craving',
                                onPressed: _deleting.contains(log.logId)
                                    ? null
                                    : () => _delete(log),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          Text(
                            '$date • ${log.mood.name} • ${log.riskAssessmentPending ? "assessment pending" : "${log.relapseRiskScore.name} risk"}',
                          ),
                          // UC3: saved on this device, not yet on the server.
                          if (controller.pendingSyncLogIds.contains(log.logId))
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                key: Key('craving_pending_sync_${log.logId}'),
                                children: [
                                  const Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  const Flexible(
                                    child: Text(
                                      'Saved on this device · waiting to sync',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (log.locationContext.isNotEmpty)
                            Text('Location: ${log.locationContext}'),
                          if (log.activity.isNotEmpty)
                            Text('Activity: ${log.activity}'),
                          if (log.notes?.isNotEmpty == true) Text(log.notes!),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
