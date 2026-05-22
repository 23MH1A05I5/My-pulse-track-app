"""
PulseTrack rPPG — Frame Decoder
Handles base64 JPEG decoding and forehead ROI extraction from camera frames.
"""
import base64
import logging
from typing import Optional, Tuple

import cv2
import numpy as np

logger = logging.getLogger("pulsetrack.frame_decoder")

# ── ROI Constants ─────────────────────────────────────────────────────────────
FOREHEAD_Y_RATIO = 0.15   # Top 15% of face bounding box = forehead
FOREHEAD_H_RATIO = 0.20   # Height of forehead region
CHEEK_X_RATIO = 0.25      # Cheek region width
CHEEK_Y_RATIO = 0.45      # Cheek region vertical position


def decode_frame(frame_b64: str) -> Optional[np.ndarray]:
    """
    Decode a base64-encoded JPEG string to a BGR numpy array.
    
    Returns:
        BGR image as numpy array, or None if decoding fails.
    """
    try:
        # Strip any data-URI prefix (e.g. "data:image/jpeg;base64,")
        if ',' in frame_b64:
            frame_b64 = frame_b64.split(',', 1)[1]

        image_bytes = base64.b64decode(frame_b64)
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img is None:
            logger.warning("cv2.imdecode returned None — corrupted frame?")
            return None

        return img
    except Exception as e:
        logger.error(f"Frame decode error: {e}")
        return None


def extract_roi_means(
    image: np.ndarray,
    roi_type: str = "forehead"
) -> Optional[Tuple[float, float, float]]:
    """
    Extract mean RGB values from the forehead or cheek ROI of a face image.
    
    The Flutter app is expected to crop the frame to the face bounding box
    before sending. If not, this function processes the full image.
    
    Args:
        image: BGR numpy array (face or full-frame image)
        roi_type: "forehead" or "cheeks"
    
    Returns:
        Tuple of (mean_R, mean_G, mean_B) floats, or None if extraction fails.
    """
    try:
        h, w = image.shape[:2]

        if roi_type == "forehead":
            y1 = int(h * FOREHEAD_Y_RATIO)
            y2 = int(h * (FOREHEAD_Y_RATIO + FOREHEAD_H_RATIO))
            x1 = int(w * 0.20)  # Avoid side hair/ears
            x2 = int(w * 0.80)
        else:
            # Left and right cheek average
            y1 = int(h * CHEEK_Y_RATIO)
            y2 = int(h * (CHEEK_Y_RATIO + 0.20))
            x1 = int(w * CHEEK_X_RATIO)
            x2 = int(w * (1.0 - CHEEK_X_RATIO))

        roi = image[y1:y2, x1:x2]
        if roi.size == 0:
            return None

        # OpenCV uses BGR order
        mean_b = float(np.mean(roi[:, :, 0]))
        mean_g = float(np.mean(roi[:, :, 1]))
        mean_r = float(np.mean(roi[:, :, 2]))

        return mean_r, mean_g, mean_b

    except Exception as e:
        logger.error(f"ROI extraction error: {e}")
        return None


def check_lighting_quality(image: np.ndarray) -> Tuple[bool, str]:
    """
    Assess frame lighting quality.
    
    Returns:
        (is_acceptable, message) tuple
    """
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    mean_brightness = float(np.mean(gray))
    std_brightness = float(np.std(gray))

    if mean_brightness < 40:
        return False, "Too dark — move to better lighting"
    if mean_brightness > 220:
        return False, "Too bright — avoid direct light on face"
    if std_brightness < 10:
        return False, "Uniform color detected — no face found?"
    return True, "Lighting OK"
