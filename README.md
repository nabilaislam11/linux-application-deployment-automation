# Linux Application Deployment Automation

[![Deployment automation checks](https://github.com/nabilaislam11/linux-application-deployment-automation/actions/workflows/quality.yml/badge.svg)](https://github.com/nabilaislam11/linux-application-deployment-automation/actions/workflows/quality.yml)

Release-oriented deployment tooling for Linux services, featuring versioned releases, atomic activation, service lifecycle management, health verification, and rollback.

## Architecture

A release is installed in `releases/<release-id>/`, while `current` is a symbolic link to the active release. The deployment utility stages and validates a new release, switches the symlink, restarts the configured systemd service, and checks the application's health endpoint. If activation or verification fails, the utility restores the previous release link and restarts the service.

## Features

- Release staging from a local artifact directory
- Release ID validation, artifact checks, and deployment locking
- Atomic symlink replacement
- Previous-release rollback on failed activation
- systemd service restart and active-state verification
- HTTP readiness polling with bounded retries
- Non-destructive release history and deployment logging
- Dry-run preview, shell validation, and automated integration tests

## Requirements

Linux with Bash, Python 3, `systemctl`, `curl`, `flock` (util-linux), and GNU coreutils. The sample application uses only the Python standard library. Running a systemd-managed service requires an appropriately configured Linux host and sufficient privileges.

## Quick start

Run the tests before deploying:

```bash
bash tests/run.sh
```

Start the sample application locally:

```bash
python3 example-app/app.py
curl --fail http://127.0.0.1:8080/health
```

Inspect the sample systemd unit in `systemd/sample-app.service`. Set its `User`, `WorkingDirectory`, and `ExecStart` paths to match your deployment location before installing it.

Example deployment preview:

```bash
bash scripts/deploy.sh --release v1.0.0 --artifact ./example-app --root /opt/sample-app --service sample-app.service --health-url http://127.0.0.1:8080/health --dry-run
```

After configuring the systemd service, run the same command without `--dry-run` to activate the release. The deploy command writes a timestamped log under the chosen deployment root.

## Commands

| Command | Purpose |
|---|---|
| `scripts/deploy.sh` | Stage, activate, restart, verify, and automatically restore on failure |
| `scripts/rollback.sh` | Activate a specified existing release and verify recovery |
| `scripts/verify.sh` | Check systemd active state and HTTP readiness |
| `tests/run.sh` | Run static checks and isolated deployment integration tests |

## Repository layout

```text
example-app/        Sample HTTP application with /health and /version
scripts/            Deployment, rollback, and verification utilities
systemd/            Sample service unit
tests/              Isolated integration tests with command stubs
docs/               Deployment architecture and operational workflow
.github/workflows/  CI validation
```

## Deployment behavior

Deployment stops before activation if the artifact or release identifier is invalid. If the new release fails its post-switch checks, the previous release is reactivated. An initial deployment without a previous release cannot restore a prior version; the tool removes the failed active symlink and reports the failure. Explicit rollback targets an already staged release.

See [deployment design](docs/deployment-design.md) for release layout, verification, and failure handling, and [deployment operations](docs/operations.md) for operational checks.

Automated tests use isolated command stubs for systemd and HTTP checks. The GitHub Actions workflow runs these tests on each push and pull request.
