import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _user;
  String? _errorMessage;
  bool _shouldShowOnboarding = true;
  final ApiService _apiService = ApiService();

  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get shouldShowOnboarding => _shouldShowOnboarding;

  Future<Map<String, dynamic>> login(String email, String password) async {
    _errorMessage = null;
    try {
      final response = await _apiService.login(email, password);
      
      if (response.containsKey('requiresTwoFactor') && response['requiresTwoFactor'] == true) {
        return {'requiresTwoFactor': true, 'email': response['email']};
      }

      if (response.containsKey('requiresVerification') && response['requiresVerification'] == true) {
        // Auto-send OTP for verification
        await _apiService.sendOTP(response['email'] ?? email);
        return {'requiresVerification': true, 'email': response['email'] ?? email};
      }

      _user = UserModel.fromJson(response);
      await _saveUser(_user!);
      notifyListeners();
      return {'success': true};
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return {'success': false, 'message': _errorMessage};
    }
  }

  Future<bool> toggle2FA(bool enabled) async {
    if (_user == null) return false;
    final success = await _apiService.toggle2FA(_user!.id, enabled);
    if (success) {
      _user = UserModel(
        id: _user!.id,
        name: _user!.name,
        email: _user!.email,
        token: _user!.token,
        profileImage: _user!.profileImage,
        dob: _user!.dob,
        gender: _user!.gender,
        healthGoals: _user!.healthGoals,
        achievements: _user!.achievements,
        scanStreak: _user!.scanStreak,
        breathingStreak: _user!.breathingStreak,
        isTwoFactorEnabled: enabled,
      );
      await _saveUser(_user!);
      notifyListeners();
    }
    return success;
  }

  Future<bool> register(String name, String email, String password) async {
    _errorMessage = null;
    try {
      await _apiService.register(name, email, password);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendOTP(String email) async {
    return await _apiService.sendOTP(email);
  }

  Future<bool> verifyOTP(String email, String otp) async {
    _errorMessage = null;
    try {
      final user = await _apiService.verifyOTP(email, otp);
      if (user != null) {
        _user = user;
        await _saveUser(user);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    _errorMessage = null;
    try {
      return await _apiService.forgotPassword(email);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email, String otp, String newPassword) async {
    _errorMessage = null;
    try {
      return await _apiService.resetPassword(email, otp, newPassword);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfileImage(Uint8List bytes, String fileName) async {
    if (_user == null) return false;
    _errorMessage = null;
    
    try {
      final imageUrl = await _apiService.uploadProfileImage(_user!.id, bytes, fileName);
      if (imageUrl != null) {
        _user = UserModel(
          id: _user!.id,
          name: _user!.name,
          email: _user!.email,
          token: _user!.token,
          profileImage: imageUrl,
          dob: _user!.dob,
          gender: _user!.gender,
          healthGoals: _user!.healthGoals,
          achievements: _user!.achievements,
          scanStreak: _user!.scanStreak,
          breathingStreak: _user!.breathingStreak,
          isTwoFactorEnabled: _user!.isTwoFactorEnabled,
        );
        await _saveUser(_user!);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({String? name, String? dob, String? gender}) async {
    if (_user == null) return false;
    
    final updatedUser = await _apiService.updateProfile(
      _user!.id,
      name: name,
      dob: dob,
      gender: gender,
    );

    if (updatedUser != null) {
      _user = updatedUser;
      await _saveUser(_user!);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> updateHealthGoals(HealthGoals goals) async {
    if (_user == null) return false;
    
    final success = await _apiService.updateHealthGoals(_user!.id, goals.toJson());
    if (success) {
      _user = UserModel(
        id: _user!.id,
        name: _user!.name,
        email: _user!.email,
        token: _user!.token,
        profileImage: _user!.profileImage,
        dob: _user!.dob,
        gender: _user!.gender,
        healthGoals: goals,
        achievements: _user!.achievements,
        scanStreak: _user!.scanStreak,
        breathingStreak: _user!.breathingStreak,
        isTwoFactorEnabled: _user!.isTwoFactorEnabled,
      );
      await _saveUser(_user!);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> getHealthStatus() async {
    if (_user == null) return null;
    return await _apiService.getHealthStatus(_user!.id);
  }

  Future<void> syncUserWithServer() async {
    if (_user == null) return;
    final status = await _apiService.getHealthStatus(_user!.id);
    if (status != null) {
      _user = UserModel(
        id: _user!.id,
        name: _user!.name,
        email: _user!.email,
        token: _user!.token,
        profileImage: _user!.profileImage,
        dob: _user!.dob,
        gender: _user!.gender,
        healthGoals: HealthGoals.fromJson(status['healthGoals'] ?? {}),
        achievements: List<String>.from(status['achievements'] ?? []),
        scanStreak: status['scanStreak'] ?? 0,
        breathingStreak: status['breathingStreak'] ?? 0,
        isTwoFactorEnabled: status['isTwoFactorEnabled'] ?? _user!.isTwoFactorEnabled,
      );
      await _saveUser(_user!);
      notifyListeners();
    }
  }

  Future<bool> recordBreathingSession(int durationMinutes) async {
    if (_user == null) return false;
    final success = await _apiService.addBreathingRecord(_user!.id, durationMinutes);
    if (success) {
      notifyListeners();
    }
    return success;
  }

  Future<void> logout() async {
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user'); // Don't clear everything, keep onboarding flag
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _shouldShowOnboarding = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    notifyListeners();
  }

  Future<void> _saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user.toJson()));
  }

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load onboarding status
    _shouldShowOnboarding = !(prefs.getBool('onboarding_completed') ?? false);
    
    final userData = prefs.getString('user');
    if (userData != null) {
      _user = UserModel.fromJson(jsonDecode(userData));
      // Sync with server to get latest data
      syncUserWithServer();
    }
    notifyListeners();
  }



  Future<Map<String, dynamic>> getUserStats() async {
    if (_user == null) return {'avgBpm': 0, 'maxBpm': 0, 'minBpm': 0, 'totalScans': 0};
    return await _apiService.getStats(_user!.id);
  }
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    if (_user == null) return false;
    _errorMessage = null;
    try {
      return await _apiService.changePassword(_user!.id, currentPassword, newPassword);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
  Future<bool> deleteAccount(String password) async {
    if (_user == null) return false;
    _errorMessage = null;
    try {
      final success = await _apiService.deleteAccount(_user!.id, password);
      if (success) {
        await logout();
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
