# UI and Bluetooth Connection Bug Report

Reviewed: 2026-11-21

## Summary

Two separate defects are present:

1. The popover's active tab content does not have an adaptive opaque or
   sufficiently opaque native material layer. This allows sharp text and
   interface elements from previous/underlying content to remain visible
   through tab changes.
2. Earbud connection notifications can terminate the app with a genuine
   Swift concurrency runtime trap. A macOS crash report proves that the
   Bluetooth connect callback is executed on IOBluetooth's
   `com.apple.bluetooth.iobluetooth.coordinatorQueue`, while the callback
   reaches `@MainActor` Swift code without dispatching onto the main actor.

The first issue is UI layering. The second issue is a real process crash.

## Issue 1: Liquid Glass Background Bleed-Through

### Findings

`PopoverRootView` wraps the complete popover in `GlassEffectContainer`.
Inside it, the root `VStack` and `ScrollView` provide no dedicated adaptive
background for the tab content area.

The tab content is selected with a `switch appState.activeSection`, and all
tab views are placed directly in the scroll view:

- [PopoverRootView.swift](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Views/PopoverRootView.swift:15)
- [PopoverRootView.swift](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Views/PopoverRootView.swift:26)
- [PopoverRootView.swift](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Views/PopoverRootView.swift:28)

The switch removes/replaces the active tab in normal SwiftUI layout, but the
surrounding content scroll view does not provide a complete opaque-adaptive
surface. Transitions and rendering can therefore expose the hosting material,
underlying window content, or remnants of the previous view.

The reusable glass card implementation also uses `.ultraThinMaterial` and
`.glassEffect(.regular)`:

- [LiquidGlassComponents.swift](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/DesignSystem/LiquidGlassComponents.swift:38)
- [LiquidGlassComponents.swift](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/DesignSystem/LiquidGlassComponents.swift:40)
- [LiquidGlassComponents.swift](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/DesignSystem/LiquidGlassComponents.swift:41)

That treatment is appropriate for individual cards and the header, but it is
not sufficiently isolated for the complete popover content area.

### Root cause

There is no explicit main-content material layer that:

- spans the full width and available height;
- uses an adaptive native material;
- is clipped to the popover bounds;
- sits below the active tab only;
- provides a transition-safe opaque baseline;
- preserves the translucent header and navigation separately.

The main body also lacks `clipShape`/`cornerRadius` boundaries around its
scrollable area and tab switcher. The result can look like underlying text is
visible through each tab, especially during tab replacement or appearance
changes.

### Proposed fix

At the `PopoverRootView` level:

1. Preserve `GlassEffectContainer` for the existing header and cards.
2. Add a dedicated content-area surface behind the `ScrollView`, spanning the
   full remaining height.
3. Use adaptive native material, for example:
   - `.regularMaterial` or `.thickMaterial` for the main content area;
   - `.ultraThinMaterial` only for card/header accents.
4. Add an accessibility fallback to an adaptive control/window background
   when reduce transparency or increased contrast requires it.
5. Clip the content-area background and the `ScrollView` to the popover's
   corner shape.
6. Add an explicit tab-content container with a fixed full-area background,
   rather than allowing the selected view to define only its own card-sized
   height.
7. Use a stable `ZStack`/material layer during tab switches so inactive tab
   content is never mounted over the prior tab.

The header and navigation should remain translucent. The fix is only required
for the main content plane.

## Issue 2: Application Closing on Earbud Connection

### Verified crash evidence

A crash report exists at:

- [RealmeBudsController-2026-11-21-160018.ips](/Users/mubtasinprotik/Library/Logs/DiagnosticReports/RealmeBudsController-2026-11-21-160018.ips)

Key report details:

- Bundle: `com.mubtasin.RealmeBudsController`
- PID: `23270`
- Process: `RealmeBudsController`
- Exception: `EXC_BREAKPOINT` / `SIGTRAP`
- Termination: signal 5, Trace/BPT trap
- Triggered queue:
  `com.apple.bluetooth.iobluetooth.coordinatorQueue`
- Faulting frame:
  `@objc RealmeBluetoothService.handleDeviceConnectedNotification(_:device:)`
