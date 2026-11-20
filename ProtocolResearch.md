# ProtocolResearch.md — Realme Buds Air 7 Bluetooth Communication Protocol

This document provides a comprehensive technical breakdown of the Bluetooth communication protocol used by the **Realme Buds Air 7** (and related BBK / OPPO / OnePlus TWS hardware). It synthesizes empirical findings, reverse-engineering analyses, and real-hardware test data from reference implementations (*Channel Fifteen / Earshot* by Srivtx, *realme-buds-mac* by kalki-kgp, and *Realme-TWS-Mac-Controller* by anikket-b).

All findings are documented here to serve as the protocol foundation for building an independent, native macOS controller application.

---

## 1. Protocol Architecture & Transport Layer

### 1.1 Transport: RFCOMM over Bluetooth Classic
Realme Buds Air 7 use standard Bluetooth Classic (BR/EDR). While standard audio streaming runs over A2DP (Advanced Audio Distribution Profile) and telephony over HFP (Hands-Free Profile), all proprietary device management, battery telemetry, and feature controls operate over a serial stream using **RFCOMM** (Radio Frequency Communication).

- **Service Class / SDP UUID:** `0000079A-D102-11E1-9B23-00025B00A5A5`
- **SDP Service Name:** `oppointeraction`
- **RFCOMM Channel:** Typically **Channel 15** on Realme Buds Air 7 (discovered dynamically via SDP query).
- **Safety Critical Warning (BESOTA):** The earbuds also advertise an SDP service named `BESOTA` (Bestechnic Over-The-Air) on RFCOMM Channel 13. This service is dedicated to flashing firmware. Writing to Channel 13 or sending corrupt frames can permanently brick the earbuds. **The application must explicitly filter out and never connect to any service with "OTA" or "BESOTA" in its SDP record.**

### 1.2 Framing & Packet Structure (OPOv1 Wire Format)
RFCOMM delivers an ordered byte stream without packet boundaries. Individual command packets must be framed and reassembled.

The packet layout:
```text
[ 0xAA ] [ Length: LEB128 ] [ 0x00 0x00 ] [ Cmd: UInt16 LE ] [ Seq: UInt8 ] [ PayloadLen: UInt16 LE ] [ Payload: N bytes ]
```

| Field | Size | Encoding | Description |
| :--- | :--- | :--- | :--- |
| **Preamble** | 1 byte | Fixed | Always `0xAA`. Used to synchronize the decoder. |
| **Length** | 1–2 bytes | Variable (LEB128) | Unsigned LEB128 integer. Counts all bytes after itself: 7 header bytes + payload length. |
| **Reserved** | 2 bytes | Fixed | `0x00 0x00`. |
| **Command ID** | 2 bytes | Little-Endian | Command opcode (e.g., `0x0106` battery request). Replies have bit 15 set (`0x8106`). |
| **Sequence Number** | 1 byte | Integer (1–255) | Rolling sequence counter. Replies echo the sequence number of the request. |
| **Payload Length** | 2 bytes | Little-Endian | Byte count of the payload that follows. |
| **Payload** | *N* bytes | Command-specific | The command arguments or telemetry data. |

> [!NOTE]
> - **Integrity & Checksums:** The OPO protocol has no CRC/checksum field; it relies entirely on RFCOMM's underlying L2CAP error detection.
> - **Decoder Precaution:** Certain Buds Air 7 firmware replies (such as Spatial Audio) declare a payload length in the inner header larger than the actual bytes carried in the frame. The decoder must treat the outer LEB128 frame length as authoritative.
> - **Command Pacing:** The earbuds' internal microcontroller drops back-to-back commands. Writes must be paced with a minimum delay of **150 ms – 350 ms** between packets.

---

## 2. Detailed Feature Breakdown

### Feature 1: Connect to Realme Buds Air 7
- **What it does:** Discovers paired Buds Air 7 on macOS, performs an SDP query to locate the `oppointeraction` service, and opens the RFCOMM channel.
- **How the earbuds communicate it:**
  - The earbuds announce their SDP records upon Bluetooth inquiry.
  - The Mac calls `IOBluetoothDevice.performSDPQuery(nil)`.
  - Once SDP records are resolved, the app searches for UUID `0000079A-D102-11E1-9B23-00025B00A5A5` or service name `oppointeraction`, retrieves the RFCOMM channel ID (typically 15), and calls `openRFCOMMChannelAsync(&channel, withChannelID: channelID, delegate: self)`.
  - When the channel opens, the host sends handshake command `0x0100` (`AA 07 00 00 00 01 <seq> 00 00`), followed by event subscription command `0x0205`.
