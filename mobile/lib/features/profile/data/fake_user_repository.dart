import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/profile/data/user_repository.dart';

class FakeUserRepository implements UserRepository {
  final Map<String, NicotineUser> _store = {};

  @override
  Future<void> saveUser(NicotineUser user) async {
    _store[user.userId] = user;
  }

  @override
  Future<NicotineUser?> getUser(String userId) async {
    return _store[userId];
  }
}
