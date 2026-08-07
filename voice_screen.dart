import 'package:flutter/material.dart';
import '../services/gemini_live_service.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  final _live = GeminiLiveService();

  @override
  void initState() {
    super.initState();
    _live.addListener(_onLiveUpdate);
  }

  void _onLiveUpdate() => setState(() {});

  @override
  void dispose() {
    _live.removeListener(_onLiveUpdate);
    _live.dispose();
    super.dispose();
  }

  String get _statusLabel {
    switch (_live.state) {
      case LiveState.idle:
        return 'Tap to talk to K';
      case LiveState.connecting:
        return 'Connecting…';
      case LiveState.listening:
        return "Listening…";
      case LiveState.speaking:
        return 'K is speaking…';
      case LiveState.error:
        return _live.lastError ?? 'Something went wrong';
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _live.state == LiveState.listening ||
        _live.state == LiveState.speaking ||
        _live.state == LiveState.connecting;

    return Scaffold(
      appBar: AppBar(title: const Text('K — Live Voice')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                if (active) {
                  _live.stopSession();
                } else {
                  _live.startSession();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _live.state == LiveState.speaking
                      ? Colors.pinkAccent
                      : active
                          ? Colors.tealAccent.shade700
                          : Theme.of(context).colorScheme.primary,
                ),
                child: Icon(
                  active ? Icons.mic : Icons.mic_none,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(_statusLabel, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (_live.liveTranscript.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _live.liveTranscript,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 40),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'This is a real live call with Gemini — audio in, audio out, '
                'no separate text-to-speech step.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
