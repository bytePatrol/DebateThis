import SwiftUI

// Maps model providers to visual identity: icon, color, label.

enum ProviderTheme {
    static func icon(for provider: String) -> String {
        switch provider.lowercased() {
        case "anthropic": return "brain.head.profile"
        case "openai": return "sparkle"
        case "google": return "globe"
        case "deepseek": return "water.waves"
        case "meta": return "atom"
        case "mistral", "mistralai": return "wind"
        case "cohere": return "arrow.triangle.branch"
        default: return "cpu"
        }
    }

    static func color(for provider: String) -> Color {
        switch provider.lowercased() {
        case "anthropic": return Color(red: 0.85, green: 0.55, blue: 0.35)
        case "openai": return Color(red: 0.0, green: 0.65, blue: 0.55)
        case "google": return Color(red: 0.25, green: 0.52, blue: 0.96)
        case "deepseek": return Color(red: 0.3, green: 0.5, blue: 0.9)
        case "meta": return Color(red: 0.0, green: 0.47, blue: 0.95)
        case "mistral", "mistralai": return Color(red: 1.0, green: 0.45, blue: 0.0)
        case "cohere": return Color(red: 0.4, green: 0.2, blue: 0.8)
        default: return .secondary
        }
    }

    static func label(for modelId: String) -> String {
        modelId.components(separatedBy: "/").first?.capitalized ?? "Unknown"
    }
}
