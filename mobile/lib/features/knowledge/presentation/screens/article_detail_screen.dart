import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/knowledge/controllers/knowledge_hub_controller.dart';
import 'package:quit_companion/features/knowledge/models/knowledge_article.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/crisis_support/data/helpline_launcher.dart';
import 'package:quit_companion/features/knowledge/presentation/widgets/external_resource_tile.dart';

/// FR13 article-reading destination. No approved mockup exists for this
/// screen — only the list view (docs/UI_Design/knowledge hub 14.png) —
/// same "no mockup, build plain" precedent as every prior module's
/// unreferenced detail/compose screen. Below the article: trusted external
/// "Learn more" links (marked External) and a medical disclaimer.
class ArticleDetailScreen extends StatefulWidget {
  final String userId;
  final KnowledgeArticle article;
  final KnowledgeHubController controller;

  /// Opens an external link in the browser; injectable for tests.
  final Future<bool> Function(String url)? openUrl;

  const ArticleDetailScreen({
    super.key,
    required this.userId,
    required this.article,
    required this.controller,
    this.openUrl,
  });

  /// Shown under every article.
  static const medicalDisclaimer =
      'This article is general information to support your quit journey. '
      'It is not medical advice and does not replace a doctor, pharmacist '
      'or other qualified health professional. Talk to one about symptoms '
      'that are severe or worrying, or before starting or changing any '
      'medicine. In an emergency, contact your local emergency services.';

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openResource(KnowledgeResource resource) async {
    final open = widget.openUrl ?? const UrlHelplineLauncher().openWebsite;
    final opened = await open(resource.url);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the page. Check your connection and try again.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final bookmarked = widget.controller.bookmarkedArticleIds.contains(
      article.articleId,
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    key: const Key('article_detail_back_button'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.sageLight,
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    key: const Key('article_detail_bookmark_button'),
                    onPressed: () => widget.controller.toggleBookmark(
                      userId: widget.userId,
                      articleId: article.articleId,
                    ),
                    icon: Icon(
                      bookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: AppColors.terracotta,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  key: const Key('article_detail_visual'),
                  height: 180,
                  width: double.infinity,
                  color: AppColors.sageLight,
                  child: article.imageAssetPath != null
                      ? Image.asset(article.imageAssetPath!, fit: BoxFit.cover)
                      : Icon(
                          article.icon ?? Icons.menu_book_rounded,
                          color: AppColors.sageDark,
                          size: 56,
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                article.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${article.category.label} · ${article.readTimeMinutes} min read',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                article.summary,
                key: const Key('article_detail_summary'),
                style: const TextStyle(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                article.body,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              ),
              if (article.resources.isNotEmpty) ...[
                const SizedBox(height: 28),
                const Text(
                  'Learn more from trusted sources',
                  key: Key('article_detail_resources_heading'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'External websites. They open in your browser and are not '
                  'part of Quit Companion.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                for (final (i, resource) in article.resources.indexed)
                  KeyedSubtree(
                    key: Key('article_resource_$i'),
                    child: ExternalResourceTile(
                      resource: resource,
                      onOpen: () => _openResource(resource),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              Container(
                key: const Key('article_detail_disclaimer'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.sageLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.sageDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ArticleDetailScreen.medicalDisclaimer,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
