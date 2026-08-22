import Foundation

protocol MediaClient: Sendable {
    func publish(_ jpeg: NormalizedJpeg) async throws -> UUID
    func fetchJPEG(_ imageRef: UUID) async throws -> Data
}

actor URLSessionMediaClient: MediaClient {
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

    func publish(_ jpeg: NormalizedJpeg) async throws -> UUID {
        let token = try await accessToken()
        let intent = try await createIntent(jpeg, token: token)
        try await upload(jpeg, path: intent.uploadPath, token: token)
        return try await complete(intent.imageRef, token: token)
    }

    func fetchJPEG(_ imageRef: UUID) async throws -> Data {
        let token = try await accessToken()
        var request = URLRequest(
            url: baseURL.appending(path: "/api/v1/media/\(imageRef.uuidString.lowercased())")
        )
        request.httpMethod = "GET"
        request.setValue("image/jpeg", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SnapRecordError.transportFailure
        }
        guard let response = response as? HTTPURLResponse, response.statusCode == 200, !data.isEmpty else {
            throw SnapRecordError.transportFailure
        }
        return data
    }

    private func createIntent(_ jpeg: NormalizedJpeg, token: String) async throws -> MediaIntentResponse {
        var request = URLRequest(url: baseURL.appending(path: "/api/v1/media/intents"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "byteSize": jpeg.byteSize,
            "contentType": "image/jpeg",
            "checksumSha256": jpeg.checksumSha256
        ])
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw SnapRecordError.transportFailure
        }
        return try JSONDecoder().decode(MediaIntentResponse.self, from: data)
    }

    private func upload(_ jpeg: NormalizedJpeg, path: String, token: String) async throws {
        let url = URL(string: path, relativeTo: baseURL) ?? baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = jpeg.bytes
        let (_, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 204 else {
            throw SnapRecordError.transportFailure
        }
    }

    private func complete(_ imageRef: UUID, token: String) async throws -> UUID {
        var request = URLRequest(
            url: baseURL.appending(path: "/api/v1/media/\(imageRef.uuidString.lowercased())/complete")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw SnapRecordError.transportFailure
        }
        let body = try JSONDecoder().decode(MediaRefResponse.self, from: data)
        return body.imageRef
    }
}

private struct MediaIntentResponse: Decodable {
    let imageRef: UUID
    let uploadPath: String
}

private struct MediaRefResponse: Decodable {
    let imageRef: UUID
}
