# Network QR Code Scanner

A Flutter app that allows you to scan QR codes and share them over the local network via UDP broadcast.

## Features

-   **Scanner Mode**: Scan QR codes using the device camera and broadcast them to the local network
-   **Listener Mode**: Listen for QR codes broadcast by other devices on the network and display them
-   Copy scanned codes to clipboard with a single tap
-   Real-time network communication using UDP broadcast

## How It Works

1. **Scanner Mode**:

    - Uses the device camera to scan QR codes
    - When a code is detected, it sends a UDP broadcast packet to port 8765
    - The broadcast is sent to the entire local network (255.255.255.255)

2. **Listener Mode**:
    - Listens on UDP port 8765 for incoming broadcast messages
    - Displays all received QR codes in a list
    - Shows timestamp for each code
    - Allows copying codes to clipboard

## Usage

1. Launch the app and select a mode:

    - **Scanner**: To scan QR codes and send them over the network
    - **Listener**: To receive QR codes from other devices

2. Make sure both devices are on the same local network

3. Grant camera permissions when prompted (Scanner mode only)

## Dependencies

-   `qr_code_scanner_plus`: QR code scanning functionality
-   `permission_handler`: Camera permission management

## Platform Requirements

### Android

-   Minimum SDK: 21
-   Permissions: Camera, Internet

### iOS

-   iOS 11.0 or higher
-   Permissions: Camera, Local Network

## Getting Started

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run
```
