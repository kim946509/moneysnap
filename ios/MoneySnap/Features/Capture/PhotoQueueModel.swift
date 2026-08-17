import Foundation
import Observation

@MainActor
@Observable
final class PhotoQueueModel {
    private(set) var photos: [NormalizedJpeg]
    private(set) var index: Int = 0
    private(set) var savedReceipts: [SnapRecordReceipt] = []

    init(photos: [NormalizedJpeg] = []) {
        self.photos = Array(photos.prefix(3))
    }

    var current: NormalizedJpeg? {
        guard photos.indices.contains(index) else { return nil }
        return photos[index]
    }

    var progressLabel: String? {
        guard !photos.isEmpty else { return nil }
        return "\(index + 1)/\(photos.count)"
    }

    var isFinished: Bool { index >= photos.count }

    func enqueue(_ incoming: [NormalizedJpeg]) {
        photos = Array(incoming.prefix(3))
        index = 0
        savedReceipts = []
    }

    func markCurrentSaved(_ receipt: SnapRecordReceipt) {
        savedReceipts.append(receipt)
        index += 1
    }
}