- **Whether documented:** Documented in open-source projects (*Earshot*, *BudsBar*, *BudsLink*).
- **Tested against Buds Air 7:** Yes, tested and verified on firmware 1.1.0.62 and 1.1.0.66.
- **Remaining uncertainty:** None regarding channel opening. Opening an RFCOMM channel fails if another app currently holds the channel, or if the audio ACL connection is dormant (requires `openConnection()` or audio activity first).

---

### Feature 2: Communicate using Bluetooth RFCOMM
- **What it does:** Full-duplex asynchronous packet transfer over the established RFCOMM channel.
- **How the earbuds communicate it:**
  - **Outgoing:** Mac writes frames via `IOBluetoothRFCOMMChannel.writeSync(&bytes, length: len)`.
  - **Incoming:** Mac receives byte chunks via `rfcommChannelData(_:data:length:)`. A streaming buffer scans for `0xAA`, decodes LEB128 length, validates packet boundaries, extracts the 16-bit opcode, and dispatches the payload.
  - **Acknowledgements:** Writes are answered by the buds with `Opcode | 0x8000` carrying a status byte (`0x00` = success/applied, `0x0E` = refused because buds are not in ear, other = error).
- **Whether documented:** Fully documented and reverse-engineered.
- **Tested against Buds Air 7:** Yes, extensively tested.
- **Remaining uncertainty:** None.

---

### Feature 3: Read Earbud and Case Battery
- **What it does:** Obtains individual battery percentages and charging states for Left bud, Right bud, and Charging Case.
- **How the earbuds communicate it:**
  - **Query:** Opcode `0x0106` (Payload: empty `[]`).
  - **Response:** Opcode `0x8106` (or asynchronous push `0x0204` with event category `0x01`).
  - **Payload Structure:**
    ```text
    [ Status: UInt8 ] [ Count: UInt8 ] [ (Slot: UInt8, RawLevel: UInt8) ... ]
    ```
    - `Slot 0x01`: Left earbud
    - `Slot 0x02`: Right earbud
    - `Slot 0x03`: Charging case
    - `RawLevel`:
      - Battery percentage: `RawLevel & 0x7F` (0–100%).
      - Charging indicator: `(RawLevel & 0x80) != 0` (top bit set = charging).
      - *Case Quirk:* If the case lid is closed and the buds are out of the case, the case cannot communicate over the earbud pins and reports level `0x00` with charging flag `false`. The UI must interpret this as "Case telemetry unavailable" rather than 0% battery.
- **Whether documented:** Documented in Gadgetbridge, Earshot, and BudsBar.
- **Tested against Buds Air 7:** Yes, tested on Buds Air 7.
- **Remaining uncertainty:** None.

---

### Feature 4: Change ANC and Transparency
- **What it does:** Toggles between Active Noise Cancellation (ANC), Transparency mode, and Off, as well as setting the specific ANC intensity level.
- **How the earbuds communicate it:**
  - **Query current mode:** Opcode `0x010C` with payload `[0x01, 0x01]`.
  - **Response:** Opcode `0x810C` with payload `[status, 0x01, 0x01, value]`.
  - **Asynchronous push:** Opcode `0x0204` with prefix `0x03` (payload: `[0x03, count, 0x01, value]`).
  - **Setting mode:** Opcode `0x0404` with payload `[0x01, 0x01, value]`.
  - **Value Mapping for Realme Buds Air 7:**
    - `0x01`: **Off**
    - `0x02`: **Transparency**
    - `0x04`: **ANC — Mild**
    - `0x10`: **ANC — Moderate**
    - `0x08`: **ANC — Max / Deep**
    - `0x20`: **ANC — Smart / Adaptive**
  - *Crucial Finding:* There is no separate "ANC on" command. To enable ANC, the host must send one of the 4 strength codes (`0x04`, `0x08`, `0x10`, or `0x20`). Furthermore, Realme Buds Air 7 invert the documented OnePlus mapping (on OnePlus `0x01` is ANC and `0x02` is Off; on Realme `0x01` is Off and `0x02` is Transparency).
  - *Refusal Behavior:* The earbuds refuse ANC mode changes with status `0x0E` if neither bud is detected inside an ear.
