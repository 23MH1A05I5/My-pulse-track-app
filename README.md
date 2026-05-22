# 💓 PulseTrack — AI-Powered Contactless Health Monitor

<div align="center">

![PulseTrack Banner](assets/images/glowing_heart.png)

**Production-grade contactless heart rate monitoring using rPPG technology, powered by Gemini AI.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/Python-FastAPI-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Node.js](https://img.shields.io/badge/Node.js-20-green?logo=node.js)](https://nodejs.org)
[![MongoDB](https://img.shields.io/badge/MongoDB-Atlas-47A248?logo=mongodb)](https://mongodb.com)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://docker.com)

</div>

---

## 🏗️ Architecture

```
Flutter App (Mobile)
   │
   ├── POST /api/frame ──────────► Python FastAPI rPPG Microservice
   │                                  │  FFT + Butterworth filter
   │◄── BPM + confidence ─────────────┘
   │
   ├── REST API ─────────────────► Node.js + Express Backend
   │   (auth, history, profile)       │  JWT + bcrypt + MongoDB
   │                                  └── Email (Nodemailer)
   │
   └── Gemini 2.0 Flash API ──────► AI Health Insights
```

---

## ✨ Features

| Category | Features |
|----------|----------|
| **Scanning** | Contactless heart rate via rPPG, face detection with ML Kit, signal quality indicator, confidence %, SpO2 estimation |
| **Security** | JWT access + refresh tokens, bcrypt, OTP email verification, helmet, CORS, rate limiting, env-based secrets |
| **AI** | Gemini 2.0 Flash health insights, hydration, stress, sleep, fitness recommendations |
| **History** | Cloud + local-first sync, merge deduplication, trend analytics, fl_chart visualizations |
| **Reports** | Professional PDF reports with graph, vitals, AI recommendations |
| **Auth** | Register, Login, 2FA OTP, Forgot Password, Reset Password, JWT refresh |

---

## 🛠️ Tech Stack

**Frontend:** Flutter 3.x · Camera · ML Kit Face Detection · fl_chart · Lottie · PDF

**Backend (Node.js):** Express · Helmet · express-rate-limit · Mongoose · bcryptjs · Nodemailer · JWT

**Python Microservice:** FastAPI · NumPy · SciPy · OpenCV · Uvicorn

**Database:** MongoDB Atlas

**Infrastructure:** Firebase Auth · Docker · Docker Compose

---

## 🚀 Quick Start

### Prerequisites
- Flutter 3.x
- Node.js 20+
- Python 3.11+
- MongoDB Atlas account (free tier works)

### 1. Clone & Setup

```bash
git clone https://github.com/your-repo/pulsetrack.git
cd pulse-track-app
```

### 2. Start Python rPPG Microservice

```bash
cd python_rppg
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

Visit http://localhost:8001/docs for the interactive API documentation.

### 3. Start Node.js Backend

```bash
cd backend
cp .env.example .env
# Edit .env with your MongoDB URI, JWT secrets, and email credentials
npm install
npm start
```

### 4. Run Flutter App

```bash
flutter pub get
flutter run
```

### Or use Docker Compose (Backend + Python together)

```bash
# Create .env in root with your secrets
cp backend/.env.example .env
docker-compose up --build
```

---

## 🔒 Security

- **JWT**: Short-lived access tokens (15min) + long-lived refresh tokens (30 days)
- **OTP**: Bcrypt-hashed, 10-minute expiry, max 5 attempts before lockout
- **Passwords**: Minimum 8 chars, uppercase + digit required, bcrypt rounds=12
- **CORS**: Restricted to declared `ALLOWED_ORIGINS` (no wildcard `*`)
- **Rate Limiting**: Auth=20/15min, OTP=10/10min, Reset=5/hour, API=60/min
- **NoSQL Injection**: `express-mongo-sanitize` on all inputs
- **Secrets**: All keys in `.env` — never committed to Git

### Environment Variables (Required)

| Variable | Description |
|----------|-------------|
| `MONGO_URI` | MongoDB connection string |
| `JWT_SECRET` | Access token secret (min 64 chars) |
| `JWT_REFRESH_SECRET` | Refresh token secret (different from JWT_SECRET) |
| `EMAIL_USER` | Gmail address for OTP emails |
| `EMAIL_PASS` | Gmail App Password (not account password) |
| `ALLOWED_ORIGINS` | Comma-separated allowed CORS origins |

---

## 📡 API Reference

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login |
| POST | `/api/auth/send-otp` | Resend OTP |
| POST | `/api/auth/verify-otp` | Verify OTP |
| POST | `/api/auth/forgot-password` | Send reset OTP |
| POST | `/api/auth/reset-password` | Reset password with OTP |
| POST | `/api/auth/refresh-token` | Get new access token |

### Health Data

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/bpm/add` | Save scan result |
| GET | `/api/bpm/history/:userId` | Get scan history |
| GET | `/api/bpm/latest/:userId` | Get latest scan |
| GET | `/api/bpm/stats/:userId` | Get aggregated stats |

### Python rPPG Microservice

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/frame` | Submit camera frame |
| POST | `/api/finalize/:sessionId` | Get final BPM result |
| DELETE | `/api/session/:sessionId` | Clear session buffer |
| GET | `/health` | Health check |

---

## 🧪 Testing

### Python (pytest)
```bash
cd python_rppg
pytest tests/ -v --tb=short
```

### Node.js (Jest + Supertest)
```bash
cd backend
npm test
```

### Flutter (Widget Tests)
```bash
flutter test
```

---

## 🤖 rPPG Algorithm

1. **Face Detection**: ML Kit detects and tracks face in real-time
2. **ROI Extraction**: Forehead region (15% of face height) sampled
3. **RGB Sampling**: Mean R, G, B values extracted per frame
4. **Detrending**: Linear drift removed from green channel signal
5. **Bandpass Filter**: Butterworth 4th-order (0.7–4.0 Hz = 42–240 BPM)
6. **FFT**: Dominant frequency → multiply by 60 → BPM
7. **Confidence**: Spectral peak prominence relative to noise floor
8. **SpO2**: AC/DC ratio of red and blue channels

---

## 🔮 Future Scope (Scaffolded)

- Smartwatch sync (WearOS / watchOS)
- Google Fit & Apple HealthKit integration
- Family health tracking
- Doctor dashboard portal
- Telehealth consultation booking
- Emergency heart rate alerts

---

## 📁 Project Structure

```
pulse-track-app/
├── lib/                        # Flutter app
│   ├── screens/                # UI screens (26 screens)
│   ├── services/               # API, rPPG, AI services
│   ├── models/                 # Data models
│   ├── providers/              # State management
│   ├── widgets/                # Reusable widgets
│   ├── utils/                  # Config, validators
│   ├── theme/                  # Design system
│   └── animations/             # Animation helpers
├── backend/                    # Node.js backend
│   ├── controllers/            # Business logic
│   ├── routes/                 # HTTP routes
│   ├── middleware/             # Auth, validation, rate-limit
│   ├── models/                 # Mongoose schemas
│   ├── services/               # Email service
│   ├── utils/                  # JWT helpers
│   ├── config/                 # DB + env config
│   └── tests/                  # Jest tests
├── python_rppg/                # FastAPI microservice
│   ├── api/                    # Routes
│   ├── processors/             # rPPG core algorithm
│   ├── filters/                # Butterworth filter
│   ├── utils/                  # Frame decoder
│   ├── models/                 # Pydantic schemas
│   └── tests/                  # pytest suite
└── docker-compose.yml          # One-command deployment
```

---

## 📄 License

MIT License — See LICENSE file for details.

---

<div align="center">Made with ❤️ for better healthcare access</div>
