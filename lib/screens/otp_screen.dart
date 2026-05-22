/// PulseTrack — Upgraded OTP Screen
/// Production features:
///  - 10-minute expiry countdown
///  - Max-attempt lockout feedback from server
///  - Resend cooldown (60s)
///  - Auto-submit on final digit
///  - Clear error messaging per server response code
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import 'reset_password_screen.dart';
import 'main_nav_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final bool isForgotPassword;

  const OtpScreen({
    super.key,
    required this.email,
    this.isForgotPassword = false,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;

  // Resend cooldown
  int _resendCooldown = 60;
  Timer? _resendTimer;

  // OTP expiry countdown (10 minutes)
  int _expirySeconds = 600;
  Timer? _expiryTimer;

  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _startResendCooldown();
    _startExpiryCountdown();
  }

  void _startResendCooldown() {
    _resendCooldown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_resendCooldown <= 0) { t.cancel(); return; }
      setState(() => _resendCooldown--);
    });
  }

  void _startExpiryCountdown() {
    _expirySeconds = 600;
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_expirySeconds <= 0) {
        t.cancel();
        setState(() => _errorMessage = 'OTP expired — tap Resend to get a new code.');
        return;
      }
      setState(() => _expirySeconds--);
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _expiryTimer?.cancel();
    _shakeController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpValue => _controllers.map((c) => c.text).join();

  String get _expiryLabel {
    final m = _expirySeconds ~/ 60;
    final s = _expirySeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _clearBoxes() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _shakeAndError(String msg) {
    HapticFeedback.mediumImpact();
    setState(() => _errorMessage = msg);
    _shakeController.forward(from: 0);
  }

  Future<void> _resendOtp() async {
    if (_resendCooldown > 0 || _isResending) return;
    setState(() { _isResending = true; _errorMessage = null; });

    final success = await context.read<AuthProvider>().sendOTP(widget.email);

    if (!mounted) return;
    setState(() => _isResending = false);

    if (success) {
      _clearBoxes();
      _startResendCooldown();
      _startExpiryCountdown();
      _showSnack('New OTP sent to ${widget.email}', isSuccess: true);
    } else {
      _showSnack('Failed to resend OTP — check your connection');
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpValue;
    final validationError = Validators.otp(otp);
    if (validationError != null) {
      _shakeAndError(validationError);
      return;
    }

    if (_expirySeconds <= 0) {
      _shakeAndError('OTP expired — request a new one first.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    final success = await context.read<AuthProvider>().verifyOTP(widget.email, otp);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _expiryTimer?.cancel();
      if (widget.isForgotPassword) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(email: widget.email, otp: otp),
          ),
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavScreen()),
          (_) => false,
        );
      }
    } else {
      _clearBoxes();
      final errorMsg = context.read<AuthProvider>().errorMessage ?? 'Invalid OTP — try again';
      // Parse backend-specific codes
      if (errorMsg.toLowerCase().contains('expired')) {
        _shakeAndError('OTP expired — tap Resend to get a new code.');
      } else if (errorMsg.toLowerCase().contains('locked') || errorMsg.toLowerCase().contains('too many')) {
        _shakeAndError('Too many attempts — request a new OTP.');
      } else if (errorMsg.toLowerCase().contains('remaining')) {
        _shakeAndError(errorMsg); // "3 attempts remaining"
      } else {
        _shakeAndError(errorMsg);
      }
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit()),
      backgroundColor: isSuccess ? const Color(0xFF16A34A) : Colors.red[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),

            // Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryRed, AppTheme.darkRed],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryRed.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.mark_email_read_outlined,
                  color: Colors.white, size: 34),
            ),
            const SizedBox(height: 24),

            Text(
              widget.isForgotPassword ? 'Reset Password' : 'Verify Your Email',
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Enter the 6-digit code sent to',
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              widget.email,
              style: GoogleFonts.outfit(
                color: AppTheme.primaryRed,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),

            // Expiry timer
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: _expirySeconds < 60 ? Colors.red : Colors.white38,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Code expires in $_expiryLabel',
                  style: GoogleFonts.outfit(
                    color: _expirySeconds < 60 ? Colors.redAccent : Colors.white38,
                    fontSize: 13,
                    fontWeight: _expirySeconds < 60 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // OTP boxes with shake animation
            AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final dx = _shakeController.value < 0.5
                    ? _shakeController.value * 2 * 8
                    : (1 - _shakeController.value) * 2 * 8;
                return Transform.translate(
                  offset: Offset(dx * ((_shakeController.value * 10).toInt().isEven ? 1 : -1), 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, _buildOtpBox),
              ),
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 36),

            // Verify button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_isLoading || _expirySeconds <= 0) ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  disabledBackgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        'Verify Code',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Resend button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive the code? ",
                  style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
                ),
                _isResending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.primaryRed),
                      )
                    : GestureDetector(
                        onTap: _resendCooldown > 0 ? null : _resendOtp,
                        child: Text(
                          _resendCooldown > 0
                              ? 'Resend in ${_resendCooldown}s'
                              : 'Resend Code',
                          style: GoogleFonts.outfit(
                            color: _resendCooldown > 0
                                ? Colors.white24
                                : AppTheme.primaryRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 48,
      height: 58,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161A22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _errorMessage != null
                ? Colors.redAccent.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            // Clear error on any input
            if (_errorMessage != null) setState(() => _errorMessage = null);

            if (value.isNotEmpty && index < 5) {
              _focusNodes[index + 1].requestFocus();
            } else if (value.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
            // Auto-submit when last digit entered
            if (index == 5 && value.isNotEmpty) {
              _verifyOtp();
            }
          },
        ),
      ),
    );
  }
}
