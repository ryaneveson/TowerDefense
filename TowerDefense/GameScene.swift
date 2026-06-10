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

// MARK: - Enemy Node ("Glitch Bug")

final class EnemyNode: SKShapeNode {
    let id = UUID()
    let originalType: EnemyType
    private let waypoints: [CGPoint]
    private(set) var currentHealth: Int
    private(set) var waypointIndex: Int = 1

    /// Total track distance covered so far; used to rank "furthest progressed".
    private(set) var distanceTraveled: CGFloat = 0

    var isCamo: Bool { originalType.isCamo && currentHealth > 0 }

    /// Speed reflects the current visible tier (a damaged Volt Beetle moves like a Glitch Mite).
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

    /// Rebuilds the programmatic glitch-bug chassis to match the current tier.
    private func redrawBody() {
        removeAllChildren()
        let tier = EnemyType.tier(forRemainingHealth: currentHealth, original: originalType)
        let r = tier.radius

        // Hexagonal chassis.
        let chassis = CGMutablePath()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 + .pi / 6
            let pt = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            if i == 0 { chassis.move(to: pt) } else { chassis.addLine(to: pt) }
        }
        chassis.closeSubpath()
        path = chassis

        let c = tier.color
        fillColor = SKColor(red: c.red, green: c.green, blue: c.blue, alpha: 0.92)
        strokeColor = c.brighterSKColor
        lineWidth = 2
        glowWidth = 3

        // Bright energy core.
        let core = SKShapeNode(circleOfRadius: r * 0.40)
        core.fillColor = SKColor(white: 1.0, alpha: 0.85)
        core.strokeColor = .clear
        core.zPosition = 1
        addChild(core)

        // Splayed legs on both flanks.
        for side in [CGFloat(-1), CGFloat(1)] {
            for i in -1...1 {
                let leg = SKShapeNode(rectOf: CGSize(width: r * 0.85, height: 2), cornerRadius: 1)
                leg.fillColor = strokeColor
                leg.strokeColor = .clear
                leg.position = CGPoint(x: side * r * 0.95, y: CGFloat(i) * r * 0.55)
                leg.zRotation = side * CGFloat(i) * 0.45
                addChild(leg)
            }
        }

