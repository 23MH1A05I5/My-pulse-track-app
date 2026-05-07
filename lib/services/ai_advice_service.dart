import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiAdviceResult {
  final String insight;
  final List<String> tips;
  final List<String> watchFor;
  final String statusLabel;
  final bool fromAi;

  AiAdviceResult({
    required this.insight,
    required this.tips,
    required this.watchFor,
    required this.statusLabel,
    this.fromAi = false,
  });
}

class AiAdviceService {
  // ✅ Replace with your free Gemini API key from https://aistudio.google.com/
  static const String _apiKey = 'YOUR_GEMINI_API_KEY_HERE'; // 🔑 Add your key from https://aistudio.google.com/
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  Future<AiAdviceResult> getAdvice({
    required int bpm,
    required String status,
  }) async {
    if (_apiKey != 'YOUR_GEMINI_API_KEY_HERE') {
      try {
        final result = await _callGemini(bpm: bpm, status: status);
        if (result != null) return result;
      } catch (e) {
        debugPrint('Gemini API error: $e');
      }
    }
    return _getFallback(bpm: bpm);
  }

  Future<AiAdviceResult?> _callGemini({
    required int bpm,
    required String status,
  }) async {
    final hour = DateTime.now().hour;
    final timeOfDay = hour < 12 ? 'morning' : hour < 17 ? 'afternoon' : hour < 21 ? 'evening' : 'night';

    final prompt = '''You are a friendly AI health assistant in the PulseTrack wellness app.
A user just completed a contactless heart rate scan:
- Heart Rate: $bpm BPM
- Status: $status
- Time: $timeOfDay

Respond ONLY with a valid JSON object (no markdown, no extra text):
{
  "insight": "2-3 sentence personalized insight about this heart rate",
  "tips": ["practical tip 1", "tip 2", "tip 3"],
  "watchFor": ["warning sign 1", "warning sign 2"]
}

Be warm, encouraging, and time-appropriate. Keep insight under 60 words.''';

    final response = await http
        .post(
          Uri.parse('$_endpoint?key=$_apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 350},
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
      final clean = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final json = jsonDecode(clean);
      return AiAdviceResult(
        insight: json['insight'],
        tips: List<String>.from(json['tips']),
        watchFor: List<String>.from(json['watchFor']),
        statusLabel: _statusLabel(bpm),
        fromAi: true,
      );
    }
    return null;
  }

  String _statusLabel(int bpm) {
    if (bpm < 50) return 'Alert';
    if (bpm < 60) return 'Low';
    if (bpm <= 80) return 'Excellent';
    if (bpm <= 100) return 'Normal';
    return 'Elevated';
  }

  AiAdviceResult _getFallback({required int bpm}) {
    if (bpm < 50) {
      return AiAdviceResult(
        insight:
            'Your heart rate of $bpm BPM is below the normal resting range (60–100 BPM). This may indicate bradycardia. If you feel dizzy or fatigued, please consult a healthcare professional.',
        tips: [
          'Sit or lie down and rest immediately',
          'Stay warm — cold can lower heart rate further',
          'Avoid strenuous activity until you feel better',
        ],
        watchFor: [
          'Dizziness or fainting spells',
          'Shortness of breath at rest',
          'Chest pain or palpitations',
        ],
        statusLabel: 'Alert',
      );
    } else if (bpm < 60) {
      return AiAdviceResult(
        insight:
            'Your heart rate of $bpm BPM is on the lower end of normal. Athletes and very fit individuals often have heart rates in this range — it can be a sign of great cardiovascular health!',
        tips: [
          'Stay well hydrated throughout the day',
          'Light stretching helps maintain good circulation',
          'Track your resting heart rate trend daily',
        ],
        watchFor: [
          'Unusual fatigue or weakness',
          'Lightheadedness when standing up quickly',
        ],
        statusLabel: 'Low',
      );
    } else if (bpm <= 80) {
      return AiAdviceResult(
        insight:
            'Excellent! Your heart rate of $bpm BPM is in the optimal zone. Your cardiovascular system is working efficiently — a strong indicator of great heart health. Keep it up!',
        tips: [
          'Keep up your current activity level — it\'s working!',
          'Drink 8 glasses of water daily to stay hydrated',
          'Practice 5 minutes of deep breathing to maintain this',
        ],
        watchFor: [
          'Sudden spikes above 100 BPM at rest',
          'Irregular or skipped heartbeats',
        ],
        statusLabel: 'Excellent',
      );
    } else if (bpm <= 100) {
      return AiAdviceResult(
        insight:
            'Your heart rate of $bpm BPM is within the normal range. Minor elevations can be caused by stress, caffeine, or recent activity. Take a moment to relax and breathe deeply.',
        tips: [
          'Try box breathing: inhale 4s, hold 4s, exhale 4s, hold 4s',
          'Reduce caffeine if you\'ve had coffee recently',
          'Take a 5-minute walk to help regulate your system',
        ],
        watchFor: [
          'Heart rate consistently above 100 BPM at rest',
          'Chest tightness or heart palpitations',
        ],
        statusLabel: 'Normal',
      );
    } else {
      return AiAdviceResult(
        insight:
            'Your heart rate of $bpm BPM is above the normal resting range. This can be caused by stress, caffeine, dehydration, or exertion. Rest, hydrate, and re-scan in 10 minutes.',
        tips: [
          'Sit quietly and take slow, deep breaths for 5 minutes',
          'Drink a glass of cool water immediately',
          'Avoid caffeine and stimulants for the next few hours',
        ],
        watchFor: [
          'Chest pain or pressure — seek help immediately',
          'Shortness of breath at rest',
          'Heart rate not returning to normal after 30 min of rest',
        ],
        statusLabel: 'Elevated',
      );
    }
  }
}
