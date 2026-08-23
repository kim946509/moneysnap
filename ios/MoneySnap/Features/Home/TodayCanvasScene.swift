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
                    index: index,
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
        let index: Int
        let isNew: Bool
        let start: TodayCanvasPose
    }

    var poseHandler: (([UUID: TodayCanvasPose]) -> Void)?
    private var insertedAt: [UUID: TimeInterval] = [:]
    private var lastTime: TimeInterval = 0

    override func didMove(to view: SKView) {
        physicsWorld.gravity = .zero
        physicsWorld.speed = 1
        view.allowsTransparency = true
        backgroundColor = .clear
    }

    func sync(specs: [BodySpec], canvasSize: CGSize) {
        let resized = size != canvasSize
        size = canvasSize
        if resized || childNode(withName: "enclosure") == nil {
            rebuildEnclosure()
        }
        let incoming = Set(specs.map(\.id))
        for child in children where child.name != "enclosure" {
            guard let name = child.name, let id = UUID(uuidString: name) else { continue }
            if !incoming.contains(id) {
                child.removeFromParent()
                insertedAt[id] = nil
            }
        }

        for spec in specs {
            if let existing = childNode(withName: spec.id.uuidString.lowercased()) {
                let radius = TodayCanvasPlacement.collisionRadius(size: spec.size)
                let stored = (existing.userData?["radius"] as? NSNumber).map { CGFloat(truncating: $0) }
                if stored == nil || abs((stored ?? 0) - radius) > 0.5 {
                    applyCollisionBody(spec.size, to: existing)
                }
                continue
            }
            addBody(spec)
        }
    }

    override func didSimulatePhysics() {
        var snapshot: [UUID: TodayCanvasPose] = [:]
        let height = size.height
        for child in children where child.name != "enclosure" {
            guard let name = child.name, let id = UUID(uuidString: name) else { continue }
            snapshot[id] = TodayCanvasPose(
                center: CGPoint(x: child.position.x, y: height - child.position.y),
                rotation: child.zRotation
            )
        }
        if !snapshot.isEmpty {
            poseHandler?(snapshot)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : currentTime - lastTime
        lastTime = currentTime
        for child in children where child.name != "enclosure" {
            guard
                let name = child.name,
                let id = UUID(uuidString: name),
                let body = child.physicsBody
            else { continue }
            if insertedAt[id] == nil {
                insertedAt[id] = currentTime
            }
            let heading = CGFloat(currentTime * 0.32 + Double(id.uuid.0) / 26)
            let cruise = TodayCanvasPlacement.floatCruiseSpeed
            let target = CGVector(dx: cos(heading) * cruise, dy: sin(heading * 1.13) * cruise)
            let speed = hypot(body.velocity.dx, body.velocity.dy)
            if speed < cruise * 0.4 {
                body.velocity = target
            } else {
                let blend = CGFloat(0.06 + min(dt, 0.04) * 0.8)
                body.velocity = CGVector(
                    dx: body.velocity.dx * (1 - blend) + target.dx * blend,
                    dy: body.velocity.dy * (1 - blend) + target.dy * blend
                )
            }
            let limited = hypot(body.velocity.dx, body.velocity.dy)
            let cap = TodayCanvasPlacement.floatSpeedLimit
            if limited > cap {
                let scale = cap / limited
                body.velocity = CGVector(dx: body.velocity.dx * scale, dy: body.velocity.dy * scale)
            }
            if abs(body.angularVelocity) > 1.6 {
                body.angularVelocity *= 0.9
            }
        }
    }

    private func addBody(_ spec: BodySpec) {
        let node = SKNode()
        node.name = spec.id.uuidString.lowercased()
        node.position = CGPoint(x: spec.start.center.x, y: size.height - spec.start.center.y)
        node.zRotation = spec.start.rotation
        applyCollisionBody(spec.size, to: node)
        addChild(node)
        insertedAt[spec.id] = nil
        let heading = CGFloat(Int(spec.id.uuid.1) % 360) * .pi / 180
        let cruise = TodayCanvasPlacement.floatCruiseSpeed
        node.physicsBody?.velocity = CGVector(
            dx: cos(heading) * cruise,
            dy: sin(heading) * cruise
        )
        node.physicsBody?.angularVelocity = spec.isNew ? CGFloat(Int(spec.id.uuid.3) % 5) / 10 - 0.2 : 0.08
    }

    private func applyCollisionBody(_ size: CGSize, to node: SKNode) {
        let radius = TodayCanvasPlacement.collisionRadius(size: size)
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.mass = max(0.12, (size.width * size.height) / 28_000)
        body.restitution = TodayCanvasPlacement.floatRestitution
        body.friction = 0
        body.linearDamping = TodayCanvasPlacement.floatLinearDamping
        body.angularDamping = TodayCanvasPlacement.floatAngularDamping
        body.affectedByGravity = false
        body.allowsRotation = true
        body.isDynamic = true
        body.categoryBitMask = 2
        body.collisionBitMask = 1 | 2
        if let current = node.physicsBody {
            body.velocity = current.velocity
            body.angularVelocity = current.angularVelocity
        }
        node.physicsBody = body
        if node.userData == nil {
            node.userData = NSMutableDictionary()
        }
        node.userData?["radius"] = NSNumber(value: Double(radius))
    }

    private func rebuildEnclosure() {
        childNode(withName: "enclosure")?.removeFromParent()
        let floor = size.height - TodayCanvasPlacement.physicsFloorY
        let ceiling = size.height - TodayCanvasPlacement.physicsCeilingY
        let inset: CGFloat = 18
        let rect = CGRect(x: inset, y: floor, width: max(0, size.width - inset * 2), height: max(0, ceiling - floor))
        let enclosure = SKNode()
        enclosure.name = "enclosure"
        let body = SKPhysicsBody(edgeLoopFrom: rect)
        body.categoryBitMask = 1
        body.collisionBitMask = 2
        body.isDynamic = false
        enclosure.physicsBody = body
        addChild(enclosure)
    }
}
