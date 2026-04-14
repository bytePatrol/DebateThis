import SwiftUI

struct SetupView: View {
    @Bindable var engine: DebateEngine
    @AppStorage("openRouterAPIKey") private var apiKey: String = ""
    @State private var topic: String = ""
    @State private var selectedModelA: String = "anthropic/claude-sonnet-4"
    @State private var selectedModelB: String = "openai/gpt-4o"
    @State private var selectedJudge: String = "google/gemini-2.5-pro"
    @State private var isValidating: Bool = false
    @State private var keyIsValid: Bool? = nil

    private let suggestedTopics = [
        "Should AI systems be granted legal personhood?",
        "Is social media a net positive for society?",
        "Should pineapple go on pizza?",
        "Is remote work better than in-office work?",
        "Should college education be free?",
        "Is space exploration worth the cost?",
        "Are electric vehicles truly better for the environment?",
        "Should voting be mandatory?",
    ]

    var body: some View {
        VStack(spacing: 0) {
            // API Key section
            apiKeySection

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    topicSection
                    modelSection
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
                .onChange(of: apiKey) { _, _ in
                    keyIsValid = nil
                }

            if isValidating {
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
    }

    // MARK: - Topic

    private var topicSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEBATE TOPIC")
                .font(.caption)
                .foregroundStyle(.secondary)
                .tracking(1.5)

            TextField("Enter a topic to debate...", text: $topic, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestedTopics, id: \.self) { suggestion in
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

    // MARK: - Model Selection

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MODELS")
                .font(.caption)
                .foregroundStyle(.secondary)
                .tracking(1.5)

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

    private func modelPicker(title: String, accent: Color, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(accent)

            Picker("", selection: selection) {
                ForEach(AvailableModels.all) { model in
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

    private var canStart: Bool {
        !apiKey.isEmpty && !topic.isEmpty
    }

    // MARK: - Actions

    private func validateKey() {
        guard !apiKey.isEmpty else { return }
        isValidating = true
        engine.configure(apiKey: apiKey)
        // Simple validation: just check non-empty for now.
        // Real validation would call OpenRouter, but that costs tokens.
        keyIsValid = true
        isValidating = false
    }

    private func startDebate() {
        engine.configure(apiKey: apiKey)

        guard let modelA = AvailableModels.model(for: selectedModelA),
              let modelB = AvailableModels.model(for: selectedModelB),
              let judge = AvailableModels.model(for: selectedJudge) else {
            return
        }

        engine.startDebate(
            topic: topic,
            modelA: modelA,
            modelB: modelB,
            judgeModel: judge
        )
    }
}
