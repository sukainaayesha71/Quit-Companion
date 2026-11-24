import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      backgroundColor: AppColors.background,
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quit Companion',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8),
              Text(
                'Version 1.0.0',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              SizedBox(height: 16),
              Text(
                'Quit Companion helps you track cravings, follow a personalized quit plan, and celebrate your '
                'nicotine-free milestones — one day at a time.',
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
