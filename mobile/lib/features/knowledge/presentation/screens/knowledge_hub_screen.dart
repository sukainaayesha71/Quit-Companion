import 'package:quit_companion/shared/widgets/responsive_grid.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/knowledge/controllers/knowledge_hub_controller.dart';
import 'package:quit_companion/features/knowledge/models/knowledge_article.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/knowledge/presentation/screens/article_detail_screen.dart';
import 'package:quit_companion/features/knowledge/models/knowledge_video.dart';
import 'package:quit_companion/features/crisis_support/data/helpline_launcher.dart';
import 'package:quit_companion/features/knowledge/presentation/widgets/external_resource_tile.dart';

// Per-category fallback icon, used only if an article somehow has neither
// its own KnowledgeArticle.icon nor an imageAssetPath set — not SDD
// content, so it stays local to this screen (same precedent as
// HighRiskScreen's _uiMeta, Module 7).
IconData _iconFor(KnowledgeCategory category) => switch (category) {
  KnowledgeCategory.addictionRecovery => Icons.psychology_alt_rounded,
  KnowledgeCategory.cravingsRelapse => Icons.flash_on_rounded,
  KnowledgeCategory.healthWellness => Icons.favorite_rounded,
  KnowledgeCategory.motivationLifestyle => Icons.emoji_events_rounded,
  KnowledgeCategory.healthRisks => Icons.warning_amber_rounded,
};

/// Which list the hub shows below the header.
enum _HubView { articles, videos, resources }

/// FR13 (Module 10 — Knowledge Hub & Education, Mehreen's last module).
/// Matches docs/UI_Design/knowledge hub 14.png: title + search icon (now
/// a working article search), a book-stack illustration, category filter
/// chips, and a 2-column article grid (icon, title, summary, "N min read",
/// bookmark indicator). Articles / Videos / Links switch the list; the
/// Links view lists trusted external pages, clearly marked External.
class KnowledgeHubScreen extends StatefulWidget {
  final String userId;
  final KnowledgeHubController controller;

  /// Opens a video link externally (YouTube app or browser); injectable
  /// for tests.
  final Future<bool> Function(String url)? openUrl;

  const KnowledgeHubScreen({
    super.key,
    required this.userId,
    required this.controller,
    this.openUrl,
  });

  @override
  State<KnowledgeHubScreen> createState() => _KnowledgeHubScreenState();
}

