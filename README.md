# K — Mobile

## Fastest path: get a built APK without installing anything

This project includes `.github/workflows/build.yml`, a free GitHub Actions
recipe that compiles a real APK in the cloud — you don't need Flutter,
Android Studio, or anything else on your PC for this part.

1. Make a free GitHub account: https://github.com/join
2. Create a new **public** repository (private repos have limited free CI
   minutes) — click "New" on github.com, name it `k-assistant`.
3. Upload this entire `k_assistant` folder into that repo (on the repo page:
   "Add file" → "Upload files" → drag the whole folder in → Commit).
4. Go to the **Actions** tab of your repo. You'll see "Build K APK" running
   automatically (it triggers on every push). It takes ~5-8 minutes.
5. When it finishes with a green check, click into that run → scroll to
   **Artifacts** → download `k-assistant-apk`. Unzip it — that's your
   `app-release.apk`.
6. Transfer the APK to your phone (email it to yourself, Google Drive, USB —
   whatever's easiest), tap it on your phone to install. Android will warn
   about "unknown sources" since it's not from the Play Store — that's
   expected for a personal-use APK, allow it.
7. Open the app, go to Settings, paste your Groq + Gemini API keys, and try
   the Voice tab.

This gives you a genuinely compiled, installable APK. What it can't give you
is a guarantee it works flawlessly on your specific phone the first try —
that only gets proven once you actually tap the mic button on real hardware.
If something breaks at that point, send me the exact behavior (crash on
open? mic button does nothing? connects but no audio?) and I'll fix the
actual bug instead of guessing.

## Alternative: build it yourself locally

A Flutter starter app that ports K's core experience to your phone:
- Text chat with K's persona (Groq)
- **Real live voice mode** using the Gemini Live API — the same WebSocket
  protocol your desktop `assistant.py` already uses (`gemini-3.1-flash-live-preview`,
  16kHz PCM mic in, 24kHz PCM audio out). No separate TTS engine anywhere.
- API keys stored encrypted, on-device only
- Local chat history

I wrote this code but could **not compile or run it** in the environment I
built it in (no Android/iOS SDK, no emulator, no package registry access).
Treat this as a strong, correct-by-design starting point, not a
guaranteed zero-edit build — see "Known rough edges" below.

## Setup

1. Install Flutter (https://docs.flutter.dev/get-started/install) and Android
   Studio (or Xcode if you're building for iOS).
2. Copy all files in this folder into a fresh project:
   ```
   flutter create k_assistant
   ```
   then overwrite the generated `pubspec.yaml` and `lib/` with the ones here.
3. Add permissions:

   **Android** — in `android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.RECORD_AUDIO" />
   <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
   ```

   **iOS** — in `ios/Runner/Info.plist`, inside the top-level `<dict>`:
   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>K needs your mic for live voice conversations.</string>
   ```

4. Get your API keys:
   - Groq: https://console.groq.com/keys
   - Gemini: https://aistudio.google.com/apikey (same key your desktop app already uses)

5. Install packages and run:
   ```
   flutter pub get
   flutter run
   ```
6. Open the app → Settings tab → paste both keys → go to the Voice tab and tap
   the mic to start a live call with K.

## Known rough edges (please read before filing this under "broken")

- **`flutter_sound` streaming API**: the exact method signature for
  streaming raw PCM in/out has changed slightly across `flutter_sound` 9.x
  point releases. If `flutter pub get` resolves a version where
  `startRecorder(toStream: ...)` or `feedFromStream(...)` doesn't match,
  check the changelog on pub.dev for that resolved version — it's a small
  signature fix, not a redesign. This is the single most likely build error.
- **Groq model name** (`llama-3.3-70b-versatile`) can be deprecated by Groq
  over time — check https://console.groq.com/docs/models if you get a
  model-not-found error and swap the string in `groq_service.dart`.
- **Barge-in handling** (interrupting K mid-sentence) stops and restarts the
  player stream, which is simple but not seamless — a production version
  would crossfade instead.

## What's intentionally NOT in this build, and why

Your desktop `assistant.py` does a lot that genuinely can't (or shouldn't)
follow onto a phone:

| Desktop feature | Why it's out of v1 |
|---|---|
| `pyautogui` screen/keyboard automation, Windows OS agent | Android/iOS sandbox every app — no app can control another app's UI or the OS without root/jailbreak. There's no safe equivalent. |
| Vosk offline wake-word ("always listening") | Needs a persistent foreground service and kills battery fast; also needs the ~50MB model bundled into the app. Doable later as an opt-in, not v1. |
| Webcam face-verification | Different privacy/permission model on mobile; would need to be rebuilt around the phone's front camera + a real consent flow. |
| ChromaDB long-term vector memory, Telegram uplink, clipboard hijack | All portable in principle, just left out to keep this first build small enough to actually work. Happy to add any of these next. |

## Next steps I'd suggest

Once this base is running and you've confirmed voice mode actually connects
end-to-end on your phone, good next additions (each is a contained, separate
task): push notifications for reminders, weather widget, local SQLite for
longer memory, and function-calling tools inside the Live session (e.g. "K,
what's the weather" triggering a real API call mid-conversation).
