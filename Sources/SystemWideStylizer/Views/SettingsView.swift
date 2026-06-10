import SwiftUI

// MARK: - Settings View State

@MainActor
final class SettingsViewState: ObservableObject {
    @Published var hasPermission: Bool = AccessibilityHelper.isTrusted()
    @Published var testResult: String?
    @Published var isTesting: Bool = false
}

// MARK: - Settings View

struct SettingsView: View {

    @ObservedObject var settings: AppSettings
    @StateObject private var viewState = SettingsViewState()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                if !viewState.hasPermission {
                    PermissionBannerView()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }

                Form {
                    Section {
                        enableToggle
                    } header: {
                        Label("General", systemImage: "switch.2")
                    }

                    Section {
                        stylePicker
                        promptSection
                    } header: {
                        Label("Style Preset", systemImage: "pencil.tip")
                    }

                    Section {
                        providerPicker
                        endpointField
                    } header: {
                        Label("API Connection", systemImage: "antenna.radiowaves.left.and.right")
                    }

                    Section {
                        apiKeyField
                    } header: {
                        Label("Authentication", systemImage: "key.fill")
                    }

                    Section {
                        modelField
                    } header: {
                        Label("Model", systemImage: "cpu")
                    }

                    Section {
                        testButton
                    } header: {
                        Label("Connection Test", systemImage: "network")
                    }

                    Section {
                        aboutSection
                    } header: {
                        Label("About", systemImage: "info.circle")
                    }
                }
                .formStyle(.grouped)
            }
        }
        .frame(width: 480, height: 640)
        .onAppear { viewState.hasPermission = AccessibilityHelper.isTrusted() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "textformat.abc.dottedunderline")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color(.controlAccentColor))

            VStack(alignment: .leading, spacing: 1) {
                Text("SystemWideStylizer")
                    .font(.system(size: 15, weight: .semibold))
                Text("Rewrite your messages with AI, system-wide")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.bottom, 4)
    }

    // MARK: - General

    private var enableToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Enable Stylizer")
                Text("Pressing Return will stylize your text before sending.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $settings.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(!viewState.hasPermission)
        }
    }

    // MARK: - Style

    private var stylePicker: some View {
        HStack {
            Text("Preset")
            Spacer()
            Picker("", selection: $settings.selectedStyle) {
                ForEach(StylePreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 220)
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("System Prompt")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))

                Spacer()

                if settings.selectedStyle == .custom {
                    Button("Reset") {
                        settings.customSystemPrompt = Self.defaultCustomPrompt
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(.controlAccentColor))
                } else {
                    Text("Read-only")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            if settings.selectedStyle == .custom {
                TextEditor(text: $settings.customSystemPrompt)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(.separatorColor), lineWidth: 0.5)
                    )
            } else {
                ScrollView {
                    Text(settings.effectiveSystemPrompt)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(height: 80)
                .background(Color(.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.separatorColor), lineWidth: 0.5)
                )
            }
        }
    }

    private static let defaultCustomPrompt = """
        You are a text translator. Rewrite the user's message in your own unique style. \
        Output ONLY the translated text. Do not include any explanations, markdown formatting, \
        code blocks, quotation marks, or conversational filler. \
        Return nothing but the rewritten message.
        """

    // MARK: - API

    private var providerPicker: some View {
        HStack {
            Text("Provider")
            Spacer()
            Picker("", selection: $settings.currentProvider) {
                ForEach(Provider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 340)
        }
    }

    private var endpointField: some View {
        HStack {
            Text("Endpoint")
                .foregroundStyle(.secondary)
            Spacer()
            if settings.currentProvider == .custom {
                TextField("https://your-api.example.com/v1", text: $settings.customEndpointURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 260)
            } else {
                Text(settings.currentProvider.defaultBaseURL)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var apiKeyField: some View {
        Group {
            if settings.currentProvider.requiresAPIKey {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("API Key")
                        Text("Stored locally in UserDefaults.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    SecureField("sk-...", text: $settings.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 200)
                }
            } else {
                HStack {
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

    private var modelField: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Model")
                Text(modelHelpText)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if !settings.currentProvider.modelList.isEmpty {
                Picker("", selection: $settings.targetModel) {
                    Text("(Default: \(settings.currentProvider.defaultModel))").tag("")
                    Divider()
                    ForEach(settings.currentProvider.modelList, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 220)
            } else {
                TextField("e.g. \(settings.currentProvider.defaultModel)", text: $settings.targetModel)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 200)
            }
        }
    }

    private var modelHelpText: String {
        if settings.currentProvider.modelList.isEmpty {
            return "Leave blank for default: \(settings.currentProvider.defaultModel)"
        } else {
            return "Select a model for \(settings.currentProvider.rawValue)"
        }
    }

    // MARK: - Test

    private var testButton: some View {
        HStack {
            Button {
                runConnectionTest()
            } label: {
                Label("Test API Connection", systemImage: "network")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(viewState.isTesting)

            if viewState.isTesting {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 4)
            }

            if let result = viewState.testResult {
                Text(result)
                    .font(.system(size: 11))
                    .foregroundStyle(result.contains("✓") ? .green : .red)
                    .lineLimit(2)
                    .padding(.leading, 8)
            }

            Spacer()
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            infoRow("Version", "1.0.0")
            infoRow("Swift", "6.4")

            Button("Open Accessibility Settings") {
                AccessibilityHelper.openAccessibilitySettings()
            }
            .buttonStyle(.link)
            .font(.system(size: 11))
            .padding(.top, 4)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .font(.system(size: 11))
            Spacer()
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Actions

    private func runConnectionTest() {
        viewState.isTesting = true
        viewState.testResult = nil

        Task {
            do {
                let client = APIClient()
                let result = try await client.stylize(text: "Hello, this is a test.", settings: settings)
                await MainActor.run {
                    viewState.testResult = "✓ \"\(result.prefix(60))…\""
                    viewState.isTesting = false
                }
            } catch {
                await MainActor.run {
                    viewState.testResult = "✗ \(error.localizedDescription)"
                    viewState.isTesting = false
                }
            }
        }
    }
}