- **Whether documented:** Documented and verified.
- **Tested against Buds Air 7:** Yes, verified on hardware.
- **Remaining uncertainty:** None.

---

### Feature 5: Enable Game Mode (Low Latency)
- **What it does:** Reduces audio transmission latency at the expense of slight range/bitrate resilience.
- **How the earbuds communicate it:**
  - Game Mode is implemented as part of the "Miscellaneous Configuration" feature switch table (`0x010D` / `0x0403`).
  - **Feature ID for Game Mode:** `0x06`.
  - **Query:** Opcode `0x010D` with payload containing requested feature IDs: `[count, 0x06, ...]`.
  - **Response:** Opcode `0x810D` with payload `[status, count, (0x06, value), ...]`, where `value = 0x01` is enabled, `0x00` is disabled.
  - **Setting Game Mode:** Opcode `0x0403` with payload `[0x06, 0x01]` (to enable) or `[0x06, 0x00]` (to disable).
  - **Notification:** Push `0x0204` with type `0x05` pushes `[0x05, value]`.
- **Whether documented:** Documented in Earshot and realme-buds-mac.
- **Tested against Buds Air 7:** Yes, verified on hardware.
- **Remaining uncertainty:** None.

---

### Feature 6: Change LHDC Preference (High-Res Codec)
- **What it does:** Configures whether the earbuds request high-resolution audio codec negotiation (LHDC / LDAC).
- **How the earbuds communicate it:**
  - Managed via feature switch `0x010D` / `0x0403`.
  - **Feature ID for Hi-Res Audio:** `0x18`.
  - **Query:** Opcode `0x010D` including ID `0x18`.
  - **Set:** Opcode `0x0403` with payload `[0x18, 0x01]` (enabled) or `[0x18, 0x00]` (disabled).
- **Whether documented:** Documented in Earshot and realme-buds-mac.
- **Tested against Buds Air 7:** Yes, verified.
- **Remaining uncertainty / macOS Limitation:** On macOS, the system A2DP Bluetooth audio stack natively supports AAC and SBC, but **macOS does not natively support LHDC or LDAC encoding**. Enabling this toggle sets the flag in the earbuds' firmware (meaning they will use LHDC when connected to a compatible Android device or custom codec pipe), but macOS will continue streaming AAC. This distinction should be transparently noted in the UI.

---

### Feature 7: Read Remembered Bluetooth Devices
- **What it does:** Retrieves the table of Bluetooth host devices previously paired and stored in the earbuds' non-volatile memory.
- **How the earbuds communicate it:**
  - **Query:** Opcode `0x0112` (`Cmd.multiConnectInfo`) with empty payload `[]`.
  - **Response:** Opcode `0x8112` (`0x0112 | 0x8000`).
  - **Payload Structure:**
    ```text
    [ Status: 0x00 ] [ DeviceCount: UInt8 ]
      For each device:
        [ Address: 6 bytes (little-endian / byte-reversed MAC) ]
        [ EntryLength: 1 byte ]
        [ ConnectionState: 1 byte ]  (1 or 2 = Connected, 0 = Disconnected)
        [ Flags: 1 byte ]            (Bit 0: 1 = This Host Device / This Mac)
        [ NameLength: 1 byte ]
        [ DeviceName: UTF-8 string ]
    ```
- **Whether documented:** Documented in `kalki-kgp/realme-buds-mac` and `maniacx/BudsLink`.
- **Tested against Buds Air 7:** Yes, confirmed on Buds Air 7 firmware 1.1.0.66.
- **Remaining uncertainty:** None regarding parsing. The earbuds do not always push an update spontaneously when an external device disconnects, requiring periodic polling or re-querying when notifications arrive.

---

