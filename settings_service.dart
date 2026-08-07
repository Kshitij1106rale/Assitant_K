import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores API keys locally, encrypted on-device (Keystore on Android,
/// Keychain on iOS). Nothing is ever sent anywhere except directly to
/// Groq / Google's own APIs when you chat with K.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  final _storage = const FlutterSecureStorage();

  static const _groqKeyKey = 'groq_api_key';
  static const _geminiKeyKey = 'gemini_api_key';

  Future<String?> getGroqKey() => _storage.read(key: _groqKeyKey);
  Future<void> setGroqKey(String value) =>
      _storage.write(key: _groqKeyKey, value: value);

  Future<String?> getGeminiKey() => _storage.read(key: _geminiKeyKey);
  Future<void> setGeminiKey(String value) =>
      _storage.write(key: _geminiKeyKey, value: value);

  Future<bool> hasRequiredKeys() async {
    final groq = await getGroqKey();
    final gemini = await getGeminiKey();
    return (groq != null && groq.isNotEmpty) &&
        (gemini != null && gemini.isNotEmpty);
  }
}
