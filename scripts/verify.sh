#!/usr/bin/env bash
set -Eeuo pipefail
usage() { echo "Usage: $0 --service NAME --health-url URL [--attempts N] [--delay N]" >&2; }
service="" health_url="" attempts=10 delay=2
while (($#)); do
  case "$1" in
    --service|--health-url|--attempts|--delay)
      (($# >= 2)) || { usage; exit 2; }
      case "$1" in
        --service) service=$2;; --health-url) health_url=$2;;
        --attempts) attempts=$2;; --delay) delay=$2;;
      esac
      shift 2;;
    *) usage; exit 2;;
  esac
done
[[ -n "$service" && -n "$health_url" ]] || { usage; exit 2; }
[[ "$attempts" =~ ^[1-9][0-9]*$ && "$delay" =~ ^[0-9]+$ ]] || { echo "Invalid retry settings" >&2; exit 2; }
[[ "$health_url" == http://* || "$health_url" == https://* ]] || { echo "HTTP(S) health URL required" >&2; exit 2; }
for ((i=1;i<=attempts;i++)); do
  if systemctl is-active --quiet "$service" && curl --fail --silent --show-error --max-time 5 --output /dev/null "$health_url"; then
    echo "PASS: service active and HTTP health endpoint responding"
    exit 0
  fi
  ((i==attempts)) || sleep "$delay"
done
echo "FAIL: service or HTTP health verification unsuccessful" >&2
exit 1
