import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/shared/widgets/action_progress.dart';
import 'package:quit_companion/features/journal/controllers/journal_controller.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/journal/models/journal_entry.dart';

/// FR12 (Module 5): plain-reflection entry creation. No approved UI
/// reference exists for this screen anywhere in docs/UI_Design/ (confirmed
/// — Module 5 plan Open Decision 2), so this reuses the card/typography
/// conventions already established by Modules 2-4 rather than copying any
/// other module's specific mockup.
class AddJournalEntryScreen extends StatefulWidget {
  final String userId;
  final JournalController controller;
  final JournalEntry? entry;

  const AddJournalEntryScreen({
    super.key,
    required this.userId,
    required this.controller,
    this.entry,
  });

  @override
  State<AddJournalEntryScreen> createState() => _AddJournalEntryScreenState();
}

class _AddJournalEntryScreenState extends State<AddJournalEntryScreen> {
  final _textController = TextEditingController();
  bool _showValidationError = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _textController.text = widget.entry?.entryText ?? '';
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    if (_textController.text.trim().isEmpty &&
        widget.entry?.relapseFlag != true) {
      setState(() => _showValidationError = true);
      return;
    }
    setState(() {
      _showValidationError = false;
      _saving = true;
    });
    final entry = widget.entry;
    final success = entry == null
        ? await widget.controller.addEntry(
            userId: widget.userId,
            entryText: _textController.text,
          )
        : await widget.controller.updateEntry(
            userId: widget.userId,
            entry: entry,
            entryText: _textController.text,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal entry saved successfully.')),
      );
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('add_journal_back_button'),
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
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      widget.entry == null
                          ? 'New Journal Entry'
                          : 'Edit Journal Entry',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                key: const Key('add_journal_text_field'),
                controller: _textController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: "What's on your mind today?",
                ),
              ),
              if (_showValidationError) ...[
                const SizedBox(height: 12),
                const Text(
                  'Write something before saving.',
                  key: Key('add_journal_validation_error'),
                  style: TextStyle(color: AppColors.error, fontSize: 14),
                ),
              ],
              const SizedBox(height: 20),
              if (widget.controller.errorMessage != null)
                Text(
                  widget.controller.errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ElevatedButton(
                key: const Key('add_journal_save_button'),
                onPressed: _saving ? null : _handleSave,
                child: _saving
                    ? const ActionProgress('Saving…')
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
