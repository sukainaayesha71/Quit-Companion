import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/shared/widgets/action_progress.dart';
import 'package:quit_companion/features/community/controllers/community_controller.dart';
import 'package:quit_companion/shared/domain/relative_time_formatter.dart';
import 'package:quit_companion/features/community/models/community_post.dart';
import 'package:quit_companion/features/community/models/post_category.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/community/presentation/screens/new_post_screen.dart';
import 'package:quit_companion/features/community/presentation/screens/post_replies_screen.dart';

/// FR11 (Module 9 — Community & Peer Support, Mehreen's module). Matches
/// docs/UI_Design/community 10.png: header illustration, "Community"
/// title + search icon (decorative — no search feature is built, same
/// "visually present but non-functional decorative element" precedent as
/// Register's Google button/Forgot-Password link), filter chip row
/// (All/Tips/Milestones/Questions/Motivation), the post feed, and a
/// floating "+" New Post button.
class CommunityScreen extends StatefulWidget {
  final String userId;
  final CommunityController controller;

  const CommunityScreen({
    super.key,
    required this.userId,
    required this.controller,
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    Future.microtask(() => widget.controller.startFeed(userId: widget.userId));
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.stopFeed();
    super.dispose();
  }

  Future<void> _openNewPost() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            NewPostScreen(userId: widget.userId, controller: widget.controller),
      ),
    );
  }

  Future<void> _openReplies(String postId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostRepliesScreen(
          userId: widget.userId,
          postId: postId,
          controller: widget.controller,
        ),
      ),
    );
  }

  Future<void> _deletePost(CommunityPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your post?'),
        content: const Text(
          'This permanently deletes your post and its replies and likes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('community_confirm_delete'),
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
        content: ActionProgress('Deleting post…'),
      ),
    );
    final success = await widget.controller.deletePost(
      postId: post.postId,
      userId: widget.userId,
    );
    if (messenger.mounted) messenger.removeCurrentSnackBar();
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Post deleted successfully.'
                : widget.controller.errorMessage ?? 'Could not delete post.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.sageLight,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.groups_rounded,
                        color: AppColors.sageDark,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: const Text(
                          'Community',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.search,
                        key: Key('community_search_icon'),
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildFilterRow(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildFeed()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('community_new_post_button'),
        backgroundColor: AppColors.terracotta,
        onPressed: _openNewPost,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterRow() {
    final controller = widget.controller;
    Widget chip(String key, String label, PostCategory? category) {
      final selected = controller.filter == category;
      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: ChoiceChip(
          key: Key(key),
          label: Text(label),
          selected: selected,
          onSelected: (_) =>
              controller.setFilter(userId: widget.userId, category: category),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('community_filter_all', 'All', null),
          chip('community_filter_tip', 'Tips', PostCategory.tip),
          chip(
            'community_filter_milestone',
            'Milestones',
            PostCategory.milestone,
          ),
          chip('community_filter_question', 'Questions', PostCategory.question),
          chip(
            'community_filter_motivation',
            'Motivation',
            PostCategory.motivation,
          ),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    final controller = widget.controller;
    if (controller.status == CommunityStatus.loading ||
        controller.status == CommunityStatus.idle) {
      return const Center(
        key: Key('community_loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (controller.status == CommunityStatus.error) {
      return Center(
        child: Text(
          controller.errorMessage ?? 'Something went wrong.',
          key: const Key('community_error_text'),
          style: const TextStyle(color: AppColors.error, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (controller.posts.isEmpty) {
      return const Center(
        child: Text(
          'No posts yet — be the first to share something.',
          key: Key('community_empty_state'),
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
      itemCount: controller.posts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) => _PostCard(
        post: controller.posts[index],
        liked: controller.likedPostIds.contains(controller.posts[index].postId),
        now: controller.now(),
        onLikeTap: () => controller.toggleLike(
          postId: controller.posts[index].postId,
          userId: widget.userId,
        ),
        onReplyTap: () => _openReplies(controller.posts[index].postId),
        onDeleteTap:
            controller.posts[index].userId == widget.userId &&
                !controller.deletingPostIds.contains(
                  controller.posts[index].postId,
                )
            ? () => _deletePost(controller.posts[index])
            : null,
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final CommunityPost post;
  final bool liked;
  final DateTime now;
  final VoidCallback onLikeTap;
  final VoidCallback onReplyTap;
  final VoidCallback? onDeleteTap;

  const _PostCard({
    required this.post,
    required this.liked,
    required this.now,
    required this.onLikeTap,
    required this.onReplyTap,
    this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('community_post_${post.postId}'),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.sageLight,
                child: Icon(Icons.person, size: 18, color: AppColors.sageDark),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  post.anonymizedUsername,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.sageLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  post.category.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.sageDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  formatRelativeTime(post.timestamp, now: now),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.content,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              InkWell(
                key: Key('community_like_${post.postId}'),
                onTap: onLikeTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: AppColors.terracotta,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${post.likeCount}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              InkWell(
                key: Key('community_reply_${post.postId}'),
                onTap: onReplyTap,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (onDeleteTap != null) ...[
                const Spacer(),
                IconButton(
                  key: Key('community_delete_${post.postId}'),
                  tooltip: 'Delete your post',
                  onPressed: onDeleteTap,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.error,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
