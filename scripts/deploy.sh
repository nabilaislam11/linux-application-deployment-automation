#!/usr/bin/env bash
set -Eeuo pipefail
usage() { echo "Usage: $0 --release ID --artifact DIR --root DIR --service NAME --health-url URL [--dry-run]" >&2; }
release="" artifact="" root="" service="" health_url="" dry_run=0
while (($#)); do
  case "$1" in
    --release|--artifact|--root|--service|--health-url)
      (($# >= 2)) || { usage; exit 2; }
      case "$1" in
        --release) release=$2;; --artifact) artifact=$2;;
        --root) root=$2;; --service) service=$2;; --health-url) health_url=$2;;
      esac
      shift 2;;
    --dry-run) dry_run=1; shift;;
    *) usage; exit 2;;
  esac
done
[[ -n "$release" && -n "$artifact" && -n "$root" && -n "$service" && -n "$health_url" ]] || { usage; exit 2; }
[[ "$release" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ && "$release" != "." && "$release" != ".." ]] || { echo "Invalid release identifier" >&2; exit 2; }
[[ "$service" =~ ^[a-zA-Z0-9@_.-]+$ ]] || { echo "Invalid service name" >&2; exit 2; }
[[ "$root" == /* && "$root" != "/" ]] || { echo "Root must be an absolute non-root path" >&2; exit 2; }
[[ -d "$artifact" && -f "$artifact/app.py" && -f "$artifact/VERSION" ]] || { echo "Artifact requires app.py and VERSION" >&2; exit 2; }
[[ "$health_url" == http://* || "$health_url" == https://* ]] || { echo "Invalid health URL" >&2; exit 2; }
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=${root%/}
target="$root/releases/$release"
current="$root/current"
[[ ! -e "$target" && ! -L "$target" ]] || { echo "Release already exists: $release" >&2; exit 2; }
if ((dry_run)); then
  printf 'DRY RUN: stage %s -> %s, switch %s, restart %s, verify %s\n' "$artifact" "$target" "$current" "$service" "$health_url"
  exit 0
fi
mkdir -p "$root/releases" "$root/logs"
log="$root/logs/deploy-$(date -u +%Y%m%dT%H%M%SZ)-$$.log"
exec > >(tee -a "$log") 2>&1
echo "Deploying release: $release"
previous=""
if [[ -L "$current" ]]; then
  previous=$(readlink -- "$current")
  [[ "$previous" == "$root/releases/"* && -d "$previous" ]] || { echo "Invalid current release link" >&2; exit 1; }
elif [[ -e "$current" ]]; then
  echo "Current path is not a symlink" >&2; exit 1
fi
staging=$(mktemp -d "$root/releases/.stage.XXXXXXXX")
activated=0
recover() {
  local rc=$?
  trap - ERR
  if ((activated)); then
    echo "Activation failed; restoring previous release"
    if [[ -n "$previous" ]]; then
      ln -sfn -- "$previous" "$root/.current-restore-$$"
      mv -Tf -- "$root/.current-restore-$$" "$current"
      systemctl restart "$service" || true
      "$script_dir/verify.sh" --service "$service" --health-url "$health_url" || true
    else
      rm -f -- "$current"
      systemctl stop "$service" || true
    fi
  fi
  [[ ! -d "$staging" ]] || rm -rf -- "$staging"
  echo "Deployment failed (exit $rc)" >&2
  exit "$rc"
}
trap recover ERR
cp -a -- "$artifact/." "$staging/"
[[ -f "$staging/app.py" && -f "$staging/VERSION" ]]
[[ $(<"$staging/VERSION") == "$release" ]] || { echo "Artifact VERSION does not match release ID" >&2; false; }
python3 -m py_compile "$staging/app.py"
mv -- "$staging" "$target"
ln -s -- "$target" "$root/.current-next-$$"
mv -Tf -- "$root/.current-next-$$" "$current"
activated=1
systemctl restart "$service"
"$script_dir/verify.sh" --service "$service" --health-url "$health_url"
trap - ERR
echo "Deployment successful: $release"
