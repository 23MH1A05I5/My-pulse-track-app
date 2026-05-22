"""
PulseTrack rPPG Microservice — FastAPI Entry Point
Starts the FastAPI application with CORS, structured logging, and lifespan management.

Run:
    uvicorn main:app --host 0.0.0.0 --port 8001 --reload
"""
import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.routes import router
from processors.rppg_processor import processor

# ── Logging ────────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("pulsetrack")


# ── Lifespan ───────────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown lifecycle hooks."""
    logger.info("🚀 PulseTrack rPPG Microservice starting up...")
    # Warm up NumPy / SciPy (first import can be slow)
    import numpy as np
    import scipy.signal
    _ = np.zeros(100)
    logger.info("✅ NumPy/SciPy warm-up complete")
    yield
    logger.info("🛑 PulseTrack rPPG Microservice shutting down — cleaning sessions...")
    processor.cleanup_stale_sessions(max_age_seconds=0)


# ── App ────────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="PulseTrack rPPG API",
    description=(
        "Real-time remote photoplethysmography microservice. "
        "Accepts camera frames from Flutter and returns BPM + signal quality."
    ),
    version="2.0.0",
    lifespan=lifespan,
    docs_url="/docs",   # Swagger UI
    redoc_url="/redoc",
)


# ── CORS ───────────────────────────────────────────────────────────────────────
# In production, restrict to your Flutter app domain / Node.js backend IP
ALLOWED_ORIGINS = os.environ.get(
    "ALLOWED_ORIGINS",
    "*"  # Mobile app connects from unknown IPs — open CORS on rPPG service
).split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # Allow all origins (mobile clients have dynamic IPs)
    allow_credentials=False,
    allow_methods=["GET", "POST", "DELETE"],
    allow_headers=["Content-Type", "Authorization"],
)


# ── Routes ─────────────────────────────────────────────────────────────────────
app.include_router(router)


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8001))
    # workers=1 for Windows (fork not available); use Docker on Linux for multi-worker
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False, workers=1)
