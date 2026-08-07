import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'persona.dart';
import 'settings_service.dart';

enum LiveState { idle, connecting, listening, speaking, error }

/// Talks directly to the Gemini Live API over the same WebSocket protocol
/// your desktop K uses: raw 16kHz PCM mic audio streamed up, raw 24kHz PCM
/// audio streamed back down. Google's model does speech-in -> speech-out
/// natively, so there is deliberately no separate TTS engine anywhere here.
class GeminiLiveService extends ChangeNotifier {
  static const _model = 'models/gemini-3.1-flash-live-preview';

  WebSocketChannel? _channel;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  StreamController<Uint8List>? _micController;
  StreamSubscription? _wsSub;

  bool _recorderOpen = false;
  bool _playerOpen = false;

  LiveState state = LiveState.idle;
  String liveTranscript = ''; // K's spoken words, shown as captions only
  String? lastError;

  void _setState(LiveState s) {
    state = s;
    notifyListeners();
  }

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> startSession() async {
    if (state != LiveState.idle && state != LiveState.error) return;

    final apiKey = await SettingsService.instance.getGeminiKey();
    if (apiKey == null || apiKey.isEmpty) {
      lastError = 'No Gemini API key set. Add it in Settings first.';
      _setState(LiveState.error);
      return;
    }

    if (!await _ensureMicPermission()) {
      lastError = 'Microphone permission denied.';
      _setState(LiveState.error);
      return;
    }

    _setState(LiveState.connecting);

    try {
      if (!_recorderOpen) {
        await _recorder.openRecorder();
        _recorderOpen = true;
      }
      if (!_playerOpen) {
        await _player.openPlayer();
        _playerOpen = true;
      }

      final uri = Uri.parse(
        'wss://generativelanguage.googleapis.com/ws/'
        'google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent'
        '?key=$apiKey',
      );
      _channel = WebSocketChannel.connect(uri);

      // --- 1. Setup message: model, persona, audio-only output ---
      final setupMsg = {
        'setup': {
          'model': _model,
          'systemInstruction': {
            'parts': [
              {'text': Persona.voiceSystemPrompt()}
            ]
          },
          'generationConfig': {
            'responseModalities': ['AUDIO'],
          },
          // Lets us show live captions of what K is saying without
          // running any separate speech synthesis / TTS.
          'outputAudioTranscription': {},
        }
      };
      _channel!.sink.add(jsonEncode(setupMsg));

      _wsSub = _channel!.stream.listen(
        _onServerMessage,
        onError: (e) {
          lastError = 'Connection error: $e';
          _setState(LiveState.error);
          stopSession();
        },
        onDone: () {
          if (state != LiveState.idle) {
            _setState(LiveState.idle);
          }
        },
      );

      await _startMicStreaming();
      await _player.startPlayerFromStream(
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 24000,
        interleaved: true,
      );

      _setState(LiveState.listening);
    } catch (e) {
      lastError = 'Failed to start live session: $e';
      _setState(LiveState.error);
      await stopSession();
    }
  }

  Future<void> _startMicStreaming() async {
    _micController = StreamController<Uint8List>();
    _micController!.stream.listen((chunk) {
      if (_channel == null) return;
      final b64 = base64Encode(chunk);
      final msg = {
        'realtimeInput': {
          'audio': {
            'mimeType': 'audio/pcm;rate=16000',
            'data': b64,
          }
        }
      };
      _channel!.sink.add(jsonEncode(msg));
    });

    // NOTE: flutter_sound's exact streaming-record signature has shifted
    // slightly across 9.x releases. If this line fails to compile, check
    // the `startRecorder` signature for your resolved flutter_sound version
    // on pub.dev - you may need `toStream: _micController!.sink` to instead
    // wrap chunks as `FoodData` objects.
    await _recorder.startRecorder(
      toStream: _micController!.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 16000,
    );
  }

  void _onServerMessage(dynamic raw) {
    try {
      final Map<String, dynamic> res = jsonDecode(raw as String);

      if (res.containsKey('setupComplete')) {
        return; // session is live
      }

      if (res.containsKey('serverContent')) {
        final serverContent = res['serverContent'] as Map<String, dynamic>;

        // Barge-in: user started talking over K, flush her audio buffer.
        if (serverContent['interrupted'] == true) {
          _player.stopPlayer();
          _player.startPlayerFromStream(
            codec: Codec.pcm16,
            numChannels: 1,
            sampleRate: 24000,
            interleaved: true,
          );
          liveTranscript = '';
          _setState(LiveState.listening);
        }

        final modelTurn = serverContent['modelTurn'] as Map<String, dynamic>?;
        if (modelTurn != null) {
          final parts = modelTurn['parts'] as List<dynamic>? ?? [];
          for (final part in parts) {
            final inline = part['inlineData'];
            if (inline != null && inline['data'] != null) {
              final audioBytes = base64Decode(inline['data'] as String);
              _player.feedFromStream(audioBytes);
              if (state != LiveState.speaking) _setState(LiveState.speaking);
            }
          }
        }

        final outputTranscription = serverContent['outputTranscription'];
        if (outputTranscription != null &&
            outputTranscription['text'] != null) {
          liveTranscript += outputTranscription['text'] as String;
          notifyListeners();
        }

        if (serverContent['turnComplete'] == true) {
          liveTranscript = '';
          _setState(LiveState.listening);
        }
      }
    } catch (e) {
      debugPrint('[GeminiLive] failed to parse server message: $e');
    }
  }

  Future<void> stopSession() async {
    await _wsSub?.cancel();
    _wsSub = null;
    await _channel?.sink.close();
    _channel = null;

    if (_recorderOpen) {
      await _recorder.stopRecorder();
    }
    await _micController?.close();
    _micController = null;

    if (_playerOpen) {
      await _player.stopPlayer();
    }

    liveTranscript = '';
    _setState(LiveState.idle);
  }

  @override
  void dispose() {
    stopSession();
    if (_recorderOpen) _recorder.closeRecorder();
    if (_playerOpen) _player.closePlayer();
    super.dispose();
  }
}
