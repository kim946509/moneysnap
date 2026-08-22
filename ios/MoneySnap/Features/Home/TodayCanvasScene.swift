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
        canvasSize: CGSize,
        motion: TodayCanvasMotion
    ) {
        let featured = Array(entries.prefix(3))
        let firstPresentation = !didPresent
        didPresent = true
        var nextKnown: Set<UUID> = []
        var specs: [TodayCanvasScene.BodySpec] = []

        for (index, entry) in featured.enumerated() {
            let isNew = !firstPresentation && !knownIDs.contains(entry.id)
            let pose = TodayCanvasPlacement.pose(
                id: entry.id,
                index: index,
                canvasWidth: canvasSize.width,
                motion: motion,
                isNew: isNew
            )
            if motion == .staticRest || poses[entry.id] == nil || isNew {
                poses[entry.id] = pose
            }
            specs.append(
                TodayCanvasScene.BodySpec(
                    id: entry.id,
                    size: TodayCanvasPlacement.cardSize(index: index),
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
        physicsWorld.gravity = CGVector(dx: 0, dy: -7.2)
        physicsWorld.speed = 1
        view.allowsTransparency = true
        backgroundColor = .clear
    }

    func sync(specs: [BodySpec], canvasSize: CGSize) {
        size = canvasSize
        rebuildEnclosure()
        let incoming = Set(specs.map(\.id))
        for child in children where child.name != "enclosure" {
            guard let name = child.name, let id = UUID(uuidString: name) else { continue }
            if !incoming.contains(id) {
                child.removeFromParent()
                insertedAt[id] = nil
            }
        }

        let addedNew = specs.contains(where: \.isNew)
        for spec in specs {
            if let existing = childNode(withName: spec.id.uuidString.lowercased()) {
                if addedNew {
                    existing.physicsBody?.isDynamic = true
                    existing.physicsBody?.applyImpulse(CGVector(dx: 10, dy: 28))
                    existing.physicsBody?.angularVelocity = 0.8
                    insertedAt[spec.id] = nil
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
        lastTime = currentTime
        for child in children where child.name != "enclosure" {
            guard
                let name = child.name,
                let id = UUID(uuidString: name),
                let body = child.physicsBody
            else { continue }
            if insertedAt[id] == nil {
                insertedAt[id] = currentTime
                continue
            }
            let started = insertedAt[id] ?? currentTime
            let elapsed = currentTime - started
            let speed = hypot(body.velocity.dx, body.velocity.dy) + abs(body.angularVelocity) * 20
            if elapsed > 0.6 && speed < 18 {
                freeze(body)
            } else if elapsed > 1.2 {
                freeze(body)
            }
        }
    }

    private func addBody(_ spec: BodySpec) {
        let node = SKNode()
        node.name = spec.id.uuidString.lowercased()
        node.position = CGPoint(x: spec.start.center.x, y: size.height - spec.start.center.y)
        node.zRotation = spec.start.rotation
        let body = SKPhysicsBody(rectangleOf: spec.size)
        body.mass = max(0.2, (spec.size.width * spec.size.height) / 18_000)
        body.restitution = 0.46
        body.friction = 0.28
        body.linearDamping = 0.32
        body.angularDamping = 0.38
        body.allowsRotation = true
        body.isDynamic = spec.isNew
        body.categoryBitMask = 2
        body.collisionBitMask = 1 | 2
        node.physicsBody = body
        addChild(node)
        insertedAt[spec.id] = nil
        if spec.isNew {
            body.applyImpulse(CGVector(dx: CGFloat(Int(spec.id.uuid.1) % 11) - 5, dy: -12))
            body.angularVelocity = CGFloat(Int(spec.id.uuid.2) % 7) / 10 - 0.3
        }
    }

    private func freeze(_ body: SKPhysicsBody) {
        body.velocity = .zero
        body.angularVelocity = 0
        body.isDynamic = false
    }

    private func rebuildEnclosure() {
        childNode(withName: "enclosure")?.removeFromParent()
        let floor = size.height - TodayCanvasPlacement.floorY
        let ceiling = size.height - TodayCanvasPlacement.ceilingY
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
