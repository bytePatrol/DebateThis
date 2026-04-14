import Foundation

// MARK: - Model Identifier

struct ModelIdentifier: Codable, Hashable, Identifiable {
    let id: String
    let displayName: String
    let provider: String
    var contextLength: Int?

    var shortName: String {
        displayName.isEmpty ? id : displayName
    }
}

// MARK: - Debate

struct Debate: Identifiable {
    let id: UUID
    let topic: String
    let modelA: ModelIdentifier
    let modelB: ModelIdentifier
    let judgeModel: ModelIdentifier
    let commentatorModel: ModelIdentifier?
    var rounds: [DebateRound]
    var verdict: Verdict?
    let createdAt: Date

    init(
        topic: String,
        modelA: ModelIdentifier,
        modelB: ModelIdentifier,
        judgeModel: ModelIdentifier,
        commentatorModel: ModelIdentifier? = nil
    ) {
        self.id = UUID()
        self.topic = topic
        self.modelA = modelA
        self.modelB = modelB
        self.judgeModel = judgeModel
        self.commentatorModel = commentatorModel
        self.rounds = []
        self.verdict = nil
        self.createdAt = Date()
    }
}

// MARK: - Round & Turn

struct DebateRound: Identifiable {
    let id: UUID
    let number: Int
    var turnA: Turn?
    var turnB: Turn?
    var commentary: String?

    init(number: Int) {
        self.id = UUID()
        self.number = number
    }
}

struct Turn: Identifiable {
    let id: UUID
    let model: ModelIdentifier
    var content: String
    let startedAt: Date
    var completedAt: Date?

    init(model: ModelIdentifier) {
        self.id = UUID()
        self.model = model
        self.content = ""
        self.startedAt = Date()
    }
}

// MARK: - Verdict

struct Verdict {
    let winner: ModelIdentifier
    let reasoning: String
    let scores: VerdictScores
}

struct VerdictScores {
    let modelAArgumentQuality: Int
    let modelAEvidence: Int
    let modelARhetoric: Int
    let modelAResponsiveness: Int
    let modelBArgumentQuality: Int
    let modelBEvidence: Int
    let modelBRhetoric: Int
    let modelBResponsiveness: Int
}

// MARK: - Debate State
//
// DebateEngine State Machine
//
//   idle
//    |
//    v
//   turnA(round: 1)
//    |
//    v
//   turnB(round: 1)
//    |
//    v
//   commenting(round: 1)
//    |
//    v
//   turnA(round: 2) ... (repeat for N rounds)
//    |
//    v (final round commenting complete)
//   judging
//    |
//    v
//   complete
//
//   ANY state --> error(message) [user can retry or reset]
//

enum DebateState: Equatable {
    case idle
    case turnA(round: Int)
    case turnB(round: Int)
    case commenting(round: Int)
    case judging
    case complete
    case error(message: String)

    var isActive: Bool {
        switch self {
        case .turnA, .turnB, .commenting, .judging:
            return true
        default:
            return false
        }
    }

    var currentRound: Int? {
        switch self {
        case .turnA(let r), .turnB(let r), .commenting(let r):
            return r
        default:
            return nil
        }
    }

    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .turnA(let round):
            return "Round \(round) — Model A arguing"
        case .turnB(let round):
            return "Round \(round) — Model B responding"
        case .commenting(let round):
            return "Round \(round) — Commentary"
        case .judging:
            return "Judge deliberating..."
        case .complete:
            return "Debate complete"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

// MARK: - Hardcoded Models

enum AvailableModels {
    static let all: [ModelIdentifier] = [
        ModelIdentifier(id: "anthropic/claude-sonnet-4", displayName: "Claude Sonnet 4", provider: "Anthropic", contextLength: 200_000),
        ModelIdentifier(id: "anthropic/claude-haiku-4", displayName: "Claude Haiku 4", provider: "Anthropic", contextLength: 200_000),
        ModelIdentifier(id: "openai/gpt-4o", displayName: "GPT-4o", provider: "OpenAI", contextLength: 128_000),
        ModelIdentifier(id: "openai/gpt-4o-mini", displayName: "GPT-4o Mini", provider: "OpenAI", contextLength: 128_000),
        ModelIdentifier(id: "google/gemini-2.5-pro", displayName: "Gemini 2.5 Pro", provider: "Google", contextLength: 1_000_000),
        ModelIdentifier(id: "google/gemini-2.5-flash", displayName: "Gemini 2.5 Flash", provider: "Google", contextLength: 1_000_000),
        ModelIdentifier(id: "deepseek/deepseek-r1", displayName: "DeepSeek R1", provider: "DeepSeek", contextLength: 64_000),
        ModelIdentifier(id: "meta-llama/llama-4-maverick", displayName: "Llama 4 Maverick", provider: "Meta", contextLength: 1_000_000),
    ]

    static func model(for id: String) -> ModelIdentifier? {
        all.first { $0.id == id }
    }
}
