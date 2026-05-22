// PulseTrack — Centralized App Configuration
// All URLs, API keys, and feature flags live here.
// No hardcoded strings anywhere else in the codebase.

class AppConfig {
  AppConfig._();

  // ── Backend API ────────────────────────────────────────────────────────────
  // Node.js backend — deployed on Render
  static const String _prodBackendUrl =
      'https://pulse-track-backend-1-bgfi.onrender.com/api';

  static String get backendBaseUrl => _prodBackendUrl;

  // ── Python rPPG Microservice ───────────────────────────────────────────────
  // Deployed on Render — update this URL after deploying python_rppg service
  // Local dev (physical device): 'http://10.244.62.93:8001'
  // Local dev (emulator):        'http://10.0.2.2:8001'
  static const String _rppgUrl =
      'https://pulsetrack-rppg.onrender.com'; // ← UPDATE after Render deploy

  static String get rppgBaseUrl => _rppgUrl;

  // ── Feature Flags ──────────────────────────────────────────────────────────
  /// Set to true when the Python rPPG server is deployed and running.
  static const bool useServerRppg = true;

  /// DevicePreview — disabled in production release builds
  static const bool _isProduction = bool.fromEnvironment('dart.vm.product');
  static const bool showDevicePreview = !_isProduction;

  // ── Scan Settings ──────────────────────────────────────────────────────────
  static const int scanDurationSeconds = 15;
  static const int minFramesForEstimate = 90;
  static const int frameSubmitIntervalMs = 100;

  // ── App Info ───────────────────────────────────────────────────────────────
  static const String appName = 'PulseTrack';
  static const String appVersion = '2.0.0';
}
