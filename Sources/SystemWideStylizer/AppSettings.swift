import Foundation
import SwiftUI

// MARK: - Provider Enum

/// Pre-configured API provider profiles. All conform to the OpenAI-compatible
/// `/v1/chat/completions` endpoint structure.
enum Provider: String, CaseIterable, Identifiable {
    case lmStudio   = "LM Studio"
    case openRouter  = "OpenRouter"
    case openAI      = "OpenAI"
    case opencodeGo  = "OpenCode Go"
    case custom      = "Custom"

    var id: String { rawValue }

    /// Default base URL for each provider (without trailing `/v1/chat/completions`).
    var defaultBaseURL: String {
        switch self {
        case .lmStudio:   return "http://localhost:1234/v1"
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .openAI:     return "https://api.openai.com/v1"
        case .opencodeGo: return "https://opencode.ai/zen/go/v1"
        case .custom:     return ""
        }
    }

    /// Sensible default model identifier per provider.
    var defaultModel: String {
        switch self {
        case .lmStudio:   return "local-model"
        case .openRouter: return "openai/gpt-4o"
        case .openAI:     return "gpt-4o"
        case .opencodeGo: return "deepseek-v4-flash"
        case .custom:     return ""
        }
    }

    /// Whether this provider typically requires an API key.
    var requiresAPIKey: Bool {
        switch self {
        case .lmStudio: return false
        default:        return true
        }
    }

    /// Pre-defined model list for providers with known model sets.
    /// Empty array means free-form text entry.
    var modelList: [String] {
        switch self {
        case .opencodeGo:
            return [
                "deepseek-v4-flash",
                "deepseek-v4-pro",
                "kimi-k2.6",
                "kimi-k2.5",
                "glm-5",
                "glm-5.1",
                "mimo-v2-pro",
                "mimo-v2-omni",
                "mimo-v2.5",
                "mimo-v2.5-pro",
                "minimax-m2.5",
                "minimax-m2.7",
                "minimax-m3",
                "qwen3.5-plus",
                "qwen3.6-plus",
                "qwen3.7-plus",
                "qwen3.7-max",
                "hy3-preview",
            ]
        default:
            return []
        }
    }
}

// MARK: - Style Preset Enum

/// 13 built-in text style profiles + a Custom slot for user-defined prompts.
/// Each case maps to a rigid system prompt that forces the AI model to rewrite
/// the input text *only* in that style, with zero commentary or formatting.
enum StylePreset: String, CaseIterable, Identifiable {
    case grammar            = "✍️ Grammar & Punctuation"
    case charisma           = "✨ Low-Key Charisma"
    case wit                = "😏 Casual Wit"
    case shakespearean      = "🎭 Shakespearean"
    case pirate             = "🏴‍☠️ High Seas Pirate"
    case genZ               = "💀 Gen Z / Brain-Rot"
    case victorian          = "🎩 Victorian Aristocrat"
    case cyberpunk          = "🌃 Cyberpunk Netrunner"
    case southern           = "🤠 Southern Drawl"
    case academic           = "📚 Hyper-Academic"
    case corporate          = "💼 Corporate Bureaucrat"
    case yoda               = "🟢 Yoda Inversion"
    case noir               = "🕵️ 1940s Noir Detective"
    case custom             = "✏️ Custom Prompt"

    var id: String { rawValue }

    /// A short name without the emoji prefix, used in compact UI contexts.
    var shortName: String {
        switch self {
        case .grammar:       return "Grammar"
        case .charisma:      return "Charisma"
        case .wit:           return "Wit"
        case .shakespearean: return "Shakespearean"
        case .pirate:        return "Pirate"
        case .genZ:          return "Gen Z"
        case .victorian:     return "Victorian"
        case .cyberpunk:     return "Cyberpunk"
        case .southern:      return "Southern"
        case .academic:      return "Academic"
        case .corporate:     return "Corporate"
        case .yoda:          return "Yoda"
        case .noir:          return "Noir"
        case .custom:        return "Custom"
        }
    }

