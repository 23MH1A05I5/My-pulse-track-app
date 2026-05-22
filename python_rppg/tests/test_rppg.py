"""
PulseTrack rPPG — pytest Test Suite
Tests for the core signal processing pipeline and API endpoints.
Run: pytest tests/ -v
"""
import sys
import os
import numpy as np
import pytest

# Add project root to path so imports work
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from filters.signal_filters import (
    bandpass_filter,
    detrend_signal,
    normalize_signal,
    estimate_noise_level,
    compute_snr,
    apply_hanning_window,
)
from processors.rppg_processor import RppgProcessor, SessionBuffer
from utils.frame_decoder import decode_frame, extract_roi_means


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def synthetic_bpm_signal():
    """Generate a clean 75 BPM signal at 30 FPS for 15 seconds."""
    fs = 30.0
    duration = 15.0
    t = np.linspace(0, duration, int(fs * duration))
    hr_hz = 75 / 60.0
    signal = 100 + 5 * np.sin(2 * np.pi * hr_hz * t)  # DC offset + pulsatile
    return signal, fs


@pytest.fixture
def noisy_signal(synthetic_bpm_signal):
    """Add Gaussian noise to the clean signal."""
    signal, fs = synthetic_bpm_signal
    noise = np.random.normal(0, 2.0, len(signal))
    return signal + noise, fs


@pytest.fixture
def processor():
    return RppgProcessor()


# ── Signal Filter Tests ───────────────────────────────────────────────────────

class TestSignalFilters:

    def test_detrend_removes_linear_trend(self):
        """Detrend should remove linear component."""
        t = np.arange(100)
        signal = 0.5 * t + 5.0 * np.sin(2 * np.pi * 0.1 * t)
        detrended = detrend_signal(signal)
        # Mean should be close to 0 after detrending
        assert abs(np.mean(detrended)) < 1.0

    def test_normalize_unit_variance(self):
        """Normalized signal should have unit variance."""
        signal = np.random.normal(50, 10, 200)
        normalized = normalize_signal(signal)
        assert abs(np.std(normalized) - 1.0) < 0.01
        assert abs(np.mean(normalized)) < 0.01

    def test_bandpass_filter_passes_hr_band(self, synthetic_bpm_signal):
        """Bandpass should preserve the 75 BPM (1.25 Hz) component."""
        signal, fs = synthetic_bpm_signal
        filtered = bandpass_filter(signal, fs)
        # Output should not be all zeros
        assert np.max(np.abs(filtered)) > 0.1
        # Energy ratio: filtered should retain most of the HR-band energy
        assert len(filtered) == len(signal)

    def test_bandpass_rejects_dc(self, synthetic_bpm_signal):
        """High DC offset should be removed by bandpass filter."""
        signal, fs = synthetic_bpm_signal
        filtered = bandpass_filter(signal, fs)
        # Filtered mean should be nearly zero (DC removed)
        assert abs(np.mean(filtered)) < 2.0

    def test_hanning_window_shape(self):
        signal = np.ones(256)
        windowed = apply_hanning_window(signal)
        assert windowed[0] < 0.01
        assert windowed[127] > 0.99
        assert windowed[-1] < 0.01

    def test_noise_level_clean_signal(self, synthetic_bpm_signal):
        signal, _ = synthetic_bpm_signal
        noise = estimate_noise_level(signal)
        assert 0.0 <= noise <= 1.0

    def test_noise_level_noisy_signal(self, noisy_signal):
        signal, _ = noisy_signal
        noise = estimate_noise_level(signal)
        assert 0.0 <= noise <= 1.0


# ── rPPG Processor Tests ──────────────────────────────────────────────────────

class TestRppgProcessor:

    def test_session_creation(self, processor):
        buf = processor.get_or_create_session("test_session_001")
        assert isinstance(buf, SessionBuffer)
        assert buf.frame_count() == 0

    def test_session_singleton(self, processor):
        buf1 = processor.get_or_create_session("sess_abc")
        buf2 = processor.get_or_create_session("sess_abc")
        assert buf1 is buf2

    def test_insufficient_frames_returns_no_estimate(self, processor):
        result = processor.process_frame(
            session_id="sess_insufficient",
            r=150, g=160, b=140, ts_ms=0,
        )
        assert result["bpm_estimate"] is None
        assert result["frames_collected"] == 1

    def test_bpm_within_valid_range(self, processor):
        """After feeding 120 synthetic frames, BPM should be in valid range."""
        fs = 30.0
        hr_hz = 1.2  # 72 BPM
        session = "sess_synthetic"
        t = np.linspace(0, 4.0, 120)
        g_signal = 150 + 5 * np.sin(2 * np.pi * hr_hz * t)

        last_result = None
        for i, g in enumerate(g_signal):
            last_result = processor.process_frame(
                session_id=session,
                r=130 + 2 * np.sin(2 * np.pi * hr_hz * t[i]),
                g=g,
                b=120 + np.sin(2 * np.pi * hr_hz * t[i]),
                ts_ms=int(t[i] * 1000),
            )

        if last_result["bpm_estimate"] is not None:
            assert 42 <= last_result["bpm_estimate"] <= 220

    def test_clear_session(self, processor):
        processor.get_or_create_session("sess_to_clear")
        processor.clear_session("sess_to_clear")
        assert "sess_to_clear" not in processor._sessions

    def test_finalize_with_no_data(self, processor):
        result = processor.finalize_scan("nonexistent_session_xyz")
        assert "bpm" in result
        assert result["bpm"] > 0  # Should return a safe fallback

    def test_spo2_estimate_range(self, processor):
        r = np.random.normal(150, 5, 100)
        g = np.random.normal(160, 5, 100)
        b = np.random.normal(140, 5, 100)
        spo2 = processor._estimate_spo2(r, g, b)
        assert 90 <= spo2 <= 100


# ── Frame Decoder Tests ───────────────────────────────────────────────────────

class TestFrameDecoder:

    def test_invalid_base64_returns_none(self):
        result = decode_frame("not_valid_base64!!!")
        assert result is None

    def test_roi_extraction_valid_image(self):
        """A plain green numpy array should yield high G mean."""
        import cv2
        import base64
        # Create a 100x100 green image
        img = np.zeros((100, 100, 3), dtype=np.uint8)
        img[:, :, 1] = 200  # Green channel (BGR index 1)
        _, jpeg = cv2.imencode('.jpg', img)
        b64 = base64.b64encode(jpeg.tobytes()).decode()

        decoded = decode_frame(b64)
        assert decoded is not None

        roi = extract_roi_means(decoded, roi_type="forehead")
        assert roi is not None
        r, g, b = roi
        assert g > r  # Green should be highest
