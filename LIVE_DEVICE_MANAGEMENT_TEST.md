# Live Connected Devices Management Test

Tested: 2026-11-21

## Implemented

- Replaced the static remembered-device array with an empty live state.
- Added `0x0112` remembered-device query.
- Added `0x8112` response parsing.
- Added dual-connection feature query `0x010D` for feature ID `0x11`.
- Added dual-connection set `0x0403 [0x11, enabled]`.
- Added connect/disconnect `0x040B`.
- Added `0x840B` acknowledgement handling.
- Added refresh after operations and topology push categories.
- Added loading and error states.
- Added `This Mac` detection using protocol flags with local-address fallback.
- Preserved the Mac as slot 1 and blocked all controller-Mac disconnect calls.
- Added explicit replacement confirmation in the existing UI.
- Replacement is secondary-slot-only: disconnect old secondary, then connect
  replacement.
- Added no unsupported active-audio-source claim.

## Device-State Semantics

The implementation distinguishes:

- Paired/remembered from the earbuds' host table.
- Connected link state from the protocol connection state.
- Slot occupancy from states 1 and 2.
- Mac identification from the protocol `This Host` flag.
- Active audio source is not claimed or controlled; the protocol only exposes
  link management, and the earbuds arbitrate audio routing independently.

## Safety

- The UI never mutates a device state before a `0x840B` success.
- The Mac entry cannot be disconnected.
- The user must confirm replacement.
- The app does not send the replacement connect until the old secondary
  disconnect is acknowledged.
- The app refreshes `0x0112` after connect, disconnect, replacement, and
  topology pushes.

## Runtime Verification

- Release build passed.
- App bundle packaging passed.
- No static test devices remain in source.
- The app reopened RFCOMM channel 15 and remained running.
- No new crash report appeared.
- The remembered-device response timer, parser, refresh timer, and
  confirmation flow compile and run.

## Physical Operation Boundary

A real second host device was not available as a controlled operation target
during this implementation pass. Therefore:

- Actual `0x0112` device names/MAC addresses were not reported.
- Actual `0x840B` connect/disconnect acknowledgement was not verified.
- Actual replacement across slot 1/slot 2 was not executed.
- Dual-feature hardware status was not verified beyond the implementation.

These operations must be tested once a second Bluetooth host is paired and
available. No static device value or fake operation acknowledgement is used
to fill the unverified state.
