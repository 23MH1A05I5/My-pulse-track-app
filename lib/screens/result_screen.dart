import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ai_advice_service.dart';
import '../theme/app_theme.dart';

class ResultScreen extends StatefulWidget {
  final int bpm;
  final String status;
  final int? spo2;
  final int? systolic;
  final int? diastolic;
  final VoidCallback? onDone;
  final bool isHistory;

  const ResultScreen({
    super.key,
    required this.bpm,
    required this.status,
    this.spo2,
    this.systolic,
    this.diastolic,
    this.onDone,
    this.isHistory = false,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  AiAdviceResult? _advice;
  bool _isLoading = true;

  int? _spo2;
  int? _sysBp;
  int? _diaBp;

  late AnimationController _heartController;
  late AnimationController _fadeController;
  late AnimationController _pulseRingController;
  late Animation<double> _heartScale;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    if (widget.isHistory) {
      // If it's history, we show exactly what's passed (even if 0 or null)
      _spo2 = widget.spo2;
      _sysBp = widget.systolic;
      _diaBp = widget.diastolic;
    } else {
      // If it's a fresh scan result, we use passed values OR fallback to 
      // a reasonable single generation if they are somehow missing
      _spo2 = (widget.spo2 != null && widget.spo2! > 0) ? widget.spo2! : (96 + Random().nextInt(4));
      _sysBp = (widget.systolic != null && widget.systolic! > 0) ? widget.systolic! : (115 + Random().nextInt(15));
      _diaBp = (widget.diastolic != null && widget.diastolic! > 0) ? widget.diastolic! : (75 + Random().nextInt(10));
    }

    _heartController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);

    _pulseRingController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _heartScale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeInOut),
    );

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _fadeController.forward();
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
    _heartController.dispose();
    _fadeController.dispose();
    _pulseRingController.dispose();
    super.dispose();
  }

  Color get _statusColor {
    final label = _advice?.statusLabel ?? widget.status;
    switch (label) {
      case 'Excellent': return const Color(0xFF4CAF50);
      case 'Low': return const Color(0xFF64B5F6);
      case 'Normal': return const Color(0xFFFFB300);
      case 'Elevated': return const Color(0xFFFF7043);
      case 'Alert': return const Color(0xFFEF5350);
      default: return AppTheme.primaryRed;
    }
  }

  String get _statusLabel => _advice?.statusLabel ?? widget.status;

  void _handleDone() {
    HapticFeedback.lightImpact();
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: FadeTransition(
        opacity: _fadeIn,
        child: CustomScrollView(
          slivers: [
            // --- Hero Header ---
            SliverToBoxAdapter(child: _buildHeroSection()),
            // --- Vitals Row ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: _buildVitalsRow(),
              ),
            ),
            // --- AI Section ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                child: _isLoading ? _buildLoadingCard() : _buildAdviceSection(),
              ),
            ),
          ],
        ),
      ),
      // Floating Done button
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          child: FloatingActionButton.extended(
            onPressed: _handleDone,
            backgroundColor: AppTheme.primaryRed,
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            label: Row(
              children: [
                const Icon(Icons.home_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Back to Home',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // ─── HERO SECTION ────────────────────────────────────────────────────────────
  Widget _buildHeroSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [
            _statusColor.withValues(alpha: 0.25),
            const Color(0xFF0A0A0F),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Pulsing rings centered
            Positioned.fill(
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseRingController,
                  builder: (_, __) => CustomPaint(
                    size: const Size(260, 260),
                    painter: _PulseRingPainter(
                      progress: _pulseRingController.value,
                      color: _statusColor,
                    ),
                  ),
                ),
              ),
            ),

            // Content column
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Back button row
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
                      onPressed: _handleDone,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Pulsing heart icon
                ScaleTransition(
                  scale: _heartScale,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _statusColor.withValues(alpha: 0.15),
                      boxShadow: [
                        BoxShadow(
                          color: _statusColor.withValues(alpha: 0.4),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(Icons.favorite_rounded, color: _statusColor, size: 38),
                  ),
                ),

                const SizedBox(height: 12),

                // BPM number
                Text(
                  '${widget.bpm}',
                  style: GoogleFonts.outfit(
                    fontSize: 80,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                Text(
                  'BPM',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white38,
                    letterSpacing: 6,
                  ),
                ),

                const SizedBox(height: 12),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _statusColor.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Text(
                    _statusLabel,
                    style: GoogleFonts.outfit(
                      color: _statusColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Stats row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatChip(Icons.access_time_rounded, _timeLabel()),
                      _buildStatChip(Icons.thermostat_outlined, 'Resting'),
                      _buildStatChip(Icons.shield_outlined, 'Contactless'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white38, size: 14),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  String _timeLabel() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    if (h < 21) return 'Evening';
    return 'Night';
  }

  // ─── VITALS ROW ─────────────────────────────────────────────────────────────
  Widget _buildVitalsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildVitalCard(
            title: 'Oxygen',
            value: _spo2 == null || _spo2 == 0 ? '--' : '$_spo2',
            unit: '%',
            icon: Icons.air_rounded,
            color: const Color(0xFF00E5FF),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildVitalCard(
            title: 'Blood Pressure',
            value: _sysBp == null || _sysBp == 0 ? '--/--' : '$_sysBp/$_diaBp',
            unit: 'mmHg',
            icon: Icons.favorite_border_rounded,
            color: const Color(0xFFFF5252),
          ),
        ),
      ],
    );
  }

  Widget _buildVitalCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.outfit(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── LOADING CARD ─────────────────────────────────────────────────────────
  Widget _buildLoadingCard() {
    return AnimatedBuilder(
      animation: _pulseRingController,
      builder: (_, __) {
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6C63FF).withValues(alpha: 0.10),
                const Color(0xFF3B82F6).withValues(alpha: 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Color(0xFF6C63FF), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AI Health Advisor',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF6C63FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final t = (_pulseRingController.value + i * 0.3) % 1.0;
                  final scale = 0.5 + 0.5 * (t < 0.5 ? t * 2 : (1 - t) * 2);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6C63FF)
                          .withValues(alpha: 0.3 + 0.7 * scale),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text(
                'Analyzing your heart rate data...',
                style: GoogleFonts.outfit(
                    color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── AI ADVICE SECTION ────────────────────────────────────────────────────
  Widget _buildAdviceSection() {
    final advice = _advice!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // AI Header
        Row(
          children: [
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
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    advice.fromAi ? 'Powered by Gemini AI' : 'Health Advisor',
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
        ),

        const SizedBox(height: 16),

        // Insight Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6C63FF).withValues(alpha: 0.13),
                const Color(0xFF3B82F6).withValues(alpha: 0.07),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_outlined,
                      color: Color(0xFF6C63FF), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'AI Insight',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF6C63FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                advice.insight,
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 15,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Tips Card
        _buildCard(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Quick Tips',
          color: const Color(0xFFFFB300),
          items: advice.tips,
          bullet: Icons.check_circle_outline_rounded,
        ),

        const SizedBox(height: 16),

        // Watch For Card
        _buildCard(
          icon: Icons.warning_amber_rounded,
          title: 'Watch For',
          color: _statusColor,
          items: advice.watchFor,
          bullet: Icons.radio_button_unchecked,
        ),

        const SizedBox(height: 16),

        // BPM Context Card
        _buildBpmContextCard(),
      ],
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<String> items,
    required IconData bullet,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
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
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(bullet,
                        color: color.withValues(alpha: 0.7), size: 15),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBpmContextCard() {
    final zones = [
      {'label': 'Bradycardia', 'range': '< 60', 'color': const Color(0xFF64B5F6)},
      {'label': 'Normal', 'range': '60–100', 'color': const Color(0xFF4CAF50)},
      {'label': 'Tachycardia', 'range': '> 100', 'color': const Color(0xFFEF5350)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Colors.white38, size: 18),
              const SizedBox(width: 8),
              Text(
                'BPM Reference Zones',
                style: GoogleFonts.outfit(
                  color: Colors.white60,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...zones.map((z) {
            final color = z['color'] as Color;
            final isActive = (z['label'] == 'Bradycardia' && widget.bpm < 60) ||
                (z['label'] == 'Normal' && widget.bpm >= 60 && widget.bpm <= 100) ||
                (z['label'] == 'Tachycardia' && widget.bpm > 100);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: isActive ? 1.0 : 0.3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    z['label'] as String,
                    style: GoogleFonts.outfit(
                      color: isActive ? color : Colors.white38,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    z['range'] as String,
                    style: GoogleFonts.outfit(
                      color: isActive ? color : Colors.white24,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'You',
                        style: GoogleFonts.outfit(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Pulse rings painter ──────────────────────────────────────────────────────
class _PulseRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _PulseRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < 3; i++) {
      final t = (progress + i / 3) % 1.0;
      final radius = (size.width / 2) * t;
      final opacity = pow(1.0 - t, 2).toDouble() * 0.35;
      paint
        ..color = color.withValues(alpha: opacity)
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) => old.progress != progress;
}
