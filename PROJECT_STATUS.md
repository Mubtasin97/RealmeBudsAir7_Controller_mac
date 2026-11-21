# Realme Buds Controller — Project Status

Reviewed: 2026-11-21

## Executive Summary

The repository contains an existing native macOS Swift Package executable with:

- A SwiftUI menu-bar application and settings window.
- A documented Realme Buds Air 7 Bluetooth Classic/RFCOMM protocol.
- Implemented paired-device detection, Bluetooth availability monitoring, SDP service discovery, RFCOMM channel open/close handling, connection notifications, and diagnostic logging.
- A completed-looking Liquid Glass UI for overview, devices, settings, and diagnostics.

The project currently builds and packages successfully. The RFCOMM transport scaffolding is present, but the OPO protocol command/response implementation is not yet present. Incoming RFCOMM bytes are logged as raw data only, so the UI is not currently driven by real earbud telemetry and UI controls do not send commands to the earbuds.

## Build and Packaging

### Build result

`./build.sh` completed successfully in release mode.

The script:

1. Runs `swift build -c release`.
2. Packages the executable as `Realme Buds Controller.app`.
3. Copies `Resources/Info.plist`.
4. Ad-hoc signs the bundle with `Resources/RealmeBudsController.entitlements`.

The generated application bundle exists locally and is ignored by Git. The SwiftPM build directory is also ignored.

### Project configuration

- Package product: executable `RealmeBudsController`.
- Swift language mode: Swift 6.
- Minimum package platform: macOS 26.
- Application bundle minimum system version: macOS 26.0.
- Menu-bar accessory configuration: `LSUIElement`.
- Bluetooth entitlement: enabled.

## Implemented Areas

### Application and menu-bar shell

- `Sources/RealmeBudsController/main.swift` starts `NSApplication`.
- `AppDelegate` initializes appearance, the status-bar controller, Bluetooth service, and optional launch flags.
- `StatusBarController` provides the menu-bar icon and transient popover.
- `WindowManager` opens and reuses the detailed settings window.

### Bluetooth transport and discovery

`RealmeBluetoothService.swift` currently implements:

- CoreBluetooth radio state and authorization monitoring.
- Search through macOS paired Bluetooth devices for Realme Buds Air 7 variants.
- Device connect/disconnect notifications.
- Base Bluetooth connection opening when the ACL link is dormant.
- SDP service discovery.
- Matching the documented `oppointeraction` service name and UUID.
- RFCOMM channel selection, including fallback to channel 15.
- Asynchronous RFCOMM channel open and close.
- RFCOMM open/close callbacks.
- Raw incoming RFCOMM data logging.
- Human-readable handling for several I/O return codes.

The service also blocks the known BESOTA/OTA channel 13 and skips OTA-like SDP service names. This safety behavior should be preserved.

### UI and local state

The following interface areas exist:

- Overview: connection status, battery cards, noise-control controls, Game Mode, and LHDC preference.
- Devices: dual-connection slots, remembered-device list, connect/disconnect/swap controls, and pairing guidance.
- Settings: appearance, EQ presets and six-band sliders, connection behavior, notifications, and About.
- Diagnostics: Bluetooth availability, device detection, SDP status, RFCOMM status, and filtered event logs.
- Light, dark, and system appearance preferences persisted through `UserDefaults`.
- Shared Liquid Glass-style components, colors, spacing, animations, and accessibility handling.

## Incomplete or Missing Functionality

### OPO protocol implementation

`ProtocolResearch.md` documents the packet framing, opcodes, payloads, and feature mappings, but those mechanics are not implemented in the application source.

Missing transport/protocol pieces include:

- OPO frame encoder.
- Streaming frame decoder and reassembly buffer.
- LEB128 length parsing.
- Command sequence management.
- Command pacing/throttling.
- Handshake command.
- Event-subscription command.
- Reply matching and status handling.
- Battery response parsing.
- Noise-control response parsing.
- Game Mode, LHDC, spatial-audio, EQ, and multi-connect command handlers.
- Remembered-device response parsing.
- Real telemetry updates into `AppState`.

### UI actions are currently local-only

Several controls update `AppState` and append diagnostic messages that describe protocol commands, but do not transmit those commands through `IOBluetoothRFCOMMChannel`. This applies to noise control, Game Mode, LHDC, device connection management, swapping, and EQ controls.

