"""
PulseTrack rPPG Microservice — Pydantic Schemas
Defines request/response models for the FastAPI endpoints.
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from enum import Enum


class SignalQuality(str, Enum):
    EXCELLENT = "Excellent"
    GOOD = "Good"
    FAIR = "Fair"
    POOR = "Poor"
    INVALID = "Invalid"


class FrameRequest(BaseModel):
    """Single base64-encoded JPEG frame from Flutter camera."""
    frame_b64: str = Field(..., description="Base64-encoded JPEG image of the face ROI")
    timestamp_ms: int = Field(..., description="Client-side timestamp in milliseconds")
    session_id: str = Field(..., description="Unique scan session ID")


class RgbFrameRequest(BaseModel):
    """
    Lightweight alternative: pre-extracted mean RGB values from the forehead ROI.
    Flutter already does precise face-bounding-box ROI extraction with ML Kit,
    so sending R,G,B means is more accurate and 100x cheaper than JPEG streaming.
    """
    session_id: str = Field(..., description="Unique scan session ID")
    r: float = Field(..., ge=0.0, le=255.0, description="Mean red channel of forehead ROI")
    g: float = Field(..., ge=0.0, le=255.0, description="Mean green channel of forehead ROI")
    b: float = Field(..., ge=0.0, le=255.0, description="Mean blue channel of forehead ROI")
    timestamp_ms: int = Field(..., description="Client-side timestamp in milliseconds")
    fps: float = Field(default=30.0, ge=5.0, le=120.0, description="Camera FPS estimate")


class BatchFrameRequest(BaseModel):
    """Batch of frames for processing (used for final BPM calculation)."""
    frames: List[FrameRequest] = Field(..., min_length=30, max_length=600)
    fps: float = Field(default=30.0, ge=10.0, le=60.0)


class LiveFrameResponse(BaseModel):
    """Response after processing a single live frame."""
    session_id: str
    frames_collected: int
    bpm_estimate: Optional[int] = None  # Available after ~5 seconds
    signal_quality: SignalQuality
    confidence: float = Field(ge=0.0, le=100.0, description="Confidence percentage")
    noise_level: float
    face_alignment: str  # "good", "too_far", "off_center"
    message: str


class ScanResultResponse(BaseModel):
    """Final BPM result after full scan completion."""
    session_id: str
    bpm: int
    spo2_estimate: Optional[int] = None
    signal_quality: SignalQuality
    confidence: float
    noise_level: float
    processing_time_ms: int
    status: str  # "Normal", "Low", "High", "Alert"
    warning: Optional[str] = None


class HealthCheckResponse(BaseModel):
    status: str
    version: str
    gpu_available: bool
