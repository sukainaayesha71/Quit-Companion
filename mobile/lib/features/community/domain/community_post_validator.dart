/// FR10 community post/reply validation, shared by the compose screens, the
/// controller and (mirrored) firestore.rules.
///
/// Length: [communityTextMaxLength] = 2000 characters. The SRDS sets no
/// figure for posts; 2000 was chosen by the project owner on 2026-11-23 to
/// match the existing Health-Bot input limit (backend/app/healthbot/
/// router.py `max_length=2000`). It is a technical safety cap, not an SRDS
/// requirement. Counted in UTF-16 code units (Dart `String.length`), which
/// is never less than the character count Firestore rules use, so anything
/// the app accepts also passes the rules.
library;

const communityTextMaxLength = 2000;

enum CommunityTextError { empty, tooLong, invalidCharacters }

// Zero-width / invisible characters that make a post look non-empty while
// showing nothing.
final _invisible = RegExp('[​‌‍⁠﻿]');

// C0 control characters except tab, newline and carriage return, plus DEL.
final _controlCharacters = RegExp(
  '[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]',
);

/// The text as it will be stored before contact-detail redaction: trimmed.
String normalizeCommunityText(String raw) => raw.trim();

CommunityTextError? validateCommunityText(String raw) {
  final text = normalizeCommunityText(raw);
  if (text.replaceAll(_invisible, '').trim().isEmpty) {
    return CommunityTextError.empty;
  }
  if (_controlCharacters.hasMatch(text) || _hasUnpairedSurrogate(text)) {
    return CommunityTextError.invalidCharacters;
  }
  if (text.length > communityTextMaxLength) {
    return CommunityTextError.tooLong;
  }
  return null;
}

String communityTextErrorMessage(
  CommunityTextError error, {
  required bool isReply,
  int? length,
}) {
  final noun = isReply ? 'reply' : 'post';
  return switch (error) {
    CommunityTextError.empty =>
      isReply
          ? 'Write a reply before sending.'
          : 'Write something before posting.',
    CommunityTextError.tooLong =>
      'Your $noun is too long — the limit is $communityTextMaxLength characters'
          '${length == null ? '' : ' (currently $length)'}.',
    CommunityTextError.invalidCharacters =>
      'Your $noun contains characters that can\'t be shared. Remove them and try again.',
  };
}

bool _hasUnpairedSurrogate(String text) {
  final units = text.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (i + 1 < units.length &&
          units[i + 1] >= 0xDC00 &&
          units[i + 1] <= 0xDFFF) {
        i++;
        continue;
      }
      return true;
    }
    if (unit >= 0xDC00 && unit <= 0xDFFF) return true;
  }
  return false;
}
