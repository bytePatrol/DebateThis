import Foundation
import OpenAI

// Thin wrapper around MacPaw/OpenAI pointed at OpenRouter.
// Handles streaming, custom headers, and error translation.

actor OpenRouterService {
    private let client: OpenAI
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
        let config = OpenAI.Configuration(
            token: apiKey,
            host: "openrouter.ai",
            basePath: "/api/v1",
            customHeaders: [
                "HTTP-Referer": "https://github.com/debatethis",
                "X-Title": "DebateThis",
            ]
        )
        self.client = OpenAI(configuration: config)
    }

    // MARK: - Streaming Chat Completion

    /// Streams a chat completion from the specified model.
    /// Returns an AsyncThrowingStream that yields content delta strings.
    func streamCompletion(
        messages: [ChatQuery.ChatCompletionMessageParam],
        model: String,
        maxCompletionTokens: Int = 800
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let query = ChatQuery(
                        messages: messages,
                        model: model,
                        maxCompletionTokens: maxCompletionTokens
                    )

                    let stream: AsyncThrowingStream<ChatStreamResult, Error> = client.chatsStream(query: query)

                    for try await result in stream {
                        if Task.isCancelled { break }
                        if let content = result.choices.first?.delta.content {
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch {
                    if !Task.isCancelled {
                        continuation.finish(throwing: OpenRouterError.streamFailed(error.localizedDescription))
                    } else {
                        continuation.finish()
                    }
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Fetch Available Models

    func fetchModels() async throws -> [ModelIdentifier] {
        let result = try await client.models()
        return result.data
            .map { model in
                ModelIdentifier(
                    id: model.id,
                    displayName: model.id.components(separatedBy: "/").last?.replacingOccurrences(of: "-", with: " ").capitalized ?? model.id,
                    provider: model.id.components(separatedBy: "/").first?.capitalized ?? "Unknown"
                )
            }
            .sorted { $0.provider < $1.provider }
    }
}

// MARK: - Errors

enum OpenRouterError: LocalizedError {
    case streamFailed(String)

    var errorDescription: String? {
        switch self {
        case .streamFailed(let reason):
            return "Stream failed: \(reason)"
        }
    }
}
