# Security rules

- **No secrets in the repo.** `scan-secrets.sh` blocks common credential patterns and any tracked key/keystore/image file. GitHub's own secret scanning/push protection should also be enabled.
- **Release signing keys never live in Git or on shared CI.** Phase 2 has no signing at all. Later: sign off-CI on a machine you control, or in a protected Environment with required reviewers.
- **Pinned actions.** Every third-party `uses:` must be a 40-hex SHA with a version comment. Only `actions/checkout` and `actions/upload-artifact` are used.
- **No untrusted code on privileged runners.** `pull_request_target` is forbidden by the policy check. PRs only reach `ci-validate.yml`, which uses a free hosted runner, read-only token and no secrets. Self-hosted and paid runners are reachable only from `workflow_dispatch` jobs gated by Environments.
- **Self-hosted runner hygiene:** run as an unprivileged user in a dedicated VM or container, never on a machine holding personal credentials, and never attach it to a public repository that accepts fork PRs.
- **Least privilege.** Top-level and job-level workflow permissions are read-only (`contents: read`); the policy checker rejects write permissions. Build failures are reported through retained workflow logs/artifacts, not issue creation.
- **Inputs are data.** Workflow inputs are passed through `env:` and quoted, never interpolated into script text.
- **KVM probing is read-only.** The probe never changes `/dev/kvm` permissions or installs udev rules. If KVM access is unavailable, record that result; do not weaken device permissions as part of an automated probe.
- **Artifacts:** short retention, no keys, review logs before sharing publicly.
