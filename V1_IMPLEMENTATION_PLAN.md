# Realme Buds Controller — V1 Implementation Plan

## Goal

Complete the first release on top of the existing native macOS application.
The plan preserves the current application shell and UI while adding the
verified OPOv1 protocol session needed to make supported controls and
telemetry real.

All commands and payloads used during implementation must come from
[ProtocolResearch.md](./ProtocolResearch.md) or from new, explicitly
hardware-verified Air 7 evidence. No command identifier, feature ID, payload,
or parser rule may be guessed.

## Non-Negotiable Constraints

- Preserve the existing SwiftUI/AppKit application structure.
- Preserve SDP discovery and the BESOTA/OTA channel-13 safety filter.
- Never connect to or write to OTA/BESOTA services.
- Never perform firmware writes or updates.
- Never automatically disconnect the Mac’s system-level audio connection.
- Keep Bluetooth transport/protocol logic separate from the UI.
- Treat the outer OPO frame length as authoritative, including Spatial Audio
  replies with inconsistent inner lengths.
- Pace writes according to the documented 150–350 ms requirement.
- Surface command failures, refusal statuses, permission errors, and malformed
  frames explicitly.
- Validate every milestone on the smallest appropriate automated test set and
  then on real Buds Air 7 hardware.

## V1 Workstreams

### 1. Protocol foundation

Add focused protocol components without replacing
`RealmeBluetoothService`:

- OPOv1 frame value types.
- LEB128 length encoder/decoder.
- Frame encoder for the documented header and payload layout.
- Streaming decoder with:
  - preamble resynchronization,
  - partial-frame buffering,
  - multiple-frame handling,
  - outer-length boundary enforcement,
  - malformed-frame diagnostics.
- Sequence-number allocator and request/reply correlation.
- A paced serial command queue with one in-flight request policy where
  required by the device.
- Explicit acknowledgement/status handling for `0x8000`-style replies.

Unit tests must cover fragmented input, coalesced frames, malformed lengths,
sequence matching, empty payloads, and the Spatial Audio length exception.

### 2. RFCOMM session bootstrap

Extend the existing channel-open success path with the documented session
sequence:

1. Open the already-discovered safe control channel.
2. Send handshake `0x0100`.
3. Confirm the documented reply/status.
4. Send event subscription `0x0205`.
5. Mark the protocol session ready only after the required bootstrap succeeds.
6. On close or failure, clear session state and report the reason.

The session must continue using the existing SDP result where available and
the documented channel-15 fallback only when discovery cannot resolve the
service.

### 3. Read-only device identity and telemetry

Implement documented reads and state updates first:

- Product ID `0x0103`/`0x8103`.
- Firmware version `0x0105`/`0x8105`.
- Battery `0x0106`/`0x8106` and event category `0x01`.
- Wear/placement `0x0109`/`0x8109`.
- Remembered devices `0x0112`/`0x8112`.

Battery handling must:

- map slots 1, 2, and 3 to left, right, and case;
- split percentage and charging bit;
- distinguish documented case telemetry unavailable from zero percent;
- tolerate missing slots and malformed entries;
- update the published state on the main actor.

Firmware strings must be displayed as device information only. No firmware
write path is permitted.

### 4. Noise and audio controls

Implement only documented Air 7 operations:

- Noise query `0x010C` and set `0x0404`.
- Realme mapping: `0x01` normal/off, `0x02` transparency,
  `0x04` mild ANC, `0x10` moderate ANC, `0x08` max/deep ANC,
  and `0x20` smart/adaptive ANC.
- Game Mode feature ID `0x06` through the documented feature-switch query/set
  operations and push type `0x05`.
- LHDC preference feature ID `0x18`, with UI wording that macOS audio remains
  limited by its native codec support.
- EQ query `0x010F` and set `0x0406` for documented presets.
- Spatial Audio feature ID `0x1B` and the documented type operation
  `0x041E`; decode using the outer frame length.

Every write must update UI state only after the command result is known, or
roll back and report the failure. Status `0x0E` must be shown as a meaningful
in-ear/refusal condition rather than a generic success.

Wind-noise reduction and Dynamic Bass must remain unavailable unless a
model-specific protocol command is documented and independently verified.
Do not map them to EQ or another feature switch by assumption.

### 5. Dual-device and remembered-device management

Implement:

- Feature-switch query/set for Dual Connection, feature ID `0x11`.
- `0x0112` remembered-device parsing and refresh.
- `0x040B` connect/disconnect operations.
- Status handling through `0x840B`.
- Refresh after relevant push events and after completed operations.
- “This Mac” identification from the documented flags.
- Two-active-link enforcement.

For replacement:

1. Require the target to be a remembered device.
2. Require the selected replacement slot to be the non-Mac secondary link.
3. Disconnect the secondary host.
4. Wait for confirmation and refresh the list.
5. Connect the replacement host.
6. Refresh and present the final state.

Do not implement an independent “switch audio source” command because the
research explicitly says OPOv1 does not expose one.

### 6. Add New Device workflow

Keep the existing hardware/OS pairing guidance and make its boundaries clear:

