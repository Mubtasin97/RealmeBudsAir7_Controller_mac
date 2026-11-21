# Live Data Audit

Reviewed: 2026-11-21

## Executive Summary

The application now has a working-looking native UI and transport lifecycle,
but it is not yet a live earbud controller. The Bluetooth layer can detect
paired devices, perform SDP discovery, open/close RFCOMM channel 15, receive
raw bytes, and surface connection state. It does not yet implement OPOv1
framing, command writes, streaming frame decoding, reply matching, or telemetry
parsers.

Consequently:

- RFCOMM transport state is partly live.
- Paired-device detection is partly live.
- Earbud telemetry and configuration values are mostly mock or hardcoded.
- UI controls mostly change local state and print diagnostics.
- There is no automated protocol test suite.
- The standalone `test_rfcomm.swift` only tests channel opening and closing.

## Transport Verification Update

Hardware verification confirmed that the normal Bluetooth ACL/audio link is
connected and that SDP discovers `oppointeraction` on RFCOMM channel 15.

A final launch also logged `rfcommChannelOpenComplete:Success` on channel 15,
and the app remained running. Battery and OPO command/response implementation
are still absent; this update verifies transport only.

## Audit Method

Evidence comes from:

- [AppState.swift](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/State/AppState.swift)
- [RealmeBluetoothService.swift](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Bluetooth/RealmeBluetoothService.swift)
- [ProtocolResearch.md](/Users/mubtasinprotik/Desktop/RealmeBudsController/ProtocolResearch.md)
- All existing Swift views and models.
- Git working state and the tracked test files.

No protocol opcode or payload is inferred here. Existing documented opcodes
are repeated only to identify which implementation work is required.

## Static and Live Value Audit