- This was not a normal application termination.

The crash stack is:

1. CoreBluetooth received the Bluetooth connection event.
2. IOBluetooth forwarded it on
   `com.apple.bluetooth.iobluetooth.coordinatorQueue`.
3. Swift hit `_dispatch_assert_queue_fail`.
4. Swift concurrency then trapped at
   `_swift_task_checkIsolatedSwift`.
5. The objective-C callback invoked
   `RealmeBluetoothService.handleDeviceConnectedNotification`.

This is a genuine process crash caused by an executor-isolation violation.

### Responsible callback

The callback is registered in:

- [RealmeBluetoothService.swift:51](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Bluetooth/RealmeBluetoothService.swift:51)
- [RealmeBluetoothService.swift:53](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Bluetooth/RealmeBluetoothService.swift:53)

The implementation is:

- [RealmeBluetoothService.swift:567](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Bluetooth/RealmeBluetoothService.swift:567)

`RealmeBluetoothService` is declared `@MainActor`:

- [RealmeBluetoothService.swift:3](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Bluetooth/RealmeBluetoothService.swift:3)

However, `handleDeviceConnectedNotification` is an Objective-C callback
registered with IOBluetooth and is executed from IOBluetooth's coordinator
queue. It directly invokes main-actor-isolated state and UI-adjacent code
instead of explicitly returning to `DispatchQueue.main`.

The same pattern exists for the disconnect callback:

- [RealmeBluetoothService.swift:587](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Bluetooth/RealmeBluetoothService.swift:587)

The RFCOMM and SDP callbacks also require actor review. The RFCOMM delegate
extension is marked `@MainActor`, but callbacks may arrive from an IOBluetooth
delegate queue. The current source should not assume that every callback will
inherit the main actor.

Relevant callbacks:

- [RealmeBluetoothService.swift:380](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Bluetooth/RealmeBluetoothService.swift:380)
- [RealmeBluetoothService.swift:504](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Bluetooth/RealmeBluetoothService.swift:504)
- [RealmeBluetoothService.swift:533](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Bluetooth/RealmeBluetoothService.swift:533)
- [RealmeBluetoothService.swift:547](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Bluetooth/RealmeBluetoothService.swift:547)

### Whether the process terminates

The crash report proves that process `23270` terminated due to
`EXC_BREAKPOINT`/`SIGTRAP`.

The user-visible disappearance can therefore be an actual application
process termination in this event. It is not only the popover closing.

The popover is separately allowed to close as normal macOS behavior. This is
controlled by:

- [StatusBarController.swift:33](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/App/StatusBarController.swift:33)
- [StatusBarController.swift:62](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/App/StatusBarController.swift:62)
- [StatusBarController.swift:67](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/App/StatusBarController.swift:67)

A transient popover normally closes when focus moves elsewhere. That behavior
does not terminate the menu-bar app. It must be distinguished from the
Bluetooth crash shown in the Diagnostic Report.

### Application lifecycle

The explicit quit button calls `NSApp.terminate(nil)`:

- [PopoverRootView.swift:94](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Views/PopoverRootView.swift:94)

There is no Bluetooth callback in the current source that calls `terminate`.
The Bluetooth disconnection handler only closes RFCOMM and updates state.

[AppDelegate.swift:36](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/App/AppDelegate.swift:36)
returns `false` when the last window closes, so closing a settings window or
popover is not intended to terminate the app.

The crash report, rather than lifecycle code, explains the observed process
termination.

### State and force unwrap risks

The Bluetooth callbacks use implicitly unwrapped Objective-C parameters and
some IOBluetooth APIs also expose implicitly unwrapped values. The callbacks
currently guard only the device callback parameter. The crash above occurs
before or independent of normal UI state mutation and is primarily actor
isolation.

Additional review areas:

- guard every callback before dereferencing channel/device pointers;
- move all `@Published` updates to `Task { @MainActor in ... }` or
  `DispatchQueue.main.async` for callbacks whose executor is unknown;
- stop using direct `AppState.shared` mutations inside non-main-actor callback
  bodies;
