import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/auth/data/recent_email_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'getRecentEmails returns an empty list when nothing was ever stored',
    () async {
      final store = RecentEmailStore();

      expect(await store.getRecentEmails(), isEmpty);
    },
  );

  test('addRecentEmail persists the email, most recent first', () async {
    final store = RecentEmailStore();

    await store.addRecentEmail('a@b.com');
    await store.addRecentEmail('c@d.com');

    expect(await store.getRecentEmails(), ['c@d.com', 'a@b.com']);
  });

  test(
    'addRecentEmail deduplicates case-insensitively and moves the entry to the front',
    () async {
      final store = RecentEmailStore();

      await store.addRecentEmail('a@b.com');
      await store.addRecentEmail('c@d.com');
      await store.addRecentEmail('A@B.com');

      expect(await store.getRecentEmails(), ['A@B.com', 'c@d.com']);
    },
  );

  test('addRecentEmail caps the list at 5 entries', () async {
    final store = RecentEmailStore();

    for (var i = 0; i < 7; i++) {
      await store.addRecentEmail('user$i@example.com');
    }

    final emails = await store.getRecentEmails();
    expect(emails.length, 5);
    expect(emails.first, 'user6@example.com');
  });

  test('addRecentEmail ignores blank input', () async {
    final store = RecentEmailStore();

    await store.addRecentEmail('   ');

    expect(await store.getRecentEmails(), isEmpty);
  });
}
