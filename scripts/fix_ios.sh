#!/usr/bin/env bash
# Run once in your terminal when iOS build fails, then: flutter run
set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

cd "$(dirname "$0")/.."

echo "Cleaning Flutter..."
flutter clean

echo "Removing stale iOS build artifacts..."
rm -rf build/ios
rm -rf ios/Pods ios/Podfile.lock ios/.symlinks
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*

echo "Fetching dependencies..."
flutter pub get

echo "Installing CocoaPods..."
cd ios && pod install && cd ..

echo ""
echo "Done. Now run in your terminal:"
echo "  flutter run"
