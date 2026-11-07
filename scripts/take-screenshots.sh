#!/bin/bash
# Takes the App Store screenshots with sample data (your own data is not used).
#
#   iPhone 6.9" and iPad 13":  ./scripts/take-screenshots.sh
#   One device only:           ./scripts/take-screenshots.sh "iPhone 17 Pro Max"
#
# List the simulator names you have with:  xcrun simctl list devices available
# The PNG files are saved in a folder on your Desktop, one subfolder per device.
# Each simulator is erased first (only the simulator, never your iPhone or iPad).

set -e
cd "$(dirname "$0")/.."

if [ $# -gt 0 ]; then
  DEVICES=("$@")
else
  # The 13-inch iPad Pro simulator's name changes with each chip (M4, M5...): find the one installed
  IPAD="$(xcrun simctl list devices available | grep -o 'iPad Pro 13-inch ([^)]*)' | head -1)"
  DEVICES=("iPhone 17 Pro Max")
  if [ -n "$IPAD" ]; then
    DEVICES+=("$IPAD")
  else
    echo "No 13-inch iPad Pro simulator found: add one in Xcode › Window › Devices and Simulators."
  fi
fi

take_screenshots() {
  DEVICE="$1"
  OUT="$HOME/Desktop/ToBeDone Screenshots/$DEVICE"
  rm -rf "$OUT"   # start with an empty folder, so no old screenshots are mixed in
  mkdir -p "$OUT"

  # Start from a clean simulator: a Home Screen that got stuck (for example after
  # adding widgets) can refuse to open the test runner ("RequestDenied").
  echo "Resetting simulator: $DEVICE"
  xcrun simctl shutdown "$DEVICE" 2>/dev/null || true
  xcrun simctl erase "$DEVICE"

  echo "Starting simulator: $DEVICE"
  xcrun simctl boot "$DEVICE" 2>/dev/null || true
  xcrun simctl bootstatus "$DEVICE" -b >/dev/null

  # Clean status bar like Apple's own screenshots: 9:41, full battery, full signal
  xcrun simctl status_bar "$DEVICE" override --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiBars 3 || true

  echo "Building and running the screenshot test (takes a few minutes the first time)..."
  TEST_RUNNER_SCREENSHOT_DIR="$OUT" xcodebuild test \
    -project ToBeDone.xcodeproj \
    -scheme ToBeDone \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -only-testing:ToBeDoneUITests/AppStoreScreenshots \
    -parallel-testing-enabled NO \
    -quiet || echo "Some screenshots failed on $DEVICE (the others are saved)."

  xcrun simctl status_bar "$DEVICE" clear || true
  xcrun simctl shutdown "$DEVICE" 2>/dev/null || true
  echo "Done: $OUT"
}

for DEVICE in "${DEVICES[@]}"; do
  take_screenshots "$DEVICE"
done

open "$HOME/Desktop/ToBeDone Screenshots"
