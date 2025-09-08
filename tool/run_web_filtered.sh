#!/usr/bin/env bash
set -Eeuo pipefail

# Flutter Web (Chrome) runner that hides the noisy DWDS "Cannot send Null" messages
# while preserving an interactive TTY for hot-reload/hot-restart.
#
# Usage:
#   ./tool/run_web_filtered.sh [flutter-run-args...]
# Examples:
#   ./tool/run_web_filtered.sh
#   ./tool/run_web_filtered.sh --web-port 5555

if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: flutter not found in PATH" >&2
  exit 127
fi

# Ensure we are run from repo root so relative paths work when called via VS Code task
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

# Build the command; default device is Chrome in debug mode
CMD=(flutter run -d chrome)

# Pass through any additional arguments provided by the user
if [[ $# -gt 0 ]]; then
  CMD+=("$@")
fi

# On macOS, use 'script' to allocate a PTY so Flutter sees a TTY even when we pipe output.
# Then filter only the specific noisy DWDS lines.
# Notes:
# - We keep case-insensitive matching to be resilient to variations: "Null"/"null".
# - We skip the "DebugService: Error serving requests" line and its immediate
#   "Error: Unsupported operation: Cannot send Null" companion line.
# - All other output is passed through unmodified.

# Run and filter
script -q /dev/null "${CMD[@]}" 2>&1 | awk -v IGNORECASE=1 '
  /^DebugService:.*Error serving requests/ { skip_next = 1; next }
  skip_next == 1 {
    if ($0 ~ /Unsupported operation: *Cannot send Null/) { skip_next = 0; next }
    # If the next line is something else, stop skipping to avoid eating logs.
    skip_next = 0
  }
  /Unsupported operation: *Cannot send Null/ { next }
  { print; fflush() }
'