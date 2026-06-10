import SpriteKit
import SwiftUI

// MARK: - Enemy Node

final class EnemyNode: SKShapeNode {
    let id = UUID()
    let originalType: EnemyType
    private(set) var currentHealth: Int
    private(set) var waypointIndex: Int = 1

    /// Total track distance covered so far; used to rank "furthest progressed".
    private(set) var distanceTraveled: CGFloat = 0

    var isCamo: Bool { originalType.isCamo && currentHealth > 0 }

    /// Speed reflects the current visible tier (a popped Blue moves like a fast Red).
    var currentSpeed: CGFloat {
        EnemyType.tier(forRemainingHealth: currentHealth, original: originalType).speed
    }

    init(type: EnemyType) {
        self.originalType = type
        self.currentHealth = type.healthLayers
        super.init()
        position = GameConfig.waypoints[0]
        zPosition = 5
        name = "enemy"
        redrawBody()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Rebuilds the programmatic balloon shape to match the current tier.
    private func redrawBody() {
        removeAllChildren()
        let tier = EnemyType.tier(forRemainingHealth: currentHealth, original: originalType)
        let r = tier.radius
        let body = CGMutablePath()
        body.addEllipse(in: CGRect(x: -r, y: -r * 1.15, width: r * 2, height: r * 2.3))
        path = body
        let c = tier.color
        fillColor = SKColor(red: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
        strokeColor = SKColor(white: 0.1, alpha: 0.8)
        lineWidth = 1.5

        // Knot at the bottom of the balloon.
        let knot = SKShapeNode(rectOf: CGSize(width: 5, height: 6), cornerRadius: 1.5)
        knot.fillColor = fillColor
        knot.strokeColor = strokeColor
        knot.position = CGPoint(x: 0, y: -r * 1.15 - 3)
        addChild(knot)

        // Camo enemies get a dashed stealth pattern overlay.
        if originalType.isCamo {
            for i in 0..<3 {
                let stripe = SKShapeNode(rectOf: CGSize(width: r * 1.2, height: 3), cornerRadius: 1.5)
                stripe.fillColor = SKColor(red: 0.55, green: 0.65, blue: 0.35, alpha: 0.9)
                stripe.strokeColor = .clear
                stripe.zRotation = .pi / 5
                stripe.position = CGPoint(x: CGFloat(i - 1) * 5, y: CGFloat(i - 1) * 7)
                addChild(stripe)
            }
        }
        alpha = originalType.isCamo ? 0.85 : 1.0
    }

    /// Applies damage. Returns the number of layers actually popped.
    /// Swaps the physical color tier when health drops but remains positive.
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
            guard waypointIndex < GameConfig.waypoints.count else { return true }
            let target = GameConfig.waypoints[waypointIndex]

            let dx = target.x - position.x
            let dy = target.y - position.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance <= remainingStep {
                position = target
                distanceTraveled += distance
                remainingStep -= distance
                waypointIndex += 1
                if waypointIndex >= GameConfig.waypoints.count { return true }
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

// MARK: - Tower Node

final class TowerNode: SKShapeNode {
    let id = UUID().uuidString
    let type: TowerType
    var lastFireTime: TimeInterval = 0

    /// Camo detection flag — altered exclusively by the Dart Monkey ability.
    var isCamoDetectionActive: Bool = false
    var camoDetectionEndTime: TimeInterval = 0

    private let rangeCircle = SKShapeNode()
    private let barrel = SKShapeNode(rectOf: CGSize(width: 8, height: 22), cornerRadius: 3)

    init(type: TowerType, position: CGPoint) {
        self.type = type
        super.init()
        self.position = position
        zPosition = 10
        name = "tower"

        let r = type.bodyRadius
        path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2), transform: nil)
        let c = type.color
        fillColor = SKColor(red: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
        strokeColor = SKColor(white: 0.05, alpha: 1.0)
        lineWidth = 2

        barrel.fillColor = SKColor(white: 0.15, alpha: 1.0)
        barrel.strokeColor = .clear
        barrel.position = CGPoint(x: 0, y: r * 0.7)
        barrel.zPosition = 1
        addChild(barrel)

        rangeCircle.path = CGPath(ellipseIn: CGRect(x: -type.range, y: -type.range,
                                                    width: type.range * 2, height: type.range * 2),
                                  transform: nil)
        rangeCircle.fillColor = SKColor(white: 1.0, alpha: 0.06)
        rangeCircle.strokeColor = SKColor(white: 1.0, alpha: 0.25)
        rangeCircle.lineWidth = 1
        rangeCircle.zPosition = -1
        addChild(rangeCircle)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Rotates the visual barrel to face a target point.
    func aim(at point: CGPoint) {
        let dx = point.x - position.x
        let dy = point.y - position.y
        zRotation = atan2(dy, dx) - .pi / 2
    }

    func setCamoIndicator(active: Bool) {
        if active {
            rangeCircle.strokeColor = SKColor(red: 0.3, green: 0.95, blue: 0.4, alpha: 0.8)
            rangeCircle.lineWidth = 2.5
        } else {
            rangeCircle.strokeColor = SKColor(white: 1.0, alpha: 0.25)
            rangeCircle.lineWidth = 1
        }
    }
}

// MARK: - Projectile Node

final class ProjectileNode: SKShapeNode {
    let damage: Int
    let flightSpeed: CGFloat = 9.0
    weak var target: EnemyNode?
    /// Fallback direction used when the target dies mid-flight or for radial bursts.
    var direction: CGVector

    init(from origin: CGPoint, target: EnemyNode?, direction: CGVector, damage: Int) {
        self.damage = damage
        self.target = target
        self.direction = direction
        super.init()
        position = origin
        zPosition = 8
        name = "projectile"
        // Crisp white geometric dart.
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: 6))
        p.addLine(to: CGPoint(x: 4, y: -5))
        p.addLine(to: CGPoint(x: -4, y: -5))
        p.closeSubpath()
        path = p
        fillColor = .white
        strokeColor = .white
        lineWidth = 1
        zRotation = atan2(direction.dy, direction.dx) - .pi / 2
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }
}

// MARK: - Game Scene

final class GameScene: SKScene {

    weak var viewModel: GameViewModel?

    private var lastUpdateTime: TimeInterval = 0

    // Wave / spawn automation state.
    private var spawnQueue: [EnemyType] = []
    private var timeSinceLastSpawn: TimeInterval = 0
    private var timeSinceWaveEnded: TimeInterval = 0
    private var waveInFlight = false

    private var enemies: [EnemyNode] = []
    private var towers: [TowerNode] = []
    private var projectiles: [ProjectileNode] = []

    private let placementPreview = SKShapeNode()

    // MARK: Setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.13, green: 0.36, blue: 0.18, alpha: 1.0)
        scaleMode = .aspectFit
        drawScenery()
        drawTrack()
        configurePlacementPreview()
        queueWave(1)
    }

    private func drawScenery() {
        // Programmatic grass texture variation: scattered darker patches.
        var generator = SeededGenerator(seed: 42)
        for _ in 0..<40 {
            let patch = SKShapeNode(ellipseOf: CGSize(width: CGFloat.random(in: 20...70, using: &generator),
                                                      height: CGFloat.random(in: 12...40, using: &generator)))
            patch.position = CGPoint(x: CGFloat.random(in: 0...GameConfig.canvasWidth, using: &generator),
                                     y: CGFloat.random(in: 0...GameConfig.canvasHeight, using: &generator))
            patch.fillColor = SKColor(red: 0.11, green: 0.32, blue: 0.16, alpha: 0.6)
            patch.strokeColor = .clear
            patch.zPosition = 0
            addChild(patch)
        }
    }

    /// Renders a visible thick track underneath the waypoint sequence.
    private func drawTrack() {
        let trackPath = CGMutablePath()
        trackPath.move(to: GameConfig.waypoints[0])
        for point in GameConfig.waypoints.dropFirst() {
            trackPath.addLine(to: point)
        }

        let outer = SKShapeNode(path: trackPath)
        outer.strokeColor = SKColor(red: 0.45, green: 0.33, blue: 0.20, alpha: 1.0)
        outer.lineWidth = GameConfig.trackWidth
        outer.lineCap = .round
        outer.lineJoin = .round
        outer.zPosition = 1
        addChild(outer)

        let inner = SKShapeNode(path: trackPath)
        inner.strokeColor = SKColor(red: 0.76, green: 0.62, blue: 0.42, alpha: 1.0)
        inner.lineWidth = GameConfig.trackWidth - 10
        inner.lineCap = .round
        inner.lineJoin = .round
        inner.zPosition = 2
        addChild(inner)
    }

    private func configurePlacementPreview() {
        placementPreview.zPosition = 50
        placementPreview.isHidden = true
        addChild(placementPreview)
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
                let enemy = EnemyNode(type: spawnQueue.removeFirst())
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
            triggerAbility(for: tower)
        }
    }

