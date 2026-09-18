import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/proactive_message_settings.dart';

class ProactiveMessageStore {
  const ProactiveMessageStore();

  static const _settingsKey = 'proactive_message_settings_v1';
  static const _planKey = 'proactive_message_plan_v1';

  Future<ProactiveMessageSettings> loadSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_settingsKey);
    if (raw == null || raw.isEmpty) return const ProactiveMessageSettings();
    try {
      return ProactiveMessageSettings.fromJson(
        Map<String, Object?>.from(jsonDecode(raw) as Map),
      );
    } on Object {
      return const ProactiveMessageSettings();
    }
  }

  Future<void> saveSettings(ProactiveMessageSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<ProactiveMessagePlan?> loadPlan() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_planKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final plan = ProactiveMessagePlan.fromJson(
        Map<String, Object?>.from(jsonDecode(raw) as Map),
      );
      if (plan.characterId.isEmpty ||
          plan.dueAt.millisecondsSinceEpoch <= 0) {
        return null;
      }
      return plan;
    } on Object {
      return null;
    }
  }

  Future<void> savePlan(ProactiveMessagePlan plan) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_planKey, jsonEncode(plan.toJson()));
  }

  Future<void> clearPlan() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_planKey);
  }
}
