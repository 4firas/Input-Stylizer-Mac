import SwiftUI

// MARK: - App Entry Point

/// The `@main` entry point for SystemWideStylizer.
///
/// This is a **menu bar agent app** — it has no main window and no Dock icon.
/// All UI is driven by the `AppDelegate` which manages the `NSStatusItem`
/// (menu bar icon) and an `NSPopover`.
///
/// The `Settings { EmptyView() }` scene is required to keep the SwiftUI app
/// lifecycle alive without presenting a visible window.
@main
struct SystemWideStylizerApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We don't use SwiftUI's built-in Settings scene for our settings window
        // because we manage it manually via NSWindow in the AppDelegate.
        // This empty Settings scene prevents SwiftUI from creating a default window.
        Settings {
            EmptyView()
        }
    }
}
