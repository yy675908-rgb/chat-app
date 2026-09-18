import '../models/character_profile.dart';
import '../models/proactive_message_settings.dart';
import 'proactive_message_planner.dart';
import 'proactive_message_store.dart';
import 'proactive_notification_service.dart';

class ProactiveMessageCoordinator {
  const ProactiveMessageCoordinator({
    ProactiveMessageStore store = const ProactiveMessageStore(),
    ProactiveNotificationService notifications =
        const ProactiveNotificationService(),
  }) : _store = store,
       _notifications = notifications;

  final ProactiveMessageStore _store;
  final ProactiveNotificationService _notifications;

  Future<ProactiveMessagePlan?> reschedule({
    required List<CharacterProfile> characters,
    DateTime? now,
    String previousCharacterId = '',
  }) async {
    final settings = await _store.loadSettings();
    if (!settings.enabled) {
      await _store.clearPlan();
      await _notifications.cancel();
      return null;
    }

    var previousId = previousCharacterId;
    if (previousId.isEmpty) {
      previousId = (await _store.loadPlan())?.characterId ?? '';
    }
    final plan = ProactiveMessagePlanner.nextPlan(
      settings: settings,
      characters: characters,
      now: now ?? DateTime.now(),
      previousCharacterId: previousId,
    );
    if (plan == null) {
      await _store.clearPlan();
      await _notifications.cancel();
      return null;
    }
    await _store.savePlan(plan);
    await _notifications.schedule(plan);
    return plan;
  }

  Future<ProactiveMessagePlan?> consumeDue({
    required List<CharacterProfile> characters,
    DateTime? now,
  }) async {
    final settings = await _store.loadSettings();
    if (!settings.enabled) return null;
    final plan = await _store.loadPlan();
    if (plan == null) {
      await reschedule(characters: characters, now: now);
      return null;
    }

    final currentTime = now ?? DateTime.now();
    if (plan.dueAt.isAfter(currentTime)) return null;
    final valid = characters.any(
      (character) =>
          character.id == plan.characterId &&
          settings.enabledCharacterIds.contains(character.id),
    );
    await _store.clearPlan();
    if (!valid) {
      await reschedule(
        characters: characters,
        now: currentTime,
        previousCharacterId: plan.characterId,
      );
      return null;
    }
    return plan;
  }

  Future<void> scheduleAfterConsumed({
    required List<CharacterProfile> characters,
    required ProactiveMessagePlan consumed,
    DateTime? now,
  }) {
    return reschedule(
      characters: characters,
      now: now,
      previousCharacterId: consumed.characterId,
    );
  }
}
