import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/crisis_support/presentation/screens/crisis_support_screen.dart';
import 'package:quit_companion/features/health_bot/controllers/health_bot_controller.dart';
import 'package:quit_companion/features/health_bot/models/health_bot_message.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/crisis_support/data/helpline_launcher.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';

const _suggestedChips = [
  ('healthbot_chip_irritable', 'Why do I feel so irritable?'),
  ('healthbot_chip_sleep', "Why can't I sleep?"),
  ('healthbot_chip_normal', 'Is this normal?'),
  ('healthbot_chip_anxious', 'Why am I so anxious?'),
];

/// FR8 (Module 6 — Mehreen's Health-Bot, see Module 6 plan Open Decision 0):
/// matches docs/UI_Design/8 healthbot.png — title + "AI" chip, disclaimer
/// banner, chat transcript (user/bot/emergency bubble styles per Open
/// Decision 2), suggested-question chip row, text input + send button.
class HealthBotScreen extends StatefulWidget {
  final String userId;
  final HealthBotController controller;

  /// Opens an FR8 source link in the browser; injectable for tests.
  final Future<bool> Function(String url)? openUrl;

  const HealthBotScreen({
    super.key,
    required this.userId,
    required this.controller,
    this.openUrl,
  });

  @override
  State<HealthBotScreen> createState() => _HealthBotScreenState();
}

