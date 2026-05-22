"""
PulseTrack rPPG — FastAPI Routes
Exposes three endpoints:
  POST /api/frame      — Push a single live camera frame
  POST /api/finalize   — Request final BPM result for a session
  DELETE /api/session  — Clear a session buffer
  GET  /health         — Health check
"""
import logging
import time
from fastapi import APIRouter, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse

from models.schemas import (
    FrameRequest,
    RgbFrameRequest,
    LiveFrameResponse,
    ScanResultResponse,
    HealthCheckResponse,
    SignalQuality,
)
from processors.rppg_processor import processor
from utils.frame_decoder import decode_frame, extract_roi_means, check_lighting_quality

logger = logging.getLogger("pulsetrack.routes")
router = APIRouter()


# ── Health Check ──────────────────────────────────────────────────────────────

@router.get("/health", response_model=HealthCheckResponse)
async def health_check():
    """Lightweight health probe for load balancers and Flutter startup check."""
    try:
        import torch
        gpu = torch.cuda.is_available()
    except ImportError:
        gpu = False

    return HealthCheckResponse(
        status="ok",
        version="2.0.0",
        gpu_available=gpu,
    )


# ── Live Frame Processing ─────────────────────────────────────────────────────

@router.post("/api/frame", response_model=LiveFrameResponse)
async def process_frame(request: FrameRequest):
    """
    Accept a single base64-encoded JPEG frame from Flutter.
    Returns a live BPM estimate and signal quality metrics.
    
    The Flutter app should call this endpoint every ~2-3 frames (not every frame)
    to reduce network load while maintaining accuracy.
    """
    # Decode the frame
    image = decode_frame(request.frame_b64)
    if image is None:
        raise HTTPException(status_code=422, detail="Could not decode frame — invalid base64 or JPEG")

    # Check lighting
    light_ok, light_msg = check_lighting_quality(image)
    if not light_ok:
        return LiveFrameResponse(
            session_id=request.session_id,
            frames_collected=0,
            bpm_estimate=None,
            signal_quality=SignalQuality.INVALID,
            confidence=0.0,
            noise_level=1.0,
            face_alignment="unknown",
            message=light_msg,
        )

    # Extract forehead ROI mean RGB
    roi = extract_roi_means(image, roi_type="forehead")
    if roi is None:
        return LiveFrameResponse(
            session_id=request.session_id,
            frames_collected=0,
            bpm_estimate=None,
            signal_quality=SignalQuality.INVALID,
            confidence=0.0,
            noise_level=1.0,
            face_alignment="off_center",
            message="Could not extract forehead region — align face in frame",
        )

    r, g, b = roi

    # Feed into processor
    result = processor.process_frame(
        session_id=request.session_id,
        r=r, g=g, b=b,
        ts_ms=request.timestamp_ms,
    )

    return LiveFrameResponse(
        session_id=request.session_id,
        frames_collected=result["frames_collected"],
        bpm_estimate=result["bpm_estimate"],
        signal_quality=result["signal_quality"],
        confidence=result["confidence"],
        noise_level=result["noise_level"],
        face_alignment="good",
        message=result["message"],
    )


# ── RGB Direct Frame (Primary streaming path from Flutter) ─────────────────────

@router.post("/api/rgb_frame", response_model=LiveFrameResponse)
async def process_rgb_frame(request: RgbFrameRequest):
    """
    Accept pre-extracted forehead ROI mean R,G,B values from Flutter.

    Flutter's ML Kit already performs precise face detection and ROI cropping,
    so sending raw R,G,B means is more accurate than re-detecting in Python,
    and eliminates the overhead of JPEG encoding/decoding entirely.

    Called on every frame where face is detected and scan is in progress.
    """
    result = processor.process_frame(
        session_id=request.session_id,
        r=request.r,
        g=request.g,
        b=request.b,
        ts_ms=request.timestamp_ms,
        fps=request.fps,
    )

    return LiveFrameResponse(
        session_id=request.session_id,
        frames_collected=result["frames_collected"],
        bpm_estimate=result["bpm_estimate"],
        signal_quality=result["signal_quality"],
        confidence=result["confidence"],
        noise_level=result["noise_level"],
        face_alignment="good",
        message=result["message"],
    )


# ── Final BPM Result ──────────────────────────────────────────────────────────

@router.post("/api/finalize/{session_id}", response_model=ScanResultResponse)
async def finalize_scan(session_id: str, background_tasks: BackgroundTasks):
    """
    Request the final BPM calculation for a completed scan session.
    The session buffer is cleared after processing (background task).
    """
    if not session_id or len(session_id) < 8:
        raise HTTPException(status_code=400, detail="Invalid session_id")

    result = processor.finalize_scan(session_id)

    # Clean up session after a short delay (allow client to call again if needed)
    background_tasks.add_task(_delayed_cleanup, session_id, delay=30.0)

    return ScanResultResponse(
        session_id=session_id,
        bpm=result["bpm"],
        spo2_estimate=result.get("spo2_estimate"),
        signal_quality=result["signal_quality"],
        confidence=result["confidence"],
        noise_level=result["noise_level"],
        processing_time_ms=result["processing_time_ms"],
        status=result["status"],
        warning=result.get("warning"),
    )


# ── Session Cleanup ───────────────────────────────────────────────────────────

@router.delete("/api/session/{session_id}")
async def clear_session(session_id: str):
    """Clear a session buffer immediately (e.g., user cancels scan)."""
    processor.clear_session(session_id)
    return JSONResponse({"status": "cleared", "session_id": session_id})


# ── Internal Helpers ──────────────────────────────────────────────────────────

async def _delayed_cleanup(session_id: str, delay: float = 30.0) -> None:
    import asyncio
    await asyncio.sleep(delay)
    processor.clear_session(session_id)
    logger.debug(f"Auto-cleanup for session {session_id}")
