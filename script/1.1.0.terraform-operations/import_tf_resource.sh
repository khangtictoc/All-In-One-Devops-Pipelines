#!/usr/bin/env bash
set -euo pipefail

# Disable AWS CLI pager globally
export AWS_PAGER=""
export AWS_CLI_PAGER=""

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <terragrunt_module_dir> <resource_address> <resource_id>"
  echo "Example: $0 Terragrunt_Project_Structure_Design/environment/dev/kubernetes/aws/us-east-1/helm 'kubernetes_service_account_v1.alb_controller[0]' 'kube-system/aws-load-balancer-controller'"
  exit 1
fi

WORK_DIR="$1"
RESOURCE_ADDRESS="$2"
RESOURCE_ID="$3"

if [[ ! -d "$WORK_DIR" ]]; then
  echo "[ERROR] Terragrunt module directory does not exist: $WORK_DIR"
  exit 1
fi

if [[ -z "$RESOURCE_ADDRESS" || -z "$RESOURCE_ID" ]]; then
  echo "[ERROR] resource_address and resource_id must be provided"
  exit 1
fi

echo "[INFO] Importing resource into Terragrunt module: $WORK_DIR"
echo "[INFO] Resource address: $RESOURCE_ADDRESS"
echo "[INFO] Resource ID: $RESOURCE_ID"

echo "[INFO] Running terragrunt import..."
(
  cd "$WORK_DIR"
  terragrunt import --non-interactive "$RESOURCE_ADDRESS" "$RESOURCE_ID"
)

echo "[INFO] Resource import completed successfully."
