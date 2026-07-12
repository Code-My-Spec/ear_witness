#!/usr/bin/env bash
#
# Builds the "EarWitness Microphone" macOS virtual audio device — a
# loopback-trick AudioServerPlugIn (HAL plug-in) derived from
# ExistentialAudio/BlackHole. Its OUTPUT is internally wired to its INPUT, so
# EarWitness plays a WAV into the device's output and any app that selected it
# as its microphone (Zoom/Teams/Meet) hears that audio on the input side. This
# is the mechanism story 871 uses to land a recording notice on the outgoing
# voice channel. See README.md.
#
# Output: build/EarWitnessMicrophone.driver  (a code-signed .driver bundle)
#
# This script only BUILDS the driver. Installing it is a machine-wide action
# (copy into /Library/Audio/Plug-Ins/HAL + restart coreaudiod) — see
# install.sh. This script never installs or touches coreaudiod.
#
# Why clang and not xcodebuild: a HAL plug-in is just a CFBundle built from a
# single C file linking CoreAudio/CoreFoundation/Accelerate. Building it
# directly with clang avoids a hard Xcode-project dependency and works on CI
# boxes with a broken/partial Xcode install. To build via Xcode instead, see
# the "xcodebuild alternative" note in README.md — both produce an equivalent
# bundle and both can be Developer-ID signed the same way.
set -euo pipefail

# --- Configuration ----------------------------------------------------------
BLACKHOLE_VERSION="0.6.0"
BLACKHOLE_URL="https://github.com/ExistentialAudio/BlackHole/archive/refs/tags/v${BLACKHOLE_VERSION}.tar.gz"

DRIVER_NAME="EarWitness"                              # kDriver_Name
DEVICE_NAME="EarWitness Microphone"                  # kDevice_Name (what apps see)
BUNDLE_ID="ai.earwitness.EarWitnessMicrophone"       # kPlugIn_BundleID (must match CFBundleIdentifier)
PRODUCT_NAME="EarWitnessMicrophone"                  # bundle + executable name
CHANNELS="2"                                         # kNumber_Of_Channels
# kSampleRates: BlackHole's default list already includes 8k/16k/44.1k/48k...
# so 16kHz-mono EarWitness WAVs play without extra config. Left at default.

# Ad-hoc ("-") signing is fine for local testing. For DISTRIBUTION set
# CODESIGN_IDENTITY to a "Developer ID Application: ..." identity and then
# notarize the bundle (see README.md — required or macOS Gatekeeper blocks
# the plug-in from loading on other machines).
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

# --- Paths ------------------------------------------------------------------
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR_DIR="${HERE}/vendor"
BUILD_DIR="${HERE}/build"
SRC_DIR="${VENDOR_DIR}/BlackHole-${BLACKHOLE_VERSION}"
DRIVER_BUNDLE="${BUILD_DIR}/${PRODUCT_NAME}.driver"

echo "==> EarWitness Microphone driver build"
echo "    device name : ${DEVICE_NAME}"
echo "    bundle id   : ${BUNDLE_ID}"
echo "    channels    : ${CHANNELS}"
echo "    sign identity: ${CODESIGN_IDENTITY}"

# --- 1. Fetch BlackHole source (cached) -------------------------------------
mkdir -p "${VENDOR_DIR}"
if [ ! -d "${SRC_DIR}" ]; then
  TARBALL="${VENDOR_DIR}/BlackHole-${BLACKHOLE_VERSION}.tar.gz"
  if [ ! -f "${TARBALL}" ]; then
    echo "==> Downloading BlackHole ${BLACKHOLE_VERSION}"
    curl -fsSL -o "${TARBALL}" "${BLACKHOLE_URL}"
  fi
  echo "==> Extracting"
  tar -xzf "${TARBALL}" -C "${VENDOR_DIR}"
fi

# --- 2. Compile the plug-in binary (universal: arm64 + x86_64) --------------
mkdir -p "${BUILD_DIR}"
BIN_OUT="${BUILD_DIR}/${PRODUCT_NAME}"
echo "==> Compiling plug-in binary"
clang -x c "${SRC_DIR}/BlackHole/BlackHole.c" \
  -arch arm64 -arch x86_64 \
  -mmacosx-version-min=11.0 \
  -O2 -bundle \
  -framework CoreAudio -framework CoreFoundation -framework Accelerate \
  -DkDriver_Name="\"${DRIVER_NAME}\"" \
  -DkPlugIn_BundleID="\"${BUNDLE_ID}\"" \
  -DkDevice_Name="\"${DEVICE_NAME}\"" \
  -DkNumber_Of_Channels="${CHANNELS}" \
  -o "${BIN_OUT}"

# --- 3. Assemble the .driver bundle -----------------------------------------
echo "==> Assembling ${PRODUCT_NAME}.driver"
rm -rf "${DRIVER_BUNDLE}"
mkdir -p "${DRIVER_BUNDLE}/Contents/MacOS" "${DRIVER_BUNDLE}/Contents/Resources"
mv "${BIN_OUT}" "${DRIVER_BUNDLE}/Contents/MacOS/${PRODUCT_NAME}"
cp "${SRC_DIR}/BlackHole/BlackHole.icns" "${DRIVER_BUNDLE}/Contents/Resources/BlackHole.icns"

sed -e "s/\${EXECUTABLE_NAME}/${PRODUCT_NAME}/g" \
    -e "s/\${PRODUCT_NAME}/${PRODUCT_NAME}/g" \
    -e "s#\$(PRODUCT_BUNDLE_IDENTIFIER)#${BUNDLE_ID}#g" \
    -e "s#\$(MARKETING_VERSION)#${BLACKHOLE_VERSION}#g" \
    "${SRC_DIR}/BlackHole/BlackHole.plist" > "${DRIVER_BUNDLE}/Contents/Info.plist"

plutil -lint "${DRIVER_BUNDLE}/Contents/Info.plist" >/dev/null

# --- 4. Codesign ------------------------------------------------------------
echo "==> Codesigning (${CODESIGN_IDENTITY})"
codesign --force --deep --sign "${CODESIGN_IDENTITY}" "${DRIVER_BUNDLE}"
codesign -dv "${DRIVER_BUNDLE}" 2>&1 | sed 's/^/    /'

echo ""
echo "==> Built: ${DRIVER_BUNDLE}"
echo "    Install it (machine-wide, needs sudo + coreaudiod restart):"
echo "      sudo ./install.sh"
