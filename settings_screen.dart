import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _groqController = TextEditingController();
  final _geminiController = TextEditingController();
  bool _saved = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groq = await SettingsService.instance.getGroqKey();
    final gemini = await SettingsService.instance.getGeminiKey();
    _groqController.text = groq ?? '';
    _geminiController.text = gemini ?? '';
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    await SettingsService.instance.setGroqKey(_groqController.text.trim());
    await SettingsService.instance.setGeminiKey(_geminiController.text.trim());
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'API keys are stored encrypted, only on this device, and used '
              'only to talk directly to Groq / Google.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _groqController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Groq API Key (text chat)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _geminiController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key (live voice)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: Text(_saved ? 'Saved ✓' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
