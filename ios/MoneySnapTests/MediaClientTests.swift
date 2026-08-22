import Foundation
import Testing
@testable import MoneySnap

@Suite(.serialized)
struct MediaClientTests {
    @Test
    func publishesJpegThroughIntentUploadAndComplete() async throws {
        let imageRef = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let jpeg = NormalizedJpeg(
            bytes: Data([0xFF, 0xD8, 0xFF, 0x01]),
            checksumSha256: "abcd",
            width: 10,
            height: 10
        )
        MediaSequenceStub.configure(responses: [
            MediaSequenceStub.Response(
                status: 200,
                body: Data("""
                {"imageRef":"\(imageRef.uuidString.lowercased())","mode":"bounded-stream","uploadPath":"/api/v1/media/\(imageRef.uuidString.lowercased())/upload"}
                """.utf8)
            ),
            MediaSequenceStub.Response(status: 204, body: Data()),
            MediaSequenceStub.Response(
                status: 200,
                body: Data("""
                {"imageRef":"\(imageRef.uuidString.lowercased())"}
                """.utf8)
            )
        ])
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MediaSequenceStub.self]
        let client = URLSessionMediaClient(
            baseURL: URL(string: "https://moneysnap.example")!,
            session: URLSession(configuration: configuration),
            accessToken: { "access-token" }
        )

        let published = try await client.publish(jpeg)

        #expect(published == imageRef)
        let requests = MediaSequenceStub.recordedRequests()
        #expect(requests.map(\.httpMethod) == ["POST", "PUT", "POST"])
        #expect(requests.map { $0.url?.path } == [
            "/api/v1/media/intents",
            "/api/v1/media/\(imageRef.uuidString.lowercased())/upload",
            "/api/v1/media/\(imageRef.uuidString.lowercased())/complete"
        ])
        #expect(requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer access-token")
        #expect(requests[1].value(forHTTPHeaderField: "Content-Type") == "image/jpeg")
        let intentBody = try #require(MediaSequenceStub.recordedBodies().first)
        let json = try #require(JSONSerialization.jsonObject(with: intentBody) as? [String: Any])
        #expect(json["byteSize"] as? Int == 4)
        #expect(json["contentType"] as? String == "image/jpeg")
        #expect(json["checksumSha256"] as? String == "abcd")
    }

    @Test
    func fetchesLinkedJpegBytes() async throws {
        let imageRef = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xAA])
        MediaSequenceStub.configure(responses: [
            MediaSequenceStub.Response(status: 200, body: jpeg)
        ])
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MediaSequenceStub.self]
        let client = URLSessionMediaClient(
            baseURL: URL(string: "https://moneysnap.example")!,
            session: URLSession(configuration: configuration),
            accessToken: { "access-token" }
        )

        let fetched = try await client.fetchJPEG(imageRef)

        #expect(fetched == jpeg)
        let requests = MediaSequenceStub.recordedRequests()
        #expect(requests.map(\.httpMethod) == ["GET"])
        #expect(requests.first?.url?.path == "/api/v1/media/\(imageRef.uuidString.lowercased())")
        #expect(requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer access-token")
    }
}

private final class MediaSequenceStub: URLProtocol, @unchecked Sendable {
    struct Response {
        let status: Int
        let body: Data
    }

    private static let state = MediaSequenceState()

    static func configure(responses: [Response]) {
        state.configure(responses: responses)
    }

    static func recordedRequests() -> [URLRequest] {
        state.recordedRequests()
    }

    static func recordedBodies() -> [Data] {
        state.recordedBodies()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = Self.readBody(from: request)
        let stub = Self.state.next(request: request, body: body)
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

    private static func readBody(from request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }
        stream.open()
        defer { stream.close() }
        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 {
                return body
            }
            body.append(contentsOf: buffer.prefix(count))
        }
    }
}

private final class MediaSequenceState: @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [MediaSequenceStub.Response] = []
    private var requests: [URLRequest] = []
    private var bodies: [Data] = []

    func configure(responses: [MediaSequenceStub.Response]) {
        lock.lock()
        defer { lock.unlock() }
        self.responses = responses
        requests = []
        bodies = []
    }

    func next(request: URLRequest, body: Data) -> MediaSequenceStub.Response {
        lock.lock()
        defer { lock.unlock() }
        requests.append(request)
        bodies.append(body)
        if responses.isEmpty {
            return MediaSequenceStub.Response(status: 500, body: Data())
        }
        return responses.removeFirst()
    }

    func recordedRequests() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    func recordedBodies() -> [Data] {
        lock.lock()
        defer { lock.unlock() }
        return bodies
    }
}