| Item | Current source | Static/mock/hardcoded? | Bluetooth command exists | Communication tested | Required implementation |
|---|---|---|---|---|---|
| Connection status | `AppState.isConnected` and `linkStatusText` are updated from RFCOMM open/close callbacks in `RealmeBluetoothService`. Earbud detection is also updated from IOBluetooth connect/disconnect callbacks. | Partly live; link text is synthesized locally. | The connection lifecycle is through SDP/RFCOMM, not an OPO status command. | RFCOMM opening and hardware behavior are not yet proven by an automated test or retained hardware result. | Preserve callback state, add protocol-session-ready versus ACL/RFCOMM-only distinction, and verify connect/disconnect on physical hardware. |
| Connected device count | [PopoverRootView.swift](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Views/PopoverRootView.swift) counts entries in `AppState.rememberedDevices` whose state is `.connected`. | Mock until the remembered-device list is replaced with parsed protocol data. | `0x0112`/`0x8112` documents the remembered-device list. Push events can require a refresh. | No parser or live protocol query exists. | Parse `0x0112`, map the `This Mac` flag and connection states, and update after topology pushes. |
| Left earbud battery | `AppState.leftBattery` is seeded with `85%`, no charging. | Mock/hardcoded. | `0x0106`/`0x8106`; slot `0x01`. Battery push category `0x01` is documented. | No live battery parser or hardware test exists. | Implement streaming frame handling and battery payload parsing, then update this property. |
| Right earbud battery | `AppState.rightBattery` is seeded with `90%`, no charging. | Mock/hardcoded. | `0x0106`/`0x8106`; slot `0x02`. | No live battery parser or hardware test exists. | Implement slot `0x02` parsing and live/push refresh. |
| Charging case battery | `AppState.caseBattery` is seeded with `65%` and charging. | Mock/hardcoded. | `0x0106`/`0x8106`; slot `0x03`. | No live parser or hardware test exists. | Decode slot `0x03`; distinguish `0x00` with no charging from real telemetry unavailable when the case lid is closed. |
| Charging indicators | `BatteryStatus.isCharging` comes only from the seeded battery properties and cannot come from the earbuds currently. | Mock/hardcoded. | Charging bit is the high bit of `RawLevel` in the battery payload. | No live battery test exists. | Split the battery byte into percentage and charging bit for left, right, and case. |
| ANC mode | `AppState.noiseControlMode` starts at `.anc(.smart)` and UI actions only change it locally. | Hardcoded initial value and local-only updates. | Query `0x010C`; set `0x0404`; push category `0x03`. | Protocol command not sent or parsed; no hardware test. | Implement query/set/reply/push handling and Realme mode mapping. |
| ANC strength | `ANCStrength` supplies smart/mild/moderate/max values, but `AppState` only changes it locally. | Prototype enum and local state. | Strength values are documented through `0x0404`: mild `0x04`, moderate `0x10`, max `0x08`, smart `0x20`. | No write or hardware verification exists. | Add paced command send, acknowledge handling, rollback, and live push/query synchronization. |
| Normal mode | `NoiseControlMode.off` exists and local action changes it. | Hardcoded local state. | Off/Normal is documented as `0x01` in the `0x0404` payload. | No write or hardware test exists. | Map Off/Normal to `0x01` and handle reply/push state. |
| Transparency | `NoiseControlMode.transparency` exists and local action changes it. | Hardcoded local state. | Transparency is documented as `0x02` in the `0x0404` payload. | No write or hardware test exists. | Map Transparency to `0x02`, wait for acknowledgement, and synchronize live mode. |
| Game Mode | `AppState.isGameModeEnabled` starts as `false` and UI toggles only mutate it locally. | Mock/hardcoded. | Feature ID `0x06`; query `0x010D`, set `0x0403`, push type `0x05`. | No protocol communication or hardware test exists. | Implement query/set/push handling and use acknowledgement to confirm state. |
| LHDC preference | `AppState.isHiResLhdcEnabled` starts as `true` and UI toggles only mutate it locally. | Mock/hardcoded. | Feature ID `0x18`; query `0x010D`, set `0x0403`. | No protocol communication or hardware test exists. | Implement query/set/push handling and display macOS AAC/SBC limitation accurately. |
| EQ settings/preset | `AppState.activeEqPreset` starts at `.original`; bands are generated locally from preset constants. Slider edits change local state only. | Hardcoded preset definitions and local state. | Query `0x010F`, set `0x0406`; documented preset IDs 0–3. | No query/write or hardware test exists. | Implement documented preset query/set. Do not claim custom-curve transmission until a documented custom payload is verified. |
| Spatial Audio | `AppState.isSpatialAudioEnabled` starts as `true`, but no dedicated live view writes or reads it. | Hardcoded. | Feature ID `0x1B`, type command `0x041E`; response length handling requires special care. | No protocol communication or hardware test exists. | Implement switch/type query/set and outer-frame-length decoding. |
| Remembered devices | `AppState.rememberedDevices` contains four fixed examples with fake names and MAC addresses. | Mock/hardcoded. | `0x0112`/`0x8112` and push events `0xF2`, `0x06`, `0x0D`, `0x12`, `0x13`, `0x16` are documented. | No remembered-device parser or live query exists. | Parse device count, MAC, state, flags, name length, and UTF-8 names; refresh after topology events. |
| Dual-device connection status | `isDualConnectionEnabled` starts as `true`; slot cards derive from mock `rememberedDevices`. | Mock/hardcoded. | Master feature ID `0x11` via `0x010D`/`0x0403`; active links come from `0x0112`. | No protocol communication or hardware test exists. | Query feature state and remembered-device states; update slot UI only after acknowledgement/list refresh. |
| Connect/disconnect remembered devices | UI methods mutate `connectionState` and `slotNumber` locally, then log claimed TX commands. | Mock/local-only. | `0x040B`/`0x840B` connects or disconnects an encoded remembered MAC. | No RFCOMM write or acknowledgement path exists. | Implement paced writes, status handling, refresh, two-slot limit, and confirmation before UI state mutation. |
| Replace connected device | `swapDevice` changes old/new local slot values immediately and logs a swap. | Mock/local-only. | The protocol has no direct source-switch command; a sequence of documented `0x040B` disconnect/connect operations is described. | No real operation or hardware test exists. | Implement disconnect-secondary-confirm-then-connect replacement sequence and never disconnect the Mac by automation. |
| Firmware information | `firmwareVersion`, `deviceModelCode`, `hardwareRevision`, and `bluetoothSoC` are seeded constants. | Hardcoded/mock. | Product ID `0x0103` and firmware `0x0105` are documented. | No query or parser exists. | Query product/firmware replies and replace seeded values, preserving firmware strings as read-only. |
| RSSI | `AppState.rssi` is hardcoded to `-52 dBm`. | Hardcoded. | RSSI may be available through macOS IOBluetooth APIs, but no protocol RSSI command is established in [ProtocolResearch.md](./ProtocolResearch.md). | No live RSSI polling exists. | Use supported IOBluetooth RSSI/device APIs or remove the claim until verified. |
| Active codec | `activeCodec` is hardcoded to `AAC-LC (48 kHz / 24-bit)`. | Hardcoded/assumption. | No Air 7 codec-query command is documented. | No communication or hardware test exists. | Do not present as live until macOS/device APIs prove it. |
| Packet counters | `txPacketsCount` and `packetDropCount` are local counters; only `rxPacketsCount` increments from the raw receive callback. | Partially runtime, but no protocol accounting. | RFCOMM transport callbacks provide byte receipt; no frame decoder/ack parser exists. | RX callback is live but TX not implemented. | Count encoded frames, decoded replies, malformed frames, and dropped frames separately. |
| Wind-noise/dynamic bass | `isWindNoiseReductionEnabled` and `isDynamicBassEnabled` are seeded as `true` and never act on Bluetooth. | Hardcoded/mock. | No Air 7 command or feature ID is documented. | Not implemented or tested. | Hide or mark unsupported until model-specific hardware evidence and documented payloads exist. |
| Add New Device | The view opens macOS Bluetooth Settings and provides pairing steps. | UI workflow, not live app pairing. | Pairing is hardware/OS driven. `0x0112` refresh can reflect the new host. | Pairing guidance exists; no post-pair remembered-device refresh exists. | Add explicit refresh and optional IOBluetooth discovery support. |
| Automatic connection | Launch calls paired-device detection and SDP discovery if enabled. | Partly live, preference hardcoded default `true`. | SDP/RFCOMM transport is documented, then handshake `0x0100` and subscription `0x0205`. | The session bootstrap is not implemented. | Complete safe session bootstrap and mark protocol-ready only after verified replies. |
| Automatic reconnection | Disconnect callbacks close RFCOMM, but there is no bounded retry or session restore policy. | Partial. | Connect/disconnect notifications and RFCOMM close callbacks are available. | Crash isolation was fixed, but reconnection was not tested. | Add retry/backoff, stale-job guards, and post-reconnect handshake/subscription refresh. |
| Launch at login | `launchAtLogin` starts `false` and UI binds to it only. | Local preference/mock. | No earbud protocol command exists. | No `SMAppService` implementation or test exists. | Implement native `SMAppService` registration, status, and error handling. |
| Notifications | Notification preference booleans are local and no delivery code exists. | Mock/preferences only. | No protocol command; triggers depend on live battery/device events. | No notification runtime test exists. | Implement authorization and state-change notifications after live telemetry exists. |
| Appearance | `AppearanceManager` persists Light/Dark/System in `UserDefaults` and applies the AppKit/SwiftUI appearance. | Live local setting. | Not Bluetooth-related. | Not documented by a test suite, but implementation is runnable. | Add focused UI verification for relaunch, accessibility, and popover. |
| Diagnostics | Availability, device detection, SDP, RFCOMM, and log filtering are connected to runtime callbacks/log state. Raw received bytes are logged. | Partially live. | RFCOMM bytes can arrive; no OPO framing or opcode decode exists. | Raw receive callback exists; protocol test coverage does not. | Add frame decoder, opcode/status/result logging, TX result correlation, and malformed-frame handling. |

