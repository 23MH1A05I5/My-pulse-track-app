/**
 * PulseTrack — BPM Routes
 */

const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const { apiLimiter } = require('../middleware/rateLimiter');
const BpmRecord = require('../models/BpmRecord');

// Add BPM record
router.post('/add', apiLimiter, async (req, res) => {
  try {
    const { userId, bpm, status, spo2, systolic, diastolic, confidence, signalQuality, noiseLevel, timestamp } = req.body;
    if (!userId || !bpm || !status) {
      return res.status(400).json({ success: false, message: 'userId, bpm, and status are required' });
    }
    const record = await BpmRecord.create({
      userId, bpm, status, spo2, systolic, diastolic,
      confidence, signalQuality, noiseLevel,
      timestamp: timestamp ? new Date(timestamp) : new Date(),
    });
    res.status(201).json(record);
  } catch (err) {
    console.error('Add BPM error:', err);
    res.status(500).json({ success: false, message: 'Failed to save record' });
  }
});

// Get history
router.get('/history/:userId', apiLimiter, async (req, res) => {
  try {
    const records = await BpmRecord.find({ userId: req.params.userId })
      .sort({ timestamp: -1 })
      .limit(100)
      .lean();
    res.json(records);
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to fetch history' });
  }
});

// Get latest
router.get('/latest/:userId', apiLimiter, async (req, res) => {
  try {
    const record = await BpmRecord.findOne({ userId: req.params.userId })
      .sort({ timestamp: -1 })
      .lean();
    if (!record) return res.status(404).json({ success: false, message: 'No records found' });
    res.json(record);
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to fetch record' });
  }
});

// Get stats
router.get('/stats/:userId', apiLimiter, async (req, res) => {
  try {
    const result = await BpmRecord.aggregate([
      { $match: { userId: require('mongoose').Types.ObjectId.createFromHexString(req.params.userId) } },
      { $group: {
        _id: null,
        avgBpm: { $avg: '$bpm' },
        maxBpm: { $max: '$bpm' },
        minBpm: { $min: '$bpm' },
        totalScans: { $sum: 1 },
        avgConfidence: { $avg: '$confidence' },
      }},
    ]);
    if (!result.length) return res.json({ avgBpm: 0, maxBpm: 0, minBpm: 0, totalScans: 0 });
    const stats = result[0];
    res.json({
      avgBpm: Math.round(stats.avgBpm || 0),
      maxBpm: stats.maxBpm || 0,
      minBpm: stats.minBpm || 0,
      totalScans: stats.totalScans || 0,
      avgConfidence: Math.round(stats.avgConfidence || 0),
    });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to compute stats' });
  }
});

module.exports = router;
