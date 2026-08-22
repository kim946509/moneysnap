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
                    .ignoresSafeArea()
            }
            ForEach(Array(entries.prefix(3).enumerated()), id: \.element.id) { index, entry in
                let pose = controller.poses[entry.id]
                    ?? TodayCanvasPlacement.pose(
                        id: entry.id,
                        index: index,
                        canvasWidth: canvasSize.width,
                        motion: .staticRest,
                        isNew: false
                    )
                canvasCard(entry, index: index)
                    .position(pose.center)
                    .rotationEffect(.radians(pose.rotation))
                    .onTapGesture { onOpen(entry.id) }
            }
        }
        .onAppear { controller.sync(entries: entries, canvasSize: canvasSize, motion: motion) }
        .onChange(of: entries.map(\.id)) { _, _ in
            controller.sync(entries: entries, canvasSize: canvasSize, motion: motion)
        }
        .onChange(of: canvasSize) { _, _ in
            controller.sync(entries: entries, canvasSize: canvasSize, motion: motion)
        }
    }

    @ViewBuilder
    private func canvasCard(_ entry: TodaySnapEntry, index: Int) -> some View {
        if index == 2 {
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
