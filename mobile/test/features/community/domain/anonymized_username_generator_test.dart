import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/community/domain/anonymized_username_generator.dart';

void main() {
  group('generateAnonymizedUsername', () {
    test(
      'is deterministic — the same userId always produces the same handle',
      () {
        final first = generateAnonymizedUsername('user-abc-123');
        final second = generateAnonymizedUsername('user-abc-123');

        expect(first, second);
      },
    );

    test('different userIds usually produce different handles', () {
      final a = generateAnonymizedUsername('user-abc-123');
      final b = generateAnonymizedUsername('completely-different-user');

      expect(a, isNot(b));
    });

    test(
      'never contains the raw userId — genuinely anonymized, not just relabeled',
      () {
        final handle = generateAnonymizedUsername('sukaina.ayesha@example.com');

        expect(handle.toLowerCase(), isNot(contains('sukaina')));
        expect(handle.toLowerCase(), isNot(contains('example')));
      },
    );

    test(
      'matches the approved reference format: a word followed by an underscore and digits',
      () {
        final handle = generateAnonymizedUsername('any-user-id');

        expect(handle, matches(RegExp(r'^[A-Za-z]+_\d+$')));
      },
    );
  });
}
