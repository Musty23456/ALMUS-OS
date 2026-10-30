#!/usr/bin/env bash
# Installs Google's documented Ubuntu AOSP host packages plus tools required by ALMUS sync.
# Invoked only after the manual workflow gates and protected Environment approval.
set -euo pipefail
if [ "${ALMUS_INSTALL_AOSP_DEPS:-no}" != "yes" ]; then
  echo "Refusing to install packages: set ALMUS_INSTALL_AOSP_DEPS=yes from the approved build workflow." >&2
  exit 1
fi
if [ "$(id -u)" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is required to install AOSP host packages." >&2
  exit 1
fi
APT=(apt-get)
if [ "$(id -u)" -ne 0 ]; then APT=(sudo apt-get); fi
"${APT[@]}" update
"${APT[@]}" install -y --no-install-recommends \
  git-core gnupg flex bison build-essential zip curl zlib1g-dev \
  libc6-dev-i386 x11proto-core-dev libx11-dev lib32z1-dev \
  libgl1-mesa-dev libxml2-utils xsltproc unzip fontconfig \
  python3 repo rsync
bash scripts/ci/check-aosp-deps.sh --strict
