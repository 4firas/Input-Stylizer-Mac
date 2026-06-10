import SwiftUI

// MARK: - Settings View

/// Full settings window with all configuration options.
/// Opened from the popover's "Settings…" button.
struct SettingsView: View {

    @ObservedObject var settings: AppSettings

    /// Tracks whether Accessibility permissions are granted.
    @State private var hasPermission: Bool = AccessibilityHelper.isTrusted()

    /// Feedback message shown after testing the API connection.
    @State private var testResult: String?
    @State private var isTesting: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                titleSection
                    .padding(.bottom, 8)

                if !hasPermission {
                    PermissionBannerView()
                        .padding(.bottom, 8)
                }

                // General
                SettingsSectionCard("General") {
                    toggleSection
                }

                // Style Preset
                SettingsSectionCard("Style Preset") {
                    styleSection
                    Divider()
                        .padding(.vertical, 4)
                    promptSection
                }

                // API Connection
                SettingsSectionCard("API Connection") {
                    providerSection
                    Divider()
                        .padding(.vertical, 4)
                    authSection
                    Divider()
                        .padding(.vertical, 4)
                    modelSection
                }

                // Connection Test
                SettingsSectionCard("Connection Testing") {
                    testSection
                }

                // App Info
                SettingsSectionCard("App Info") {
                    aboutSection
                }
            }
            .padding(24)
        }
        .frame(width: 480, height: 680)
        .onAppear {
            hasPermission = AccessibilityHelper.isTrusted()
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SystemWideStylizer")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Settings")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "textformat.abc.dottedunderline")
                .font(.system(size: 28))
                .foregroundStyle(.secondary.opacity(0.5))
        }
    }

    // MARK: - Toggle

    private var toggleSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Enable Stylizer")
                    .font(.system(size: 13, weight: .semibold))
                Text("When enabled, pressing Return in any text field will stylize your text before sending.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $settings.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    // MARK: - Provider

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API Provider")
                .font(.system(size: 13, weight: .semibold))

            Picker("Provider", selection: $settings.currentProvider) {
                ForEach(Provider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Show the resolved endpoint URL
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                if settings.currentProvider == .custom {
                    TextField("https://your-api.example.com/v1", text: $settings.customEndpointURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                } else {
                    Text(settings.currentProvider.defaultBaseURL)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Auth

    private var authSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API Key")
                .font(.system(size: 13, weight: .semibold))

            if settings.currentProvider.requiresAPIKey {
                SecureField("sk-...", text: $settings.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))

                Text("Your API key is stored locally in UserDefaults and never sent anywhere except the configured endpoint.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 12))
                    Text("No API key required for \(settings.currentProvider.rawValue).")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Model

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model")
                .font(.system(size: 13, weight: .semibold))

            TextField("e.g. gpt-4o, local-model", text: $settings.targetModel)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))

            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("Leave blank to use the default: \(settings.currentProvider.defaultModel)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Style Preset

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Style Preset")
                .font(.system(size: 13, weight: .semibold))

            Picker("Style Preset", selection: $settings.selectedStyle) {
                ForEach(StylePreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            Text("Choose the style preset that SystemWideStylizer will use to rewrite your messages.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - System Prompt

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("System Prompt")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                if settings.selectedStyle == .custom {
                    Button("Reset to Default") {
                        settings.customSystemPrompt = """
                            You are a text translator. Rewrite the user's message in your own unique style. \
                            Output ONLY the translated text. Do not include any explanations, markdown formatting, \
                            code blocks, quotation marks, or conversational filler. \
                            Return nothing but the rewritten message.
                            """
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(.blue)
                } else {
                    Text("Read-Only (Preset: \(settings.selectedStyle.shortName))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            if settings.selectedStyle == .custom {
                TextEditor(text: $settings.customSystemPrompt)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    )
            } else {
                ScrollView {
                    Text(settings.effectiveSystemPrompt)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 100)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }

            Text(settings.selectedStyle == .custom
                 ? "This custom prompt instructs the AI how to transform your text. The model must output ONLY the rewritten text with no extra formatting."
                 : "This preset prompt is configured to rewrite your text in the \(settings.selectedStyle.shortName) style.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Test Connection

    private var testSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Test Connection")
                .font(.system(size: 13, weight: .semibold))

            HStack {
                Button {
                    runConnectionTest()
                } label: {
                    HStack(spacing: 4) {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 11))
                        }
                        Text(isTesting ? "Testing…" : "Test API Connection")
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(isTesting)

                if let result = testResult {
                    Text(result)
                        .font(.system(size: 11))
                        .foregroundStyle(result.contains("✓") ? .green : .red)
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("About")
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 8) {
                Text("v1.0.0")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text("·")
                    .foregroundStyle(.secondary)

                Button("Accessibility Settings") {
                    AccessibilityHelper.openAccessibilitySettings()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.blue)
            }
        }
    }

    // MARK: - Actions

    private func runConnectionTest() {
        isTesting = true
        testResult = nil

        Task {
            do {
                let client = APIClient()
                let result = try await client.stylize(text: "Hello, this is a test.", settings: settings)
                await MainActor.run {
                    testResult = "✓ Success: \"\(result.prefix(60))…\""
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = "✗ \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }
}

// MARK: - Settings Section Card

struct SettingsSectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


