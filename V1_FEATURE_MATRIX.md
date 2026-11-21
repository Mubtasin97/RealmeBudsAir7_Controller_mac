# Realme Buds Controller — V1 Feature Matrix

Reviewed: 2026-11-21

## Classification Rules

The status below describes the current repository implementation, not merely
whether a feature is theoretically possible. Protocol evidence is taken only
from [ProtocolResearch.md](./ProtocolResearch.md). A protocol feature with a
UI model but no encoder, write, decoder, or live state update is classified as
**Partially implemented**.

- **Already implemented and tested** — implemented in the application and
  supported by repository evidence of successful testing.
- **Implemented but not tested** — implementation exists, but there is no
  relevant runtime or hardware test evidence in the repository.
- **Partially implemented** — a UI, state model, transport primitive, or
  guidance exists, but the complete feature path is missing.
- **Not implemented** — no usable application implementation exists.
- **Unsupported or not exposed by the protocol** — no documented,
  model-specific command or payload exists in the current protocol research.
- **Requires additional hardware verification** — the design is documented or
  implemented, but operation on the target Buds Air 7 hardware still needs a
  controlled test. This is recorded as a verification gate rather than a
  reason to invent undocumented behavior.

## Matrix

| # | Feature | V1 status | Protocol support/evidence | Current repository evidence | V1 acceptance requirement |
|---:|---|---|---|---|---|
| 1 | Left battery | Partially implemented; requires additional hardware verification | Supported. `0x0106`/`0x8106` battery status; slot `0x01`; level is `RawLevel & 0x7F`. | `BatteryStatus` and left battery card exist, but values are seeded and RFCOMM data is not parsed. | Decode query/push data, update the left value, handle missing data, and verify against hardware. |
| 2 | Right battery | Partially implemented; requires additional hardware verification | Supported. `0x0106`/`0x8106`; slot `0x02`. | Right battery model/card exists; no live protocol binding. | Decode, display, refresh, and verify right-bud readings. |
| 3 | Case battery | Partially implemented; requires additional hardware verification | Supported. `0x0106`/`0x8106`; slot `0x03`. Research documents the closed-lid `0x00` unavailable case. | Case battery model/card exists; the unavailable-vs-zero rule is not implemented. | Decode case status and display “unavailable” when the documented quirk applies. |
| 4 | Charging status | Partially implemented; requires additional hardware verification | Supported in the battery payload: high bit of `RawLevel` indicates charging. | Charging UI exists, but no battery payload parser updates it. | Verify charging flags for both buds and case, including transitions. |
| 5 | Firmware information | Partially implemented; requires additional hardware verification | Supported. `0x0105`/`0x8105` returns an ASCII firmware string; `0x0103`/`0x8103` returns product ID. | Firmware/model fields exist with seeded values; no queries or parsers exist. | Query and parse product/firmware information per side where applicable. Do not add firmware writing/update behavior. |
| 6 | ANC | Partially implemented; requires additional hardware verification | Supported. Query `0x010C`; set `0x0404`; Realme mapping is documented. | ANC UI and `NoiseControlMode` exist; `AppState` only changes local state and logs a claimed command. | Query current mode, send documented mode values, process acknowledgements/refusals, and verify in-ear behavior. |
| 7 | Transparency | Partially implemented; requires additional hardware verification | Supported by `0x010C`/`0x0404`; Realme value `0x02`. | Transparency control exists only in SwiftUI/local state. | Implement query/set/acknowledgement and verify actual transparency mode. |
| 8 | Normal mode | Partially implemented; requires additional hardware verification | Supported as the documented Off/normal value `0x01` through `0x0404`. | “Off” mode exists in the UI/model; no RFCOMM write or response handling exists. | Expose the product-appropriate “Normal/Off” label and verify it maps to `0x01`. |
| 9 | ANC strength | Partially implemented; requires additional hardware verification | Supported. `0x04` mild, `0x10` moderate, `0x08` max/deep, `0x20` smart. | Four strength choices exist in `ANCStrength`; no protocol path exists. | Send only the documented strength values and verify each level. |
| 10 | Game Mode | Partially implemented; requires additional hardware verification | Supported. Feature ID `0x06` via `0x010D`/`0x810D` and `0x0403`/`0x8403`; push type `0x05`. | Toggle and local log exist; no query/set/push handling exists. | Implement read, set, acknowledgement, push update, and hardware verification. |
| 11 | LHDC preference | Partially implemented; requires additional hardware verification | Supported as an earbud feature switch: ID `0x18` via `0x010D`/`0x0403`. Research explicitly says macOS still streams AAC/SBC without native LHDC/LDAC encoding. | Toggle and local state exist; no protocol path or macOS limitation messaging is implemented. | Implement the earbud preference with an explicit macOS codec limitation in the UI. |
| 12 | EQ presets | Partially implemented; requires additional hardware verification | Supported. Query `0x010F`/`0x810F`; set `0x0406`/`0x8406`; documented preset IDs 0–3. | Preset model, six-band UI, and local state exist; no query/set commands are sent. | Implement documented preset query/set and verify all documented Air 7 presets. Custom curves remain a separate capability unless a documented custom-curve command is verified. |
| 13 | Spatial Audio | Partially implemented; requires additional hardware verification | Supported as feature ID `0x1B` through feature switches and type command `0x041E`/`0x841E`; research warns about response length handling. | No dedicated spatial-audio view or protocol handler; only an `AppState` boolean exists. | Implement switch/type query and set using only documented payloads; use outer frame length for decoding; verify on hardware. |
| 14 | Wind-noise reduction | Unsupported or not exposed by the documented protocol | No Air 7 command, feature ID, or payload is documented in [ProtocolResearch.md](./ProtocolResearch.md). | `isWindNoiseReductionEnabled` exists as a local boolean, but has no protocol evidence or behavior. | Do not expose a functional V1 control. It may be shown as unavailable; add support only after model-specific hardware evidence and documented payloads exist. |
| 15 | Dynamic bass | Unsupported or not exposed by the documented protocol | No Air 7 command, feature ID, or payload is documented. EQ presets are documented, but that is not evidence for a separate dynamic-bass switch. | `isDynamicBassEnabled` exists only as local state. | Do not expose a functional V1 control or invent a feature ID. |
| 16 | Other Realme Link settings supported by the protocol | Partially implemented; requires additional hardware verification | Documented capabilities include product ID (`0x0103`), firmware (`0x0105`), wear/placement (`0x0109`), event subscription (`0x0205`), Find Earbuds/ring (`0x0400`), EQ, Spatial Audio, Game Mode, LHDC, and Dual Connection. | Diagnostics and state fields exist, but the protocol session, parsers, and command handlers are missing. Firmware update is explicitly prohibited by project rules. | Include all safe documented read/set operations above, including wear state and Find Earbuds. Exclude OTA/firmware writes and any undocumented setting. |
| 17 | Dual-device connection | Partially implemented; requires additional hardware verification | Supported. Master switch feature ID `0x11`; remembered list `0x0112`; operations `0x040B`. Audio-source selection is not a discrete OPO command. | Two-slot UI and local toggles exist; no protocol reads/writes or confirmation handling exists. | Query state, enable/disable documented switch, preserve the Mac link, and verify two-device behavior without unsafe automatic disconnection. |
| 18 | Remembered-device list | Partially implemented; requires additional hardware verification | Supported. `0x0112`/`0x8112`; documented MAC, state, flags, and UTF-8 name structure. | List UI exists with seeded devices; no parser or refresh path exists. | Parse the complete list safely, identify this Mac from flags, and refresh after connection-topology events. |
| 19 | Connect/disconnect remembered devices | Partially implemented; requires additional hardware verification | Supported. `0x040B`/`0x840B`; documented connect/disconnect payload structure. | Buttons update local slot state only. | Send operations, await status, refresh `0x0112`, enforce the two-link limit, and never disconnect the Mac automatically. |
| 20 | Replace connected device | Partially implemented; requires additional hardware verification | Supported as an application sequence using documented `0x040B`: disconnect the secondary host, confirm, then connect the replacement. No independent source-switch opcode exists. | “Swap In” UI and local state sequence exist; no Bluetooth operations or confirmation workflow exists. | Implement a guarded secondary-only replacement sequence and verify failure/recovery paths. |
| 21 | Add New Device | Partially implemented; requires additional hardware verification | Pairing is OS/hardware-driven, not an RFCOMM command. After pairing, `0x0112` exposes the remembered host list. | Pairing guidance sheet exists and opens macOS Bluetooth Settings; no post-pair refresh/inquiry integration exists. | Provide reliable guidance, optionally monitor the Mac’s pairing/discovery state, then refresh the remembered list. Do not claim software-controlled case pairing. |
| 22 | Automatic connection | Partially implemented; requires additional hardware verification | Transport flow is documented: paired-device detection, SDP, RFCOMM, handshake `0x0100`, then event subscription `0x0205`. | Launch detection and `autoConnectOnLaunch` call service discovery; handshake/subscription are missing. | Complete the session bootstrap and make launch connection state reflect real success/failure. |
| 23 | Automatic reconnection | Partially implemented; requires additional hardware verification | System connect/disconnect notifications, RFCOMM close callback, and documented push events support a reconnection workflow. | Notifications and close handling exist; retry/session restoration is missing. | Add bounded retry/backoff, reconnect only when safe, repeat handshake/subscription, refresh state, and preserve the system audio link. |
| 24 | Launch at login | Partially implemented | macOS supports login-item integration; no earbud protocol is involved. | A setting exists and the UI describes `SMAppService`, but no integration is implemented. | Implement and test native login-item registration/status/error handling. |
| 25 | Light/Dark/System appearance | Implemented but not tested | Not a Bluetooth protocol feature. | `AppearanceManager`, `UserDefaults` persistence, SwiftUI color-scheme override, and menu-bar toggle exist. | Verify all three modes, relaunch persistence, accessibility contrast, and menu-bar/popover behavior. |
| 26 | Notifications | Partially implemented | Not a Bluetooth protocol feature; notification triggers depend on decoded telemetry/events. | Preference toggles exist; no notification authorization/delivery implementation exists. | Implement permission-aware notifications for low battery, device changes, and charging completion after live state exists. |
| 27 | Diagnostics | Implemented but not tested; requires additional hardware verification | Supported by transport callbacks and documented protocol states/events. | Bluetooth availability, paired-device detection, SDP, RFCOMM state, raw hex logging, filters, copy, and clear actions exist. | Add decoded frame/command/status visibility, preserve raw frames, expose errors clearly, and verify diagnostics during real hardware sessions. |

## First-Release Scope Decision

V1 includes every feature with documented, safe, model-specific support:

- Battery and charging telemetry.
- Product and firmware reads.
- Normal/Transparency/ANC modes and ANC strengths.
- Game Mode, LHDC preference, documented EQ presets, and Spatial Audio.
- Wear/placement telemetry and Find Earbuds/ring.
- Dual-device state, remembered devices, connect/disconnect, and guarded replacement.
- Pairing guidance and post-pair remembered-list refresh.
- Automatic connection/reconnection.
- Launch at login, appearance modes, notifications, and diagnostics.

Wind-noise reduction and Dynamic Bass are not included as functional controls
because the current protocol research does not expose reliable Air 7 commands
for them. Firmware update/write operations are also excluded by the project
safety rules, even though firmware information reads are in V1.
