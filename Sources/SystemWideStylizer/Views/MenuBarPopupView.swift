import Combine
import SwiftUI

// MARK: - Popup View State

@MainActor
final class PopupViewState: ObservableObject {
    @Published var hasPermission: Bool = AccessibilityHelper.isTrusted()
}

// MARK: - Menu Bar Popup View

/// The compact popover UI shown when clicking the menu bar icon.
struct MenuBarPopupView: View {

    @ObservedObject var settings: AppSettings
    var onOpenSettings: () -> Void
    var onQuit: () -> Void

    @StateObject private var viewState = PopupViewState()

    private let permissionPublisher = DistributedNotificationCenter.default().publisher(for: NSNotification.Name("com.apple.accessibility.api"))

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
                .padding(EdgeInsets(top: 14, leading: 14, bottom: 10, trailing: 14))

            Divider()

            if !viewState.hasPermission {
                PermissionBannerView()
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .transition(.opacity)
            }

            // Controls
            controlsSection
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 10, trailing: 14))

            Divider()
                .padding(.horizontal, 10)

            // Footer
            footerSection
                .padding(EdgeInsets(top: 8, leading: 14, bottom: 10, trailing: 14))
        }
        .frame(width: 300)
        .onReceive(permissionPublisher) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                viewState.hasPermission = AccessibilityHelper.isTrusted()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "textformat.abc.dottedunderline")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(settings.isEnabled && viewState.hasPermission
                    ? Color(.controlAccentColor)
                    : .secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text("SystemWideStylizer")
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 5) {
                    DotView(color: statusColor, size: 7)
                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: $settings.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
                .disabled(!viewState.hasPermission)
        }
    }

    private var statusText: String {
        if !viewState.hasPermission { return "Permission Required" }
        return settings.isEnabled ? "Active" : "Paused"
    }

    private var statusColor: Color {
        if !viewState.hasPermission { return .orange }
        return settings.isEnabled ? .green : .secondary
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(spacing: 10) {
            controlRow(
                icon: "pencil.tip",
                label: "Style",
                control: AnyView(
                    Picker("", selection: $settings.selectedStyle) {
                        ForEach(StylePreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(maxWidth: 150, alignment: .trailing)
                )
            )

            Divider()
                .padding(.leading, 26)

            controlRow(
                icon: "antenna.radiowaves.left.and.right",
                label: "Provider",
                control: AnyView(
                    Picker("", selection: $settings.currentProvider) {
                        ForEach(Provider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(maxWidth: 150, alignment: .trailing)
                )
            )

            Divider()
                .padding(.leading, 26)

            controlRow(
                icon: "cpu",
                label: "Model",
                control: AnyView(
                    Text(settings.effectiveModel)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 150, alignment: .trailing)
                )
            )

            controlRow(
                icon: "link",
                label: "Endpoint",
                control: AnyView(
                    Text(settings.effectiveBaseURL?.host() ?? "—")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 150, alignment: .trailing)
                )
            )
        }
        .padding(10)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func controlRow(icon: String, label: String, control: AnyView) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.primary)

            Spacer()

            control
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 12) {
            Button(action: onOpenSettings) {
                Label("Settings…", systemImage: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(.controlAccentColor))

            Spacer()

            Button(action: onQuit) {
                Label("Quit", systemImage: "power")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Dot View

private struct DotView: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.4), radius: 2)
    }
}
