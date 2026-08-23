import SpriteKit
import SwiftUI

struct TodayCanvasView: View {
    let entries: [TodaySnapEntry]
    let maximumAmount: KrwAmount?
    let canvasSize: CGSize
    let onOpen: (UUID) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var controller = TodayCanvasController()

    var body: some View {
        let motion = TodayCanvasPlacement.motion(
            reduceMotion: reduceMotion,
            visualScenario: ProcessInfo.processInfo.environment["MONEYSNAP_VISUAL_SCENARIO"]
        )

        ZStack {
            if motion == .physics {
                SpriteView(scene: controller.scene, options: [.allowsTransparency])
                    .allowsHitTesting(false)
            }
            ForEach(Array(visibleEntries(motion).enumerated()), id: \.element.id) { index, entry in
                let pose = controller.poses[entry.id]
                    ?? TodayCanvasPlacement.pose(
                        id: entry.id,
                        index: index,
                        count: visibleEntries(motion).count,
                        canvasWidth: canvasSize.width,
                        size: tokenSize(for: entry, count: visibleEntries(motion).count, motion: motion),
                        motion: motion == .physics ? .staticRest : motion,
                        isNew: false
                    )
                canvasCard(entry, index: index, motion: motion)
                    .position(pose.center)
                    .rotationEffect(.radians(pose.rotation))
                    .onTapGesture { onOpen(entry.id) }
            }
        }
        .onAppear { controller.sync(entries: entries, maximumAmount: maximumAmount, canvasSize: canvasSize, motion: motion) }
        .onChange(of: canvasSignature) { _, _ in
            controller.sync(entries: entries, maximumAmount: maximumAmount, canvasSize: canvasSize, motion: motion)
        }
        .onChange(of: canvasSize) { _, _ in
            controller.sync(entries: entries, maximumAmount: maximumAmount, canvasSize: canvasSize, motion: motion)
        }
    }

    private var canvasSignature: String {
        entries.map { "\($0.id.uuidString.lowercased()):\($0.amount.value)" }.joined(separator: ",")
            + ":\(maximumAmount?.value ?? 0)"
    }

    private func visibleEntries(_ motion: TodayCanvasMotion) -> [TodaySnapEntry] {
        motion == .staticRest ? Array(entries.prefix(3)) : entries
    }

    private func tokenSize(
        for entry: TodaySnapEntry,
        count: Int,
        motion: TodayCanvasMotion
    ) -> CGSize {
        guard motion == .physics, let maximumAmount else {
            return TodayCanvasPlacement.cardSize(index: 0)
        }
        return TodayCanvasPlacement.physicsSize(for: entry, maximumAmount: maximumAmount, count: count)
    }

    @ViewBuilder
    private func canvasCard(_ entry: TodaySnapEntry, index: Int, motion: TodayCanvasMotion) -> some View {
        if motion == .physics, let maximumAmount {
            CanvasSnapToken(
                entry: entry,
                imageSize: TodayCanvasPlacement.physicsSize(
                    for: entry,
                    maximumAmount: maximumAmount,
                    count: visibleEntries(motion).count
                )
            )
        } else if index == 2 {
            PriceTicket(entry: entry)
                .rotationEffect(.degrees(-4))
        } else if let maximumAmount {
            FeaturedSnapCard(
                entry: entry,
                imageSize: TodayCanvasLayout.imageSize(for: entry, maximumAmount: maximumAmount),
                layout: index == 0 ? .landscape : .portrait
            )
        }
    }
}
