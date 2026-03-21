import Foundation

struct QRPass: Equatable, Sendable {
    let token: String
    let status: String
    let expiresAt: Date

    var payload: String { token }
}

struct PassResponse: Decodable, Sendable {
    let qrToken: String
    let status: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case qrToken = "qr_token"
        case status
        case expiresAt = "expires_at"
    }

    func toDomain() throws -> QRPass {
        guard let parsedDate = ISO8601DateParser.parse(expiresAt) else {
            throw QRError.invalidResponse
        }
        return QRPass(token: qrToken, status: status, expiresAt: parsedDate)
    }
}

enum QRError: Error, LocalizedError, Equatable, Sendable {
    case invalidResponse
    case generationFailed
    case unauthorized
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Unexpected QR response from server."
        case .generationFailed:
            return "Failed to generate a QR code. Try again."
        case .unauthorized:
            return "Session expired. Please sign in again."
        case let .network(message):
            return message
        }
    }
}

enum ISO8601DateParser {
    private static let formatters: [ISO8601DateFormatter] = {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        return [withFractional, plain]
    }()

    static func parse(_ value: String) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}
