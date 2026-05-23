/**
 * PulseTrack — User Mongoose Model
 * Secure schema with:
 *  - Passwords and OTPs excluded from default queries (+password)
 *  - Lean toPublicJSON() helper
 *  - Audit fields (createdAt, updatedAt)
 */

const mongoose = require('mongoose');

const HealthGoalsSchema = new mongoose.Schema({
  targetHeartRate: {
    min: { type: Number, default: 60 },
    max: { type: Number, default: 90 },
  },
  dailyScanGoal: { type: Number, default: 3 },
  dailyBreathingGoal: { type: Number, default: 5 },
  weeklyBpmTarget: { type: Number, default: 85 },
}, { _id: false });

const UserSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true, maxlength: 100 },
  email: { type: String, required: true, unique: true, lowercase: true, trim: true },
  
  // Sensitive fields — excluded from default queries
  password: { type: String, select: false },
  otp: { type: String, select: false },
  otpExpiry: { type: Date, select: false },
  otpAttempts: { type: Number, default: 0, select: false },
  
  isVerified: { type: Boolean, default: false },
  isTwoFactorEnabled: { type: Boolean, default: false },
  
  profileImage: { type: String },
  dob: { type: String },
  gender: { type: String, enum: ['Male', 'Female', 'Other', ''] },
  
  healthGoals: { type: HealthGoalsSchema, default: () => ({}) },
  achievements: [{ type: String }],
  scanStreak: { type: Number, default: 0 },
  breathingStreak: { type: Number, default: 0 },
}, {
  timestamps: true,  // createdAt, updatedAt
});

// ── Indexes ────────────────────────────────────────────────────────────────────
UserSchema.index({ email: 1 }, { unique: true });

// ── Methods ────────────────────────────────────────────────────────────────────
UserSchema.methods.toPublicJSON = function () {
  return {
    id: this._id.toString(),
    name: this.name,
    email: this.email,
    profileImage: this.profileImage,
    dob: this.dob,
    gender: this.gender,
    healthGoals: this.healthGoals,
    achievements: this.achievements,
    scanStreak: this.scanStreak,
    breathingStreak: this.breathingStreak,
    isTwoFactorEnabled: this.isTwoFactorEnabled,
    isVerified: this.isVerified,
  };
};

module.exports = mongoose.model('User', UserSchema);
