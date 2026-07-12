#!/bin/sh
# Human-run steps to build a BlackHole-derived EarWitness virtual mic.
# NOT run by the spike agent (no git access in the agent sandbox). Run on a
# real macOS box with Xcode. Steps transcribed from BlackHole's README.
set -e

NAME="EarWitnessMic"
BUNDLE_ID="ai.earwitness.mic"
DEVICE_NAME="EarWitness Microphone"
CHANNELS=2

# 1. Get the source
git clone --depth 1 https://github.com/ExistentialAudio/BlackHole.git
cd BlackHole

# 2. Build the .driver bundle with our name/channels baked in at compile time.
#    (BlackHole is configured entirely via preprocessor defines.)
xcodebuild \
  -project BlackHole.xcodeproj \
  -configuration Release \
  -target BlackHole \
  CONFIGURATION_BUILD_DIR=build \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  GCC_PREPROCESSOR_DEFINITIONS='$GCC_PREPROCESSOR_DEFINITIONS'" kNumber_Of_Channels=$CHANNELS kDriver_Name=\\\"$NAME\\\" kDevice_Name=\\\"$DEVICE_NAME\\\""
  # For DISTRIBUTION add: CODE_SIGN_IDENTITY="Developer ID Application: <TEAM>" \
  #                       and notarize the resulting .pkg (see create_installer.sh).
  # For a LOCAL unsigned smoke test add:
  #   CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# 3. Install (needs admin) and restart the CoreAudio daemon.
sudo cp -R "build/$NAME.driver" /Library/Audio/Plug-Ins/HAL/
sudo killall -9 coreaudiod   # coreaudiod respawns and rescans the HAL dir

# 4. Verify it appeared as BOTH an output and an input (loopback) device:
#    - open "Audio MIDI Setup", or
#    - system_profiler SPAudioDataType | grep -A3 "EarWitness"
#
# 5. To use as the "record notice on my mic" path (option (a) in README.md):
#    - pick "EarWitness Microphone" as the mic in Zoom/Teams/Meet
#    - from EarWitness, open the SAME device's OUTPUT via the miniaudio
#      playback path and play the notice / mic+notice mix into it.
