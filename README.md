# PulseTrack - rPPG Health Monitoring App

PulseTrack is a modern Flutter application that uses rPPG (remote Photoplethysmography) technology to monitor heart rate, SpO2, and blood pressure using just your smartphone camera.

## 🚀 Key Features

*   **Contactless Monitoring**: Measure your vitals by simply looking at your camera.
*   **AI Health Assistant**: Integrated Gemini AI chatbot for personalized health insights and advice.
*   **Offline Data Persistence**: Advanced local caching ensures your health history is saved even without an internet connection.
*   **Health Analytics**: Track your trends with automated stats (Average, Max, Min BPM).
*   **Secure Authentication**: Firebase-powered login and registration.

## 🛠️ Recent Fixes & Improvements

### 1. Robust AI Chatbot Connection
*   Implemented fallback model logic (Flash, Pro, Flash-Lite) to bypass rate limits.
*   Fixed conversation history formatting for strict Gemini API requirements.
*   Enhanced error logging and intelligent offline mode responses.

### 2. Reliable Data Storage (History Screen)
*   Implemented local caching using `SharedPreferences`.
*   Every scan is persisted locally before syncing to the cloud.
*   Hybrid history loading: Merges local and server records for a seamless experience.

## 📱 Getting Started

1.  **Clone the repo**: `git clone https://github.com/VenkataReddy2006/pulse-track-app.git`
2.  **Install dependencies**: `flutter pub get`
3.  **Run the app**: `flutter run`

---
*Disclaimer: PulseTrack is for informational purposes only and is not a substitute for professional medical advice, diagnosis, or treatment.*
