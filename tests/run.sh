#!/usr/bin/env bash
set -Eeuo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
bash -n "$repo"/scripts/*.sh
python3 -m py_compile "$repo/example-app/app.py"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/app"
cat > "$tmp/bin/systemctl" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  restart) [[ ! -f "$TEST_ROOT/fail_restart" ]];;
  stop) exit 0;;
  is-active) [[ ! -f "$TEST_ROOT/fail_health" ]];;
  *) exit 1;;
esac
STUB
cat > "$tmp/bin/curl" <<'STUB'
#!/usr/bin/env bash
[[ ! -f "$TEST_ROOT/fail_health" ]]
STUB
chmod +x "$tmp/bin/systemctl" "$tmp/bin/curl"
export PATH="$tmp/bin:$PATH" TEST_ROOT="$tmp"
cp -a "$repo/example-app/." "$tmp/app/"
bash "$repo/scripts/deploy.sh" --release v1.0.0 --artifact "$tmp/app" --root "$tmp/releases-root" --service sample-app.service --health-url http://127.0.0.1:8080/health --dry-run
[[ ! -e "$tmp/releases-root" ]] || { echo "Dry run modified filesystem" >&2; exit 1; }
bash "$repo/scripts/deploy.sh" --release v1.0.0 --artifact "$tmp/app" --root "$tmp/releases-root" --service sample-app.service --health-url http://127.0.0.1:8080/health
[[ $(readlink "$tmp/releases-root/current") == "$tmp/releases-root/releases/v1.0.0" ]]
echo v1.1.0 > "$tmp/app/VERSION"
bash "$repo/scripts/deploy.sh" --release v1.1.0 --artifact "$tmp/app" --root "$tmp/releases-root" --service sample-app.service --health-url http://127.0.0.1:8080/health
[[ $(readlink "$tmp/releases-root/current") == "$tmp/releases-root/releases/v1.1.0" ]]
bash "$repo/scripts/rollback.sh" --release v1.0.0 --root "$tmp/releases-root" --service sample-app.service --health-url http://127.0.0.1:8080/health
[[ $(readlink "$tmp/releases-root/current") == "$tmp/releases-root/releases/v1.0.0" ]]
echo v1.2.0 > "$tmp/app/VERSION"
touch "$tmp/fail_restart"
if bash "$repo/scripts/deploy.sh" --release v1.2.0 --artifact "$tmp/app" --root "$tmp/releases-root" --service sample-app.service --health-url http://127.0.0.1:8080/health; then
  echo "Expected deployment failure" >&2; exit 1
fi
[[ $(readlink "$tmp/releases-root/current") == "$tmp/releases-root/releases/v1.0.0" ]]
rm "$tmp/fail_restart"
echo "PASS: dry run, deployment, rollback, and failed activation recovery"
