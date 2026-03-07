# rocket_reminder

Goal Lock mobile app for Rocket Goals.

## Local config

Do not commit Firebase keys or other secrets into source.

Run linked-account flows with:

```bash
flutter run --dart-define=ROCKET_GOALS_FIREBASE_API_KEY=your_key_here
```

Without that define, the app still works in Preview mode.
