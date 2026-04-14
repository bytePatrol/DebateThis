import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \SavedDebate.createdAt, order: .reverse)
    private var debates: [SavedDebate]

    @State private var selectedDebate: SavedDebate?

    var body: some View {
        List(selection: $selectedDebate) {
            ForEach(debates) { debate in
                HistoryRow(debate: debate)
                    .tag(debate)
            }
            .onDelete(perform: deleteDebates)
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
        .overlay {
            if debates.isEmpty {
                ContentUnavailableView(
                    "No Debates Yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Completed debates will appear here.")
                )
            }
        }
    }

    private func deleteDebates(at offsets: IndexSet) {
        // Deletion handled via SwiftData cascade
    }
}

struct HistoryRow: View {
    let debate: SavedDebate

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(debate.topic)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)

            HStack(spacing: 4) {
                Image(systemName: ProviderTheme.icon(for: ProviderTheme.label(for: debate.modelAID)))
                    .font(.caption2)
                    .foregroundStyle(ProviderTheme.color(for: ProviderTheme.label(for: debate.modelAID)))

                Text(debate.modelAName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("vs")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text(debate.modelBName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Image(systemName: ProviderTheme.icon(for: ProviderTheme.label(for: debate.modelBID)))
                    .font(.caption2)
                    .foregroundStyle(ProviderTheme.color(for: ProviderTheme.label(for: debate.modelBID)))
            }

            HStack(spacing: 6) {
                if let winner = debate.winnerName {
                    Image(systemName: "trophy.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text(winner)
                        .font(.caption2)
                        .fontWeight(.semibold)
                }

                Spacer()

                Text(debate.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Debate Detail (for reading saved debates)

struct SavedDebateDetailView: View {
    let debate: SavedDebate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text(debate.topic)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("\(debate.modelAName) vs \(debate.modelBName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(debate.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                Divider()

                // Rounds
                let sortedRounds = debate.rounds.sorted { $0.number < $1.number }
                ForEach(sortedRounds) { round in
                    savedRoundView(round)
                }

                // Verdict
                if let winner = debate.winnerName {
                    Divider()
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                            Text("Winner: \(winner)")
                                .font(.headline)
                        }

                        if let reasoning = debate.verdictReasoning {
                            Text(reasoning)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(24)
            .textSelection(.enabled)
        }
        .toolbar {
            ShareLink(item: debate.exportTranscript()) {
                Label("Share Transcript", systemImage: "square.and.arrow.up")
            }
        }
    }

    private func savedRoundView(_ round: SavedRound) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ROUND \(round.number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .tracking(1)

            if let a = round.turnAContent {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(debate.modelAName) (FOR)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                    Text(a)
                        .font(.body)
                        .lineSpacing(4)
                }
            }

            if let b = round.turnBContent {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(debate.modelBName) (AGAINST)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                    Text(b)
                        .font(.body)
                        .lineSpacing(4)
                }
            }

            if let c = round.commentary {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "mic.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text(c)
                        .font(.callout)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
