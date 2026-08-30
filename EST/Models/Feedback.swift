import Foundation
import UIKit

/// The small JSON contract used by the in-app feedback form.
///
/// Feedback is intentionally separate from anonymous diagnostics: sending a
/// message does not require diagnostics consent and the message is not added
/// to the weekly telemetry batch.
struct ESTFeedbackPayload: Codable, Equatable, Sendable {
    struct App: Codable, Equatable, Sendable {
        let version: String
        let build: String
        let iOSMajor: Int
        let deviceFamily: String

        enum CodingKeys: String, CodingKey {
            case version, build
            case iOSMajor = "ios_major"
            case deviceFamily = "device_family"
        }
    }

    let schema: Int
    let product: String
    let message: String
    let app: App

    init(
        schema: Int = 1,
        product: String = "est",
        message: String,
        app: App
    ) {
        self.schema = schema
        self.product = product
        self.message = message
        self.app = app
    }
}

enum ESTFeedbackService {
    enum FeedbackError: LocalizedError {
        case invalidMessage
        case unavailable
        case deliveryFailed

        var errorDescription: String? {
            switch self {
            case .invalidMessage:
                "Write a message before sending feedback."
            case .unavailable, .deliveryFailed:
                "Feedback could not be sent right now. Please try again."
            }
        }
    }

    static let endpointKey = "estFeedbackEndpoint"
    static let endpointInfoKey = "ESTFeedbackEndpoint"
    static let defaultEndpoint = "https://est-telemetry.envisioning.workers.dev/v1/feedback"
    static let maxMessageLength = 5_000
    private static let requestBodyLimit = 12_000

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 15
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    static var endpoint: URL? {
        let infoEndpoint = (Bundle.main.object(
            forInfoDictionaryKey: endpointInfoKey
        ) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = UserDefaults.standard.string(forKey: endpointKey)
            ?? (infoEndpoint?.isEmpty == false ? infoEndpoint : nil)
            ?? defaultEndpoint
        guard let url = URL(string: raw),
              url.scheme == "https"
                || (url.scheme == "http"
                    && (url.host == "127.0.0.1" || url.host == "localhost"))
        else { return nil }
        return url
    }

    static func normalizedMessage(_ message: String) -> String {
        let normalized = message
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return String(
            normalized.trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(maxMessageLength)
        )
    }

    @MainActor
    static func send(message: String) async throws {
        let message = normalizedMessage(message)
        guard !message.isEmpty else { throw FeedbackError.invalidMessage }
        guard let endpoint else { throw FeedbackError.unavailable }

        let payload = ESTFeedbackPayload(
            message: message,
            app: .init(
                version: Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleShortVersionString"
                ) as? String ?? "unknown",
                build: Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleVersion"
                ) as? String ?? "unknown",
                iOSMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
                deviceFamily: UIDevice.current.userInterfaceIdiom == .pad
                    ? "ipad"
                    : "iphone"
            )
        )
        guard let body = try? JSONEncoder().encode(payload),
              body.count <= requestBodyLimit
        else { throw FeedbackError.invalidMessage }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "X-EST-Feedback-Schema")
        request.httpBody = body

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode)
            else { throw FeedbackError.deliveryFailed }
        } catch let error as FeedbackError {
            throw error
        } catch {
            throw FeedbackError.deliveryFailed
        }
    }
}
