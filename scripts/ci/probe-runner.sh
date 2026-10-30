#!/usr/bin/env bash
# scripts/ci/probe-runner.sh
# Read-only probe: records what THIS machine actually offers and compares it with
# the AOSP documented minimums. It never claims anything it did not measure.
# Usage: probe-runner.sh [--strict]    (--strict: exit 1 if a minimum is missed)
# Env:   PROBE_OUT_DIR (default probe-out)  MIN_RAM_GB (default 60)  MIN_DISK_GB (default 400)
# NOTE: AOSP docs say 64 GB RAM. A nominal 64 GB VM reports ~62 GiB in MemTotal,
#       so the default threshold is 60. Change it if you want the strict doc value.
set -uo pipefail

STRICT=0; [ "${1:-}" = "--strict" ] && STRICT=1
OUT_DIR="${PROBE_OUT_DIR:-probe-out}"; mkdir -p "$OUT_DIR"
TXT="$OUT_DIR/probe.txt"; JSON="$OUT_DIR/probe.json"; : > "$TXT"
MIN_RAM_GB="${MIN_RAM_GB:-60}"; MIN_DISK_GB="${MIN_DISK_GB:-400}"

declare -A V
say() { echo "$*" | tee -a "$TXT"; }
rec() { V["$1"]="$2"; say "$1: $2"; }

say "== ALMUS runner probe $(date -u +%FT%TZ) =="
rec arch "$(uname -m)"
rec kernel "$(uname -r)"
rec os "$( (. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}") || echo unknown)"
rec cpu_model "$(awk -F: '/model name/ {gsub(/^ +/,"",$2); print $2; exit}' /proc/cpuinfo)"
rec cores "$(nproc)"
rec ram_gb "$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)"
rec swap_gb "$(awk '/SwapTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)"
rec disk_free_gb_cwd "$(df -P --block-size=1G . | awk 'NR==2 {print $4}')"
rec disk_total_gb_cwd "$(df -P --block-size=1G . | awk 'NR==2 {print $2}')"
rec runner_name "${RUNNER_NAME:-n/a}"
rec runner_environment "${RUNNER_ENVIRONMENT:-n/a}"   # github-hosted | self-hosted
rec virt_detected "$(systemd-detect-virt 2>/dev/null || echo unknown)"
rec cpu_virt_flag_cpus "$(grep -Ec '^flags.*\b(vmx|svm)\b' /proc/cpuinfo || true)"

if [ -e /dev/kvm ]; then
  rec dev_kvm "present: $(ls -l /dev/kvm)"
  if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then rec dev_kvm_rw "yes"; else rec dev_kvm_rw "no"; fi
else
  rec dev_kvm "MISSING"; rec dev_kvm_rw "no"
fi
nested="n/a"
for m in kvm_intel kvm_amd; do
  [ -r "/sys/module/$m/parameters/nested" ] && nested="$m=$(cat /sys/module/$m/parameters/nested)"
done
rec kvm_nested_param "$nested"
for m in vhost_vsock vhost_net; do
  if lsmod 2>/dev/null | grep -q "^$m"; then rec "module_$m" loaded
  elif modinfo "$m" >/dev/null 2>&1; then rec "module_$m" "available-not-loaded"
  else rec "module_$m" "not-found"; fi
done
say "-- df -h --"; df -h 2>/dev/null | tee -a "$TXT" >/dev/null

# --- verdict vs AOSP documented minimums ---
bad=0
[ "${V[arch]}" = "x86_64" ] || { say "MISS: need x86_64 (found ${V[arch]})"; bad=1; }
[ "${V[ram_gb]}" -ge "$MIN_RAM_GB" ] || { say "MISS: RAM ${V[ram_gb]} GB < $MIN_RAM_GB GB"; bad=1; }
[ "${V[disk_free_gb_cwd]}" -ge "$MIN_DISK_GB" ] || { say "MISS: free disk ${V[disk_free_gb_cwd]} GB < $MIN_DISK_GB GB"; bad=1; }
if [ "$bad" -eq 0 ]; then V[aosp_build_verdict]="MEETS_DOCUMENTED_MINIMUMS"; else V[aosp_build_verdict]="BELOW_DOCUMENTED_MINIMUMS"; fi
say "aosp_build_verdict: ${V[aosp_build_verdict]}  (this is NOT a build test)"

# --- JSON (sorted keys, simple escaping) ---
esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
{
  echo "{"
  first=1
  # shellcheck disable=SC2046
  for k in $(printf '%s\n' "${!V[@]}" | sort); do
    [ "$first" -eq 1 ] || echo ","
    first=0
    printf '  "%s": "%s"' "$k" "$(esc "${V[$k]}")"
  done
  echo; echo "}"
} > "$JSON"

[ "$STRICT" -eq 1 ] && exit "$bad"
exit 0
