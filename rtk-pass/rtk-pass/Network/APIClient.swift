import Dependencies
import Foundation
import os

struct APIClient: Sendable {
    var send: @Sendable (_ endpoint: Endpoint) async throws -> Data
}

extension APIClient {
    private static let sensitiveFieldNames: Set<String> = [
        "access_token", "accesstoken", "api_key", "apikey", "authorization", "cookie",
        "password", "pwd", "refresh_token", "refreshtoken", "secret", "set-cookie", "token"
    ]

    private static let maxBodyPreviewLength = 512

    struct Endpoint: Sendable {
        let path: String
        let method: HTTPMethod
        let body: Data?
        let bearerToken: String?

        init(path: String, method: HTTPMethod, body: Data? = nil, bearerToken: String? = nil) {
            self.path = path
            self.method = method
            self.body = body
            self.bearerToken = bearerToken
        }
    }

    enum HTTPMethod: String, Sendable {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    static func live(baseURL: URL) -> APIClient {
        let logger = Logger(subsystem: "dgtu-ios", category: "APIClient")
        return APIClient(send: { endpoint in
            var request = URLRequest(url: baseURL.appending(path: endpoint.path))
            request.httpMethod = endpoint.method.rawValue
            request.httpBody = endpoint.body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token = endpoint.bearerToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let requestId = UUID().uuidString
            let startedAt = Date()
            let requestHeaders = await redactHeaders(request.allHTTPHeaderFields ?? [:])
            let requestBodySize = endpoint.body?.count ?? 0
            let requestBodyPreview = await redactBodyPreview(endpoint.body)
            let query = await safeQueryString(from: request.url)
            logger.info("\("network.request.started id=\(requestId) method=\(endpoint.method.rawValue) path=\(endpoint.path) query=\(query) headers=\(requestHeaders) bodySize=\(requestBodySize) bodyPreview=\(requestBodyPreview)", privacy: .public)")

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                let durationMs = await durationMilliseconds(since: startedAt)
                let details = await describe(error: error)
                logger.error("\("network.request.failed id=\(requestId) method=\(endpoint.method.rawValue) path=\(endpoint.path) durationMs=\(durationMs) kind=transport details=\(details)", privacy: .public)")
                throw error
            }

            guard let http = response as? HTTPURLResponse else {
                let durationMs = await durationMilliseconds(since: startedAt)
                logger.error("\("network.request.failed id=\(requestId) method=\(endpoint.method.rawValue) path=\(endpoint.path) durationMs=\(durationMs) kind=invalidResponse details=Non-HTTP response", privacy: .public)")
                throw AuthError.invalidResponse
            }

            let durationMs = await durationMilliseconds(since: startedAt)
            let responseHeaders = await redactHeaders(await http.headersAsStringMap)
            let responseBodyPreview = await redactBodyPreview(data)
            logger.info("\("network.response.received id=\(requestId) method=\(endpoint.method.rawValue) path=\(endpoint.path) status=\(http.statusCode) durationMs=\(durationMs) bodySize=\(data.count) headers=\(responseHeaders) bodyPreview=\(responseBodyPreview)", privacy: .public)")

            guard (200 ... 299).contains(http.statusCode) else {
                if http.statusCode == 401 {
                    logger.error("\("network.request.failed id=\(requestId) method=\(endpoint.method.rawValue) path=\(endpoint.path) durationMs=\(durationMs) kind=unauthorized status=\(http.statusCode)", privacy: .public)")
                    throw AuthError.unauthorized
                }
                if http.statusCode == 404, endpoint.path == "/auth/refresh" {
                    logger.error("\("network.request.failed id=\(requestId) method=\(endpoint.method.rawValue) path=\(endpoint.path) durationMs=\(durationMs) kind=refreshUnavailable status=\(http.statusCode)", privacy: .public)")
                    throw AuthError.refreshUnavailable
                }
                if http.statusCode == 422,
                   let validation = try? JSONDecoder().decode(APIValidationErrorResponse.self, from: data),
                   let firstMessage = validation.detail.first?.msg {
                    logger.error("\("network.request.failed id=\(requestId) method=\(endpoint.method.rawValue) path=\(endpoint.path) durationMs=\(durationMs) kind=validation status=\(http.statusCode) details=\(firstMessage)", privacy: .public)")
                    throw AuthError.validation(firstMessage)
                }
                logger.error("\("network.request.failed id=\(requestId) method=\(endpoint.method.rawValue) path=\(endpoint.path) durationMs=\(durationMs) kind=httpStatus status=\(http.statusCode)", privacy: .public)")
                throw AuthError.network("Server error: \(http.statusCode)")
            }

            return data
        })
    }
}

