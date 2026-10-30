# Cost control

Prices below are GitHub's published list rates found on 2026-10-30 (GitHub Docs "Actions runner pricing"; same figures on several pages dated Sept 2026). **They change. Re-check before spending.** I did not test billing myself.

## 1. How paid runners are kept away from PRs and ordinary commits (defense in depth)
1. `ci-validate.yml` (the only PR/push workflow) uses `ubuntu-24.04` only.
2. `scripts/ci/check-workflow-policy.py` runs in that CI and **fails the PR** if any workflow job uses anything other than `ubuntu-24.04/22.04/latest` unless the workflow is `workflow_dispatch`-only, has `concurrency`, and the job has an `environment` and timeout <= 350. It also forbids `pull_request_target`.
3. `build-aosp.yml` additionally needs repo variable `ALMUS_BUILDS_ENABLED=true`, `main` ref, `confirm=BUILD`, a pinned AOSP version, a target on the allow-list, and **Environment approval**.
4. Runner group `almus-paid` (see RUNNER_16CORE.md) is restricted to this repo and named workflows, so other workflows cannot even select the runner.
5. Branch protection + CODEOWNERS on `.github/` so nobody can weaken 1-4 without review.
6. Spending budget set to stop usage (section 6), as the last line of defense.

## 2. Controls in the workflows
| Control | Where | Value |
|---|---|---|
| Manual trigger only | build/probe workflows | `workflow_dispatch` |
| Manual approval | Environments | `paid-runners`, `self-hosted-runners`, `expensive-builds` |
| Timeouts | every job | probes 20 min, guard 5, CI 15, build 350 (GitHub's own cap is 360 for hosted) |
| Concurrency | build/probe | one at a time, never cancel a running build |
| Artifact retention | upload steps | probes 7 d, images 7 d, build logs 14 d |
| Compression | image upload | level 1 (fast; AOSP images are large) |
| Fail fast | build preflight | `probe-runner.sh --strict` aborts in seconds if RAM/disk too small |

## 3. Cost estimate for the planned Linux 16-core runner
Rate: **$0.042 per minute** (Linux 16-core x64). Estimate = minutes x rate. Excludes artifact/cache storage, taxes, and per-minute rounding (GitHub rounds each job up to a whole minute).

| Build duration | Billable minutes | Compute cost | Feasible as one hosted job? |
|---|---|---|---|
| 1 hour | 60 | **$2.52** | yes |
| 3 hours | 180 | **$7.56** | yes |
| 5 hours | 300 | **$12.60** | yes, close to the cap |
| 10 hours | 600 | **$25.20** | **No.** Hosted jobs are killed at 6 h (360 min = $15.12 maximum per job) |

Important:
- **Nobody has measured how long a full ALMUS/AOSP build takes on 16 cores.** Google's reference: ~6 h on 6 cores/64 GB and ~40 min on 72 cores. A 16-core cold sync + build may or may not fit in 6 h. Treat the 1/3/5 h rows as scenarios, and the first paid run as an experiment with a $15.12 ceiling (350 min timeout = $14.70).
- A job killed at the time limit is still billed and produces nothing usable. This is the main financial risk.
- Larger runners are not free on public repos and need a Team or Enterprise Cloud plan; the plan fee itself is not in the table above.
- Self-hosted runner: GitHub currently bills no Actions minutes for it. A $0.002/min "platform charge" was announced for March 2026 and then postponed; I found no sign it took effect, but verify. (If it ever applied: 1 h = $0.12, 10 h = $1.20, plus your own hardware and power.) A self-hosted job may run up to 5 days, so 10-hour builds are possible there.

## 4. Build cache strategy
| Layer | Hosted larger runner | Self-hosted |
|---|---|---|
| AOSP source tree | Ephemeral VM: full re-sync every run (~250 GB, counts toward the 6 h cap). Cannot be cached (cache/artifact storage is far smaller; exact quota UNVERIFIED). | Persist `$ALMUS_AOSP_DIR` on disk; `repo sync` is then incremental |
| `out/` incremental build | Not preserved | Persisted: incremental builds take minutes per Google's docs |
| ccache (`ALMUS_USE_CCACHE=1`) | Possible only if a compressed cache fits the repo cache quota; benefit UNVERIFIED | Persistent `CCACHE_DIR` |
| Whole-build skip | Planned `build-key` = hash(AOSP_VERSION + manifests + patches + target); skip if images for that key already exist | same |

Conclusion: cost-effective incremental development needs a persistent disk, i.e. a self-hosted machine. On paid hosted runners every build is cold.

## 5. Rules of thumb for spending
- Probe first on the free runner. Only build on paid when the probe proves the target machine meets the minimums.
- One paid build at a time, from `main`, after a second look at the change set.
- Never retry a failed paid build blindly; read `logs/` first.
- Prefer one big verified build over many speculative ones.

## 6. GitHub Actions spending protection (recommended settings)
1. **Billing & licensing -> Budgets** (organization or enterprise): create a budget for GitHub Actions with a small cap and **enable "stop usage when budget is reached"**. A budget without that setting only sends alerts.
2. Set alert thresholds (e.g. 50/75/90%) to your email.
3. Keep the default **$0 spending limit** on a plan that has one until you deliberately create the paid runner.
4. Do not create the 16-core runner until the free probe report is filled in. Creating one costs nothing while idle; only job minutes are billed.
5. Set the runner's maximum concurrency to 1 and autoscaling minimum to 0.
6. Review **Billing -> Usage** after every paid run and record actual minutes in `testing/reports/`.
7. On a personal account on the Free plan, larger runners are not offered, which is itself a hard protection.
