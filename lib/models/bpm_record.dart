import 'package:flutter/foundation.dart';

class BpmRecord {
  final String? id;
  final String userId;
  final int bpm;
  final String status;
  final int? spo2;
  final int? systolic;
  final int? diastolic;
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
  });

  factory BpmRecord.fromJson(Map<String, dynamic> json) {
    String rawStatus = json['status']?.toString() ?? 'Normal';
    int? packedSpo2;
    int? packedSys;
    int? packedDia;

    // Smart Unpacking: Check if status contains packed vitals [V:spo2,sys,dia]
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
      bpm: json['bpm'] is int ? json['bpm'] : int.tryParse(json['bpm']?.toString() ?? '0') ?? 0,
      status: rawStatus,
      spo2: packedSpo2 ?? (json['spo2'] is int ? json['spo2'] : int.tryParse(json['spo2']?.toString() ?? '')),
      systolic: packedSys ?? (json['systolic'] is int ? json['systolic'] : int.tryParse(json['systolic']?.toString() ?? '')),
      diastolic: packedDia ?? (json['diastolic'] is int ? json['diastolic'] : int.tryParse(json['diastolic']?.toString() ?? '')),
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']).toLocal() 
          : DateTime.now(),
    );
  }

  // Helper to get clean status for UI
  String get displayStatus => status;

  Map<String, dynamic> toJson() {
    // Smart Packing: Include vitals in status string to ensure they save to old backends
    String packedStatus = status;
    if (spo2 != null || systolic != null) {
      packedStatus = '$status [V:${spo2 ?? 0},${systolic ?? 0},${diastolic ?? 0}]';
    }

    return {
      'userId': userId,
      'bpm': bpm,
      'status': packedStatus,
      'spo2': spo2, // Keep these for future-proofing
      'systolic': systolic,
      'diastolic': diastolic,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
