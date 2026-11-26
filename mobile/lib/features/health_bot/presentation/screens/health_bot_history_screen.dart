import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/health_bot/controllers/health_bot_controller.dart';
import 'package:quit_companion/features/health_bot/domain/health_bot_chats.dart';
import 'package:quit_companion/shared/widgets/empty_state_message.dart';

/// Chat History: the signed-in user's saved Health-Bot conversations, most
/// recent first. Tapping one opens it on the Health-Bot screen to read or
/// continue. Only this account's conversations are read (Firestore path
/// nicotineUsers/{uid}/healthBotConversations, owner-only rules).
class HealthBotHistoryScreen extends StatefulWidget {
  final String userId;
  final HealthBotController controller;

  const HealthBotHistoryScreen({
    super.key,
    required this.userId,
    required this.controller,
  });

  @override
  State<HealthBotHistoryScreen> createState() => _HealthBotHistoryScreenState();
}

class _HealthBotHistoryScreenState extends State<HealthBotHistoryScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    Future.microtask(() {
      if (mounted) widget.controller.refreshChats(widget.userId);
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

  Future<void> _open(HealthBotChat chat) async {
    await widget.controller.openChat(widget.userId, chat.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat history')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final controller = widget.controller;
    final chats = controller.chats;
    if (chats.isEmpty && controller.isChatListLoading) {
      return const Center(
        child: CircularProgressIndicator(key: Key('healthbot_history_loading')),
      );
    }
    if (chats.isEmpty && controller.chatListErrorMessage != null) {
      return EmptyStateMessage(
        key: const Key('healthbot_history_error'),
        icon: Icons.cloud_off_outlined,
        title: 'Could not load chat history',
        message: controller.chatListErrorMessage!,
        actionLabel: 'Try again',
        actionKey: const Key('healthbot_history_retry'),
        onAction: () => controller.refreshChats(widget.userId),
        isError: true,
      );
    }
    if (chats.isEmpty) {
      return const EmptyStateMessage(
        key: Key('healthbot_history_empty'),
        icon: Icons.forum_outlined,
        title: 'No conversations yet',
        message:
            'Your chats with Health-Bot will appear here. Ask a question to '
            'start one.',
      );
    }
    return Column(
      children: [
        if (controller.isChatListLoading)
          const LinearProgressIndicator(
            key: Key('healthbot_history_refreshing'),
            minHeight: 2,
          ),
        if (controller.chatListErrorMessage != null)
          TextButton(
            key: const Key('healthbot_history_refresh_error'),
            onPressed: () => controller.refreshChats(widget.userId),
            child: const Text("Couldn't refresh. Tap to try again."),
          ),
        Expanded(
          child: ListView.separated(
            key: const Key('healthbot_history_list'),
            padding: const EdgeInsets.all(16),
            itemCount: chats.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _ChatTile(
              chat: chats[index],
              isOpen: chats[index].id == controller.currentChatId,
              onTap: () => _open(chats[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatTile extends StatelessWidget {
  final HealthBotChat chat;
  final bool isOpen;
  final VoidCallback onTap;

  const _ChatTile({
    required this.chat,
    required this.isOpen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final questions = chat.questionCount == 1
        ? '1 question'
        : '${chat.questionCount} questions';
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('healthbot_history_chat_${chat.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOpen ? AppColors.sage : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.sageLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: AppColors.sageDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatChatDateTime(chat.lastMessageAt)} · $questions',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isOpen)
                Container(
                  key: const Key('healthbot_history_open_badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sageLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Open',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sageDark,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
