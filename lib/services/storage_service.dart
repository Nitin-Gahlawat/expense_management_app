import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  static const String _apiKeyBoxName = 'api_keys';
  static const String _geminiApiKeyKey = 'gemini_api_key';

  static Box<String>? _apiKeyBox;

  static Future<void> initialize() async {
    if (_apiKeyBox == null) {
      _apiKeyBox = await Hive.openBox<String>(_apiKeyBoxName);
    }
  }

  static Future<void> saveGeminiApiKey(String apiKey) async {
    await _apiKeyBox?.put(_geminiApiKeyKey, apiKey);
  }

  static String? getGeminiApiKey() {
    return _apiKeyBox?.get(_geminiApiKeyKey);
  }

  static bool hasGeminiApiKey() {
    final key = getGeminiApiKey();
    return key != null && key.isNotEmpty;
  }

  static Future<void> deleteGeminiApiKey() async {
    await _apiKeyBox?.delete(_geminiApiKeyKey);
  }

  static Future<void> close() async {
    await _apiKeyBox?.close();
    _apiKeyBox = null;
  }
}
