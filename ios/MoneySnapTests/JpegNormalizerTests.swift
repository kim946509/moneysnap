import Testing
import UIKit
@testable import MoneySnap

struct JpegNormalizerTests {
    @Test
    func normalizeProducesOrientedJpegUnderLimits() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 800))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2400, height: 800))
        }

        let normalized = try JpegNormalizer.normalize(image)

        #expect(normalized.byteSize <= JpegNormalizer.maxBytes)
        #expect(max(normalized.width, normalized.height) <= JpegNormalizer.maxEdge)
        #expect(normalized.bytes.starts(with: [0xFF, 0xD8, 0xFF]))
        #expect(normalized.checksumSha256.count == 64)
    }
}

@MainActor
struct PhotoQueueModelTests {
    @Test
    func keepsAtMostThreePhotosAndAdvancesOnlyAfterSave() {
        let photos = (0..<4).map {
            NormalizedJpeg(bytes: Data([0xFF, 0xD8, 0xFF, UInt8($0)]), checksumSha256: "a", width: 10, height: 10)
        }
        let queue = PhotoQueueModel()
        queue.enqueue(photos)
        #expect(queue.photos.count == 3)
        #expect(queue.progressLabel == "1/3")
        queue.markCurrentSaved(SnapRecordReceipt(
            id: UUID(),
            category: .food,
            amountWon: 100,
            localDay: "2026-08-13",
            createdAt: Date()
        ))
        #expect(queue.progressLabel == "2/3")
        #expect(queue.savedReceipts.count == 1)
    }
}