- add no-op or stale-callback guards for devices that are no longer active;
- retain strong references to notification/channel delegates as needed;
- keep the popover ownership in `StatusBarController` independent from
  Bluetooth callbacks.

### Proposed fix

For IOBluetooth and CoreBluetooth callbacks:

1. Mark Objective-C notification callback entry points with an explicit
   nonisolated boundary if supported by the deployed Swift syntax.
2. Capture notification/device values safely.
3. Dispatch once to `@MainActor`.
4. Perform device-name matching and `AppState.shared` mutations only on the
   main actor.
5. Route SDP and RFCOMM callbacks through the main actor before touching
   published state.
6. Keep raw Bluetooth/framework work, pointer access, and queue-specific
   operations in framework callbacks or dedicated serial queues.
7. Add explicit stale-notification guards.
8. Add a crash-proof disconnection path that only closes protocol state and
   schedules bounded reconnection.

The fix must preserve the existing architecture and menu-bar lifecycle. It
does not require changing `NSApplicationMain`, adding `NSApp.terminate`, or
replacing the IOBluetooth implementation.

## Additional diagnostics required

The following data should be collected after the actor fix is approved:

- both connect and disconnect crash reports;
- the callback queue name for each IOBluetooth/RFCOMM callback;
- application log timestamps around Bluetooth connect/disconnect;
- ACL link state and RFCOMM open/close status;
- SDP and RFCOMM channel values;
- the last action in `AppState` before the callback;
- process PID before and after a connection event;
- a popover close event separately from application exit.

A proposed diagnostic format should preserve a process/session identifier and
record:

1. callback name;
2. callback thread/queue;
3. actor boundary reached;
4. earbud name/address;
5. ACL state;
6. RFCOMM state;
7. popover state;
8. application process exit/termination state.

## Implemented Fixes

### Liquid Glass content stabilization

Updated [PopoverRootView.swift](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Views/PopoverRootView.swift)
to add:

- A dedicated full-height adaptive content background behind the active
  tab.
- `.regularMaterial` with adaptive light/dark overlaying.
- An opaque system window/control background fallback for reduce-transparency
  environments.
- A stable `ZStack` around the active `ScrollView`.
- Clipping of the content plane and scroll view to a rounded popover content
  shape.
- Full-width tab content inside the scroll view.

The translucent header, navigation, violet accents, and existing
`LiquidGlassCard` treatment remain in place.

Updated [OverviewSectionView.swift](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Views/Overview/OverviewSectionView.swift)
to reduce the temporary product placeholder case height from 142 points to
112 points and each isolated-bud image from 82x88 to 58x62 points. This
removes oversized empty visual areas without fabricating new product
imagery. The supplied source images remain placeholder assets.

### Bluetooth lifecycle isolation

Updated [RealmeBluetoothService.swift](/Users/mubtasinprotik/Desktop/RealmeBudsController/Sources/RealmeBudsController/Bluetooth/RealmeBluetoothService.swift)
to:

- Declare both IOBluetooth connect/disconnect notification entry points
  `nonisolated`.
- Dispatch callback work to `DispatchQueue.main`.
- Enter `MainActor.assumeIsolated` before mutating `AppState` or
  `RealmeBluetoothService` state.
- Add duplicate SDP/RFCOMM guards.
- Reject duplicate RFCOMM open requests while connected or connecting.
- Preserve disconnection cleanup and close only the control channel.

No `NSApp.terminate` call was added to either Bluetooth callback. The explicit
quit button remains the only in-app termination action.

## Verification

- `./build.sh` completed successfully.
- Swift Package release build completed.
- `Realme Buds Controller.app` was rebuilt and ad-hoc signed.
- All three placeholder PNG resources were confirmed in the app bundle:
  `BudsAir7CaseOpen.png`, `BudsAir7Left.png`, and `BudsAir7Right.png`.
- `git diff --check` passed.
- The app process remained running after launch.
- No new crash report appeared after the fixed launch.
- Bluetooth connect/disconnect hardware behavior still requires a physical
  Buds Air 7 run because the callback fix cannot be proven by compilation
  alone. The original crash report has been removed from runtime state by the
  implementation change, but it should be retained for comparison.
