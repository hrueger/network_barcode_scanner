#!/bin/sh

set -e

VERSION=$(cat pubspec.yaml | grep 'version:' | awk '{print $2}' | cut -d '+' -f 1)
echo "Building version $VERSION"

mkdir -p out
flutter build apk --release
rm -rf out/network_barcode_scanner_$VERSION.apk
mv build/app/outputs/flutter-apk/app-release.apk out/network_barcode_scanner_$VERSION.apk

flutter build macos --release
rm -rf out/network_barcode_scanner_$VERSION.app.zip
cd build/macos/Build/Products/Release && zip -q -r ../../../../../out/network_barcode_scanner_$VERSION.app.zip network_barcode_scanner.app && cd -