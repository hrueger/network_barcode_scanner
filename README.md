# Network Barcode Scanner

Scan barcodes with a phone or a handheld and have them typed on a computer, as
if a USB scanner were plugged in, over the local network.

- **Scanner** (Android, iOS): scans with the camera, or with the built-in scan
  engine of a handheld such as the Chainway C90, and sends every code to all
  listeners on the network.
- **Listener** (macOS, Windows, Linux): receives the codes, lists them, and
  optionally types each one into whatever app has focus, followed by Enter or
  Tab.

Phones are always scanners and computers always listeners; there is nothing to
choose.

## Download

Every [release](https://github.com/hrueger/network_barcode_scanner/releases)
carries:

| Platform | File                         | Notes                                                                                                   |
| -------- | ---------------------------- | ------------------------------------------------------------------------------------------------------- |
| Android  | `…apk`                       | Allow installs from unknown sources.                                                                    |
| macOS    | `…-macos.dmg`                | Signed and notarized. Drag the app to Applications.                                                     |
| Windows  | `…-windows-x64.zip`          | Unsigned: SmartScreen warns on first start (_More info → Run anyway_). Unzip anywhere and start the exe. |
| Linux    | `…-linux-x64.tar.gz`         | Unpack and run `network_barcode_scanner`. Needs GTK 3, GStreamer and libxdo.                             |

## Usage

1. Start the app on the computer. It opens the listener and announces itself on
   the network.
2. Start the app on the phone. The bar at the top names the listeners it found
   ("Sending to: …"). Orange means none was found.
3. Scan. The code shows up in the listener's list.

To have codes typed, turn on **Auto-Type on Receive** in the listener's
settings and pick the key pressed afterwards (Enter, Tab or none). Text is typed
as Unicode, so upper case, umlauts and symbols come out right on any keyboard
layout.

On macOS, auto-type needs permission to send keystrokes. The listener shows a
page that asks for it; macOS lists the app under _System Settings → Privacy &
Security → Accessibility_ and applies the permission after a restart, which the
page offers.

### Handhelds

On Android handhelds with a hardware scan engine (Chainway, Sunmi, and models
matching "C90") the scanner uses the trigger instead of the camera. The engine
must emit a broadcast Intent; the action and extra key are configurable under
**Settings → Scanner Settings** if the device doesn't use the defaults.

## How it works

Listeners advertise the Bonjour service `_barcodescan._udp` on port 38765.
Scanners browse for it and send each code as a UDP datagram to every listener
found, plus one broadcast to `255.255.255.255` for listeners of older versions.
Listeners drop duplicates by message id, and drop the same code arriving again
within 1.5 seconds.

A datagram is one JSON object:

```json
{ "id": "1727398123456-482913", "code": "40000395", "timestamp": 1727398123456 }
```

Bonjour plus unicast is what lets it work where broadcast doesn't: a sandboxed
macOS app never receives datagrams sent to `255.255.255.255`, and iOS only sends
broadcasts with a special entitlement from Apple.

## Development

```bash
flutter pub get
flutter run          # on a phone for the scanner, on the desktop for the listener
```

Bundle and package ids are `com.hannesrueger.networkBarcodeScanner` (Apple) and
`com.hannesrueger.network_barcode_scanner` (Android, Linux).

The app icon is drawn in `assets/icon/*.svg`. After changing it, render the PNGs
and regenerate the platform icons:

```bash
for f in icon icon_macos icon_foreground icon_background; do
  rsvg-convert -w 1024 -h 1024 assets/icon/$f.svg -o assets/icon/$f.png
done
dart run flutter_launcher_icons
git checkout ios/Runner.xcodeproj/project.pbxproj   # the generator breaks a build setting there
```

`packages/bixat_key_mouse` is a vendored copy of the plugin that types on
Windows and Linux (via enigo, built from Rust). macOS types natively in
`macos/Runner/MainFlutterWindow.swift`, because enigo requires the Accessibility
permission, which a sandboxed app can never get.

## Releasing

Set `version:` in `pubspec.yaml`, commit, then tag the commit with the same
version:

```bash
git tag v1.2.3 && git push origin v1.2.3
```

[`.github/workflows/release.yml`](.github/workflows/release.yml) builds all four
platforms and publishes the GitHub release. A platform that fails doesn't hold
back the others; the release notes name what is missing, and re-running the
workflow for the tag (_Actions → Release → Run workflow_) adds it later.

Signing:

- **Android**: upload key from the repository secrets `ANDROID_KEYSTORE_*` and
  `ANDROID_KEY_ALIAS`, kept in 1Password as "Network Barcode Scanner — Android
  upload key". Locally, copy `android/key.properties.example` to
  `android/key.properties`.
- **macOS**: Developer ID certificate from the technikpool match repo
  (`MATCH_*` secrets), notarized with the App Store Connect API key (`ASC_*`
  secrets). `cd macos && fastlane mac build` produces the same signed DMG
  locally, without notarizing.
