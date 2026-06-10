import SpriteKit
import SwiftUI

// MARK: - Color bridging

extension SKColorCompatible {
    var skColor: SKColor {
        SKColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    var brighterSKColor: SKColor {
        SKColor(red: min(red + 0.25, 1.0),
                green: min(green + 0.25, 1.0),
                blue: min(blue + 0.25, 1.0),
                alpha: alpha)
    }
}

// MARK: - Enemy Node (Alien Swarm)

final class EnemyNode: SKShapeNode {
    let id = UUID()
    let originalType: EnemyType
    private let waypoints: [CGPoint]
    private(set) var currentHealth: Int
    private(set) var waypointIndex: Int = 1

    /// Total track distance covered so far; used to rank "furthest progressed".
    private(set) var distanceTraveled: CGFloat = 0

    /// Per-frame slow factor applied by gravity wells (1 = full speed). Reset each tick.
    var slowMultiplier: CGFloat = 1.0

    var isCamo: Bool { originalType.isInvisible && currentHealth > 0 }
    var isRobotic: Bool { originalType.isRobotic }

    private var isRevealedByScan = false

    /// Speed reflects the current visible tier (a damaged Blob moves like a Pod).
    var currentSpeed: CGFloat {
        EnemyType.tier(forRemainingHealth: currentHealth, original: originalType).speed
    }

    init(type: EnemyType, waypoints: [CGPoint]) {
        self.originalType = type
        self.waypoints = waypoints
        self.currentHealth = type.healthLayers
        super.init()
        position = waypoints[0]
        zPosition = 5
        name = "enemy"
        redrawBody()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Deep Scan visual reveal — cloaked wisps brighten while a global scan runs.
    func setRevealed(_ revealed: Bool) {
        guard originalType.isInvisible, revealed != isRevealedByScan else { return }
        isRevealedByScan = revealed
        alpha = revealed ? 0.85 : 0.45
    }

    /// Rebuilds the programmatic alien chassis to match the current tier.
    private func redrawBody() {
        removeAllChildren()
        let tier = EnemyType.tier(forRemainingHealth: currentHealth, original: originalType)
        let r = tier.radius
        let c = tier.color
        lineWidth = 2
        glowWidth = 3
        fillColor = SKColor(red: c.red, green: c.green, blue: c.blue, alpha: 0.92)
        strokeColor = c.brighterSKColor
        alpha = 1.0

        switch tier {
        case .pod:
            // Round alien pod with a dome highlight and stabilizer fins.
            path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2), transform: nil)
            let dome = SKShapeNode(ellipseOf: CGSize(width: r * 1.1, height: r * 0.6))
            dome.fillColor = SKColor(white: 1.0, alpha: 0.35)
            dome.strokeColor = .clear
            dome.position = CGPoint(x: 0, y: r * 0.35)
            addChild(dome)
            for side in [CGFloat(-1), CGFloat(1)] {
                let fin = SKShapeNode(rectOf: CGSize(width: 4, height: r * 0.8), cornerRadius: 2)
                fin.fillColor = strokeColor
                fin.strokeColor = .clear
                fin.position = CGPoint(x: side * r * 0.85, y: -r * 0.5)
                fin.zRotation = side * 0.5
                addChild(fin)
            }

        case .blob:
            // Wobbling cosmic blob with inner bubbles.
            path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2), transform: nil)
            for (dx, dy, br) in [(-0.35, 0.25, 0.30), (0.3, -0.2, 0.22), (0.05, 0.4, 0.16)] {
                let bubble = SKShapeNode(circleOfRadius: r * CGFloat(br))
                bubble.fillColor = SKColor(white: 1.0, alpha: 0.30)
                bubble.strokeColor = .clear
                bubble.position = CGPoint(x: r * CGFloat(dx), y: r * CGFloat(dy))
                addChild(bubble)
            }
            if action(forKey: "pulse") == nil {
                run(.repeatForever(.sequence([
                    .scale(to: 1.07, duration: 0.5),
                    .scale(to: 0.94, duration: 0.5)
                ])), withKey: "pulse")
            }

        case .drone:
            // Angular robotic chassis with a glowing thruster.
            let chassis = CGMutablePath()
            chassis.move(to: CGPoint(x: 0, y: r * 1.1))
            chassis.addLine(to: CGPoint(x: r * 0.9, y: -r * 0.8))
            chassis.addLine(to: CGPoint(x: 0, y: -r * 0.35))
            chassis.addLine(to: CGPoint(x: -r * 0.9, y: -r * 0.8))
            chassis.closeSubpath()
            path = chassis
            let thruster = SKShapeNode(ellipseOf: CGSize(width: r * 0.55, height: r * 0.35))
            thruster.fillColor = SKColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 0.95)
            thruster.strokeColor = .clear
            thruster.glowWidth = 4
            thruster.position = CGPoint(x: 0, y: -r * 0.75)
            addChild(thruster)
            let core = SKShapeNode(circleOfRadius: r * 0.28)
            core.fillColor = SKColor(red: 1.0, green: 0.35, blue: 0.25, alpha: 1.0)
            core.strokeColor = .clear
            core.position = CGPoint(x: 0, y: r * 0.1)
            addChild(core)

        case .wisp:
            // Cloaked hexagonal energy entity.
            let hex = CGMutablePath()
            for i in 0..<6 {
                let angle = CGFloat(i) * .pi / 3 + .pi / 6
                let pt = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
                if i == 0 { hex.move(to: pt) } else { hex.addLine(to: pt) }
            }
            hex.closeSubpath()
            path = hex
            let core = SKShapeNode(circleOfRadius: r * 0.4)
            core.fillColor = SKColor(white: 1.0, alpha: 0.8)
            core.strokeColor = .clear
            addChild(core)
            let cloak = SKShapeNode(circleOfRadius: r * 1.3)
            cloak.fillColor = .clear
            cloak.strokeColor = SKColor(red: 0.75, green: 0.55, blue: 1.0, alpha: 0.55)
            cloak.lineWidth = 1.5
            addChild(cloak)
            alpha = isRevealedByScan ? 0.85 : 0.45

        case .behemoth:
            // Armored void octagon with a burning core.
            let oct = CGMutablePath()
            for i in 0..<8 {
                let angle = CGFloat(i) * .pi / 4 + .pi / 8
                let pt = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
                if i == 0 { oct.move(to: pt) } else { oct.addLine(to: pt) }
            }
            oct.closeSubpath()
            path = oct
            lineWidth = 3.5
            let armor = SKShapeNode(circleOfRadius: r * 0.68)
            armor.fillColor = .clear
            armor.strokeColor = SKColor(white: 0.15, alpha: 0.9)
            armor.lineWidth = 3
            addChild(armor)
            let core = SKShapeNode(circleOfRadius: r * 0.35)
            core.fillColor = SKColor(red: 1.0, green: 0.45, blue: 0.2, alpha: 1.0)
            core.strokeColor = .clear
            core.glowWidth = 5
            addChild(core)
        }
    }

    /// Applies damage. Returns the number of layers actually destroyed.
    /// Swaps the physical chassis tier when health drops but remains positive.
    func applyDamage(_ amount: Int) -> Int {
        guard currentHealth > 0 else { return 0 }
        let popped = min(amount, currentHealth)
        currentHealth -= popped
        if currentHealth > 0 {
            redrawBody()
        }
        return popped
    }

    /// Advances along the waypoint path. Returns true when the enemy exits the final waypoint.
    func advance(deltaTime: TimeInterval) -> Bool {
        var remainingStep = currentSpeed * slowMultiplier * 60 * CGFloat(deltaTime)

        while remainingStep > 0 {
            guard waypointIndex < waypoints.count else { return true }
            let target = waypoints[waypointIndex]

            let dx = target.x - position.x
            let dy = target.y - position.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance <= remainingStep {
                position = target
                distanceTraveled += distance
                remainingStep -= distance
                waypointIndex += 1
                if waypointIndex >= waypoints.count { return true }
            } else {
                let movementRatio = remainingStep / distance
                position = CGPoint(x: position.x + dx * movementRatio,
                                   y: position.y + dy * movementRatio)
                distanceTraveled += remainingStep
                remainingStep = 0
            }
        }
        return false
    }
}

