/**
 * PulseTrack — Breathing Routes
 */
const express = require('express');
const router = express.Router();
const { apiLimiter } = require('../middleware/rateLimiter');
const mongoose = require('mongoose');

// Minimal inline schema for breathing records
const breathingSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  duration: { type: Number, required: true },   // minutes
  timestamp: { type: Date, default: Date.now },
}, { timestamps: false });

const Breathing = mongoose.models.Breathing || mongoose.model('Breathing', breathingSchema);

// Add breathing session
router.post('/add', apiLimiter, async (req, res) => {
  try {
    const { userId, duration } = req.body;
    if (!userId || !duration) {
      return res.status(400).json({ success: false, message: 'userId and duration required' });
    }
    const record = await Breathing.create({ userId, duration });
    res.status(201).json({ success: true, record });
  } catch (err) {
    console.error('Add breathing error:', err);
    res.status(500).json({ success: false, message: 'Failed to save breathing record' });
  }
});

// Get breathing history
router.get('/history/:userId', apiLimiter, async (req, res) => {
  try {
    const records = await Breathing.find({ userId: req.params.userId })
      .sort({ timestamp: -1 })
      .limit(50)
      .lean();
    res.json(records);
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to fetch breathing history' });
  }
});

module.exports = router;
