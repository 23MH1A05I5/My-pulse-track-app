
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

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
        title: const Text('Tips for Better Results', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildHeroSection(),
            const SizedBox(height: 32),
            _buildTipCard(
              Icons.touch_app_outlined,
              Colors.orange,
              'Gentle Touch',
              'Do not press too hard on the camera. Just enough to cover the lens and flash.',
            ),
            _buildTipCard(
              Icons.wb_sunny_outlined,
              Colors.yellow,
              'Good Lighting',
              'Ensure you are in a well-lit area. The flash helps, but steady light improves AI accuracy.',
            ),
            _buildTipCard(
              Icons.airline_seat_flat_outlined,
              Colors.blue,
              'Stay Still',
              'Try to sit or lie down and stay completely still during the 15-20 second scan.',
            ),
            _buildTipCard(
              Icons.timer_outlined,
              Colors.green,
              'Be Consistent',
              'Scan at the same time every day (e.g., right after waking up) for the most accurate trend.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: kIsWeb
          ? const Center(child: Icon(Icons.tips_and_updates_outlined, size: 80, color: Colors.amber))
          : ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.asset(
                'assets/images/health_tips_hero.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.lightbulb, size: 80, color: Colors.amber),
              ),
            ),
    );
  }

  Widget _buildTipCard(IconData icon, Color color, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
