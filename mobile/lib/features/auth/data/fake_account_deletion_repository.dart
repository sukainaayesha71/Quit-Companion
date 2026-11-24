import 'package:quit_companion/features/auth/data/account_deletion_repository.dart';

class FakeAccountDeletionRepository implements AccountDeletionRepository {
  int deleteCount = 0;
  String? errorMessage;

  @override
  Future<void> deleteAccount() async {
    deleteCount++;
    if (errorMessage != null) {
      throw AccountDeletionException(errorMessage!);
    }
  }
}
