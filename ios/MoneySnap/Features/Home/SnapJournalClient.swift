import Foundation

protocol SnapJournalClient: Sendable {
    func fetchToday() async throws -> TodaySnapSummary
    func record(_ command: SnapRecordCommand) async throws -> SnapRecordReceipt
    func get(_ snapID: UUID) async throws -> SnapDetail
    func revise(snapID: UUID, command: SnapReviseCommand) async throws -> SnapDetail
    func delete(snapID: UUID, mutationID: String) async throws
    func archive(from: String, to: String, cursor: String?) async throws -> ArchivePage
}

enum SnapJournalClientError: Error {
    case unavailable
}

extension SnapJournalClient {
    func get(_ snapID: UUID) async throws -> SnapDetail {
        throw SnapJournalClientError.unavailable
    }

    func revise(snapID: UUID, command: SnapReviseCommand) async throws -> SnapDetail {
        throw SnapJournalClientError.unavailable
    }

    func delete(snapID: UUID, mutationID: String) async throws {
        throw SnapJournalClientError.unavailable
    }

    func archive(from: String, to: String, cursor: String?) async throws -> ArchivePage {
        throw SnapJournalClientError.unavailable
    }
}

struct UnavailableSnapJournalClient: SnapJournalClient {
    func fetchToday() async throws -> TodaySnapSummary {
        throw SnapJournalClientError.unavailable
    }

    func record(_ command: SnapRecordCommand) async throws -> SnapRecordReceipt {
        throw SnapRecordError.transportFailure
    }

    func get(_ snapID: UUID) async throws -> SnapDetail {
        throw SnapJournalClientError.unavailable
    }

    func revise(snapID: UUID, command: SnapReviseCommand) async throws -> SnapDetail {
        throw SnapJournalClientError.unavailable
    }

    func delete(snapID: UUID, mutationID: String) async throws {
        throw SnapJournalClientError.unavailable
    }

    func archive(from: String, to: String, cursor: String?) async throws -> ArchivePage {
        throw SnapJournalClientError.unavailable
    }
}

