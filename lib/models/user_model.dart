class UserModel {
  final String id;
  final String name;
  final String email;
  final String? token;
  final String? profileImage;
  final String? dob;
  final String? gender;
  final HealthGoals healthGoals;
  final List<String> achievements;
  final int scanStreak;
  final int breathingStreak;
  final bool isTwoFactorEnabled;


  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.token,
    this.profileImage,
    this.dob,
    this.gender,
    required this.healthGoals,
    this.achievements = const [],
    this.scanStreak = 0,
    this.breathingStreak = 0,
    this.isTwoFactorEnabled = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'],
      name: json['name'],
      email: json['email'],
      token: json['token'],
      profileImage: json['profileImage'],
      dob: json['dob'],
      gender: json['gender'],
      healthGoals: HealthGoals.fromJson(json['healthGoals'] ?? {}),
      achievements: List<String>.from(json['achievements'] ?? []),
      scanStreak: json['scanStreak'] ?? 0,
      breathingStreak: json['breathingStreak'] ?? 0,
      isTwoFactorEnabled: json['isTwoFactorEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'token': token,
      'profileImage': profileImage,
      'dob': dob,
      'gender': gender,
      'healthGoals': healthGoals.toJson(),
      'achievements': achievements,
      'scanStreak': scanStreak,
      'breathingStreak': breathingStreak,
      'isTwoFactorEnabled': isTwoFactorEnabled,
    };
  }
}

class HealthGoals {
  final int minBpm;
  final int maxBpm;
  final int dailyScanGoal;
  final int dailyBreathingGoal;
  final int weeklyBpmTarget;

  HealthGoals({
    required this.minBpm,
    required this.maxBpm,
    required this.dailyScanGoal,
    required this.dailyBreathingGoal,
    required this.weeklyBpmTarget,
  });

  factory HealthGoals.fromJson(Map<String, dynamic> json) {
    final target = json['targetHeartRate'] ?? {};
    return HealthGoals(
      minBpm: target['min'] ?? 60,
      maxBpm: target['max'] ?? 90,
      dailyScanGoal: json['dailyScanGoal'] ?? 3,
      dailyBreathingGoal: json['dailyBreathingGoal'] ?? 5,
      weeklyBpmTarget: json['weeklyBpmTarget'] ?? 85,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'targetHeartRate': {'min': minBpm, 'max': maxBpm},
      'dailyScanGoal': dailyScanGoal,
      'dailyBreathingGoal': dailyBreathingGoal,
      'weeklyBpmTarget': weeklyBpmTarget,
    };
  }
}
