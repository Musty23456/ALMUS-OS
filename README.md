# ALMUS OS

Custom Android OS based on AOSP. **Status: Phase 2 (CI infrastructure only). No AOSP source has been synced and no build has been run.**

## Repository map — what is ours vs. AOSP's
AOSP itself (~250 GB) is **never committed here**; `repo` fetches it from Google. This repo holds only ALMUS-owned material.

| Path | Owner | Purpose |
|---|---|---|
| `.github/` | ALMUS | Workflows, composite probe action, Dependabot |
| `build/` | ALMUS | `AOSP_VERSION` pin, `targets.conf` allow-list, local manifest templates, runner descriptions |
| `device/almus/` | ALMUS | Future product/device config (synced into AOSP `device/almus/`) |
| `vendor/almus/` | ALMUS | Future overlays, AI Core, launcher, sepolicy, Hausa resources |
| `frameworks/`, `packages/`, `system/` | ALMUS (patch series only) | Future patches against the same-named AOSP trees; AOSP's own copies are never stored here |
| `scripts/ci/` | ALMUS | Probes, pin/policy/secret checks (run in free CI) |
| `scripts/build/` | ALMUS | Build templates, refuse to run unless explicitly enabled |
| `testing/` | ALMUS | Cuttlefish verifier, report folder |
| `docs/` | ALMUS | Setup, cost control, security, templates |
| `tools/` | ALMUS | Helper tooling (empty) |

## Workflows
| File | Trigger | Runner | Cost |
|---|---|---|---|
| `ci-validate.yml` | PR, push to main | standard hosted (free label only) | free on public repos; private repos use included minutes |
| `probe-runner.yml` | manual | you choose; self-hosted and paid are approval-gated | free target needs no approval |
| `build-aosp.yml` | manual, **disabled by default** | self-hosted or paid 16-core, approval-gated | see `docs/COST_CONTROL.md` |

Start with `docs/SETUP.md`.


**Probe safety:** runner and Cuttlefish probes are read-only. They do not modify `/dev/kvm` permissions. The AOSP host dependency installer runs only inside the manually approved build workflow.
# ALMUS-OS
