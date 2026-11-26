import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';

/// The only profile details the Health-Bot sends with a question, so it
/// can personalise replies ("day 3 is often the hardest"): product, quit
/// strategy and days since quitting. Never the name, email, phone number,
/// motivation or other free text.
///
/// Days are counted like the dashboard's nicotine-free counter: whole days
/// from the later of the quit date and the last restart (relapse) date.
HealthBotUserContext? healthBotContextFor(NicotineUser user, DateTime now) {
  int? days;
  final quitDate = user.quitDate;
  if (quitDate != null) {
    final quitDay = _dateOnly(quitDate);
    final relapse = user.lastRelapseDate == null
        ? null
        : _dateOnly(user.lastRelapseDate!);
    final start = (relapse != null && relapse.isAfter(quitDay))
        ? relapse
        : quitDay;
    days = _dateOnly(now).difference(start).inDays;
  }
  final context = HealthBotUserContext(
    product: user.productType?.name,
    daysSinceQuit: days,
    quitStrategy: user.quitStrategy?.name,
  );
  return context.isEmpty ? null : context;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
