import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var engine = DebateEngine()
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSidebarItem: SidebarItem? = .newDebate
    @State private var selectedSavedDebate: SavedDebate?

    enum SidebarItem: Hashable {
        case newDebate
        case history
        case leaderboard
        case tournament
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 1000, minHeight: 700)
        .onAppear {
            engine.modelContext = modelContext
        }
    }

    private var sidebar: some View {
        List(selection: $selectedSidebarItem) {
            Section("Debate") {
                Label("New Debate", systemImage: "plus.bubble.fill")
                    .tag(SidebarItem.newDebate)
            }

            Section("Compete") {
                Label("Tournament", systemImage: "trophy.circle.fill")
                    .tag(SidebarItem.tournament)

                Label("Leaderboard", systemImage: "chart.bar.fill")
                    .tag(SidebarItem.leaderboard)
            }

            Section("History") {
                Label("Past Debates", systemImage: "clock.fill")
                    .tag(SidebarItem.history)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 160)
    }

    @ViewBuilder
    private var detail: some View {
        switch selectedSidebarItem {
        case .newDebate, .none:
            if engine.state == .idle {
                SetupView(engine: engine)
            } else {
                DebateView(engine: engine)
            }
        case .leaderboard:
            LeaderboardView()
        case .tournament:
            TournamentSetupView(engine: engine)
        case .history:
            HistorySplitView()
        }
    }
}

struct HistorySplitView: View {
    @Query(sort: \SavedDebate.createdAt, order: .reverse)
    private var debates: [SavedDebate]
    @State private var selected: SavedDebate?

    var body: some View {
        HSplitView {
            HistoryView()
                .frame(minWidth: 240, maxWidth: 300)

            if let debate = selected ?? debates.first {
                SavedDebateDetailView(debate: debate)
            } else {
                ContentUnavailableView(
                    "No Debates Yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Complete a debate and it'll show up here.")
                )
            }
        }
    }
}
