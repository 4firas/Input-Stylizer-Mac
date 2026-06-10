import Cocoa
import CoreGraphics
import Foundation

// MARK: - Event Tap Manager

/// Manages a system-wide CGEvent tap that intercepts Return key presses.
///
/// ## How the event tap works
///
/// 1. We install a **passive-turned-active** tap via `CGEvent.tapCreate` that listens
///    for `.keyDown` events at the session level.
/// 2. When the user presses Return (keycode 36), we **swallow** the event by returning
///    `nil` from the callback, extract the text from the focused element, send it to
///    the AI API, replace the text, and post a **synthetic** Return event.
/// 3. To prevent an **infinite recursive loop** (our synthetic Return being intercepted
///    again by our own tap), we tag synthetic events with a sentinel value in
///    `CGEventField.eventSourceUserData` (field 43). The callback checks this field
///    first and passes tagged events through immediately.
///
/// ## Thread model
///
/// - The CGEvent callback runs on whichever RunLoop the tap source is attached to
///   (we use `CFRunLoopGetMain()`).
/// - The async styling work (AX read → API call → AX write → synthetic keypress)
///   is dispatched onto a `Task` so it doesn't block the callback.
/// - AX calls are made from the main thread via `MainActor`.
///
final class EventTapManager {

    // MARK: - Constants

    /// Magic value written to `eventSourceUserData` on synthetic events.
    /// ASCII for "STYL" = 0x5354594C. The callback checks this to avoid re-entry.
    private static let syntheticEventTag: Int64 = 0x5354_594C

    /// macOS virtual keycode for Return / Enter.
    private static let returnKeyCode: Int64 = 36

    // MARK: - State

    /// Reference to the Mach port backing the event tap. Retained to allow enable/disable.
    private var eventTap: CFMachPort?

    /// RunLoop source for the event tap.
    private var runLoopSource: CFRunLoopSource?

    /// When `true`, an async styling operation is in flight. We pass through any
    /// additional Return presses while processing to avoid queuing up duplicates.
    private var isProcessing = false

    /// Shared settings reference.
    private let settings: AppSettings

    /// API client for stylization requests.
    private let apiClient = APIClient()

    // MARK: - Init

    init(settings: AppSettings) {
        self.settings = settings
    }

    deinit {
        stop()
    }

    // MARK: - Public API

