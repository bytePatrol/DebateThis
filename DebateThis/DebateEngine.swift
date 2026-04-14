import Foundation
import Observation
import OpenAI
import SwiftData

// MARK: - DebateEngine
//
// Orchestrates the debate: manages state transitions, turn sequencing,
// and delegates API calls to OpenRouterService.
//
// State Machine:
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
//   turnA(round: 2) ... (repeat for N rounds)
//    |
//    v (final round turnB complete)
//   judging
//    |
//    v
//   complete
//
//   ANY state --> error(message) [user can retry or reset]
//

@MainActor
@Observable
final class DebateEngine {
    // MARK: - Published State

    var state: DebateState = .idle
    var debate: Debate?
    var streamingTextA: String = ""
    var streamingTextB: String = ""
    var commentaryText: String = ""
    var judgeText: String = ""

    // MARK: - Voice

    var speechService = SpeechService()

    // MARK: - Configuration

    var commentaryPersonality: Double = 0.7
    var coachingEnabled: Bool = false
    var coachingText: String = ""
    var coachingTarget: DebaterSide = .forTopic
    var coachingTimeRemaining: Int = 0
    private var coachingContinuation: CheckedContinuation<CoachingHint?, Never>?

    var totalRounds: Int = 3 {
        didSet { totalRounds = max(1, min(totalRounds, maxRounds)) }
    }
    private let maxRounds = 10

    // MARK: - Coaching

