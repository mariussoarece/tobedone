#!/bin/bash
# Takes the App Store screenshots with sample data (your own data is not used).
#
#   iPhone 6.9":  ./scripts/take-screenshots.sh
#   iPad 13":     ./scripts/take-screenshots.sh "iPad Pro 13-inch (M5)"
#
# List the simulator names you have with:  xcrun simctl list devices available
# The PNG files are saved in a folder on your Desktop.

set -e
cd "$(dirname "$0")/.."

DEVICE="${1:-iPhone 17 Pro Max}"
OUT="$HOME/Desktop/ToBeDone Screenshots/$DEVICE"
mkdir -p "$OUT"

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
  -quiet

xcrun simctl status_bar "$DEVICE" clear || true

echo "Done. Screenshots are in: $OUT"
open "$OUT"
