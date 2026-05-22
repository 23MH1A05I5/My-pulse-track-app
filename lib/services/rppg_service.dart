// PulseTrack — Upgraded rPPG Service
//
// Dual-mode architecture:
//   - LOCAL mode: On-device FFT-based calculation (current behavior)
//   - SERVER mode: Streams face ROI frames to Python FastAPI microservice
//                  and receives real-time BPM + confidence + quality.
//
// Toggle via AppConfig.useServerRppg.

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/app_config.dart';

// ── Data Classes ───────────────────────────────────────────────────────────────

/// Raw RGB sample collected from a camera frame
class RppgSignal {
  final double r;
  final double g;
  final double b;
  final DateTime timestamp;

  RppgSignal({
    required this.r,
    required this.g,
    required this.b,
    required this.timestamp,
  });
}

/// Signal quality classification
enum SignalQuality { excellent, good, fair, poor, invalid }

extension SignalQualityX on SignalQuality {
  String get label {
    switch (this) {
      case SignalQuality.excellent: return 'Excellent';
      case SignalQuality.good: return 'Good';
      case SignalQuality.fair: return 'Fair';
      case SignalQuality.poor: return 'Poor';
      case SignalQuality.invalid: return 'Invalid';
    }
  }

  static SignalQuality fromString(String? s) {
    switch (s?.toLowerCase()) {
      case 'excellent': return SignalQuality.excellent;
      case 'good': return SignalQuality.good;
      case 'fair': return SignalQuality.fair;
      case 'poor': return SignalQuality.poor;
      default: return SignalQuality.invalid;
    }
  }
}

/// Live frame processing result (returned every frame)
class LiveFrameResult {
  final int? bpmEstimate;
  final SignalQuality quality;
  final double confidence;  // 0–100
  final double noiseLevel;  // 0.0–1.0
  final int framesCollected;
  final String message;

  const LiveFrameResult({
    this.bpmEstimate,
    required this.quality,
    required this.confidence,
    required this.noiseLevel,
    required this.framesCollected,
    required this.message,
  });

  factory LiveFrameResult.initial() => const LiveFrameResult(
    bpmEstimate: null,
    quality: SignalQuality.invalid,
    confidence: 0,
    noiseLevel: 1,
    framesCollected: 0,
    message: 'Waiting for face...',
  );
}

/// Final scan result after full scan duration
class ScanResult {
  final int bpm;
  final int? spo2;
  final SignalQuality quality;
  final double confidence;
  final double noiseLevel;
  final String status;
  final String? warning;

  const ScanResult({
    required this.bpm,
    this.spo2,
    required this.quality,
    required this.confidence,
    required this.noiseLevel,
    required this.status,
    this.warning,
  });
}

// ── Service ────────────────────────────────────────────────────────────────────

class RppgService {
  static final RppgService _instance = RppgService._internal();
  factory RppgService() => _instance;
  RppgService._internal();

  // ── Local Buffer ───────────────────────────────────────────────────────────
  final List<RppgSignal> _buffer = [];
  static const int _maxBufferSize = 450; // ~15s at 30fps

  // ── Server Session ─────────────────────────────────────────────────────────
  String? _sessionId;
  int _frameCount = 0;
  int _lastServerSubmitMs = 0; // throttle guard

  // ── Buffer Management ──────────────────────────────────────────────────────

  void addSignal(double r, double g, double b) {
    _buffer.add(RppgSignal(r: r, g: g, b: b, timestamp: DateTime.now()));
    if (_buffer.length > _maxBufferSize) _buffer.removeAt(0);
  }

  void clearBuffer() {
    _buffer.clear();
    _frameCount = 0;
    _lastServerSubmitMs = 0;
  }

  List<RppgSignal> get buffer => List.unmodifiable(_buffer);
  int get bufferLength => _buffer.length;

  void startSession(String sessionId) {
    _sessionId = sessionId;
    _frameCount = 0;
    _lastServerSubmitMs = 0;
    clearBuffer();
  }

  // ── Server Mode: Submit Frame ──────────────────────────────────────────────

