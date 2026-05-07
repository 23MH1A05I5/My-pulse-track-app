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
  static const String _apiKey = 'AIzaSyBsxpbqaSZLVCUJTGlrxukWoOtCSWVF-VI';
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

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

  Future<String> chatWithAi(String message, List<Map<String, String>> history) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      return "I'm currently running in offline mode. I can only provide basic scan advice right now!";
    }

    try {
      final contents = <Map<String, dynamic>>[];
      
      const systemContext = "You are a helpful and knowledgeable AI health assistant for the PulseTrack app. "
          "Answer briefly and safely. If asked for medical diagnosis, remind them you are an AI and they should see a doctor.";

      // Build contents from history
      for (int i = 0; i < history.length; i++) {
        final msg = history[i];
        String text = msg['text'] ?? '';
        
        // Prepend system context to the very first user message for better grounding
        if (i == 0 && msg['role'] == 'user') {
          text = "$systemContext\n\n$text";
        } else if (i == 0 && msg['role'] != 'user' && history.length > 1 && history[1]['role'] == 'user') {
            // If first msg is AI (intro), skip system context there, will add to next user msg
        }

        contents.add({
          'role': msg['role'] == 'user' ? 'user' : 'model',
          'parts': [{'text': text}]
        });
      }

      // If history already contains the message (added in UI state), we don't need to add it again
      // The ai_chat_screen adds it before calling this.
      if (contents.isEmpty || contents.last['parts'][0]['text'] != message) {
         contents.add({
          'role': 'user',
          'parts': [{'text': contents.isEmpty ? "$systemContext\n\n$message" : message}]
        });
      }

      final response = await http
          .post(
            Uri.parse('$_endpoint?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': contents,
              'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 400},
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] as String;
      }
      
      debugPrint('Gemini Error ${response.statusCode}: ${response.body}');
      return "I'm having trouble connecting to the AI server. Please try again in a moment.";
    } catch (e) {
      debugPrint('Gemini Chat API error: $e');
      return "Sorry, I couldn't process that due to a network error. Check your connection!";
    }
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
