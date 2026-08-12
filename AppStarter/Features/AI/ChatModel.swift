import Foundation

/// Conversation state for `AIChatView`.
///
/// The transcript is the request body: the Messages API is stateless, so every
/// turn resends the whole history. Trim `messages` if a conversation is allowed
/// to run long enough to matter.
@Observable
@MainActor
final class ChatModel {
    /// One entry per turn, in order. The in-flight assistant reply is the last
    /// element and grows as chunks arrive.
    private(set) var messages: [AnthropicClient.Message] = []

    private(set) var isStreaming = false
    private(set) var errorMessage: String?

    /// Set when the model declined to answer — a normal outcome, shown
    /// differently from a network failure.
    private(set) var wasRefused = false

    var draft = ""

    /// Sensible default; edit or remove to change the assistant's behaviour.
    var systemPrompt = "You are a helpful assistant inside an iOS app. Keep answers brief and concrete."

    private var streamTask: Task<Void, Never>?

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        draft = ""
        errorMessage = nil
        wasRefused = false
        messages.append(.init(role: .user, text: text))

        // An empty assistant turn is appended immediately so the view can show
        // a bubble filling in, rather than nothing until the first chunk.
        messages.append(.init(role: .assistant, text: ""))
        isStreaming = true

        let history = Array(messages.dropLast())

        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                let client = try AnthropicClient.development()
                var configured = client
                configured.systemPrompt = self.systemPrompt

                for try await event in configured.stream(messages: history) {
                    switch event {
                    case .text(let chunk):
                        self.appendToReply(chunk)

                    case .finished(let stopReason):
                        // A refusal arrives as a successful response with no
                        // useful content, so it has to be checked explicitly.
                        if stopReason == "refusal" {
                            self.wasRefused = true
                            self.dropEmptyReply()
                        } else if stopReason == "max_tokens" {
                            self.errorMessage = "The reply was cut off — raise maxTokens in AnthropicClient."
                        }
                    }
                }
            } catch {
                self.errorMessage = error.localizedDescription
                self.dropEmptyReply()
            }

            self.isStreaming = false
        }
    }

    /// Stops the current reply, keeping whatever text already arrived.
    func stop() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        dropEmptyReply()
    }

    func clear() {
        stop()
        messages.removeAll()
        errorMessage = nil
        wasRefused = false
    }

    private func appendToReply(_ chunk: String) {
        guard let last = messages.indices.last, messages[last].role == .assistant else { return }
        messages[last].text += chunk
    }

    /// Removes the placeholder assistant turn when nothing was ever written to
    /// it, so a failed request doesn't leave an empty bubble behind.
    private func dropEmptyReply() {
        if let last = messages.indices.last,
           messages[last].role == .assistant,
           messages[last].text.isEmpty {
            messages.removeLast()
        }
    }
}