class _HealthBotScreenState extends State<HealthBotScreen> {
  final _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.controller.disclaimerAcknowledged = false;
    Future.microtask(() => widget.controller.loadHistory(widget.userId));
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _inputController.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty ||
        widget.controller.isHistoryLoading ||
        widget.controller.status == HealthBotStatus.sending) {
      return;
    }
    widget.controller.sendQuery(userId: widget.userId, text: text);
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: const Text('Health-Bot')),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.sageLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'AI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.sageDark,
                ),
              ),
            ),
          ],
        ),
        // SRDS 4.2: always reachable, including before the disclaimer is
        // acknowledged — someone in distress shouldn't have to accept terms
        // first to see a helpline.
        actions: [
          IconButton(
            key: const Key('healthbot_crisis_support_button'),
            tooltip: 'Crisis support',
            onPressed: _openCrisisSupport,
            icon: const Icon(Icons.support_agent_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!controller.disclaimerAcknowledged)
              Expanded(child: _buildDisclaimer())
            else ...[
              Expanded(child: _buildTranscript(controller)),
              _buildChips(),
              _buildInputBar(controller),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            key: const Key('healthbot_disclaimer_banner'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.terracottaLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.terracottaDark,
                  size: 28,
                ),
                SizedBox(height: 10),
                Text(
                  'Not a substitute for medical advice.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Health-Bot uses AI to provide general nicotine-cessation information. '
                  'It can make mistakes and cannot diagnose or replace a clinician. '
                  'Your messages are sent to Google Gemini and saved in your account history; '
                  'avoid sharing identifying or highly sensitive details.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            key: const Key('healthbot_disclaimer_acknowledge_button'),
            onPressed: () => widget.controller.acknowledgeDisclaimer(),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscript(HealthBotController controller) {
    if (controller.isHistoryLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.historyErrorMessage != null) {
      return Center(
        child: TextButton(
          onPressed: () => controller.loadHistory(widget.userId),
          child: Text('${controller.historyErrorMessage} Tap to retry.'),
        ),
      );
    }
    if (controller.transcript.isEmpty) {
      return const Center(
        child: Text(
          'Ask about withdrawal symptoms like headaches, sleep, or irritability.',
          key: Key('healthbot_empty_state'),
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      );
    }
    final isTyping = controller.status == HealthBotStatus.sending;
    return ListView.builder(
      key: const Key('healthbot_transcript'),
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: controller.transcript.length + (isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (isTyping && index == 0) return const _TypingIndicator();
        final messageIndex =
            controller.transcript.length - 1 - index + (isTyping ? 1 : 0);
        return _buildBubble(controller.transcript[messageIndex], messageIndex);
      },
    );
  }

  void _openCrisisSupport() {
    Navigator.of(context).push(CrisisSupportScreen.route());
  }

  Widget _buildBubble(HealthBotMessage message, int index) {
    final isUser = message.sender == HealthBotSender.user;
    final bubbleColor = message.isEmergency
        ? AppColors.error.withValues(alpha: 0.12)
        : isUser
        ? AppColors.terracotta
        : AppColors.surface;
    final textColor = message.isEmergency
        ? AppColors.error
        : isUser
        ? Colors.white
        : AppColors.textPrimary;

    final showSources =
        !isUser && !message.isEmergency && message.sources.isNotEmpty;
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(18),
        border: message.isEmergency
            ? Border.all(color: AppColors.error, width: 1.5)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.isEmergency)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isUser
                      ? message.text
                      : message.text
                            .split(RegExp(r'\n\s*Sources:\s*\n'))
                            .first
                            .trimRight(),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14.5,
                    height: 1.4,
                  ),
                ),
                // Honest origin label for non-AI replies (curated library
                // or offline guidance), shown after the answer itself.
                if (!isUser && message.note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      message.note!,
                      key: Key('healthbot_note_$index'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        height: 1.3,
                      ),
                    ),
                  ),
                if (!isUser && message.retryQuery != null)
                  TextButton.icon(
                    key: Key('healthbot_retry_$index'),
                    onPressed: () => _send(message.retryQuery!),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.terracotta,
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try again'),
                  ),
                // SRDS 4.2: the existing emergency referral text is kept
                // as-is; this adds a direct route to verified helplines.
                if (message.isEmergency)
                  TextButton.icon(
                    key: Key('healthbot_emergency_crisis_support_$index'),
                    onPressed: _openCrisisSupport,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: const Text('Get crisis support'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return Align(
      key: Key(
        'healthbot_message_$index${message.isEmergency ? '_emergency' : ''}',
      ),
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: showSources
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                bubble,
                _SourceLinks(
                  key: Key('healthbot_sources_$index'),
                  sources: message.sources,
                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                  onOpen: _openSource,
                ),
              ],
            )
          : bubble,
    );
  }

  Future<void> _openSource(HealthBotSource source) async {
    final open = widget.openUrl ?? const UrlHelplineLauncher().openWebsite;
    final opened = await open(source.url);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open ${source.url}')));
    }
  }

  Widget _buildChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestedChips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (key, label) = _suggestedChips[index];
          return ActionChip(
            key: Key(key),
            label: Text(label),
            backgroundColor: AppColors.sageLight,
            onPressed: () => _send(label),
          );
        },
      ),
    );
  }

  Widget _buildInputBar(HealthBotController controller) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('healthbot_input_field'),
              controller: _inputController,
              decoration: const InputDecoration(hintText: 'Type a message...'),
              onSubmitted: _send,
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            key: const Key('healthbot_send_button'),
            onPressed:
                controller.status == HealthBotStatus.sending ||
                    controller.isHistoryLoading
                ? null
                : () => _send(_inputController.text),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.terracotta,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
    } else {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    key: const Key('healthbot_typing_indicator'),
    alignment: Alignment.centerLeft,
    child: Semantics(
      label: 'Health-Bot is typing',
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final phase = (_animation.value + index / 3) % 1;
              final pulse = 1 - (phase * 2 - 1).abs();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Transform.translate(
                  offset: Offset(0, -4 * pulse),
                  child: Opacity(
                    opacity: .35 + .65 * pulse,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.sageDark,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    ),
  );
}

/// FR8: "Sources" list under a bot reply — trusted public-health pages for
/// the question's topic. Tapping opens the page in the browser.
class _SourceLinks extends StatelessWidget {
  final List<HealthBotSource> sources;
  final double maxWidth;
  final ValueChanged<HealthBotSource> onOpen;

  const _SourceLinks({
    super.key,
    required this.sources,
    required this.maxWidth,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sources',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            for (final (i, source) in sources.indexed)
              InkWell(
                key: Key('healthbot_source_link_$i'),
                onTap: () => onOpen(source),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.open_in_new_rounded,
                          size: 13,
                          color: AppColors.sageDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          source.title,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.sageDark,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.sageDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