class _KnowledgeHubScreenState extends State<KnowledgeHubScreen> {
  _HubView _view = _HubView.articles;
  bool _searchOpen = false;
  final _searchController = TextEditingController();

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

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (_searchOpen) {
        _view = _HubView.articles;
      } else {
        _searchController.clear();
        widget.controller.setQuery('');
      }
    });
  }

  Future<void> _openVideo(KnowledgeVideo video) async {
    final open = widget.openUrl ?? const UrlHelplineLauncher().openWebsite;
    final opened = await open(video.url);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open the video. Check your connection and try again.',
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    Future.microtask(
      () => widget.controller.loadArticles(userId: widget.userId),
    );
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _openArticle(KnowledgeArticle article) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(
          userId: widget.userId,
          article: article,
          controller: widget.controller,
          openUrl: widget.openUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: const Text(
                      'Knowledge Hub',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('knowledge_search_icon'),
                    tooltip: _searchOpen ? 'Close search' : 'Search articles',
                    onPressed: _toggleSearch,
                    icon: Icon(
                      _searchOpen ? Icons.close_rounded : Icons.search,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (_searchOpen) ...[
                const SizedBox(height: 8),
                TextField(
                  key: const Key('knowledge_search_field'),
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: widget.controller.setQuery,
                  decoration: const InputDecoration(
                    hintText: 'Search articles',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                height: 110,
                decoration: BoxDecoration(
                  color: AppColors.sageLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.sageDark,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildContentToggle(),
              const SizedBox(height: 12),
              ...switch (_view) {
                _HubView.videos => [Expanded(child: _buildVideoList())],
                _HubView.resources => [Expanded(child: _buildResourceList())],
                _HubView.articles => [
                  _buildFilterRow(),
                  const SizedBox(height: 12),
                  Expanded(child: _buildGrid()),
                ],
              },
            ],
          ),
        ),
      ),
    );
  }

  /// Switch between the article grid, the video list and the trusted
  /// external links.
  Widget _buildContentToggle() {
    Widget option(String key, String label, IconData icon, _HubView view) {
      final selected = _view == view;
      return Expanded(
        child: ChoiceChip(
          key: Key(key),
          avatar: Icon(
            icon,
            size: 18,
            color: selected ? Colors.white : AppColors.sageDark,
          ),
          label: SizedBox(
            width: double.infinity,
            child: Text(label, textAlign: TextAlign.center),
          ),
          showCheckmark: false,
          selected: selected,
          selectedColor: AppColors.sage,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
          onSelected: (_) => setState(() => _view = view),
        ),
      );
    }

    return Row(
      children: [
        option(
          'knowledge_tab_articles',
          'Articles',
          Icons.menu_book_rounded,
          _HubView.articles,
        ),
        const SizedBox(width: 8),
        option(
          'knowledge_tab_videos',
          'Videos',
          Icons.play_circle_outline_rounded,
          _HubView.videos,
        ),
        const SizedBox(width: 8),
        option(
          'knowledge_tab_resources',
          'Links',
          Icons.public_rounded,
          _HubView.resources,
        ),
      ],
    );
  }

  Widget _buildVideoList() {
    final groups = widget.controller.videosByTopic;
    return ListView(
      key: const Key('knowledge_video_list'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Short videos from trusted public-health sources. They open in '
            'YouTube or your browser and need an internet connection.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              entry.key.label,
              key: Key('knowledge_video_topic_${entry.key.name}'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          for (final video in entry.value)
            _VideoCard(video: video, onOpen: () => _openVideo(video)),
        ],
      ],
    );
  }

  /// Trusted external pages, grouped by organisation and marked External.
  Widget _buildResourceList() {
    final byOrg = <ResourceOrganization, List<KnowledgeResource>>{};
    for (final r in widget.controller.resources) {
      byOrg.putIfAbsent(r.organization, () => []).add(r);
    }
    return ListView(
      key: const Key('knowledge_resource_list'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Trusted external websites from public-health organisations. '
            'They open in your browser and are not part of Quit Companion.',
            key: Key('knowledge_resources_intro'),
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        for (final entry in byOrg.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              entry.key.label,
              key: Key('knowledge_resource_org_${entry.key.name}'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          for (final resource in entry.value)
            ExternalResourceTile(
              resource: resource,
              onOpen: () => _openResource(resource),
            ),
        ],
      ],
    );
  }

  Widget _buildFilterRow() {
    final controller = widget.controller;
    Widget chip(String key, String label, KnowledgeCategory? category) {
      final selected = controller.filter == category;
      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: ChoiceChip(
          key: Key(key),
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => controller.setFilter(category)),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilterChip(
              key: const Key('knowledge_filter_saved'),
              label: const Text('Saved Articles'),
              selected: controller.savedOnly,
              onSelected: controller.setSavedOnly,
            ),
          ),
          chip('knowledge_filter_all', 'All', null),
          for (final category in KnowledgeCategory.values)
            chip('knowledge_filter_${category.name}', category.label, category),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final controller = widget.controller;
    if (controller.status == KnowledgeHubStatus.loading ||
        controller.status == KnowledgeHubStatus.idle) {
      return const Center(
        key: Key('knowledge_loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (controller.status == KnowledgeHubStatus.error) {
      return Center(
        child: Text(
          controller.errorMessage ?? 'Something went wrong.',
          key: const Key('knowledge_error_text'),
          style: const TextStyle(color: AppColors.error, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }
    final articles = controller.filteredArticles;
    if (articles.isEmpty) {
      final searching = controller.query.trim().isNotEmpty;
      return Center(
        child: Text(
          searching
              ? 'No articles match "${controller.query.trim()}".'
              : 'No saved articles in this category yet.',
          key: const Key('knowledge_empty_text'),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ResponsiveGrid(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: articles.length,
      maxColumns: 2,
      minItemWidth: 130,
      fixedExtent: 126,
      fontSize: 14,
      textLines: 6,
      shrinkWrap: false,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final article = articles[index];
        final bookmarked = controller.bookmarkedArticleIds.contains(
          article.articleId,
        );
        final isGreen = index.isEven;
        return InkWell(
          key: Key('knowledge_article_${article.articleId}'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openArticle(article),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 70,
                        width: double.infinity,
                        color: isGreen
                            ? AppColors.sageLight
                            : AppColors.terracottaLight,
                        child: article.imageAssetPath != null
                            ? Image.asset(
                                article.imageAssetPath!,
                                fit: BoxFit.cover,
                              )
                            : Icon(
                                article.icon ?? _iconFor(article.category),
                                color: isGreen
                                    ? AppColors.sageDark
                                    : AppColors.terracottaDark,
                                size: 28,
                              ),
                      ),
                    ),
                    if (bookmarked)
                      Positioned(
                        key: Key(
                          'knowledge_bookmark_${article.articleId}_filled',
                        ),
                        right: 6,
                        top: 6,
                        child: const Icon(
                          Icons.bookmark,
                          size: 18,
                          color: AppColors.terracotta,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  article.summary,
                  key: Key('knowledge_summary_${article.articleId}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${article.readTimeMinutes} min read',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VideoCard extends StatelessWidget {
  final KnowledgeVideo video;
  final VoidCallback onOpen;

  const _VideoCard({required this.video, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final where = video.platform == VideoPlatform.youtube
        ? '${video.sourceName} · YouTube'
        : '${video.sourceName} · Watch on ${video.sourceName.toLowerCase()}.gov';
    return Semantics(
      button: true,
      label:
          'Play video: ${video.title}, from ${video.sourceName}. '
          'Opens outside the app.',
      excludeSemantics: true,
      child: InkWell(
        key: Key('knowledge_video_${video.videoId}'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.terracottaLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.terracottaDark,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.description,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 13,
                          color: AppColors.sageDark,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            where,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.sageDark,
                            ),
                          ),
                        ),
                      ],
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
