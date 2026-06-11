import ApplicationServices
import Cocoa
import Foundation

// MARK: - Accessibility Helper

/// Provides safe, documented wrappers around the macOS Accessibility (AX) API.
///
/// All AX calls require the app to be trusted via System Settings → Privacy & Security
/// → Accessibility. Without trust, `tapCreate` returns `nil` and AX queries fail.
enum AccessibilityHelper {

    // MARK: Permission Checks

    /// Returns `true` if the current process has Accessibility trust.
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Checks trust and, if not granted, triggers the macOS system dialog that asks
    /// the user to enable Accessibility for this app.
    @discardableResult
    static func requestPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings directly to the Accessibility privacy pane.
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Focused Element Text Operations

    /// Reads the text value from the currently focused UI element system-wide.
    ///
    /// How it works:
    /// 1. `AXUIElementCreateSystemWide()` gives us a handle to the entire desktop.
    /// 2. We query `kAXFocusedUIElementAttribute` to find whatever control has keyboard focus
    ///    across *all* applications (Slack, iMessage, browser text fields, etc.).
    /// 3. We then read `kAXValueAttribute` from that element to get its text content.
    ///
    /// - Returns: A tuple of the AXUIElement (needed for writing back) and the text string,
    ///            or `nil` if any step fails (no focus, non-text element, permission denied).
    static func getFocusedTextValue() -> (element: AXUIElement, text: String)? {
        let systemWide = AXUIElementCreateSystemWide()

        // Step 1: Get the focused element
        var focusedRef: CFTypeRef?
        let focusErr = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )

        guard focusErr == .success, let element = focusedRef else {
            return nil
        }

        // Safely check the type ID to prevent crashes from misbehaving apps
        guard CFGetTypeID(element) == AXUIElementGetTypeID() else {
            return nil
        }
        let axElement = element as! AXUIElement

        // Step 2: Read the text value
        var valueRef: CFTypeRef?
        let valueErr = AXUIElementCopyAttributeValue(
            axElement,
            kAXValueAttribute as CFString,
            &valueRef
        )

        guard valueErr == .success, let value = valueRef as? String else {
            return nil
        }

        return (element: axElement, text: value)
    }

    /// Overwrites the text value of a specific AXUIElement.
    ///
    /// - Parameters:
    ///   - text: The new text to place into the element.
    ///   - element: The target AXUIElement (typically obtained from `getFocusedTextValue()`).
    /// - Returns: `true` if the AX API reported success. Note: some apps may acknowledge
    ///            the call but silently ignore it (web browsers occasionally do this).
    @discardableResult
    static func setText(_ text: String, on element: AXUIElement) -> Bool {
        // Verify the attribute is settable before writing
        var isSettable: DarwinBoolean = false
        let checkErr = AXUIElementIsAttributeSettable(
            element,
            kAXValueAttribute as CFString,
            &isSettable
        )

        guard checkErr == .success, isSettable.boolValue else {
            return false
        }

        let setErr = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            text as CFString
        )

        return setErr == .success
    }
}
