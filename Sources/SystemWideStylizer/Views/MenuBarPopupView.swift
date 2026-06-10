import SwiftUI

// MARK: - Menu Bar Popup View

/// The compact popover UI shown when clicking the menu bar icon.
/// Provides a quick toggle, provider indicator, and access to full settings.
struct MenuBarPopupView: View {

    @ObservedObject var settings: AppSettings

    /// Callback to open the full Settings window.
    var onOpenSettings: () -> Void

    /// Callback to quit the application.
    var onQuit: () -> Void

    /// Tracks whether Accessibility permissions are granted.
    @State private var hasPermission: Bool = AccessibilityHelper.isTrusted()

    /// Timer to re-check permission status periodically.
    private let permissionTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ──
            headerSection
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 12)

            // ── Permission Banner (conditional) ──
            if !hasPermission {
                PermissionBannerView()
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // ── Controls ──
            controlsSection
                .padding(.horizontal, 16)
                .padding(.top, 12)

            Divider()
                .padding(.horizontal, 12)
                .padding(.top, 12)

            // ── Footer ──
            footerSection
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 300)
        .onReceive(permissionTimer) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                hasPermission = AccessibilityHelper.isTrusted()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SystemWideStylizer")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(settings.isEnabled && hasPermission ? Color.green : Color.red.opacity(0.7))
                        .frame(width: 7, height: 7)
                        .shadow(
                            color: settings.isEnabled && hasPermission
                                ? Color.green.opacity(0.6)
                                : Color.clear,
                            radius: 4
                        )

                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Quick toggle
            Toggle("", isOn: $settings.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
                .disabled(!hasPermission)
        }
    }

    private var statusText: String {
        if !hasPermission {
            return "Permission Required"
        }
        return settings.isEnabled ? "Active" : "Paused"
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(spacing: 12) {
            // Pickers grouped in a clean card
            VStack(spacing: 12) {
                // Style Preset picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Style Preset")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    Picker("", selection: $settings.selectedStyle) {
                        ForEach(StylePreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Provider picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Provider")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    Picker("", selection: $settings.currentProvider) {
                        ForEach(Provider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            
            // Stats grouped in a clean list
            VStack(spacing: 8) {
                HStack {
                    Text("Model")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(settings.effectiveModel)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                HStack {
                    Text("Endpoint")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(settings.effectiveBaseURL?.host() ?? "—")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button {
                onOpenSettings()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gear")
                        .font(.system(size: 11))
                    Text("Settings…")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary.opacity(0.7))

            Spacer()

            Button {
                onQuit()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 11))
                    Text("Quit")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red.opacity(0.8))
        }
    }
}


