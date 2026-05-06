class BpmRecord {
  final String? id;
  final String userId;
  final int bpm;
  final String status;
  final DateTime timestamp;

  BpmRecord({
    this.id,
    required this.userId,
    required this.bpm,
    required this.status,
    required this.timestamp,
  });

  factory BpmRecord.fromJson(Map<String, dynamic> json) {
    return BpmRecord(
      id: json['_id'],
      userId: json['userId'],
      bpm: json['bpm'],
      status: json['status'],
      timestamp: DateTime.parse(json['timestamp']).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'bpm': bpm,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
