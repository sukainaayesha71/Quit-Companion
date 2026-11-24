import 'package:quit_companion/features/knowledge/models/knowledge_video.dart';

/// FR12 Knowledge Hub educational videos — external links only, nothing
/// is downloaded or embedded.
///
/// Verification (2026-11-23):
/// - YouTube entries: each video id was copied from the official CDC page
///   that embeds it (cdc.gov "Tips For Quitting" page or a Tips From Former
///   Smokers story page), and YouTube's oEmbed API confirmed the video
///   exists, its exact title, and author "Centers for Disease Control and
///   Prevention (CDC)".
/// - Web-page entries: official CDC pages, fetched successfully (HTTP 200),
///   that host the video in their own player.
/// - Descriptions only restate the official title / CDC page caption; they
///   don't claim anything about the video's content beyond that.
///
/// No WHO video is listed: none of the WHO pages checked exposed a video URL
/// that could be verified (the WHO EMRO video page returned HTTP 502). Do
/// not add a video without verifying it the same way — never construct ids.
const knowledgeVideoLibrary = <KnowledgeVideo>[
  // ---- Health benefits of quitting ----
  KnowledgeVideo(
    videoId: 'cdc_benefits_over_time',
    title: 'Benefits of Quitting Over Time',
    description:
        'A short animated CDC video showing the health benefits that build '
        'up after you quit smoking, on CDC\'s Benefits of Quitting page.',
    topic: VideoTopic.healthBenefits,
    url: 'https://www.cdc.gov/tobacco/about/benefits-of-quitting.html',
    sourceName: 'CDC',
    platform: VideoPlatform.webPage,
    verification:
        'Page fetched HTTP 200; hosts cdc-osh-cessation-over-time.mp4, '
        'described by CDC as an "animated video showing the various benefits '
        'of quitting smoking".',
  ),
  KnowledgeVideo(
    videoId: 'cdc_tiffany_surprising_things',
    title: 'Tiffany R.: Surprising Things About Quitting',
    description:
        'A former smoker from CDC\'s Tips From Former Smokers campaign talks '
        'about what surprised her after quitting.',
    topic: VideoTopic.healthBenefits,
    url: 'https://www.youtube.com/watch?v=QmVEbwVA_ck',
    sourceName: 'CDC',
    platform: VideoPlatform.youtube,
    verification:
        'Linked from cdc.gov/tobacco/campaign/tips/stories/tiffany.html; '
        'oEmbed author "Centers for Disease Control and Prevention (CDC)".',
  ),
  KnowledgeVideo(
    videoId: 'cdc_tiffany_not_just_for_yourself',
    title: "Tiffany R.: You Don't Quit Just for Yourself",
    description:
        'A former smoker shares why quitting mattered for the people around '
        'her, not only for herself.',
    topic: VideoTopic.healthBenefits,
    url: 'https://www.youtube.com/watch?v=kyLhO4vGcGY',
    sourceName: 'CDC',
    platform: VideoPlatform.youtube,
    verification:
        'Linked from cdc.gov/tobacco/campaign/tips/stories/tiffany.html; '
        'oEmbed author "Centers for Disease Control and Prevention (CDC)".',
  ),

  // ---- Managing cravings & withdrawal ----
  KnowledgeVideo(
    videoId: 'cdc_cessation_tips',
    title: 'Tips From Former Smokers: Cessation Tips',
    description:
        'Former smokers share their tips for quitting smoking — featured on '
        'CDC\'s Tips For Quitting page alongside advice on distracting '
        'yourself when a craving hits.',
    topic: VideoTopic.cravingsWithdrawal,
    url: 'https://www.youtube.com/watch?v=d6iS44aHy4s',
    sourceName: 'CDC',
    platform: VideoPlatform.youtube,
    verification:
        'Embedded on cdc.gov/tobacco/campaign/tips/quit-smoking/'
        'tips-for-quitting under "Distract yourself"; oEmbed title "CDC: Tips '
        'from Former Smokers - Cessation Tips Ad", author CDC.',
  ),
  KnowledgeVideo(
    videoId: 'cdc_tiffany_how_i_quit',
    title: 'Tiffany R.: How I Quit Smoking',
    description:
        'A former smoker describes how she quit — one person\'s real '
        'experience of getting through it.',
    topic: VideoTopic.cravingsWithdrawal,
    url: 'https://www.youtube.com/watch?v=6OZehKDHsj0',
    sourceName: 'CDC',
    platform: VideoPlatform.youtube,
    verification:
        'Linked from cdc.gov/tobacco/campaign/tips/stories/tiffany.html; '
        'oEmbed author "Centers for Disease Control and Prevention (CDC)".',
  ),

  // ---- Relapse prevention ----
  KnowledgeVideo(
    videoId: 'cdc_james_wont_buy_smokes',
    title: 'James F.: "No, I Won\'t Buy You Smokes"',
    description:
        'A former smoker recalls a moment when he recognized the risk of '
        'going back to smoking and acted to prevent it.',
    topic: VideoTopic.relapsePrevention,
    url: 'https://www.youtube.com/watch?v=_MlDuDWLo0U',
    sourceName: 'CDC',
    platform: VideoPlatform.youtube,
    verification:
        'Embedded on cdc.gov/tobacco/campaign/tips/quit-smoking/'
        'tips-for-quitting; oEmbed author CDC.',
  ),
  KnowledgeVideo(
    videoId: 'cdc_john_dont_quit_quitting',
    title: "John B.: Don't Quit Quitting",
    description:
        'A former smoker\'s tip about not giving up on quitting, on his CDC '
        'Tips From Former Smokers story page.',
    topic: VideoTopic.relapsePrevention,
    url:
        'https://www.cdc.gov/tobacco/campaign/tips/stories/john-b.html#john-videos',
    sourceName: 'CDC',
    platform: VideoPlatform.webPage,
    verification:
        'Story page fetched successfully; hosts "John B.: Don\'t Quit '
        'Quitting Tip" in CDC\'s own player.',
  ),

  // ---- Healthy alternatives & coping ----
  KnowledgeVideo(
    videoId: 'cdc_beatrice_told_everyone',
    title: 'Beatrice R.: "I Told Everyone I Stopped Smoking"',
    description:
        'A former smoker on telling the people around her that she had '
        'quit — leaning on others for support.',
    topic: VideoTopic.copingStrategies,
    url: 'https://www.youtube.com/watch?v=PVuRNZP5igo',
    sourceName: 'CDC',
    platform: VideoPlatform.youtube,
    verification:
        'Embedded on cdc.gov/tobacco/campaign/tips/quit-smoking/'
        'tips-for-quitting; oEmbed author CDC.',
  ),
  KnowledgeVideo(
    videoId: 'cdc_tiffany_decision',
    title: "Tiffany R.'s Decision",
    description:
        'A former smoker talks about her decision to quit — a reminder of '
        'your own reasons when cravings test your resolve.',
    topic: VideoTopic.copingStrategies,
    url: 'https://www.youtube.com/watch?v=26_rxunCRXU',
    sourceName: 'CDC',
    platform: VideoPlatform.youtube,
    verification:
        'Linked from cdc.gov/tobacco/campaign/tips/stories/tiffany.html; '
        'oEmbed author "Centers for Disease Control and Prevention (CDC)".',
  ),
];