    /// The rigid system prompt for this style. Every prompt enforces that the model
    /// outputs *only* the rewritten text — no markdown, no quotes, no explanations.
    ///
    /// The `.custom` case returns an empty string; the app uses the user's
    /// `customSystemPrompt` from `AppSettings` instead.
    var systemPrompt: String {
        switch self {

        case .grammar:
            return """
            You are a text corrector. Fix spelling, grammatical errors, typos, and punctuation in the user's message.
            CRITICAL REQUIREMENTS:
            - DO NOT change the user's tone, style, or wording. Maintain the casual or formal nature of the original text.
            - DO NOT capitalize the first letter of the message or the first letters of sentences. Keep all text in lowercase.
            - DO NOT use any emojis.
            - DO NOT use em-dashes (—).
            - Output ONLY the corrected text. Do not include any explanations, introduction, quotes, or conversational filler.
            """

        case .charisma:
            return """
            You are a text enhancer. Rewrite the user's message to sound slightly more confident, persuasive, and engaging, while keeping the original casual tone and exact meaning.
            CRITICAL REQUIREMENTS:
            - Keep it extremely natural and human. It must not sound like AI, marketing copy, or an email.
            - DO NOT capitalize the first letter of the message or the first letters of sentences. Keep all text in lowercase.
            - DO NOT use any emojis.
            - DO NOT use em-dashes (—).
            - Output ONLY the enhanced text. Do not include any explanations, introduction, quotes, or conversational filler.
            """

        case .wit:
            return """
            You are a text transformer. Rewrite the user's message to add a touch of casual intelligence and dry, understated wit.
            CRITICAL REQUIREMENTS:
            - Keep the core meaning, but reframe it with a dry, humorous, or clever perspective. Make it sound like a real person, not an AI trying to make a joke.
            - DO NOT capitalize the first letter of the message or the first letters of sentences. Keep all text in lowercase.
            - DO NOT use any emojis.
            - DO NOT use em-dashes (—).
            - Output ONLY the transformed text. Do not include any explanations, introduction, quotes, or conversational filler.
            """

        case .shakespearean:
            return """
            You are a text translator specializing in Early Modern English. Rewrite the user's message using authentic 16th-17th century grammar, pronouns (thou, thee, thy, ye), and verb inflections (e.g., -est, -eth). Make it sound like natural period dialogue, rather than just inserting random archaic words. Maintain the original emotional resonance and meaning. Do not write a summary or use introductory phrases. Output ONLY the translated text, with no quotes, markdown, or commentary.
            """

        case .pirate:
            return """
            You are a text translator. Rewrite the user's message in the voice of a seasoned 18th-century pirate. Use authentic maritime phrasing, phonetic slang (e.g., "me" instead of "my", "ye" instead of "you"), and drop g's on "-ing" verbs (e.g., "sailin'"). Avoid childish caricature clichés and instead focus on grit, dry humor, and natural phrasing. Output ONLY the translated text, with no quotes, markdown, or commentary.
            """

        case .genZ:
            return """
            You are a text translator. Rewrite the message in a natural, casual modern internet/Gen Z dialect. Keep all letters strictly lowercase. Use contemporary slang organically (e.g., "lowkey", "fr", "real", "bruh", "ngl", "slay", "bet", "no cap") rather than forcing brain-rot terms. Include a couple of realistic emojis (like 💀, 😭, or 💀😭) if they fit the emotional tone, but keep it looking like a real message sent by a human. Output ONLY the translated text, with no quotes, markdown, or commentary.
            """

        case .victorian:
            return """
            You are a text translator. Rewrite the user's message as a formal, elegant piece of 19th-century English correspondence. Use sophisticated vocabulary and structured phrasing. Avoid contractions, and write with polite restraint. Maintain the original message's intent exactly. Output ONLY the translated text, with no quotes, markdown, or commentary.
            """

        case .cyberpunk:
            return """
            You are a text translator. Rewrite the user's message in a gritty, street-smart cyberpunk slang. Incorporate technological and street vernacular (e.g., "flatline", "choom", "chrome", "eddies", "corpo", "ICE") naturally into the phrasing. Keep the tone dry, cynical, and concise. Output ONLY the translated text, with no quotes, markdown, or commentary.
            """

        case .southern:
            return """
            You are a text translator. Rewrite the user's message in a natural Southern American dialect. Use phonetic spellings ("fixin' to", "reckon", "y'all") and drop g's from "-ing" endings. Focus on a warm, hospitable, and folksy tone without exaggerating it into a cartoon trope. Output ONLY the translated text, with no quotes, markdown, or commentary.
            """

        case .academic:
            return """
            You are a text translator. Rewrite the user's message using formal, precise, and sophisticated academic prose. Employ advanced vocabulary and structured argumentation, avoiding conversational filler or contractions. The style should read like a scholarly journal article, maintaining clarity and depth. Output ONLY the translated text, with no quotes, markdown, or commentary.
            """

        case .corporate:
            return """
            You are a text translator. Rewrite the user's message in standard, polished professional corporate correspondence. Use clear, office-appropriate vocabulary (e.g., "align", "touch base", "action item", "bandwidth") but keep it readable and realistic rather than a ridiculous caricature of jargon. Output ONLY the translated text, with no quotes, markdown, or commentary.
            """

        case .yoda:
            return """
            You are a text translator. Rewrite the user's message using Yoda's inverted grammatical structure (typically placing the object or complement before the subject and verb, e.g., "To the store, I must go"). Ensure the inverted structure reads naturally for Yoda's classic style rather than simple word scrambling. Output ONLY the translated text, with no quotes, markdown, or commentary.
            """

        case .noir:
            return """
            You are a text translator. Rewrite the user's message in the style of a hardboiled 1940s detective's internal monologue. Use sharp, dry similes and a world-weary, cynical perspective. Keep sentences short, punchy, and atmospheric. Output ONLY the translated text, with no quotes, markdown, or commentary.
            """

        case .custom:
            // Custom mode uses the user's `customSystemPrompt` from AppSettings directly.
            return ""
        }
    }
}

