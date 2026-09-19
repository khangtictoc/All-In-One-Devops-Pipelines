#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 \"title\" \"working_dir\" [--] <command> [args...]" >&2
  exit 2
fi

title="$1"
working_dir="$2"
shift 2

if [[ "${1:-}" == "--" ]]; then
  shift
fi

if [[ -z "$title" || -z "$working_dir" ]]; then
  echo "title and working_dir are required" >&2
  exit 2
fi

cd "$working_dir"

summary_date="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"

terragrunt_step() {
  local step_title="$1"
  shift
  local log_file
  log_file="$(mktemp)"
  trap 'rm -f "$log_file"' RETURN

  if "$@" 2>&1 | tee "$log_file"; then
    echo "::notice title=${step_title}::Succeeded"
    return 0
  fi

  local rc=$?
  local raw_log
  raw_log="$(tr -d '\r' < "$log_file")"
  local encoded_log
  encoded_log="${raw_log//%/%25}"
  encoded_log="${encoded_log//$'\n'/%0A}"
  encoded_log="${encoded_log//$'\r'/%0D}"

  {
    echo "## ${step_title}"
    echo "- Date: ${summary_date}"
    echo "- Status: failed"
    echo "- Exit code: ${rc}"
    echo ""
    echo "### Full Terragrunt error log"
    echo '```text'
    printf '%s\n' "$raw_log"
    echo '```'
  } >> "$GITHUB_STEP_SUMMARY"

  echo "::error title=${step_title}::${encoded_log}"
  return "$rc"
}

terragrunt_step "$title" "$@"