### Feature 8: Manage Two Simultaneous Device Connections (Dual-Device / Multi-Connect)
- **What it does:** Enables/disables the Dual Connection feature (`0x11`), queries active connections, and connects or disconnects specific remembered devices.
- **How the earbuds communicate it:**
  - **Toggle Dual Connection Master Switch:**
    - Feature ID: `0x11` via `0x0403 [0x11, 0x01]` (enable) or `[0x11, 0x00]` (disable).
  - **Connect a Remembered Device:**
    - Opcode `0x040B` (`operateMultiConnect`).
    - Payload: `[0x01] + DeviceMACAddress (6 bytes) + [0x01]`.
  - **Disconnect a Remembered Device:**
    - Opcode `0x040B`.
    - Payload: `[0x01] + DeviceMACAddress (6 bytes) + [0x00]`.

#### Special Investigation: Can the protocol switch the active audio source or only connect/disconnect remembered devices?
> [!IMPORTANT]
> **Key Finding on Audio Source Switching:**
> 1. **Link Layer vs. Audio Routing:** The OPO protocol commands `0x0112` and `0x040B` operate strictly on the **Bluetooth ACL link state table** (connecting and disconnecting host links).
> 2. **Multipoint Audio Arbitration:** In Bluetooth Classic multipoint (Dual Connection), audio routing between two simultaneously connected devices (e.g., Mac and iPhone) is handled **autonomously inside the earbuds' DSP/firmware**. The earbuds switch audio based on stream activity: if the Mac pauses media and the iPhone starts playing (or receives a telephone call), the earbuds internally route the iPhone's A2DP/HFP audio stream.
> 3. **Protocol Limitation:** There is **no discrete protocol command payload** in OPOv1 to tell the earbuds *"keep both devices connected, but switch the active audio playback stream to Device B"*.
> 4. **Hardware Gesture Binding:** The protocol does define a gesture action code `0x0A` (`deviceSwitch`), which can be bound to the touch sensor ("Touch & Hold"). When triggered on the hardware, the buds attempt an internal source swap.
> 5. **Application Solution for Host Control:** To reliably switch audio to a third device or swap focus from a desktop controller, the application must orchestrate connection state:
>    - If 2 devices are connected and the user wants to connect Device C, the controller must issue `0x040B [0x01, MAC_other, 0x00]` to disconnect the second device (never disconnecting the Mac), wait for confirmation that the link is dropped, and then issue `0x040B [0x01, MAC_C, 0x01]`.

- **Tested against Buds Air 7:** Yes, tested on Buds Air 7.
- **Remaining uncertainty:** None; the physical limit of the hardware radio is 2 concurrent ACL connections.

---

### Feature 9: Add a New Paired Device
- **What it does:** Guides discovery and pairing of a brand-new device (host) to the earbuds.
- **How the earbuds communicate it:**
  - **Bluetooth Pairing Mode:** A new device cannot be paired over RFCOMM because RFCOMM requires an existing authenticated Bluetooth ACL link. The earbuds enter pairing mode via hardware:
    1. Placing both earbuds in the charging case with the lid open.
    2. Pressing and holding the physical case button for 3 seconds until the indicator LED blinks white.
  - **Host Discovery:** Once in pairing mode, the earbuds broadcast standard Bluetooth Classic inquiry responses and BLE Fast Pair beacons. The new host device discovers them through OS-level Bluetooth pairing menus.
  - **Post-Pairing Integration:** Once paired with the new host, the earbuds add the host's MAC address and Bluetooth name to the remembered-device list (`0x0112`).
  - **Role of the Mac Controller:** The app cannot magically force the earbuds into pairing mode via software if they are out of the case. The app can:
    - Display an interactive "Add New Device" pairing guide.
    - Monitor `IOBluetoothDeviceInquiry` if adding the device to the Mac itself.
    - Refresh the `0x0112` list once the new device is paired to display it immediately.
- **Whether documented:** Standard Bluetooth Core Specification behavior combined with OPO's `0x0112` device list.
- **Tested against Buds Air 7:** Yes.
- **Remaining uncertainty:** None.

---

