import Foundation
import Testing
@testable import MoneySnap

@Suite(.serialized)
struct AuthenticationAPIClientTests {
    @Test
    func signInUsesTheAppleAuthenticationEndpointAndEnvelope() async throws {
        let client = clientReturning(status: 200, body: sessionJSON)

        _ = try await client.signIn(with: AppleSignInCredential(
            identityToken: "identity-token",
            authorizationCode: "authorization-code",
            nonce: "raw-nonce"
        ))

        let request = try #require(URLProtocolStub.recordedRequest())
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/api/v1/auth/apple")
        #expect(json == [
            "identityToken": "identity-token",
            "authorizationCode": "authorization-code",
            "nonce": "raw-nonce"
        ])
    }

    @Test
    func refreshUsesTheRefreshTokenEnvelope() async throws {
        let client = clientReturning(status: 200, body: sessionJSON)

        _ = try await client.refresh("refresh-token")

        let body = try #require(URLProtocolStub.recordedRequest()?.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(json == ["refreshToken": "refresh-token"])
    }

    @Test
    func logoutUsesBearerAuthentication() async throws {
        let client = clientReturning(status: 204)

        try await client.logout(accessToken: "access-token")

        let request = try #require(URLProtocolStub.recordedRequest())
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/api/v1/auth/logout")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access-token")
    }

    @Test
    func accountDeletionUsesDeleteAndTheReauthenticationEnvelope() async throws {
        let client = clientReturning(status: 204)

        try await client.deleteAccount(
            accessToken: "access-token",
            credential: AppleSignInCredential(
                identityToken: "identity-token",
                authorizationCode: "authorization-code",
                nonce: "raw-nonce"
            )
        )

        let request = try #require(URLProtocolStub.recordedRequest())
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.path == "/api/v1/account")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access-token")
    }

    @Test
    func unauthorizedResponseBecomesASessionRejection() async {
        let client = clientReturning(status: 401)

        await #expect(throws: AuthenticationClientError.sessionRejected) {
            _ = try await client.refresh("rejected-refresh")
        }
    }

    @Test
    func serverFailureBecomesTemporaryUnavailability() async {
        let client = clientReturning(status: 503)

        await #expect(throws: AuthenticationClientError.temporarilyUnavailable) {
            _ = try await client.signIn(with: AppleSignInCredential(
                identityToken: "identity-token",
                authorizationCode: "authorization-code",
                nonce: "raw-nonce"
            ))
        }
    }

    @Test
    func decodesSpringInstantWithFractionalSeconds() async throws {
        let client = clientReturning(status: 200, body: fractionalSessionJSON)

        let session = try await client.refresh("refresh-token")

        #expect(session.accessToken == "access-token")
    }

    private func clientReturning(status: Int, body: Data = Data()) -> URLSessionAuthenticationAPI {
        URLProtocolStub.configure(status: status, body: body)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSessionAuthenticationAPI(
            baseURL: URL(string: "https://moneysnap.example")!,
            session: URLSession(configuration: configuration)
        )
    }

    private var sessionJSON: Data {
        Data("""
        {
          "accessToken": "access-token",
          "accessExpiresAt": "2026-08-10T12:15:00Z",
          "refreshToken": "refresh-token",
          "refreshExpiresAt": "2027-02-06T12:00:00Z"
        }
        """.utf8)
    }

    private var fractionalSessionJSON: Data {
        Data("""
        {
          "accessToken": "access-token",
          "accessExpiresAt": "2026-08-10T12:15:00.123456Z",
          "refreshToken": "refresh-token",
          "refreshExpiresAt": "2027-02-06T12:00:00.123456Z"
        }
        """.utf8)
    }
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    private static let state = URLProtocolState()

    static func configure(status: Int, body: Data) {
        state.configure(status: status, body: body)
    }

    static func recordedRequest() -> URLRequest? {
        state.recordedRequest()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.state.record(request)
        let stub = Self.state.response()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !stub.body.isEmpty {
            client?.urlProtocol(self, didLoad: stub.body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class URLProtocolState: @unchecked Sendable {
    private let lock = NSLock()
    private var request: URLRequest?
    private var status = 200
    private var body = Data()

    func configure(status: Int, body: Data) {
        lock.lock()
        defer { lock.unlock() }
        request = nil
        self.status = status
        self.body = body
    }

    func record(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        self.request = request
    }

    func recordedRequest() -> URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return request
    }

    func response() -> (status: Int, body: Data) {
        lock.lock()
        defer { lock.unlock() }
        return (status, body)
    }
}
