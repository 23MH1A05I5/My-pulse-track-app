"""
PulseTrack rPPG — Core Processor
Implements the full rPPG pipeline:
  1. Green-channel signal extraction
  2. Detrending
  3. Butterworth bandpass filtering
  4. Hanning windowing
  5. FFT-based BPM estimation
  6. Confidence scoring
  7. SpO2 estimation
"""
import time
import logging
import threading
from collections import defaultdict
from typing import Dict, List, Optional, Tuple

import numpy as np

from filters.signal_filters import (
    bandpass_filter,
    detrend_signal,
    normalize_signal,
    compute_snr,
    estimate_noise_level,
    apply_hanning_window,
)
from models.schemas import SignalQuality

logger = logging.getLogger("pulsetrack.rppg_processor")


# ── Constants ──────────────────────────────────────────────────────────────────
MIN_FRAMES_FOR_ESTIMATE = 90    # ~3 seconds at 30 FPS
MIN_FRAMES_FOR_FINAL = 270      # ~9 seconds at 30 FPS
MAX_SESSION_FRAMES = 600        # ~20 seconds (memory safety cap)
DEFAULT_FPS = 30.0
HR_LOW_BPM = 42
HR_HIGH_BPM = 220


class SessionBuffer:
    """Thread-safe buffer for a single scan session."""

    def __init__(self, session_id: str, fps: float = DEFAULT_FPS):
        self.session_id = session_id
        self.fps = fps
        self.r_values: List[float] = []
        self.g_values: List[float] = []
        self.b_values: List[float] = []
        self.timestamps_ms: List[int] = []
        self._lock = threading.Lock()
        self.created_at = time.time()

    def add_sample(self, r: float, g: float, b: float, ts_ms: int) -> None:
        with self._lock:
            self.r_values.append(r)
            self.g_values.append(g)
            self.b_values.append(b)
            self.timestamps_ms.append(ts_ms)
            # Cap buffer to avoid memory bloat
            if len(self.g_values) > MAX_SESSION_FRAMES:
                self.r_values.pop(0)
                self.g_values.pop(0)
                self.b_values.pop(0)
                self.timestamps_ms.pop(0)

    def frame_count(self) -> int:
        with self._lock:
            return len(self.g_values)

    def get_arrays(self) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        with self._lock:
            return (
                np.array(self.r_values, dtype=np.float64),
                np.array(self.g_values, dtype=np.float64),
                np.array(self.b_values, dtype=np.float64),
            )

    def estimate_fps(self) -> float:
        """Estimate actual FPS from timestamps if available."""
        with self._lock:
            if len(self.timestamps_ms) < 2:
                return self.fps
            duration_s = (self.timestamps_ms[-1] - self.timestamps_ms[0]) / 1000.0
            n = len(self.timestamps_ms) - 1
            return n / duration_s if duration_s > 0 else self.fps


