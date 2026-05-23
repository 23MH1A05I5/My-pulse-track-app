/**
 * PulseTrack — BpmRecord Mongoose Model
 * Stores each heart rate scan result with all vitals.
 */

const mongoose = require('mongoose');

const BpmRecordSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  bpm: { type: Number, required: true, min: 20, max: 300 },
  status: { type: String, required: true, enum: ['Normal', 'Low', 'High', 'Alert', 'Excellent'] },
  spo2: { type: Number, min: 50, max: 100 },
  systolic: { type: Number, min: 60, max: 250 },
  diastolic: { type: Number, min: 40, max: 150 },
  confidence: { type: Number, min: 0, max: 100 },
  signalQuality: { type: String, enum: ['Excellent', 'Good', 'Fair', 'Poor', 'Invalid'] },
  noiseLevel: { type: Number },
  timestamp: { type: Date, default: Date.now, index: true },
}, {
  timestamps: false,
});

// ── Indexes ────────────────────────────────────────────────────────────────────
BpmRecordSchema.index({ userId: 1, timestamp: -1 });

module.exports = mongoose.model('BpmRecord', BpmRecordSchema);
