# syntax=docker/dockerfile:1

##############################################################
# Stage 1 – builder
#   Install Python dependencies into /app so they can be
#   copied cleanly to the runtime stage.
##############################################################
FROM python:3.13-slim AS builder

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


##############################################################
# Stage 2 – runtime
#   Copy Lambda Web Adapter binary from the official public
#   ECR image, then add our application.
#
#   LWA listens for the Lambda runtime protocol and proxies
#   HTTP requests to the application on $PORT (default 8080).
##############################################################
FROM python:3.13-slim

# ── Lambda Web Adapter ──────────────────────────────────────
# Copy the LWA binary to the Lambda extensions directory.
# This file is automatically detected and executed by the
# Lambda runtime before invoking the function handler.
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.9.1 \
     /lambda-adapter /opt/extensions/lambda-adapter

WORKDIR /app

# ── Application dependencies ────────────────────────────────
COPY --from=builder /install /usr/local

# ── Application source ──────────────────────────────────────
COPY main.py .

# ── Runtime configuration ───────────────────────────────────
# PORT: the port LWA will forward requests to (must match uvicorn's --port)
ENV PORT=8080

# Tell LWA to use the /health endpoint for readiness probes
ENV AWS_LWA_READINESS_CHECK_PATH=/health

# Lambda Web Adapter passes the request body as-is; uvicorn handles it.
EXPOSE 8080

# uvicorn is started as the entrypoint.
# LWA will proxy API Gateway events to this HTTP server.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
