String redactContactDetails(String text, {String? displayName}) {
  var result = text.replaceAll(
    RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
    '[email removed]',
  );
  result = result.replaceAll(
    RegExp(r'\+?\d[\d\s().-]{7,}\d'),
    '[phone removed]',
  );
  final name = displayName?.trim();
  if (name != null && name.length > 2) {
    result = result.replaceAll(
      RegExp('\\b${RegExp.escape(name)}\\b', caseSensitive: false),
      '[name removed]',
    );
  }
  return result;
}
