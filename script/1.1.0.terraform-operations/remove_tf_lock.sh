#!/usr/bin/env bash
set -euo pipefail

# Disable AWS CLI pager globally
export AWS_PAGER=""
export AWS_CLI_PAGER=""

BUCKET="$1"
KEY="$2"

if [[ -z "$BUCKET" || -z "$KEY" ]]; then
  echo "Usage: $0 <bucket> <key>"
  echo "Example: $0 terraform-state-backend-4ft9tj565 environment/dev/aws/us-east-1/eks/terragrunt.tfstate"
  exit 1
fi

if [[ "$KEY" == *.tflock ]]; then
  LOCK_KEY="$KEY"
else
  LOCK_KEY="${KEY}.tflock"
fi

echo "[INFO] Checking S3 lock object: s3://$BUCKET/$LOCK_KEY"

if aws s3api head-object --bucket "$BUCKET" --key "$LOCK_KEY" >/dev/null 2>&1; then
  echo "[INFO] Lock object exists. Deleting..."
  aws s3api delete-object --bucket "$BUCKET" --key "$LOCK_KEY"
  echo "[INFO] Deleted lock object: s3://$BUCKET/$LOCK_KEY"
else
  echo "[INFO] No lock object found. Nothing to delete."
  echo "[INFO] Normalized lock key checked: s3://$BUCKET/$LOCK_KEY"
fi
