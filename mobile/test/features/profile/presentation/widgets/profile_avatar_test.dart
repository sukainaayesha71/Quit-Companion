import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/onboarding/models/gender.dart';
import 'package:quit_companion/features/profile/presentation/screens/widgets/profile_avatar.dart';

void main() {
  testWidgets('renders the male-keyed avatar for Gender.male', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProfileAvatar(gender: Gender.male)),
    );
    expect(find.byKey(const Key('profile_avatar_male')), findsOneWidget);
  });

  testWidgets('defaults to the female-keyed avatar when gender is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProfileAvatar(gender: null)),
    );
    expect(find.byKey(const Key('profile_avatar_female')), findsOneWidget);
  });
}
