import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/provider_profile.dart';

class ProviderStore {
  static const _providersKey = 'providers_v2';
  static const _selectedProviderKey = 'selected_provider_v2';
  static const _legacyBaseUrlKey = 'api_base_url_v1';
  static const _legacyModelKey = 'api_model_v1';
  static const _legacyApiKeyKey = 'api_secret_v1';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<List<ProviderProfile>> loadProviders() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_providersKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        return (jsonDecode(raw) as List<dynamic>)
            .map(
              (item) => ProviderProfile.fromJson(
                Map<String, Object?>.from(item as Map),
              ),
            )
            .toList();
      } on Object {
        // Recreate a usable provider list below.
      }
    }

    final legacyBaseUrl = preferences.getString(_legacyBaseUrlKey);
    final legacyModel = preferences.getString(_legacyModelKey);
    final migrated = ProviderProfile.openAi().copyWith(
      baseUrl: legacyBaseUrl,
      selectedModel: legacyModel,
      models: legacyModel == null || legacyModel.isEmpty ? [] : [legacyModel],
    );
    final legacyKey = await _secureStorage.read(key: _legacyApiKeyKey);
    if (legacyKey != null && legacyKey.isNotEmpty) {
      await saveApiKey(migrated.id, legacyKey);
    }
    await saveProviders([migrated]);
    return [migrated];
  }

  Future<void> saveProviders(List<ProviderProfile> providers) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _providersKey,
      jsonEncode(providers.map((provider) => provider.toJson()).toList()),
    );
  }

  Future<String?> loadSelectedProviderId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_selectedProviderKey);
  }

  Future<void> saveSelectedProviderId(String id) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_selectedProviderKey, id);
  }

  Future<String> loadApiKey(String providerId) async {
    return await _secureStorage.read(key: 'provider_key_$providerId') ?? '';
  }

  Future<void> saveApiKey(String providerId, String apiKey) async {
    await _secureStorage.write(
      key: 'provider_key_$providerId',
      value: apiKey.trim(),
    );
  }

  Future<void> deleteProviderKey(String providerId) async {
    await _secureStorage.delete(key: 'provider_key_$providerId');
  }
}
