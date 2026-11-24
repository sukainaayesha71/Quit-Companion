import 'package:material_ui/material_ui.dart' hide Badge;
import 'package:quit_companion/features/rewards/controllers/gamification_controller.dart';
import 'package:quit_companion/features/rewards/presentation/widgets/badge_celebration_dialog.dart';

/// Wraps a screen (Dashboard, Rewards) and shows
/// [BadgeCelebrationDialog] for each badge in the controller's
/// celebration queue, one at a time.
///
/// Rewards is pushed on top of Dashboard, so both listeners can be alive
/// together. Only the listener whose route is on top shows anything, and
/// [GamificationController.takeNextCelebration] removes each badge as it is
/// taken, so no badge is ever celebrated twice.
class BadgeCelebrationListener extends StatefulWidget {
  final GamificationController controller;
  final Widget child;

  const BadgeCelebrationListener({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  State<BadgeCelebrationListener> createState() =>
      _BadgeCelebrationListenerState();
}

class _BadgeCelebrationListenerState extends State<BadgeCelebrationListener> {
  bool _isShowing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scheduleCheck);
    // Picks up badges already waiting when this screen opens, e.g. awarded
    // while another screen was covering the Dashboard.
    _scheduleCheck();
  }

  @override
  void didUpdateWidget(covariant BadgeCelebrationListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scheduleCheck);
      widget.controller.addListener(_scheduleCheck);
      _scheduleCheck();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scheduleCheck);
    super.dispose();
  }

  void _scheduleCheck() {
    if (_isShowing || !widget.controller.hasPendingCelebration) return;
    // notifyListeners can arrive mid-build or mid-route-transition, so the
    // dialog is opened after the current frame. A post-frame callback
    // alone never fires on an idle screen (nothing else repainting), so a
    // frame is explicitly requested too.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showQueued());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool get _isTopRoute => ModalRoute.of(context)?.isCurrent ?? true;

  Future<void> _showQueued() async {
    if (_isShowing || !mounted || !_isTopRoute) return;
    _isShowing = true;
    try {
      while (mounted && widget.controller.hasPendingCelebration) {
        // Everything earned so far goes into one dialog; anything earned
        // while it is open gets its own dialog afterwards.
        final badges = widget.controller.takeAllCelebrations();
        await BadgeCelebrationDialog.showAll(context, badges);
      }
    } finally {
      _isShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
