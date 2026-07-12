#!/bin/sh
# Build the Core Audio tap probe. Requires macOS 14.4+ SDK (present in Xcode 15.3+).
set -e
cd "$(dirname "$0")"
clang -fobjc-arc -O2 \
  -mmacosx-version-min=14.4 \
  -framework Foundation -framework CoreAudio -framework AudioToolbox \
  tap_probe.m -o tap_probe
echo "built ./tap_probe"
# Ad-hoc sign so the TCC (audio-capture) prompt has a stable-ish identity to key
# on. A real distribution build must be Developer ID signed + notarized and
# carry NSAudioCaptureUsageDescription in its Info.plist.
codesign -s - --force ./tap_probe 2>/dev/null && echo "ad-hoc signed" || echo "codesign skipped"