// MARK: - Tower Node (Space Defense)

final class TowerNode: SKShapeNode {
    let id = UUID().uuidString
    let type: TowerType
    var lastFireTime: TimeInterval = 0

    /// Upgrade tiers (alpha = speed/utility, beta = power).
    private(set) var pathALevel: Int = 0
    private(set) var pathBLevel: Int = 0

    /// Temporary cloak detection from the laser's Phase Scanner ability.
    var isCamoDetectionActive: Bool = false
    var camoDetectionEndTime: TimeInterval = 0

    /// Plasma Overload double-damage window.
    var damageBuffEndTime: TimeInterval = 0

    /// Gravity Stasis Field window.
    var stasisEndTime: TimeInterval = 0

    /// Per-frame aura state computed by the scene.
    var isScannerBuffed: Bool = false
    var auraRateFactor: Double = 1.0

    var isSelected: Bool = false { didSet { refreshRangeRing() } }

    // Effective combat stats after upgrades.
    var effectiveCooldown: TimeInterval {
        type.fireCooldown * pow(TowerType.alphaCooldownFactor, Double(pathALevel))
    }
    var effectiveDamage: Int {
        type.projectileDamage + pathBLevel * TowerType.betaDamageBonus
    }
    var effectiveRange: CGFloat {
        type.range * CGFloat(pow(TowerType.betaRangeFactor, Double(pathBLevel)))
    }

    /// Damage including any active Overload buff.
    func currentDamage(at time: TimeInterval) -> Int {
        effectiveDamage * (time < damageBuffEndTime ? 2 : 1)
    }

    /// Gravity slow including alpha upgrades, or stasis override.
    func currentSlowStrength(at time: TimeInterval) -> Double {
        if time < stasisEndTime { return 0.9 }
        return min(0.85, type.slowStrength + Double(pathALevel) * TowerType.alphaEffectBonus)
    }

    /// Alien Tech haste including alpha upgrades.
    var currentHasteStrength: Double {
        min(0.6, type.hasteStrength + Double(pathALevel) * TowerType.alphaEffectBonus)
    }

    /// Whether this tower can target cloaked enemies right now.
    func canSeeInvisible(globalReveal: Bool) -> Bool {
        type.detectsInvisibleBase
            || (type == .laser && pathBLevel >= 3)
            || isCamoDetectionActive
            || isScannerBuffed
            || globalReveal
    }

    private let rangeCircle = SKShapeNode()
    private let turretHead = SKNode()

    init(type: TowerType, position: CGPoint) {
        self.type = type
        super.init()
        self.position = position
        zPosition = 10
        name = "tower"
        buildBody()
        addChild(rangeCircle)
        rangeCircle.zPosition = -1
        refreshRangeRing()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func buildBody() {
        let r = type.bodyRadius

        // Dark armored base plate.
        path = CGPath(ellipseIn: CGRect(x: -(r + 6), y: -(r + 6), width: (r + 6) * 2, height: (r + 6) * 2),
                      transform: nil)
        fillColor = SKColor(white: 0.10, alpha: 1.0)
        strokeColor = SKColor(white: 0.38, alpha: 1.0)
        lineWidth = 1.5

        // Glowing reactor body.
        let body = SKShapeNode(circleOfRadius: r)
        body.fillColor = type.color.skColor
        body.strokeColor = type.color.brighterSKColor
        body.lineWidth = 2
        body.glowWidth = 3
        body.zPosition = 1
        addChild(body)

        turretHead.zPosition = 2
        addChild(turretHead)

        let tint = type.projectileTint.skColor

        switch type {
        case .laser, .plasma:
            // Beam barrel with an emitter lens (plasma's is stockier).
            let length: CGFloat = type == .laser ? 24 : 18
            let width: CGFloat = type == .laser ? 7 : 11
            let barrel = SKShapeNode(rectOf: CGSize(width: width, height: length), cornerRadius: 3)
            barrel.fillColor = SKColor(white: 0.15, alpha: 1.0)
            barrel.strokeColor = SKColor(white: 0.45, alpha: 1.0)
            barrel.position = CGPoint(x: 0, y: r * 0.85)
            turretHead.addChild(barrel)
            let lens = SKShapeNode(circleOfRadius: type == .laser ? 3.5 : 5)
            lens.fillColor = tint
            lens.strokeColor = .clear
            lens.glowWidth = 3
            lens.position = CGPoint(x: 0, y: r * 0.85 + length / 2)
            turretHead.addChild(lens)

        case .darkMatter:
            // Collapsed-core orb wrapped in a dark ring.
            let orb = SKShapeNode(circleOfRadius: r * 0.55)
            orb.fillColor = tint
            orb.strokeColor = SKColor(white: 1.0, alpha: 0.9)
            orb.lineWidth = 1.5
            orb.glowWidth = 6
            turretHead.addChild(orb)
            let ring = SKShapeNode(circleOfRadius: r * 0.8)
            ring.fillColor = .clear
            ring.strokeColor = SKColor(white: 0.05, alpha: 1.0)
            ring.lineWidth = 3
            turretHead.addChild(ring)
            orb.run(.repeatForever(.sequence([
                .scale(to: 1.18, duration: 0.5),
                .scale(to: 0.9, duration: 0.5)
            ])))

        case .emp:
            // Radial emitter stubs.
            for i in 0..<8 {
                let angle = CGFloat(i) * (.pi / 4)
                let stub = SKShapeNode(rectOf: CGSize(width: 5, height: 12), cornerRadius: 2)
                stub.fillColor = SKColor(white: 0.15, alpha: 1.0)
                stub.strokeColor = tint
                stub.lineWidth = 1
                stub.position = CGPoint(x: cos(angle) * (r + 2), y: sin(angle) * (r + 2))
                stub.zRotation = angle - .pi / 2
                turretHead.addChild(stub)
            }

        case .missile:
            // Twin launch tubes.
            for side in [CGFloat(-1), CGFloat(1)] {
                let tube = SKShapeNode(rectOf: CGSize(width: 7, height: 20), cornerRadius: 3)
                tube.fillColor = SKColor(white: 0.18, alpha: 1.0)
                tube.strokeColor = tint
                tube.lineWidth = 1
                tube.position = CGPoint(x: side * 6, y: r * 0.8)
                turretHead.addChild(tube)
            }

        case .ion:
            // Tesla spire with three arc prongs.
            let rod = SKShapeNode(rectOf: CGSize(width: 4, height: r * 1.3), cornerRadius: 2)
            rod.fillColor = SKColor(white: 0.3, alpha: 1.0)
            rod.strokeColor = .clear
            rod.position = CGPoint(x: 0, y: r * 0.5)
            turretHead.addChild(rod)
            for i in 0..<3 {
                let angle = CGFloat(i) * (2 * .pi / 3) + .pi / 2
                let prong = SKShapeNode(circleOfRadius: 3.5)
                prong.fillColor = tint
                prong.strokeColor = .clear
                prong.glowWidth = 3
                prong.position = CGPoint(x: cos(angle) * r * 0.7, y: sin(angle) * r * 0.7)
                turretHead.addChild(prong)
            }

        case .gravity:
            // Concentric distortion rings, the outer one slowly rotating.
            let inner = SKShapeNode(circleOfRadius: r * 0.5)
            inner.fillColor = tint.withAlphaComponent(0.5)
            inner.strokeColor = tint
            inner.glowWidth = 4
            turretHead.addChild(inner)
            let outer = SKShapeNode(ellipseOf: CGSize(width: r * 2.2, height: r * 1.4))
            outer.fillColor = .clear
            outer.strokeColor = tint.withAlphaComponent(0.8)
            outer.lineWidth = 2
            turretHead.addChild(outer)
            outer.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 5)))

