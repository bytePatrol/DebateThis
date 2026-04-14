import SwiftUI

struct TournamentBracketView: View {
    @Bindable var tournamentEngine: TournamentEngine
    @Bindable var debateEngine: DebateEngine

    var body: some View {
        VStack(spacing: 0) {
            tournamentHeader
            Divider()

            if tournamentEngine.isRunning {
                DebateView(engine: debateEngine)
            } else if let tournament = tournamentEngine.tournament {
                if tournament.isComplete {
                    championView(tournament)
                } else {
                    bracketView(tournament)
                }
            }
        }
    }

    private var tournamentHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TOURNAMENT")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .tracking(2)

                Text(tournamentEngine.tournament?.topic ?? "")
                    .font(.headline)
            }

            Spacer()

            if let t = tournamentEngine.tournament {
                let completed = t.matches.filter { $0.state == .complete }.count
                let total = t.matches.filter { $0.modelA != nil && $0.modelB != nil || $0.state == .complete }.count
                Text("\(completed)/\(total) matches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.bar)
    }

    private func bracketView(_ tournament: TournamentData) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .center, spacing: 40) {
                ForEach(0..<tournament.totalRounds, id: \.self) { roundIndex in
                    let roundMatches = tournament.matches.filter { $0.roundIndex == roundIndex }

                    VStack(spacing: 24) {
                        Text(roundLabel(roundIndex, total: tournament.totalRounds))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .tracking(1)

                        ForEach(roundMatches) { match in
                            matchCard(match)
                        }
                    }
                }
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func matchCard(_ match: TournamentMatch) -> some View {
        VStack(spacing: 2) {
            matchSlot(model: match.modelA, isWinner: match.winner?.id == match.modelA?.id, match: match)
            Rectangle().fill(.quaternary).frame(height: 1)
            matchSlot(model: match.modelB, isWinner: match.winner?.id == match.modelB?.id, match: match)
        }
        .frame(width: 180)
        .background(.bar, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(match.state == .inProgress ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .opacity(match.state == .pending ? 0.4 : 1.0)
    }

    private func matchSlot(model: ModelIdentifier?, isWinner: Bool, match: TournamentMatch) -> some View {
        HStack(spacing: 6) {
            if let model, model.id != "bye" {
                Image(systemName: ProviderTheme.icon(for: model.provider))
                    .font(.caption2)
                    .foregroundStyle(ProviderTheme.color(for: model.provider))
                    .frame(width: 14)

                Text(model.shortName)
                    .font(.caption)
                    .fontWeight(isWinner ? .bold : .regular)
                    .lineLimit(1)
            } else {
                Text("TBD")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if isWinner && match.state == .complete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isWinner ? Color.green.opacity(0.08) : Color.clear)
    }

    private func championView(_ tournament: TournamentData) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "trophy.fill")
                .font(.system(size: 64))
                .foregroundStyle(.yellow)

            Text("Tournament Champion")
                .font(.title)
                .fontWeight(.bold)

            if let champion = tournament.champion {
                HStack(spacing: 8) {
                    Image(systemName: ProviderTheme.icon(for: champion.provider))
                        .foregroundStyle(ProviderTheme.color(for: champion.provider))
                    Text(champion.shortName)
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }

            Text("Topic: \(tournament.topic)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            bracketView(tournament)
        }
    }

    private func roundLabel(_ index: Int, total: Int) -> String {
        let remaining = total - index
        switch remaining {
        case 1: return "FINAL"
        case 2: return "SEMIS"
        case 3: return "QUARTERS"
        default: return "ROUND \(index + 1)"
        }
    }
}