- Explain case pairing mode steps.
- Open macOS Bluetooth Settings.
- Never claim that RFCOMM can create a new pairing.
- Detect or allow the user to request a refresh after pairing.
- Re-query `0x0112` to show the newly remembered host.

Any optional `IOBluetoothDeviceInquiry` integration must be limited to
discovering the Mac’s own Bluetooth environment and must not replace the
hardware pairing procedure.

### 7. Automatic connection and reconnection

Build a session state machine on the existing notifications:

- Bluetooth unavailable/unauthorized.
- Paired device not found.
- ACL dormant and being opened.
- SDP querying.
- Safe RFCOMM connecting.
- Protocol bootstrapping.
- Ready/telemetry-active.
- Closed/out of range.
- Retrying with bounded backoff.
- Permanently failed until user action or a new connection event.

Automatic reconnection must:

- honor the existing preference;
- never tear down the Mac’s audio link;
- repeat handshake and event subscription;
- re-query identity, battery, features, and remembered devices;
- avoid duplicate simultaneous connect attempts.

### 8. Platform features

Implement the non-protocol V1 features:

- Launch at login with native `SMAppService` registration/status/error
  handling.
- Light/Dark/System appearance persistence and reliable relaunch behavior.
- Notification authorization and delivery for:
  - low battery,
  - device connection changes,
  - charging completed.
- Notification deduplication and preference checks.

Notifications should only be generated from decoded state changes, not seeded
initial values.

### 9. Diagnostics and supportability

Expand the existing diagnostics surface to include:

- protocol session state;
- command opcode, sequence, and result;
- decoded event category;
- malformed-frame and rejected-command errors;
- raw frame hex when enabled;
- last successful telemetry refresh;
- reconnect attempt count and reason;
- safety-filter events.

Retain the current copy, clear, and filter behavior. Diagnostics must never
log secrets or expose unrelated Bluetooth device data beyond what is needed
for the controller.

## Recommended Milestone Order

### Milestone 1 — Protocol tests and transport foundation

Deliver frame types, encoder, streaming decoder, sequence tracking, paced
queue, and unit tests. No UI behavior should be changed yet.

**Exit criteria:** all parser/encoder tests pass; malformed and fragmented
frames are handled; no OTA channel path exists.

### Milestone 2 — Session bootstrap and identity

Wire handshake, event subscription, product ID, firmware reads, and protocol
session state into the existing RFCOMM lifecycle.

**Exit criteria:** a hardware session reaches “ready,” or diagnostics clearly
report the exact failed stage.

### Milestone 3 — Battery, charging, wear, and remembered devices

Implement read/event parsers and connect them to AppState and the existing UI.

**Exit criteria:** left/right/case values, charging flags, case-unavailable
state, wear state, firmware, and remembered devices match controlled hardware
observations.

### Milestone 4 — Noise and documented audio controls

Implement ANC, Transparency, Normal, ANC strengths, Game Mode, LHDC,
documented EQ presets, and Spatial Audio.

**Exit criteria:** each documented command is sent with the exact researched
payload, acknowledgements/refusals are handled, and hardware behavior matches
the selected UI state.

### Milestone 5 — Dual-device operations and replacement

Implement Dual Connection, connect/disconnect, remembered-list refresh, and
guarded secondary-device replacement.

**Exit criteria:** two-link limit is enforced, the Mac link is protected, and
replacement recovers correctly from rejected or disconnected operations.

### Milestone 6 — Reconnection and Add New Device completion

Complete bounded reconnection, post-pair refresh, and user-facing pairing
guidance.

**Exit criteria:** case removal, out-of-range, return-to-range, and newly
paired-host scenarios produce correct state without duplicate sessions.

### Milestone 7 — Platform integrations and diagnostics

Implement Launch at Login, notifications, final appearance verification, and
decoded diagnostics.

**Exit criteria:** platform settings persist correctly; notifications are
authorized, deduplicated, and preference-aware; diagnostics explain failures.

### Milestone 8 — V1 acceptance and release packaging

Run unit tests, Swift build, `build.sh`, and a hardware acceptance matrix for
every supported protocol feature. Verify the app bundle, entitlements,
permissions, safety filter, and clean startup/shutdown behavior.

**Exit criteria:** every feature marked supported in
[V1_FEATURE_MATRIX.md](./V1_FEATURE_MATRIX.md) is either demonstrated on
hardware or has an explicit, recorded hardware blocker; no undocumented
command is used; release packaging succeeds.

## V1 Hardware Acceptance Matrix

The final hardware pass must cover:

- left/right/case battery and charging transitions;
- closed-lid case telemetry behavior;
- firmware/product reads;
- Normal, Transparency, ANC, and all four documented ANC strengths;
- Game Mode, LHDC preference, EQ presets, and Spatial Audio;
- wear/placement events and documented Find Earbuds/ring;
- remembered-device parsing;
- dual connection, secondary disconnect/connect, and replacement;
- out-of-range, case-close, reconnect, and post-pair refresh;
- refusal status when a mode change is attempted outside the ear;
- OTA/BESOTA safety filtering.

The test record must include device firmware version, command/result
diagnostics, and any feature-specific limitation. A successful compile alone
does not count as hardware verification.
