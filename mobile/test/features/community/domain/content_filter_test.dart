import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/community/domain/content_filter.dart';

void main() {
  group('isContentAllowed', () {
    test('allows ordinary supportive/motivational text', () {
      expect(
        isContentAllowed('Day 15 nicotine-free! Still going strong.'),
        isTrue,
      );
    });

    test('blocks text containing a banned term, case-insensitively', () {
      expect(isContentAllowed('You are such an idiot for relapsing'), isFalse);
    });

    test(
      'blocks text containing a banned term regardless of surrounding punctuation',
      () {
        expect(isContentAllowed('IDIOT!!! why would you do that'), isFalse);
      },
    );

    test('blank content is not allowed (nothing to post)', () {
      expect(isContentAllowed('   '), isFalse);
    });
  });
}