### Feature 10: Detect Bluetooth Connection Changes
- **What it does:** Detects when the earbuds connect, disconnect, or drop out of range, automatically re-establishing the RFCOMM channel.
- **How the earbuds communicate it:**
  - **System Notifications (`IOBluetooth`):**
    - `IOBluetoothDevice.register(forConnectNotifications:selector:)`: Informs the app when the Mac's audio link to the earbuds connects.
    - `IOBluetoothDevice.register(forDisconnectNotification:selector:)`: Informs the app when the audio link disconnects.
  - **RFCOMM Delegate Callbacks:**
    - `rfcommChannelClosed(_:)`: Fired immediately when the RFCOMM channel terminates (e.g., buds put in case, lid closed, or out of range).
    - `rfcommChannelOpenComplete(_:status:)`: Fired when an asynchronous channel connection attempt completes.
  - **Unsolicited Push Events (`0x0204`):**
    - Event `0xF2`: Buds push when remembered device status changes.
    - Events `0x06`, `0x0D`, `0x12`, `0x13`, `0x16`: Push triggers indicating connection topology shifts, signalling the app to re-fetch `0x0112`.
- **Whether documented:** Fully documented across macOS `IOBluetooth` APIs and OPO event logs.
- **Tested against Buds Air 7:** Yes, verified.
- **Remaining uncertainty:** None.

---

## 3. Summary of Command Opcodes & Payload Reference

| Feature | Request Opcode | Reply Opcode | Payload Summary |
| :--- | :--- | :--- | :--- |
| **Handshake** | `0x0100` | `0x8100` | `[]` |
| **Register Push Events** | `0x0205` | None (Pushes `0x0204`) | `[Count, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x0D, 0x0E, 0x0F, 0x10, 0xF1, 0xF2]` |
| **Product ID** | `0x0103` | `0x8103` | Returns 3 bytes (Air 7 = `0x064812`) |
| **Firmware Version** | `0x0105` | `0x8105` | Returns ASCII string `side,kind,version,...` |
| **Battery Status** | `0x0106` | `0x8106` | `[Status, Count, (Slot, Level \| ChargeBit)...]` |
| **Earbud Placement (Wear)** | `0x0109` | `0x8109` | `[Status, Count, (Side, State)...]` (0=case, 1=out, 3=ear) |
| **Noise Mode Query** | `0x010C` | `0x810C` | `[0x01, 0x01]` -> `[Status, 0x01, 0x01, Mode]` |
| **Set Noise Mode / ANC** | `0x0404` | `0x8404` | `[0x01, 0x01, ModeByte]` (`01`=Off, `02`=Trans, `04`=Mild, `08`=Deep, `10`=Mod, `20`=Smart) |
| **Equalizer Preset** | `0x010F` | `0x810F` | Query: `[]` -> `[Status, PresetID]` (0=Orig, 1=Deep, 2=Serenade, 3=Clear) |
| **Set Equalizer** | `0x0406` | `0x8406` | `[PresetID]` |
| **Feature Switches (Misc)** | `0x010D` | `0x810D` | `[Count, ID1, ID2...]` (GameMode=`06`, DualDev=`11`, HiRes=`18`, Spatial=`1B`) |
| **Set Feature Switch** | `0x0403` | `0x8403` | `[FeatureID, 0x01 / 0x00]` |
| **Spatial Audio Type** | `0x041E` | `0x841E` | `[0x01 / 0x00]` (Sent alongside switch `0x1B`) |
| **Remembered Devices List** | `0x0112` | `0x8112` | `[]` -> `[0x00, Count, (MAC[6], Len, State, Flags, NameLen, Name)...]` |
| **Operate Device Connect** | `0x040B` | `0x840B` | `[0x01] + MAC[6] + [0x01 (connect) / 0x00 (disconnect)]` |
| **Find Earbuds (Ring)** | `0x0400` | `0x8400` | `[0x01 (ring) / 0x00 (stop)]` |

---

## 4. Conclusion & Readiness

The communication protocol for the Realme Buds Air 7 is fully reverse-engineered, well-understood, and verified on physical hardware running current firmware releases. All 10 required features have concrete, unambiguous binary payloads and operational flows.

Special attention has been documented regarding the distinction between link-level connection swapping (`0x040B`) versus autonomous DSP audio routing in dual-device mode.

The project is fully prepared to proceed with architecture and implementation planning.
