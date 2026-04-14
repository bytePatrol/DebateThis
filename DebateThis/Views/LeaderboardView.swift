import SwiftUI
import SwiftData

struct LeaderboardView: View {
    @Query(sort: \ModelRating.rating, order: .reverse)
    private var ratings: [ModelRating]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if ratings.isEmpty {
                ContentUnavailableView(
                    "No Rankings Yet",
                    systemImage: "chart.bar.fill",
                    description: Text("Complete some debates and model rankings will appear here.")
                )
            } else {
                List {
                    ForEach(Array(ratings.enumerated()), id: \.element.modelID) { index, rating in
                        LeaderboardRow(rank: index + 1, rating: rating)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Image(systemName: "trophy.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)

            Text("Model Leaderboard")
                .font(.title2)
                .fontWeight(.bold)

            Text("Elo ratings based on debate wins and losses")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let rating: ModelRating

    var body: some View {
        HStack(spacing: 12) {
            rankBadge

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: ProviderTheme.icon(for: ProviderTheme.label(for: rating.modelID)))
                        .font(.caption)
                        .foregroundStyle(ProviderTheme.color(for: ProviderTheme.label(for: rating.modelID)))

                    Text(rating.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                }

                Text(ProviderTheme.label(for: rating.modelID))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(rating.rating))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .monospacedDigit()

                HStack(spacing: 8) {
                    Text("\(rating.wins)W")
                        .foregroundStyle(.green)
                    Text("\(rating.losses)L")
                        .foregroundStyle(.red)
                    if rating.totalGames > 0 {
                        Text("\(Int(rating.winRate * 100))%")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }

    private var rankBadge: some View {
        ZStack {
            Circle()
                .fill(rankColor.opacity(0.15))
                .frame(width: 32, height: 32)

            if rank <= 3 {
                Image(systemName: rankIcon)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(rankColor)
            } else {
                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .secondary
        }
    }

    private var rankIcon: String {
        switch rank {
        case 1: return "trophy.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return ""
        }
    }
}