        case .scanner:
            // Sensor dish on a mast, sweeping a pulse.
            let mast = SKShapeNode(rectOf: CGSize(width: 4, height: r), cornerRadius: 2)
            mast.fillColor = SKColor(white: 0.3, alpha: 1.0)
            mast.strokeColor = .clear
            mast.position = CGPoint(x: 0, y: r * 0.4)
            turretHead.addChild(mast)
            let dishPath = CGMutablePath()
            dishPath.addArc(center: .zero, radius: r * 0.7,
                            startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: false)
            let dish = SKShapeNode(path: dishPath)
            dish.strokeColor = tint
            dish.lineWidth = 3
            dish.glowWidth = 2
            dish.position = CGPoint(x: 0, y: r * 0.75)
            turretHead.addChild(dish)
            let pulse = SKShapeNode(circleOfRadius: r)
            pulse.fillColor = .clear
            pulse.strokeColor = tint.withAlphaComponent(0.5)
            pulse.lineWidth = 1.5
            addChild(pulse)
            pulse.zPosition = 1
            pulse.run(.repeatForever(.sequence([
                .group([.scale(to: 2.2, duration: 1.6), .fadeOut(withDuration: 1.6)]),
                .run { pulse.setScale(1); pulse.alpha = 1 }
            ])))

        case .satellite:
            // Uplink station: solar panels flanking a center dish.
            for side in [CGFloat(-1), CGFloat(1)] {
                let panel = SKShapeNode(rectOf: CGSize(width: r * 0.9, height: r * 0.55), cornerRadius: 2)
                panel.fillColor = SKColor(red: 0.12, green: 0.20, blue: 0.40, alpha: 1.0)
                panel.strokeColor = tint
                panel.lineWidth = 1
                panel.position = CGPoint(x: side * r * 0.95, y: 0)
                turretHead.addChild(panel)
            }
            let dish = SKShapeNode(circleOfRadius: r * 0.4)
            dish.fillColor = SKColor(white: 0.85, alpha: 1.0)
            dish.strokeColor = SKColor(white: 0.4, alpha: 1.0)
            dish.glowWidth = 2
            turretHead.addChild(dish)

        case .quantum:
            // Phase prism: nested glowing diamonds.
            let outerDiamond = SKShapeNode(rectOf: CGSize(width: r * 1.5, height: r * 1.5), cornerRadius: 3)
            outerDiamond.zRotation = .pi / 4
            outerDiamond.fillColor = SKColor(white: 0.12, alpha: 1.0)
            outerDiamond.strokeColor = tint
            outerDiamond.lineWidth = 2
            outerDiamond.glowWidth = 2
            turretHead.addChild(outerDiamond)
            let innerDiamond = SKShapeNode(rectOf: CGSize(width: r * 0.7, height: r * 0.7), cornerRadius: 2)
            innerDiamond.zRotation = .pi / 4
            innerDiamond.fillColor = tint
            innerDiamond.strokeColor = .clear
            innerDiamond.glowWidth = 4
            turretHead.addChild(innerDiamond)

        case .alien:
            // Organic spire with orbiting motes.
            let orb = SKShapeNode(circleOfRadius: r * 0.5)
            orb.fillColor = tint.withAlphaComponent(0.8)
            orb.strokeColor = tint
            orb.glowWidth = 4
            turretHead.addChild(orb)
            let orbiter = SKNode()
            for i in 0..<2 {
                let mote = SKShapeNode(circleOfRadius: 4)
                mote.fillColor = SKColor(white: 1.0, alpha: 0.9)
                mote.strokeColor = .clear
                mote.glowWidth = 2
                let angle = CGFloat(i) * .pi
                mote.position = CGPoint(x: cos(angle) * r * 0.95, y: sin(angle) * r * 0.95)
                orbiter.addChild(mote)
            }
            turretHead.addChild(orbiter)
            orbiter.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 3)))
        }
    }

    /// Rotates the turret head to face a target point (range ring stays fixed).
    func aim(at point: CGPoint) {
        let dx = point.x - position.x
        let dy = point.y - position.y
        turretHead.zRotation = atan2(dy, dx) - .pi / 2
    }

    func increaseUpgrade(path: UpgradePath) {
        switch path {
        case .alpha: pathALevel += 1
        case .beta:  pathBLevel += 1
        }
        refreshRangeRing()
        playUpgradeFlash()
    }

    /// Rebuilds the range ring to reflect effective range, selection, and scanner state.
    func refreshRangeRing() {
        // Satellite range covers the map; show a compact indicator instead.
        let radius = min(effectiveRange, GameConfig.canvasWidth)
        rangeCircle.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
                                  transform: nil)
        if isCamoDetectionActive {
            rangeCircle.strokeColor = SKColor(red: 0.40, green: 0.95, blue: 1.0, alpha: 0.85)
            rangeCircle.lineWidth = 2.5
            rangeCircle.fillColor = SKColor(red: 0.40, green: 0.95, blue: 1.0, alpha: 0.06)
        } else if isSelected {
            rangeCircle.strokeColor = SKColor(white: 1.0, alpha: 0.8)
            rangeCircle.lineWidth = 2
            rangeCircle.fillColor = SKColor(white: 1.0, alpha: 0.10)
        } else {
            rangeCircle.strokeColor = SKColor(white: 1.0, alpha: 0.22)
            rangeCircle.lineWidth = 1
            rangeCircle.fillColor = SKColor(white: 1.0, alpha: 0.05)
        }
    }

    private func playUpgradeFlash() {
        let ring = SKShapeNode(circleOfRadius: type.bodyRadius + 10)
        ring.fillColor = .clear
        ring.strokeColor = .white
        ring.lineWidth = 3
        ring.glowWidth = 4
        ring.zPosition = 5
        addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1.9, duration: 0.35), .fadeOut(withDuration: 0.35)]),
            .removeFromParent()
        ]))
    }
}

// MARK: - Projectile Node (Energy Bolt / Rocket)

final class ProjectileNode: SKShapeNode {
    let damage: Int
    let flightSpeed: CGFloat = 9.0
    /// Area damage radius on impact (0 = direct hit only).
    let splashRadius: CGFloat
    /// EMP bolts deal double damage to robotic enemies.
    let bonusVsRobotic: Bool
    weak var target: EnemyNode?
    /// Fallback direction used when the target dies mid-flight or for radial bursts.
    var direction: CGVector

    init(from origin: CGPoint, target: EnemyNode?, direction: CGVector,
         damage: Int, tint: SKColor, splashRadius: CGFloat = 0, bonusVsRobotic: Bool = false) {
        self.damage = damage
        self.target = target
        self.direction = direction
        self.splashRadius = splashRadius
        self.bonusVsRobotic = bonusVsRobotic
        super.init()
        position = origin
        zPosition = 8
        name = "projectile"
        // Glowing energy bolt capsule (rockets are stockier).
        let size: CGSize = splashRadius > 0 ? CGSize(width: 6, height: 16) : CGSize(width: 4, height: 18)
        path = CGPath(roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2,
                                          width: size.width, height: size.height),
                      cornerWidth: size.width / 2, cornerHeight: size.width / 2, transform: nil)
        fillColor = tint
        strokeColor = tint
        lineWidth = 1
        glowWidth = 3
        zRotation = atan2(direction.dy, direction.dx) - .pi / 2
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }
}

