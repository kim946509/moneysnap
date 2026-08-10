import Foundation

actor URLSessionAuthenticationAPI: AuthenticationAPI {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func signIn(with credential: AppleSignInCredential) async throws -> AuthenticationSession {
        try await sendSession(
            path: "/api/v1/auth/apple",
            method: "POST",
            body: credential
        )
    }

    func refresh(_ refreshToken: String) async throws -> AuthenticationSession {
        try await sendSession(
            path: "/api/v1/auth/refresh",
            method: "POST",
            body: RefreshRequest(refreshToken: refreshToken)
        )
    }

    func logout(accessToken: String) async throws {
        let request = try makeRequest(
            path: "/api/v1/auth/logout",
            method: "POST",
            accessToken: accessToken
        )
        _ = try await data(for: request, expectedStatus: 204)
    }

    func deleteAccount(
        accessToken: String,
        credential: AppleSignInCredential
    ) async throws {
        let request = try makeRequest(
            path: "/api/v1/account",
            method: "DELETE",
            body: credential,
            accessToken: accessToken
        )
        _ = try await data(for: request, expectedStatus: 204)
    }

    private func sendSession<Body: Encodable & Sendable>(
        path: String,
        method: String,
        body: Body
    ) async throws -> AuthenticationSession {
        let request = try makeRequest(path: path, method: method, body: body)
        let responseData = try await data(for: request, expectedStatus: 200)
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let value = try container.decode(String.self)
                let fractional = ISO8601DateFormatter()
                fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = fractional.date(from: value) {
                    return date
                }
                let wholeSeconds = ISO8601DateFormatter()
                wholeSeconds.formatOptions = [.withInternetDateTime]
                if let date = wholeSeconds.date(from: value) {
                    return date
                }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Expected an ISO 8601 instant"
                )
            }
            return try decoder.decode(AuthenticationSession.self, from: responseData)
        } catch {
            throw AuthenticationClientError.invalidResponse
        }
    }

    private func makeRequest(
        path: String,
        method: String,
        accessToken: String? = nil
    ) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func makeRequest<Body: Encodable>(
        path: String,
        method: String,
        body: Body,
        accessToken: String? = nil
    ) throws -> URLRequest {
        var request = try makeRequest(path: path, method: method, accessToken: accessToken)
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func data(for request: URLRequest, expectedStatus: Int) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthenticationClientError.temporarilyUnavailable
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationClientError.invalidResponse
        }
        if httpResponse.statusCode == 401 {
            throw AuthenticationClientError.sessionRejected
        }
        guard httpResponse.statusCode == expectedStatus else {
            throw AuthenticationClientError.temporarilyUnavailable
        }
        return data
    }

    private struct RefreshRequest: Encodable {
        let refreshToken: String
    }
}
