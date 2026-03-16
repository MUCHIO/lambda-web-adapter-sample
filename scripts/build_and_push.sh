#!/usr/bin/env bash
# =============================================================================
# build_and_push.sh
#
# Logs in to ECR, builds the Docker image, and pushes it to the repository.
#
# Usage:
#   chmod +x scripts/build_and_push.sh
#   AWS_PROFILE=<profile> ./scripts/build_and_push.sh
#
# Environment variables (optional, defaults shown):
#   AWS_REGION   - Deployment region  (default: us-west-2)
#   ENVIRONMENT  - Environment name   (default: dev)
#   IMAGE_TAG    - Docker image tag   (default: latest)
# =============================================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-west-2}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
PROJECT_ID="lambda-web-adapter-sample"

# ---------------------------------------------------------------------------
# Retrieve ECR repository URL from Terragrunt output
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ECR_DIR="${REPO_ROOT}/infrastructure/envs/${ENVIRONMENT}/ecr"

echo ">>> Fetching ECR repository URL from Terragrunt..."
REPOSITORY_URL=$(
  cd "${ECR_DIR}" && \
  terragrunt output -raw repository_url 2>/dev/null
)

if [[ -z "${REPOSITORY_URL}" ]]; then
  echo "[ERROR] Could not retrieve repository_url from Terragrunt output."
  echo "        Make sure 'terragrunt apply' has been run for the ECR module."
  exit 1
fi

echo "    Repository URL: ${REPOSITORY_URL}"

# ---------------------------------------------------------------------------
# ECR login
# ---------------------------------------------------------------------------
ACCOUNT_ID=$(echo "${REPOSITORY_URL}" | cut -d'.' -f1)
echo ">>> Logging in to ECR (account: ${ACCOUNT_ID}, region: ${AWS_REGION})..."
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin \
      "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# ---------------------------------------------------------------------------
# Build & push
# ---------------------------------------------------------------------------
IMAGE_URI="${REPOSITORY_URL}:${IMAGE_TAG}"
APP_DIR="${REPO_ROOT}/app"

echo ">>> Building Docker image: ${IMAGE_URI}"
docker build \
  --platform linux/amd64 \
  -t "${IMAGE_URI}" \
  "${APP_DIR}"

echo ">>> Pushing image to ECR..."
docker push "${IMAGE_URI}"

echo ""
echo "✅  Push complete: ${IMAGE_URI}"
echo ""
echo "Next step – apply Lambda & API Gateway:"
echo "  cd ${REPO_ROOT}/infrastructure/envs/${ENVIRONMENT}"
echo "  terragrunt run-all apply"
