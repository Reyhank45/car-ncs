# Car NCS 🏎️ 🎶

An automotive-grade, landscape-locked cockpit music player and flightdeck telemetry display tailored for streaming and caching **NoCopyrightSounds (NCS)** audio directly on Android and Linux car head units or dashboard-mounted phones.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Target Platform](https://img.shields.io/badge/Architecture-ARMv8%20(arm64--v8a)-success)](#building-the-apk)

---

## Highlights & Features

- **Automotive Cockpit UI**:
  - Locked to landscape orientation with immersive edge-to-edge UI.
  - Large tactile transport controls designed for high-contrast visibility and gloved/quick-touch operation.
  - Responsive 3-column dashboard: Navigation Rail (Col 1), Persistent Playback Deck (Col 2), Dynamic Telemetry / Viewport Deck (Col 3).
- **Progressive Stream-to-Disk Playback**:
  - Low-latency live streaming: Starts playing in 1–2 seconds via tuned `just_audio` buffer thresholds.
  - Detached background caching: A background worker downloads and assembles the full `.mp3` file to disk concurrently.
  - Seamless seek upgrade: Once the local file finishes downloading, backward seeking upgrades to the local file for instant 0 ms seek response with zero network consumption.
- **High-Throughput 4-Chunk Parallel Downloader**:
  - Probes AWS S3 origin and splits files into 4 concurrent byte-range streams (`bytes=start-end`), achieving ~210 KiB/s over intercontinental links.
  - File assembly and chunk stitching run strictly inside background isolates (`Isolate.spawn`), keeping the main UI thread at 60/120 FPS.
- **Warm In-Memory Genre Pools & Non-Blocking Switching**:
  - Pre-scrapes track metadata for major genres (`Trap`, `House`, `Dubstep`) in the background on app start.
  - Tapping genre tiles initiates playback immediately from in-memory pools without blocking on cold HTML scrapes.
  - Strict 6-second timeout safety with automatic page-1 retry.
- **Instant Abort & Zero Zombie Connections**:
  - Skipping tracks or switching genres immediately terminates the background isolate and closes active HTTP sockets, pivoting 100% bandwidth to the new selection.
- **Automotive Telemetry & Flightdeck Metrics**:
  - Live GPS ground speed readout (`KM/H` and `KM/MIN`).
  - GPS WGS84 elevation and barometric altitude calculation.
  - Monospaced coordinates in Degrees & Decimal Minutes.
  - Throttled to **2 Hz (500ms)** with isolated `ValueNotifier` bindings to eliminate CPU thermal spikes and phone overheating.
  - Isolated GPU `RepaintBoundary` wrappers on persistent deck cards and album artwork.
- **Zero Mock / Fallback Audio Enforcement**:
  - Plays exclusively genuine production NCS tracks scraped directly from official AWS S3 endpoints. Never plays synthetic sine waves, silent buffers, or mock audio assets.

---

## Architecture Overview

```
                      ┌─────────────────────────────────────────┐
                      │          CarAudioHandler (Core)         │
                      └────┬───────────────────────────────┬────┘
                           │                               │
             ┌─────────────▼───────────────┐ ┌─────────────▼──────────────┐
             │         AudioPlayer         │ │     NcsDownloadManager     │
             │   (Low-latency streaming &  │ │   (4-chunk parallel isolate│
             │     local disk playback)    │ │    worker, ~210 KiB/s)     │
             └─────────────────────────────┘ └─────────────┬──────────────┘
                                                           │
                                             ┌─────────────▼──────────────┐
                                             │      Local Disk Cache      │
                                             │  (<tempDir>/ncs_cache/*.mp3│
                                             │     max 10 tracks LRU)     │
                                             └────────────────────────────┘
```

---

## Getting Started

### Prerequisites
- **Flutter SDK**: `>=3.10.0`
- **Android SDK**: API 34+
- **Java JDK**: 17

### Installation & Running

1. Clone the repository:
   ```bash
   git clone https://github.com/Reyhank45/car-ncs.git
   cd car-ncs
   ```

2. Fetch Flutter packages:
   ```bash
   flutter pub get
   ```

3. Run the automated test suite:
   ```bash
   flutter test
   ```

4. Run locally (connected Android device or Linux desktop):
   ```bash
   flutter run
   ```

---

## Building the APK

To build the optimized release APK targeting 64-bit ARMv8 devices:

```bash
flutter build apk --target-platform android-arm64 --release
```

The compiled binary will be located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## Telemetry Permissions (Android)

Car NCS utilizes the device GPS hardware to render velocity and elevation telemetry. Ensure location permissions are granted when prompted, or configure via:

- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`

---

## License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See the [LICENSE](LICENSE) file for the full license text.

---

## Disclaimer

Audio tracks and cover artwork are provided by [NoCopyrightSounds](https://ncs.io). All rights to the respective music tracks belong to their respective creators and NCS.
