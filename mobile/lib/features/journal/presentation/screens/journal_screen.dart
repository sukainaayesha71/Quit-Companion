import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/shared/widgets/action_progress.dart';
import 'package:quit_companion/features/journal/controllers/journal_controller.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/journal/presentation/screens/add_journal_entry_screen.dart';
import 'package:quit_companion/features/journal/models/journal_entry.dart';

const _monthAbbrev = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';

/// FR12 (Module 5): "My Journal" — matches the approved reference,
/// docs/UI_Design/journal reflection 13.png: title + "+" add button,
/// decorative illustration, reverse-chronological entry list with a date
/// badge and a flag icon on relapse-flagged entries (same JournalEntry,
/// not a separate view — Module 5 plan Open Decision 1).
class JournalScreen extends StatefulWidget {
  final String userId;
  final JournalController controller;

  const JournalScreen({
    super.key,
    required this.userId,
    required this.controller,
  });

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    Future.microtask(() => widget.controller.loadEntries(widget.userId));
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  Future<void> _openAddEntry() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddJournalEntryScreen(
          userId: widget.userId,
          controller: widget.controller,
        ),
      ),
    );
  }

  Future<void> _editEntry(JournalEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddJournalEntryScreen(
          userId: widget.userId,
          controller: widget.controller,
          entry: entry,
        ),
      ),
    );
  }

  Future<void> _deleteEntry(JournalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete journal entry?'),
        content: Text(
          entry.relapseFlag
              ? 'This deletes the relapse entry and recalculates your nicotine-free streak from the remaining history.'
              : 'This permanently deletes this journal entry.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('journal_confirm_delete'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(days: 1),
        content: ActionProgress('Deleting journal entry…'),
      ),
    );
    final success = await widget.controller.deleteEntry(
      userId: widget.userId,
      entry: entry,
    );
    if (messenger.mounted) messenger.removeCurrentSnackBar();
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Journal entry deleted successfully.'
                : widget.controller.errorMessage ?? 'Could not delete entry.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: const Text(
                      'My Journal',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('journal_add_button'),
                    onPressed: _openAddEntry,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.sageLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.sageDark,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(child: _buildBody(controller)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(JournalController controller) {
    if (controller.status == JournalStatus.loading ||
        controller.status == JournalStatus.idle) {
      return const Center(
        key: Key('journal_loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (controller.status == JournalStatus.error) {
      return Center(
        child: Text(
          controller.errorMessage ?? 'Something went wrong.',
          key: const Key('journal_error_text'),
          style: const TextStyle(color: AppColors.error, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (controller.entries.isEmpty) {
      return const Center(
        child: Text(
          'No entries yet — tap + to write your first one.',
          key: Key('journal_empty_state'),
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      itemCount: controller.entries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = controller.entries[index];
        return Container(
          key: Key('journal_entry_$index'),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatDate(entry.entryDate),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (entry.relapseFlag)
                    const Icon(
                      Icons.flag,
                      color: AppColors.terracotta,
                      size: 18,
                    ),
                  PopupMenuButton<String>(
                    key: Key('journal_actions_${entry.entryId}'),
                    enabled: !controller.isMutating,
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editEntry(entry);
                      } else if (value == 'delete') {
                        _deleteEntry(entry);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              if (entry.entryText != null) ...[
                const SizedBox(height: 10),
                Text(
                  entry.entryText!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
