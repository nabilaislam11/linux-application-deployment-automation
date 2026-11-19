#!/usr/bin/env bash
set -Eeuo pipefail
usage() { echo "Usage: $0 --release ID --root DIR --service NAME --health-url URL" >&2; }
release="" root="" service="" health_url=""
while (($#)); do
  (($# >= 2)) || { usage; exit 2; }
  case "$1" in
    --release) release=$2;; --root) root=$2;; --service) service=$2;;
    --health-url) health_url=$2;; *) usage; exit 2;;
  esac
  shift 2
done
[[ "$release" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ && "$release" != "." && "$release" != ".." ]] || exit 2
[[ "$root" == /* && "$root" != "/" && -n "$service" && -n "$health_url" ]] || exit 2
[[ "$service" =~ ^[a-zA-Z0-9@_.-]+$ ]] || exit 2
[[ "$health_url" == http://* || "$health_url" == https://* ]] || exit 2
root=${root%/}
[[ -d "$root" ]] || { echo "Deployment root not found" >&2; exit 1; }
exec 9>"$root/.deployment.lock"
flock -n 9 || { echo "Another deployment or rollback is running" >&2; exit 1; }
target="$root/releases/$release"
current="$root/current"
[[ -d "$target" && ! -L "$target" ]] || { echo "Release not found" >&2; exit 1; }
[[ -L "$current" ]] || { echo "Active release link missing" >&2; exit 1; }
previous=$(readlink -- "$current")
[[ "$previous" == "$root/releases/"* && -d "$previous" ]] || exit 1
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ln -s -- "$target" "$root/.current-rollback-$$"
mv -Tf -- "$root/.current-rollback-$$" "$current"
if systemctl restart "$service" && "$script_dir/verify.sh" --service "$service" --health-url "$health_url"; then
  echo "Rollback completed: $release"
else
  echo "Rollback verification failed; restoring prior active release" >&2
  ln -s -- "$previous" "$root/.current-recover-$$"
  mv -Tf -- "$root/.current-recover-$$" "$current"
  systemctl restart "$service" || true
  exit 1
fi
