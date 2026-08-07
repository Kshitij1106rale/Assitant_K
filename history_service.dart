import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

class HistoryService {
  static const _key = 'k_chat_history';

  Future<List<ChatMessage>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((s) => ChatMessage.fromJson(jsonDecode(s))).toList();
  }

  Future<void> save(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    // Keep the last 200 messages on-device so this never grows unbounded.
    final trimmed = messages.length > 200
        ? messages.sublist(messages.length - 200)
        : messages;
    await prefs.setStringList(
      _key,
      trimmed.map((m) => jsonEncode(m.toJson())).toList(),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
