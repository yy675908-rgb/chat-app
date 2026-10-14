import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationContextService {
  const LocationContextService();

  static const _channel = MethodChannel('linjian/location');
  static const _enabledKey = 'location_context_enabled_v1';
  static String? _cachedPlace;
  static DateTime? _cachedAt;
  static String? _lastSharedPlace;

  String? get lastSharedPlace => _lastSharedPlace;

  Future<bool> isEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, enabled);
    if (!enabled) {
      _cachedPlace = null;
      _cachedAt = null;
      _lastSharedPlace = null;
    }
  }

  void markSharedWithCharacter(String? place) {
    _lastSharedPlace = place;
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

  Future<String?> currentPlace({bool forceRefresh = false}) async {
    if (!await isEnabled()) return null;
    final now = DateTime.now();
    final cachedAt = _cachedAt;
    if (!forceRefresh && cachedAt != null &&
        now.difference(cachedAt) < const Duration(minutes: 2)) {
      return _cachedPlace;
    }
    try {
      final place = await _channel
          .invokeMethod<String>('currentPlace')
          .timeout(const Duration(seconds: 12));
      if (place != null && place.trim().isNotEmpty) {
        _cachedPlace = place.trim();
        _cachedAt = DateTime.now();
        return _cachedPlace;
      }
    } on Object {
      // A temporarily unavailable fix should not disrupt a normal reply.
    }
    if (cachedAt == null || _cachedPlace == null ||
        now.difference(cachedAt) >= const Duration(minutes: 15)) return null;
    final minutes = now.difference(cachedAt).inMinutes;
    return '${_cachedPlace!}（约$minutes 分钟前取得，非实时）';
  }
}
