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
  // ✅ Get your free API key from https://aistudio.google.com/
  // Current key is provided by the user.
  static const String _apiKey = 'AIzaSyDoW9vMoyZE1OvLiZ7JVOVjfnqwsfjEPfU';

  // Model priority list — tries each in order if the previous fails/is rate-limited
  static const List<String> _modelFallbacks = [
    'gemini-2.0-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash-lite',
  ];

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static String _getSystemInstruction(String? vitalsContext) {
    return 'You are a helpful and knowledgeable AI health assistant for the PulseTrack app. '
        'Your job is to help users understand their heart health readings. '
        'Keep answers concise (under 100 words), warm, and friendly. '
        'Never provide a medical diagnosis. Always recommend consulting a doctor for medical concerns. '
        '${vitalsContext ?? "If the user shares their vitals, give personalised feedback."}';
  }

  // ── Chat with AI ─────────────────────────────────────────────────────────────
  Future<String> chatWithAi(String message, List<Map<String, String>> history,
      {String? vitalsContext}) async {
    debugPrint('CHATBOT: Sending message: "$message"');

    if (_apiKey.isEmpty || _apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      debugPrint('CHATBOT: No API key set, using offline mode.');
      return _offlineChat(message);
    }

    // Build clean conversation contents for Gemini
    final contents = <Map<String, dynamic>>[];

    // Process history — filter empty, ensure alternating roles, skip leading 'model'
    for (final msg in history) {
      final role =
          (msg['role'] == 'user' || msg['role'] == 'client') ? 'user' : 'model';
      final text = (msg['text'] ?? '').trim();

      // Skip empty messages
      if (text.isEmpty) continue;

      // If we haven't started yet, skip leading model messages
      if (contents.isEmpty && role == 'model') continue;

      // Skip consecutive same-role messages
      if (contents.isNotEmpty && contents.last['role'] == role) continue;

      contents.add({
        'role': role,
        'parts': [
          {'text': text}
        ]
      });
    }

    // Ensure the current user message is at the end
    if (contents.isNotEmpty && contents.last['role'] == 'user') {
      // Check if last user message is already this message
      final lastText = (contents.last['parts'] as List)[0]['text'];
      if (lastText != message) {
        // Can't have two user messages in a row — replace the last one
        contents.last['parts'] = [
          {'text': message}
        ];
      }
    } else {
      // Either empty or last was 'model' — add user message
      contents.add({
        'role': 'user',
        'parts': [
          {'text': message}
        ]
      });
    }

    debugPrint('CHATBOT: Prepared ${contents.length} messages for API.');

    // Try each model in fallback order
    for (final model in _modelFallbacks) {
      try {
        final url = Uri.parse('$_baseUrl/$model:generateContent?key=$_apiKey');
        final body = jsonEncode({
          'system_instruction': {
            'parts': [
              {'text': _getSystemInstruction(vitalsContext)}
            ]
          },
          'contents': contents,
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 512,
          },
        });

        debugPrint('CHATBOT: Calling Gemini API ($model)...');
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 20));

        debugPrint('CHATBOT: Response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final candidate = candidates[0];
            if (candidate['content'] != null &&
                candidate['content']['parts'] != null) {
              final parts = candidate['content']['parts'] as List;
              if (parts.isNotEmpty) {
                final aiText = (parts[0]['text'] as String).trim();
                debugPrint(
                    'CHATBOT SUCCESS: Got response from $model (${aiText.length} chars)');
                return aiText;
              }
            }
          }
          debugPrint('CHATBOT ERROR: Empty/malformed response from $model');
          debugPrint('CHATBOT BODY: ${response.body.substring(0, (response.body.length > 500) ? 500 : response.body.length)}');
        } else if (response.statusCode == 429) {
          debugPrint('CHATBOT: Rate limited on $model, trying next...');
          continue;
        } else if (response.statusCode == 400) {
          debugPrint('CHATBOT ERROR 400 ($model): ${response.body}');
          // Try simplifying — send only the current message without history
          final simpleResult = await _simpleSingleCall(message, model, vitalsContext);
          if (simpleResult != null) return simpleResult;
          continue;
        } else {
          debugPrint(
              'CHATBOT ERROR ${response.statusCode} ($model): ${response.body}');
        }
      } catch (e) {
        debugPrint('CHATBOT EXCEPTION ($model): $e');
      }
    }

    // All models failed
    debugPrint('CHATBOT: All models failed. Falling back to offline mode.');
    return _offlineChat(message);
  }

  // ── Simple single-message call (no history) as a last resort ──────────────
  Future<String?> _simpleSingleCall(
      String message, String model, String? vitalsContext) async {
    try {
      debugPrint('CHATBOT: Trying simple single-message call on $model...');
      final url = Uri.parse('$_baseUrl/$model:generateContent?key=$_apiKey');
      final body = jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': _getSystemInstruction(vitalsContext)}
          ]
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': message}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 512,
        },
      });

      final response = await http
          .post(url,
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']['parts'] as List;
          if (parts.isNotEmpty) {
            final aiText = (parts[0]['text'] as String).trim();
            debugPrint(
                'CHATBOT SUCCESS (simple): Got response from $model');
            return aiText;
          }
        }
      } else {
        debugPrint(
            'CHATBOT SIMPLE ERROR ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('CHATBOT SIMPLE EXCEPTION: $e');
    }
    return null;
  }

  // ── Get Advice (for Result Screen) ───────────────────────────────────────────
  Future<AiAdviceResult> getAdvice({
    required int bpm,
    required String status,
  }) async {
    if (_apiKey.isNotEmpty && _apiKey != 'YOUR_GEMINI_API_KEY_HERE') {
      for (final model in _modelFallbacks) {
        try {
          final result =
              await _callGeminiAdvice(model: model, bpm: bpm, status: status);
          if (result != null) return result;
        } catch (e) {
          debugPrint('[$model] Advice error: $e');
        }
      }
    }
    return _getFallback(bpm: bpm);
  }

  // ── Internal: call Gemini for structured advice ───────────────────────────────
  Future<AiAdviceResult?> _callGeminiAdvice({
    required String model,
    required int bpm,
    required String status,
  }) async {
    final hour = DateTime.now().hour;
    final timeOfDay = hour < 12
        ? 'morning'
        : hour < 17
            ? 'afternoon'
            : hour < 21
                ? 'evening'
                : 'night';

    final prompt = '''A PulseTrack user just completed a heart rate scan.
- Heart Rate: $bpm BPM
- Status: $status
- Time of day: $timeOfDay

Respond ONLY with valid JSON (no markdown, no extra text):
{
  "insight": "A warm, 2-3 sentence personalised insight about this reading",
  "tips": ["tip 1", "tip 2", "tip 3"],
  "watchFor": ["warning sign 1", "warning sign 2"]
}''';

    final url = Uri.parse('$_baseUrl/$model:generateContent?key=$_apiKey');
    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'system_instruction': {
                'parts': [
                  {'text': _getSystemInstruction(null)}
                ]
              },
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.6,
                'maxOutputTokens': 400,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text =
            data['candidates'][0]['content']['parts'][0]['text'] as String;
        final clean =
            text.replaceAll('```json', '').replaceAll('```', '').trim();
        final json = jsonDecode(clean) as Map<String, dynamic>;
        return AiAdviceResult(
          insight: json['insight'] as String,
          tips: List<String>.from(json['tips'] as List),
          watchFor: List<String>.from(json['watchFor'] as List),
          statusLabel: _statusLabel(bpm),
          fromAi: true,
        );
      }
    } catch (e) {
      debugPrint('Advice Exception ($model): $e');
    }

    return null;
  }

  // ── Intelligent offline chat ──────────────────────────────────────────────────
  String _offlineChat(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('bpm') ||
        lower.contains('heart rate') ||
        lower.contains('pulse')) {
      return "A normal resting heart rate for adults is 60–100 BPM. Athletes can have rates as low as 40 BPM. Anything consistently above 100 BPM at rest (tachycardia) or below 60 BPM (bradycardia) should be discussed with a doctor.";
    }

    if (lower.contains('spo2') ||
        lower.contains('oxygen') ||
        lower.contains('saturation')) {
      return "Blood oxygen saturation (SpO2) is normally 95–100%. Readings below 92% may indicate low oxygen levels and warrant medical attention. PulseTrack estimates SpO2 using the color variations in your skin captured by the camera.";
    }

    if (lower.contains('blood pressure') ||
        lower.contains('systolic') ||
        lower.contains('diastolic')) {
      return "Normal blood pressure is below 120/80 mmHg. Stage 1 hypertension is 130–139/80–89 mmHg, and Stage 2 is 140+/90+ mmHg. PulseTrack provides estimated BP readings — for accurate diagnosis, always use a certified blood pressure cuff.";
    }

    if (lower.contains('stress') || lower.contains('anxiety')) {
      return "Stress and anxiety can temporarily raise your heart rate and blood pressure. Try box breathing: inhale for 4 seconds, hold for 4, exhale for 4, hold for 4. Repeat 4–5 times. Regular deep breathing exercises can lower your resting heart rate over time.";
    }

    if (lower.contains('exercise') || lower.contains('workout')) {
      return "During exercise, your heart rate increases to deliver more oxygen to your muscles. Your target heart rate zone is typically 50–85% of your maximum heart rate (roughly 220 minus your age). PulseTrack is best used for resting heart rate measurements.";
    }

    if (lower.contains('sleep') || lower.contains('resting')) {
      return "Your resting heart rate is best measured in the morning after waking up, before getting out of bed. Consistent tracking over time gives you the most meaningful data about your cardiovascular health trends.";
    }

    if (lower.contains('high') || lower.contains('elevated')) {
      return "A temporarily elevated heart rate can be caused by stress, caffeine, dehydration, or recent physical activity. Try sitting quietly for 5 minutes and re-scanning. If it stays consistently high at rest, consult a healthcare professional.";
    }

    if (lower.contains('low') || lower.contains('bradycardia')) {
      return "A low resting heart rate below 60 BPM is common in athletes and very fit individuals. However, if it's accompanied by dizziness, fatigue, or shortness of breath, you should consult a doctor as it may indicate bradycardia.";
    }

    if (lower.contains('hello') ||
        lower.contains('hi') ||
        lower.contains('hey')) {
      return "Hello! I'm your PulseTrack AI Health Assistant. I can help you understand your heart rate, SpO2, and blood pressure readings. Ask me anything about your health data! 💓";
    }

    // Generic fallback
    return "I'm currently in offline mode due to connectivity issues or API limits. I can still answer questions about heart rate (BPM), blood oxygen (SpO2), blood pressure, stress, exercise, and sleep. What would you like to know?";
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
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
        ],
        statusLabel: 'Alert',
      );
    } else if (bpm < 60) {
      return AiAdviceResult(
        insight:
            'Your heart rate of $bpm BPM is on the lower end. Athletes and very fit individuals often have rates in this range — a great sign of cardiovascular fitness!',
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
            'Excellent! Your heart rate of $bpm BPM is in the optimal zone. Your cardiovascular system is working efficiently — keep it up!',
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
        ],
        statusLabel: 'Elevated',
      );
    }
  }
}