  /// Submit pre-extracted forehead ROI mean R,G,B values to the Python server.
  ///
  /// This is the primary streaming path. Flutter ML Kit already performs precise
  /// face detection and ROI cropping, so sending lightweight R,G,B means is far
  /// more accurate and efficient than re-encoding and uploading full JPEG frames.
  ///
  /// Throttled to [AppConfig.frameSubmitIntervalMs] to avoid saturating the server.
  /// Returns null if throttled or session not started.
  Future<LiveFrameResult?> submitRgbFrame({
    required double r,
    required double g,
    required double b,
    required int timestampMs,
    double fps = 30.0,
  }) async {
    if (_sessionId == null) return null;

    // Throttle: submit at most once per frameSubmitIntervalMs
    if (timestampMs - _lastServerSubmitMs < AppConfig.frameSubmitIntervalMs) {
      return null;
    }
    _lastServerSubmitMs = timestampMs;
    _frameCount++;

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.rppgBaseUrl}/api/rgb_frame'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': _sessionId,
          'r': r,
          'g': g,
          'b': b,
          'timestamp_ms': timestampMs,
          'fps': fps,
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return LiveFrameResult(
          bpmEstimate: data['bpm_estimate'] as int?,
          quality: SignalQualityX.fromString(data['signal_quality'] as String?),
          confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
          noiseLevel: (data['noise_level'] as num?)?.toDouble() ?? 1,
          framesCollected: data['frames_collected'] as int? ?? _frameCount,
          message: data['message'] as String? ?? 'Processing...',
        );
      }
    } catch (e) {
      debugPrint('rPPG RGB frame submit error: $e');
    }
    return null;
  }

  /// Legacy base64 frame submission (kept for compatibility).
  Future<LiveFrameResult?> submitFrameToServer({
    required String frameB64,
    required int timestampMs,
  }) async {
    if (_sessionId == null) return null;
    _frameCount++;

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.rppgBaseUrl}/api/frame'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'frame_b64': frameB64,
          'timestamp_ms': timestampMs,
          'session_id': _sessionId,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return LiveFrameResult(
          bpmEstimate: data['bpm_estimate'] as int?,
          quality: SignalQualityX.fromString(data['signal_quality'] as String?),
          confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
          noiseLevel: (data['noise_level'] as num?)?.toDouble() ?? 1,
          framesCollected: data['frames_collected'] as int? ?? _frameCount,
          message: data['message'] as String? ?? 'Processing...',
        );
      }
    } catch (e) {
      debugPrint('rPPG server frame error: $e');
    }
    return null;
  }

  /// Request final BPM calculation from the server.
  Future<ScanResult?> finalizeOnServer() async {
    if (_sessionId == null) return null;

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.rppgBaseUrl}/api/finalize/$_sessionId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ScanResult(
          bpm: data['bpm'] as int? ?? 72,
          spo2: data['spo2_estimate'] as int?,
          quality: SignalQualityX.fromString(data['signal_quality'] as String?),
          confidence: (data['confidence'] as num?)?.toDouble() ?? 50,
          noiseLevel: (data['noise_level'] as num?)?.toDouble() ?? 0.5,
          status: data['status'] as String? ?? 'Normal',
          warning: data['warning'] as String?,
        );
      }
    } catch (e) {
      debugPrint('rPPG server finalize error: $e');
    }
    return null;
  }

  // ── Local Mode: On-Device FFT Calculation ─────────────────────────────────

  /// Calculate BPM locally using FFT on the green channel.
  /// Used when [AppConfig.useServerRppg] is false.
  int calculateBpm() {
    if (_buffer.length < 90) return 0; // Need at least 3s

    final greenSignals = _buffer.map((s) => s.g).toList();
    final fs = _estimateFps();

    // 1. Detrend
    final mean = greenSignals.reduce((a, b) => a + b) / greenSignals.length;
    final detrended = greenSignals.map((v) => v - mean).toList();

    // 2. FFT
    final n = detrended.length;
    final fftResult = _fft(detrended);
    final freqResolution = fs / n;

    // 3. Find dominant frequency in HR range (0.7–4.0 Hz)
    double maxPower = 0;
    double peakFreq = 0;

    for (int i = 1; i < fftResult.length ~/ 2; i++) {
      final freq = i * freqResolution;
      if (freq < 0.7 || freq > 4.0) continue;

      final power = fftResult[i] * fftResult[i];
      if (power > maxPower) {
        maxPower = power;
        peakFreq = freq;
      }
    }

    if (peakFreq == 0) return 0;
    final bpm = (peakFreq * 60).round();
    return bpm.clamp(42, 220);
  }

  /// Estimate local signal quality for display.
  LiveFrameResult calculateLocalQuality() {
    final n = _buffer.length;
    if (n < 30) {
      return LiveFrameResult(
        quality: SignalQuality.invalid,
        confidence: 0,
        noiseLevel: 1,
        framesCollected: n,
        message: 'Collecting signal ($n/90 frames)...',
      );
    }

    final green = _buffer.map((s) => s.g).toList();
    final mean = green.reduce((a, b) => a + b) / green.length;
    final variance = green.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / green.length;
    final cv = variance > 0 ? (sqrt(variance) / (mean + 1e-8)).clamp(0.0, 1.0) : 0.0;

    // Heuristic confidence from coefficient of variation
    final confidence = (1 - cv * 2).clamp(0.0, 1.0) * 100;
    final noiseLevel = cv.clamp(0.0, 1.0);

    SignalQuality quality;
    String message;
    if (confidence >= 80) {
      quality = SignalQuality.excellent;
      message = '✅ Excellent signal — keep still';
    } else if (confidence >= 65) {
      quality = SignalQuality.good;
      message = '🟢 Good signal — stay steady';
    } else if (confidence >= 45) {
      quality = SignalQuality.fair;
      message = '🟡 Fair — improve lighting';
    } else {
      quality = SignalQuality.poor;
      message = '🔴 Poor signal — align face better';
    }

    final bpmEst = n >= 90 ? calculateBpm() : null;

    return LiveFrameResult(
      bpmEstimate: bpmEst == 0 ? null : bpmEst,
      quality: quality,
      confidence: confidence,
      noiseLevel: noiseLevel,
      framesCollected: n,
      message: message,
    );
  }

  /// Calculate SpO2 from R/B ratio
  int calculateSpo2() {
    if (_buffer.length < 60) return 0;
    double sumR = 0, sumB = 0;
    for (final s in _buffer) {
      sumR += s.r;
      sumB += s.b;
    }
    final ratio = (sumR / _buffer.length) / (sumB / _buffer.length + 1e-8);
    return (110 - 15 * ratio).round().clamp(90, 100);
  }

  /// Estimate blood pressure (heuristic only — not clinically validated)
  Map<String, int> calculateBp(int bpm) {
    if (bpm == 0) return {'systolic': 0, 'diastolic': 0};
    final bpmFactor = (bpm - 70) / 10;
    final rand = Random();
    return {
      'systolic': (115 + bpmFactor * 3 + rand.nextInt(5)).round().clamp(90, 160),
      'diastolic': (75 + bpmFactor * 2 + rand.nextInt(3)).round().clamp(60, 100),
    };
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  double _estimateFps() {
    if (_buffer.length < 2) return 30.0;
    final duration = _buffer.last.timestamp.difference(_buffer.first.timestamp).inMilliseconds;
    if (duration == 0) return 30.0;
    return (_buffer.length - 1) * 1000.0 / duration;
  }

  /// Simple DFT magnitude calculation (O(n²) — sufficient for n≤450)
  List<double> _fft(List<double> signal) {
    final n = signal.length;
    final result = List<double>.filled(n, 0);
    for (int k = 0; k < n ~/ 2; k++) {
      double real = 0, imag = 0;
      for (int t = 0; t < n; t++) {
        final angle = 2 * pi * k * t / n;
        real += signal[t] * cos(angle);
        imag -= signal[t] * sin(angle);
      }
      result[k] = sqrt(real * real + imag * imag);
    }
    return result;
  }
}
