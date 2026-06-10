import Cocoa
import SwiftUI

// MARK: - App Delegate

/// Manages the NSStatusItem (menu bar icon), NSPopover, and the EventTapManager lifecycle.
/// Uses `@NSApplicationDelegateAdaptor` so SwiftUI can delegate AppKit duties here.
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    // MARK: - Properties

    /// The persistent menu bar icon.
    private var statusItem: NSStatusItem?

    /// The popover shown when clicking the menu bar icon.
    private let popover = NSPopover()

    /// The global keyboard event tap.
    private var eventTapManager: EventTapManager?

    /// Reference to the dedicated settings window.
    private var settingsWindow: NSWindow?

    /// Shared settings.
    private let settings = AppSettings.shared

    /// Monitor for clicks outside the popover (to dismiss it).
    private var outsideClickMonitor: Any?

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force the app to be a background accessory (no Dock icon, no app menu focus).
        NSApp.setActivationPolicy(.accessory)

        setupPopover()
        setupStatusItem()
        startEventTap()

        // Request Accessibility permission on first launch (shows system dialog).
        AccessibilityHelper.requestPermission()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventTapManager?.stop()
    }

    // MARK: - Status Item Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        // Use an SF Symbol that conveys "text transformation"
        button.image = NSImage(systemSymbolName: "textformat.abc.dottedunderline", accessibilityDescription: "SystemWideStylizer")
        button.action = #selector(togglePopover(_:))
        button.target = self

        // Update icon appearance based on enabled state
        updateStatusItemIcon()

        // Observe changes to isEnabled to update the icon dynamically
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc private func settingsDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusItemIcon()
        }
    }

    private func updateStatusItemIcon() {
        guard let button = statusItem?.button else { return }

        // Tint the icon to indicate active/inactive state.
        if settings.isEnabled && AccessibilityHelper.isTrusted() {
            button.contentTintColor = NSColor.controlAccentColor
        } else {
            button.contentTintColor = nil // default appearance
        }
    }

    // MARK: - Popover Setup

    private func setupPopover() {
        popover.contentSize = NSSize(width: 300, height: 360)
        popover.behavior = .transient
        popover.animates = true

        let popupView = MenuBarPopupView(
            settings: settings,
            onOpenSettings: { [weak self] in
                self?.popover.performClose(nil)
                self?.openSettingsWindow()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )

        popover.contentViewController = NSHostingController(rootView: popupView)
    }

    // MARK: - Popover Toggle

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // Install a global click monitor to close the popover when clicking outside.
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    private func closePopover() {
        popover.performClose(nil)

        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    // MARK: - Settings Window

    private func openSettingsWindow() {
        // If the window already exists, just bring it to front.
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(settings: settings)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "SystemWideStylizer Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 480, height: 640))
        window.minSize = NSSize(width: 400, height: 500)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        // Temporarily switch activation policy so the window can receive focus.
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    // MARK: - Event Tap

    private func startEventTap() {
        eventTapManager = EventTapManager(settings: settings)

        if AccessibilityHelper.isTrusted() {
            eventTapManager?.start()
        } else {
            // Poll for permission in the background and start the tap once granted.
            pollForAccessibilityPermission()
        }
    }

    /// Periodically checks if Accessibility permission has been granted, and starts
    /// the event tap as soon as it is.
    private func pollForAccessibilityPermission() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            if AccessibilityHelper.isTrusted() {
                timer.invalidate()
                self?.eventTapManager?.start()
                self?.updateStatusItemIcon()
                print("[AppDelegate] Accessibility permission granted — event tap started.")
            }
        }
    }
}
