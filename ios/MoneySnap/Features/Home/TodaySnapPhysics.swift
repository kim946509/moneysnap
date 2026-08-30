import CoreMotion
import SpriteKit
import SwiftUI
import UIKit

struct TodaySnapPhysicsCanvas: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let entries: [TodaySnapEntry]
    let onSelect: (TodaySnapEntry.ID) -> Void
    @State private var scene: TodaySnapPhysicsScene

    init(
        entries: [TodaySnapEntry],
        onSelect: @escaping (TodaySnapEntry.ID) -> Void
    ) {
        self.entries = entries
        self.onSelect = onSelect
        _scene = State(initialValue: TodaySnapPhysicsScene(
            entries: entries,
            onSelect: onSelect
        ))
    }

    var body: some View {
        Group {
            if reduceMotion {
                StaticSnapPile(entries: entries, onSelect: onSelect)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .accessibilityIdentifier("home.physics-canvas")
            }
        }
        .onChange(of: entries) { _, updatedEntries in
            scene.replaceEntries(updatedEntries)
        }
    }
}

final class TodaySnapPhysicsScene: SKScene {
    private let motionManager = CMMotionManager()
    private let onSelect: (TodaySnapEntry.ID) -> Void
    private var entries: [TodaySnapEntry]
    private weak var draggedNode: SKNode?
    private var dragOrigin = CGPoint.zero
    private var previousDragPoint = CGPoint.zero
    private var previousDragTime: TimeInterval = 0

    init(
        entries: [TodaySnapEntry],
        onSelect: @escaping (TodaySnapEntry.ID) -> Void
    ) {
        self.entries = entries
        self.onSelect = onSelect
        super.init(size: CGSize(width: 393, height: 310))
        scaleMode = .resizeFill
        backgroundColor = .clear
        physicsWorld.gravity = TodayCanvasPhysics.defaultGravity
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        view.allowsTransparency = true
        rebuildScene()
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates()
    }

    override func willMove(from view: SKView) {
        motionManager.stopDeviceMotionUpdates()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        rebuildScene()
    }

    override func update(_ currentTime: TimeInterval) {
        guard let gravity = motionManager.deviceMotion?.gravity else { return }
        let isFlat = abs(gravity.x) + abs(gravity.y) < 0.2
        physicsWorld.gravity = isFlat
            ? TodayCanvasPhysics.defaultGravity
            : TodayCanvasPhysics.gravity(deviceX: gravity.x, deviceY: gravity.y)
    }

    func replaceEntries(_ entries: [TodaySnapEntry]) {
        guard self.entries != entries else { return }
        self.entries = entries
        rebuildScene()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        guard let node = cardNode(at: point) else { return }
        draggedNode = node
        dragOrigin = point
        previousDragPoint = point
        previousDragTime = touch.timestamp
        node.physicsBody?.isDynamic = false
        node.zPosition = 100
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let node = draggedNode else { return }
        let point = clamped(touch.location(in: self), for: node)
        node.position = point
        previousDragPoint = point
        previousDragTime = touch.timestamp
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let node = draggedNode else { return }
        let point = clamped(touch.location(in: self), for: node)
        let distance = hypot(point.x - dragOrigin.x, point.y - dragOrigin.y)
        let elapsed = max(1.0 / 120.0, touch.timestamp - previousDragTime)
        let velocity = CGVector(
            dx: boundedVelocity((point.x - previousDragPoint.x) / elapsed),
            dy: boundedVelocity((point.y - previousDragPoint.y) / elapsed)
        )

        node.position = point
        node.physicsBody?.isDynamic = true
        node.physicsBody?.velocity = velocity
        node.zPosition = 10
        draggedNode = nil

        if distance < 10,
           let name = node.name,
           let id = UUID(uuidString: String(name.dropFirst("snap:".count))) {
            onSelect(id)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        draggedNode?.physicsBody?.isDynamic = true
        draggedNode?.zPosition = 10
        draggedNode = nil
    }

    private func rebuildScene() {
        guard size.width > 100, size.height > 100 else { return }
        removeAllChildren()
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(
            x: 5,
            y: 5,
            width: size.width - 10,
            height: size.height - 10
        ))
        physicsBody?.friction = 0.42

        guard let maximumAmount = entries.map(\.amount).max() else { return }
        let xOffsets: [CGFloat] = [-56, 24, 66, -16, 48, -42]
        let rotations: [CGFloat] = [0.08, -0.07, 0.04, -0.1, 0.06, -0.03]

        for (index, entry) in entries.prefix(6).enumerated() {
            let cardSize = TodayCanvasLayout.physicsCardSize(
                for: entry,
                maximumAmount: maximumAmount
            )
            let card = makeCard(for: entry, size: cardSize)
            let halfWidth = cardSize.width / 2
            card.position = CGPoint(
                x: min(size.width - halfWidth - 8, max(halfWidth + 8, size.width / 2 + xOffsets[index])),
                y: max(cardSize.height / 2 + 12, size.height - 48 - CGFloat(index * 24))
            )
            card.zRotation = rotations[index]
            card.zPosition = CGFloat(index + 1)
            addChild(card)
        }
    }

    private func makeCard(for entry: TodaySnapEntry, size: CGSize) -> SKNode {
        let card = SKNode()
        card.name = "snap:\(entry.id.uuidString)"

        let shadow = SKShapeNode(rectOf: size, cornerRadius: 15)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.11)
        shadow.strokeColor = .clear
        shadow.position.y = -5
        shadow.zPosition = -2
        card.addChild(shadow)

