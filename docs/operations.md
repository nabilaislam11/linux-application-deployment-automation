# Deployment Operations

## Release preparation

Prepare an artifact directory containing `app.py` and `VERSION`. The release identifier passed to `deploy.sh` must match the contents of `VERSION`.

## Deployment checks

The deployment script validates inputs, stages the artifact, checks Python syntax, switches the active symlink, restarts the configured systemd unit, and polls the HTTP readiness endpoint. The systemd unit's `ExecStart` must reference the active symlink path.

## Recovery

When activation fails, the deployment script attempts to restore the prior symlink and restart the service. Inspect the service status and journal after any unsuccessful deployment, including when automatic recovery was attempted. For deliberate version selection, use `rollback.sh` with an existing release ID.

## Useful diagnostics

```bash
systemctl status sample-app.service --no-pager
journalctl -u sample-app.service -n 100 --no-pager
readlink /opt/sample-app/current
curl --fail http://127.0.0.1:8080/health
```

## Release directory permissions

Keep the deployment root writable only by the authorized deployment identity. The application service identity needs read access to the active release, but not write access to release directories. Avoid concurrent deployments to the same release root.
