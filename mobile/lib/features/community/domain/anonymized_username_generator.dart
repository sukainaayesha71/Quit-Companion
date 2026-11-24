const _handleWords = [
  'QuitWarrior',
  'FreshStart',
  'BraveSoul',
  'CleanSlate',
  'NewDawn',
  'SteadyHeart',
  'CalmMind',
  'StrongWill',
  'QuietWin',
  'ClearSky',
];

/// SRDS UC8 step 7: "saves the post to Firebase with timestamp and
/// anonymized username." No community-profile entity exists anywhere in
/// the SDD/SRDS, so there is nothing to read a real handle from — this
/// deterministically derives a stable, non-reversible-looking pseudonym
/// from [userId] using a simple string hash, so the same user always
/// posts under the same handle (matching the approved reference,
/// docs/UI_Design/community 10.png, which shows one repeated username
/// across multiple posts from the same person) without ever storing or
/// exposing the real userId/email in the public feed.
String generateAnonymizedUsername(String userId) {
  var hash = 0;
  for (final codeUnit in userId.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }
  final word = _handleWords[hash % _handleWords.length];
  final suffix = (hash ~/ _handleWords.length) % 100;
  return '${word}_$suffix';
}
