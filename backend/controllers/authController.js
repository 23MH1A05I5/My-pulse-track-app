/**
 * PulseTrack — Auth Controller (Production)
 * Handles: register, login, OTP, refresh token, forgot/reset password,
 *          profile update, 2FA toggle, change password, delete account.
 */

const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const User = require('../models/User');
const { signAccessToken, signRefreshToken, verifyRefreshToken } = require('../utils/jwt');
const { sendOTPEmail, sendPasswordResetEmail } = require('../services/emailService');

const OTP_EXPIRY_MS = 10 * 60 * 1000;      // 10 minutes
const OTP_MAX_ATTEMPTS = 5;
const BCRYPT_ROUNDS = 12;

// ── Register ──────────────────────────────────────────────────────────────────
async function register(req, res) {
  try {
    const { name, email, password } = req.body;

    const existing = await User.findOne({ email: email.toLowerCase() });
    if (existing) {
      return res.status(409).json({ success: false, message: 'Email already registered' });
    }

    const hashedPassword = await bcrypt.hash(password, BCRYPT_ROUNDS);
    const otp = _generateOtp();
    const otpHash = await bcrypt.hash(otp, 8);

    const user = await User.create({
      name: name.trim(),
      email: email.toLowerCase(),
      password: hashedPassword,
      otp: otpHash,
      otpExpiry: new Date(Date.now() + OTP_EXPIRY_MS),
      otpAttempts: 0,
      isVerified: false,
    });

    await sendOTPEmail(email, otp, name);

    res.status(201).json({
      success: true,
      message: 'Registration successful — check your email for the OTP',
      email: user.email,
    });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ success: false, message: 'Registration failed' });
  }
}

// ── Login ─────────────────────────────────────────────────────────────────────
async function login(req, res) {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email: email.toLowerCase() }).select('+password');
    if (!user) {
      // Constant-time response to prevent user enumeration
      await bcrypt.compare(password, '$2b$12$invalidhashpadding00000000000000000000000000000000000');
      return res.status(401).json({ success: false, message: 'Invalid email or password' });
    }

    const passwordMatch = await bcrypt.compare(password, user.password);
    if (!passwordMatch) {
      return res.status(401).json({ success: false, message: 'Invalid email or password' });
    }

    if (!user.isVerified) {
      // Auto-resend OTP
      const otp = _generateOtp();
      const otpHash = await bcrypt.hash(otp, 8);
      user.otp = otpHash;
      user.otpExpiry = new Date(Date.now() + OTP_EXPIRY_MS);
      user.otpAttempts = 0;
      await user.save();
      await sendOTPEmail(user.email, otp, user.name);

      return res.status(401).json({
        success: false,
        message: 'Please verify your email first — a new OTP has been sent',
        requiresVerification: true,
        email: user.email,
      });
    }

    if (user.isTwoFactorEnabled) {
      const otp = _generateOtp();
      const otpHash = await bcrypt.hash(otp, 8);
      user.otp = otpHash;
      user.otpExpiry = new Date(Date.now() + OTP_EXPIRY_MS);
      user.otpAttempts = 0;
      await user.save();
      await sendOTPEmail(user.email, otp, user.name, '2FA');

      return res.status(200).json({
        success: true,
        requiresTwoFactor: true,
        email: user.email,
      });
    }

    const tokens = _issueTokens(user);
    res.json({ ...tokens, ...user.toPublicJSON() });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ success: false, message: 'Login failed' });
  }
}

// ── Send OTP ──────────────────────────────────────────────────────────────────
async function sendOtp(req, res) {
  try {
    const { email } = req.body;
    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    const otp = _generateOtp();
    const otpHash = await bcrypt.hash(otp, 8);
    user.otp = otpHash;
    user.otpExpiry = new Date(Date.now() + OTP_EXPIRY_MS);
    user.otpAttempts = 0;
    await user.save();

    await sendOTPEmail(email, otp, user.name);
    res.json({ success: true, message: 'OTP sent to your email' });
  } catch (err) {
    console.error('Send OTP error:', err);
    res.status(500).json({ success: false, message: 'Failed to send OTP' });
  }
}

// ── Verify OTP ────────────────────────────────────────────────────────────────
async function verifyOtp(req, res) {
  try {
    const { email, otp } = req.body;
    const user = await User.findOne({ email: email.toLowerCase() }).select('+otp +otpExpiry +otpAttempts');

    if (!user || !user.otp) {
      return res.status(400).json({ success: false, message: 'Invalid or expired OTP' });
    }

    // Check expiry
    if (user.otpExpiry < new Date()) {
      return res.status(400).json({ success: false, message: 'OTP expired — request a new one', code: 'OTP_EXPIRED' });
    }

    // Check max attempts (brute-force protection)
    if (user.otpAttempts >= OTP_MAX_ATTEMPTS) {
      return res.status(429).json({ success: false, message: 'Too many OTP attempts — request a new OTP', code: 'OTP_LOCKED' });
    }

    const isMatch = await bcrypt.compare(otp, user.otp);
    if (!isMatch) {
      user.otpAttempts += 1;
      await user.save();
      const remaining = OTP_MAX_ATTEMPTS - user.otpAttempts;
      return res.status(400).json({
        success: false,
        message: `Incorrect OTP — ${remaining} attempt${remaining !== 1 ? 's' : ''} remaining`,
        code: 'OTP_WRONG',
      });
    }

    // OTP valid — verify user and clear OTP
    user.isVerified = true;
    user.otp = undefined;
    user.otpExpiry = undefined;
    user.otpAttempts = 0;
    await user.save();

    const tokens = _issueTokens(user);
    res.json({ success: true, ...tokens, ...user.toPublicJSON() });
  } catch (err) {
    console.error('Verify OTP error:', err);
    res.status(500).json({ success: false, message: 'OTP verification failed' });
  }
}

