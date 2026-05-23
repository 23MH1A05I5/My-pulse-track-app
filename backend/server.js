/**
 * PulseTrack Backend — Express Server (Production-Ready)
 *
 * Security:
 *  - helmet: HTTP security headers
 *  - express-rate-limit: brute-force protection
 *  - CORS restricted to known origins
 *  - All secrets via dotenv (never hardcoded)
 */

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const mongoSanitize = require('express-mongo-sanitize');
const morgan = require('morgan');
require('dotenv').config();

const { connectDB } = require('./config/db');
const { validateEnv } = require('./config/env');

// ── Routes ────────────────────────────────────────────────────────────────────
const authRoutes = require('./routes/auth');
const bpmRoutes = require('./routes/bpm');
const breathingRoutes = require('./routes/breathing');

// ── Validate Environment ───────────────────────────────────────────────────────
validateEnv();

const app = express();

// ── Security Middleware ────────────────────────────────────────────────────────

// HTTP security headers
app.use(helmet({
  contentSecurityPolicy: false, // Disabled for API-only server
}));

// CORS — restrict to known origins (not wildcard)
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '').split(',').map(o => o.trim()).filter(Boolean);
app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, Postman, server-to-server)
    if (!origin) return callback(null, true);
    if (allowedOrigins.length === 0 || allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    callback(new Error(`CORS blocked: Origin ${origin} not allowed`));
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
}));

// Global rate limiter — prevent DoS
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Too many requests — please try again later' },
});
app.use(globalLimiter);

// NoSQL injection prevention
app.use(mongoSanitize());

// Request logging (dev only)
if (process.env.NODE_ENV !== 'production') {
  app.use(morgan('dev'));
}

// Body parsing
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true, limit: '2mb' }));

// ── Database ───────────────────────────────────────────────────────────────────
connectDB();

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/bpm', bpmRoutes);
app.use('/api/breathing', breathingRoutes);

// Health check (for Docker / Render)
app.get('/health', (req, res) => res.json({ status: 'ok', version: '2.0.0' }));

// 404 handler
app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Route not found' });
});

// Global error handler
app.use((err, req, res, next) => { // eslint-disable-line no-unused-vars
  console.error('SERVER ERROR:', err);
  const status = err.status || 500;
  const message = process.env.NODE_ENV === 'production'
    ? 'An internal server error occurred'
    : err.message;
  res.status(status).json({ success: false, message });
});

// ── Start Server ───────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`✅ PulseTrack Backend running on port ${PORT} [${process.env.NODE_ENV || 'development'}]`);
});

module.exports = app; // Export for testing
