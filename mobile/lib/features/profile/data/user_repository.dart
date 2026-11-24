import 'package:quit_companion/features/profile/models/nicotine_user.dart';

abstract class UserRepository {
  Future<void> saveUser(NicotineUser user);
  Future<NicotineUser?> getUser(String userId);
}
