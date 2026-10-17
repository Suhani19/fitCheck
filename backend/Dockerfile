# FitCheck FastAPI Backend Dockerfile
# Optimized for Google Cloud Run deployment
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080

WORKDIR /app

# Install minimal OS dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend application source
COPY . .

# Expose default Cloud Run container port
EXPOSE 8080

# Start Uvicorn bound to 0.0.0.0:$PORT (default 8080).
# Database migrations are intentionally NOT executed automatically during container startup
# to avoid concurrent migration deadlocks and permission risks across scaling instances.
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}"]
