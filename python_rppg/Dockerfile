FROM python:3.11-slim

# Install OS-level dependencies for OpenCV + curl for healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 libsm6 libxrender1 libxext6 libgl1 curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements first (Docker layer cache)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source
COPY . .

# Expose FastAPI port (Render sets $PORT dynamically)
EXPOSE 8001

# Health check using curl
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:${PORT:-8001}/health || exit 1

# Use $PORT env var if set (Render injects it), else default 8001
# workers=1 on free tier (no multiprocessing on Render free)
CMD uvicorn main:app --host 0.0.0.0 --port ${PORT:-8001} --workers 1
