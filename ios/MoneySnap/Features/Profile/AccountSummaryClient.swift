import Foundation

struct AccountSummary: Equatable, Sendable, Decodable {
    let displayName: String
    let todaySnapCount: Int
    let monthSnapCount: Int
    let groupCount: Int
}

protocol AccountSummaryClient: Sendable {
    func summary(timeZone: String) async throws -> AccountSummary
}

actor URLSessionAccountSummaryClient: AccountSummaryClient {
    private let baseURL: URL
    private let session: URLSession
    private let accessToken: @Sendable () async throws -> String

    init(
        baseURL: URL,
        session: URLSession = .shared,
        accessToken: @escaping @Sendable () async throws -> String
    ) {
        self.baseURL = baseURL
        self.session = session
        self.accessToken = accessToken
    }

    func summary(timeZone: String) async throws -> AccountSummary {
        var components = URLComponents(
            url: baseURL.appending(path: "/api/v1/account/summary"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "timeZone", value: timeZone)]
        guard let url = components?.url else {
            throw SnapRecordError.transportFailure
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw SnapRecordError.transportFailure
        }
        return try JSONDecoder().decode(AccountSummary.self, from: data)
    }
}
