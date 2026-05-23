/**
 * PulseTrack — Jest Auth Tests
 * Tests the auth API endpoints using Supertest.
 * Run: npm test
 */

const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../server');
const User = require('../models/User');

const TEST_USER = {
  name: 'Test User',
  email: `test_${Date.now()}@pulsetrack.test`,
  password: 'TestPass123!',
};

beforeAll(async () => {
  await mongoose.connect(process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/pulsetrack_test');
});

afterAll(async () => {
  // Clean up test user
  await User.deleteOne({ email: TEST_USER.email });
  await mongoose.disconnect();
});

describe('POST /api/auth/register', () => {
  it('should register a new user', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send(TEST_USER)
      .expect(201);

    expect(res.body.success).not.toBe(false);
    expect(res.body.email).toBe(TEST_USER.email);
  });

  it('should reject duplicate email', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send(TEST_USER)
      .expect(409);

    expect(res.body.message).toMatch(/already registered/i);
  });

  it('should reject weak password', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ ...TEST_USER, email: 'other@test.com', password: 'weak' })
      .expect(422);

    expect(res.body.message).toMatch(/password/i);
  });

  it('should reject invalid email', async () => {
    await request(app)
      .post('/api/auth/register')
      .send({ ...TEST_USER, email: 'not-an-email' })
      .expect(422);
  });
});

describe('POST /api/auth/login', () => {
  it('should return 401 for unverified account', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: TEST_USER.email, password: TEST_USER.password })
      .expect(401);

    expect(res.body.requiresVerification).toBe(true);
  });

  it('should return 401 for wrong password', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: TEST_USER.email, password: 'WrongPassword123!' })
      .expect(401);

    expect(res.body.message).toMatch(/invalid/i);
  });
});

describe('POST /api/auth/forgot-password', () => {
  it('should always return 200 (prevent email enumeration)', async () => {
    const res = await request(app)
      .post('/api/auth/forgot-password')
      .send({ email: 'nonexistent@test.com' })
      .expect(200);

    expect(res.body.success).toBe(true);
  });
});

describe('GET /health', () => {
  it('should return health check', async () => {
    const res = await request(app).get('/health').expect(200);
    expect(res.body.status).toBe('ok');
  });
});
