#!/usr/bin/env bash
# Runs a command and retries it only when it failed because a dependency could
# not be downloaded (GitHub's release CDN occasionally answers 502/503/504 or
# truncates large archives). Any other failure is reported immediately so real
# compile errors are never retried.
#
# Usage: bash .github/scripts/make-with-network-retry.sh <command> [args...]

set -uo pipefail

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <command> [args...]" >&2
  exit 2
fi

max_attempts="${MAKE_RETRY_ATTEMPTS:-8}"
retry_delay="${MAKE_RETRY_DELAY:-20}"
delay="$retry_delay"

is_transient_failure() {
  grep -Eq 'Gateway Time-?out|Error downloading|Error in download_and_extract|An error occurred during the fetch of repository|Could not resolve host|Connection (reset|refused|closed|timed out)|HTTP/2 stream|TLS handshake timeout|502 Bad Gateway|503 Service Unavailable|504 Gateway|transfer closed|Operation timed out|remote end hung up|unexpected EOF|early EOF|RPC failed|does not match SHA256|curl: \([0-9]+\)' "$1"
}

for (( attempt = 1; attempt <= max_attempts; attempt++ )); do
  attempt_log="$(mktemp "${TMPDIR:-/tmp}/make-attempt.XXXXXX")"
  echo "=== Attempt ${attempt}/${max_attempts}: $* ==="
  "$@" 2>&1 | tee "$attempt_log"
  status="${PIPESTATUS[0]}"

  # Make.py re-raises Bazel's exit status, but guard against a future change
  # that swallows it: a log that says the build failed is never a success.
  if [ "$status" -eq 0 ] && grep -q 'Build did NOT complete successfully' "$attempt_log"; then
    echo "=== Bazel reported a failed build despite a zero exit code ==="
    status=1
  fi

  if [ "$status" -eq 0 ]; then
    echo "MAKE_RETRY_RESULT: success"
    rm -f "$attempt_log"
    exit 0
  fi

  if is_transient_failure "$attempt_log" && [ "$attempt" -lt "$max_attempts" ]; then
    echo "=== Transient download failure on attempt ${attempt}/${max_attempts}; retrying in ${delay}s ==="
    rm -f "$attempt_log"
    sleep "$delay"
    if [ "$delay" -lt 180 ]; then
      delay=$((delay * 2))
      if [ "$delay" -gt 180 ]; then
        delay=180
      fi
    fi
    continue
  fi

  if is_transient_failure "$attempt_log"; then
    echo "=== Transient download failure persisted after ${max_attempts} attempts; giving up ==="
  else
    echo "=== Command failed for a non-transient reason (exit ${status}); not retrying ==="
  fi
  rm -f "$attempt_log"
  exit "$status"
done

exit 1