private extension APIClient {
    static func durationMilliseconds(since date: Date) -> Int {
        Int(Date().timeIntervalSince(date) * 1_000)
    }

    static func safeQueryString(from url: URL?) -> String {
        guard
            let url,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let items = components.queryItems,
            !items.isEmpty
        else {
            return "-"
        }

        let redactedItems = items.map { item -> String in
            let key = item.name
            let value = (isSensitiveField(key) ? "[REDACTED]" : (item.value ?? ""))
            return "\(key)=\(value)"
        }
        return redactedItems.joined(separator: "&")
    }

    static func redactHeaders(_ headers: [String: String]) -> String {
        guard !headers.isEmpty else { return "-" }
        let sanitized = headers
            .sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending })
            .map { key, value in
                "\(key)=\(isSensitiveField(key) ? "[REDACTED]" : truncate(value, maxLength: 128))"
            }
            .joined(separator: ";")
        return truncate(sanitized, maxLength: 512)
    }

    static func redactBodyPreview(_ body: Data?) -> String {
        guard let body, !body.isEmpty else { return "-" }

        if
            let object = try? JSONSerialization.jsonObject(with: body),
            let redactedObject = redactJSONValue(object),
            let redactedData = try? JSONSerialization.data(withJSONObject: redactedObject, options: [.sortedKeys]),
            let redactedString = String(data: redactedData, encoding: .utf8)
        {
            return truncate(redactedString, maxLength: maxBodyPreviewLength)
        }

        let plainText = String(data: body, encoding: .utf8) ?? "<\(body.count) bytes binary>"
        return truncate(plainText, maxLength: maxBodyPreviewLength)
    }

    static func redactBodyPreview(_ body: Data) -> String {
        redactBodyPreview(Optional(body))
    }

    static func redactJSONValue(_ value: Any, parentKey: String? = nil) -> Any? {
        if let dictionary = value as? [String: Any] {
            var output: [String: Any] = [:]
            for (key, nestedValue) in dictionary {
                if isSensitiveField(key) {
                    output[key] = "[REDACTED]"
                } else if let redactedNested = redactJSONValue(nestedValue, parentKey: key) {
                    output[key] = redactedNested
                }
            }
            return output
        }

        if let array = value as? [Any] {
            return array.compactMap { redactJSONValue($0, parentKey: parentKey) }
        }

        if let parentKey, isSensitiveField(parentKey) {
            return "[REDACTED]"
        }

        return value
    }

    static func truncate(_ value: String, maxLength: Int) -> String {
        guard value.count > maxLength else { return value }
        let prefix = value.prefix(maxLength)
        return "\(prefix)..."
    }

    static func isSensitiveField(_ key: String) -> Bool {
        let normalized = key.lowercased().replacingOccurrences(of: "-", with: "")
        return sensitiveFieldNames.contains(normalized)
    }

    static func describe(error: Error) -> String {
        if let urlError = error as? URLError {
            return "URLError(\(urlError.code.rawValue)): \(urlError.localizedDescription)"
        }
        if let decodingError = error as? DecodingError {
            return "DecodingError: \(String(describing: decodingError))"
        }
        if let authError = error as? AuthError {
            return "AuthError: \(authError.errorDescription ?? String(describing: authError))"
        }
        return String(describing: error)
    }
}

private extension HTTPURLResponse {
    var headersAsStringMap: [String: String] {
        allHeaderFields.reduce(into: [String: String]()) { partialResult, entry in
            let key = String(describing: entry.key)
            let value = String(describing: entry.value)
            partialResult[key] = value
        }
    }
}

extension APIClient: DependencyKey {
    static let liveValue: APIClient = {
        // Default local backend URL can be overridden in tests/previews.
        APIClient.live(baseURL: URL(string: "https://dstu.devoriole.ru")!)
    }()

    static let testValue = APIClient(send: { _ in Data() })
}

extension DependencyValues {
    var apiClient: APIClient {
        get { self[APIClient.self] }
        set { self[APIClient.self] = newValue }
    }
}