actor URLSessionSnapJournalClient: SnapJournalClient {
    private let baseURL: URL
    private let session: URLSession
    private let accessToken: @Sendable () async throws -> String
    private let sessionRejected: @Sendable (String) async -> Void
    private let now: @Sendable () -> Date
    private let timeZone: @Sendable () -> TimeZone

    init(
        baseURL: URL,
        session: URLSession = .shared,
        accessToken: @escaping @Sendable () async throws -> String,
        sessionRejected: @escaping @Sendable (String) async -> Void,
        now: @escaping @Sendable () -> Date = Date.init,
        timeZone: @escaping @Sendable () -> TimeZone = { .current }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.accessToken = accessToken
        self.sessionRejected = sessionRejected
        self.now = now
        self.timeZone = timeZone
    }

    func fetchToday() async throws -> TodaySnapSummary {
        guard let zoneIdentifier = Self.serverTimeZoneIdentifier(timeZone(), at: now()) else {
            throw SnapRecordError.invalidRequest(correlationID: "invalid-timezone")
        }
        var components = URLComponents(
            url: baseURL.appending(path: "/api/v1/snaps/today"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "timeZone", value: zoneIdentifier)]
        guard let url = components?.url else {
            throw SnapRecordError.malformedResponse
        }

        let firstToken = try await tokenForRequest()
        do {
            return try await sendToday(url: url, token: firstToken)
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
                return try await sendToday(url: url, token: retryToken)
            } catch let retryError as UnauthorizedResponse {
                await sessionRejected(retryToken)
                throw SnapRecordError.sessionRejected(correlationID: retryError.correlationID)
            }
        }
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

    func get(_ snapID: UUID) async throws -> SnapDetail {
        try await authorizedJSON(
            method: "GET",
            path: "/api/v1/snaps/\(snapID.uuidString.lowercased())",
            body: nil
        ) { data, status in
            switch status {
            case 200:
                return try self.decodeDetail(data)
            case 401:
                throw try self.unauthorized(data)
            case 404:
                let envelope = try self.decodeError(data, expectedCode: "NOT_ACCESSIBLE")
                throw SnapRecordError.notAccessible(correlationID: envelope.correlationId)
            case 500...599:
                let envelope = try? self.decodeError(data, expectedCode: "INTERNAL_ERROR")
                throw SnapRecordError.serverFailure(correlationID: envelope?.correlationId)
            default:
                throw SnapRecordError.malformedResponse
            }
        }
    }

    func revise(snapID: UUID, command: SnapReviseCommand) async throws -> SnapDetail {
        let body: Data
        do {
            body = try JSONEncoder().encode(command)
        } catch {
            throw SnapRecordError.malformedResponse
        }
        return try await authorizedJSON(
            method: "PATCH",
            path: "/api/v1/snaps/\(snapID.uuidString.lowercased())",
            body: body
        ) { data, status in
            switch status {
            case 200:
                return try self.decodeDetail(data)
            case 400:
                let envelope = try self.decodeError(data, expectedCode: "INVALID_REQUEST")
                throw SnapRecordError.invalidRequest(correlationID: envelope.correlationId)
            case 401:
                throw try self.unauthorized(data)
            case 404:
                let envelope = try self.decodeError(data, expectedCode: "NOT_ACCESSIBLE")
                throw SnapRecordError.notAccessible(correlationID: envelope.correlationId)
            case 409:
                let envelope = try self.decodeConflict(data)
                throw envelope
            case 500...599:
                let envelope = try? self.decodeError(data, expectedCode: "INTERNAL_ERROR")
                throw SnapRecordError.serverFailure(correlationID: envelope?.correlationId)
            default:
                throw SnapRecordError.malformedResponse
            }
        }
    }

    func delete(snapID: UUID, mutationID: String) async throws {
        try await authorizedJSON(
            method: "DELETE",
            path: "/api/v1/snaps/\(snapID.uuidString.lowercased())",
            body: nil,
            headers: ["X-Client-Mutation-Id": mutationID]
        ) { data, status in
            switch status {
            case 204:
                return
            case 400:
                let envelope = try self.decodeError(data, expectedCode: "INVALID_REQUEST")
                throw SnapRecordError.invalidRequest(correlationID: envelope.correlationId)
            case 401:
                throw try self.unauthorized(data)
            case 404:
                let envelope = try self.decodeError(data, expectedCode: "NOT_ACCESSIBLE")
                throw SnapRecordError.notAccessible(correlationID: envelope.correlationId)
            case 409:
                let envelope = try self.decodeError(data, expectedCode: "MUTATION_CONFLICT")
                throw SnapRecordError.mutationConflict(correlationID: envelope.correlationId)
            case 500...599:
                let envelope = try? self.decodeError(data, expectedCode: "INTERNAL_ERROR")
                throw SnapRecordError.serverFailure(correlationID: envelope?.correlationId)
            default:
                throw SnapRecordError.malformedResponse
            }
        }
    }

    func archive(from: String, to: String, cursor: String?) async throws -> ArchivePage {
        var components = URLComponents(
            url: baseURL.appending(path: "/api/v1/snaps/archive"),
            resolvingAgainstBaseURL: false
        )
        var items = [
            URLQueryItem(name: "fromLocalDay", value: from),
            URLQueryItem(name: "toLocalDay", value: to),
            URLQueryItem(name: "limit", value: "50")
        ]
        if let cursor {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components?.queryItems = items
        guard let url = components?.url else { throw SnapRecordError.malformedResponse }
        return try await authorizedJSON(method: "GET", path: url.path + "?" + (url.query ?? ""), body: nil) { data, status in
            guard status == 200 else { throw SnapRecordError.transportFailure }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom(Self.decodeInstant)
            let payload = try decoder.decode(ArchiveResponse.self, from: data)
            let entries = try payload.snaps.map { item in
                TodaySnapEntry(
                    id: item.id,
                    category: item.category,
                    amount: try KrwAmount(item.amountWon),
                    imageRef: item.imageRef
                )
            }
            return ArchivePage(
                snaps: entries,
                nextCursor: payload.nextCursor,
                occupiedLocalDays: payload.occupiedLocalDays
            )
        }
    }

    private func unauthorized(_ data: Data) throws -> UnauthorizedResponse {
        let envelope = try decodeError(data, expectedCode: "SESSION_REJECTED")
        return UnauthorizedResponse(correlationID: envelope.correlationId)
    }

    private func decodeConflict(_ data: Data) throws -> SnapRecordError {
        guard hasExactKeys(data, expected: ["code", "correlationId"]),
              let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
        else {
            throw SnapRecordError.malformedResponse
        }
        switch envelope.code {
        case "MUTATION_CONFLICT":
            return .mutationConflict(correlationID: envelope.correlationId)
        case "SNAP_VERSION_CONFLICT":
            return .versionConflict(correlationID: envelope.correlationId)
        default:
            throw SnapRecordError.malformedResponse
        }
    }

    private func authorizedJSON<T: Sendable>(
        method: String,
        path: String,
        body: Data?,
        headers: [String: String] = [:],
        handle: (Data, Int) async throws -> T
    ) async throws -> T {
        let firstToken = try await tokenForRequest()
        do {
            return try await sendRaw(
                method: method, path: path, body: body, headers: headers, token: firstToken, handle: handle
            )
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
                return try await sendRaw(
                    method: method, path: path, body: body, headers: headers, token: retryToken, handle: handle
                )
            } catch let retryError as UnauthorizedResponse {
                await sessionRejected(retryToken)
                throw SnapRecordError.sessionRejected(correlationID: retryError.correlationID)
            }
        }
    }

    private func sendRaw<T: Sendable>(
        method: String,
        path: String,
        body: Data?,
        headers: [String: String],
        token: String,
        handle: (Data, Int) async throws -> T
    ) async throws -> T {
        let requestURL = path.contains("?")
            ? (URL(string: path, relativeTo: baseURL) ?? baseURL.appending(path: path))
            : baseURL.appending(path: path)
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
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
        return try await handle(data, response.statusCode)
    }

    private func decodeDetail(_ data: Data) throws -> SnapDetail {
        guard hasAllowedKeys(data, required: [
            "id", "category", "amountWon", "localDay", "createdAt", "updatedAt", "version"
        ], optional: ["imageRef"]) else {
            throw SnapRecordError.malformedResponse
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom(Self.decodeInstant)
            let response = try decoder.decode(DetailResponse.self, from: data)
            guard (1...999_999_999).contains(response.amountWon),
                  response.version >= 1,
                  Self.isValidLocalDay(response.localDay) else {
                throw SnapRecordError.malformedResponse
            }
            return SnapDetail(
                id: response.id,
                category: response.category,
                amountWon: response.amountWon,
                localDay: response.localDay,
                createdAt: response.createdAt,
                updatedAt: response.updatedAt,
                version: response.version,
                imageRef: response.imageRef
            )
        } catch let error as SnapRecordError {
            throw error
        } catch {
            throw SnapRecordError.malformedResponse
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
        guard hasAllowedKeys(
            data,
            required: ["id", "category", "amountWon", "localDay", "createdAt"],
            optional: ["imageRef"]
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
                createdAt: response.createdAt,
                imageRef: response.imageRef
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
        hasAllowedKeys(data, required: expected)
    }

    private func hasAllowedKeys(
        _ data: Data,
        required: Set<String>,
        optional: Set<String> = []
    ) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return hasAllowedKeys(object, required: required, optional: optional)
    }

    private func hasAllowedKeys(
        _ object: [String: Any],
        required: Set<String>,
        optional: Set<String> = []
    ) -> Bool {
        let keys = Set(object.keys)
        return required.isSubset(of: keys) && keys.isSubset(of: required.union(optional))
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

    private func sendToday(url: URL, token: String) async throws -> TodaySnapSummary {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
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
        case 200:
            return try decodeToday(data)
        case 400:
            let envelope = try decodeError(data, expectedCode: "INVALID_REQUEST")
            throw SnapRecordError.invalidRequest(correlationID: envelope.correlationId)
        case 401:
            let envelope = try decodeError(data, expectedCode: "SESSION_REJECTED")
            throw UnauthorizedResponse(correlationID: envelope.correlationId)
        case 500...599:
            let envelope = try? decodeError(data, expectedCode: "INTERNAL_ERROR")
            throw SnapRecordError.serverFailure(correlationID: envelope?.correlationId)
        default:
            throw SnapRecordError.malformedResponse
        }
    }

    private func decodeToday(_ data: Data) throws -> TodaySnapSummary {
        guard hasExactKeys(data, expected: ["localDay", "totalAmountWon", "snaps"]) else {
            throw SnapRecordError.malformedResponse
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom(Self.decodeInstant)
            let payload = try decoder.decode(TodayResponse.self, from: data)
            guard Self.isValidLocalDay(payload.localDay),
                  payload.totalAmountWon >= 0,
                  payload.snaps.allSatisfy({
                      $0.localDay == payload.localDay
                          && (1...999_999_999).contains($0.amountWon)
                          && Self.isValidLocalDay($0.localDay)
                  }) else {
                throw SnapRecordError.malformedResponse
            }
            let sum = payload.snaps.reduce(0) { $0 + $1.amountWon }
            guard sum == payload.totalAmountWon else {
                throw SnapRecordError.malformedResponse
            }
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let snaps = object["snaps"] as? [[String: Any]],
                  snaps.allSatisfy({
                      hasAllowedKeys(
                          $0,
                          required: ["id", "category", "amountWon", "localDay", "createdAt"],
                          optional: ["imageRef"]
                      )
                  })
            else {
                throw SnapRecordError.malformedResponse
            }
            guard let day = SnapDay.parse(localDay: payload.localDay) else {
                throw SnapRecordError.malformedResponse
            }
            let entries = try payload.snaps.map { item in
                TodaySnapEntry(
                    id: item.id,
                    category: item.category,
                    amount: try KrwAmount(item.amountWon),
                    imageRef: item.imageRef
                )
            }
            return try TodaySnapSummary(
                day: day,
                entries: entries,
                featuredEntryIDs: entries.prefix(3).map(\.id),
                recentEntryIDs: entries.prefix(2).map(\.id)
            )
        } catch let error as SnapRecordError {
            throw error
        } catch {
            throw SnapRecordError.malformedResponse
        }
    }

    private static func serverTimeZoneIdentifier(_ zone: TimeZone, at date: Date) -> String? {
        if zone.secondsFromGMT(for: date) == 0,
           zone.identifier == "GMT" || zone.identifier == "UTC" {
            return "UTC"
        }
        guard zone.identifier.contains("/"),
              TimeZone.knownTimeZoneIdentifiers.contains(zone.identifier) else { return nil }
        return zone.identifier
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

    private struct ArchiveResponse: Decodable {
        let snaps: [ReceiptResponse]
        let nextCursor: String?
        let occupiedLocalDays: [String]?
    }

    private struct DetailResponse: Decodable {
        let id: UUID
        let category: SnapCategory
        let amountWon: Int64
        let localDay: String
        let createdAt: Date
        let updatedAt: Date
        let version: Int
        let imageRef: UUID?
    }

    private struct TodayResponse: Decodable {
        let localDay: String
        let totalAmountWon: Int64
        let snaps: [ReceiptResponse]
    }

    private struct ReceiptResponse: Decodable {
        let id: UUID
        let category: SnapCategory
        let amountWon: Int64
        let localDay: String
        let createdAt: Date
        let imageRef: UUID?
    }

    private struct ErrorEnvelope: Decodable {
        let code: String
        let correlationId: String
    }

    private struct UnauthorizedResponse: Error {
        let correlationID: String
    }
}
