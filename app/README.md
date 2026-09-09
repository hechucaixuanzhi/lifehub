# LifeHub Open Flutter client

The client is local-first: life, study, exercise, pet, and chat data are kept
in its local Drift database and synchronized only through the configured
backend.

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Use an Android emulator's host address or `adb reverse` when the backend runs
on the development machine. Do not embed provider API keys in a Flutter build.

The app ships only fictional sample characters. Import media or configure
voice/identity features only for content you are authorized to use.
