import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce application appearance
        AppearanceManager.shared.applyAppearance()

        // Initialize Menu Bar controller
        statusBarController = StatusBarController()

        print("[RealmeBudsController] Application initialized successfully.")
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in background menu bar even if settings window is closed
        return false
    }
}
