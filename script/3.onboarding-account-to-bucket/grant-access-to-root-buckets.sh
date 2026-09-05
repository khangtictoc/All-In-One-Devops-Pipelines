#!/usr/bin/env bash

set -euo pipefail

: "${ACCOUNT_ID:?ACCOUNT_ID is required}"
: "${BUCKET_NAME:?BUCKET_NAME is required}"
: "${REGION:?REGION is required}"

if [[ ! "$ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
  echo "ERROR: ACCOUNT_ID must be a 12-digit AWS account ID" >&2
  exit 1
fi

if [[ -z "$BUCKET_NAME" ]]; then
  echo "ERROR: BUCKET_NAME cannot be empty" >&2
  exit 1
fi

if [[ -z "$REGION" ]]; then
  echo "ERROR: REGION cannot be empty" >&2
  exit 1
fi

PRINCIPAL="arn:aws:iam::${ACCOUNT_ID}:root"

if POLICY_DOCUMENT=$(aws s3api get-bucket-policy \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --query Policy \
  --output text 2>/dev/null); then
  echo "Existing policy found for bucket '$BUCKET_NAME'"
  POLICY=$(jq -r 'if type == "string" then fromjson else . end' <<< "$POLICY_DOCUMENT")
else
  echo "No existing policy found for bucket '$BUCKET_NAME'; creating a new one"
  POLICY=$(cat <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": []
}
JSON
)
fi

if jq -e --arg principal "$PRINCIPAL" \
  'any(.Statement[]?; (.Principal.AWS | if type == "array" then index($principal) != null else . == $principal end))' \
  <<< "$POLICY" >/dev/null; then
  echo "Account $ACCOUNT_ID already has access to '$BUCKET_NAME'; nothing to do"
  exit 0
fi

NEW_POLICY=$(jq \
  --arg account_id "$ACCOUNT_ID" \
  --arg bucket_name "$BUCKET_NAME" \
  '.Statement += [{
    "Effect": "Allow",
    "Principal": {
      "AWS": ("arn:aws:iam::" + $account_id + ":root")
    },
    "Action": [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetObjectTagging"
    ],
    "Resource": [
      ("arn:aws:s3:::" + $bucket_name),
      ("arn:aws:s3:::" + $bucket_name + "/*")
    ]
  }]' <<< "$POLICY")

echo "$NEW_POLICY" | aws s3api put-bucket-policy \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --policy file:///dev/stdin

echo "Account $ACCOUNT_ID added to bucket '$BUCKET_NAME'"

echo "Verifying policy update"

aws s3api get-bucket-policy \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --output json |
  jq --arg principal "$PRINCIPAL" \
  '.Policy | if type == "string" then fromjson else . end | .Statement[]? | select(.Principal.AWS | if type == "array" then index($principal) != null else . == $principal end)'