    private func towerIntersecting(_ point: CGPoint) -> TowerNode? {
        towers.first { tower in
            let dx = tower.position.x - point.x
            let dy = tower.position.y - point.y
            return sqrt(dx * dx + dy * dy) <= tower.type.bodyRadius + 14
        }
    }

    private func attemptPlacement(of type: TowerType, at location: CGPoint) {
        guard let viewModel else { return }

        let valid = isPlacementValid(at: location, bodyRadius: type.bodyRadius)
        guard valid else {
            flashStatus("Can't place there — too close to the track or another tower.")
            DispatchQueue.main.async { viewModel.selectedTowerType = nil }
            return
        }
        guard viewModel.spendGold(type.cost) else {
            flashStatus("Not enough gold for \(type.displayName).")
            DispatchQueue.main.async { viewModel.selectedTowerType = nil }
            return
        }

        let tower = TowerNode(type: type, position: location)
        towers.append(tower)
        addChild(tower)
        flashStatus("\(type.displayName) deployed. Tap it to use \(type.abilitySignature).")
        DispatchQueue.main.async { viewModel.selectedTowerType = nil }
    }

    /// Valid placement: inside canvas, off the track corridor, not overlapping towers.
    private func isPlacementValid(at point: CGPoint, bodyRadius: CGFloat) -> Bool {
        guard point.x > bodyRadius, point.x < GameConfig.canvasWidth - bodyRadius,
              point.y > bodyRadius, point.y < GameConfig.canvasHeight - bodyRadius else { return false }

        let clearance = GameConfig.trackWidth / 2 + bodyRadius
        let pts = GameConfig.waypoints
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

    // MARK: Active Abilities

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
            executeCamoVision(tower)
        case .tackNode:
            executeRingBurst(tower)
        case .superNode:
            executeScreenFlash(tower)
        }
    }

    /// Dart Monkey: 8-second camo vision flare.
    private func executeCamoVision(_ tower: TowerNode) {
        tower.isCamoDetectionActive = true
        tower.camoDetectionEndTime = lastUpdateTime + tower.type.camoVisionDuration
        tower.setCamoIndicator(active: true)

        let flare = SKShapeNode(circleOfRadius: tower.type.range)
        flare.position = tower.position
        flare.fillColor = SKColor(red: 0.3, green: 0.95, blue: 0.4, alpha: 0.25)
        flare.strokeColor = SKColor(red: 0.3, green: 0.95, blue: 0.4, alpha: 0.7)
        flare.zPosition = 40
        flare.setScale(0.1)
        addChild(flare)
        flare.run(.sequence([
            .group([.scale(to: 1.0, duration: 0.35), .fadeOut(withDuration: 0.6)]),
            .removeFromParent()
        ]))
        flashStatus("Camo Vision active for \(Int(tower.type.camoVisionDuration))s!")
    }

    /// Tack Shooter: localized high-damage ring burst within its range.
    private func executeRingBurst(_ tower: TowerNode) {
        let ring = SKShapeNode(circleOfRadius: tower.type.range)
        ring.position = tower.position
        ring.fillColor = SKColor(red: 1.0, green: 0.55, blue: 0.1, alpha: 0.3)
        ring.strokeColor = SKColor(red: 1.0, green: 0.45, blue: 0.05, alpha: 0.9)
        ring.lineWidth = 4
        ring.zPosition = 40
        ring.setScale(0.1)
        addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1.0, duration: 0.25), .fadeOut(withDuration: 0.45)]),
            .removeFromParent()
        ]))

        var totalReward = 0
        // Ring burst hits everything physical inside the radius, camo included.
        for enemy in enemies {
            let dx = enemy.position.x - tower.position.x
            let dy = enemy.position.y - tower.position.y
            if sqrt(dx * dx + dy * dy) <= tower.type.range {
                let popped = enemy.applyDamage(tower.type.ringBurstDamage)
                totalReward += rewardForPops(enemy: enemy, popped: popped)
            }
        }
        cleanUpDestroyedEnemies(rewarding: totalReward)
        flashStatus("Ring Burst detonated!")
    }

    /// Super Monkey: flashes the display and deals massive damage to all onscreen enemies.
    private func executeScreenFlash(_ tower: TowerNode) {
        let flash = SKShapeNode(rectOf: GameConfig.canvasSize)
        flash.position = CGPoint(x: GameConfig.canvasWidth / 2, y: GameConfig.canvasHeight / 2)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.alpha = 0.0
        flash.zPosition = 90
        addChild(flash)
        flash.run(.sequence([
            .fadeAlpha(to: 0.95, duration: 0.08),
            .fadeOut(withDuration: 0.5),
            .removeFromParent()
        ]))

        var totalReward = 0
        for enemy in enemies {
            let popped = enemy.applyDamage(tower.type.screenFlashDamage)
            totalReward += rewardForPops(enemy: enemy, popped: popped)
        }
        cleanUpDestroyedEnemies(rewarding: totalReward)
        flashStatus("Solar Annihilation unleashed!")
    }

    // MARK: Frame Loop

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let deltaTime = min(currentTime - lastUpdateTime, 1.0 / 20.0)
        lastUpdateTime = currentTime

        guard let viewModel, viewModel.isSimulationActive else { return }

        runSpawning(deltaTime: deltaTime)
        runTraversal(deltaTime: deltaTime)
        runCamoVisionExpiry(currentTime: currentTime)
        runTargeting(currentTime: currentTime)
        runProjectiles()
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

    private func runCamoVisionExpiry(currentTime: TimeInterval) {
        for tower in towers where tower.isCamoDetectionActive {
            if currentTime >= tower.camoDetectionEndTime {
                tower.isCamoDetectionActive = false
                tower.setCamoIndicator(active: false)
            }
        }
    }

    /// Evaluates reload intervals and fires at the furthest-progressed valid enemy.
    private func runTargeting(currentTime: TimeInterval) {
        for tower in towers {
            guard currentTime - tower.lastFireTime >= tower.type.fireCooldown else { continue }

            let candidates = enemies.filter { enemy in
                guard enemy.currentHealth > 0 else { return false }
                // Strict camo check: skip camo enemies unless camo vision is running.
                if enemy.isCamo && !tower.isCamoDetectionActive { return false }
                let dx = enemy.position.x - tower.position.x
                let dy = enemy.position.y - tower.position.y
                return sqrt(dx * dx + dy * dy) <= tower.type.range
            }

            guard let target = candidates.max(by: { $0.distanceTraveled < $1.distanceTraveled }) else { continue }

            tower.lastFireTime = currentTime
            tower.aim(at: target.position)

            if tower.type.firesRadially {
                // Tack shooter: 8 darts in a radial spread.
                for i in 0..<8 {
                    let angle = CGFloat(i) * (.pi / 4)
                    let dir = CGVector(dx: cos(angle), dy: sin(angle))
                    let projectile = ProjectileNode(from: tower.position,
                                                    target: nil,
                                                    direction: dir,
                                                    damage: tower.type.projectileDamage)
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
                                                damage: tower.type.projectileDamage)
                projectiles.append(projectile)
                addChild(projectile)
            }
        }
    }

    /// Advances projectiles, homing on live targets, and resolves collisions.
    private func runProjectiles() {
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

            projectile.position.x += projectile.direction.dx * projectile.flightSpeed
            projectile.position.y += projectile.direction.dy * projectile.flightSpeed

            // Off-canvas culling.
            if projectile.position.x < -30 || projectile.position.x > GameConfig.canvasWidth + 30 ||
               projectile.position.y < -30 || projectile.position.y > GameConfig.canvasHeight + 30 {
                projectile.removeFromParent()
                continue
            }

            // Collision check against all enemies (radial tack darts hit anything).
            var hit = false
            for enemy in enemies where enemy.currentHealth > 0 {
                let dx = enemy.position.x - projectile.position.x
                let dy = enemy.position.y - projectile.position.y
                let hitRadius = enemy.originalType.radius + 5
                if dx * dx + dy * dy <= hitRadius * hitRadius {
                    let popped = enemy.applyDamage(projectile.damage)
                    totalReward += rewardForPops(enemy: enemy, popped: popped)
                    spawnPopBurst(at: enemy.position)
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

    /// Gold: small income per layer popped, plus the destruction bonus.
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
            spawnPopBurst(at: enemy.position)
            enemy.removeFromParent()
        }
        enemies.removeAll { $0.currentHealth <= 0 }

        if reward > 0 {
            DispatchQueue.main.async { [weak viewModel] in
                viewModel?.earnGold(reward)
            }
        }
    }

    /// Programmatic particle burst on pop (no asset files).
    private func spawnPopBurst(at point: CGPoint) {
        for i in 0..<6 {
            let shard = SKShapeNode(circleOfRadius: 2.5)
            shard.position = point
            shard.fillColor = .white
            shard.strokeColor = .clear
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
        waveInFlight = false
        timeSinceWaveEnded = 0
        timeSinceLastSpawn = 0
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
