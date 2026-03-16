# lambda-web-adapter-sample

A sample project that runs a standard web framework application on AWS Lambda using the [AWS Lambda Web Adapter](https://github.com/awslabs/aws-lambda-web-adapter).

## Project Structure

```
.
├── app/                        # Python application
│   ├── main.py                 # FastAPI app (DynamoDB CRUD)
│   ├── requirements.txt
│   ├── Dockerfile              # Container image with Lambda Web Adapter
│   └── .dockerignore
├── infrastructure/             # Terragrunt / OpenTofu infrastructure
│   ├── root.hcl                # Shared config (provider, remote state)
│   ├── project.hcl             # Project ID
│   ├── modules/
│   │   └── api-gateway/        # Custom REST API v1 module
│   └── envs/
│       └── dev/
│           ├── dynamodb/       # DynamoDB table
│           ├── ecr/            # ECR repository
│           ├── lambda/         # Lambda function (container image)
│           └── api-gateway/    # API Gateway
└── scripts/
    └── build_and_push.sh       # Docker build & ECR push script
```

## Architecture

```
Internet
    │
    ▼
API Gateway (REST API v1)
  ANY /
  ANY /{proxy+}
    │
    ▼  AWS_PROXY integration
Lambda Function
  ├── Container image (ECR)
  ├── Lambda Web Adapter (forwards to port 8080)
  └── IAM: DynamoDB CRUD + ECR Pull
    │
    ▼
DynamoDB Table
  PK: ITEM#{id}
  SK: ITEM#{id}
```

## Tech Stack

| Layer | Technology |
|---|---|
| IaC | [OpenTofu](https://opentofu.org/) + [Terragrunt](https://terragrunt.gruntwork.io/) |
| Runtime | Python 3.13 (container) |
| Web Framework | [FastAPI](https://fastapi.tiangolo.com/) + [Uvicorn](https://www.uvicorn.org/) |
| Lambda Adapter | [AWS Lambda Web Adapter](https://github.com/awslabs/aws-lambda-web-adapter) |
| Data Store | Amazon DynamoDB (PAY_PER_REQUEST) |
| Region | `us-west-2` |

## Prerequisites

- [OpenTofu](https://opentofu.org/docs/intro/install/) >= 1.11.5
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) >= 0.99.4
- [Docker](https://docs.docker.com/get-docker/)
- AWS CLI (configured with appropriate credentials)

## Deployment

### 1. Create DynamoDB table and ECR repository

```bash
cd infrastructure/envs/dev/dynamodb
terragrunt apply

cd ../ecr
terragrunt apply
```

### 2. Build and push the Docker image to ECR

```bash
# Run from the repository root
./scripts/build_and_push.sh
```

> **Note**  
> The script automatically retrieves the ECR URL from Terragrunt output.  
> Set `AWS_PROFILE` to use a specific AWS profile.

### 3. Deploy Lambda and API Gateway

```bash
cd infrastructure/envs/dev/lambda
terragrunt apply

cd ../api-gateway
terragrunt apply
```

### 4. Get the API endpoint

```bash
cd infrastructure/envs/dev/api-gateway
terragrunt output invoke_url
```

## API Reference

Base URL: `https://<api-id>.execute-api.us-west-2.amazonaws.com/dev`

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Health check |
| POST | `/items` | Create an item |
| GET | `/items/{id}` | Get an item |
| PUT | `/items/{id}` | Update an item |
| DELETE | `/items/{id}` | Delete an item |

### Examples

```bash
BASE_URL="https://<api-id>.execute-api.us-west-2.amazonaws.com/dev"

# Health check
curl $BASE_URL/health

# Create an item
curl -X POST $BASE_URL/items \
  -H "Content-Type: application/json" \
  -d '{"name": "Sample Item", "description": "A sample item"}'

# Get an item
curl $BASE_URL/items/<id>

# Update an item
curl -X PUT $BASE_URL/items/<id> \
  -H "Content-Type: application/json" \
  -d '{"name": "Updated Name"}'

# Delete an item
curl -X DELETE $BASE_URL/items/<id>
```

## How Lambda Web Adapter Works

[AWS Lambda Web Adapter](https://github.com/awslabs/aws-lambda-web-adapter) lets you run any web server (FastAPI, Flask, Express, Spring Boot, etc.) on Lambda without code changes.

The Dockerfile setup:

```dockerfile
# Copy the LWA binary from the official public ECR image
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.9.1 \
     /lambda-adapter /opt/extensions/lambda-adapter

# Port LWA will forward requests to
ENV PORT=8080
ENV AWS_LWA_READINESS_CHECK_PATH=/health

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

No custom handler or Mangum adapter is needed — the app runs as a standard HTTP server.

## Teardown

```bash
cd infrastructure/envs/dev/api-gateway && terragrunt destroy
cd ../lambda                             && terragrunt destroy
cd ../ecr                                && terragrunt destroy
cd ../dynamodb                           && terragrunt destroy
```