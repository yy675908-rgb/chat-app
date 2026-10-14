import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationContextService {
  const LocationContextService();

  static const _channel = MethodChannel('linjian/location');
  static const _enabledKey = 'location_context_enabled_v1';
  static String? _lastSharedPlace;
  static bool _hasSharedWithCharacter = false;

  String? get lastSharedPlace => _lastSharedPlace;
  bool get hasSharedWithCharacter => _hasSharedWithCharacter;

  Future<bool> isEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, enabled);
    if (!enabled) {
      _lastSharedPlace = null;
      _hasSharedWithCharacter = false;
    }
  }

  void markSharedWithCharacter(String? place) {
    _lastSharedPlace = place;
    _hasSharedWithCharacter = true;
  }

  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<String?> currentPlace() async {
    if (!await isEnabled()) return null;
    try {
      final place = await _channel
          .invokeMethod<String>('currentPlace')
          .timeout(const Duration(seconds: 12));
      if (place != null && place.trim().isNotEmpty) {
        return place.trim();
      }
    } on Object {
      // A temporarily unavailable fix should not disrupt a normal reply.
    }
    return null;
  }
}
