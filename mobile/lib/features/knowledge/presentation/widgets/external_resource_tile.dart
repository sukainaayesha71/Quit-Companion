import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/knowledge/models/knowledge_article.dart';

/// A tappable external link: title, organisation and an "External" tag,
/// so it can't be mistaken for an in-app Quit Companion article. Used in
/// the hub's Links view and in article "Learn more" sections.
class ExternalResourceTile extends StatelessWidget {
  final KnowledgeResource resource;
  final VoidCallback onOpen;

  const ExternalResourceTile({
    super.key,
    required this.resource,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          'External link: ${resource.title}, from '
          '${resource.organization.label}. Opens in your browser.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.sageLight),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.public_rounded,
                color: AppColors.sageDark,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          resource.organization.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.sageLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'External',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.sageDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: AppColors.sageDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
