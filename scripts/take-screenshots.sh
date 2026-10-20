#!/usr/bin/env bash
# Builds HabitGarden, runs it in the iOS Simulator and saves a screenshot of
# every screen into docs/screenshots/ (the images the README shows).
#
# Usage (from the project folder, on your Mac):
#   ./scripts/take-screenshots.sh
#   DEVICE="iPhone 17 Pro Max" ./scripts/take-screenshots.sh   # pick a simulator
#   APPEARANCE=dark ./scripts/take-screenshots.sh               # dark-mode shots
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE="${DEVICE:-iPhone 17 Pro}"
APPEARANCE="${APPEARANCE:-light}"
OUT="docs/screenshots"
DERIVED="build/screenshots"
WAIT="${WAIT:-4}"

# Screen name (as understood by ScreenshotMode.swift) -> file name
SCREENS=(
  "login:01-login"
  "habits:02-habit-list"
  "add-habit:03-add-habit"
  "emoji-picker:04-emoji-picker"
  "habit-detail:05-habit-detail"
  "garden:06-garden"
  "insights:07-insights"
  "empty:08-empty-state"
)

echo "▸ Finding simulator \"$DEVICE\"…"
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
devices = [d for rt in json.load(sys.stdin)["devices"].values() for d in rt]
match = [d for d in devices if d["name"] == name] or [d for d in devices if d["name"].startswith("iPhone")]
print(match[-1]["udid"] if match else "")
' "$DEVICE")
if [[ -z "$UDID" ]]; then
  echo "No iPhone simulator found. Install one in Xcode > Settings > Components." >&2
  exit 1
fi

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
open -a Simulator --args -CurrentDeviceUDID "$UDID" || true
xcrun simctl ui "$UDID" appearance "$APPEARANCE"
# Clean, App Store–style status bar (9:41, full battery, full signal)
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged \
  --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiBars 3 || true

echo "▸ Building (Debug)…"
xcodebuild -project HabitGarden.xcodeproj -scheme HabitGarden -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$DERIVED" build -quiet

APP="$DERIVED/Build/Products/Debug-iphonesimulator/HabitGarden.app"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")
xcrun simctl install "$UDID" "$APP"

mkdir -p "$OUT"
for entry in "${SCREENS[@]}"; do
  screen="${entry%%:*}"
  file="${entry##*:}"
  echo "▸ $screen → $OUT/$file.png"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -screenshot "$screen" >/dev/null
  sleep "$WAIT"
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$file.png" >/dev/null 2>&1
done

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl status_bar "$UDID" clear || true
echo "✓ Done — ${#SCREENS[@]} screenshots saved in $OUT/"