        let surface = SKShapeNode(rectOf: size, cornerRadius: 15)
        surface.fillColor = .white
        surface.strokeColor = UIColor.black.withAlphaComponent(0.08)
        surface.lineWidth = 1
        surface.zPosition = -1
        card.addChild(surface)

        let mediaSize = CGSize(width: size.width - 12, height: size.height - 38)
        if let artwork = entry.artwork {
            let crop = artworkNode(named: artwork.rawValue, size: mediaSize)
            crop.position.y = 13
            card.addChild(crop)
        } else if let symbol = UIImage(systemName: entry.category.placeholderSymbol) {
            let tile = SKShapeNode(rectOf: mediaSize, cornerRadius: 11)
            tile.fillColor = UIColor(MoneySnapVisualSystem.profileNeutralFill)
            tile.strokeColor = .clear
            tile.position.y = 13
            card.addChild(tile)

            let icon = SKSpriteNode(texture: SKTexture(image: symbol))
            let side = min(mediaSize.width, mediaSize.height) * 0.38
            icon.size = CGSize(width: side, height: side)
            icon.color = UIColor(MoneySnapVisualSystem.charcoal)
            icon.colorBlendFactor = 1
            icon.position.y = 13
            card.addChild(icon)
        }

        let category = SKLabelNode(fontNamed: "NotoSansKR-Medium")
        category.text = entry.category.title
        category.fontSize = 9
        category.fontColor = UIColor(MoneySnapVisualSystem.secondaryText)
        category.horizontalAlignmentMode = .left
        category.verticalAlignmentMode = .center
        category.position = CGPoint(x: -size.width / 2 + 9, y: -size.height / 2 + 13)
        card.addChild(category)

        let amount = SKLabelNode(fontNamed: "NotoSansKR-Bold")
        amount.text = entry.amount.value.wonText
        amount.fontSize = size.width >= 140 ? 14 : 12
        amount.fontColor = UIColor(MoneySnapVisualSystem.ink)
        amount.horizontalAlignmentMode = .right
        amount.verticalAlignmentMode = .center
        amount.position = CGPoint(x: size.width / 2 - 9, y: -size.height / 2 + 13)
        card.addChild(amount)

        card.physicsBody = SKPhysicsBody(rectangleOf: size)
        card.physicsBody?.density = 0.72
        card.physicsBody?.friction = 0.46
        card.physicsBody?.restitution = 0.2
        card.physicsBody?.linearDamping = 0.38
        card.physicsBody?.angularDamping = 0.46
        card.physicsBody?.allowsRotation = true
        card.isAccessibilityElement = true
        card.accessibilityLabel = "\(entry.category.title), \(entry.amount.value.wonText)"
        card.accessibilityHint = "두 번 탭하여 Snap 상세 보기"
        card.accessibilityIdentifier = "home.snap.\(entry.id.uuidString.lowercased())"
        return card
    }

    private func artworkNode(named name: String, size: CGSize) -> SKCropNode {
        let crop = SKCropNode()
        let mask = SKShapeNode(rectOf: size, cornerRadius: 11)
        mask.fillColor = .white
        mask.strokeColor = .clear
        crop.maskNode = mask

        let image = SKSpriteNode(imageNamed: name)
        if let textureSize = image.texture?.size(), textureSize.width > 0, textureSize.height > 0 {
            let scale = max(size.width / textureSize.width, size.height / textureSize.height)
            image.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
        } else {
            image.size = size
        }
        crop.addChild(image)
        return crop
    }

    private func cardNode(at point: CGPoint) -> SKNode? {
        for candidate in nodes(at: point) {
            var current: SKNode? = candidate
            while let node = current {
                if node.name?.hasPrefix("snap:") == true { return node }
                current = node.parent
            }
        }
        return nil
    }

    private func clamped(_ point: CGPoint, for node: SKNode) -> CGPoint {
        let width = node.physicsBody == nil ? CGFloat(44) : node.calculateAccumulatedFrame().width
        let height = node.physicsBody == nil ? CGFloat(44) : node.calculateAccumulatedFrame().height
        return CGPoint(
            x: min(size.width - width / 2 - 6, max(width / 2 + 6, point.x)),
            y: min(size.height - height / 2 - 6, max(height / 2 + 6, point.y))
        )
    }

    private func boundedVelocity(_ value: CGFloat) -> CGFloat {
        max(-900, min(900, value))
    }
}

private struct StaticSnapPile: View {
    let entries: [TodaySnapEntry]
    let onSelect: (TodaySnapEntry.ID) -> Void

    var body: some View {
        let visibleEntries = Array(entries.prefix(3))
        let maximumAmount = visibleEntries.map(\.amount).max()

        ZStack {
            ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, entry in
                Button {
                    onSelect(entry.id)
                } label: {
                    FeaturedSnapCard(
                        entry: entry,
                        imageSize: maximumAmount.map {
                            TodayCanvasLayout.imageSize(for: entry, maximumAmount: $0)
                        } ?? .zero,
                        layout: index.isMultiple(of: 2) ? .landscape : .portrait
                    )
                }
                .buttonStyle(.plain)
                .rotationEffect(.degrees([4, -5, 2][index]))
                .offset(x: [-62, 48, 6][index], y: [-26, 12, 58][index])
                .accessibilityLabel("\(entry.category.title), \(entry.amount.value.wonText)")
                .accessibilityHint("Snap 상세 보기")
            }
        }
    }
}
