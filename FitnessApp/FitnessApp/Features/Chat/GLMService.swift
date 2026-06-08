import Foundation
// NOTE: This file must NEVER import SwiftUI (architectural constraint).

// MARK: - Request / Response Models

struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessagePayload]
}

struct ChatMessagePayload: Codable {
    let role: String   // "system" | "user" | "assistant"
    let content: String
}

struct ChatResponse: Decodable {
    let choices: [ChatChoice]
}

struct ChatChoice: Decodable {
    let message: ChatMessagePayload
}

// MARK: - ChatMessage → Payload Mapping

extension ChatMessage {
    var asPayload: ChatMessagePayload {
        ChatMessagePayload(role: role.rawValue, content: content)
    }
}

// MARK: - DeepSeekService

/// Pure networking struct for the DeepSeek API (OpenAI-compatible REST).
/// Contains no SwiftUI dependency so it can be unit-tested in isolation.
struct DeepSeekService {

    static let endpoint = URL(string: "https://api.deepseek.com/v1/chat/completions")!
    static let model = "deepseek-chat"
    static let timeoutSeconds: TimeInterval = 30
    static let maxRetries = 2
    static let retryBaseDelay: TimeInterval = 1.5

    // MARK: - Errors

    enum ChatAPIError: LocalizedError {
        case missingAPIKey
        case httpError(Int)
        case decodingFailed
        case timeout
        case networkError(Error)
        case rateLimited(retryAfter: Int?)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "DeepSeek API key not configured."
            case .httpError(let code):
                return "Request failed (\(code)). \(code == 401 ? "Invalid API key." : "Please try again.")"
            case .decodingFailed:
                return "Failed to parse AI response."
            case .timeout:
                return "Request timed out. Please try again."
            case .networkError(let error):
                return error.localizedDescription
            case .rateLimited(let seconds):
                if let s = seconds {
                    return "Too many requests. Retry after \(s)s."
                }
                return "Too many requests. Please wait a moment."
            }
        }

        /// Whether this error is worth retrying automatically.
        var isRetryable: Bool {
            switch self {
            case .timeout, .networkError: return true
            case .httpError(let code): return code >= 500 || code == 429
            default: return false
            }
        }
    }

    // MARK: - URLSession

    /// Injectable session for testing; defaults to a session configured with a 30s request timeout.
    let session: URLSession

    init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = DeepSeekService.timeoutSeconds
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Send (with retry)

    /// Sends a conversation to the DeepSeek API and returns the assistant reply text.
    /// Automatically retries up to `maxRetries` times for transient failures.
    /// - Parameters:
    ///   - messages: The full ordered message list (system prompt first, then turns).
    ///   - apiKey: The Bearer token loaded from Info.plist.
    /// - Returns: The assistant's reply text from `choices[0].message.content`.
    func sendMessage(messages: [ChatMessage], apiKey: String) async throws -> String {
        var lastError: ChatAPIError = .missingAPIKey

        for attempt in 0...Self.maxRetries {
            if attempt > 0 {
                // Exponential backoff: 1.5s, 3s
                let multiplier = pow(2.0, Double(attempt - 1))
                let delay = Self.retryBaseDelay * multiplier
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            do {
                return try await sendOnce(messages: messages, apiKey: apiKey)
            } catch let error as ChatAPIError {
                lastError = error
                guard error.isRetryable, attempt < Self.maxRetries else { throw error }
                continue
            } catch {
                throw ChatAPIError.networkError(error)
            }
        }

        throw lastError
    }

    // MARK: - Single send (no retry)

    private func sendOnce(messages: [ChatMessage], apiKey: String) async throws -> String {
        var request = URLRequest(url: DeepSeekService.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = DeepSeekService.timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload = ChatRequest(
            model: DeepSeekService.model,
            messages: messages.map { $0.asPayload }
        )

        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            throw ChatAPIError.decodingFailed
        }

        let data: Data
        let httpResponse: HTTPURLResponse
        do {
            let (d, r) = try await session.data(for: request)
            data = d
            guard let hr = r as? HTTPURLResponse else { throw ChatAPIError.decodingFailed }
            httpResponse = hr
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw ChatAPIError.timeout
        } catch {
            throw ChatAPIError.networkError(error)
        }

        // Handle rate limiting
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
            let seconds = retryAfter.flatMap(Int.init)
            throw ChatAPIError.rateLimited(retryAfter: seconds)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ChatAPIError.httpError(httpResponse.statusCode)
        }

        let decoded: ChatResponse
        do {
            decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            throw ChatAPIError.decodingFailed
        }

        guard let reply = decoded.choices.first?.message.content else {
            throw ChatAPIError.decodingFailed
        }

        return reply
    }
}