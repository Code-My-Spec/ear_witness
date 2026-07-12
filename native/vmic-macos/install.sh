#!/usr/bin/env bash
#
# Installs the "EarWitness Microphone" virtual audio device system-wide.
#
# THIS IS A MACHINE-WIDE ACTION. It copies the HAL plug-in into
# /Library/Audio/Plug-Ins/HAL (root-owned) and restarts coreaudiod, which
# briefly interrupts ALL audio on the machine. Run it deliberately, with the
# user present. Requires sudo.
#
#   sudo ./install.sh
#
# After it runs, "EarWitness Microphone" appears in Audio MIDI Setup and as a
# selectable microphone/output in any app.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRIVER_BUNDLE="${HERE}/build/EarWitnessMicrophone.driver"
HAL_DIR="/Library/Audio/Plug-Ins/HAL"
DEST="${HAL_DIR}/EarWitnessMicrophone.driver"

if [ "$(id -u)" -ne 0 ]; then
  echo "error: must run as root (sudo ./install.sh)" >&2
  exit 1
fi

if [ ! -d "${DRIVER_BUNDLE}" ]; then
  echo "error: ${DRIVER_BUNDLE} not found — run ./build.sh first" >&2
  exit 1
fi

echo "==> Installing to ${DEST}"
mkdir -p "${HAL_DIR}"
rm -rf "${DEST}"
cp -R "${DRIVER_BUNDLE}" "${DEST}"

echo "==> Restarting coreaudiod (all audio briefly interrupts)"
killall coreaudiod || true

echo "==> Installed. Verify with:  system_profiler SPAudioDataType | grep -A2 EarWitness"
