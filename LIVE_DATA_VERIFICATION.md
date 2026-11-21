# Live Data Verification

Verified: 2026-11-21

## Summary

This audit removed production display assumptions that could present
unverified earbud state as live. Mock values remain absent from production
initial state.

## Verified Real Sources

| Displayed value | Source | Verification state |
|---|---|---|
| Normal Bluetooth/ACL state | `IOBluetoothDevice.isConnected()` and connect/disconnect notifications | Verified on hardware |
| OPO RFCOMM control state | `rfcommChannelOpenComplete` / `rfcommChannelClosed` | Verified on channel 15 |
| Left/right/case battery | OPO `0x0106`/`0x8106` and `0x0204` category `0x01` | Left 100%, right 100%, case 40%; no charging |
| Noise/ANC mode | OPO `0x010C`/`0x810C` and push category `0x03` | Normal/Off readback verified |
| Game Mode | OPO `0x010D`/`0x810D` and `0x0403`/push `0x05` | Initial off and on/off writes verified |
| LHDC preference | OPO `0x010D`/`0x810D`, feature ID `0x18` | Initial off readback verified; write not complete |
| Spatial Audio | OPO `0x010D`/`0x810D`, feature ID `0x1B` | Initial off readback verified; write not complete |
| EQ preset | OPO `0x010F`/`0x810F` | Clear Bass readback verified; writes not complete |
| Remembered devices | OPO `0x0112`/`0x8112` | Parser and UI implemented; actual response not reported |
| Dual-device status | OPO `0x010D`/`0x810D`, feature ID `0x11` | Not hardware-verified |
| Replacement/operation state | OPO `0x040B`/`0x840B` | Not hardware-verified with a second host |

## Mock Values Removed

The production source no longer initializes:

- battery values `85`, `90`, or `65`;
- charging status for those mock batteries;
- firmware `1.1.0.66`;
- hardware revision `0x064812`;
- model code `RMA2401`;
- Bluetooth SoC `Bestechnic BES2700YP`;
- RSSI `-52 dBm`;
- codec `AAC-LC (48 kHz / 24-bit)`;
- fake remembered-device names or MAC addresses;
- an assumed enabled dual-device state;
- an assumed enabled in-ear state;
- a fake active EQ selection before readback;
- fake LHDC/Spatial enabled assumptions;
- fake ANC Smart state before readback.

The previous static device names and addresses do not remain in production
source.

## Current Unknown/Loading/Unavailable States

### Connection

- ACL/audio status comes from IOBluetooth.
- RFCOMM control status comes only from real open/close callbacks.
- Disconnected values clear stale telemetry.

### Battery

- Production battery values begin unavailable.
- The UI shows `Updating…` while loading.
- It shows `Unavailable` or `—` when no valid slot reading exists.
- Raw battery level `0` with no charging is not displayed as 0% for case
  telemetry; the parser leaves it unavailable.
- Charging is shown only from the protocol's charging bit.

### Audio

- Noise mode begins `.unknown`.
- Game Mode, LHDC, Spatial Audio, and EQ expose known-state flags.
- UI controls are disabled until verified readback or push state exists.
- EQ bands and selection are hidden/loading until `0x010F` confirms a preset.
- LHDC never claims AAC/SBC is an LHDC stream on macOS.

### Devices

- Remembered devices begin empty.
- The interface reads loading state before `0x0112` completes.
- It shows an explicit timeout/rejection/unavailable state on failure.
- Active slot counts derive only from parsed remembered-device entries.
- The Mac is identified only by protocol flags or a verified local-address
  fallback.

### Firmware

`0x0103` and `0x0105` requests were added. Their fields begin `"Unavailable"`.
They may not display a firmware/model value unless a valid protocol reply is
parsed.

### RSSI and Codec

- RSSI begins unavailable because no protocol value is established.
- Active codec begins `"Unavailable"`.
- No fake AAC-LC, LHDC, LDAC, or hardware codec claim is shown.

## Mock Data Boundary

Mock data is not intentionally embedded in production SwiftUI initializers.
Future SwiftUI previews or XCTest fixtures must construct local preview/test
instances and must not mutate `AppState.shared`.

## Remaining Verification Required

Do not claim completion for:

- firmware/product parsing without real `0x8103`/`0x8105` replies;
- dual-device status without a real readback;
- device operations without a second host;
- ANC strengths or Transparency with earbuds in-ear;
- LHDC write/readback;
- Spatial write/readback;
- EQ writes/readback;
- phone-originated Realme Link pushes;
- RSSI or active codec if no supported live source exists.
