/// PulseTrack — Extended BPM Record Model
/// Adds confidence, signal quality, and noise level fields
/// to the existing model for production-grade scan results.
library;

import 'package:flutter/foundation.dart';

class BpmRecord {
  final String? id;
  final String userId;
  final int bpm;
  final String status;
  final int? spo2;
  final int? systolic;
  final int? diastolic;

  // ── New Production Fields ──────────────────────────────────────────────────
  /// Confidence percentage from rPPG algorithm (0–100%)
  final double? confidence;

  /// Signal quality classification from Python processor
  final String? signalQuality;

  /// Noise level (0.0 = clean, 1.0 = very noisy)
  final double? noiseLevel;

  final DateTime timestamp;

  BpmRecord({
    this.id,
    required this.userId,
    required this.bpm,
    required this.status,
    required this.timestamp,
    this.spo2,
    this.systolic,
    this.diastolic,
    this.confidence,
    this.signalQuality,
    this.noiseLevel,
  });

  factory BpmRecord.fromJson(Map<String, dynamic> json) {
    String rawStatus = json['status']?.toString() ?? 'Normal';
    int? packedSpo2;
    int? packedSys;
    int? packedDia;

    // Legacy: unpack vitals from status string "[V:spo2,sys,dia]"
    if (rawStatus.contains('[V:')) {
      try {
        final parts = rawStatus.split('[V:');
        final data = parts[1].replaceAll(']', '').split(',');
        if (data.length >= 3) {
          packedSpo2 = int.tryParse(data[0].trim());
          packedSys = int.tryParse(data[1].trim());
          packedDia = int.tryParse(data[2].trim());
        }
        rawStatus = parts[0].trim();
      } catch (e) {
        debugPrint('Error unpacking vitals: $e');
      }
    }

    return BpmRecord(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      userId: json['userId']?.toString() ?? '',
      bpm: _parseInt(json['bpm']) ?? 0,
      status: rawStatus,
      spo2: packedSpo2 ?? _parseInt(json['spo2']),
      systolic: packedSys ?? _parseInt(json['systolic']),
      diastolic: packedDia ?? _parseInt(json['diastolic']),
      confidence: _parseDouble(json['confidence']),
      signalQuality: json['signalQuality']?.toString(),
      noiseLevel: _parseDouble(json['noiseLevel']),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'].toString()).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    // Preserve legacy vitals packing for old backend compatibility
    String packedStatus = status;
    if (spo2 != null || systolic != null) {
      packedStatus = '$status [V:${spo2 ?? 0},${systolic ?? 0},${diastolic ?? 0}]';
    }

    return {
      'userId': userId,
      'bpm': bpm,
      'status': packedStatus,
      'spo2': spo2,
      'systolic': systolic,
      'diastolic': diastolic,
      'confidence': confidence,
      'signalQuality': signalQuality,
      'noiseLevel': noiseLevel,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // ── Computed Getters ───────────────────────────────────────────────────────

  /// Human-readable confidence string, e.g. "94%"
  String get confidenceLabel =>
      confidence != null ? '${confidence!.toInt()}%' : 'N/A';

  /// Quality label for display
  String get qualityLabel => signalQuality ?? 'N/A';

  /// Whether this was a high-confidence scan
  bool get isHighConfidence => (confidence ?? 0) >= 75;

  // ── Helpers ────────────────────────────────────────────────────────────────
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
