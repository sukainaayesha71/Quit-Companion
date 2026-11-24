/// SRDS UC8's alternative flow: "If post content is flagged as
/// inappropriate by the content filter, the post is blocked and the user
/// is notified." No content-moderation ML/service exists anywhere in this
/// project — consistent with every other "AI" feature in this codebase
/// (FR5's relapse rules, FR7's alternative matcher, FR8's Health-Bot),
/// this is a deterministic, fixed keyword list, not a trained classifier.
/// Deliberately small and generic (not a comprehensive profanity list,
/// which is out of scope for an FYP) — flagged as a real, documented
/// scope limitation, not presented as production-grade moderation.
const _bannedTerms = [
  'idiot',
  'stupid',
  'shut up',
  'kill yourself',
  'hate you',
];

bool isContentAllowed(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) return false;
  final lowered = trimmed.toLowerCase();
  return !_bannedTerms.any((term) => lowered.contains(term));
}