    /// Installs and enables the global event tap.
    ///
    /// - Returns: `true` if the tap was created successfully. Returns `false` if
    ///   Accessibility permissions are missing (the most common failure cause).
    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true } // already running

        // We only care about keyDown events.
        let eventMask: CGEventMask = 1 << CGEventType.keyDown.rawValue

        // `refcon` carries a pointer to `self` so the C-compatible callback can
        // reach back into Swift-land.
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,       // active tap — can modify/swallow events
            eventsOfInterest: eventMask,
            callback: EventTapManager.eventTapCallback,
            userInfo: refcon
        ) else {
            // Most likely cause: Accessibility permission not granted.
            print("[EventTapManager] Failed to create event tap — check Accessibility permissions.")
            return false
        }

        eventTap = tap

        // Wire the tap into the main RunLoop so the callback fires on the main thread.
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("[EventTapManager] Event tap installed and enabled.")
        return true
    }

    /// Disables and removes the event tap.
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        print("[EventTapManager] Event tap stopped.")
    }

    // MARK: - C Callback (static)

    /// The C-compatible callback passed to `CGEvent.tapCreate`.
    ///
    /// This function is intentionally minimal — it checks flags, decides whether to
    /// swallow the event, and dispatches heavy work asynchronously.
    private static let eventTapCallback: CGEventTapCallBack = {
        (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in

        // Re-enable the tap if the OS disabled it (happens under heavy load).
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let refcon = refcon {
                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
                if let tap = manager.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
            return Unmanaged.passUnretained(event)
        }

        // Only process keyDown events.
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        // ─── Infinite-loop guard ───
        // If this event carries our sentinel in eventSourceUserData, it's one we
        // synthesized ourselves. Pass it through unconditionally.
        let userData = event.getIntegerValueField(.eventSourceUserData)
        if userData == EventTapManager.syntheticEventTag {
            return Unmanaged.passUnretained(event)
        }

        // Only intercept the Return key (keycode 36).
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == EventTapManager.returnKeyCode else {
            return Unmanaged.passUnretained(event)
        }

        // Retrieve the manager instance from refcon.
        guard let refcon = refcon else {
            return Unmanaged.passUnretained(event)
        }
        let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()

        // If styling is disabled globally, or we're already processing, let it through.
        guard manager.settings.isEnabled, !manager.isProcessing else {
            return Unmanaged.passUnretained(event)
        }

        // ─── Swallow the event and begin async styling ───
        manager.isProcessing = true

        // Capture the focused element (and text if possible) NOW on the main thread
        let axResult = AccessibilityHelper.getFocusedTextValue()
        let capturedElement = axResult?.element
        let capturedAXText = axResult?.text

        // Dispatch the async API call + text extraction/replacement pipeline
        Task { @MainActor in
            defer { manager.isProcessing = false }

            var targetText: String? = nil
            var usedAX = false

            // 1. Try to read text via Accessibility API first
            if let axText = capturedAXText, !axText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                targetText = axText
                usedAX = true
            }

            // 2. Fallback: Try to read text via clipboard copy simulation (for Discord/Slack/Chrome)
            if targetText == nil {
                print("[EventTapManager] AX read failed or empty; attempting clipboard copy fallback...")
                let pbBackup = PasteboardBackup.backup()
                
                // Clear clipboard text first to detect new copy
                NSPasteboard.general.clearContents()
                
                // Command + A (Select All)
                EventTapManager.postCommandKey(virtualKey: 0x00)
                try? await Task.sleep(for: .milliseconds(50))
                
                // Command + C (Copy)
                EventTapManager.postCommandKey(virtualKey: 0x08)
                try? await Task.sleep(for: .milliseconds(150)) // Wait for copy to register
                
                if let clipboardText = NSPasteboard.general.string(forType: .string),
                   !clipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    targetText = clipboardText
                }
                
                pbBackup.restore() // Restore user's clipboard immediately after reading
            }

            // 3. If we successfully extracted text, proceed with stylization and replacement
            if let textToStyle = targetText {
                do {
                    let styledText = try await manager.apiClient.stylize(
                        text: textToStyle,
                        settings: manager.settings
                    )

                    var writeSuccess = false

                    // Try writing via AX first if we read via AX
                    if usedAX, let element = capturedElement {
                        writeSuccess = AccessibilityHelper.setText(styledText, on: element)
                    }

                    // Fallback to Clipboard Paste writing if AX write failed or was skipped
                    if !writeSuccess {
                        print("[EventTapManager] AX write failed or skipped; attempting clipboard paste fallback...")
                        let pbBackup = PasteboardBackup.backup()
                        
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(styledText, forType: .string)
                        
                        // Command + A (Select All)
                        EventTapManager.postCommandKey(virtualKey: 0x00)
                        try? await Task.sleep(for: .milliseconds(50))
                        
                        // Command + V (Paste)
                        EventTapManager.postCommandKey(virtualKey: 0x09)
                        try? await Task.sleep(for: .milliseconds(150)) // Wait for paste to register
                        
                        EventTapManager.postSyntheticReturn()
                        
                        // Keep the clipboard for a brief moment before restoring it to allow pasting to complete
                        try? await Task.sleep(for: .milliseconds(200))
                        pbBackup.restore()
                    } else {
                        // AX write succeeded, send Return
                        EventTapManager.postSyntheticReturn()
                    }

                } catch {
                    print("[EventTapManager] Styling API failed: \(error.localizedDescription); sending original text.")
                    // API failed: just send the message as is
                    EventTapManager.postSyntheticReturn()
                }
            } else {
                print("[EventTapManager] No text could be extracted via AX or clipboard fallback.")
                // No text extracted: just let the Return key go through
                EventTapManager.postSyntheticReturn()
            }
        }

        // Return nil to swallow the original Return event.
        return nil
    }

    // MARK: - Synthetic Key Posting

    /// Posts a synthetic Return keyDown + keyUp pair, tagged with our sentinel so
    /// the event tap passes them through without re-triggering.
    private static func postSyntheticReturn() {
        let source = CGEventSource(stateID: .combinedSessionState)

        // Key down
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true) {
            keyDown.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
            keyDown.post(tap: .cgSessionEventTap)
        }

        // Key up
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false) {
            keyUp.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
            keyUp.post(tap: .cgSessionEventTap)
        }
    }

    /// Simulates pressing key combination Command + key
    private static func postCommandKey(virtualKey: CGKeyCode) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let cmdFlag = CGEventFlags.maskCommand

        // Key down
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true) {
            keyDown.flags = cmdFlag
            keyDown.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
            keyDown.post(tap: .cgSessionEventTap)
        }

        // Key up
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) {
            keyUp.flags = cmdFlag
            keyUp.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
            keyUp.post(tap: .cgSessionEventTap)
        }
    }
}

// MARK: - Pasteboard Backup Helper

private struct PasteboardBackup {
    let items: [NSPasteboardItem]?

    static func backup() -> PasteboardBackup {
        let pb = NSPasteboard.general
        guard let pbItems = pb.pasteboardItems else {
            return PasteboardBackup(items: nil)
        }
        let copies = pbItems.map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
        return PasteboardBackup(items: copies)
    }

    func restore() {
        guard let items = items else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(items)
    }
}
