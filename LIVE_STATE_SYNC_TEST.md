# Live Application State Synchronization Test

Tested: 2026-11-21

## Implemented

The existing Bluetooth service is now the shared synchronization coordinator
for:

- IOBluetooth paired-device, connect, and disconnect events.
- CoreBluetooth radio availability.
- SDP discovery.
- RFCOMM open, close, failure, and incoming data callbacks.
- Battery query and battery push updates.
- Noise-mode query/push updates.
- Game Mode query/push updates.
- Feature-state and dual-device query updates.
- EQ query/readback updates.
- Remembered-device query/push updates.
- Topology push refreshes.
- Bounded RFCOMM reconnection.
- Mac sleep/wake state refresh.

## Shared State Behavior

All UI surfaces observe `AppState.shared`.

Targeted synchronization is used:

- battery refresh only updates battery state;
- noise/feature pushes update only audio state;
- device topology pushes refresh only the remembered-device list;
- RFCOMM close clears battery, audio-readiness, and device state as
  temporarily unavailable;
- repeated identical pushes do not reassign or log unchanged values;
- UI never mutates live hardware state optimistically.

## Reconnection and Stale-State Handling

The service now:

- starts a bounded retry sequence after RFCOMM close or open failure;
- stops retries when channel 15 is connected;
- clears stale telemetry and remembered-device state on disconnection;
- re-queries battery, audio settings, and remembered devices after recovery;
- registers `NSWorkspace` sleep/wake notifications;
- refreshes active sessions after wake.

## Hardware Runtime Verification

- Release build passed.
- App bundle packaging passed.
- Final app process remained running.
- RFCOMM channel 15 reopened successfully once.
- No duplicate channel-open action was observed.
- No new crash report appeared.
- Repeated state reads now compare before assignment.

## Phone-Originated Change Test Boundary

The protocol's push behavior was inspected and parsed for:

- battery category `0x01`;
- noise category `0x03`;
- Game Mode type `0x05`;
- remembered-device change `0xF2`;
- topology categories `0x06`, `0x0D`, `0x12`, `0x13`, `0x16`.

No phone-side setting change was performed during this implementation pass,
so cross-device Realme Link confirmation is pending:

- Game Mode changed through Realme Link;
- ANC/Transparency changed through Realme Link;
- LHDC/Spatial changes through Realme Link;
- EQ change through Realme Link;
- remembered host connection change through another device.
