# Setup instructions (Phase 2)

Menu names below follow GitHub's UI as I know it; GitHub changes them, so check the linked docs if something differs.

## 1. Create the repository
1. Create an empty repo (private recommended while experimenting; a private repo's standard runner minutes count against your plan's included minutes).
2. Push this folder: `git init -b main && git add -A && git commit -m "Phase 2 infra" && git remote add origin <url> && git push -u origin main`.

## 2. Lock down Actions (Settings -> Actions -> General)
- Workflow permissions: **Read repository contents** (not read/write).
- Fork pull requests: **Require approval for all outside collaborators**; do not enable "send write tokens/secrets to fork PRs".
- Allow actions: "Allow ... select actions" and keep the list to `actions/*` (the only owners used here).
- Leave runner-related repository variable `ALMUS_BUILDS_ENABLED` **unset** (build-aosp.yml stays inert).

## 3. Branch protection on `main`
Require PRs, require the `ci-validate / validate` check, require code-owner review (uncomment `.github/CODEOWNERS` after replacing OWNER), block force pushes.

## 4. Environments (manual approval gates)
Settings -> Environments -> New environment. Create all three, add yourself (and ideally a second person) as **Required reviewers**, enable "Prevent self-review" if you have a second reviewer, and restrict "Deployment branches" to `main`:
- `self-hosted-runners` (guards probe-selfhosted)
- `paid-runners` (guards probe-paid)
- `expensive-builds` (guards build-aosp)

## 5. Spending protection (do this before ever creating a paid runner)
See `docs/COST_CONTROL.md` section 6.

## 6. Run the free probe (the first real evidence)
Actions -> **probe-runner** -> Run workflow -> target `github-hosted-free`. When it finishes, download artifact `probe-github-hosted-free` and fill in `docs/templates/COMPAT_REPORT_TEMPLATE.md`. The probe is read-only: it does not change KVM permissions or install udev rules. Until you do, **no hardware compatibility result exists**.

## 7. Pin maintenance
All third-party actions are pinned to full SHAs (`scripts/ci/check-pins.sh` enforces it in CI). Dependabot opens PRs to bump them. Before merging a bump, open the tag on GitHub and confirm the SHA matches the release.

## Run the checks locally
```bash
sudo apt-get install -y shellcheck libxml2-utils python3-yaml
git add -A   # the scanners read tracked files
bash scripts/ci/check-pins.sh && python3 scripts/ci/check-workflow-policy.py && bash scripts/ci/scan-secrets.sh
find scripts testing tools -name '*.sh' -print0 | xargs -0 shellcheck -x
```
