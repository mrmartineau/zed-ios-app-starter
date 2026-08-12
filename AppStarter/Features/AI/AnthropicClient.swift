import Foundation

/// A small streaming client for the Claude Messages API
/// (`POST /v1/messages`), written against `URLSession` because there is no
/// official Anthropic SDK for Swift.
///
/// ## ⚠️ Do not ship an API key inside the app
///
/// Anything bundled with an iOS app — a constant, a plist entry, an obfuscated
/// blob, a Keychain item written at first launch — can be extracted from the
/// binary or the device. A leaked Anthropic key is billed to your account until
/// you notice and rotate it.
///
/// So this client has two modes:
///
/// - `.direct` sends `x-api-key` straight to `api.anthropic.com`. Fine for
///   development on your own device. **Not** for the App Store.
/// - `.proxy` sends the request to a server you control, which holds the key,
///   adds it server-side, and forwards to Anthropic. That server is also where
///   per-user rate limiting, auth and abuse controls belong.
///
/// The wire format is identical either way, so the only production change is
/// which `Configuration` you construct.
///
/// ## Wire-format notes
///
/// - `anthropic-version: 2023-06-01` is required on every request.
/// - Streaming is Server-Sent Events; the text arrives as `content_block_delta`
///   events carrying a `text_delta`.
/// - A response can end with `stop_reason: "refusal"` — a **successful** HTTP
///   200 where the model declined. It is a normal outcome, not an error, and
///   must be handled before treating the accumulated text as a complete answer.
struct AnthropicClient: Sendable {
    // MARK: - Configuration

    enum Configuration: Sendable {
        /// Talks to Anthropic directly with an API key. Development only.
        case direct(apiKey: String)

        /// Talks to your own backend, which holds the key.
        /// `headers` is where a user session token goes.
        case proxy(url: URL, headers: [String: String])

        var endpoint: URL {
            switch self {
            case .direct:
                URL(string: "https://api.anthropic.com/v1/messages")!
            case .proxy(let url, _):
                url
            }
        }

        var headers: [String: String] {
            switch self {
            case .direct(let apiKey):
                [
                    "content-type": "application/json",
                    "x-api-key": apiKey,
                    "anthropic-version": "2023-06-01",
                ]
            case .proxy(_, let headers):
                headers.merging(["content-type": "application/json"]) { current, _ in current }
            }
        }
    }

    /// How hard the model works before answering.
    ///
    /// The API default is `high`. `medium` is the default here because a chat
    /// UI makes latency very visible; raise it for work where the answer's
    /// quality matters more than the wait, and drop to `low` for simple
    /// lookups and classification.
    enum Effort: String, Sendable {
        case low, medium, high, xhigh, max
    }

    var configuration: Configuration

    /// Claude Opus 5. Change this in one place to move the whole app.
    var model = "claude-opus-5"

    /// A hard ceiling on the response, covering thinking *and* visible text —
    /// thinking is on by default on Opus 5, so a tight budget can truncate an
    /// answer mid-sentence. Raise it for long-form output.
    var maxTokens = 8192

    var effort: Effort = .medium

    /// Steers tone and behaviour across the whole conversation.
    var systemPrompt: String?

    // MARK: - Types

    struct Message: Sendable, Equatable {
        enum Role: String, Sendable { case user, assistant }
        var role: Role
        var text: String
    }

    /// What the caller sees while a response streams in.
    enum Event: Sendable {
        /// A chunk of visible text. Append these in order.
        case text(String)
        /// The turn finished. `stopReason` is `"end_turn"` normally,
        /// `"max_tokens"` if it ran out of room, `"refusal"` if the model
        /// declined.
        case finished(stopReason: String?)
    }

    enum ClientError: LocalizedError {
        case notConfigured
        case http(status: Int, body: String)
        case api(message: String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                "No API key set. Add one in the assistant screen to try this out."
            case .http(let status, let body):
                "The request failed (\(status)). \(body)"
            case .api(let message):
                message
            }
        }
    }

    // MARK: - Streaming

    /// Streams a reply to `messages`, yielding text as it arrives.
    ///
    /// Cancelling the returned stream's consuming task cancels the request.
    func stream(messages: [Message]) -> AsyncThrowingStream<Event, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(messages: messages) { event in
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(
        messages: [Message],
        emit: @Sendable (Event) -> Void
    ) async throws {
        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        for (field, value) in configuration.headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body(for: messages))

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            // Errors come back as a normal JSON body, not SSE — drain it so the
            // message can be surfaced instead of a bare status code.
            var text = ""
            for try await line in bytes.lines { text += line }
            throw ClientError.http(status: http.statusCode, body: Self.errorMessage(from: text) ?? text)
        }

        var stopReason: String?

        for try await line in bytes.lines {
            try Task.checkCancellation()

            // SSE frames are `event: <name>` then `data: <json>`. The event name
            // is duplicated inside the JSON as `type`, so only `data:` matters.
            guard line.hasPrefix("data:") else { continue }

            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard !payload.isEmpty,
                  let data = payload.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = object["type"] as? String
            else { continue }

            switch type {
            case "content_block_delta":
                // `thinking_delta` blocks also arrive here when thinking is
                // displayed; only `text_delta` is the visible answer.
                if let delta = object["delta"] as? [String: Any],
                   delta["type"] as? String == "text_delta",
                   let text = delta["text"] as? String {
                    emit(.text(text))
                }

            case "message_delta":
                if let delta = object["delta"] as? [String: Any],
                   let reason = delta["stop_reason"] as? String {
                    stopReason = reason
                }

            case "error":
                let message = (object["error"] as? [String: Any])?["message"] as? String
                throw ClientError.api(message: message ?? "The assistant returned an error.")

            default:
                // `message_start`, `content_block_start`, `ping`, `message_stop`
                // and anything added later — nothing to do.
                break
            }
        }

        emit(.finished(stopReason: stopReason))
    }

    private func body(for messages: [Message]) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "stream": true,
            // Nested inside output_config, not top-level.
            "output_config": ["effort": effort.rawValue],
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.text] },
        ]

        if let systemPrompt, !systemPrompt.isEmpty {
            body["system"] = systemPrompt
        }

        return body
    }

    /// Pulls `error.message` out of a non-200 JSON body, if it's there.
    private static func errorMessage(from text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = object["error"] as? [String: Any]
        else { return nil }
        return error["message"] as? String
    }
}

extension AnthropicClient {
    /// Where the development key lives. See the warning at the top of the file
    /// before considering this for a shipping build.
    static let apiKeyKeychainKey = "anthropic-api-key"

    /// Builds a client from the locally stored development key, or throws if
    /// there isn't one.
    ///
    /// Swap this for a `.proxy` configuration pointing at your backend when the
    /// app goes anywhere near the App Store.
    static func development() throws -> AnthropicClient {
        guard let key = KeychainStore.string(for: apiKeyKeychainKey), !key.isEmpty else {
            throw ClientError.notConfigured
        }
        return AnthropicClient(configuration: .direct(apiKey: key))
    }
}
