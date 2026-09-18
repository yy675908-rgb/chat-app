import '../models/character_profile.dart';
import '../models/proactive_message_settings.dart';

class ProactiveMessagePlanner {
  const ProactiveMessagePlanner._();

  static ProactiveMessagePlan? nextPlan({
    required ProactiveMessageSettings settings,
    required List<CharacterProfile> characters,
    required DateTime now,
    String previousCharacterId = '',
  }) {
    if (!settings.enabled) return null;
    final enabledIds = settings.enabledCharacterIds.toSet();
    final enabled = characters
        .where((character) => enabledIds.contains(character.id))
        .toList();
    if (enabled.isEmpty) return null;

    var index = 0;
    if (previousCharacterId.isNotEmpty) {
      final previousIndex = enabled.indexWhere(
        (character) => character.id == previousCharacterId,
      );
      if (previousIndex >= 0) index = (previousIndex + 1) % enabled.length;
    }
    return planForCharacter(
      settings: settings,
      character: enabled[index],
      now: now,
    );
  }

  static ProactiveMessagePlan planForCharacter({
    required ProactiveMessageSettings settings,
    required CharacterProfile character,
    required DateTime now,
  }) {
    var dueAt = now.add(Duration(hours: settings.intervalHours));
    dueAt = moveOutsideQuietHours(
      dueAt,
      quietStartMinutes: settings.quietStartMinutes,
      quietEndMinutes: settings.quietEndMinutes,
    );
    return ProactiveMessagePlan(
      characterId: character.id,
      characterName: character.name,
      dueAt: dueAt,
    );
  }

  static bool isQuietTime(
    DateTime time, {
    required int quietStartMinutes,
    required int quietEndMinutes,
  }) {
    if (quietStartMinutes == quietEndMinutes) return false;
    final minute = time.hour * 60 + time.minute;
    if (quietStartMinutes < quietEndMinutes) {
      return minute >= quietStartMinutes && minute < quietEndMinutes;
    }
    return minute >= quietStartMinutes || minute < quietEndMinutes;
  }

  static DateTime moveOutsideQuietHours(
    DateTime time, {
    required int quietStartMinutes,
    required int quietEndMinutes,
  }) {
    if (!isQuietTime(
      time,
      quietStartMinutes: quietStartMinutes,
      quietEndMinutes: quietEndMinutes,
    )) {
      return time;
    }
    final endHour = quietEndMinutes ~/ 60;
    final endMinute = quietEndMinutes % 60;
    final minute = time.hour * 60 + time.minute;

    if (quietStartMinutes > quietEndMinutes && minute >= quietStartMinutes) {
      final nextDay = time.add(const Duration(days: 1));
      return DateTime(
        nextDay.year,
        nextDay.month,
        nextDay.day,
        endHour,
        endMinute,
      );
    }
    return DateTime(
      time.year,
      time.month,
      time.day,
      endHour,
      endMinute,
    );
  }
}
