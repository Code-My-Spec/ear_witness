#!/usr/bin/env bash
#
# Removes the "EarWitness Microphone" virtual audio device system-wide.
#
# MACHINE-WIDE ACTION: deletes the HAL plug-in and restarts coreaudiod, which
# briefly interrupts ALL audio on the machine. Requires sudo.
#
#   sudo ./uninstall.sh
set -euo pipefail

DEST="/Library/Audio/Plug-Ins/HAL/EarWitnessMicrophone.driver"

if [ "$(id -u)" -ne 0 ]; then
  echo "error: must run as root (sudo ./uninstall.sh)" >&2
  exit 1
fi

if [ -d "${DEST}" ]; then
  echo "==> Removing ${DEST}"
  rm -rf "${DEST}"
else
  echo "==> ${DEST} not present; nothing to remove"
fi

echo "==> Restarting coreaudiod (all audio briefly interrupts)"
killall coreaudiod || true

echo "==> Uninstalled."
