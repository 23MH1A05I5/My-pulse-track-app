import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/user_model.dart';
import '../models/bpm_record.dart';

class ApiService {
  // Use 10.0.2.2 for Android Emulator, localhost for Web/iOS Simulator
  static String get baseUrl {
    // Use the new deployed Render server URL
    return 'https://pulse-track-backend-xffm.onrender.com/api';

    /* Local development URLs
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    } else if (Platform.isAndroid) {
      return 'http://10.16.52.216:5000/api';
    } else {
      return 'http://localhost:5000/api';
    }
    */
  }

  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data;
      }
      throw Exception(data['message'] ?? 'Login failed');
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  Future<UserModel?> register(
    String name,
    String email,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        return UserModel.fromJson(jsonDecode(response.body));
      }
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Registration failed');
    } catch (e) {
      debugPrint('Register error: $e');
      rethrow;
    }
  }

  Future<bool> sendOTP(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Send OTP error: $e');
      return false;
    }
  }

  Future<UserModel?> verifyOTP(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Verify OTP error: $e');
      return null;
    }
  }

  Future<bool> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (response.statusCode == 200) return true;

      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Forgot password request failed');
    } catch (e) {
      debugPrint('Forgot Password error: $e');
      rethrow;
    }
  }

  Future<bool> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp, 'password': newPassword}),
      );
      if (response.statusCode == 200) return true;

      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Reset password failed');
    } catch (e) {
      debugPrint('Reset Password error: $e');
      rethrow;
    }
  }

  // BPM
  Future<bool> addRecord(BpmRecord record) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bpm/add'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(record.toJson()),
    );
    return response.statusCode == 201;
  }

  Future<List<BpmRecord>> getHistory(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/bpm/history/$userId'));

    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((item) => BpmRecord.fromJson(item)).toList();
    }
    return [];
  }

  Future<BpmRecord?> getLatest(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/bpm/latest/$userId'));

    if (response.statusCode == 200 && response.body.isNotEmpty) {
      return BpmRecord.fromJson(jsonDecode(response.body));
    }
    return null;
  }

  Future<Map<String, dynamic>> getStats(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/bpm/stats/$userId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'avgBpm': 0, 'maxBpm': 0, 'minBpm': 0, 'totalScans': 0};
    } catch (e) {
      debugPrint('Get stats error: $e');
      return {'avgBpm': 0, 'maxBpm': 0, 'minBpm': 0, 'totalScans': 0};
    }
  }

  Future<String?> uploadProfileImage(
    String userId,
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/auth/update-profile-image'),
      );

      request.fields['userId'] = userId;

      // Determine content type based on extension
      final extension = fileName.split('.').last.toLowerCase();
      String mimeType = 'jpeg';
      if (extension == 'png')
        mimeType = 'png';
      else if (extension == 'webp')
        mimeType = 'webp';

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: fileName,
          contentType: MediaType('image', mimeType),
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['profileImage'];
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['message'] ??
              'Server returned status ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      rethrow;
    }
  }

  Future<UserModel?> updateProfile(
    String userId, {
    String? name,
    String? dob,
    String? gender,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/update-profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'name': name,
          'dob': dob,
          'gender': gender,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserModel.fromJson(data['user']);
      }
      return null;
    } catch (e) {
      debugPrint('Update profile error: $e');
      return null;
    }
  }

  Future<bool> updateHealthGoals(
    String userId,
    Map<String, dynamic> goals,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/health-goals'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'healthGoals': goals}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Update health goals error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getHealthStatus(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/health-status/$userId'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Get health status error: $e');
      return null;
    }
  }

  Future<bool> addBreathingRecord(String userId, int duration) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/breathing/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'duration': duration}),
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Add breathing record error: $e');
      return false;
    }
  }

  Future<bool> toggle2FA(String userId, bool enabled) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/toggle-2fa'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'enabled': enabled}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Toggle 2FA error: $e');
      return false;
    }
  }

  Future<bool> changePassword(
    String userId,
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/change-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );
      if (response.statusCode == 200) return true;

      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Change password failed');
    } catch (e) {
      debugPrint('Change Password error: $e');
      rethrow;
    }
  }

  Future<bool> deleteAccount(String userId, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/delete-account'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'password': password}),
      );
      if (response.statusCode == 200) return true;

      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Delete account failed');
    } catch (e) {
      debugPrint('Delete Account error: $e');
      rethrow;
    }
  }

  Future<bool> updateSubscription(
    String userId,
    String subscriptionType,
    DateTime expiry,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/update-subscription'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'subscriptionType': subscriptionType,
          'subscriptionExpiry': expiry.toIso8601String(),
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Update Subscription error: $e');
      return false;
    }
  }
}
