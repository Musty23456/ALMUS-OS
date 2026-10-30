#!/usr/bin/env bash
# testing/cuttlefish/verify-cuttlefish.sh
# Cuttlefish compatibility detection.
#   verify-cuttlefish.sh check                       environment readiness only
#   verify-cuttlefish.sh boot --host-pkg DIR --images DIR [--timeout SEC]   (NEVER RUN YET)
#
# HONESTY RULES
#  * `check` can only say ENVIRONMENT_READY or ENVIRONMENT_NOT_READY. It never says Cuttlefish works.
#  * `boot` prints "COMPAT: BOOTED" only after adb returned sys.boot_completed=1 and evidence
#    files were written. `boot` has not been executed in Phase 2 (no images exist yet).
#  * Thresholds marked "heuristic" are ours, not Google's.
set -uo pipefail

MODE="${1:-check}"; shift || true
HOST=""; IMGS=""; TIMEOUT=600
while [ $# -gt 0 ]; do
  case "$1" in
    --host-pkg) HOST="$2"; shift 2;;
    --images)   IMGS="$2"; shift 2;;
    --timeout)  TIMEOUT="$2"; shift 2;;
    *) echo "unknown arg: $1"; exit 2;;
  esac
done

EV="${EVIDENCE_DIR:-evidence}"; mkdir -p "$EV"
REPORT="$EV/cuttlefish-compat.txt"; JSON="$EV/cuttlefish-compat.json"; : > "$REPORT"
fail=0
declare -A R
log()  { echo "$*" | tee -a "$REPORT"; }
item() { R["$2"]="$1"; log "[$1] $2 - $3"; [ "$1" = FAIL ] && fail=1; return 0; }

write_json() {  # $1 = overall status string
  { echo "{"; echo "  \"overall\": \"$1\","; echo "  \"mode\": \"$MODE\",";
    echo "  \"date_utc\": \"$(date -u +%FT%TZ)\",";
    echo "  \"runner\": \"${RUNNER_NAME:-n/a}\", \"runner_environment\": \"${RUNNER_ENVIRONMENT:-n/a}\",";
    echo "  \"kernel\": \"$(uname -r)\",";
    echo "  \"checks\": {"; f=1
    # shellcheck disable=SC2046
    for k in $(printf '%s\n' "${!R[@]}" | sort); do
      [ "$f" -eq 1 ] || echo ","; f=0; printf '    "%s": "%s"' "$k" "${R[$k]}"; done
    echo; echo "  }"; echo "}"; } > "$JSON"
}

# ---------------- environment checks ----------------
if [ "$(uname -m)" = x86_64 ]; then item PASS arch "x86_64"; else item FAIL arch "$(uname -m) (Cuttlefish x86_64 target assumed)"; fi

virt=$(grep -Ec '^flags.*\b(vmx|svm)\b' /proc/cpuinfo || true)
if [ "${virt:-0}" -gt 0 ]; then item PASS cpu-virt-flags "vmx/svm visible on $virt cpus"
else item FAIL cpu-virt-flags "no vmx/svm flag exposed to this VM"; fi

if [ -e /dev/kvm ]; then
  if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then item PASS kvm-access "/dev/kvm readable+writable"
  else item FAIL kvm-access "/dev/kvm exists but this user cannot rw it (udev rule needed)"; fi
else item FAIL kvm-device "/dev/kvm missing"; fi

for m in vhost_vsock vhost_net; do
  if lsmod 2>/dev/null | grep -q "^$m"; then item PASS "module-$m" "loaded"
  elif modinfo "$m" >/dev/null 2>&1; then item WARN "module-$m" "available but not loaded (modprobe needed)"
  else item FAIL "module-$m" "not found for kernel $(uname -r)"; fi
done

ram_gb=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
if   [ "$ram_gb" -ge 16 ]; then item PASS ram "${ram_gb} GB"
elif [ "$ram_gb" -ge 8 ];  then item WARN ram "${ram_gb} GB (heuristic: tight)"
else item FAIL ram "${ram_gb} GB (heuristic minimum 8)"; fi