        // Phantom Crawlers shimmer behind a cloak ring.
        if originalType.isCamo {
            alpha = 0.55
            let cloak = SKShapeNode(circleOfRadius: r * 1.3)
            cloak.fillColor = .clear
            cloak.strokeColor = SKColor(red: 0.75, green: 0.55, blue: 1.0, alpha: 0.55)
            cloak.lineWidth = 1.5
            cloak.zPosition = 2
            addChild(cloak)
        } else {
            alpha = 1.0
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
        var remainingStep = currentSpeed * 60 * CGFloat(deltaTime)

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

// MARK: - Tower Node (Sci-Fi Turret)

final class TowerNode: SKShapeNode {
    let id = UUID().uuidString
    let type: TowerType
    var lastFireTime: TimeInterval = 0

    /// Upgrade tiers (alpha = fire rate, beta = damage/range).
    private(set) var pathALevel: Int = 0
    private(set) var pathBLevel: Int = 0

    /// Cloak detection flag — altered exclusively by the Phase Scanner ability.
    var isCamoDetectionActive: Bool = false
    var camoDetectionEndTime: TimeInterval = 0

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

        switch type {
        case .dartNode:
            // Long precision beam barrel with an emitter lens.
            let barrel = SKShapeNode(rectOf: CGSize(width: 7, height: 24), cornerRadius: 3)
            barrel.fillColor = SKColor(white: 0.15, alpha: 1.0)
            barrel.strokeColor = SKColor(white: 0.45, alpha: 1.0)
            barrel.position = CGPoint(x: 0, y: r * 0.85)
            turretHead.addChild(barrel)

            let lens = SKShapeNode(circleOfRadius: 3.5)
            lens.fillColor = type.projectileTint.skColor
            lens.strokeColor = .clear
            lens.glowWidth = 3
            lens.position = CGPoint(x: 0, y: r * 0.85 + 12)
            turretHead.addChild(lens)

        case .tackNode:
            // Eight stub emitters in a radial array.
            for i in 0..<8 {
                let angle = CGFloat(i) * (.pi / 4)
                let stub = SKShapeNode(rectOf: CGSize(width: 5, height: 12), cornerRadius: 2)
                stub.fillColor = SKColor(white: 0.15, alpha: 1.0)
                stub.strokeColor = type.projectileTint.skColor
                stub.lineWidth = 1
                stub.position = CGPoint(x: cos(angle) * (r + 2), y: sin(angle) * (r + 2))
                stub.zRotation = angle - .pi / 2
                turretHead.addChild(stub)
            }

        case .superNode:
            // Pulsing plasma orb.
            let orb = SKShapeNode(circleOfRadius: r * 0.55)
            orb.fillColor = type.projectileTint.skColor
            orb.strokeColor = SKColor(white: 1.0, alpha: 0.9)
            orb.lineWidth = 1.5
            orb.glowWidth = 5
            turretHead.addChild(orb)
            orb.run(.repeatForever(.sequence([
                .scale(to: 1.18, duration: 0.6),
                .scale(to: 0.92, duration: 0.6)
            ])))
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
        let radius = effectiveRange
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

// MARK: - Projectile Node (Energy Bolt)

final class ProjectileNode: SKShapeNode {
    let damage: Int
    let flightSpeed: CGFloat = 9.0
    weak var target: EnemyNode?
    /// Fallback direction used when the target dies mid-flight or for radial bursts.
    var direction: CGVector

    init(from origin: CGPoint, target: EnemyNode?, direction: CGVector, damage: Int, tint: SKColor) {
        self.damage = damage
        self.target = target
        self.direction = direction
        super.init()
        position = origin
        zPosition = 8
        name = "projectile"
        // Glowing energy bolt capsule.
        path = CGPath(roundedRect: CGRect(x: -2, y: -9, width: 4, height: 18),
                      cornerWidth: 2, cornerHeight: 2, transform: nil)
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
        drawScenery()
        drawTrack()
        queueWave(1)
    }

    private func drawScenery() {
        // Programmatic terrain variation: scattered darker patches.
        var generator = SeededGenerator(seed: 42)
        let scenery = map.theme.scenery
        for _ in 0..<40 {
            let patch = SKShapeNode(ellipseOf: CGSize(width: CGFloat.random(in: 20...70, using: &generator),
                                                      height: CGFloat.random(in: 12...40, using: &generator)))
            patch.position = CGPoint(x: CGFloat.random(in: 0...GameConfig.canvasWidth, using: &generator),
                                     y: CGFloat.random(in: 0...GameConfig.canvasHeight, using: &generator))
            patch.fillColor = scenery.skColor
            patch.strokeColor = .clear
            patch.zPosition = 0
            addChild(patch)
        }
    }

    /// Renders a visible thick track underneath the waypoint sequence,
    /// finished with an energized neon center line.
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

    // MARK: Wave Spawning

    private func queueWave(_ wave: Int) {
        let count = GameConfig.baseEnemiesPerWave + wave * GameConfig.extraEnemiesPerWave
        var queue: [EnemyType] = []
        for i in 0..<count {
            if wave >= 3 && i % 5 == 4 {
                queue.append(.camo)
            } else if wave >= 2 && i % 2 == 1 {
                queue.append(.blue)
            } else {
                queue.append(.red)
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
                                  range: Int(tower.effectiveRange.rounded()),
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
        flashStatus("\(title) upgraded to level \(level + 1)!")
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
        case .dartNode:
            executePhaseScanner(tower)
        case .tackNode:
            executeEMPShockwave(tower)
        case .superNode:
            executePlasmaStorm(tower)
        }
    }

    /// Quantum Laser: 8-second phase scanner revealing cloaked Phantoms.
    private func executePhaseScanner(_ tower: TowerNode) {
        tower.isCamoDetectionActive = true
        tower.camoDetectionEndTime = gameTime + tower.type.camoVisionDuration
        tower.refreshRangeRing()

        let flare = SKShapeNode(circleOfRadius: tower.effectiveRange)
        flare.position = tower.position
        flare.fillColor = SKColor(red: 0.40, green: 0.95, blue: 1.0, alpha: 0.22)
        flare.strokeColor = SKColor(red: 0.40, green: 0.95, blue: 1.0, alpha: 0.75)
        flare.zPosition = 40
        flare.setScale(0.1)
        addChild(flare)
        flare.run(.sequence([
            .group([.scale(to: 1.0, duration: 0.35), .fadeOut(withDuration: 0.6)]),
            .removeFromParent()
        ]))
        flashStatus("Phase Scanner active for \(Int(tower.type.camoVisionDuration))s!")
    }

    /// EMP Blaster: localized high-damage electromagnetic shockwave.
    private func executeEMPShockwave(_ tower: TowerNode) {
        let ring = SKShapeNode(circleOfRadius: tower.effectiveRange)
        ring.position = tower.position
        ring.fillColor = SKColor(red: 1.0, green: 0.75, blue: 0.2, alpha: 0.28)
        ring.strokeColor = SKColor(red: 1.0, green: 0.65, blue: 0.1, alpha: 0.9)
        ring.lineWidth = 4
        ring.glowWidth = 6
        ring.zPosition = 40
        ring.setScale(0.1)
        addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1.0, duration: 0.25), .fadeOut(withDuration: 0.45)]),
            .removeFromParent()
        ]))

