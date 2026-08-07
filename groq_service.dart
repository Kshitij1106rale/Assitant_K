import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import 'persona.dart';
import 'settings_service.dart';

class GroqService {
  static const _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  // Same family of model your desktop app uses via the Groq SDK.
  // Swap this if Groq deprecates it - check console.groq.com/docs/models.
  static const _model = 'llama-3.3-70b-versatile';

  Future<String> sendMessage(List<ChatMessage> history) async {
    final apiKey = await SettingsService.instance.getGroqKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('No Groq API key set. Add it in Settings first.');
    }

    final messages = [
      {'role': 'system', 'content': Persona.textSystemPrompt()},
      for (final m in history)
        {
          'role': m.sender == Sender.user ? 'user' : 'assistant',
          'content': m.text,
        },
    ];

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': 0.9,
        'max_tokens': 400,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Groq error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return (data['choices'][0]['message']['content'] as String).trim();
  }
}
