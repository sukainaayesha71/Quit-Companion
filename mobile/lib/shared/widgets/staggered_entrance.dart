import 'package:material_ui/material_ui.dart';

/// Shared staggered fade+slide-in transition, used by every screen with a
/// multi-section entrance animation (Dashboard, Track, Profile). [index]
/// controls the stagger offset — section 0 starts immediately, each
/// following section starts 0.1 later in [parent]'s 0..1 timeline, same
/// math DashboardScreen originally used inline.
///
/// Callers own their own `AnimationController` (typically via
/// `SingleTickerProviderStateMixin`) and pass it in as [parent] — this
/// widget only builds the per-child transition, not the controller
/// lifecycle (creation, `forward()` triggering, disposal), which stays the
/// caller's responsibility.
class StaggeredEntrance extends StatelessWidget {
  final int index;
  final Animation<double> parent;
  final Widget child;

  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.parent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.1).clamp(0.0, 0.6);
    final animation = CurvedAnimation(
      parent: parent,
      curve: Interval(
        start,
        (start + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOut,
      ),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}
