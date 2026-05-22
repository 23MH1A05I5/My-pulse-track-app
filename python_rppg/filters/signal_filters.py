"""
PulseTrack rPPG — Signal Filters
Implements Butterworth bandpass filter for isolating heart rate frequencies.
Heart rate range: 0.7 Hz – 4.0 Hz (42–240 BPM)
"""
import numpy as np
from scipy.signal import butter, filtfilt, welch
from typing import Tuple


# ── Constants ─────────────────────────────────────────────────────────────────
HR_LOW_HZ = 0.7    # 42 BPM minimum
HR_HIGH_HZ = 4.0   # 240 BPM maximum
FILTER_ORDER = 4


def bandpass_filter(signal: np.ndarray, fs: float, low: float = HR_LOW_HZ, high: float = HR_HIGH_HZ) -> np.ndarray:
    """
    Apply a Butterworth bandpass filter to the input signal.
    
    Args:
        signal: 1D numpy array of raw green channel values
        fs: Sampling frequency (camera FPS)
        low: Lower cutoff frequency in Hz
        high: Upper cutoff frequency in Hz
    
    Returns:
        Filtered signal as 1D numpy array
    """
    nyquist = fs / 2.0
    low_norm = low / nyquist
    high_norm = min(high / nyquist, 0.99)  # Prevent aliasing

    b, a = butter(FILTER_ORDER, [low_norm, high_norm], btype='band')
    return filtfilt(b, a, signal)


def detrend_signal(signal: np.ndarray) -> np.ndarray:
    """
    Remove linear trend from signal to eliminate slow drift.
    This is critical before FFT to avoid spectral leakage.
    """
    return signal - np.polyval(np.polyfit(np.arange(len(signal)), signal, 1), np.arange(len(signal)))


def normalize_signal(signal: np.ndarray) -> np.ndarray:
    """Zero-mean, unit-variance normalization."""
    std = np.std(signal)
    if std < 1e-8:
        return signal - np.mean(signal)
    return (signal - np.mean(signal)) / std


def compute_snr(signal: np.ndarray, fs: float, bpm_estimate: float) -> float:
    """
    Compute Signal-to-Noise Ratio around the fundamental heart rate frequency.
    
    Returns:
        SNR in dB (higher = cleaner signal)
    """
    freqs, psd = welch(signal, fs=fs, nperseg=min(256, len(signal)))
    hr_hz = bpm_estimate / 60.0
    
    # Signal power: within ±0.1 Hz of the HR frequency and its 2nd harmonic
    signal_mask = (
        ((freqs >= hr_hz - 0.1) & (freqs <= hr_hz + 0.1)) |
        ((freqs >= 2 * hr_hz - 0.1) & (freqs <= 2 * hr_hz + 0.1))
    )
    noise_mask = (freqs >= HR_LOW_HZ) & (freqs <= HR_HIGH_HZ) & ~signal_mask

    signal_power = np.mean(psd[signal_mask]) if np.any(signal_mask) else 1e-10
    noise_power = np.mean(psd[noise_mask]) if np.any(noise_mask) else 1e-10

    snr_db = 10 * np.log10(signal_power / noise_power) if noise_power > 0 else 0
    return float(np.clip(snr_db, -20, 40))


def estimate_noise_level(signal: np.ndarray) -> float:
    """
    Estimate noise as the variance of consecutive differences (signal velocity),
    normalized by the signal's peak-to-peak amplitude.

    This works correctly on zero-mean normalized signals (unlike CV which always
    returns 1.0 after normalization). A smooth rPPG pulse has low diff variance;
    motion artifacts produce large frame-to-frame jumps.

    Returns a normalized value 0.0 (clean) – 1.0 (very noisy).
    """
    if len(signal) < 4:
        return 1.0
    diffs = np.diff(signal)
    diff_std = np.std(diffs)
    peak_to_peak = np.ptp(signal)  # max - min
    if peak_to_peak < 1e-8:
        return 1.0
    noise = diff_std / (peak_to_peak + 1e-8)
    return float(np.clip(noise, 0.0, 1.0))


def apply_hanning_window(signal: np.ndarray) -> np.ndarray:
    """Apply a Hanning window to reduce spectral leakage before FFT."""
    window = np.hanning(len(signal))
    return signal * window
