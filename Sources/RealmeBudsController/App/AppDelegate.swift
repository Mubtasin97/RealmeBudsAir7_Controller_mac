import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var workspaceObservers: [NSObjectProtocol] = []

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce application-only appearance
        AppearanceManager.shared.applyAppearance()

        // Initialize Menu Bar controller
        statusBarController = StatusBarController()

        // Initialize Bluetooth Service & detect paired earbuds
        _ = RealmeBluetoothService.shared
        RealmeBluetoothService.shared.detectPairedBuds()
        if AppState.shared.autoConnectOnLaunch {
            RealmeBluetoothService.shared.discoverServicesAndConnect()
        }

        print("[RealmeBudsController] Application initialized successfully.")

        // Support CLI flags for automation and preview inspection
        if CommandLine.arguments.contains("--settings") {
            WindowManager.shared.openSettingsWindow(appState: AppState.shared)
        }

        if CommandLine.arguments.contains("--show-popover") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.statusBarController?.showPopover()
            }
        }

        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                RealmeBluetoothService.shared.handleSleep()
            }
        })
        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                RealmeBluetoothService.shared.handleWake()
            }
        })
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
