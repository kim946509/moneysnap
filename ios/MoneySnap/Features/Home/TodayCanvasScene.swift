import SpriteKit

@MainActor
@Observable
final class TodayCanvasController {
    private(set) var poses: [UUID: TodayCanvasPose] = [:]
    let scene: TodayCanvasScene
    private var knownIDs: Set<UUID> = []
    private var didPresent = false

    init() {
        let scene = TodayCanvasScene(size: CGSize(width: 393, height: 852))
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        self.scene = scene
        scene.poseHandler = { [weak self] snapshot in
            Task { @MainActor in
                guard let self else { return }
                for (id, pose) in snapshot {
                    self.poses[id] = pose
                }
            }
        }
    }

    func sync(
        entries: [TodaySnapEntry],
        maximumAmount: KrwAmount?,
        canvasSize: CGSize,
        motion: TodayCanvasMotion
    ) {
        let visible = motion == .staticRest ? Array(entries.prefix(3)) : entries
        let firstPresentation = !didPresent
        didPresent = true
        var nextKnown: Set<UUID> = []
        var specs: [TodayCanvasScene.BodySpec] = []
        let largest = maximumAmount ?? visible.map(\.amount).max()

        for (index, entry) in visible.enumerated() {
            let isNew = !firstPresentation && !knownIDs.contains(entry.id)
            let size: CGSize
            if motion == .physics, let largest {
                size = TodayCanvasPlacement.physicsSize(
                    for: entry,
                    maximumAmount: largest,
                    count: visible.count
                )
            } else {
                size = TodayCanvasPlacement.cardSize(index: index)
            }
            let pose = TodayCanvasPlacement.pose(
                id: entry.id,
                index: index,
                count: visible.count,
                canvasWidth: canvasSize.width,
                size: size,
                motion: motion,
                isNew: isNew
            )
            if motion == .staticRest || poses[entry.id] == nil || isNew {
                poses[entry.id] = pose
            }
            specs.append(
                TodayCanvasScene.BodySpec(
                    id: entry.id,
                    size: size,
                    isNew: isNew,
                    start: pose
                )
            )
            nextKnown.insert(entry.id)
        }

        for id in knownIDs.subtracting(nextKnown) {
            poses[id] = nil
        }
        knownIDs = nextKnown
        scene.isPaused = motion != .physics
        if motion == .physics, canvasSize != .zero {
            scene.sync(specs: specs, canvasSize: canvasSize)
        }
    }
}

final class TodayCanvasScene: SKScene {
    struct BodySpec {
        let id: UUID
        let size: CGSize
        let isNew: Bool
        let start: TodayCanvasPose
    }

    var poseHandler: (([UUID: TodayCanvasPose]) -> Void)?
    private var bodies: [TodayCanvasDriftBody] = []
    private var lastTime: TimeInterval = 0

    override func didMove(to view: SKView) {
        view.allowsTransparency = true
        backgroundColor = .clear
    }

    func sync(specs: [BodySpec], canvasSize: CGSize) {
        size = canvasSize
        let incoming = Set(specs.map(\.id))
        bodies.removeAll { !incoming.contains($0.id) }

        for spec in specs {
            let radius = TodayCanvasPlacement.collisionRadius(size: spec.size)
            if let index = bodies.firstIndex(where: { $0.id == spec.id }) {
                bodies[index].radius = radius
                continue
            }
            let heading = CGFloat(Int(spec.id.uuid.1) % 360) * .pi / 180
            let cruise = TodayCanvasPlacement.floatCruiseSpeed
            bodies.append(
                TodayCanvasDriftBody(
                    id: spec.id,
                    center: spec.start.center,
                    velocity: CGVector(dx: cos(heading) * cruise, dy: sin(heading) * cruise),
                    radius: radius,
                    rotation: spec.start.rotation,
                    spin: spec.isNew ? CGFloat(Int(spec.id.uuid.3) % 5) / 10 - 0.2 : 0.08
                )
            )
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? TodayCanvasDrift.frameDuration : CGFloat(currentTime - lastTime)
        lastTime = currentTime
        guard !bodies.isEmpty else { return }
        TodayCanvasDrift.step(
            bodies: &bodies,
            bounds: TodayCanvasDrift.playBounds(canvasSize: size),
            dt: dt,
            time: currentTime
        )
        var snapshot: [UUID: TodayCanvasPose] = [:]
        for body in bodies {
            snapshot[body.id] = TodayCanvasPose(center: body.center, rotation: body.rotation)
        }
        poseHandler?(snapshot)
    }
}
