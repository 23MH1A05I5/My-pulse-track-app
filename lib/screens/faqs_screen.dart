
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FaqsScreen extends StatefulWidget {
  const FaqsScreen({super.key});

  @override
  State<FaqsScreen> createState() => _FaqsScreenState();
}

class _FaqsScreenState extends State<FaqsScreen> {
  final _searchController = TextEditingController();
  int? _expandedIndex;

  final List<Map<String, dynamic>> _faqs = [
    {
      'icon': Icons.waves,
      'color': Colors.purple,
      'question': 'How does heart rate scanning work?',
      'answer': 'PulseTrack uses your device camera and advanced AI to detect subtle color changes in your skin caused by blood flow. This helps estimate your heart rate within seconds.',
      'hasIllustration': true,
    },
    {
      'icon': Icons.trending_up,
      'color': Colors.blue,
      'question': 'Why is my BPM different sometimes?',
      'answer': 'Your heart rate naturally fluctuates based on activity, stress, caffeine intake, and even your breathing pattern. It is normal to see different results throughout the day.',
    },
    {
      'icon': Icons.verified_user_outlined,
      'color': Colors.green,
      'question': 'Is this app accurate?',
      'answer': 'While PulseTrack uses advanced algorithms, it is intended for wellness purposes only and is not a replacement for medical-grade equipment.',
    },
    {
      'icon': Icons.favorite_outline,
      'color': Colors.red,
      'question': 'What is a normal heart rate?',
      'answer': 'For most adults, a normal resting heart rate ranges from 60 to 100 beats per minute (BPM). Factors like fitness level and age can influence this.',
    },
    {
      'icon': Icons.fitness_center,
      'color': Colors.orange,
      'question': 'How can I improve my heart health?',
      'answer': 'Regular exercise, a balanced diet, adequate sleep, and stress management are key to maintaining a healthy heart.',
    },
    {
      'icon': Icons.lock_outline,
      'color': Colors.indigo,
      'question': 'Is my data safe and secure?',
      'answer': 'Yes, your health data is encrypted and stored securely. We do not share your personal health information with third parties.',
    },
    {
      'icon': Icons.battery_charging_full,
      'color': Colors.teal,
      'question': 'Does scanning drain my battery?',
      'answer': 'The scan uses the camera and flash for a short duration, so the battery impact is minimal—similar to taking a short video.',
    },
    {
      'icon': Icons.history,
      'color': Colors.cyan,
      'question': 'How often should I scan?',
      'answer': 'We recommend scanning twice a day—once in the morning and once in the evening—to get a good baseline of your resting heart rate.',
    },
    {
      'icon': Icons.devices,
      'color': Colors.pink,
      'question': 'Which devices are supported?',
      'answer': 'PulseTrack works on most modern smartphones with a functional camera and flash. Performance may vary on very old devices.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              'FAQs',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              'Find answers to common questions',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _faqs.length + 1,
              itemBuilder: (context, index) {
                if (index == _faqs.length) {
                  return _buildStillHaveQuestions();
                }
                return _buildFaqItem(index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search for questions...',
            hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem(int index) {
    final faq = _faqs[index];
    final bool isExpanded = _expandedIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpanded ? faq['color'].withOpacity(0.3) : Colors.white.withOpacity(0.02),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _expandedIndex = isExpanded ? null : index),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: faq['color'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(faq['icon'], color: faq['color'], size: 20),
            ),
            title: Text(
              faq['question'],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
            ),
            trailing: Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.grey,
            ),
          ),
          if (isExpanded) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: Colors.white.withOpacity(0.05)),
                  const SizedBox(height: 12),
                  Text(
                    faq['answer'],
                    style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.5),
                  ),
                  if (faq['hasIllustration'] == true) ...[
                    const SizedBox(height: 20),
                    _buildScanningIllustration(),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScanningIllustration() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: kIsWeb 
        ? Center(child: Icon(Icons.monitor_heart_outlined, size: 60, color: Colors.purple.withOpacity(0.5)))
        : Image.asset(
            'assets/images/faq_scanning.png',
            height: 120,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.info_outline, color: Colors.grey),
          ),
    );
  }

  Widget _buildStillHaveQuestions() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF121417),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.headset_mic_outlined, color: Colors.purple, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Still have questions?',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Our support team is here to help you.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3F37C9).withOpacity(0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Contact Support', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 14, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
