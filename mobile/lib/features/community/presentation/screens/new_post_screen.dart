import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/shared/widgets/action_progress.dart';
import 'package:quit_companion/features/community/controllers/community_controller.dart';
import 'package:quit_companion/features/community/models/post_category.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:quit_companion/features/community/domain/community_post_validator.dart';

/// SRDS UC8 steps 3-6 ("New Post" -> type message -> optionally select a
/// category -> "Post"). No approved mockup exists for the compose screen
/// itself (only the feed, docs/UI_Design/community 10.png) — same
/// documented "no mockup, build plain" precedent as every prior module's
/// unreferenced compose/detail screen.
class NewPostScreen extends StatefulWidget {
  final String userId;
  final CommunityController controller;

  const NewPostScreen({
    super.key,
    required this.userId,
    required this.controller,
  });

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final _contentController = TextEditingController();
  PostCategory? _category;
  bool _showValidationError = false;
  bool _saving = false;
  String? _contentError;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final error = validateCommunityText(_contentController.text);
    final contentError = error == null
        ? null
        : communityTextErrorMessage(
            error,
            isReply: false,
            length: normalizeCommunityText(_contentController.text).length,
          );
    if (contentError != null || _category == null) {
      setState(() {
        _contentError = contentError;
        _showValidationError = _category == null;
      });
      return;
    }
    setState(() {
      _contentError = null;
      _showValidationError = false;
      _saving = true;
    });
    final success = await widget.controller.createPost(
      userId: widget.userId,
      content: _contentController.text,
      category: _category!,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post saved successfully.')));
      Navigator.of(context).pop();
    } else if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Post')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('new_post_content_field'),
                controller: _contentController,
                maxLines: 5,
                // Counter only — never truncate typed or pasted text
                // silently; an over-long post gets a clear message instead.
                maxLength: communityTextMaxLength,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                onChanged: (_) {
                  if (_contentError != null) {
                    setState(() => _contentError = null);
                  }
                },
                decoration: InputDecoration(
                  hintText:
                      'Share your experience, tip, question, or encouragement...',
                  errorText: _contentError,
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Category',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final category in PostCategory.values)
                    ChoiceChip(
                      key: Key('new_post_category_${category.name}'),
                      label: Text(category.label),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                ],
              ),
              if (_showValidationError) ...[
                const SizedBox(height: 10),
                const Text(
                  'Choose a category before posting.',
                  key: Key('new_post_validation_error'),
                  style: TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              if (widget.controller.errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  widget.controller.errorMessage!,
                  key: const Key('new_post_error_text'),
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                key: const Key('new_post_submit_button'),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const ActionProgress('Saving…')
                    : const Text('Post'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
