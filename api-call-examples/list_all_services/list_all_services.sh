#!/usr/bin/env bash
#
# list_all_services.sh — reliably list every socket in an org using cursor pagination.
#
# Walks GET /api/v1/sockets in cursor mode, following `next_cursor` until the scan is
# complete. Because cursor mode orders by an immutable key and seeks (rather than using
# page/offset), the full scan won't skip or duplicate sockets even if sockets are created,
# deleted, or (dis)connected while it runs.
#
# Requires: curl, jq
#
# Auth: set BORDER0_ADMIN_TOKEN, or place a token at ~/.border0/token (e.g. via `border0 login`).
#
# Usage:
#   ./list_all_services.sh [flags]
#
# Flags:
#   --search-term <str>   Case-insensitive substring match against name and display_name.
#   --page-size <n>       Sockets per request (1-100). Default 100. Does not change the total
#                         result set — only how many round-trips the scan takes.
#   --api <url>           API base URL. Default: $BORDER0_API or https://api.border0.com
#   -h, --help            Show this help and exit.
#
# Examples:
#   ./list_all_services.sh
#   ./list_all_services.sh --search-term prod
#   ./list_all_services.sh --search-term prod --page-size 3

set -euo pipefail

API="${BORDER0_API:-https://api.border0.com}"
SEARCH=""
PAGE_SIZE=100   # server max is 100

usage() {
  # Print the leading comment block (lines starting with #) as help text.
  sed -n '3,27p' "$0" | sed 's/^# \{0,1\}//'
}

# get_auth_token resolves the admin token the same way the other examples in this repo do:
# the BORDER0_ADMIN_TOKEN environment variable, falling back to the ~/.border0/token file.
get_auth_token() {
  if [ -n "${BORDER0_ADMIN_TOKEN:-}" ]; then
    printf '%s' "$BORDER0_ADMIN_TOKEN"
    return
  fi
  if [ -r "$HOME/.border0/token" ]; then
    tr -d '[:space:]' < "$HOME/.border0/token"
    return
  fi
  echo "error: no token found. Set BORDER0_ADMIN_TOKEN or run 'border0 login' to create ~/.border0/token" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --search-term)
      [ $# -ge 2 ] || { echo "error: --search-term requires a value" >&2; exit 1; }
      SEARCH="$2"; shift 2 ;;
    --search-term=*)
      SEARCH="${1#*=}"; shift ;;
    --page-size)
      [ $# -ge 2 ] || { echo "error: --page-size requires a value" >&2; exit 1; }
      PAGE_SIZE="$2"; shift 2 ;;
    --page-size=*)
      PAGE_SIZE="${1#*=}"; shift ;;
    --api)
      [ $# -ge 2 ] || { echo "error: --api requires a value" >&2; exit 1; }
      API="$2"; shift 2 ;;
    --api=*)
      API="${1#*=}"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "error: unknown argument: $1" >&2
      echo "run with --help for usage" >&2
      exit 1 ;;
  esac
done

# Validate page size locally (the server rejects >100 with a 400; fail fast with a clear message).
case "$PAGE_SIZE" in
  ''|*[!0-9]*) echo "error: --page-size must be a positive integer, got: $PAGE_SIZE" >&2; exit 1 ;;
esac
if [ "$PAGE_SIZE" -lt 1 ] || [ "$PAGE_SIZE" -gt 100 ]; then
  echo "error: --page-size must be between 1 and 100, got: $PAGE_SIZE" >&2
  exit 1
fi

for bin in curl jq; do
  command -v "$bin" >/dev/null || { echo "error: $bin is required" >&2; exit 1; }
done

TOKEN="$(get_auth_token)"

# cursor starts empty: an empty cursor opts into cursor mode and starts from the beginning.
cursor=""
page=0
total=0

while :; do
  page=$((page + 1))

  # The `cursor` param is ALWAYS sent (empty on the first request) — its presence is what selects
  # cursor mode. page_size still applies; page is not used. curl -G moves these into the query
  # string and --data-urlencode handles escaping, so the empty cursor is sent as `?cursor=`.
  resp="$(curl -fsS -G "$API/api/v1/sockets" \
    -H "Authorization: $TOKEN" \
    --data-urlencode "page_size=$PAGE_SIZE" \
    ${SEARCH:+--data-urlencode "search=$SEARCH"} \
    --data-urlencode "cursor=$cursor")" || {
    echo "error: request for page $page failed" >&2
    exit 1
  }

  # Emit one line per socket: <socket_id> <name>
  count="$(jq -r '.list | length' <<<"$resp")"
  jq -r '.list[] | "\(.socket_id)\t\(.name)"' <<<"$resp"
  total=$((total + count))
  echo "# page $page: $count sockets (running total: $total)" >&2

  # Advance. An empty/absent next_cursor means the scan is complete.
  cursor="$(jq -r '.next_cursor // ""' <<<"$resp")"
  [ -n "$cursor" ] || break
done

echo "# done: $total sockets total" >&2
