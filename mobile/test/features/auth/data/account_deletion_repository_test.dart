import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quit_companion/features/auth/data/account_deletion_repository.dart';

void main() {
  test(
    'sends an authenticated DELETE request to the account endpoint',
    () async {
      http.Request? capturedRequest;
      final repository = HttpAccountDeletionRepository(
        baseUrl: 'https://api.example.test',
        getIdToken: () async => 'firebase-id-token',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response('', 204);
        }),
      );

      await repository.deleteAccount();

      expect(capturedRequest?.method, 'DELETE');
      expect(capturedRequest?.url.path, '/account');
      expect(
        capturedRequest?.headers['Authorization'],
        'Bearer firebase-id-token',
      );
    },
  );

  test('surfaces a server deletion failure', () async {
    final repository = HttpAccountDeletionRepository(
      baseUrl: 'https://api.example.test',
      getIdToken: () async => 'firebase-id-token',
      httpClient: MockClient(
        (_) async => http.Response(
          '{"detail":"Account deletion is not configured."}',
          503,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      repository.deleteAccount(),
      throwsA(
        isA<AccountDeletionException>().having(
          (error) => error.message,
          'message',
          'Account deletion is not configured.',
        ),
      ),
    );
  });
}