// ── Forgot Password ───────────────────────────────────────────────────────────
async function forgotPassword(req, res) {
  try {
    const { email } = req.body;
    const user = await User.findOne({ email: email.toLowerCase() });

    // Always respond 200 to prevent email enumeration
    if (!user) {
      return res.json({ success: true, message: 'If that email is registered, a reset OTP has been sent' });
    }

    const otp = _generateOtp();
    const otpHash = await bcrypt.hash(otp, 8);
    user.otp = otpHash;
    user.otpExpiry = new Date(Date.now() + OTP_EXPIRY_MS);
    user.otpAttempts = 0;
    await user.save();

    await sendPasswordResetEmail(email, otp, user.name);
    res.json({ success: true, message: 'If that email is registered, a reset OTP has been sent' });
  } catch (err) {
    console.error('Forgot password error:', err);
    res.status(500).json({ success: false, message: 'Failed to process request' });
  }
}

// ── Reset Password ────────────────────────────────────────────────────────────
async function resetPassword(req, res) {
  try {
    const { email, otp, password } = req.body;
    const user = await User.findOne({ email: email.toLowerCase() }).select('+otp +otpExpiry +otpAttempts +password');

    if (!user || !user.otp || user.otpExpiry < new Date()) {
      return res.status(400).json({ success: false, message: 'Invalid or expired OTP' });
    }

    if (user.otpAttempts >= OTP_MAX_ATTEMPTS) {
      return res.status(429).json({ success: false, message: 'Too many attempts — request a new OTP' });
    }

    const isMatch = await bcrypt.compare(otp, user.otp);
    if (!isMatch) {
      user.otpAttempts += 1;
      await user.save();
      return res.status(400).json({ success: false, message: 'Incorrect OTP' });
    }

    user.password = await bcrypt.hash(password, BCRYPT_ROUNDS);
    user.otp = undefined;
    user.otpExpiry = undefined;
    user.otpAttempts = 0;
    await user.save();

    res.json({ success: true, message: 'Password reset successfully' });
  } catch (err) {
    console.error('Reset password error:', err);
    res.status(500).json({ success: false, message: 'Password reset failed' });
  }
}

// ── Refresh Token ─────────────────────────────────────────────────────────────
async function refreshToken(req, res) {
  try {
    const { refreshToken: token } = req.body;
    if (!token) return res.status(401).json({ success: false, message: 'Refresh token required' });

    const decoded = verifyRefreshToken(token);
    const user = await User.findById(decoded.id);
    if (!user) return res.status(401).json({ success: false, message: 'User not found' });

    const tokens = _issueTokens(user);
    res.json({ success: true, ...tokens });
  } catch (err) {
    res.status(401).json({ success: false, message: 'Invalid or expired refresh token' });
  }
}

// ── Change Password ───────────────────────────────────────────────────────────
async function changePassword(req, res) {
  try {
    const { userId, currentPassword, newPassword } = req.body;
    const user = await User.findById(userId).select('+password');
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    const match = await bcrypt.compare(currentPassword, user.password);
    if (!match) return res.status(401).json({ success: false, message: 'Current password is incorrect' });

    user.password = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);
    await user.save();
    res.json({ success: true, message: 'Password changed successfully' });
  } catch (err) {
    console.error('Change password error:', err);
    res.status(500).json({ success: false, message: 'Failed to change password' });
  }
}

// ── Update Profile ────────────────────────────────────────────────────────────
async function updateProfile(req, res) {
  try {
    const { userId, name, dob, gender } = req.body;
    const user = await User.findByIdAndUpdate(
      userId,
      { ...(name && { name }), ...(dob && { dob }), ...(gender && { gender }) },
      { new: true, runValidators: true }
    );
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, user: user.toPublicJSON() });
  } catch (err) {
    console.error('Update profile error:', err);
    res.status(500).json({ success: false, message: 'Failed to update profile' });
  }
}

// ── Delete Account ────────────────────────────────────────────────────────────
async function deleteAccount(req, res) {
  try {
    const { userId, password } = req.body;
    const user = await User.findById(userId).select('+password');
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    const match = await bcrypt.compare(password, user.password);
    if (!match) return res.status(401).json({ success: false, message: 'Incorrect password' });

    await User.findByIdAndDelete(userId);
    res.json({ success: true, message: 'Account deleted successfully' });
  } catch (err) {
    console.error('Delete account error:', err);
    res.status(500).json({ success: false, message: 'Failed to delete account' });
  }
}

// ── Health Status ─────────────────────────────────────────────────────────────
async function getHealthStatus(req, res) {
  try {
    const user = await User.findById(req.params.userId);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({
      healthGoals: user.healthGoals,
      achievements: user.achievements,
      scanStreak: user.scanStreak,
      breathingStreak: user.breathingStreak,
      isTwoFactorEnabled: user.isTwoFactorEnabled,
    });
  } catch (err) {
    console.error('Health status error:', err);
    res.status(500).json({ success: false, message: 'Failed to get health status' });
  }
}

// ── Internal Helpers ──────────────────────────────────────────────────────────
function _generateOtp() {
  return crypto.randomInt(100000, 999999).toString();
}

function _issueTokens(user) {
  const payload = { id: user._id.toString(), email: user.email };
  return {
    token: signAccessToken(payload),
    refreshToken: signRefreshToken(payload),
  };
}

module.exports = {
  register,
  login,
  sendOtp,
  verifyOtp,
  forgotPassword,
  resetPassword,
  refreshToken,
  changePassword,
  updateProfile,
  deleteAccount,
  getHealthStatus,
};