// MARK: - App Settings

/// Centralized, observable settings store. All values are persisted to UserDefaults
/// via `@AppStorage` so they survive app restarts.
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    // MARK: Global Toggle

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "isEnabled") }
    }

    // MARK: Style Selection

    @Published var selectedStyle: StylePreset {
        didSet { UserDefaults.standard.set(selectedStyle.rawValue, forKey: "selectedStyle") }
    }

    // MARK: Provider Configuration

    @Published var currentProvider: Provider {
        didSet { UserDefaults.standard.set(currentProvider.rawValue, forKey: "currentProvider") }
    }

    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "apiKey") }
    }

    @Published var targetModel: String {
        didSet { UserDefaults.standard.set(targetModel, forKey: "targetModel") }
    }

    @Published var customEndpointURL: String {
        didSet { UserDefaults.standard.set(customEndpointURL, forKey: "customEndpointURL") }
    }

    // MARK: Custom System Prompt

    @Published var customSystemPrompt: String {
        didSet { UserDefaults.standard.set(customSystemPrompt, forKey: "customSystemPrompt") }
    }

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "isEnabled")

        if let styleRaw = UserDefaults.standard.string(forKey: "selectedStyle"),
           let style = StylePreset(rawValue: styleRaw) {
            self.selectedStyle = style
        } else {
            self.selectedStyle = .grammar
        }

        if let providerRaw = UserDefaults.standard.string(forKey: "currentProvider"),
           let provider = Provider(rawValue: providerRaw) {
            self.currentProvider = provider
        } else {
            self.currentProvider = .lmStudio
        }

        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.targetModel = UserDefaults.standard.string(forKey: "targetModel") ?? ""
        self.customEndpointURL = UserDefaults.standard.string(forKey: "customEndpointURL") ?? ""

        self.customSystemPrompt = UserDefaults.standard.string(forKey: "customSystemPrompt") ?? """
        You are a text translator. Rewrite the user's message in your own unique style. \
        Output ONLY the translated text. Do not include any explanations, markdown formatting, \
        code blocks, quotation marks, or conversational filler. \
        Return nothing but the rewritten message.
        """
    }

    // MARK: Computed Helpers

    /// The effective system prompt resolved from the selected style.
    /// If the selected style is `.custom`, falls back to `customSystemPrompt`.
    var effectiveSystemPrompt: String {
        if selectedStyle == .custom {
            return customSystemPrompt
        }
        return selectedStyle.systemPrompt
    }

    /// The effective base URL, resolved from the current provider or the custom override.
    var effectiveBaseURL: URL? {
        let raw: String
        if currentProvider == .custom {
            raw = customEndpointURL
        } else {
            raw = currentProvider.defaultBaseURL
        }
        // Strip trailing slashes for consistent joining
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return URL(string: trimmed)
    }

    /// The effective model string, falling back to the provider's default.
    var effectiveModel: String {
        let model = targetModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.isEmpty ? currentProvider.defaultModel : model
    }
}