### Real telemetry is not connected to the UI

Battery values, device lists, firmware information, RSSI, codec information, and packet counters are primarily initialized or updated as local application state. The RFCOMM callback increments the receive counter and logs a hex preview, but does not decode or apply telemetry.

### Reconnection and notification behavior

Connection and disconnect callbacks exist, but automatic reconnection is not yet a complete protocol/session workflow. The settings toggle exists; its behavior is not fully wired to a retry policy, handshake, subscription, or telemetry refresh.

### Launch at Login and notifications

The settings UI exposes Launch at Login and notification preferences, but no complete `SMAppService` integration or system notification delivery implementation is present in the reviewed source.

## RFCOMM Status

### What is implemented

The code can:

- Find the paired earbuds.
- Discover the control service through SDP.
- Fall back to RFCOMM channel 15.
- Open an asynchronous RFCOMM channel.
- Report the channel ID and MTU.
- Receive raw RFCOMM callback data.
- Close the channel cleanly.

The standalone `test_rfcomm.swift` utility also attempts to open channel 15 and exits after the open callback.

### What is verified

- The application release build and app packaging succeeded locally.
- The source contains a complete connection lifecycle and diagnostic path.

### What is not verified

There is no captured hardware test result, runtime log, or automated test proving that RFCOMM successfully opens against a physical Buds Air 7 in the current environment. Therefore, RFCOMM should be considered implemented in source but hardware operation remains unverified in this review.

The current RFCOMM callback receives bytes but intentionally does not interpret them.

## Feature Status

| Feature | Current status |
|---|---|
| Native macOS menu-bar app | Implemented |
| SwiftUI overview/settings/diagnostics UI | Implemented |
| Appearance preferences | Implemented |
| Paired Realme Buds detection | Implemented in source |
| Bluetooth availability/permission state | Implemented in source |
| SDP service discovery | Implemented in source |
| RFCOMM open/close lifecycle | Implemented in source; hardware unverified |
| Raw RFCOMM diagnostics | Implemented |
| OPO packet framing/decoding | Missing |
| Handshake/event subscription | Missing |
| Live battery telemetry | Missing |
| Live noise-control control | UI only |
| Game Mode/LHDC/spatial audio commands | UI/state only |
| EQ command transmission | UI/state only |
| Remembered-device protocol parsing | Missing |
| Dual-device protocol control | UI/state only |
| Add-device guidance | UI implemented; pairing remains OS/hardware-driven |
| Automatic reconnect workflow | Partial |
| Launch at Login | UI setting only |
| System notifications | Preference UI only |
| Automated tests | No test target or test files found |

## Known Issues and Risks

1. The application currently presents seeded/default device and telemetry values, which can look like live hardware data before protocol parsing is connected.
2. Protocol command log messages can imply that commands were dispatched even though no RFCOMM write is currently performed.
3. The RFCOMM data callback reads and logs a bounded raw byte preview only; it has no persistent stream buffer, so fragmented/coalesced frames are not decoded.
4. The documented protocol warns that channel 13 is firmware/OTA-related. The existing safety filter must not be removed or weakened.
5. No automated test coverage exists for packet framing, parsing, Bluetooth state transitions, or UI state changes.
6. Hardware-dependent RFCOMM behavior cannot be confirmed from the successful compile/package result alone.

## Files and Areas to Preserve

Unless a change is directly required by a feature, do not rewrite:

- `AGENTS.md` — repository architecture, safety, and development rules.
- `ProtocolResearch.md` — protocol reference and safety findings.
- `build.sh` — existing release build and app packaging path.
- `Resources/Info.plist` and `Resources/RealmeBudsController.entitlements` — bundle and Bluetooth configuration.
- The existing SDP/RFCOMM lifecycle and BESOTA safety checks in `RealmeBluetoothService.swift`.
- The existing SwiftUI design system and feature views.

Future protocol work should add focused encoder/decoder/session components and connect them to the existing Bluetooth service and `AppState`, rather than replacing the current application shell or UI.

## Git History and Working Tree

Recent commits:

- `4618b05` — initial native macOS application structure.
- `e2472ce` — Liquid Glass visual design across the main UI.
- `3f7f22a` — WIP Bluetooth connection implementation.

The working tree was clean before this status document was created. Build products are ignored by Git.
