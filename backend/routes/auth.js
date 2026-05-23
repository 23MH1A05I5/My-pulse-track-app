/**
 * PulseTrack — Auth Routes
 * Maps HTTP methods to controller functions with rate limiting and validation.
 */

const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const { validateRequest } = require('../middleware/validate');
const { authLimiter, otpLimiter, resetLimiter } = require('../middleware/rateLimiter');
const authMiddleware = require('../middleware/auth');
const ctrl = require('../controllers/authController');

// Password validation rule (min 8 chars, 1 uppercase, 1 digit)
const passwordRule = body('password')
  .isLength({ min: 8 }).withMessage('Password must be at least 8 characters')
  .matches(/[A-Z]/).withMessage('Password must contain at least one uppercase letter')
  .matches(/\d/).withMessage('Password must contain at least one number');

// Register
router.post('/register', authLimiter, [
  body('name').trim().isLength({ min: 2, max: 100 }).withMessage('Name must be 2-100 characters'),
  body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
  passwordRule,
], validateRequest, ctrl.register);

// Login
router.post('/login', authLimiter, [
  body('email').isEmail().normalizeEmail(),
  body('password').notEmpty(),
], validateRequest, ctrl.login);

// Send OTP
router.post('/send-otp', otpLimiter, [
  body('email').isEmail().normalizeEmail(),
], validateRequest, ctrl.sendOtp);

// Verify OTP
router.post('/verify-otp', otpLimiter, [
  body('email').isEmail().normalizeEmail(),
  body('otp').isLength({ min: 6, max: 6 }).isNumeric().withMessage('OTP must be 6 digits'),
], validateRequest, ctrl.verifyOtp);

// Forgot Password
router.post('/forgot-password', resetLimiter, [
  body('email').isEmail().normalizeEmail(),
], validateRequest, ctrl.forgotPassword);

// Reset Password
router.post('/reset-password', resetLimiter, [
  body('email').isEmail().normalizeEmail(),
  body('otp').isLength({ min: 6, max: 6 }).isNumeric(),
  passwordRule,
], validateRequest, ctrl.resetPassword);

// Refresh Token
router.post('/refresh-token', [
  body('refreshToken').notEmpty(),
], validateRequest, ctrl.refreshToken);

// Protected routes (require valid JWT)
router.post('/change-password', authMiddleware, [
  body('currentPassword').notEmpty(),
  passwordRule.optional({ checkFalsy: true }),
], validateRequest, ctrl.changePassword);

router.post('/update-profile', authMiddleware, ctrl.updateProfile);

router.delete('/delete-account', authMiddleware, [
  body('password').notEmpty(),
], validateRequest, ctrl.deleteAccount);

router.get('/health-status/:userId', authMiddleware, ctrl.getHealthStatus);

module.exports = router;
