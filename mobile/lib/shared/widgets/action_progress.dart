import 'package:material_ui/material_ui.dart';

class ActionProgress extends StatelessWidget {
  final String label;
  const ActionProgress(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text(label),
      ],
    ),
  );
}
