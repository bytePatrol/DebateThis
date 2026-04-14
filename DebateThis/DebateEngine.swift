import Foundation
import Observation
import OpenAI

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
    var judgeText: String = ""

    // MARK: - Configuration

    var totalRounds: Int = 3 {
        didSet { totalRounds = max(1, min(totalRounds, maxRounds)) }
    }
    private let maxRounds = 10

    // MARK: - Private

    private var service: OpenRouterService?
    private var activeTask: Task<Void, Never>?

    // MARK: - Setup

    func configure(apiKey: String) {
        self.service = OpenRouterService(apiKey: apiKey)
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

    func startDebate(topic: String, modelA: ModelIdentifier, modelB: ModelIdentifier, judgeModel: ModelIdentifier) {
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

        debate = Debate(topic: topic, modelA: modelA, modelB: modelB, judgeModel: judgeModel)
        streamingTextA = ""
        streamingTextB = ""
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
        state = .idle
    }

    // MARK: - Reset

    func reset() {
        cancel()
        debate = nil
        streamingTextA = ""
        streamingTextB = ""
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

            let transcriptForA = buildTranscript()
            let messagesA = buildMessages(
                systemPrompt: SystemPrompts.debaterWithContext(
                    side: .forTopic,
                    topic: debate.topic,
                    transcript: transcriptForA
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
                    writeTo: \.streamingTextA
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
            let transcriptForB = buildTranscript()

            let messagesB = buildMessages(
                systemPrompt: SystemPrompts.debaterWithContext(
                    side: .againstTopic,
                    topic: debate.topic,
                    transcript: transcriptForB
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
                    writeTo: \.streamingTextB
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
                writeTo: \.judgeText
            )
            self.debate?.verdict = parseVerdict(from: verdictText, debate: debate)
        } catch {
            if Task.isCancelled { return }
            state = .error(message: "Judge failed: \(error.localizedDescription)")
            return
        }

        state = .complete
    }

    // MARK: - Streaming Helper

    @discardableResult
    private func streamResponse(
        service: OpenRouterService,
        messages: [ChatQuery.ChatCompletionMessageParam],
        model: String,
        maxCompletionTokens: Int = 800,
        writeTo keyPath: ReferenceWritableKeyPath<DebateEngine, String>
    ) async throws -> String {
        var accumulated = ""
        let stream = await service.streamCompletion(
            messages: messages,
            model: model,
            maxCompletionTokens: maxCompletionTokens
        )

        for try await chunk in stream {
            guard !Task.isCancelled else { throw CancellationError() }
            accumulated += chunk
            self[keyPath: keyPath] = accumulated
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