## Bluetooth and Protocol Implementation Status

### Existing Bluetooth implementation

[RealmeBluetoothService.swift](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Bluetooth/RealmeBluetoothService.swift)
currently contains:

- CoreBluetooth availability and permission monitoring.
- Paired-device detection.
- Device connect/disconnect notification registration.
- main-actor dispatch for IOBluetooth notification callbacks.
- SDP query and service matching.
- channel-13 BESOTA/OTA safety filtering.
- channel-15 fallback.
- asynchronous RFCOMM open/close.
- duplicate-open and duplicate-discovery guards.
- raw receive-byte preview logging.

### Missing OPO implementation

No source file currently implements:

- OPO frame encoding.
- LEB128 length encoding/decoding.
- rolling sequence numbers.
- request/reply correlation.
- command pacing.
- streaming frame reassembly.
- handshake.
- event subscription.
- battery/charging parsing.
- wear-state parsing.
- noise-mode parsing/writing.
- Game Mode, LHDC, Spatial Audio, EQ, or feature-switch writes.
- remembered-device parsing.
- connect/disconnect remembered-device writes.
- acknowledgement/status handling.

The receive callback at
[RealmeBluetoothService.swift](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Bluetooth/RealmeBluetoothService.swift)
only logs the first 32 bytes and increments `rxPacketsCount`.

