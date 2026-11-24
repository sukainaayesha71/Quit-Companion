import 'dart:math' as math;

import 'package:flutter/widgets.dart' show IconData;

/// FR13 (SDD §3, = SRDS FR12): "Knowledge Hub educational content."
/// SRDS Module 9 description: "a curated library of educational content
/// about the health effects of nicotine, the science of addiction, and
/// the documented health benefits of quitting at various milestones...
/// sourced from WHO, CDC, and peer-reviewed medical research." No SDD/
/// SRDS entity is ever defined for this content (unlike CravingLog,
/// JournalEntry, etc.) — this is a new, purely presentational model,
/// mirroring HabitAlternative's precedent (Module 7) for a fixed content
/// library with no defined entity shape to inherit.
///
/// Categories (owner decision, 2026-11-23): four reader-facing groups plus
/// Health Risks for the harms-of-continued-use articles.
enum KnowledgeCategory {
  addictionRecovery,
  cravingsRelapse,
  healthWellness,
  motivationLifestyle,
  healthRisks,
}

extension KnowledgeCategoryLabel on KnowledgeCategory {
  String get label => switch (this) {
    KnowledgeCategory.addictionRecovery => 'Addiction & Recovery',
    KnowledgeCategory.cravingsRelapse => 'Cravings & Relapse',
    KnowledgeCategory.healthWellness => 'Health & Wellness',
    KnowledgeCategory.motivationLifestyle => 'Motivation & Lifestyle',
    KnowledgeCategory.healthRisks => 'Health Risks',
  };
}

/// Publisher of an external resource. Only these trusted public-health
/// organisations are linked.
enum ResourceOrganization { who, cdc, nhs, smokefree, nci }

extension ResourceOrganizationLabel on ResourceOrganization {
  String get label => switch (this) {
    ResourceOrganization.who => 'World Health Organization (WHO)',
    ResourceOrganization.cdc =>
      'Centers for Disease Control and Prevention (CDC)',
    ResourceOrganization.nhs => 'NHS',
    ResourceOrganization.smokefree => 'Smokefree.gov',
    ResourceOrganization.nci => 'National Cancer Institute (NCI)',
  };

  /// Every link must be on one of these hosts (checked by tests).
  String get host => switch (this) {
    ResourceOrganization.who => 'www.who.int',
    ResourceOrganization.cdc => 'www.cdc.gov',
    ResourceOrganization.nhs => 'www.nhs.uk',
    ResourceOrganization.smokefree => 'smokefree.gov',
    ResourceOrganization.nci => 'www.cancer.gov',
  };
}

/// An external page from a trusted organisation, shown as "External" in
/// the app and opened in the browser. Each URL was checked to return
/// HTTP 200 directly (no redirect) with a matching page title on
/// 2026-11-23.
class KnowledgeResource {
  final String title;
  final ResourceOrganization organization;
  final String url;

  const KnowledgeResource({
    required this.title,
    required this.organization,
    required this.url,
  });
}

class KnowledgeArticle {
  final String articleId;
  final String title;
  final KnowledgeCategory category;

  /// One-sentence description shown on the article card.
  final String summary;
  final String body;

  /// Path to a bundled real photo/diagram asset (see pubspec.yaml), used
  /// only when a verified public-domain U.S. government source (CDC/NIH/
  /// NIDA) image exists for this topic. Null when no such image could be
  /// verified — [icon] is the fallback in that case (see
  /// knowledge_article_library.dart's per-article sourcing notes).
  final String? imageAssetPath;

  /// Topic-specific fallback icon shown when [imageAssetPath] is null.
  final IconData? icon;

  /// Trusted external pages the article draws on, for further reading.
  final List<KnowledgeResource> resources;

  const KnowledgeArticle({
    required this.articleId,
    required this.title,
    required this.category,
    required this.summary,
    required this.body,
    this.imageAssetPath,
    this.icon,
    this.resources = const [],
  });

  static const wordsPerMinute = 200;

  /// Reading time from the body's length (owner decision, 2026-11-23):
  /// words ÷ 200 per minute, rounded up, at least 1 minute.
  int get readTimeMinutes {
    final words = body.trim().split(RegExp(r'\s+')).length;
    return math.max(1, (words / wordsPerMinute).ceil());
  }

  /// Case-insensitive match against title, summary and body.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        summary.toLowerCase().contains(q) ||
        body.toLowerCase().contains(q);
  }
}
