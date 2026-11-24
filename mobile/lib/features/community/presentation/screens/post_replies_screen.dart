import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/community/controllers/community_controller.dart';
import 'package:quit_companion/shared/domain/relative_time_formatter.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:quit_companion/features/community/domain/community_post_validator.dart';

/// SRDS UC8 step 9 ("reply to the post"). No approved mockup exists for
/// this screen either — same "no mockup, build plain" precedent.
class PostRepliesScreen extends StatefulWidget {
  final String userId;
  final String postId;
  final CommunityController controller;

  const PostRepliesScreen({
    super.key,
    required this.userId,
    required this.postId,
    required this.controller,
  });

  @override
  State<PostRepliesScreen> createState() => _PostRepliesScreenState();
}

class _PostRepliesScreenState extends State<PostRepliesScreen> {
  final _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    Future.microtask(() => widget.controller.startReplies(widget.postId));
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.stopReplies();
    _inputController.dispose();
    super.dispose();
  }

  String? _inputError;

  Future<void> _send() async {
    final text = _inputController.text;
    final error = validateCommunityText(text);
    if (error != null) {
      setState(
        () => _inputError = communityTextErrorMessage(
          error,
          isReply: true,
          length: normalizeCommunityText(text).length,
        ),
      );
      return;
    }
    setState(() => _inputError = null);
    final success = await widget.controller.addReply(
      postId: widget.postId,
      userId: widget.userId,
      content: text,
    );
    if (success) _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final replies = widget.controller.repliesForCurrentPost;

    return Scaffold(
      appBar: AppBar(title: const Text('Replies')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: replies.isEmpty
                  ? const Center(
                      child: Text(
                        'No replies yet — be the first to respond.',
                        key: Key('post_replies_empty_state'),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: replies.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final reply = replies[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      reply.anonymizedUsername,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      formatRelativeTime(
                                        reply.timestamp,
                                        now: widget.controller.now(),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                reply.content,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (widget.controller.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.controller.errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('post_replies_input_field'),
                      controller: _inputController,
                      maxLength: communityTextMaxLength,
                      maxLengthEnforcement: MaxLengthEnforcement.none,
                      // Counter appears only near the limit, to keep the
                      // reply bar compact.
                      buildCounter:
                          (
                            context, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => currentLength > communityTextMaxLength * 0.9
                          ? Text(
                              '$currentLength/$communityTextMaxLength',
                              key: const Key('post_replies_counter'),
                            )
                          : null,
                      onChanged: (_) {
                        if (_inputError != null) {
                          setState(() => _inputError = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Write a reply...',
                        errorText: _inputError,
                        errorMaxLines: 3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    key: const Key('post_replies_send_button'),
                    onPressed: _send,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
