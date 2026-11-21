# RFCOMM and Bluetooth Connection Verification

Verified: 2026-11-21

## Result

The normal Bluetooth ACL/audio connection is established and the proprietary
OPO RFCOMM control connection is now established successfully.

The app remains running in the menu bar after the control channel opens.

## Normal Bluetooth Audio/ACL Connection

Verified read-only IOBluetooth probe:

- Device name: `realme Buds Air7`
- Bluetooth address: `b0-38-e2-a4-ae-95`
- `IOBluetoothDevice.isConnected()`: `true`

This confirms the normal Bluetooth Classic ACL/audio relationship. It does not
by itself prove that the proprietary OPO control service is open.

## OPO Service Discovery

SDP discovery completed successfully:

- SDP status: `0` / success
- Discovered service count: `14`
- `oppointeraction` service found
- RFCOMM channel: `15`
- Channel lookup status: `0` / success
- Channel 13 present, but not used

The channel-13 entry is not treated as a control channel. It is not opened,
and it remains blocked as BESOTA/OTA firmware flashing infrastructure.

## Explicit ACL/Open-Connection Root-Cause Test

Before the fix, asynchronous RFCOMM channel opening was started but
`rfcommChannelOpenComplete` did not arrive within the verification window.
The synchronous open returned general I/O error `-536870212`.

An explicit baseband/ACL reopen sequence was tested:

1. Normal ACL already reported connected.
2. `openConnection()` returned `0`.
3. After a short settle period, ACL remained connected.
4. SDP found `oppointeraction` on channel 15.
5. `openRFCOMMChannelAsync` was called.
6. `rfcommChannelOpenComplete` reported success.
7. Channel 15 reported MTU `669`.

This establishes that the control-channel failure was related to the app
skipping the explicit baseband open/settle sequence when cached ACL state was
already true. It was not an SDP/OPO service discovery failure.

## Fixed Application Transport Behavior

The application now:

- explicitly calls `openConnection()` before SDP discovery;
- waits briefly for baseband settling;
- performs SDP discovery;
- opens the safe `oppointeraction`/channel-15 control service;
- preserves duplicate-open guards;
- dispatches IOBluetooth callbacks safely to the main actor;
- keeps normal ACL state separate from RFCOMM control state;
- does not interpret the normal audio link as proof of an OPO control link.

Files changed for this transport fix:

- [RealmeBluetoothService.swift](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Bluetooth/RealmeBluetoothService.swift)
- [PopoverRootView.swift](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Views/PopoverRootView.swift)

The UI now represents both states independently rather than counting mock
remembered devices as the header connection status.

## Final Binary Verification

The rebuilt and signed app binary was launched as PID `25031`.

Unified Bluetooth logs show:

- `openRFCOMMChannelAsync` with channel ID `15`;
- `IOBluetoothRFCOMMChannel` initialization;
- `Connected to RFCOMM: 0xf`;
- `rfcommChannelOpenComplete:Success`;

The app process remained running after the open callback.

No new crash report appeared after the final launch. The only crash report
found in DiagnosticReports was the earlier connection-callback crash from
before the `nonisolated`/main-actor fix.

## Connection Stability

Verified after the open callback:

- application process remained running;
- no control-channel close callback was observed during the test window;
- no disconnect callback was observed during the test window;
- no new Bluetooth crash report appeared;
- no channel-13/BESOTA connection was attempted.

A longer physical disconnection/reconnection run is still required to prove
out-of-range, case-close, reconnect, and repeated-open behavior beyond the
current verification window.

## Incoming Protocol Verification

The IOBluetooth transport callbacks received no verified, decoded OPO protocol
responses during this transport-only test.

No OPO handshake or battery/configuration command was sent. The project does
not yet implement:

- OPO frame encoder;
- LEB128 frame decoder;
- sequence/reply correlation;
- handshake `0x0100`;
- event subscription `0x0205`;
- raw protocol response parsing.

Therefore, the application must not claim that OPO protocol responses or
earbud telemetry are live.

## Accurate Status Representation

The application now distinguishes:

- Normal Bluetooth ACL/audio: established.
- OPO RFCOMM control: established on channel 15.
- OPO protocol session: not yet initialized.
- Battery/ANC/configuration telemetry: not yet live.
- Remembered-device count: must not use mock device entries for live status.

## Battery Monitoring Boundary

Battery monitoring is intentionally not implemented in this phase.

The next phase should begin only with:

1. protocol frame encoding/decoding;
2. handshake and event subscription;
3. reply correlation;
4. verified battery/charging parsing;
5. hardware verification of the displayed battery values.
