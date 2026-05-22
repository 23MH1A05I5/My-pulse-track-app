/// PulseTrack — Signal Quality Widget
/// Displays the real-time signal quality indicator with animated bars.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/rppg_service.dart';

class SignalQualityWidget extends StatelessWidget {
  final SignalQuality quality;
  final double confidence;
  final int? bpmEstimate;
  final String message;

  const SignalQualityWidget({
    super.key,
    required this.quality,
    required this.confidence,
    this.bpmEstimate,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _qualityColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _qualityColor.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quality header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(_qualityIcon, color: _qualityColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Signal Quality',
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _qualityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  quality.label,
                  style: GoogleFonts.outfit(
                    color: _qualityColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Confidence bar
          Row(
            children: [
              Text(
                'Confidence',
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${confidence.toInt()}%',
                style: GoogleFonts.outfit(
                  color: _qualityColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence / 100,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(_qualityColor),
              minHeight: 6,
            ),
          ),

          // Live BPM estimate
          if (bpmEstimate != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite, color: Color(0xFFFF4D4D), size: 16),
                const SizedBox(width: 6),
                Text(
                  '$bpmEstimate BPM (live)',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),
          Text(
            message,
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color get _qualityColor {
    switch (quality) {
      case SignalQuality.excellent: return const Color(0xFF4ADE80);
      case SignalQuality.good: return const Color(0xFF86EFAC);
      case SignalQuality.fair: return const Color(0xFFFACC15);
      case SignalQuality.poor: return const Color(0xFFFF4D4D);
      case SignalQuality.invalid: return Colors.white38;
    }
  }

  IconData get _qualityIcon {
    switch (quality) {
      case SignalQuality.excellent: return Icons.signal_cellular_alt;
      case SignalQuality.good: return Icons.signal_cellular_alt_2_bar;
      case SignalQuality.fair: return Icons.signal_cellular_alt_1_bar;
      case SignalQuality.poor: return Icons.signal_cellular_off;
      case SignalQuality.invalid: return Icons.signal_cellular_no_sim;
    }
  }
}
