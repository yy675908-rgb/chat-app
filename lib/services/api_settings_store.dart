import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_profile.dart';

class ApiSettingsStore {
  static const _baseUrlKey = 'api_base_url_v1';
  static const _modelKey = 'api_model_v1';
  static const _apiKeyKey = 'api_secret_v1';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<ApiProfile> loadProfile() async {
    final preferences = await SharedPreferences.getInstance();
    return ApiProfile(
      baseUrl: preferences.getString(_baseUrlKey) ??
          'https://api.openai.com/v1',
      model: preferences.getString(_modelKey) ?? '',
    );
  }

  Future<String> loadApiKey() async {
    return await _secureStorage.read(key: _apiKeyKey) ?? '';
  }

  Future<void> save(ApiProfile profile, String apiKey) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_baseUrlKey, profile.baseUrl.trim());
    await preferences.setString(_modelKey, profile.model.trim());
    await _secureStorage.write(key: _apiKeyKey, value: apiKey.trim());
  }
}
