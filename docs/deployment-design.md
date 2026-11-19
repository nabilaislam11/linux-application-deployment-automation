# Deployment Design

## Release layout

```text
/opt/sample-app/
├── current -> /opt/sample-app/releases/v1.0.0
├── releases/
│   ├── v1.0.0/
│   └── v1.1.0/
└── logs/
```

Each release contains `app.py` and `VERSION`. The systemd unit executes the application through the `current` symlink. Release directories are retained so operators can select an earlier release.

## Deployment sequence

1. Validate release identifier, artifact directory, and target paths.
2. Stage the artifact under `releases/` and check its declared version.
3. Compile-check the sample Python application.
4. Atomically replace the active release symlink.
5. Restart the configured systemd unit.
6. Verify service active state and HTTP readiness.
7. Restore the previous symlink if restart or verification fails.

## Rollback

`rollback.sh` selects an existing release, restarts the service, and checks readiness. If rollback verification fails, it attempts to restore the prior active release.

## Operational considerations

- Deployment and rollback acquire a non-blocking advisory lock at `<root>/.deployment.lock` to prevent overlapping operations against one release root.
- A readiness endpoint returning HTTP 2xx establishes endpoint response, not full application correctness.
- The sample application uses Python's standard-library HTTP server; adapt the service unit, artifact checks, and health criteria to the actual workload.
- Deployment requires controlled permissions on the release root and systemd service. The scripts require `flock` (util-linux) and GNU coreutils.
- Review the installed service unit after changing its path, user, or environment.
