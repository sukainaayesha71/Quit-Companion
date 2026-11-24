/// FR12 (SRDS) / FR13 (SDD) Knowledge Hub educational videos. Like
/// KnowledgeArticle, a purely presentational model for a fixed, pre-vetted
/// library — no SDD/SRDS entity exists for this content.
enum VideoTopic {
  healthBenefits,
  cravingsWithdrawal,
  relapsePrevention,
  copingStrategies,
}

extension VideoTopicLabel on VideoTopic {
  String get label => switch (this) {
    VideoTopic.healthBenefits => 'Health benefits of quitting',
    VideoTopic.cravingsWithdrawal => 'Managing cravings & withdrawal',
    VideoTopic.relapsePrevention => 'Relapse prevention',
    VideoTopic.copingStrategies => 'Healthy alternatives & coping',
  };
}

/// Where the link opens: a YouTube video (opens the YouTube app when
/// installed, otherwise the browser), or an official web page that hosts
/// the video in its own player.
enum VideoPlatform { youtube, webPage }

class KnowledgeVideo {
  final String videoId;
  final String title;
  final String description;
  final VideoTopic topic;
  final String url;

  /// Publisher shown to the user, e.g. "CDC".
  final String sourceName;
  final VideoPlatform platform;

  /// How the link was verified (audit only, not shown).
  final String verification;

  const KnowledgeVideo({
    required this.videoId,
    required this.title,
    required this.description,
    required this.topic,
    required this.url,
    required this.sourceName,
    required this.platform,
    required this.verification,
  });
}
