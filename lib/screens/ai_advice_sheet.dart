import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ai_advice_service.dart';
import '../theme/app_theme.dart';

class AiAdviceSheet extends StatefulWidget {
  final int bpm;
  final String status;

  const AiAdviceSheet({super.key, required this.bpm, required this.status});

  @override
  State<AiAdviceSheet> createState() => _AiAdviceSheetState();
}

class _AiAdviceSheetState extends State<AiAdviceSheet>
    with SingleTickerProviderStateMixin {
  AiAdviceResult? _advice;
  bool _isLoading = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _loadAdvice();
  }

  Future<void> _loadAdvice() async {
    final advice = await AiAdviceService().getAdvice(
      bpm: widget.bpm,
      status: widget.status,
    );
    if (mounted) {
      setState(() {
        _advice = advice;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _statusColor(String label) {
    switch (label) {
      case 'Excellent':
        return const Color(0xFF4CAF50);
      case 'Low':
        return const Color(0xFF64B5F6);
      case 'Normal':
        return const Color(0xFFFFB300);
      case 'Elevated':
        return const Color(0xFFFF7043);
      case 'Alert':
        return const Color(0xFFEF5350);
      default:
        return AppTheme.primaryRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141418),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _isLoading ? _buildLoading() : _buildContent(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final label = _isLoading ? 'Analyzing...' : (_advice?.statusLabel ?? '');
    final color = _isLoading ? Colors.grey : _statusColor(label);

    return Row(
      children: [
        // Pulsing heart icon
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, __) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryRed
                  .withOpacity(0.1 + 0.1 * _pulseController.value),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite,
              color: AppTheme.primaryRed,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.bpm} BPM',
                style: GoogleFonts.outfit(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        // AI badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 12),
              const SizedBox(width: 4),
              Text(
                'AI',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final t = (_pulseController.value + i * 0.3) % 1.0;
                final scale = 0.6 + 0.4 * (t < 0.5 ? t * 2 : (1 - t) * 2);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF6C63FF)
                        .withOpacity(0.3 + 0.7 * scale),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF)
                            .withOpacity(0.4 * scale),
                        blurRadius: 8,
                      )
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'AI is analyzing your health data...',
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final advice = _advice!;
    final statusColor = _statusColor(advice.statusLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Insight card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6C63FF).withOpacity(0.12),
                const Color(0xFF3B82F6).withOpacity(0.07),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: Color(0xFF6C63FF), size: 15),
                  const SizedBox(width: 8),
                  Text(
                    advice.fromAi ? 'AI Health Insight' : 'Health Insight',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF6C63FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                advice.insight,
                style: GoogleFonts.outfit(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Quick Tips
        _buildSection(
          icon: Icons.lightbulb_outline,
          title: 'Quick Tips',
          color: const Color(0xFFFFB300),
          items: advice.tips,
          bulletIcon: Icons.check_circle_outline,
        ),

        const SizedBox(height: 18),

        // Watch For
        _buildSection(
          icon: Icons.warning_amber_outlined,
          title: 'Watch For',
          color: statusColor,
          items: advice.watchFor,
          bulletIcon: Icons.radio_button_unchecked,
        ),

        const SizedBox(height: 28),

        // Close button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              'Got it, Thanks!',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<String> items,
    required IconData bulletIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(bulletIcon,
                      color: color.withOpacity(0.7), size: 15),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
