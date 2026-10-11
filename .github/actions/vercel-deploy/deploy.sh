#!/usr/bin/env bash
# `vercel deploy` waits only for READY or ERROR, so a deployment Vercel parks
# in BLOCKED (commit author not on the team) kept it polling for hours. Create
# it with --no-wait, then `vercel inspect --wait`, which stops on any final
# state. --archive=tgz uploads one tarball instead of many files, avoiding
# Vercel's per-day uploaded-file-count limit.
set -euo pipefail

# A deployment we stop waiting for keeps building on Vercel and, on push, can
# still promote to production after a newer one. Cancel it whenever we give up:
# on our own wait timeout, and on job cancellation (timeout-minutes or
# concurrency), when the runner sends SIGINT/SIGTERM before killing us.
url=""
cancel_deployment() {
  [ -n "$url" ] || return 0
  echo "::warning::Cancelling unfinished deployment $url"
  # The runner allows ~7s between SIGINT and SIGKILL, hence the short timeouts.
  local api="https://api.vercel.com" q="teamId=$VERCEL_ORG_ID" auth="Authorization: Bearer $VERCEL_TOKEN" id
  id=$(curl -fsS -m 3 -H "$auth" "$api/v13/deployments/${url#https://}?$q" | jq -r .id) &&
    curl -fsS -m 3 -X PATCH -H "$auth" "$api/v12/deployments/$id/cancel?$q" > /dev/null ||
    echo "::warning::Could not cancel $url"
}
trap 'cancel_deployment; exit 130' INT TERM

args=(--archive=tgz --yes --no-wait)
[ "$GITHUB_EVENT_NAME" = push ] && args+=(--prod)

# The CLI exits 1 when the deployment is created already BLOCKED, so don't stop
# here: take the URL from either stream and ask Vercel.
vercel deploy "${args[@]}" > "$RUNNER_TEMP/out.txt" 2>&1 || true
cat "$RUNNER_TEMP/out.txt"
url=$(grep -oE 'https://[^ ]+\.vercel\.app' "$RUNNER_TEMP/out.txt" | tail -n1 || true)
if [ -z "$url" ]; then
  echo "::error::vercel deploy did not create a deployment"
  exit 1
fi
echo "url=$url" >> "$GITHUB_OUTPUT"
# Scope to the "Inspect" line: the CLI also prints a telemetry docs URL.
inspect=$(grep -i inspect "$RUNNER_TEMP/out.txt" | grep -oE 'https://vercel\.com/[^ ]+' | head -n1 || true)
echo "inspect=$inspect" >> "$GITHUB_OUTPUT"

# Exits 0 on BLOCKED and 124 on timeout; the state check below decides.
vercel inspect "$url" --wait --timeout "$TIMEOUT" --format json > "$RUNNER_TEMP/inspect.json" || true
state=$(jq -r '.readyState // "UNKNOWN"' "$RUNNER_TEMP/inspect.json" 2>/dev/null || echo UNKNOWN)
echo "state=$state" >> "$GITHUB_OUTPUT"
case "$state" in
  READY | ERROR | CANCELED | BLOCKED) ;;
  *) cancel_deployment ;;
esac
if [ "$state" != READY ]; then
  echo "::error::Deployment $state: $(jq -r '.readyStateReason // empty' "$RUNNER_TEMP/inspect.json" 2>/dev/null) $url"
  exit 1
fi
