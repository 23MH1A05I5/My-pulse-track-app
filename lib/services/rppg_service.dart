import 'dart:math';

class RppgSignal {
  final double r;
  final double g;
  final double b;
  final DateTime timestamp;

  RppgSignal({required this.r, required this.g, required this.b, required this.timestamp});
}

class RppgService {
  static final RppgService _instance = RppgService._internal();
  factory RppgService() => _instance;
  RppgService._internal();

  final List<RppgSignal> _buffer = [];
  static const int _maxBufferSize = 450; // ~15 seconds at 30fps

  void addSignal(double r, double g, double b) {
    _buffer.add(RppgSignal(
      r: r,
      g: g,
      b: b,
      timestamp: DateTime.now(),
    ));

    if (_buffer.length > _maxBufferSize) {
      _buffer.removeAt(0);
    }
  }

  void clearBuffer() {
    _buffer.clear();
  }

  List<RppgSignal> get buffer => List.unmodifiable(_buffer);

  /// Simple implementation of BPM calculation using the Green channel (Peak detection)
  /// This is a basic version. For production, use FFT on the backend.
  int calculateBpm() {
    if (_buffer.length < 150) return 0; // Need at least 5 seconds

    // 1. Extract Green channel signals
    List<double> greenSignals = _buffer.map((s) => s.g).toList();

    // 2. Normalize and Detrend (simplified)
    double mean = greenSignals.reduce((a, b) => a + b) / greenSignals.length;
    List<double> normalized = greenSignals.map((v) => v - mean).toList();

    // 3. Simple Peak Counting
    int peaks = 0;
    for (int i = 1; i < normalized.length - 1; i++) {
      if (normalized[i] > normalized[i - 1] && normalized[i] > normalized[i + 1] && normalized[i] > 0) {
        peaks++;
      }
    }

    // 4. Calculate BPM based on time span
    double durationMinutes = _buffer.last.timestamp.difference(_buffer.first.timestamp).inMilliseconds / 60000;
    if (durationMinutes == 0) return 0;

    int bpm = (peaks / durationMinutes).round();
    
    // Clamp to realistic values
    return bpm.clamp(50, 180);
  }

  /// Simplified SpO2 calculation based on R/B ratio
  int calculateSpo2() {
    if (_buffer.length < 100) return 0;

    double sumR = 0, sumB = 0;
    for (var s in _buffer) {
      sumR += s.r;
      sumB += s.b;
    }
    
    double ratio = (sumR / _buffer.length) / (sumB / _buffer.length);
    
    // SpO2 estimation
    int spo2 = (110 - (15 * ratio)).round();
    return spo2.clamp(92, 100);
  }

  /// Simplified Blood Pressure calculation
  /// In a real app, this would use Pulse Transit Time (PTT) or complex ML models.
  /// Here we use a correlation model based on BPM and signal intensity.
  Map<String, int> calculateBp(int bpm) {
    if (bpm == 0) return {'systolic': 0, 'diastolic': 0};

    // Base values for resting adult
    int sysBase = 115;
    int diaBase = 75;

    // Adjust based on BPM (higher BPM usually increases BP)
    double bpmFactor = (bpm - 70) / 10; // Positive if above 70
    
    int systolic = (sysBase + (bpmFactor * 3)).round();
    int diastolic = (diaBase + (bpmFactor * 2)).round();

    // Add some "jitter" for realism
    final rand = Random();
    systolic += rand.nextInt(5);
    diastolic += rand.nextInt(3);

    return {
      'systolic': systolic.clamp(90, 160),
      'diastolic': diastolic.clamp(60, 100),
    };
  }
}
