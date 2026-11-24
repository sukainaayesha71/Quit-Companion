import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/crisis_support/data/crisis_helplines.dart';
import 'package:quit_companion/features/crisis_support/data/helpline_launcher.dart';

/// SRDS 4.2 Mental Health Safeguards: verified Pakistan and international
/// crisis / emotional-support helplines. Reached from Profile, Health-Bot
/// (app bar and every emergency reply) and the professional-support prompt
/// after repeated high anxiety/sadness ratings.
///
/// Information only: Quit Companion does not contact anyone on the user's
/// behalf, and nothing here is a diagnosis.
class CrisisSupportScreen extends StatelessWidget {
  final HelplineLauncher launcher;
  final List<CrisisHelpline> helplines;

  const CrisisSupportScreen({
    super.key,
    this.launcher = const UrlHelplineLauncher(),
    this.helplines = crisisHelplines,
  });

  static Route<void> route({HelplineLauncher? launcher}) {
    return MaterialPageRoute<void>(
      builder: (_) => CrisisSupportScreen(
        launcher: launcher ?? const UrlHelplineLauncher(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pakistan = helplines
        .where((h) => h.region == HelplineRegion.pakistan)
        .toList();
    final international = helplines
        .where((h) => h.region == HelplineRegion.international)
        .toList();

    return Scaffold(
      key: const Key('crisis_support_screen'),
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Crisis Support')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const _IntroCard(),
            const SizedBox(height: 16),
            const _EmergencyNotice(),
            const SizedBox(height: 24),
            const _SectionTitle('Pakistan'),
            for (final helpline in pakistan)
              _HelplineCard(helpline: helpline, launcher: launcher),
            const SizedBox(height: 12),
            const _SectionTitle('Outside Pakistan'),
            for (final helpline in international)
              _HelplineCard(helpline: helpline, launcher: launcher),
            const SizedBox(height: 16),
            const Text(
              'Helpline details were checked against each organization\'s '
              'own website or a recognized helpline directory in November '
              '2026. Services can change their hours or numbers. Quit '
              'Companion is not a crisis service and does not contact '
              'anyone for you.',
              key: Key('crisis_support_footer'),
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.sageLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.favorite_rounded, color: AppColors.sageDark, size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You don't have to go through this alone",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Quitting nicotine can bring up difficult feelings. '
                  'Talking to a trained counsellor can help, whether you '
                  'are struggling right now or just need someone to listen.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyNotice extends StatelessWidget {
  const _EmergencyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('crisis_support_emergency_notice'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.terracottaLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.terracotta.withValues(alpha: 0.4)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.emergency_rounded,
            color: AppColors.terracottaDark,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'If you are thinking about harming yourself, or anyone is in '
              'immediate danger, call Rescue 1122 in Pakistan or your local '
              'emergency number now.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _HelplineCard extends StatelessWidget {
  final CrisisHelpline helpline;
  final HelplineLauncher launcher;

  const _HelplineCard({required this.helpline, required this.launcher});

  Future<void> _call(BuildContext context) async {
    final number = helpline.dialNumber!;
    final ok = await launcher.call(number);
    if (!ok && context.mounted) await _copyFallback(context);
  }

  Future<void> _text(BuildContext context) async {
    final ok = await launcher.text(helpline.dialNumber!);
    if (!ok && context.mounted) await _copyFallback(context);
  }

  Future<void> _openWebsite(BuildContext context) async {
    final ok = await launcher.openWebsite(helpline.website!);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${helpline.website}')),
      );
    }
  }

  Future<void> _copyFallback(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: helpline.displayNumber!));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not open your phone app. ${helpline.displayNumber} was '
          'copied so you can dial it.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = helpline.isEmergency
        ? AppColors.terracottaDark
        : AppColors.sageDark;

    return Container(
      key: Key('crisis_helpline_${helpline.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            helpline.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (helpline.displayNumber != null) ...[
            const SizedBox(height: 4),
            SelectableText(
              helpline.displayNumber!,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            helpline.description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  helpline.hours,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (helpline.dialNumber != null)
                FilledButton.icon(
                  key: Key('crisis_call_${helpline.id}'),
                  onPressed: () => _call(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: helpline.isEmergency
                        ? AppColors.terracotta
                        : AppColors.sage,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: Text('Call ${helpline.displayNumber}'),
                ),
              if (helpline.supportsText && helpline.dialNumber != null)
                OutlinedButton.icon(
                  key: Key('crisis_text_${helpline.id}'),
                  onPressed: () => _text(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.sms_outlined, size: 18),
                  label: const Text('Text'),
                ),
              if (helpline.website != null)
                OutlinedButton.icon(
                  key: Key('crisis_web_${helpline.id}'),
                  onPressed: () => _openWebsite(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Website'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
