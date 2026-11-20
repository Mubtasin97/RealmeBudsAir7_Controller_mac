import AppKit
import SwiftUI

@MainActor
public final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?

    public override init() {
        super.init()
        setupStatusItem()
        setupPopover()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            let image = NSImage(systemSymbolName: "headphones", accessibilityDescription: "Realme Buds Air 7")?
                .withSymbolConfiguration(config)
            image?.isTemplate = true
            button.image = image
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 330, height: 490)
        popover.behavior = .transient
        popover.animates = true

        let rootView = PopoverRootView { [weak self] in
            self?.closePopover()
            WindowManager.shared.openSettingsWindow(appState: AppState.shared)
        }

        popover.contentViewController = NSHostingController(rootView: rootView)
    }

    @objc public func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    public func showPopover() {
        guard let button = statusItem.button else { return }

        // Refresh popover appearance
        AppearanceManager.shared.applyAppearance()

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        startEventMonitoring()
    }

    public func closePopover() {
        popover.performClose(nil)
        stopEventMonitoring()
    }

    private func startEventMonitoring() {
        stopEventMonitoring()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func stopEventMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
