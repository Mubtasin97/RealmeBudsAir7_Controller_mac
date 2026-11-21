# Live Audio Settings Test

Tested: 2026-11-21

## Implemented

The existing OPO/RFCOMM implementation was extended with:

- Live noise-mode query `0x010C`.
- Noise-mode set `0x0404`.
- Normal/Off `0x01`.
- Transparency `0x02`.
- Mild ANC `0x04`.
- Moderate ANC `0x10`.
- Deep ANC `0x08`.
- Adaptive ANC `0x20`.
- Push parsing for noise category `0x03`.
- Game Mode feature query/set `0x010D` / `0x0403`, feature ID `0x06`.
- LHDC preference feature query/set `0x010D` / `0x0403`, feature ID `0x18`.
- EQ preset query/set `0x010F` / `0x0406`.
- Spatial Audio feature query/set `0x010D` / `0x0403`, feature ID `0x1B`.
- Acknowledgement handling for status `0x00`, `0x0E`, and other rejection values.
- Readback after successful acknowledged writes.
- Loading/error state and unknown initial audio state.
- UI controls remain disabled until their live state is known.
- Custom EQ curves are not sent because no custom-curve command is documented.
- LHDC UI does not claim macOS codec support; macOS remains AAC/SBC.

## Verified Initial Hardware Readback

The real paired device was `realme Buds Air7`.

Noise mode:

- `0x810C` payload: `00 01 01 01`
- Result: Normal/Off (`0x01`)

Feature switches:

- `0x810D` payload: `00 03 06 00 18 00 1B 00`
- Game Mode: off (`0x06 = 0x00`)
- LHDC: off (`0x18 = 0x00`)
- Spatial Audio: off (`0x1B = 0x00`)

EQ:

- `0x810F` payload: `00 03`
- Result: Clear Bass preset (`0x03`)

## Verified Hardware Writes

Game Mode was tested and confirmed in both directions:

- `0x0403 [0x06, 0x01]` write succeeded.
- Push: `0x0204 [0x05, 0x01]`.
- Readback: `0x810D [0x00, 0x01, 0x06, 0x01]`.
- `0x0403 [0x06, 0x00]` write succeeded.
- Push: `0x0204 [0x05, 0x00]`.
- Readback: `0x810D [0x00, 0x01, 0x06, 0x00]`.

## Not Fully Verified

ANC, Transparency, and ANC strengths were sent to the earbuds, but the
post-write readback remained Normal/Off. This is not treated as a successful
hardware change.

LHDC, Spatial Audio, and EQ write/readback scripts did not complete because
the standalone Swift test harness failed to compile before execution.
Therefore, those writes are implemented from the project protocol
documentation but are not yet individually hardware-verified in this report.

The app will not update UI state from write-buffer success alone:

- write failure remains an error;
- timeout remains an error;
- rejection/refusal remains an error;
- UI state changes only after readback or a verified push.

ANC changes that require earbud wear may return refusal `0x0E`; the UI reports
that refusal explicitly and does not claim the mode changed.

## Runtime Verification

- Release build: Passed.
- App bundle packaging: Passed.
- Final app process remained running.
- RFCOMM channel 15 reopened successfully.
- No new crash report appeared.
- Initial live reads and Game Mode push/readback were received.

## Remaining Hardware Acceptance

Before declaring these features fully complete, the app itself must be used to
verify:

- each ANC mode with earbuds in-ear;
- Transparency;
- Normal/Off restoration;
- LHDC on/off readback;
- Spatial on/off readback;
- every documented EQ preset;
- disconnect/reconnect audio-state refresh.
