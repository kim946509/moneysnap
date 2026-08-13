import Foundation
import Testing
@testable import MoneySnap

@Suite(.serialized)
struct SnapJournalClientTests {
    @Test
    func recordSendsTheCanonicalEnvelopeWithTheLatestBearer() async throws {
        let requestFixture = try canonicalFixture("record-request")
        let responseFixture = try canonicalFixture("record-response")
        let command = try JSONDecoder().decode(SnapRecordCommand.self, from: requestFixture)
        let harness = Harness(responses: [.init(status: 201, body: responseFixture)])

        let receipt = try await harness.client.record(command)

        let request = try #require(harness.protocolState.requests.first)
        let body = try #require(request.body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: AnyHashable])
        let expectedJSON = try #require(
            JSONSerialization.jsonObject(with: requestFixture) as? [String: AnyHashable]
        )
        #expect(request.request.httpMethod == "POST")
        #expect(request.request.url?.path == "/api/v1/snaps")
        #expect(request.request.value(forHTTPHeaderField: "Authorization") == "Bearer current-token")
        #expect(json == expectedJSON)
        #expect(receipt.id.uuidString.lowercased() == "018f1e2d-1234-7abc-8def-0123456789ab")
    }

    @Test
    func staleBearer401RetriesAtMostOnceWithTheSameCommandAndNewBearer() async throws {
        let harness = Harness(
            tokens: ["old-token", "new-token"],
            responses: [
                .init(status: 401, body: .sessionRejected),
                .init(status: 201, body: .receipt)
            ]
        )

        _ = try await harness.client.record(.fixture)

        #expect(harness.protocolState.requests.map { $0.request.value(forHTTPHeaderField: "Authorization") } == [
            "Bearer old-token", "Bearer new-token"
        ])
        #expect(harness.protocolState.requests[0].body == harness.protocolState.requests[1].body)
        #expect(await harness.tokenState.rejectedTokens == ["old-token"])
    }

    @Test
    func currentBearer401DoesNotSendASecondRequest() async {
        let harness = Harness(
            tokens: ["current-token", "current-token"],
            responses: [.init(status: 401, body: .sessionRejected)]
        )

        await #expect(throws: SnapRecordError.sessionRejected(correlationID: "corr-401")) {
            _ = try await harness.client.record(.fixture)
        }

        #expect(harness.protocolState.requests.count == 1)
        #expect(await harness.tokenState.rejectedTokens == ["current-token"])
    }

    @Test
    @MainActor
    func currentBearer401TransportClearsTheAuthenticationSession() async {
        let session = AuthenticationSession(
            accessToken: "current-token",
            accessExpiresAt: .distantFuture,
            refreshToken: "refresh-token",
            refreshExpiresAt: .distantFuture
        )
        let store = TransportSessionStore(session: session)
        let authentication = AuthenticationModel(
            api: TransportAuthenticationAPI(),
            store: store,
            initialPhase: .authenticated(session)
        )
        let protocolState = SnapURLProtocolState(responses: [
            .init(status: 401, body: .sessionRejected)
        ])
        SnapURLProtocol.state = protocolState
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SnapURLProtocol.self]
        let client = URLSessionSnapJournalClient(
            baseURL: URL(string: "https://moneysnap.example")!,
            session: URLSession(configuration: configuration),
            accessToken: { try await authentication.accessTokenForRequest() },
            sessionRejected: { token in
                await authentication.handleSessionRejection(for: token)
            }
        )

        await #expect(throws: SnapRecordError.sessionRejected(correlationID: "corr-401")) {
            _ = try await client.record(.fixture)
        }

        #expect(protocolState.requests.count == 1)
        #expect(authentication.phase == .signedOut)
        #expect(await store.load() == nil)
    }

    @Test
    func transportFailureIsCommitUnknown() async {
        let harness = Harness(responses: [
            .init(status: 0, body: Data(), error: URLError(.notConnectedToInternet))
        ])

        await #expect(throws: SnapRecordError.transportFailure) {
            _ = try await harness.client.record(.fixture)
        }
    }

    @Test
    func decodesSpringInstantsWithFractionalSeconds() async throws {
        let harness = Harness(responses: [.init(status: 201, body: .fractionalReceipt)])

        let receipt = try await harness.client.record(.fixture)

        #expect(receipt.amountWon == 18_900)
    }

    @Test
    func malformedReceiptLocalDayIsCommitUnknown() async {
        let harness = Harness(responses: [.init(status: 201, body: .invalidDayReceipt)])

        await #expect(throws: SnapRecordError.malformedResponse) {
            _ = try await harness.client.record(.fixture)
        }
    }

    @Test
    func normalizesStatusAndMalformedResponses() async {
        let cases: [(Int, Data, SnapRecordError)] = [
            (400, .invalidRequest, .invalidRequest(correlationID: "corr-400")),
            (401, .sessionRejected, .sessionRejected(correlationID: "corr-401")),
            (409, .conflict, .mutationConflict(correlationID: "corr-409")),
            (503, .internalError, .serverFailure(correlationID: "corr-500")),
            (503, Data("{}".utf8), .serverFailure(correlationID: nil)),
            (201, Data("{}".utf8), .malformedResponse)
        ]
        for (status, body, expected) in cases {
            let harness = Harness(responses: [.init(status: status, body: body)])
            do {
                _ = try await harness.client.record(.fixture)
                Issue.record("Expected status \(status) to fail")
            } catch {
                #expect(error as? SnapRecordError == expected)
            }
        }
    }

    private func canonicalFixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: SnapFixtureBundleToken.self)
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "snaps")
            ?? bundle.url(forResource: name, withExtension: "json")
        return try Data(contentsOf: try #require(url))
    }
}

