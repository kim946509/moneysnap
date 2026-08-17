import CryptoKit
import Foundation
import UIKit

struct NormalizedJpeg: Equatable, Sendable {
    let bytes: Data
    let checksumSha256: String
    let width: Int
    let height: Int

    var byteSize: Int { bytes.count }
}

enum JpegNormalizer {
    static let maxEdge = 1600
    static let maxBytes = 2_097_152

    static func normalize(_ image: UIImage) throws -> NormalizedJpeg {
        let oriented = image.fixedOrientation()
        let scaled = oriented.scaledToMaxEdge(CGFloat(maxEdge))
        var quality: CGFloat = 0.9
        var data: Data?
        while quality >= 0.4 {
            data = scaled.jpegData(compressionQuality: quality)
            if let data, data.count <= maxBytes { break }
            quality -= 0.1
        }
        guard let jpeg = data, jpeg.count <= maxBytes, jpeg.starts(with: [0xFF, 0xD8, 0xFF]) else {
            throw SnapRecordError.invalidRequest(correlationID: "normalize-failed")
        }
        return NormalizedJpeg(
            bytes: jpeg,
            checksumSha256: SHA256.hash(data: jpeg).map { String(format: "%02x", $0) }.joined(),
            width: Int(scaled.size.width.rounded()),
            height: Int(scaled.size.height.rounded())
        )
    }
}

private extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func scaledToMaxEdge(_ edge: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > edge else { return self }
        let scale = edge / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
