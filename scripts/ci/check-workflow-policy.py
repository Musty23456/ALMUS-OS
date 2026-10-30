#!/usr/bin/env python3
"""Fail-closed policy for ALMUS GitHub Actions workflows.

- Forbid pull_request_target and reusable workflow jobs.
- Require explicit top-level permissions; only read/none scopes are allowed.
- Job-level permissions, when present, must also be read/none only.
- Every job has a <=360 minute timeout.
- Any non-standard/dynamic/self-hosted runner is restricted to workflow_dispatch
  only, with concurrency, a literal protected Environment, and <=350 minutes.
"""
import glob
import sys

try:
    import yaml
except ImportError:
    sys.exit("PyYAML missing: sudo apt-get install -y python3-yaml")

FREE_LABELS = {"ubuntu-24.04", "ubuntu-22.04", "ubuntu-latest"}
errors = []


def triggers(doc):
    # PyYAML's default YAML 1.1 resolver treats the key `on` as boolean True.
    value = doc.get("on", doc.get(True))
    if value is None:
        return set()
    if isinstance(value, str):
        return {value}
    if isinstance(value, list):
        return set(value)
    if isinstance(value, dict):
        return set(value.keys())
    errors.append("workflow: invalid trigger declaration")
    return set()


def validate_permissions(path, label, permissions):
    if permissions is None:
        return
    if permissions == "write-all":
        errors.append(f"{path}: {label} permissions must not be write-all")
        return
    if not isinstance(permissions, dict):
        errors.append(f"{path}: {label} permissions must be a mapping of read/none scopes")
        return
    for scope, access in permissions.items():
        if access not in ("read", "none"):
            errors.append(f"{path}: {label} permission {scope}={access!r} is not read-only")


def is_free(runs_on):
    return isinstance(runs_on, str) and runs_on in FREE_LABELS


for path in sorted(glob.glob(".github/workflows/*.y*ml")):
    with open(path, encoding="utf-8") as handle:
        doc = yaml.safe_load(handle) or {}
    if not isinstance(doc, dict):
        errors.append(f"{path}: workflow root must be a mapping")
        continue
    trig = triggers(doc)
    if "pull_request_target" in trig:
        errors.append(f"{path}: pull_request_target is forbidden")

    if "permissions" not in doc:
        errors.append(f"{path}: missing top-level permissions")
    else:
        validate_permissions(path, "top-level", doc.get("permissions"))

    jobs = doc.get("jobs") or {}
    if not isinstance(jobs, dict) or not jobs:
        errors.append(f"{path}: jobs must be a non-empty mapping")
        continue

    restricted_jobs = []
    for name, job in jobs.items():
        if not isinstance(job, dict):
            errors.append(f"{path}: job {name} must be a mapping")
            continue
        if "uses" in job:
            errors.append(f"{path}: job {name} calls a reusable workflow; not allowed by policy")
            continue
        if "permissions" in job:
            validate_permissions(path, f"job {name}", job.get("permissions"))
        timeout = job.get("timeout-minutes")
        if not isinstance(timeout, int) or isinstance(timeout, bool) or timeout < 1 or timeout > 360:
            errors.append(f"{path}: job {name} needs integer timeout-minutes between 1 and 360")
        if not is_free(job.get("runs-on")):
            restricted_jobs.append((name, job))

    if restricted_jobs:
        other_triggers = trig - {"workflow_dispatch"}
        if other_triggers:
            errors.append(f"{path}: restricted-runner workflow has non-manual triggers {sorted(other_triggers)}")
        if "workflow_dispatch" not in trig:
            errors.append(f"{path}: restricted-runner workflow must be workflow_dispatch-only")
        if not isinstance(doc.get("concurrency"), (str, dict)):
            errors.append(f"{path}: restricted-runner workflow must declare concurrency")
        for name, job in restricted_jobs:
            environment = job.get("environment")
            if not isinstance(environment, str) or not environment.strip():
                errors.append(f"{path}: restricted job {name} must use a literal protected Environment name")
            timeout = job.get("timeout-minutes")
            if isinstance(timeout, int) and not isinstance(timeout, bool) and timeout > 350:
                errors.append(f"{path}: restricted job {name} timeout {timeout} > 350")

if errors:
    print("\n".join("POLICY VIOLATION: " + error for error in errors))
    sys.exit(1)
print("check-workflow-policy: OK")
