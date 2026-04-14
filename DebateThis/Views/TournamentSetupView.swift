import SwiftUI

struct TournamentSetupView: View {
    @Bindable var engine: DebateEngine
    @State private var tournamentEngine: TournamentEngine?
    @AppStorage("openRouterAPIKey") private var apiKey: String = ""
    @State private var topic: String = ""
    @State private var selectedSize: TournamentSize = .four
    @State private var selectedJudge: String = "google/gemini-2.5-pro"
    @State private var selectedModels: Set<String> = []

    var body: some View {
        if let te = tournamentEngine, te.tournament != nil {
            TournamentBracketView(tournamentEngine: te, debateEngine: engine)
        } else {
            setupForm
        }
    }

    private var setupForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(spacing: 4) {
                    Image(systemName: "trophy.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.yellow)
                    Text("Tournament Mode")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Models compete in elimination brackets. Winner takes all.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                // Topic
                VStack(alignment: .leading, spacing: 6) {
                    Text("TOPIC")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .tracking(1.5)

                    TextField("Enter a debate topic...", text: $topic, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...3)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(TopicCategories.all.first?.topics ?? [], id: \.self) { t in
                                Button(t) { topic = t }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                    }
                }

                // Size
                Picker("Tournament Size", selection: $selectedSize) {
                    ForEach(TournamentSize.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }
                .pickerStyle(.segmented)

                // Model Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("SELECT \(selectedSize.rawValue) MODELS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .tracking(1.5)

                    Text("\(selectedModels.count)/\(selectedSize.rawValue) selected")
                        .font(.caption2)
                        .foregroundStyle(selectedModels.count == selectedSize.rawValue ? .green : .orange)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 8) {
                        ForEach(engine.availableModels.prefix(20)) { model in
                            modelSelectionCard(model)
                        }
                    }
                }

                // Judge
                VStack(alignment: .leading, spacing: 4) {
                    Text("JUDGE")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .tracking(1.5)

                    Picker("", selection: $selectedJudge) {
                        ForEach(engine.availableModels) { model in
                            Text(model.shortName).tag(model.id)
                        }
                    }
                    .labelsHidden()
                }

                // Start
                Button {
                    startTournament()
                } label: {
                    Label("Start Tournament", systemImage: "play.fill")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .disabled(!canStart)
            }
            .padding(32)
        }
    }

    private func modelSelectionCard(_ model: ModelIdentifier) -> some View {
        let isSelected = selectedModels.contains(model.id)
        return Button {
            if isSelected {
                selectedModels.remove(model.id)
            } else if selectedModels.count < selectedSize.rawValue {
                selectedModels.insert(model.id)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: ProviderTheme.icon(for: model.provider))
                    .foregroundStyle(ProviderTheme.color(for: model.provider))
                    .frame(width: 20)

                Text(model.shortName)
                    .font(.caption)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding(8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var canStart: Bool {
        !topic.isEmpty && selectedModels.count == selectedSize.rawValue && !apiKey.isEmpty
    }

    private func startTournament() {
        engine.configure(apiKey: apiKey)
        let models = selectedModels.compactMap { id in engine.availableModels.first { $0.id == id } }
        guard let judge = engine.availableModels.first(where: { $0.id == selectedJudge }) else { return }

        let te = TournamentEngine(debateEngine: engine)
        te.createTournament(
            topic: topic,
            participants: models,
            judgeModel: judge,
            commentatorModel: nil,
            roundsPerMatch: 2
        )
        tournamentEngine = te
        te.runNextMatch()
    }
}
