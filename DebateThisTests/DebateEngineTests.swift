import Testing
@testable import DebateThis

@Suite("DebateEngine State Machine")
@MainActor
struct DebateEngineTests {

    @Test("Initial state is idle")
    func initialState() {
        let engine = DebateEngine()
        #expect(engine.state == .idle)
        #expect(engine.debate == nil)
        #expect(engine.streamingTextA.isEmpty)
        #expect(engine.streamingTextB.isEmpty)
    }

    @Test("Reset returns to idle")
    func resetReturnsToIdle() {
        let engine = DebateEngine()
        engine.state = .complete
        engine.streamingTextA = "some text"
        engine.reset()
        #expect(engine.state == .idle)
        #expect(engine.debate == nil)
        #expect(engine.streamingTextA.isEmpty)
    }

    @Test("Preflight passes with large-context models")
    func preflightPassesLargeContext() {
        let engine = DebateEngine()
        let modelA = ModelIdentifier(id: "a", displayName: "A", provider: "X", contextLength: 128_000)
        let modelB = ModelIdentifier(id: "b", displayName: "B", provider: "X", contextLength: 128_000)
        let judge = ModelIdentifier(id: "j", displayName: "J", provider: "X", contextLength: 128_000)

        let warning = engine.preflight(modelA: modelA, modelB: modelB, judge: judge, topic: "test")
        #expect(warning == nil)
    }

    @Test("Preflight warns with small-context model")
    func preflightWarnsSmallContext() {
        let engine = DebateEngine()
        let smallModel = ModelIdentifier(id: "s", displayName: "Small", provider: "X", contextLength: 2_000)
        let bigModel = ModelIdentifier(id: "b", displayName: "Big", provider: "X", contextLength: 128_000)

        let warning = engine.preflight(modelA: smallModel, modelB: bigModel, judge: bigModel, topic: "test")
        #expect(warning != nil)
        #expect(warning!.contains("Small"))
    }

    @Test("Preflight rejects too many rounds")
    func preflightRejectsTooManyRounds() {
        let engine = DebateEngine()
        engine.totalRounds = 15
        let model = ModelIdentifier(id: "a", displayName: "A", provider: "X", contextLength: 1_000_000)

        let warning = engine.preflight(modelA: model, modelB: model, judge: model, topic: "test")
        #expect(warning != nil)
        #expect(warning!.contains("Maximum"))
    }

    @Test("Start debate without API key produces error")
    func startWithoutAPIKey() {
        let engine = DebateEngine()
        let model = ModelIdentifier(id: "a", displayName: "A", provider: "X", contextLength: 128_000)
        engine.startDebate(topic: "test", modelA: model, modelB: model, judgeModel: model)
        #expect(engine.state == .error(message: "API key not configured"))
    }

    @Test("DebateState display text")
    func stateDisplayText() {
        #expect(DebateState.idle.displayText == "Ready")
        #expect(DebateState.turnA(round: 2).displayText.contains("Round 2"))
        #expect(DebateState.judging.displayText.contains("Judge"))
        #expect(DebateState.complete.displayText == "Debate complete")
    }

    @Test("DebateState isActive")
    func stateIsActive() {
        #expect(!DebateState.idle.isActive)
        #expect(DebateState.turnA(round: 1).isActive)
        #expect(DebateState.turnB(round: 1).isActive)
        #expect(DebateState.judging.isActive)
        #expect(!DebateState.complete.isActive)
        #expect(!DebateState.error(message: "x").isActive)
    }
}

@Suite("System Prompts")
struct SystemPromptsTests {

    @Test("Debater prompt includes topic and side")
    func debaterPromptContent() {
        let prompt = SystemPrompts.debater(side: .forTopic, topic: "Pineapple on pizza")
        #expect(prompt.contains("Pineapple on pizza"))
        #expect(prompt.contains("FOR"))
        #expect(prompt.contains("DO NOT concede"))
    }

    @Test("Against debater prompt includes AGAINST")
    func againstDebaterPrompt() {
        let prompt = SystemPrompts.debater(side: .againstTopic, topic: "test")
        #expect(prompt.contains("AGAINST"))
    }

    @Test("Debater with context includes transcript")
    func debaterWithContextIncludesTranscript() {
        let transcript = [
            TranscriptEntry(speaker: "Model A (FOR)", content: "My argument here"),
        ]
        let prompt = SystemPrompts.debaterWithContext(
            side: .againstTopic,
            topic: "test",
            transcript: transcript
        )
        #expect(prompt.contains("My argument here"))
        #expect(prompt.contains("Model A (FOR)"))
        #expect(prompt.contains("Attack their reasoning"))
    }

    @Test("Judge prompt includes scoring rubric")
    func judgePromptContent() {
        let transcript = [
            TranscriptEntry(speaker: "A", content: "arg1"),
            TranscriptEntry(speaker: "B", content: "arg2"),
        ]
        let prompt = SystemPrompts.judge(topic: "test", transcript: transcript)
        #expect(prompt.contains("WINNER:"))
        #expect(prompt.contains("SCORES:"))
        #expect(prompt.contains("argument="))
        #expect(prompt.contains("evidence="))
        #expect(prompt.contains("rhetoric="))
        #expect(prompt.contains("responsiveness="))
    }

    @Test("Empty transcript produces no transcript section")
    func emptyTranscriptDebater() {
        let prompt = SystemPrompts.debaterWithContext(
            side: .forTopic,
            topic: "test",
            transcript: []
        )
        #expect(!prompt.contains("Debate transcript so far"))
    }
}

@Suite("Models")
struct ModelsTests {

    @Test("Available models contains expected entries")
    func availableModelsExist() {
        #expect(AvailableModels.all.count >= 6)
        #expect(AvailableModels.model(for: "openai/gpt-4o") != nil)
        #expect(AvailableModels.model(for: "anthropic/claude-sonnet-4") != nil)
    }

    @Test("Model lookup returns nil for unknown ID")
    func unknownModelReturnsNil() {
        #expect(AvailableModels.model(for: "nonexistent/model") == nil)
    }

    @Test("Debate initializes correctly")
    func debateInit() {
        let modelA = ModelIdentifier(id: "a", displayName: "A", provider: "X")
        let modelB = ModelIdentifier(id: "b", displayName: "B", provider: "X")
        let judge = ModelIdentifier(id: "j", displayName: "J", provider: "X")

        let debate = Debate(topic: "Test topic", modelA: modelA, modelB: modelB, judgeModel: judge)
        #expect(debate.topic == "Test topic")
        #expect(debate.rounds.isEmpty)
        #expect(debate.verdict == nil)
    }
}
