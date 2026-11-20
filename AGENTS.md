# AGENTS.md — Realme Buds Controller

## 1. Project Overview

**Realme Buds Controller** is an independent, native macOS utility designed to manage and control **Realme Buds Air 7** directly from an Apple Silicon Mac over Bluetooth.

The application communicates with the earbuds using native macOS Bluetooth frameworks to deliver hardware control, monitoring, and profile management in a lightweight, responsive interface tailored for modern macOS.

---

## 2. Technical Stack & Development Environment

- **Platform:** macOS 27.2 (Apple Silicon / `arm64`)
- **IDE:** Xcode 27.2
- **Language:** Swift 6.4 (Swift 6 strict concurrency compliance)
- **UI Frameworks:** SwiftUI with targeted AppKit integration where required
- **Communication Frameworks:** Native macOS Bluetooth frameworks (`IOBluetooth`, `CoreBluetooth`)
- **Persistence & Preferences:** `UserDefaults` / `AppStorage`, macOS Keychain where appropriate
- **Version Control:** Git

---

## 3. Design System & User Interface

- **Visual Theme:** macOS Liquid Glass appearance with translucent, floating material surfaces (`NSVisualEffectView` / `.ultraThinMaterial`).
- **Accent Color:** Soft violet (`#7652C8` / `rgb(118, 82, 200)`).
- **Iconography:** Native Apple SF Symbols.
- **Color Modes:**
  - Full support for Light, Dark, and System appearance.
  - Dedicated Light / Dark / System appearance toggle located prominently in the application header.
- **Window Behavior:** Lightweight, floating or menu-bar accessible translucent window with fluid animations and responsive layout.

---

## 4. Main Application Sections

1. **Overview**
   - Live connection state and device status.
   - Granular battery indicators (Left bud, Right bud, Charging case).
   - Quick toggles for Noise Control (ANC, Transparency, Off) and Game Mode.
2. **Connected Devices**
   - Active device status and dual-device connection management.
   - List of remembered and previously paired devices.
   - "Add New Device" discovery and pairing workflow.
3. **Settings**
   - Sound profiles, Equalizer (EQ) presets and custom curves.
   - Spatial audio configuration (where supported).
   - LHDC preference / high-res audio streaming toggles.
   - Connection behaviors: Automatic connection, automatic reconnection, and Launch at Login.
4. **Diagnostics**
   - Bluetooth connection logs, signal quality (RSSI), and raw packet exchange monitor.
   - Protocol message verification and diagnostic tracing.

---

## 5. Feature Specifications

- **Battery Monitoring:** Accurate readout for Left bud, Right bud, and Case, including charging indicators.
- **Noise Control:** Seamless switching between Active Noise Cancellation (ANC), Transparency, and Off.
- **ANC Strength:** Fine-tuned control over cancellation intensity levels (e.g., Mild, Moderate, Strong, Smart/Adaptive).
- **Game Mode:** Low-latency mode toggle.
- **LHDC Preference:** High-resolution audio codec preference toggle.
- **Equalizer (EQ):** Built-in audio presets (Bass Boost, Balanced, Clear, etc.) and custom band adjustments.
- **Spatial Audio:** Spatial audio toggle and mode configuration where hardware supports it.
- **Dual-Device Management:** View, switch, and manage dual-connection active links between host devices.
- **Remembered Devices:** View, prioritize, or forget previously paired devices.
- **Add New Device Workflow:** Assisted Bluetooth discovery, pairing guidance, and handshake.
- **Auto-Connection & Reconnection:** Automatically detect when earbuds are taken out of the case or power on, and re-establish control channels gracefully.
- **Launch at Login:** Native `SMAppService` or login item integration for background / menu-bar readiness.

---

## 6. Development Rules & Engineering Directives

1. **Native Architecture:** Use strictly native Swift and SwiftUI. Use AppKit bridges only when necessary for advanced windowing or system integration.
2. **Separation of Concerns:** Keep the UI layer strictly decoupled from Bluetooth protocol and transport layers. Use reactive view models and clean service abstractions.
3. **Milestone-Driven Execution:** Work strictly one milestone at a time.
4. **No Giant Leaps:** Do not build everything in a single turn. Wait for user instructions before implementing each phase.
5. **Protocol Authenticity:** Verify all command payloads and packet structures against documented protocol specifications.
6. **No Speculation:** Never guess or invent Bluetooth command bytes or payloads.
7. **Safe Bluetooth Handling:** Never disconnect the Mac's system-level audio Bluetooth connection automatically unless explicitly instructed.
8. **Firmware Safety:** Never execute firmware updates or write to dangerous firmware regions.
9. **Rigorous Testing:** Verify and test every feature thoroughly before declaring a milestone complete.
10. **Regression Prevention:** Preserve and protect existing working functionality across all changes.
11. **Clean Commit History:** Create meaningful Git commits after every completed milestone.
12. **Lightweight & Efficient:** Maintain minimal memory footprint, negligible idle CPU usage, and efficient Bluetooth polling/listening.
13. **Licensing & Reference Policy:** Existing open-source implementations are technical references only. Build an independent, original application and respect all relevant licenses.
14. **User Guidance:** Always wait for user instructions before moving to the next stage or creating new project milestones.
