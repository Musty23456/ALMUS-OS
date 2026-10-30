# Future Linux 16-core runner (NOT created in Phase 2)

Target: Linux x64, **16 vCPU, 64 GB RAM, 600 GB SSD**, GitHub-owned Ubuntu 24.04 image. Sizes match GitHub's larger-runner table. Availability: Team or Enterprise Cloud plans only.

## Capacity check against AOSP
| Need (AOSP docs) | Runner | Verdict |
|---|---|---|
| 400 GB free disk (250 checkout + 150 build) | 600 GB total (free space after OS/tools is UNMEASURED) | likely OK, verify with probe |
| 64 GB RAM minimum | 64 GB nominal (~62 GiB visible) | at the limit, no headroom; probe threshold set to 60 |
| Time | 6 h hosted cap | unmeasured; may not fit a cold sync+build |

## How to create it (verify menu names in GitHub's "Managing larger runners" docs)
1. Org Settings -> Actions -> Runners -> New runner -> **New GitHub-hosted runner**.
2. Name: `almus-linux-16c` (the exact label the workflows use). Platform Linux x64, image Ubuntu 24.04 (GitHub-owned), size 16-core/64 GB/600 GB.
3. Runner group: create `almus-paid`; repository access = this repo only; **workflow access = `build-aosp.yml` and `probe-runner.yml` only**; do not allow public repositories.
4. Maximum concurrency 1; autoscaling min 0.
5. Make sure budget and stop-usage are set (COST_CONTROL.md section 6).
6. Run `probe-runner` with target `paid-larger-16core` (needs Environment approval) and fill the report. Only if RAM/disk results meet minimums, proceed.
7. Set repo variable `ALMUS_BUILDS_ENABLED=true` only when Phase 3 approves a first build; unset it afterwards.

Machine description: `build/runners/almus-linux-16c.yaml`.

## Alternative that avoids per-minute billing
A self-hosted runner with label `almus-builder` on hardware you already own (64 GB RAM, 400+ GB free disk), in a dedicated VM, registered to a **private** repo. Same workflows, no GitHub per-minute fee currently, persistent disk for incremental builds. No VPS is required if you have such a machine; if you do not, this option is unavailable at no cost.
