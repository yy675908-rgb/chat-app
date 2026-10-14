import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationContextService {
  const LocationContextService();

  static const _channel = MethodChannel('linjian/location');
  static const _enabledKey = 'location_context_enabled_v1';

  Future<bool> isEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, enabled);
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
      return place?.trim().isEmpty == true ? null : place?.trim();
    } on Object {
      // Missing permission, disabled device location, or geocoding failure
      // should never prevent a normal reply.
      return null;
    }
  }
}
