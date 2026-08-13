import Foundation

protocol SnapJournalClient: Sendable {
    func fetchToday() async throws -> TodaySnapSummary
    func record(_ command: SnapRecordCommand) async throws -> SnapRecordReceipt
}

enum SnapJournalClientError: Error {
    case unavailable
}

struct UnavailableSnapJournalClient: SnapJournalClient {
    func fetchToday() async throws -> TodaySnapSummary {
        throw SnapJournalClientError.unavailable
    }

    func record(_ command: SnapRecordCommand) async throws -> SnapRecordReceipt {
        throw SnapRecordError.transportFailure
    }
}

actor URLSessionSnapJournalClient: SnapJournalClient {
    private let baseURL: URL
    private let session: URLSession
    private let accessToken: @Sendable () async throws -> String
    private let sessionRejected: @Sendable (String) async -> Void

    init(
        baseURL: URL,
        session: URLSession = .shared,
        accessToken: @escaping @Sendable () async throws -> String,
        sessionRejected: @escaping @Sendable (String) async -> Void
    ) {
        self.baseURL = baseURL
        self.session = session
        self.accessToken = accessToken
        self.sessionRejected = sessionRejected
    }

    func fetchToday() async throws -> TodaySnapSummary {
        throw SnapJournalClientError.unavailable
    }

    func record(_ command: SnapRecordCommand) async throws -> SnapRecordReceipt {
        let body: Data
        do {
            body = try JSONEncoder().encode(command)
        } catch {
            throw SnapRecordError.malformedResponse
        }

        let firstToken = try await tokenForRequest()
        do {
            return try await send(body: body, token: firstToken, expected: command)
        } catch let unauthorized as UnauthorizedResponse {
            let correlationID = unauthorized.correlationID
            await sessionRejected(firstToken)
            let retryToken: String
            do {
                retryToken = try await tokenForRequest()
            } catch {
                throw SnapRecordError.sessionRejected(correlationID: correlationID)
            }
            guard retryToken != firstToken else {
                throw SnapRecordError.sessionRejected(correlationID: correlationID)
            }
            do {
                return try await send(body: body, token: retryToken, expected: command)
            } catch let retryError as UnauthorizedResponse {
                await sessionRejected(retryToken)
                throw SnapRecordError.sessionRejected(correlationID: retryError.correlationID)
            }
        }
    }

    private func tokenForRequest() async throws -> String {
        do {
            return try await accessToken()
        } catch AuthenticationClientError.sessionRejected {
            throw SnapRecordError.sessionRejected(correlationID: nil)
        } catch {
            throw SnapRecordError.transportFailure
        }
    }

    private func send(
        body: Data,
        token: String,
        expected command: SnapRecordCommand
    ) async throws -> SnapRecordReceipt {
        var request = URLRequest(url: baseURL.appending(path: "/api/v1/snaps"))
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SnapRecordError.transportFailure
        }
        guard let response = response as? HTTPURLResponse else {
            throw SnapRecordError.malformedResponse
        }

        switch response.statusCode {
        case 201:
            let receipt = try decodeReceipt(data)
            guard receipt.category == command.category,
                  receipt.amountWon == command.amountWon,
                  receipt.localDay == command.localDay else {
                throw SnapRecordError.malformedResponse
            }
            return receipt
        case 400:
            let envelope = try decodeError(data, expectedCode: "INVALID_REQUEST")
            throw SnapRecordError.invalidRequest(correlationID: envelope.correlationId)
        case 401:
            let envelope = try decodeError(data, expectedCode: "SESSION_REJECTED")
            throw UnauthorizedResponse(correlationID: envelope.correlationId)
        case 409:
            let envelope = try decodeError(data, expectedCode: "MUTATION_CONFLICT")
            throw SnapRecordError.mutationConflict(correlationID: envelope.correlationId)
        case 500...599:
            let envelope = try? decodeError(data, expectedCode: "INTERNAL_ERROR")
            throw SnapRecordError.serverFailure(correlationID: envelope?.correlationId)
        default:
            throw SnapRecordError.malformedResponse
        }
    }

    private func decodeReceipt(_ data: Data) throws -> SnapRecordReceipt {
        guard hasExactKeys(
            data,
            expected: ["id", "category", "amountWon", "localDay", "createdAt"]
        ) else {
            throw SnapRecordError.malformedResponse
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom(Self.decodeInstant)
            let response = try decoder.decode(ReceiptResponse.self, from: data)
            guard (1...999_999_999).contains(response.amountWon),
                  Self.isValidLocalDay(response.localDay) else {
                throw SnapRecordError.malformedResponse
            }
            return SnapRecordReceipt(
                id: response.id,
                category: response.category,
                amountWon: response.amountWon,
                localDay: response.localDay,
                createdAt: response.createdAt
            )
        } catch let error as SnapRecordError {
            throw error
        } catch {
            throw SnapRecordError.malformedResponse
        }
    }

    private func decodeError(_ data: Data, expectedCode: String) throws -> ErrorEnvelope {
        guard hasExactKeys(data, expected: ["code", "correlationId"]) else {
            throw SnapRecordError.malformedResponse
        }
        guard
            let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data),
            envelope.code == expectedCode,
            !envelope.correlationId.isEmpty
        else {
            throw SnapRecordError.malformedResponse
        }
        return envelope
    }

    private func hasExactKeys(_ data: Data, expected: Set<String>) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return Set(object.keys) == expected
    }

    private static func decodeInstant(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        for options: ISO8601DateFormatter.Options in [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime]
        ] {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = options
            if let date = formatter.date(from: value) { return date }
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected an ISO 8601 instant"
        )
    }

    private static func isValidLocalDay(_ value: String) -> Bool {
        guard value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else {
            return false
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value) else { return false }
        return formatter.string(from: date) == value
    }

    private struct ReceiptResponse: Decodable {
        let id: UUID
        let category: SnapCategory
        let amountWon: Int64
        let localDay: String
        let createdAt: Date
    }

    private struct ErrorEnvelope: Decodable {
        let code: String
        let correlationId: String
    }

    private struct UnauthorizedResponse: Error {
        let correlationID: String
    }
}
