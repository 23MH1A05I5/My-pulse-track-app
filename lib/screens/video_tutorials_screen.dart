
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class VideoTutorialsScreen extends StatelessWidget {
  const VideoTutorialsScreen({super.key});

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
        title: const Text('Video Tutorials', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(),
            const SizedBox(height: 32),
            const Text('All Tutorials', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildVideoItem('How to take an accurate scan', '2:45', 'https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=400'),
            _buildVideoItem('Understanding your heart status', '3:12', 'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?w=400'),
            _buildVideoItem('Breathing exercises for relaxation', '5:00', 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=400'),
            _buildVideoItem('Setting up 2FA for security', '1:30', 'https://images.unsplash.com/photo-1563986768609-322da13575f3?w=400'),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: kIsWeb
          ? const Center(child: Icon(Icons.play_circle_fill, size: 80, color: Colors.purple))
          : ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/video_tutorials_hero.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.video_library, size: 80, color: Colors.purple),
              ),
            ),
    );
  }

  Widget _buildVideoItem(String title, String duration, String thumbUrl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 100,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(image: NetworkImage(thumbUrl), fit: BoxFit.cover),
          ),
          child: const Center(child: Icon(Icons.play_arrow, color: Colors.white)),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(duration, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        trailing: const Icon(Icons.more_vert, color: Colors.grey),
      ),
    );
  }
}