        var totalReward = 0
        // The shockwave hits every physical enemy inside the radius, cloaked included.
        for enemy in enemies {
            let dx = enemy.position.x - tower.position.x
            let dy = enemy.position.y - tower.position.y
            if sqrt(dx * dx + dy * dy) <= tower.effectiveRange {
                let popped = enemy.applyDamage(tower.type.ringBurstDamage)
                totalReward += rewardForPops(enemy: enemy, popped: popped)
            }
        }
        cleanUpDestroyedEnemies(rewarding: totalReward)
        flashStatus("EMP Shockwave detonated!")
    }

    /// Plasma Overlord: floods the display, dealing massive damage to all onscreen enemies.
    private func executePlasmaStorm(_ tower: TowerNode) {
        let flash = SKShapeNode(rectOf: GameConfig.canvasSize)
        flash.position = CGPoint(x: GameConfig.canvasWidth / 2, y: GameConfig.canvasHeight / 2)
        flash.fillColor = SKColor(red: 1.0, green: 0.6, blue: 1.0, alpha: 1.0)
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
        flashStatus("Plasma Storm unleashed!")
    }

    // MARK: Placement

    private func attemptPlacement(of type: TowerType, at location: CGPoint) {
        guard let viewModel else { return }

        let valid = isPlacementValid(at: location, bodyRadius: type.bodyRadius)
        guard valid else {
            flashStatus("Can't deploy there — too close to the track or another defense.")
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
        runTraversal(deltaTime: deltaTime)
        runCamoVisionExpiry()
        runTargeting()
        runProjectiles(speedScale: speedScale)
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

    /// Evaluates reload intervals and fires at the furthest-progressed valid enemy.
    private func runTargeting() {
        for tower in towers {
            guard gameTime - tower.lastFireTime >= tower.effectiveCooldown else { continue }

            let candidates = enemies.filter { enemy in
                guard enemy.currentHealth > 0 else { return false }
                // Strict cloak check: skip Phantoms unless the phase scanner is running.
                if enemy.isCamo && !tower.isCamoDetectionActive { return false }
                let dx = enemy.position.x - tower.position.x
                let dy = enemy.position.y - tower.position.y
                return sqrt(dx * dx + dy * dy) <= tower.effectiveRange
            }

            guard let target = candidates.max(by: { $0.distanceTraveled < $1.distanceTraveled }) else { continue }

            tower.lastFireTime = gameTime
            tower.aim(at: target.position)

            let tint = tower.type.projectileTint.skColor

            if tower.type.firesRadially {
                // EMP Blaster: 8 bolts in a radial spread.
                for i in 0..<8 {
                    let angle = CGFloat(i) * (.pi / 4)
                    let dir = CGVector(dx: cos(angle), dy: sin(angle))
                    let projectile = ProjectileNode(from: tower.position,
                                                    target: nil,
                                                    direction: dir,
                                                    damage: tower.effectiveDamage,
                                                    tint: tint)
                    projectiles.append(projectile)
                    addChild(projectile)
                }
            } else {
                let dx = target.position.x - tower.position.x
                let dy = target.position.y - tower.position.y
                let dist = max(sqrt(dx * dx + dy * dy), 0.001)
                let projectile = ProjectileNode(from: tower.position,
                                                target: target,
                                                direction: CGVector(dx: dx / dist, dy: dy / dist),
                                                damage: tower.effectiveDamage,
                                                tint: tint)
                projectiles.append(projectile)
                addChild(projectile)
            }
        }
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
                    let popped = enemy.applyDamage(projectile.damage)
                    totalReward += rewardForPops(enemy: enemy, popped: popped)
                    spawnPopBurst(at: enemy.position, tint: projectile.fillColor)
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
            spawnPopBurst(at: enemy.position, tint: enemy.strokeColor)
            enemy.removeFromParent()
        }
        enemies.removeAll { $0.currentHealth <= 0 }

        if reward > 0 {
            DispatchQueue.main.async { [weak viewModel] in
                viewModel?.earnGold(reward)
            }
        }
    }

    /// Programmatic particle burst on destruction (no asset files).
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
        queueWave(1)
    }
}

// MARK: - Deterministic RNG for scenery

/// Simple seeded generator so the programmatic scenery is stable between launches.
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
