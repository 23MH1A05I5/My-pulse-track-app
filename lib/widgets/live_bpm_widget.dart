/// PulseTrack — Live BPM Widget
/// Animated real-time BPM display used during scanning.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LiveBpmWidget extends StatefulWidget {
  final int? bpm;
  final bool isScanning;
  final double scanProgress;

  const LiveBpmWidget({
    super.key,
    this.bpm,
    required this.isScanning,
    required this.scanProgress,
  });

  @override
  State<LiveBpmWidget> createState() => _LiveBpmWidgetState();
}

class _LiveBpmWidgetState extends State<LiveBpmWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isScanning ? _pulseAnimation.value : 1.0,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: widget.isScanning
                    ? [const Color(0xFFFF4D4D), const Color(0xFF800000)]
                    : [const Color(0xFF1E2430), const Color(0xFF0A0A0F)],
              ),
              boxShadow: widget.isScanning
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF4D4D).withValues(alpha: 0.5),
                        blurRadius: 32,
                        spreadRadius: 8,
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite, color: Colors.white, size: 22),
                const SizedBox(height: 4),
                Text(
                  widget.bpm != null && widget.isScanning
                      ? '${widget.bpm}'
                      : '--',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                Text(
                  'BPM',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.isScanning) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${(widget.scanProgress * 100).toInt()}%',
                    style: GoogleFonts.outfit(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Animated pulsing heart icon for the scan screen header
class PulsingHeartIcon extends StatefulWidget {
  final double size;
  final Color color;

  const PulsingHeartIcon({
    super.key,
    this.size = 32,
    this.color = const Color(0xFFFF4D4D),
  });

  @override
  State<PulsingHeartIcon> createState() => _PulsingHeartIconState();
}

class _PulsingHeartIconState extends State<PulsingHeartIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Icon(Icons.favorite, color: widget.color, size: widget.size),
      ),
    );
  }
}

/// EKG-style animated waveform painter
class EKGWavePainter extends CustomPainter {
  final double progress;
  final Color color;

  EKGWavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final mid = size.height / 2;
    final segments = 6;
    final segW = size.width / segments;

    for (int i = 0; i < segments; i++) {
      final ox = i * segW;
      // Flat → rise → sharp peak → dip → flat
      path.moveTo(ox, mid);
      path.lineTo(ox + segW * 0.3, mid);
      path.lineTo(ox + segW * 0.4, mid - size.height * 0.2);
      path.lineTo(ox + segW * 0.5, mid + size.height * 0.3);
      path.lineTo(ox + segW * 0.55, mid - size.height * 0.5);
      path.lineTo(ox + segW * 0.6, mid + size.height * 0.15);
      path.lineTo(ox + segW * 0.7, mid);
      path.lineTo(ox + segW, mid);
    }

    // Clip to progress for animation effect
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    canvas.drawPath(path, paint);
    canvas.restore();

    // Draw dimmed full path behind
    canvas.drawPath(
      path,
      paint
        ..color = color.withValues(alpha: 0.1)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(EKGWavePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