class RppgProcessor:
    """
    Singleton processor managing multiple concurrent scan sessions.
    Each session (identified by session_id) has its own SignalBuffer.
    """

    def __init__(self):
        self._sessions: Dict[str, SessionBuffer] = {}
        self._lock = threading.Lock()

    # ── Session Management ────────────────────────────────────────────────────

    def get_or_create_session(self, session_id: str, fps: float = DEFAULT_FPS) -> SessionBuffer:
        with self._lock:
            if session_id not in self._sessions:
                self._sessions[session_id] = SessionBuffer(session_id, fps)
                logger.info(f"New session created: {session_id}")
            return self._sessions[session_id]

    def clear_session(self, session_id: str) -> None:
        with self._lock:
            self._sessions.pop(session_id, None)
            logger.info(f"Session cleared: {session_id}")

    def cleanup_stale_sessions(self, max_age_seconds: float = 120.0) -> None:
        """Remove sessions older than max_age_seconds to free memory."""
        now = time.time()
        with self._lock:
            stale = [sid for sid, buf in self._sessions.items()
                     if (now - buf.created_at) > max_age_seconds]
            for sid in stale:
                del self._sessions[sid]
                logger.info(f"Stale session removed: {sid}")

    # ── Core BPM Estimation ───────────────────────────────────────────────────

    def process_frame(
        self,
        session_id: str,
        r: float, g: float, b: float,
        ts_ms: int,
        fps: float = DEFAULT_FPS,
    ) -> dict:
        """
        Process a single frame sample and return a live estimate.

        Args:
            session_id: Unique scan session identifier
            r, g, b: Mean RGB values from the forehead ROI
            ts_ms: Client timestamp in milliseconds
            fps: Camera frame rate

        Returns:
            dict with keys: bpm_estimate, signal_quality, confidence,
                            noise_level, frames_collected, message
        """
        buf = self.get_or_create_session(session_id, fps)
        buf.add_sample(r, g, b, ts_ms)

        n = buf.frame_count()
        fs = buf.estimate_fps()

        # Not enough data yet
        if n < MIN_FRAMES_FOR_ESTIMATE:
            remaining = MIN_FRAMES_FOR_ESTIMATE - n
            return {
                "bpm_estimate": None,
                "signal_quality": SignalQuality.INVALID,
                "confidence": 0.0,
                "noise_level": 1.0,
                "frames_collected": n,
                "message": f"Collecting signal... {remaining} more frames needed",
            }

        # Run FFT-based estimate
        bpm, confidence, noise, quality = self._run_fft(buf, fs)

        return {
            "bpm_estimate": bpm,
            "signal_quality": quality,
            "confidence": round(confidence, 1),
            "noise_level": round(noise, 3),
            "frames_collected": n,
            "message": self._quality_message(quality, confidence),
        }

    def finalize_scan(self, session_id: str) -> dict:
        """
        Compute the final high-accuracy BPM result for a completed scan.
        Uses the full accumulated buffer.

        Returns:
            dict with bpm, spo2_estimate, confidence, signal_quality,
                   noise_level, status, processing_time_ms
        """
        start_time = time.perf_counter()

        buf = self._sessions.get(session_id)
        if buf is None or buf.frame_count() < MIN_FRAMES_FOR_ESTIMATE:
            logger.warning(f"Cannot finalize session {session_id}: insufficient data")
            return {
                "bpm": 72,
                "spo2_estimate": 98,
                "signal_quality": SignalQuality.POOR,
                "confidence": 30.0,
                "noise_level": 1.0,
                "status": "Normal",
                "processing_time_ms": 0,
                "warning": "Insufficient data — result may be inaccurate",
            }

        fs = buf.estimate_fps()
        bpm, confidence, noise, quality = self._run_fft(buf, fs)
        spo2 = self._estimate_spo2(*buf.get_arrays())

        elapsed_ms = int((time.perf_counter() - start_time) * 1000)

        status = "Normal"
        warning = None
        if bpm < 50:
            status = "Alert"
            warning = "Very low heart rate — please rest and re-scan"
        elif bpm < 60:
            status = "Low"
        elif bpm > 100:
            status = "High"
            warning = "Elevated heart rate — try to relax before re-scanning"
        elif bpm > 120:
            status = "Alert"
            warning = "Very high heart rate — seek medical advice if persistent"

        return {
            "bpm": bpm,
            "spo2_estimate": spo2,
            "signal_quality": quality,
            "confidence": round(confidence, 1),
            "noise_level": round(noise, 3),
            "status": status,
            "processing_time_ms": elapsed_ms,
            "warning": warning,
        }

    # ── Internal FFT Pipeline ─────────────────────────────────────────────────

    def _run_fft(
        self, buf: SessionBuffer, fs: float
    ) -> Tuple[int, float, float, SignalQuality]:
        """
        Core FFT pipeline:
          1. Extract green channel (most sensitive to blood volume changes)
          2. Detrend → normalize → bandpass → Hanning window → FFT
          3. Pick dominant frequency in HR range
          4. Compute confidence from spectral peak prominence
        """
        r_arr, g_arr, b_arr = buf.get_arrays()

        # Use the green channel as primary signal (highest SNR for rPPG)
        raw = g_arr.copy()

        # 1. Detrend (remove slow illumination drift)
        raw = detrend_signal(raw)

        # 2. Normalize
        raw = normalize_signal(raw)

        # 3. Bandpass filter (0.7–4.0 Hz)
        try:
            filtered = bandpass_filter(raw, fs)
        except Exception as e:
            logger.error(f"Bandpass filter failed: {e}")
            filtered = raw

        # 4. Hanning window to reduce spectral leakage
        windowed = apply_hanning_window(filtered)

        # 5. FFT
        n = len(windowed)
        fft_vals = np.abs(np.fft.rfft(windowed, n=n * 4))  # Zero-pad for resolution
        freqs = np.fft.rfftfreq(n * 4, d=1.0 / fs)

        # 6. Restrict to valid HR range
        hr_mask = (freqs >= 0.7) & (freqs <= 4.0)
        if not np.any(hr_mask):
            return 72, 30.0, 1.0, SignalQuality.POOR

        hr_freqs = freqs[hr_mask]
        hr_fft = fft_vals[hr_mask]

        # 7. Dominant frequency = highest spectral peak
        peak_idx = np.argmax(hr_fft)
        peak_freq = hr_freqs[peak_idx]
        bpm = int(round(peak_freq * 60.0))
        bpm = int(np.clip(bpm, HR_LOW_BPM, HR_HIGH_BPM))

        # 8. Confidence = spectral peak prominence (0–100%)
        peak_power = hr_fft[peak_idx]
        mean_power = np.mean(hr_fft)
        prominence = peak_power / (mean_power + 1e-8)
        # Map prominence to 0–100%: prominence of 10 → ~67%, 20 → ~80%
        prominence_conf = float(np.clip((1 - 1.0 / (1 + prominence / 8.0)) * 100, 20.0, 98.0))

        # 9. SNR-based confidence boost using Welch PSD
        try:
            snr_db = compute_snr(filtered, fs, float(bpm))
            # SNR of >6 dB is good; scale to 0–30 bonus points
            snr_bonus = float(np.clip(snr_db * 2.5, -20.0, 30.0))
        except Exception:
            snr_bonus = 0.0

        # Blend: 70% prominence-based + 30% SNR bonus
        confidence = float(np.clip(prominence_conf * 0.7 + snr_bonus * 0.3 + 20.0, 20.0, 98.0))

        # 10. Noise level estimate
        noise = estimate_noise_level(filtered)

        # 11. Signal quality classification
        quality = self._classify_quality(confidence, noise)

        logger.debug(f"BPM={bpm} | prominence_conf={prominence_conf:.1f}% | snr_db={snr_bonus/2.5:.1f}dB | final_confidence={confidence:.1f}% | noise={noise:.3f} | quality={quality}")
        return bpm, confidence, noise, quality

    def _estimate_spo2(
        self, r_arr: np.ndarray, g_arr: np.ndarray, b_arr: np.ndarray
    ) -> int:
        """
        Estimate SpO2 using AC/DC ratio of red and blue channels.
        This is a simplified calibration-free approximation.
        Normal range: 95–100%.
        """
        if len(r_arr) < 30 or len(b_arr) < 30:
            return 98

        # AC component = standard deviation, DC component = mean
        ac_r = np.std(r_arr)
        dc_r = np.mean(r_arr) + 1e-8
        ac_b = np.std(b_arr)
        dc_b = np.mean(b_arr) + 1e-8

        ratio = (ac_r / dc_r) / (ac_b / dc_b)
        # Empirical calibration formula (approximation)
        spo2 = int(np.clip(110 - 14 * ratio, 90, 100))
        return spo2

    @staticmethod
    def _classify_quality(confidence: float, noise: float) -> SignalQuality:
        """
        Classify signal quality based on confidence score and noise level.

        Thresholds tuned for real camera rPPG data:
        - After the noise estimator fix, good signals produce noise ~0.1–0.3
        - Confidence for real skin data typically 40–80%
        """
        if confidence >= 75 and noise < 0.35:
            return SignalQuality.EXCELLENT
        if confidence >= 60 and noise < 0.50:
            return SignalQuality.GOOD
        if confidence >= 40 and noise < 0.65:
            return SignalQuality.FAIR
        if confidence >= 25:
            return SignalQuality.POOR
        return SignalQuality.INVALID

    @staticmethod
    def _quality_message(quality: SignalQuality, confidence: float) -> str:
        messages = {
            SignalQuality.EXCELLENT: "✅ Excellent signal — keep still",
            SignalQuality.GOOD: "🟢 Good signal — stay steady",
            SignalQuality.FAIR: "🟡 Fair signal — improve lighting",
            SignalQuality.POOR: "🔴 Poor signal — face not detected properly",
            SignalQuality.INVALID: "⏳ Building signal...",
        }
        return messages.get(quality, "Processing...")


# ── Module-level singleton ────────────────────────────────────────────────────
processor = RppgProcessor()