// MARK: - Game Scene

final class GameScene: SKScene {

    weak var viewModel: GameViewModel?

    /// Battleground configuration injected before presentation.
    var map: MapConfig = GameConfig.maps[0]

    private var lastUpdateTime: TimeInterval = 0
    /// Simulation clock — advances at gameSpeed multiples of wall time.
    private var gameTime: TimeInterval = 0

    /// Global timed effects (abilities).
    private var globalRevealEndTime: TimeInterval = 0
    private var globalRateBuffEndTime: TimeInterval = 0

    // Wave / spawn automation state.
    private var spawnQueue: [EnemyType] = []
    private var timeSinceLastSpawn: TimeInterval = 0
    private var timeSinceWaveEnded: TimeInterval = 0
    private var waveInFlight = false

    private var enemies: [EnemyNode] = []
    private var towers: [TowerNode] = []
    private var projectiles: [ProjectileNode] = []

    private weak var selectedTower: TowerNode?

    // MARK: Setup

    override func didMove(to view: SKView) {
        backgroundColor = map.theme.background.skColor
        scaleMode = .aspectFit
        drawSpaceBackdrop()
        drawTrack()
        queueWave(1)
    }

    /// Procedural deep-space backdrop: nebula clouds and a starfield.
    private func drawSpaceBackdrop() {
        var generator = SeededGenerator(seed: UInt64(map.totalWaves * 1000 + map.difficulty))

        // Nebula clouds.
        let nebula = map.theme.nebula
        for _ in 0..<6 {
            let cloud = SKShapeNode(ellipseOf: CGSize(width: CGFloat.random(in: 220...480, using: &generator),
                                                      height: CGFloat.random(in: 140...320, using: &generator)))
            cloud.position = CGPoint(x: CGFloat.random(in: 0...GameConfig.canvasWidth, using: &generator),
                                     y: CGFloat.random(in: 0...GameConfig.canvasHeight, using: &generator))
            cloud.fillColor = nebula.skColor
            cloud.strokeColor = .clear
            cloud.zPosition = 0
            cloud.zRotation = CGFloat.random(in: 0...(.pi), using: &generator)
            addChild(cloud)
        }

        // Starfield.
        for i in 0..<90 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.8...2.2, using: &generator))
            star.position = CGPoint(x: CGFloat.random(in: 0...GameConfig.canvasWidth, using: &generator),
                                    y: CGFloat.random(in: 0...GameConfig.canvasHeight, using: &generator))
            star.fillColor = SKColor(white: 1.0, alpha: CGFloat.random(in: 0.3...0.9, using: &generator))
            star.strokeColor = .clear
            star.zPosition = 0.5
            addChild(star)
            if i % 8 == 0 {
                star.run(.repeatForever(.sequence([
                    .fadeAlpha(to: 0.15, duration: Double.random(in: 0.8...1.6, using: &generator)),
                    .fadeAlpha(to: 0.9, duration: Double.random(in: 0.8...1.6, using: &generator))
                ])))
            }
        }
    }

    /// Renders the flight corridor with an energized neon center line.
    private func drawTrack() {
        let trackPath = CGMutablePath()
        trackPath.move(to: map.waypoints[0])
        for point in map.waypoints.dropFirst() {
            trackPath.addLine(to: point)
        }

        let outer = SKShapeNode(path: trackPath)
        outer.strokeColor = map.theme.trackOuter.skColor
        outer.lineWidth = GameConfig.trackWidth
        outer.lineCap = .round
        outer.lineJoin = .round
        outer.zPosition = 1
        addChild(outer)

        let inner = SKShapeNode(path: trackPath)
        inner.strokeColor = map.theme.trackInner.skColor
        inner.lineWidth = GameConfig.trackWidth - 10
        inner.lineCap = .round
        inner.lineJoin = .round
        inner.zPosition = 2
        addChild(inner)

        let centerLine = SKShapeNode(path: trackPath)
        centerLine.strokeColor = map.theme.accent.skColor
        centerLine.lineWidth = 3
        centerLine.lineCap = .round
        centerLine.lineJoin = .round
        centerLine.glowWidth = 4
        centerLine.zPosition = 3
        addChild(centerLine)
    }

    // MARK: Wave Spawning & Difficulty

    /// Wave composition scales with the sector difficulty and wave number:
    /// early sectors are pods and blobs; drones arrive at difficulty 2;
    /// cloaked wisps from difficulty 2-3; behemoths anchor the late campaign.
    private func queueWave(_ wave: Int) {
        let d = map.difficulty
        let count = GameConfig.baseEnemiesPerWave + wave * GameConfig.extraEnemiesPerWave + d * 2
        var queue: [EnemyType] = []
        for i in 0..<count {
            if d >= 5 && i % 7 == 6 {
                queue.append(.behemoth)
            } else if d >= 4 && wave >= 4 && i % 9 == 8 {
                queue.append(.behemoth)
            } else if (d >= 3 && wave >= 3 && i % 5 == 4) || (d == 2 && wave >= 6 && i % 6 == 5) {
                queue.append(.wisp)
            } else if d >= 2 && wave >= 2 && i % 4 == 3 {
                queue.append(.drone)
            } else if wave >= 2 && i % 2 == 1 {
                queue.append(.blob)
            } else {
                queue.append(.pod)
            }
        }
        spawnQueue = queue
        waveInFlight = true
        timeSinceLastSpawn = GameConfig.spawnInterval // spawn first enemy immediately
    }

    private func runSpawning(deltaTime: TimeInterval) {
        if waveInFlight {
            guard !spawnQueue.isEmpty else {
                if enemies.isEmpty {
                    if let viewModel, viewModel.currentWave >= map.totalWaves {
                        waveInFlight = false
                        DispatchQueue.main.async { viewModel.winMission() }
                        return
                    }
                    waveInFlight = false
                    timeSinceWaveEnded = 0
                }
                return
            }
            timeSinceLastSpawn += deltaTime
            if timeSinceLastSpawn >= GameConfig.spawnInterval {
                timeSinceLastSpawn = 0
                let enemy = EnemyNode(type: spawnQueue.removeFirst(), waypoints: map.waypoints)
                enemies.append(enemy)
                addChild(enemy)
                // Warp-in effect.
                enemy.setScale(0.2)
                enemy.run(.scale(to: 1.0, duration: 0.25))
            }
        } else {
            timeSinceWaveEnded += deltaTime
            if timeSinceWaveEnded >= GameConfig.secondsBetweenWaves {
                DispatchQueue.main.async { self.viewModel?.advanceWave() }
                queueWave((viewModel?.currentWave ?? 1) + 1)
            }
        }
    }

    // MARK: Touch Resolution

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let viewModel, viewModel.isSimulationActive else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if let selected = viewModel.selectedTowerType {
            attemptPlacement(of: selected, at: location)
        } else if let tower = towerIntersecting(location) {
            select(tower)
        } else {
            deselectTower()
        }
    }

    private func towerIntersecting(_ point: CGPoint) -> TowerNode? {
        towers.first { tower in
            let dx = tower.position.x - point.x
            let dy = tower.position.y - point.y
            return sqrt(dx * dx + dy * dy) <= tower.type.bodyRadius + 14
        }
    }

    // MARK: Selection & Sidebar Bridge

    private func select(_ tower: TowerNode) {
        selectedTower?.isSelected = false
        selectedTower = tower
        tower.isSelected = true
        publishPanel(for: tower)
    }

    func deselectTower() {
        selectedTower?.isSelected = false
        selectedTower = nil
        DispatchQueue.main.async { [weak viewModel] in
            viewModel?.selectedTowerInfo = nil
        }
    }

    private func publishPanel(for tower: TowerNode) {
        let info = TowerPanelInfo(id: tower.id,
                                  type: tower.type,
                                  pathALevel: tower.pathALevel,
                                  pathBLevel: tower.pathBLevel,
                                  damage: tower.effectiveDamage,
                                  range: Int(min(tower.effectiveRange, 999).rounded()),
                                  fireRate: 1.0 / tower.effectiveCooldown)
        DispatchQueue.main.async { [weak viewModel] in
            viewModel?.selectedTowerInfo = info
        }
    }

    // MARK: Upgrades

    /// Purchases the next tier on the given path for the identified defense.
    func upgrade(towerID: String, path: UpgradePath) {
        guard let viewModel,
              let tower = towers.first(where: { $0.id == towerID }) else { return }

        let level = path == .alpha ? tower.pathALevel : tower.pathBLevel
        guard let cost = tower.type.upgradeCost(path: path, currentLevel: level) else { return }
        guard viewModel.spendGold(cost) else {
            flashStatus("Not enough credits for that upgrade.")
            return
        }

        tower.increaseUpgrade(path: path)
        let title = path == .alpha ? tower.type.pathATitle : tower.type.pathBTitle
        if tower.type == .laser && path == .beta && tower.pathBLevel == 3 {
            flashStatus("Tachyon Optics maxed — this Laser Turret now sees cloaked enemies!")
        } else {
            flashStatus("\(title) upgraded to level \(level + 1)!")
        }
        publishPanel(for: tower)
    }

    // MARK: Active Abilities

    /// Triggered from the sidebar's ability button.
    func activateAbility(towerID: String) {
        guard let tower = towers.first(where: { $0.id == towerID }) else { return }
        triggerAbility(for: tower)
    }

    private func triggerAbility(for tower: TowerNode) {
        guard let viewModel else { return }
        guard viewModel.isAbilityReady(towerID: tower.id, type: tower.type) else {
            let remaining = viewModel.abilityCooldownRemaining(towerID: tower.id, type: tower.type)
            flashStatus("\(tower.type.abilitySignature) recharging — \(Int(ceil(remaining)))s left.")
            return
        }
        viewModel.recordAbilityUse(towerID: tower.id)

        switch tower.type {
        case .laser:      executePhaseScanner(tower)
        case .emp:        executeEMPShockwave(tower)
        case .plasma:     executeOverload(tower)
        case .missile:    executeBarrage(tower)
        case .ion:        executeStormDischarge(tower)
        case .gravity:    executeStasisField(tower)
        case .scanner:    executeDeepScan(tower)
        case .satellite:  executeOrbitalBombardment(tower)
        case .quantum:    executePhaseLance(tower)
        case .alien:      executeHarmonicSurge(tower)
        case .darkMatter: executeSingularity(tower)
        }
    }

    private func executePhaseScanner(_ tower: TowerNode) {
        tower.isCamoDetectionActive = true
        tower.camoDetectionEndTime = gameTime + tower.type.camoVisionDuration
        tower.refreshRangeRing()
        showExpandingRing(at: tower.position, radius: tower.effectiveRange,
                          tint: SKColor(red: 0.40, green: 0.95, blue: 1.0, alpha: 0.8))
        flashStatus("Phase Scanner active for \(Int(tower.type.camoVisionDuration))s!")
    }

    private func executeEMPShockwave(_ tower: TowerNode) {
        showExpandingRing(at: tower.position, radius: tower.effectiveRange,
                          tint: SKColor(red: 1.0, green: 0.65, blue: 0.1, alpha: 0.9))
        var totalReward = 0
        for enemy in enemies {
            let dx = enemy.position.x - tower.position.x
            let dy = enemy.position.y - tower.position.y
            if sqrt(dx * dx + dy * dy) <= tower.effectiveRange {
                let dmg = enemy.isRobotic ? tower.type.ringBurstDamage * 2 : tower.type.ringBurstDamage
                let popped = enemy.applyDamage(dmg)
                totalReward += rewardForPops(enemy: enemy, popped: popped)
            }
        }
        cleanUpDestroyedEnemies(rewarding: totalReward)
        flashStatus("EMP Shockwave detonated!")
    }

    private func executeOverload(_ tower: TowerNode) {
        tower.damageBuffEndTime = gameTime + 6
        showExpandingRing(at: tower.position, radius: tower.type.bodyRadius * 3,
                          tint: tower.type.projectileTint.skColor)
        flashStatus("Plasma Overload — double damage for 6s!")
    }

    private func executeBarrage(_ tower: TowerNode) {
        let canSee = tower.canSeeInvisible(globalReveal: gameTime < globalRevealEndTime)
        let targets = enemies
            .filter { enemy in
                guard enemy.currentHealth > 0, (!enemy.isCamo || canSee) else { return false }
                let dx = enemy.position.x - tower.position.x
                let dy = enemy.position.y - tower.position.y
                return sqrt(dx * dx + dy * dy) <= tower.effectiveRange
            }
            .sorted { $0.distanceTraveled > $1.distanceTraveled }
            .prefix(5)

        var totalReward = 0
        for enemy in targets {
            showExplosion(at: enemy.position, radius: tower.type.splashRadius,
                          tint: tower.type.projectileTint.skColor)
            totalReward += applySplashDamage(at: enemy.position, damage: 2,
                                             radius: tower.type.splashRadius, bonusVsRobotic: false)
        }
        cleanUpDestroyedEnemies(rewarding: totalReward)
        flashStatus("Missile Barrage launched!")
    }

    private func executeStormDischarge(_ tower: TowerNode) {
        var totalReward = 0
        for enemy in enemies {
            let dx = enemy.position.x - tower.position.x
            let dy = enemy.position.y - tower.position.y
            if sqrt(dx * dx + dy * dy) <= tower.effectiveRange {
                showLightning(from: tower.position, to: enemy.position,
                              tint: tower.type.projectileTint.skColor)
                let popped = enemy.applyDamage(2)
                totalReward += rewardForPops(enemy: enemy, popped: popped)
            }
        }
        cleanUpDestroyedEnemies(rewarding: totalReward)
        flashStatus("Storm Discharge!")
    }

    private func executeStasisField(_ tower: TowerNode) {
        tower.stasisEndTime = gameTime + 4
        showExpandingRing(at: tower.position, radius: tower.effectiveRange,
                          tint: tower.type.projectileTint.skColor)
        flashStatus("Stasis Field — enemies nearly frozen for 4s!")
    }

    private func executeDeepScan(_ tower: TowerNode) {
        globalRevealEndTime = gameTime + 10
        showExpandingRing(at: tower.position, radius: GameConfig.canvasWidth,
                          tint: tower.type.projectileTint.skColor)
        flashStatus("Deep Scan — all cloaked enemies revealed for 10s!")
    }

    private func executeOrbitalBombardment(_ tower: TowerNode) {
        let canSee = tower.canSeeInvisible(globalReveal: gameTime < globalRevealEndTime)
        let targets = enemies
            .filter { $0.currentHealth > 0 && (!$0.isCamo || canSee) }
            .sorted { $0.distanceTraveled > $1.distanceTraveled }
            .prefix(3)

        var totalReward = 0
        for enemy in targets {
            showOrbitalBeam(at: enemy.position, tint: tower.type.projectileTint.skColor)
            totalReward += applySplashDamage(at: enemy.position, damage: 5,
                                             radius: tower.type.splashRadius, bonusVsRobotic: false)
        }
        cleanUpDestroyedEnemies(rewarding: totalReward)
        flashStatus("Orbital Bombardment inbound!")
    }

    private func executePhaseLance(_ tower: TowerNode) {
        guard let target = enemies
            .filter({ $0.currentHealth > 0 })
            .max(by: { $0.distanceTraveled < $1.distanceTraveled }) else {
            flashStatus("No targets for Phase Lance.")
            return
        }
        let reward = performPierce(from: tower.position, through: target.position,
                                   damage: 4, length: 1400,
                                   tint: tower.type.projectileTint.skColor)
        cleanUpDestroyedEnemies(rewarding: reward)
        flashStatus("Phase Lance fired across the sector!")
    }

    private func executeHarmonicSurge(_ tower: TowerNode) {
        globalRateBuffEndTime = gameTime + 6
        for other in towers {
            showExpandingRing(at: other.position, radius: other.type.bodyRadius * 2.2,
                              tint: tower.type.projectileTint.skColor)
        }
        flashStatus("Harmonic Surge — all defenses firing 50% faster!")
    }

    private func executeSingularity(_ tower: TowerNode) {
        let flash = SKShapeNode(rectOf: GameConfig.canvasSize)
        flash.position = CGPoint(x: GameConfig.canvasWidth / 2, y: GameConfig.canvasHeight / 2)
        flash.fillColor = SKColor(red: 0.85, green: 0.45, blue: 1.0, alpha: 1.0)
        flash.strokeColor = .clear
        flash.alpha = 0.0
        flash.zPosition = 90
        addChild(flash)
        flash.run(.sequence([
            .fadeAlpha(to: 0.85, duration: 0.08),
            .fadeOut(withDuration: 0.5),
            .removeFromParent()
        ]))

        var totalReward = 0
        for enemy in enemies {
            let popped = enemy.applyDamage(tower.type.screenFlashDamage)
            totalReward += rewardForPops(enemy: enemy, popped: popped)
        }
        cleanUpDestroyedEnemies(rewarding: totalReward)
        flashStatus("Singularity unleashed!")
    }

    // MARK: Placement

    private func attemptPlacement(of type: TowerType, at location: CGPoint) {
        guard let viewModel else { return }

        let valid = isPlacementValid(at: location, bodyRadius: type.bodyRadius)
        guard valid else {
            flashStatus("Can't deploy there — too close to the corridor or another defense.")
            DispatchQueue.main.async { viewModel.selectedTowerType = nil }
            return
        }
        guard viewModel.spendGold(type.cost) else {
            flashStatus("Not enough credits for \(type.displayName).")
            DispatchQueue.main.async { viewModel.selectedTowerType = nil }
            return
        }

        let tower = TowerNode(type: type, position: location)
        towers.append(tower)
        addChild(tower)
        tower.setScale(0.3)
        tower.run(.scale(to: 1.0, duration: 0.2))
        flashStatus("\(type.displayName) deployed. Tap it to upgrade or fire \(type.abilitySignature).")
        DispatchQueue.main.async { viewModel.selectedTowerType = nil }
    }

    /// Valid placement: inside canvas, off the track corridor, not overlapping defenses.
    private func isPlacementValid(at point: CGPoint, bodyRadius: CGFloat) -> Bool {
        guard point.x > bodyRadius, point.x < GameConfig.canvasWidth - bodyRadius,
              point.y > bodyRadius, point.y < GameConfig.canvasHeight - bodyRadius else { return false }

        let clearance = GameConfig.trackWidth / 2 + bodyRadius
        let pts = map.waypoints
        for i in 0..<(pts.count - 1) {
            if distanceToSegment(point: point, a: pts[i], b: pts[i + 1]) < clearance {
                return false
            }
        }
        for tower in towers {
            let dx = tower.position.x - point.x
            let dy = tower.position.y - point.y
            if sqrt(dx * dx + dy * dy) < tower.type.bodyRadius + bodyRadius + 4 {
                return false
            }
        }
        return true
    }

    private func distanceToSegment(point p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let abx = b.x - a.x
        let aby = b.y - a.y
        let lengthSquared = abx * abx + aby * aby
        guard lengthSquared > 0 else {
            return hypot(p.x - a.x, p.y - a.y)
        }
        let t = max(0, min(1, ((p.x - a.x) * abx + (p.y - a.y) * aby) / lengthSquared))
        let proj = CGPoint(x: a.x + t * abx, y: a.y + t * aby)
        return hypot(p.x - proj.x, p.y - proj.y)
    }

    // MARK: Frame Loop

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let rawDelta = min(currentTime - lastUpdateTime, 1.0 / 20.0)
        lastUpdateTime = currentTime

        guard let viewModel, viewModel.isSimulationActive else { return }

        // Fast-forward scales the simulation clock; all per-tick math below
        // consumes the scaled delta so collisions stay consistent.
        let speedScale = CGFloat(viewModel.gameSpeed)
        let deltaTime = rawDelta * viewModel.gameSpeed
        gameTime += deltaTime

        runSpawning(deltaTime: deltaTime)
        runAuras()
        runTraversal(deltaTime: deltaTime)
        runCamoVisionExpiry()
        runTargeting()
        runProjectiles(speedScale: speedScale)
    }

    /// Computes per-frame field effects: gravity slows, scanner detection,
    /// haste auras, and the global Deep Scan reveal.
    private func runAuras() {
        let globalReveal = gameTime < globalRevealEndTime

        for enemy in enemies {
            enemy.slowMultiplier = 1.0
            if enemy.isCamo {
                enemy.setRevealed(globalReveal)
            }
        }
        for tower in towers {
            tower.isScannerBuffed = false
            tower.auraRateFactor = 1.0
        }

        for tower in towers {
            switch tower.type.behavior {
            case .slowField:
                let slow = CGFloat(tower.currentSlowStrength(at: gameTime))
                for enemy in enemies {
                    let dx = enemy.position.x - tower.position.x
                    let dy = enemy.position.y - tower.position.y
                    if sqrt(dx * dx + dy * dy) <= tower.effectiveRange {
                        // The distortion field is physical: it slows cloaked enemies too.
                        enemy.slowMultiplier = min(enemy.slowMultiplier, 1.0 - slow)
                    }
                }

            case .scannerSupport:
                let haste = Double(tower.pathALevel) * 0.06
                for other in towers where other !== tower {
                    let dx = other.position.x - tower.position.x
                    let dy = other.position.y - tower.position.y
                    if sqrt(dx * dx + dy * dy) <= tower.effectiveRange {
                        other.isScannerBuffed = true
                        if haste > 0 {
                            other.auraRateFactor = min(other.auraRateFactor, 1.0 - haste)
                        }
                    }
                }

            case .rateSupport:
                let haste = tower.currentHasteStrength
                for other in towers where other !== tower {
                    let dx = other.position.x - tower.position.x
                    let dy = other.position.y - tower.position.y
                    if sqrt(dx * dx + dy * dy) <= tower.effectiveRange {
                        other.auraRateFactor = min(other.auraRateFactor, 1.0 - haste)
                    }
                }

            default:
                break
            }
        }
    }

    /// Moves every active enemy toward its next waypoint using the vector formula.
    private func runTraversal(deltaTime: TimeInterval) {
        var leaks = 0
        var survivors: [EnemyNode] = []
        survivors.reserveCapacity(enemies.count)

        for enemy in enemies {
            let exited = enemy.advance(deltaTime: deltaTime)
            if exited {
                leaks += 1
                enemy.removeFromParent()
            } else {
                survivors.append(enemy)
            }
        }
        enemies = survivors

        if leaks > 0 {
            DispatchQueue.main.async { [weak viewModel] in
                for _ in 0..<leaks { viewModel?.loseLife() }
            }
        }
    }

    private func runCamoVisionExpiry() {
        for tower in towers where tower.isCamoDetectionActive {
            if gameTime >= tower.camoDetectionEndTime {
                tower.isCamoDetectionActive = false
                tower.refreshRangeRing()
            }
        }
    }

    /// Evaluates reload intervals and dispatches each defense's attack behavior.
    private func runTargeting() {
        let globalReveal = gameTime < globalRevealEndTime
        let globalRate = gameTime < globalRateBuffEndTime ? 0.5 : 1.0

        for tower in towers {
            let behavior = tower.type.behavior
            guard behavior.isAttacking else { continue }

            let cooldown = tower.effectiveCooldown * tower.auraRateFactor * globalRate
            guard gameTime - tower.lastFireTime >= cooldown else { continue }

            let canSee = tower.canSeeInvisible(globalReveal: globalReveal)
            let candidates = enemies.filter { enemy in
                guard enemy.currentHealth > 0 else { return false }
                // Strict cloak check: skip Phantoms unless this tower can detect them.
                if enemy.isCamo && !canSee { return false }
                let dx = enemy.position.x - tower.position.x
                let dy = enemy.position.y - tower.position.y
                return sqrt(dx * dx + dy * dy) <= tower.effectiveRange
            }

            guard let target = candidates.max(by: { $0.distanceTraveled < $1.distanceTraveled }) else { continue }

            tower.lastFireTime = gameTime
            tower.aim(at: target.position)

            let tint = tower.type.projectileTint.skColor
            let damage = tower.currentDamage(at: gameTime)

            switch behavior {
            case .singleTarget, .splashMissile:
                let dx = target.position.x - tower.position.x
                let dy = target.position.y - tower.position.y
                let dist = max(sqrt(dx * dx + dy * dy), 0.001)
                let projectile = ProjectileNode(from: tower.position,
                                                target: target,
                                                direction: CGVector(dx: dx / dist, dy: dy / dist),
                                                damage: damage,
                                                tint: tint,
                                                splashRadius: tower.type.splashRadius)
                projectiles.append(projectile)
                addChild(projectile)

            case .radialBurst:
                for i in 0..<8 {
                    let angle = CGFloat(i) * (.pi / 4)
                    let projectile = ProjectileNode(from: tower.position,
                                                    target: nil,
                                                    direction: CGVector(dx: cos(angle), dy: sin(angle)),
                                                    damage: damage,
                                                    tint: tint,
                                                    bonusVsRobotic: true)
                    projectiles.append(projectile)
                    addChild(projectile)
                }

            case .chainLightning:
                let reward = performChain(from: tower, start: target, damage: damage, canSee: canSee)
                cleanUpDestroyedEnemies(rewarding: reward)

            case .piercingBeam:
                let reward = performPierce(from: tower.position, through: target.position,
                                           damage: damage, length: tower.effectiveRange,
                                           tint: tint)
                cleanUpDestroyedEnemies(rewarding: reward)

            case .orbitalStrike:
                showOrbitalBeam(at: target.position, tint: tint)
                let reward = applySplashDamage(at: target.position, damage: damage,
                                               radius: tower.type.splashRadius, bonusVsRobotic: false)
                cleanUpDestroyedEnemies(rewarding: reward)

            case .slowField, .scannerSupport, .rateSupport:
                break
            }
        }
    }

    /// Instant chain-lightning arc jumping between nearby enemies with decaying damage.
    private func performChain(from tower: TowerNode, start: EnemyNode, damage: Int, canSee: Bool) -> Int {
        var visited = Set<UUID>()
        var current: EnemyNode? = start
        var previousPoint = tower.position
        var reward = 0
        var hop = 0

        while let enemy = current, hop < tower.type.chainHops {
            showLightning(from: previousPoint, to: enemy.position,
                          tint: tower.type.projectileTint.skColor)
            let hopDamage = max(1, damage - hop)
            let popped = enemy.applyDamage(hopDamage)
            reward += rewardForPops(enemy: enemy, popped: popped)
            visited.insert(enemy.id)
            previousPoint = enemy.position
            hop += 1

            current = enemies
                .filter { candidate in
                    guard !visited.contains(candidate.id), candidate.currentHealth > 0,
                          (!candidate.isCamo || canSee) else { return false }
                    return hypot(candidate.position.x - previousPoint.x,
                                 candidate.position.y - previousPoint.y) <= tower.type.chainJumpDistance
                }
                .min { lhs, rhs in
                    hypot(lhs.position.x - previousPoint.x, lhs.position.y - previousPoint.y)
                        < hypot(rhs.position.x - previousPoint.x, rhs.position.y - previousPoint.y)
                }
        }
        return reward
    }

    /// Instant piercing beam damaging every enemy along the line.
    @discardableResult
    private func performPierce(from origin: CGPoint, through targetPoint: CGPoint,
                               damage: Int, length: CGFloat, tint: SKColor) -> Int {
        let dx = targetPoint.x - origin.x
        let dy = targetPoint.y - origin.y
        let dist = max(sqrt(dx * dx + dy * dy), 0.001)
        let end = CGPoint(x: origin.x + dx / dist * length,
                          y: origin.y + dy / dist * length)
        showBeam(from: origin, to: end, tint: tint, width: 5)

        var reward = 0
        for enemy in enemies where enemy.currentHealth > 0 {
            if distanceToSegment(point: enemy.position, a: origin, b: end)
                <= enemy.originalType.radius + 8 {
                let popped = enemy.applyDamage(damage)
                reward += rewardForPops(enemy: enemy, popped: popped)
            }
        }
        return reward
    }

    /// Area damage application used by missiles, orbital strikes, and abilities.
    private func applySplashDamage(at point: CGPoint, damage: Int,
                                   radius: CGFloat, bonusVsRobotic: Bool) -> Int {
        var reward = 0
        for enemy in enemies where enemy.currentHealth > 0 {
            let dx = enemy.position.x - point.x
            let dy = enemy.position.y - point.y
            if sqrt(dx * dx + dy * dy) <= radius + enemy.originalType.radius {
                let dmg = (enemy.isRobotic && bonusVsRobotic) ? damage * 2 : damage
                let popped = enemy.applyDamage(dmg)
                reward += rewardForPops(enemy: enemy, popped: popped)
            }
        }
        return reward
    }

    /// Advances projectiles, homing on live targets, and resolves collisions.
    private func runProjectiles(speedScale: CGFloat) {
        var totalReward = 0
        var surviving: [ProjectileNode] = []
        surviving.reserveCapacity(projectiles.count)

        for projectile in projectiles {
            // Re-home on the tracked target while it remains alive.
            if let target = projectile.target, target.currentHealth > 0, target.parent != nil {
                let dx = target.position.x - projectile.position.x
                let dy = target.position.y - projectile.position.y
                let dist = max(sqrt(dx * dx + dy * dy), 0.001)
                projectile.direction = CGVector(dx: dx / dist, dy: dy / dist)
                projectile.zRotation = atan2(dy, dx) - .pi / 2
            }

            projectile.position.x += projectile.direction.dx * projectile.flightSpeed * speedScale
            projectile.position.y += projectile.direction.dy * projectile.flightSpeed * speedScale

            // Off-canvas culling.
            if projectile.position.x < -30 || projectile.position.x > GameConfig.canvasWidth + 30 ||
               projectile.position.y < -30 || projectile.position.y > GameConfig.canvasHeight + 30 {
                projectile.removeFromParent()
                continue
            }

            // Collision check against all enemies (radial EMP bolts hit anything).
            var hit = false
            for enemy in enemies where enemy.currentHealth > 0 {
                let dx = enemy.position.x - projectile.position.x
                let dy = enemy.position.y - projectile.position.y
                let hitRadius = enemy.originalType.radius + 5
                if dx * dx + dy * dy <= hitRadius * hitRadius {
                    if projectile.splashRadius > 0 {
                        showExplosion(at: enemy.position, radius: projectile.splashRadius,
                                      tint: projectile.fillColor)
                        totalReward += applySplashDamage(at: enemy.position,
                                                         damage: projectile.damage,
                                                         radius: projectile.splashRadius,
                                                         bonusVsRobotic: projectile.bonusVsRobotic)
                    } else {
                        let dmg = (enemy.isRobotic && projectile.bonusVsRobotic)
                            ? projectile.damage * 2 : projectile.damage
                        let popped = enemy.applyDamage(dmg)
                        totalReward += rewardForPops(enemy: enemy, popped: popped)
                        spawnPopBurst(at: enemy.position, tint: projectile.fillColor)
                    }
                    hit = true
                    break
                }
            }

            if hit {
                projectile.removeFromParent()
            } else {
                surviving.append(projectile)
            }
        }

        projectiles = surviving
        cleanUpDestroyedEnemies(rewarding: totalReward)
    }

    // MARK: Rewards & Cleanup

    /// Credits: small income per layer destroyed, plus the destruction bonus.
    private func rewardForPops(enemy: EnemyNode, popped: Int) -> Int {
        guard popped > 0 else { return 0 }
        var reward = popped
        if enemy.currentHealth <= 0 {
            reward += enemy.originalType.reward
        }
        return reward
    }

    private func cleanUpDestroyedEnemies(rewarding reward: Int) {
        let destroyed = enemies.filter { $0.currentHealth <= 0 }
        guard !destroyed.isEmpty || reward > 0 else { return }

        for enemy in destroyed {
            spawnDeathBurst(at: enemy.position, tint: enemy.strokeColor,
                            big: enemy.originalType == .behemoth)
            enemy.removeFromParent()
        }
        enemies.removeAll { $0.currentHealth <= 0 }

        if reward > 0 {
            DispatchQueue.main.async { [weak viewModel] in
                viewModel?.earnGold(reward)
            }
        }
    }

    // MARK: Visual Effects

    private func spawnPopBurst(at point: CGPoint, tint: SKColor) {
        for i in 0..<6 {
            let shard = SKShapeNode(circleOfRadius: 2.5)
            shard.position = point
            shard.fillColor = tint
            shard.strokeColor = .clear
            shard.glowWidth = 2
            shard.zPosition = 30
            addChild(shard)
            let angle = CGFloat(i) * (.pi / 3)
            let move = SKAction.moveBy(x: cos(angle) * 22, y: sin(angle) * 22, duration: 0.25)
            shard.run(.sequence([.group([move, .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
        }
    }

    /// Destruction effect: shard burst plus an expanding shock ring.
    private func spawnDeathBurst(at point: CGPoint, tint: SKColor, big: Bool) {
        let shardCount = big ? 12 : 8
        let throwDistance: CGFloat = big ? 44 : 26
        for i in 0..<shardCount {
            let shard = SKShapeNode(circleOfRadius: big ? 3.5 : 2.5)
            shard.position = point
            shard.fillColor = tint
            shard.strokeColor = .clear
            shard.glowWidth = 2
            shard.zPosition = 30
            addChild(shard)
            let angle = CGFloat(i) * (2 * .pi / CGFloat(shardCount))
            let move = SKAction.moveBy(x: cos(angle) * throwDistance,
                                       y: sin(angle) * throwDistance, duration: 0.3)
            shard.run(.sequence([.group([move, .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        }
        let ring = SKShapeNode(circleOfRadius: big ? 16 : 9)
        ring.position = point
        ring.fillColor = .clear
        ring.strokeColor = tint
        ring.lineWidth = 2
        ring.glowWidth = 3
        ring.zPosition = 30
        addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: big ? 3.0 : 2.2, duration: 0.3), .fadeOut(withDuration: 0.3)]),
            .removeFromParent()
        ]))
    }

    private func showExpandingRing(at point: CGPoint, radius: CGFloat, tint: SKColor) {
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = point
        ring.fillColor = tint.withAlphaComponent(0.18)
        ring.strokeColor = tint
        ring.lineWidth = 3
        ring.glowWidth = 5
        ring.zPosition = 40
        ring.setScale(0.1)
        addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1.0, duration: 0.3), .fadeOut(withDuration: 0.55)]),
            .removeFromParent()
        ]))
    }

    private func showLightning(from a: CGPoint, to b: CGPoint, tint: SKColor) {
        let path = CGMutablePath()
        path.move(to: a)
        let dx = b.x - a.x
        let dy = b.y - a.y
        // Jittered midpoints perpendicular to the arc for a lightning look.
        let perpX = -dy * 0.18
        let perpY = dx * 0.18
        path.addLine(to: CGPoint(x: a.x + dx * 0.33 + perpX, y: a.y + dy * 0.33 + perpY))
        path.addLine(to: CGPoint(x: a.x + dx * 0.66 - perpX, y: a.y + dy * 0.66 - perpY))
        path.addLine(to: b)

        let bolt = SKShapeNode(path: path)
        bolt.strokeColor = tint
        bolt.lineWidth = 2
        bolt.glowWidth = 3
        bolt.zPosition = 35
        addChild(bolt)
        bolt.run(.sequence([.fadeOut(withDuration: 0.18), .removeFromParent()]))
    }

    private func showBeam(from a: CGPoint, to b: CGPoint, tint: SKColor, width: CGFloat) {
        let path = CGMutablePath()
        path.move(to: a)
        path.addLine(to: b)
        let beam = SKShapeNode(path: path)
        beam.strokeColor = tint
        beam.lineWidth = width
        beam.lineCap = .round
        beam.glowWidth = 5
        beam.zPosition = 35
        addChild(beam)
        beam.run(.sequence([.fadeOut(withDuration: 0.22), .removeFromParent()]))
    }

    private func showOrbitalBeam(at point: CGPoint, tint: SKColor) {
        showBeam(from: CGPoint(x: point.x, y: GameConfig.canvasHeight + 20),
                 to: point, tint: tint, width: 6)
        showExplosion(at: point, radius: 40, tint: tint)
    }

    private func showExplosion(at point: CGPoint, radius: CGFloat, tint: SKColor) {
        let blast = SKShapeNode(circleOfRadius: radius)
        blast.position = point
        blast.fillColor = tint.withAlphaComponent(0.35)
        blast.strokeColor = tint
        blast.lineWidth = 2
        blast.glowWidth = 4
        blast.zPosition = 35
        blast.setScale(0.2)
        addChild(blast)
        blast.run(.sequence([
            .group([.scale(to: 1.0, duration: 0.18), .fadeOut(withDuration: 0.35)]),
            .removeFromParent()
        ]))
    }

    private func flashStatus(_ message: String) {
        DispatchQueue.main.async { [weak viewModel] in
            viewModel?.statusMessage = message
        }
    }

    // MARK: Full Reset

    func resetSimulation() {
        for enemy in enemies { enemy.removeFromParent() }
        for tower in towers { tower.removeFromParent() }
        for projectile in projectiles { projectile.removeFromParent() }
        enemies.removeAll()
        towers.removeAll()
        projectiles.removeAll()
        spawnQueue.removeAll()
        selectedTower = nil
        waveInFlight = false
        timeSinceWaveEnded = 0
        timeSinceLastSpawn = 0
        gameTime = 0
        globalRevealEndTime = 0
        globalRateBuffEndTime = 0
        queueWave(1)
    }
}

// MARK: - Deterministic RNG for scenery

/// Simple seeded generator so the programmatic backdrop is stable between launches.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
