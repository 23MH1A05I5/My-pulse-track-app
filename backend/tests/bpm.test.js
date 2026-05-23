/**
 * PulseTrack — Jest BPM API Tests
 * Tests the BPM endpoints: add record, get history, get latest, get stats.
 */

const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../server');
const BpmRecord = require('../models/BpmRecord');

const TEST_USER_ID = new mongoose.Types.ObjectId().toString();

const SAMPLE_RECORD = {
  userId: TEST_USER_ID,
  bpm: 72,
  status: 'Normal',
  spo2: 98,
  systolic: 120,
  diastolic: 80,
  confidence: 87.5,
  signalQuality: 'Excellent',
};

beforeAll(async () => {
  await mongoose.connect(process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/pulsetrack_test');
});

afterAll(async () => {
  await BpmRecord.deleteMany({ userId: TEST_USER_ID });
  await mongoose.disconnect();
});

describe('POST /api/bpm/add', () => {
  it('should add a BPM record', async () => {
    const res = await request(app)
      .post('/api/bpm/add')
      .send(SAMPLE_RECORD)
      .expect(201);

    expect(res.body.bpm).toBe(72);
    expect(res.body.status).toBe('Normal');
    expect(res.body.confidence).toBe(87.5);
    expect(res.body.signalQuality).toBe('Excellent');
  });

  it('should reject missing required fields', async () => {
    await request(app)
      .post('/api/bpm/add')
      .send({ userId: TEST_USER_ID }) // missing bpm and status
      .expect(400);
  });

  it('should add multiple records', async () => {
    await request(app).post('/api/bpm/add').send({ ...SAMPLE_RECORD, bpm: 85, status: 'Normal' });
    await request(app).post('/api/bpm/add').send({ ...SAMPLE_RECORD, bpm: 105, status: 'High' });
  });
});

describe('GET /api/bpm/history/:userId', () => {
  it('should return history for the user', async () => {
    const res = await request(app)
      .get(`/api/bpm/history/${TEST_USER_ID}`)
      .expect(200);

    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);
  });

  it('should return empty array for unknown user', async () => {
    const unknownId = new mongoose.Types.ObjectId().toString();
    const res = await request(app)
      .get(`/api/bpm/history/${unknownId}`)
      .expect(200);

    expect(res.body).toEqual([]);
  });
});

describe('GET /api/bpm/latest/:userId', () => {
  it('should return the most recent record', async () => {
    const res = await request(app)
      .get(`/api/bpm/latest/${TEST_USER_ID}`)
      .expect(200);

    expect(res.body.bpm).toBeDefined();
    expect(res.body.userId).toBeDefined();
  });

  it('should return 404 for user with no records', async () => {
    const unknownId = new mongoose.Types.ObjectId().toString();
    await request(app)
      .get(`/api/bpm/latest/${unknownId}`)
      .expect(404);
  });
});

describe('GET /api/bpm/stats/:userId', () => {
  it('should return aggregated stats', async () => {
    const res = await request(app)
      .get(`/api/bpm/stats/${TEST_USER_ID}`)
      .expect(200);

    expect(res.body.avgBpm).toBeGreaterThan(0);
    expect(res.body.maxBpm).toBeGreaterThanOrEqual(res.body.minBpm);
    expect(res.body.totalScans).toBeGreaterThan(0);
  });
});