    func submitCoachingHint() {
        guard !coachingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            skipCoaching()
            return
        }
        let hint = CoachingHint(targetSide: coachingTarget, content: coachingText.trimmingCharacters(in: .whitespacesAndNewlines))
        coachingContinuation?.resume(returning: hint)
        coachingContinuation = nil
    }

    func skipCoaching() {
        coachingContinuation?.resume(returning: nil)
        coachingContinuation = nil
    }

    // MARK: - Callbacks

    var onDebateComplete: ((Debate) -> Void)?

    // MARK: - Persistence

    var modelContext: ModelContext?

    // MARK: - Private

    private var service: OpenRouterService?
    private var activeTask: Task<Void, Never>?

    // MARK: - Setup

    func configure(apiKey: String) {
        self.service = OpenRouterService(apiKey: apiKey)
    }

    // MARK: - Model Fetching

    var availableModels: [ModelIdentifier] = AvailableModels.all
    var isLoadingModels: Bool = false

    func fetchModels() {
        guard let service else { return }
        isLoadingModels = true
        Task {
            do {
                let models = try await service.fetchModels()
                if !models.isEmpty {
                    self.availableModels = models
                }
            } catch {
                // Keep hardcoded fallback on failure
            }
            self.isLoadingModels = false
        }
    }

    // MARK: - Pre-flight Checks

    /// Estimates total tokens needed and checks against model context lengths.
    func preflight(
        modelA: ModelIdentifier,
        modelB: ModelIdentifier,
        judge: ModelIdentifier,
        topic: String
    ) -> String? {
        let systemPromptTokens = 200
        let tokensPerTurn = 800
        let totalTurns = totalRounds * 2
        // By the last round, the transcript in context is roughly:
        // (totalTurns - 1) * tokensPerTurn for prior turns + system prompt
        let maxContextNeeded = systemPromptTokens + (totalTurns * tokensPerTurn) + tokensPerTurn

        for model in [modelA, modelB, judge] {
            if let contextLength = model.contextLength, maxContextNeeded > contextLength {
                return "'\(model.shortName)' has a \(contextLength)-token context window, but this debate needs ~\(maxContextNeeded) tokens. Pick a model with a larger context or reduce rounds."
            }
        }

        if totalRounds > maxRounds {
            return "Maximum \(maxRounds) rounds allowed."
        }

        return nil
    }

    // MARK: - Start Debate

    func startDebate(topic: String, modelA: ModelIdentifier, modelB: ModelIdentifier, judgeModel: ModelIdentifier, commentatorModel: ModelIdentifier? = nil) {
        // Cancel any in-flight debate before starting a new one
        activeTask?.cancel()
        activeTask = nil

        guard let service else {
            state = .error(message: "API key not configured")
            return
        }

        if let warning = preflight(modelA: modelA, modelB: modelB, judge: judgeModel, topic: topic) {
            state = .error(message: warning)
            return
        }

        debate = Debate(topic: topic, modelA: modelA, modelB: modelB, judgeModel: judgeModel, commentatorModel: commentatorModel)
        streamingTextA = ""
        streamingTextB = ""
        commentaryText = ""
        judgeText = ""

        activeTask = Task { [weak self] in
            guard let self else { return }
            await self.runDebate(service: service)
        }
    }

    // MARK: - Cancel

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
        speechService.stop()
        state = .idle
    }

    // MARK: - Reset

    func reset() {
        cancel()
        debate = nil
        streamingTextA = ""
        streamingTextB = ""
        commentaryText = ""
        judgeText = ""
    }

    // MARK: - Debate Loop

    private func runDebate(service: OpenRouterService) async {
        guard let debate else { return }

        for round in 1...totalRounds {
            guard !Task.isCancelled else { return }

            // -- Model A's turn --
            state = .turnA(round: round)
            streamingTextA = ""

            // Check for coaching hint from previous round targeted at Model A
            let coachHintForA = self.debate?.rounds.last?.coachingHint?.targetSide == .forTopic
                ? self.debate?.rounds.last?.coachingHint?.content : nil

            let transcriptForA = buildTranscript()
            let messagesA = buildMessages(
                systemPrompt: SystemPrompts.debaterWithContext(
                    side: .forTopic,
                    topic: debate.topic,
                    transcript: transcriptForA,
                    coachingHint: coachHintForA
                ),
                userMessage: round == 1
                    ? "Begin your opening argument FOR the topic."
                    : "Respond to your opponent's argument. Attack their weakest points."
            )

            let contentA: String
            do {
                contentA = try await streamResponse(
                    service: service,
                    messages: messagesA,
                    model: debate.modelA.id,
                    writeTo: \.streamingTextA,
                    speechRole: .modelA
                )
            } catch {
                if Task.isCancelled { return }
                state = .error(message: "Model A failed: \(error.localizedDescription)")
                return
            }

            // Record turn A
            var currentRound = DebateRound(number: round)
            var turnA = Turn(model: debate.modelA)
            turnA.content = contentA
            turnA.completedAt = Date()
            currentRound.turnA = turnA

            guard !Task.isCancelled else { return }

            // Brief pause between turns for theatrical effect
            try? await Task.sleep(for: .milliseconds(800))

            // -- Model B's turn --
            state = .turnB(round: round)
            streamingTextB = ""

            // Rebuild transcript including A's just-completed turn
            self.debate?.rounds.append(currentRound)

            // Check for coaching hint targeted at Model B
            let coachHintForB = self.debate?.rounds.dropLast().last?.coachingHint?.targetSide == .againstTopic
                ? self.debate?.rounds.dropLast().last?.coachingHint?.content : nil

            let transcriptForB = buildTranscript()

            let messagesB = buildMessages(
                systemPrompt: SystemPrompts.debaterWithContext(
                    side: .againstTopic,
                    topic: debate.topic,
                    transcript: transcriptForB,
                    coachingHint: coachHintForB
                ),
                userMessage: round == 1
                    ? "Your opponent has made their opening argument. Argue AGAINST the topic and counter their points."
                    : "Respond to your opponent's latest argument. Be direct and aggressive."
            )

            let contentB: String
            do {
                contentB = try await streamResponse(
                    service: service,
                    messages: messagesB,
                    model: debate.modelB.id,
                    writeTo: \.streamingTextB,
                    speechRole: .modelB
                )
            } catch {
                if Task.isCancelled { return }
                state = .error(message: "Model B failed: \(error.localizedDescription)")
                return
            }

            // Record turn B
            var turnB = Turn(model: debate.modelB)
            turnB.content = contentB
            turnB.completedAt = Date()
            if var lastRound = self.debate?.rounds.last,
               let lastIndex = self.debate.map({ $0.rounds.count - 1 }),
               lastIndex >= 0 {
                lastRound.turnB = turnB
                self.debate?.rounds[lastIndex] = lastRound
            }

            guard !Task.isCancelled else { return }

            // -- Commentary phase (if commentator model selected) --
            if let commentatorModel = debate.commentatorModel {
                state = .commenting(round: round)
                commentaryText = ""

                // Build transcript for just this round
                let roundTranscript = buildRoundTranscript(round: round)
                let commentaryMessages = buildMessages(
                    systemPrompt: SystemPrompts.commentator(
                        topic: debate.topic,
                        round: round,
                        transcript: roundTranscript,
                        personality: commentaryPersonality
                    ),
                    userMessage: "Deliver your commentary on this round."
                )

                do {
                    let commentary = try await streamResponse(
                        service: service,
                        messages: commentaryMessages,
                        model: commentatorModel.id,
                        maxCompletionTokens: 200,
                        writeTo: \.commentaryText,
                        speechRole: .commentator
                    )
                    // Record commentary on the round
                    if let lastIndex = self.debate.map({ $0.rounds.count - 1 }),
                       lastIndex >= 0 {
                        self.debate?.rounds[lastIndex].commentary = commentary
                    }
                } catch {
                    if Task.isCancelled { return }
                    // Commentary failure is non-fatal, just skip it
                }

                guard !Task.isCancelled else { return }
            }

            // -- Coaching phase (if enabled and not the last round) --
            if coachingEnabled && round < totalRounds {
                state = .coaching(round: round)
                coachingText = ""
                coachingTimeRemaining = 30

                let hint: CoachingHint? = await withCheckedContinuation { continuation in
                    self.coachingContinuation = continuation
                    Task {
                        for i in stride(from: 30, through: 0, by: -1) {
                            guard !Task.isCancelled else { return }
                            if self.coachingContinuation == nil { return }
                            self.coachingTimeRemaining = i
                            try? await Task.sleep(for: .seconds(1))
                        }
                        self.coachingContinuation?.resume(returning: nil)
                        self.coachingContinuation = nil
                    }
                }

                if let hint {
                    if let lastIndex = self.debate.map({ $0.rounds.count - 1 }),
                       lastIndex >= 0 {
                        self.debate?.rounds[lastIndex].coachingHint = hint
                    }
                }

                guard !Task.isCancelled else { return }
            }

            // Pause between rounds
            if round < totalRounds {
                try? await Task.sleep(for: .seconds(1))
            }
        }

        // -- Judge's verdict --
        guard !Task.isCancelled else { return }
        state = .judging
        judgeText = ""

        let transcript = buildTranscript(useGenericLabels: true)
        let judgeMessages = buildMessages(
            systemPrompt: SystemPrompts.judge(topic: debate.topic, transcript: transcript),
            userMessage: "Deliver your verdict now."
        )

        do {
            let verdictText = try await streamResponse(
                service: service,
                messages: judgeMessages,
                model: debate.judgeModel.id,
                maxCompletionTokens: 500,
                writeTo: \.judgeText,
                speechRole: .judge
            )
            self.debate?.verdict = parseVerdict(from: verdictText, debate: debate)
        } catch {
            if Task.isCancelled { return }
            state = .error(message: "Judge failed: \(error.localizedDescription)")
            return
        }

        state = .complete

        // Auto-save completed debate and notify listeners
        if let debate = self.debate {
            saveDebate(debate)
            onDebateComplete?(debate)
        }
    }

    private func saveDebate(_ debate: Debate) {
        guard let modelContext else { return }
        let saved = SavedDebate(from: debate)
        modelContext.insert(saved)

        // Update Elo ratings
        if let verdict = debate.verdict {
            let winnerIsA = verdict.winner.id == debate.modelA.id
            EloService.recordResult(
                winnerID: winnerIsA ? debate.modelA.id : debate.modelB.id,
                winnerName: winnerIsA ? debate.modelA.shortName : debate.modelB.shortName,
                loserID: winnerIsA ? debate.modelB.id : debate.modelA.id,
                loserName: winnerIsA ? debate.modelB.shortName : debate.modelA.shortName,
                context: modelContext
            )
        }

        try? modelContext.save()
    }

    // MARK: - Streaming Helper

    @discardableResult
    private func streamResponse(
        service: OpenRouterService,
        messages: [ChatQuery.ChatCompletionMessageParam],
        model: String,
        maxCompletionTokens: Int = 800,
        writeTo keyPath: ReferenceWritableKeyPath<DebateEngine, String>,
        speechRole: SpeechRole? = nil
    ) async throws -> String {
        var accumulated = ""
        speechService.resetForNewTurn()
        let stream = await service.streamCompletion(
            messages: messages,
            model: model,
            maxCompletionTokens: maxCompletionTokens
        )

        for try await chunk in stream {
            guard !Task.isCancelled else { throw CancellationError() }
            accumulated += chunk
            self[keyPath: keyPath] = accumulated

            if let role = speechRole {
                speechService.feedStreamingText(accumulated, role: role)
            }
        }

        if let role = speechRole {
            speechService.flushRemaining(role: role)
        }

        return accumulated
    }

    // MARK: - Message Construction

    private func buildMessages(
        systemPrompt: String,
        userMessage: String
    ) -> [ChatQuery.ChatCompletionMessageParam] {
        [
            .init(role: .system, content: systemPrompt)!,
            .init(role: .user, content: userMessage)!,
        ]
    }

    // MARK: - Transcript

    private func buildTranscript(useGenericLabels: Bool = false) -> [TranscriptEntry] {
        guard let debate else { return [] }
        var entries: [TranscriptEntry] = []
        let speakerA = useGenericLabels ? "Model A (FOR)" : "\(debate.modelA.shortName) (FOR)"
        let speakerB = useGenericLabels ? "Model B (AGAINST)" : "\(debate.modelB.shortName) (AGAINST)"
        for round in debate.rounds {
            if let turnA = round.turnA {
                entries.append(TranscriptEntry(speaker: speakerA, content: turnA.content))
            }
            if let turnB = round.turnB {
                entries.append(TranscriptEntry(speaker: speakerB, content: turnB.content))
            }
        }
        return entries
    }

    /// Build transcript for a specific round only (used for commentary).
    private func buildRoundTranscript(round: Int) -> [TranscriptEntry] {
        guard let debate,
              let debateRound = debate.rounds.first(where: { $0.number == round }) else {
            return []
        }
        var entries: [TranscriptEntry] = []
        if let turnA = debateRound.turnA {
            entries.append(TranscriptEntry(
                speaker: "\(debate.modelA.shortName) (FOR)",
                content: turnA.content
            ))
        }
        if let turnB = debateRound.turnB {
            entries.append(TranscriptEntry(
                speaker: "\(debate.modelB.shortName) (AGAINST)",
                content: turnB.content
            ))
        }
        return entries
    }

    // MARK: - Verdict Parsing

    private func parseVerdict(from text: String, debate: Debate) -> Verdict {
        // Parse the structured verdict format from the judge.
        // Falls back to declaring Model A winner with the full text as reasoning
        // if parsing fails (the judge might not follow format exactly).

        let lines = text.components(separatedBy: "\n")
        let winnerLine = lines.first { $0.uppercased().hasPrefix("WINNER:") }
        let winnerIsB = winnerLine?.uppercased().contains("MODEL B") ?? false
        let winner = winnerIsB ? debate.modelB : debate.modelA

        // Extract scores (best effort)
        let scores = parseScores(from: text)

        // Extract reasoning
        let reasoningStart = text.range(of: "REASONING:")?.upperBound ?? text.startIndex
        let reasoning = String(text[reasoningStart...]).trimmingCharacters(in: .whitespacesAndNewlines)

        return Verdict(
            winner: winner,
            reasoning: reasoning.isEmpty ? text : reasoning,
            scores: scores
        )
    }

    private func parseScores(from text: String) -> VerdictScores {
        func extractScore(_ text: String, after label: String) -> Int {
            guard let range = text.range(of: label) else { return 5 }
            let after = text[range.upperBound...]
            let digits = after.prefix(while: { $0.isNumber || $0 == "=" }).filter { $0.isNumber }
            return Int(digits) ?? 5
        }

        let lines = text.components(separatedBy: "\n")
        let modelALine = lines.first { $0.contains("Model A:") && $0.contains("argument") } ?? ""
        let modelBLine = lines.first { $0.contains("Model B:") && $0.contains("argument") } ?? ""

        return VerdictScores(
            modelAArgumentQuality: extractScore(modelALine, after: "argument="),
            modelAEvidence: extractScore(modelALine, after: "evidence="),
            modelARhetoric: extractScore(modelALine, after: "rhetoric="),
            modelAResponsiveness: extractScore(modelALine, after: "responsiveness="),
            modelBArgumentQuality: extractScore(modelBLine, after: "argument="),
            modelBEvidence: extractScore(modelBLine, after: "evidence="),
            modelBRhetoric: extractScore(modelBLine, after: "rhetoric="),
            modelBResponsiveness: extractScore(modelBLine, after: "responsiveness=")
        )
    }
}