### Existing tests

Only `test_rfcomm.swift` is present. It:

- finds a paired Realme-named device;
- opens RFCOMM channel 15;
- prints open/close callback status;
- closes the channel;
- logs raw data callbacks.

It does not:

- assert state;
- encode or send OPO frames;
- test handshake or subscriptions;
- parse telemetry;
- test controls;
- test fragmented/coalesced frames;
- test sequence or acknowledgement handling;
- test reconnection;
- test UI state.

No XCTest or SwiftPM test target exists.

## Priority Implementation Plan

### Priority 1: Protocol Foundation

Create isolated OPOv1 and RFCOMM protocol components rather than adding
opaque logic directly to views or `AppState`.

Required work:

1. Define frame, opcode, sequence, payload, and decoded-response types.
2. Implement LEB128 encoder/decoder.
3. Implement frame encoder.
4. Implement streaming receive buffer.
5. Reassemble fragmented/coalesced frames.
6. Use outer frame length as authoritative.
7. Add paced command queue and in-flight correlation.
8. Add unit tests for fragmentation, coalescing, malformed frames,
   empty payloads, sequence matching, and Spatial Audio length cases.

Exit criteria: protocol unit tests pass and no OTA/BESOTA path is callable.

### Priority 2: RFCOMM Session Bootstrap

On a confirmed safe channel:

1. Send handshake `0x0100`.
2. Confirm/handle handshake reply.
3. Send event subscription `0x0205`.
4. Mark protocol-ready only after bootstrap succeeds.
5. Clear session state on close or failure.

Exit criteria: one physical session reaches ready and duplicate connection
requests remain suppressed.

### Priority 3: Read-Only Telemetry

Implement and verify reads before controls:

1. Product ID `0x0103`.
2. Firmware `0x0105`.
3. Battery/charging `0x0106` and push category `0x01`.
4. Wear state `0x0109`.
5. Feature states and remembered devices.

Update `AppState` on the main actor only.

Exit criteria: left, right, and case telemetry match the physical buds and
case unavailable behavior is represented correctly.

### Priority 4: Noise and Configuration Controls

Implement each control only after live query state is available:

1. ANC, Transparency, Normal, and strength.
2. Game Mode.
3. LHDC preference.
4. EQ presets.
5. Spatial Audio.

Every write must:

- use the documented payload;
- wait for acknowledgement;
- handle refusal status `0x0E`;
- update UI only on confirmed state or restore prior state on failure.

Exit criteria: every control and push/query path is demonstrated on
hardware.

### Priority 5: Remembered Devices and Dual Connection

1. Parse `0x0112`/`0x8112`.
2. Replace mock array entries.
3. Refresh after topology pushes.
4. Implement Dual Connection feature query/set.
5. Implement documented `0x040B` connect/disconnect operations.
6. Implement secondary-device replacement.
7. Preserve the Mac's ACL link.

Exit criteria: UI reflects actual dual-connection state and only protocol-
supported source behavior is exposed.

### Priority 6: Reconnection and Lifecycle

Add a bounded reconnection state machine:

- ACL disconnected.
- SDP pending.
- RFCOMM connecting.
- protocol bootstrapping.
- protocol ready.
- retrying.
- failed.

Repeat handshake/subscription after reconnect and refresh telemetry. Remove
or suspend stale retry jobs after channel close/success.

Exit criteria: connect, disconnect, out-of-range, and reconnect cycles leave
the app running and produce exactly one active control channel.

### Priority 7: Platform State and Notifications

After live telemetry exists:

1. Implement `SMAppService` Launch at Login.
2. Implement notification authorization.
3. Generate low-battery, charging-complete, and device-change notifications
   only from state transitions.
4. Replace assumed RSSI/codec values unless supported APIs provide them.

### Priority 8: Hardware Acceptance and Regression

Create a real hardware test run covering:

- app launch/auto-connect;
- AFC/SDP/RFCOMM duplicate prevention;
- handshake/subscription;
- all battery and charging states;
- all ANC modes and strengths;
- Game Mode, LHDC, EQ, and Spatial Audio;
- dual-device list/connect/disconnect/replacement;
- disconnect/out-of-range/reconnect;
- app process stability;
- final build and signed app bundle.

No status should be considered complete until it is backed by a protocol
reply or a verified hardware test.
