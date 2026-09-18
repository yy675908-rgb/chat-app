import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:character_chat_app/models/character_profile.dart';
import 'package:character_chat_app/models/proactive_message_settings.dart';
import 'package:character_chat_app/services/proactive_message_planner.dart';
import 'package:character_chat_app/services/proactive_message_store.dart';

void main() {
  CharacterProfile character(String id, String name) => CharacterProfile(
    id: id,
    name: name,
    status: '',
    firstMetAt: DateTime(2026, 1, 1),
    greeting: '',
    systemPrompt: 'prompt',
  );

  test('planner rotates enabled characters and uses configured frequency', () {
    final settings = const ProactiveMessageSettings(
      enabled: true,
      enabledCharacterIds: ['a', 'b'],
      frequency: ProactiveFrequency.frequent,
      quietStartMinutes: 23 * 60,
      quietEndMinutes: 8 * 60,
    );
    final now = DateTime(2026, 9, 18, 9);

    final first = ProactiveMessagePlanner.nextPlan(
      settings: settings,
      characters: [character('a', 'A'), character('b', 'B')],
      now: now,
    );
    expect(first?.characterId, 'a');
    expect(first?.dueAt, DateTime(2026, 9, 18, 17));

    final second = ProactiveMessagePlanner.nextPlan(
      settings: settings,
      characters: [character('a', 'A'), character('b', 'B')],
      now: now,
      previousCharacterId: 'a',
    );
    expect(second?.characterId, 'b');
  });

  test('planner moves night-time due date to quiet-hours end', () {
    final settings = const ProactiveMessageSettings(
      enabled: true,
      enabledCharacterIds: ['a'],
      frequency: ProactiveFrequency.frequent,
      quietStartMinutes: 23 * 60,
      quietEndMinutes: 8 * 60,
    );
    final plan = ProactiveMessagePlanner.nextPlan(
      settings: settings,
      characters: [character('a', 'A')],
      now: DateTime(2026, 9, 18, 20),
    );
    expect(plan?.dueAt, DateTime(2026, 9, 19, 8));
  });

  test('equal quiet-hours endpoints mean no quiet period', () {
    final time = DateTime(2026, 9, 18, 12);
    expect(
      ProactiveMessagePlanner.moveOutsideQuietHours(
        time,
        quietStartMinutes: 0,
        quietEndMinutes: 0,
      ),
      time,
    );
  });

  test('proactive settings and plan survive local storage round trip', () async {
    SharedPreferences.setMockInitialValues({});
    const store = ProactiveMessageStore();
    const settings = ProactiveMessageSettings(
      enabled: true,
      enabledCharacterIds: ['a'],
      frequency: ProactiveFrequency.occasional,
      quietStartMinutes: 22 * 60 + 30,
      quietEndMinutes: 7 * 60 + 15,
    );
    final plan = ProactiveMessagePlan(
      characterId: 'a',
      characterName: 'A',
      dueAt: DateTime.utc(2026, 9, 20, 7, 15),
    );

    await store.saveSettings(settings);
    await store.savePlan(plan);

    final restoredSettings = await store.loadSettings();
    final restoredPlan = await store.loadPlan();
    expect(restoredSettings.enabled, isTrue);
    expect(restoredSettings.enabledCharacterIds, ['a']);
    expect(restoredSettings.frequency, ProactiveFrequency.occasional);
    expect(restoredSettings.quietStartMinutes, 22 * 60 + 30);
    expect(restoredPlan?.characterId, 'a');
    expect(restoredPlan?.dueAt, plan.dueAt);
  });
}
