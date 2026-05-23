/**
 * PulseTrack — Rate Limiters
 * Tiered rate limits for different endpoint sensitivity levels.
 */

const rateLimit = require('express-rate-limit');

// Auth endpoints: strict limits to prevent brute-force
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20,
  message: { success: false, message: 'Too many authentication attempts — try again in 15 minutes' },
  standardHeaders: true,
  legacyHeaders: false,
});

// OTP endpoint: very strict (prevent OTP guessing)
const otpLimiter = rateLimit({
  windowMs: 10 * 60 * 1000, // 10 minutes
  max: 10,
  message: { success: false, message: 'Too many OTP attempts — try again in 10 minutes' },
  standardHeaders: true,
  legacyHeaders: false,
});

// Password reset: strict
const resetLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 5,
  message: { success: false, message: 'Too many password reset requests — try again in 1 hour' },
  standardHeaders: true,
  legacyHeaders: false,
});

// API endpoints: moderate limits
const apiLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 60,
  message: { success: false, message: 'Too many requests — slow down' },
  standardHeaders: true,
  legacyHeaders: false,
});

module.exports = { authLimiter, otpLimiter, resetLimiter, apiLimiter };