disk_gb=$(df -P --block-size=1G . | awk 'NR==2 {print $4}')
if [ "$disk_gb" -ge 30 ]; then item PASS disk "${disk_gb} GB free"; else item WARN disk "${disk_gb} GB free (heuristic: 30 GB)"; fi

if command -v adb >/dev/null 2>&1; then item PASS tool-adb "$(command -v adb)"
else
  # hosted runners ship the Android SDK; adb may not be on PATH
  cand="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}/platform-tools/adb"
  if [ -x "$cand" ]; then item WARN tool-adb "found at $cand but not on PATH"; else item WARN tool-adb "not found (needed for boot mode)"; fi
fi
if command -v cvd >/dev/null 2>&1 || command -v launch_cvd >/dev/null 2>&1; then item PASS tool-cuttlefish-host "cvd/launch_cvd on PATH"
else item WARN tool-cuttlefish-host "not installed (expected before images exist; boot mode takes --host-pkg)"; fi

if [ "$MODE" = check ]; then
  if [ "$fail" -eq 0 ]; then
    log "COMPAT: ENVIRONMENT_READY (checks only; boot NOT tested)"; write_json ENVIRONMENT_READY; exit 0
  else
    log "COMPAT: ENVIRONMENT_NOT_READY (see FAIL lines)"; write_json ENVIRONMENT_NOT_READY; exit 1
  fi
fi

# ---------------- boot test (not executed in Phase 2) ----------------
[ "$MODE" = boot ] || { echo "mode must be check|boot"; exit 2; }
bail() { log "COMPAT: NOT_BOOTED ($1)"; write_json NOT_BOOTED; exit 1; }
[ "$fail" -eq 0 ] || bail "environment checks failed"
command -v adb >/dev/null 2>&1 || bail "adb not on PATH"
[ -x "$HOST/bin/launch_cvd" ] || bail "no executable $HOST/bin/launch_cvd"
ls "$IMGS"/*.img >/dev/null 2>&1 || bail "no .img files in $IMGS"

sudo modprobe vhost_vsock vhost_net 2>>"$REPORT" || true
export HOME="$PWD/cf-home"; mkdir -p "$HOME"
export ANDROID_PRODUCT_OUT; ANDROID_PRODUCT_OUT="$(readlink -f "$IMGS")"
export ANDROID_HOST_OUT;    ANDROID_HOST_OUT="$(readlink -f "$HOST")"
# launch_cvd flags differ between versions: confirm with `launch_cvd --help` first (UNVERIFIED).
( cd "$HOME" && "$ANDROID_HOST_OUT/bin/launch_cvd" --daemon ) >"$EV/launch_cvd.log" 2>&1 \
  || bail "launch_cvd failed; see launch_cvd.log"

SERIAL="0.0.0.0:6520"   # default instance-1 adb port (UNVERIFIED for the chosen branch)
adb start-server >/dev/null 2>&1; adb connect "$SERIAL" >/dev/null 2>&1
end=$((SECONDS+TIMEOUT)); booted=""
while [ "$SECONDS" -lt "$end" ]; do
  booted=$(adb -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
  [ "$booted" = 1 ] && break
  sleep 5
done
if [ "$booted" = 1 ]; then
  adb -s "$SERIAL" shell getprop ro.build.fingerprint | tr -d '\r' > "$EV/fingerprint.txt"
  adb -s "$SERIAL" shell getprop > "$EV/getprop.txt"
  adb -s "$SERIAL" logcat -d -t 500 > "$EV/logcat-tail.txt" 2>&1
  "$ANDROID_HOST_OUT/bin/stop_cvd" >/dev/null 2>&1 || true
  item PASS boot "sys.boot_completed=1"
  log "COMPAT: BOOTED fingerprint=$(cat "$EV/fingerprint.txt")"; write_json BOOTED; exit 0
fi
adb -s "$SERIAL" logcat -d -t 500 > "$EV/logcat-tail.txt" 2>&1 || true
"$ANDROID_HOST_OUT/bin/stop_cvd" >/dev/null 2>&1 || true
bail "sys.boot_completed never reached 1 within ${TIMEOUT}s"
