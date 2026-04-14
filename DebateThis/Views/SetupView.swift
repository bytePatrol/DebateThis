import SwiftUI

struct SetupView: View {
    @Bindable var engine: DebateEngine
    @AppStorage("openRouterAPIKey") private var apiKey: String = ""
    @State private var topic: String = ""
    @State private var selectedModelA: String = "anthropic/claude-sonnet-4"
    @State private var selectedModelB: String = "openai/gpt-4o"
    @State private var selectedJudge: String = "google/gemini-2.5-pro"
    @State private var selectedCommentator: String = "google/gemini-2.5-flash"
    @State private var commentaryEnabled: Bool = true
    @State private var isValidating: Bool = false
    @State private var keyIsValid: Bool? = nil
    @State private var selectedCategory: String = "tech"

    var body: some View {
        VStack(spacing: 0) {
            apiKeySection
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    topicSection
                    modelSection
                    commentarySection
                    coachingSection
                    voiceSection
                    startButton
                }
                .padding(24)
            }
        }
    }

    // MARK: - API Key

    private var apiKeySection: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .foregroundStyle(.secondary)

            SecureField("OpenRouter API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .onChange(of: apiKey) { _, newValue in
                    keyIsValid = nil
                    if !newValue.isEmpty {
                        engine.configure(apiKey: newValue)
                        engine.fetchModels()
                    }
                }

            if engine.isLoadingModels {
                ProgressView()
                    .controlSize(.small)
            } else if let valid = keyIsValid {
                Image(systemName: valid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(valid ? .green : .red)
            }

            Button("Validate") {
                validateKey()
            }
            .disabled(apiKey.isEmpty || isValidating)
        }
        .padding(16)
        .background(.bar)
        .onAppear {
            if !apiKey.isEmpty {
                engine.configure(apiKey: apiKey)
                engine.fetchModels()
            }
        }
    }

    // MARK: - Topic

    private var topicSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DEBATE TOPIC")
                .font(.caption)
                .foregroundStyle(.secondary)
                .tracking(1.5)

            TextField("Enter a topic to debate...", text: $topic, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            // Category tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(TopicCategories.all) { category in
                        Button {
                            selectedCategory = category.id
                        } label: {
                            Label(category.name, systemImage: category.icon)
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedCategory == category.id ? .accentColor : .secondary)
                        .controlSize(.small)
                    }
                }
            }

            // Topics for selected category
            if let category = TopicCategories.all.first(where: { $0.id == selectedCategory }) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(category.topics, id: \.self) { suggestion in
                            Button(suggestion) {
                                topic = suggestion
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Model Selection

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("MODELS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .tracking(1.5)

                Spacer()

                if engine.availableModels.count > AvailableModels.all.count {
                    Text("\(engine.availableModels.count) models loaded from OpenRouter")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 24) {
                modelPicker(
                    title: "Debater A (FOR)",
                    accent: .blue,
                    selection: $selectedModelA
                )

                Text("VS")
                    .font(.title2)
                    .fontWeight(.black)
                    .foregroundStyle(.secondary)

                modelPicker(
                    title: "Debater B (AGAINST)",
                    accent: .red,
                    selection: $selectedModelB
                )
            }

            modelPicker(
                title: "Judge",
                accent: .purple,
                selection: $selectedJudge
            )

            if selectedJudge == selectedModelA || selectedJudge == selectedModelB {
                Label("Judge should be a different model from both debaters for impartiality.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Commentary

    private var commentarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $commentaryEnabled) {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.orange)
                    Text("Live Commentary")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .toggleStyle(.switch)

            if commentaryEnabled {
                HStack(spacing: 8) {
                    Text("Commentator:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    modelPicker(
                        title: "",
                        accent: .orange,
                        selection: $selectedCommentator
                    )
                }
                .padding(.leading, 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Personality:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(personalityLabel)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                    }

                    Slider(value: $engine.commentaryPersonality, in: 0...1, step: 0.1)
                        .controlSize(.small)

                    HStack {
                        Text("Academic")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("Sports Broadcaster")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(12)
        .background(.orange.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    private var coachingSection: some View {
        Toggle(isOn: $engine.coachingEnabled) {
            HStack(spacing: 6) {
                Image(systemName: "megaphone.fill")
                    .foregroundStyle(.mint)
                Text("Audience Coaching")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .toggleStyle(.switch)
        .padding(12)
        .background(.mint.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    private var voiceSection: some View {
        Toggle(isOn: $engine.speechService.isEnabled) {
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.indigo)
                Text("Voice (Text-to-Speech)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .toggleStyle(.switch)
        .padding(12)
        .background(.indigo.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    private func modelPicker(title: String, accent: Color, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !title.isEmpty {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(accent)
            }

            Picker("", selection: selection) {
                ForEach(engine.availableModels) { model in
                    Text(model.shortName).tag(model.id)
                }
            }
            .labelsHidden()
        }
    }

    // MARK: - Start

    private var startButton: some View {
        HStack {
            Spacer()
            Button {
                startDebate()
            } label: {
                Label("Start Debate", systemImage: "play.fill")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canStart)
            Spacer()
        }
    }

    private var personalityLabel: String {
        let p = engine.commentaryPersonality
        if p < 0.2 { return "Dry Academic" }
        if p < 0.4 { return "Measured Analyst" }
        if p < 0.6 { return "Balanced" }
        if p < 0.8 { return "Energetic" }
        return "Full Broadcaster"
    }

    private var canStart: Bool {
        !apiKey.isEmpty && !topic.isEmpty
    }

    // MARK: - Actions

    private func validateKey() {
        guard !apiKey.isEmpty else { return }
        isValidating = true
        engine.configure(apiKey: apiKey)
        keyIsValid = true
        isValidating = false
        engine.fetchModels()
    }

    private func startDebate() {
        engine.configure(apiKey: apiKey)

        let models = engine.availableModels
        let findModel = { (id: String) -> ModelIdentifier? in
            models.first { $0.id == id }
        }

        guard let modelA = findModel(selectedModelA),
              let modelB = findModel(selectedModelB),
              let judge = findModel(selectedJudge) else {
            return
        }

        let commentator: ModelIdentifier? = commentaryEnabled ? findModel(selectedCommentator) : nil

        engine.startDebate(
            topic: topic,
            modelA: modelA,
            modelB: modelB,
            judgeModel: judge,
            commentatorModel: commentator
        )
    }
}
