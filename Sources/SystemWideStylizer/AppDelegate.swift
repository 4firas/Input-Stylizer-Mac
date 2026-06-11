import Cocoa
import SwiftUI
import Combine

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

    /// Permission polling timer — kept as property so we can restart it.
    private weak var permissionTimer: Timer?
    private var settingsCancellable: AnyCancellable?

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force the app to be a background accessory (no Dock icon, no app menu focus).
        NSApp.setActivationPolicy(.accessory)

        setupPopover()
        setupStatusItem()
        setupEventTap()

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

        button.image = NSImage(systemSymbolName: "textformat.abc.dottedunderline", accessibilityDescription: "SystemWideStylizer")
        button.action = #selector(togglePopover(_:))
        button.target = self

        updateStatusItemIcon(isEnabled: settings.isEnabled)

        settingsCancellable = settings.$isEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.updateStatusItemIcon(isEnabled: isEnabled)
            }
    }

    private func updateStatusItemIcon(isEnabled: Bool? = nil) {
        guard let button = statusItem?.button else { return }
        let enabled = isEnabled ?? settings.isEnabled

        if enabled && AccessibilityHelper.isTrusted() {
            button.contentTintColor = NSColor.controlAccentColor
        } else {
            button.contentTintColor = nil
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

        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    // MARK: - Event Tap

    /// Creates the manager and attempts to start the tap.
    /// If permission is not yet granted, polls until it is — and keeps polling
    /// so the tap is re-created if permission is ever revoked and re-granted.
    private func setupEventTap() {
        eventTapManager = EventTapManager(settings: settings)
        tryStartOrPollPermission()
    }

    private var wasTrusted = false

    private func tryStartOrPollPermission() {
        permissionTimer?.invalidate()

        wasTrusted = AccessibilityHelper.isTrusted()
        if wasTrusted {
            let started = eventTapManager?.start() ?? false
            if started {
                updateStatusItemIcon(isEnabled: settings.isEnabled)
                print("[AppDelegate] Event tap started.")
            }
        }

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let isTrusted = AccessibilityHelper.isTrusted()
            if isTrusted != self.wasTrusted {
                self.wasTrusted = isTrusted
                if isTrusted {
                    let started = self.eventTapManager?.start() ?? false
                    if started {
                        self.updateStatusItemIcon(isEnabled: self.settings.isEnabled)
                    }
                } else {
                    self.eventTapManager?.stop()
                    self.updateStatusItemIcon(isEnabled: self.settings.isEnabled)
                }
            }
        }
    }
}