private final class SnapFixtureBundleToken {}

private struct Harness {
    let tokenState: TokenState
    let protocolState: SnapURLProtocolState
    let client: URLSessionSnapJournalClient

    init(tokens: [String] = ["current-token"], responses: [SnapURLProtocolState.Stub]) {
        let tokenState = TokenState(tokens: tokens)
        let protocolState = SnapURLProtocolState(responses: responses)
        SnapURLProtocol.state = protocolState
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SnapURLProtocol.self]
        self.tokenState = tokenState
        self.protocolState = protocolState
        client = URLSessionSnapJournalClient(
            baseURL: URL(string: "https://moneysnap.example")!,
            session: URLSession(configuration: configuration),
            accessToken: tokenState.nextToken,
            sessionRejected: tokenState.reject
        )
    }
}

private actor TokenState {
    private var tokens: [String]
    private(set) var rejectedTokens: [String] = []

    init(tokens: [String]) { self.tokens = tokens }

    func nextToken() throws -> String {
        guard !tokens.isEmpty else { throw AuthenticationClientError.sessionRejected }
        return tokens.removeFirst()
    }

    func reject(_ token: String) { rejectedTokens.append(token) }
}

private actor TransportSessionStore: SessionStore {
    private var session: AuthenticationSession?

    init(session: AuthenticationSession?) { self.session = session }
    func load() -> AuthenticationSession? { session }
    func save(_ session: AuthenticationSession) { self.session = session }
    func clear() { session = nil }
}

private actor TransportAuthenticationAPI: AuthenticationAPI {
    func signIn(with credential: AppleSignInCredential) throws -> AuthenticationSession {
        throw AuthenticationClientError.temporarilyUnavailable
    }
    func refresh(_ refreshToken: String) throws -> AuthenticationSession {
        throw AuthenticationClientError.temporarilyUnavailable
    }
    func logout(accessToken: String) {}
    func deleteAccount(accessToken: String, credential: AppleSignInCredential) {}
}

private final class SnapURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var state = SnapURLProtocolState(responses: [])

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let stub = Self.state.consume(request, body: Self.body(from: request))
        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: stub.status, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func body(from request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
}

private final class SnapURLProtocolState: @unchecked Sendable {
    struct Stub {
        let status: Int
        let body: Data
        let error: Error?

        init(status: Int, body: Data, error: Error? = nil) {
            self.status = status
            self.body = body
            self.error = error
        }
    }
    struct Recorded { let request: URLRequest; let body: Data? }

    private let lock = NSLock()
    private var responses: [Stub]
    private(set) var requests: [Recorded] = []

    init(responses: [Stub]) { self.responses = responses }

    func consume(_ request: URLRequest, body: Data?) -> Stub {
        lock.lock()
        defer { lock.unlock() }
        requests.append(.init(request: request, body: body))
        return responses.removeFirst()
    }
}

private extension SnapRecordCommand {
    static let fixture = SnapRecordCommand(
        clientMutationId: "11111111-1111-4111-8111-111111111111",
        localDay: "2026-08-13",
        timeZone: "Asia/Seoul",
        category: .food,
        amountWon: 18_900
    )
}

private extension Data {
    static let receipt = Data(#"{"id":"22222222-2222-4222-8222-222222222222","category":"food","amountWon":18900,"localDay":"2026-08-13","createdAt":"2026-08-13T01:00:00Z"}"#.utf8)
    static let fractionalReceipt = Data(#"{"id":"22222222-2222-4222-8222-222222222222","category":"food","amountWon":18900,"localDay":"2026-08-13","createdAt":"2026-08-13T01:00:00.123Z"}"#.utf8)
    static let invalidDayReceipt = Data(#"{"id":"22222222-2222-4222-8222-222222222222","category":"food","amountWon":18900,"localDay":"2026-99-99","createdAt":"2026-08-13T01:00:00Z"}"#.utf8)
    static let invalidRequest = Data(#"{"code":"INVALID_REQUEST","correlationId":"corr-400"}"#.utf8)
    static let sessionRejected = Data(#"{"code":"SESSION_REJECTED","correlationId":"corr-401"}"#.utf8)
    static let conflict = Data(#"{"code":"MUTATION_CONFLICT","correlationId":"corr-409"}"#.utf8)
    static let internalError = Data(#"{"code":"INTERNAL_ERROR","correlationId":"corr-500"}"#.utf8)
}
