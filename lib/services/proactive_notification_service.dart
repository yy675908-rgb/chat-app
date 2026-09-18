import 'package:flutter/services.dart';

import '../models/proactive_message_settings.dart';

class ProactiveNotificationService {
  const ProactiveNotificationService();

  static const _channel = MethodChannel('linjian/proactive_notifications');
  static const _notificationId = 7301;

  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> canNotify() async {
    try {
      return await _channel.invokeMethod<bool>('canNotify') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> schedule(ProactiveMessagePlan plan) async {
    try {
      await _channel.invokeMethod<void>('schedule', {
        'id': _notificationId,
        'triggerAtMillis': plan.dueAt.millisecondsSinceEpoch,
        'title': plan.characterName,
        'body': '想和你说句话',
      });
    } on MissingPluginException {
      // Unit/widget tests and unsupported platforms have no Android channel.
    }
  }

  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel', {'id': _notificationId});
    } on MissingPluginException {
      // Unit/widget tests and unsupported platforms have no Android channel.
    }
  }
}
