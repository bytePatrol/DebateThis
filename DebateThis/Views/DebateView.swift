import SwiftUI

struct DebateView: View {
    @Bindable var engine: DebateEngine

    var body: some View {
        VStack(spacing: 0) {
            // Top: topic + status
            topicBar

            Divider()

            // Middle: debate panes
            debatePanes

            Divider()

            // Bottom: judge area
            judgeArea
        }
    }

    // MARK: - Topic Bar

    private var topicBar: some View {
        VStack(spacing: 4) {
            Text("DEBATE")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .tracking(2)

            Text(engine.debate?.topic ?? "")
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            statusPill
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            if engine.state.isActive {
                ProgressView()
                    .controlSize(.mini)
            }

            Text(engine.state.displayText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
    }

    // MARK: - Debate Panes

    private var debatePanes: some View {
        HStack(spacing: 0) {
            // Model A (left, blue)
            debatePane(
                model: engine.debate?.modelA,
                side: "FOR",
                accent: .blue,
                streamingText: engine.streamingTextA,
                rounds: engine.debate?.rounds ?? [],
                turnKeyPath: \.turnA,
                isStreaming: isModelAStreaming
            )

            // Center divider
            VStack {
                Spacer()
                Text("VS")
                    .font(.headline)
                    .fontWeight(.black)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                Spacer()
            }
            .frame(width: 60)

            // Model B (right, red)
            debatePane(
                model: engine.debate?.modelB,
                side: "AGAINST",
                accent: .red,
                streamingText: engine.streamingTextB,
                rounds: engine.debate?.rounds ?? [],
                turnKeyPath: \.turnB,
                isStreaming: isModelBStreaming
            )
        }
        .frame(maxHeight: .infinity)
    }

    private func debatePane(
        model: ModelIdentifier?,
        side: String,
        accent: Color,
        streamingText: String,
        rounds: [DebateRound],
        turnKeyPath: KeyPath<DebateRound, Turn?>,
        isStreaming: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Nameplate
            HStack(spacing: 8) {
                Circle()
                    .fill(accent.gradient)
                    .frame(width: 10, height: 10)

                Text(model?.shortName ?? "")
                    .font(.caption)
                    .fontWeight(.bold)

                Text("(\(side))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(accent.opacity(0.08))

            Divider()

            // Content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Completed rounds
                        ForEach(rounds) { round in
                            if let turn = round[keyPath: turnKeyPath] {
                                roundBlock(
                                    round: round.number,
                                    content: turn.content,
                                    accent: accent
                                )
                            }
                        }

                        // Currently streaming
                        if isStreaming && !streamingText.isEmpty {
                            streamingBlock(
                                content: streamingText,
                                accent: accent
                            )
                            .id("streaming")
                        }
                    }
                    .padding(16)
                }
                .onChange(of: streamingText) { _, _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func roundBlock(round: Int, content: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ROUND \(round)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(accent)
                .tracking(1)

            Text(content)
                .font(.body)
                .textSelection(.enabled)
                .lineSpacing(4)
        }
    }

    private func streamingBlock(content: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("ROUND \(currentRound)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(accent)
                    .tracking(1)

                streamingIndicator(accent: accent)
            }

            Text(content)
                .font(.body)
                .textSelection(.enabled)
                .lineSpacing(4)
        }
    }

    private func streamingIndicator(accent: Color) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(accent)
                    .frame(width: 4, height: 4)
                    .opacity(0.6)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(i) * 0.2),
                        value: engine.state
                    )
            }
        }
    }

    // MARK: - Judge Area

    private var judgeArea: some View {
        VStack(spacing: 8) {
            if case .judging = engine.state {
                judgingView
            } else if case .complete = engine.state, let verdict = engine.debate?.verdict {
                verdictView(verdict)
            } else if case .error(let message) = engine.state {
                errorView(message)
            } else {
                judgeWaiting
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var judgeWaiting: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.badge.shield.checkmark.fill")
                .foregroundStyle(.purple)

            Text("Judge: \(engine.debate?.judgeModel.shortName ?? "")")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Waiting for debate to finish...")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            Button("Cancel") {
                engine.cancel()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var judgingView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)

                Text("Judge \(engine.debate?.judgeModel.shortName ?? "") is deliberating...")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.purple)
            }

            if !engine.judgeText.isEmpty {
                Text(engine.judgeText)
                    .font(.callout)
                    .lineSpacing(3)
                    .textSelection(.enabled)
            }
        }
    }

    private func verdictView(_ verdict: Verdict) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                    .font(.title2)

                Text("Winner: \(verdict.winner.shortName)")
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Text(verdict.reasoning)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .textSelection(.enabled)

            // Score summary
            HStack(spacing: 32) {
                scoreColumn(
                    name: engine.debate?.modelA.shortName ?? "A",
                    accent: .blue,
                    scores: [
                        ("Argument", verdict.scores.modelAArgumentQuality),
                        ("Evidence", verdict.scores.modelAEvidence),
                        ("Rhetoric", verdict.scores.modelARhetoric),
                        ("Response", verdict.scores.modelAResponsiveness),
                    ]
                )

                scoreColumn(
                    name: engine.debate?.modelB.shortName ?? "B",
                    accent: .red,
                    scores: [
                        ("Argument", verdict.scores.modelBArgumentQuality),
                        ("Evidence", verdict.scores.modelBEvidence),
                        ("Rhetoric", verdict.scores.modelBRhetoric),
                        ("Response", verdict.scores.modelBResponsiveness),
                    ]
                )
            }

            Button("New Debate") {
                engine.reset()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private func scoreColumn(name: String, accent: Color, scores: [(String, Int)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(accent)

            ForEach(scores, id: \.0) { label, score in
                HStack {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                    Text("\(score)/10")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.callout)
                .foregroundStyle(.red)

            Spacer()

            Button("Retry") {
                // Re-start with same params
                if let debate = engine.debate {
                    engine.startDebate(
                        topic: debate.topic,
                        modelA: debate.modelA,
                        modelB: debate.modelB,
                        judgeModel: debate.judgeModel
                    )
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Reset") {
                engine.reset()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Helpers

    private var isModelAStreaming: Bool {
        if case .turnA = engine.state { return true }
        return false
    }

    private var isModelBStreaming: Bool {
        if case .turnB = engine.state { return true }
        return false
    }

    private var currentRound: Int {
        switch engine.state {
        case .turnA(let r), .turnB(let r):
            return r
        default:
            return (engine.debate?.rounds.count ?? 0) + 1
        }
    }
}
