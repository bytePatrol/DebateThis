import SwiftUI

struct DebateView: View {
    @Bindable var engine: DebateEngine

    var body: some View {
        VStack(spacing: 0) {
            topicBar
            Divider()
            debatePanes
            commentaryBar
            Divider()
            judgeArea
        }
    }

    // MARK: - Topic Bar

    private var topicBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                nameplate(
                    model: engine.debate?.modelA,
                    side: "FOR",
                    accent: .blue
                )

                Spacer()

                VStack(spacing: 2) {
                    Text("DEBATE")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .tracking(2)
                    statusPill
                }

                Spacer()

                nameplate(
                    model: engine.debate?.modelB,
                    side: "AGAINST",
                    accent: .red
                )
            }

            Text(engine.debate?.topic ?? "")
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            roundIndicator
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func nameplate(model: ModelIdentifier?, side: String, accent: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(accent.gradient)
                .frame(width: 4, height: 32)

            VStack(alignment: side == "FOR" ? .leading : .trailing, spacing: 1) {
                Text(model?.shortName ?? "")
                    .font(.subheadline)
                    .fontWeight(.bold)

                Text(side)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(accent)
                    .tracking(1)
            }
        }
    }

    private var roundIndicator: some View {
        HStack(spacing: 4) {
            if let total = Optional(engine.totalRounds) {
                ForEach(1...total, id: \.self) { round in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(roundColor(for: round))
                        .frame(width: roundWidth(for: round), height: 4)
                        .animation(.easeInOut(duration: 0.3), value: engine.state)
                }
            }
        }
    }

    private func roundColor(for round: Int) -> Color {
        guard let current = engine.state.currentRound else {
            if case .judging = engine.state { return .purple.opacity(0.6) }
            if case .complete = engine.state { return .green.opacity(0.6) }
            return .gray.opacity(0.2)
        }
        if round < current { return .primary.opacity(0.3) }
        if round == current { return .accentColor }
        return .gray.opacity(0.2)
    }

    private func roundWidth(for round: Int) -> CGFloat {
        guard let current = engine.state.currentRound else { return 24 }
        return round == current ? 40 : 24
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            if engine.state.isActive {
                PulsingDot(color: statusColor)
            }

            Text(engine.state.displayText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(statusColor.opacity(0.1), in: Capsule())
    }

    private var statusColor: Color {
        switch engine.state {
        case .turnA: return .blue
        case .turnB: return .red
        case .commenting: return .orange
        case .judging: return .purple
        case .complete: return .green
        case .error: return .red
        case .idle: return .secondary
        }
    }

    // MARK: - Debate Panes

    private var debatePanes: some View {
        HStack(spacing: 0) {
            debatePane(
                side: "FOR",
                accent: .blue,
                streamingText: engine.streamingTextA,
                rounds: engine.debate?.rounds ?? [],
                turnKeyPath: \.turnA,
                isStreaming: isModelAStreaming
            )

            Rectangle()
                .fill(.quaternary)
                .frame(width: 1)

            debatePane(
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
        side: String,
        accent: Color,
        streamingText: String,
        rounds: [DebateRound],
        turnKeyPath: KeyPath<DebateRound, Turn?>,
        isStreaming: Bool
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(rounds) { round in
                        if let turn = round[keyPath: turnKeyPath] {
                            roundBlock(
                                round: round.number,
                                content: turn.content,
                                accent: accent
                            )
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }

                    if isStreaming && !streamingText.isEmpty {
                        streamingBlock(content: streamingText, accent: accent)
                            .id("streaming-\(side)")
                    }
                }
                .padding(16)
                .animation(.easeOut(duration: 0.3), value: rounds.count)
            }
            .onChange(of: streamingText) { _, _ in
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo("streaming-\(side)", anchor: .bottom)
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

                StreamingDots(color: accent)
            }

            Text(content)
                .font(.body)
                .textSelection(.enabled)
                .lineSpacing(4)
        }
    }

    // MARK: - Commentary Bar

    @ViewBuilder
    private var commentaryBar: some View {
        if engine.debate?.commentatorModel != nil {
            let isCommenting = { if case .commenting = engine.state { return true }; return false }()
            let hasCommentary = !engine.commentaryText.isEmpty || hasAnyCommentary

            if isCommenting || hasCommentary {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)

                        Text("COMMENTARY")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                            .tracking(1.5)

                        if let name = engine.debate?.commentatorModel?.shortName {
                            Text(name)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    if isCommenting && !engine.commentaryText.isEmpty {
                        Text(engine.commentaryText)
                            .font(.callout)
                            .italic()
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    } else if let lastCommentary = latestCommentary {
                        Text(lastCommentary)
                            .font(.callout)
                            .italic()
                            .foregroundStyle(.tertiary)
                            .lineSpacing(3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.orange.opacity(0.05))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.3), value: engine.state)
            }
        }
    }

    private var hasAnyCommentary: Bool {
        engine.debate?.rounds.contains { $0.commentary != nil } ?? false
    }

    private var latestCommentary: String? {
        engine.debate?.rounds.last(where: { $0.commentary != nil })?.commentary
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
                DeliberationIndicator()

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
                    .scaleEffect(verdictAppeared ? 1.0 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: verdictAppeared)

                Text("Winner: \(verdict.winner.shortName)")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .onAppear { verdictAppeared = true }

            Text(verdict.reasoning)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .textSelection(.enabled)

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
                verdictAppeared = false
                engine.reset()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    @State private var verdictAppeared = false

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
                if let debate = engine.debate {
                    engine.startDebate(
                        topic: debate.topic,
                        modelA: debate.modelA,
                        modelB: debate.modelB,
                        judgeModel: debate.judgeModel,
                        commentatorModel: debate.commentatorModel
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
        engine.state.currentRound ?? (engine.debate?.rounds.count ?? 0) + 1
    }
}

// MARK: - Animated Components

/// Continuously pulsing dot for status indicators.
struct PulsingDot: View {
    let color: Color
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .opacity(isAnimating ? 1.0 : 0.3)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

/// Three dots that animate sequentially for streaming state.
struct StreamingDots: View {
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.15)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                        .opacity(dotOpacity(index: i, phase: phase))
                }
            }
        }
    }

    private func dotOpacity(index: Int, phase: Double) -> Double {
        let wave = sin((phase * 4) + Double(index) * 0.8)
        return 0.3 + (wave + 1) * 0.35
    }
}

/// Animated scales icon for judge deliberation.
struct DeliberationIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        Image(systemName: "scalemass.fill")
            .foregroundStyle(.purple)
            .font(.caption)
            .rotationEffect(.degrees(isAnimating ? 5 : -5))
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}
