/// Temporarily dormant modules retain their source code and local data.
/// Restore with --dart-define=LIFE_TRACKING_ENABLED=true and enable the backend.
abstract final class FeatureFlags {
  static const lifeTrackingEnabled = bool.fromEnvironment(
    'LIFE_TRACKING_ENABLED',
    defaultValue: false,
  );
}
