import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Global Canvas Constants

enum GameConfig {
    /// Fixed virtual canvas size the whole game is laid out against.
    /// The scene renders aspect-fit inside any screen, so gameplay scales to every device.
    static let canvasWidth: CGFloat = 1024
    static let canvasHeight: CGFloat = 768
    static let canvasSize = CGSize(width: canvasWidth, height: canvasHeight)

    /// Starting player resources.
    static let startingGold: Int = 350
    static let startingLives: Int = 40

    /// Wave pacing.
    static let secondsBetweenWaves: TimeInterval = 8.0
    static let baseEnemiesPerWave: Int = 6
    static let extraEnemiesPerWave: Int = 2
    static let spawnInterval: TimeInterval = 0.8

    /// Visual track width drawn under the waypoint path.
    static let trackWidth: CGFloat = 44

    /// Defenses available from mission one; the rest unlock through the campaign.
    static let starterTowers: [TowerType] = [.laser, .emp, .plasma, .missile]

    /// Campaign sectors, in story order. Each unlocks after the previous is completed.
    static let maps: [MapConfig] = [
        .earthOrbit, .lunarOutpost, .asteroidBelt, .marsColony,
        .nebulaFrontier, .alienRuins, .blackHoleSector, .galacticCore
    ]

    static let storyIntro = "The Galactic Defense Network has detected an invasion spreading across the sector. Defend each world and push back the alien threat."
}

// MARK: - Maps / Campaign Sectors

/// Procedural color palette for a battleground sector.
struct MapTheme {
    let background: SKColorCompatible
    /// Nebula cloud tint painted behind the playfield.
    let nebula: SKColorCompatible
    let trackOuter: SKColorCompatible
    let trackInner: SKColorCompatible
    /// Neon accent used for the energized center line of the track.
    let accent: SKColorCompatible
}

struct MapConfig: Identifiable, Equatable {
    let id: String
    let name: String
    let sector: String
    let missionDescription: String
    /// 1 (tutorial) ... 5 (endgame). Drives wave composition and pacing.
    let difficulty: Int
    /// Waves the player must survive to secure the sector.
    let totalWaves: Int
    let waypoints: [CGPoint]
    let theme: MapTheme
    /// Defense unlocked when this mission is completed.
    let unlockTowerOnComplete: TowerType?

    static func == (lhs: MapConfig, rhs: MapConfig) -> Bool { lhs.id == rhs.id }

    static let earthOrbit = MapConfig(
        id: "earth",
        name: "Earth Orbital Defense",
        sector: "Sector 01 — Sol",
        missionDescription: "The invasion fleet has reached Earth's orbital perimeter. Hold the line at the planetary shield grid.",
        difficulty: 1,
        totalWaves: 10,
        waypoints: [
            CGPoint(x: -40,  y: 600), CGPoint(x: 180,  y: 600), CGPoint(x: 180,  y: 220),
            CGPoint(x: 420,  y: 220), CGPoint(x: 420,  y: 560), CGPoint(x: 650,  y: 560),
            CGPoint(x: 650,  y: 160), CGPoint(x: 860,  y: 160), CGPoint(x: 860,  y: 430),
            CGPoint(x: 1064, y: 430)
        ],
        theme: MapTheme(
            background: SKColorCompatible(red: 0.02, green: 0.04, blue: 0.10, alpha: 1.0),
            nebula:     SKColorCompatible(red: 0.10, green: 0.30, blue: 0.55, alpha: 0.20),
            trackOuter: SKColorCompatible(red: 0.10, green: 0.16, blue: 0.26, alpha: 1.0),
            trackInner: SKColorCompatible(red: 0.22, green: 0.34, blue: 0.50, alpha: 1.0),
            accent:     SKColorCompatible(red: 0.35, green: 0.80, blue: 1.00, alpha: 0.50)
        ),
        unlockTowerOnComplete: .ion
    )

    static let lunarOutpost = MapConfig(
        id: "lunar",
        name: "Lunar Outpost",
        sector: "Sector 02 — Sol",
        missionDescription: "Tranquility Base is under siege. Protect the helium-3 refineries from the advancing swarm.",
        difficulty: 1,
        totalWaves: 11,
        waypoints: [
            CGPoint(x: -40,  y: 150), CGPoint(x: 190,  y: 150), CGPoint(x: 190,  y: 610),
            CGPoint(x: 430,  y: 610), CGPoint(x: 430,  y: 250), CGPoint(x: 640,  y: 250),
            CGPoint(x: 640,  y: 560), CGPoint(x: 860,  y: 560), CGPoint(x: 860,  y: 330),
            CGPoint(x: 1064, y: 330)
        ],
        theme: MapTheme(
            background: SKColorCompatible(red: 0.05, green: 0.05, blue: 0.09, alpha: 1.0),
            nebula:     SKColorCompatible(red: 0.35, green: 0.35, blue: 0.48, alpha: 0.18),
            trackOuter: SKColorCompatible(red: 0.18, green: 0.18, blue: 0.22, alpha: 1.0),
            trackInner: SKColorCompatible(red: 0.42, green: 0.42, blue: 0.48, alpha: 1.0),
            accent:     SKColorCompatible(red: 0.75, green: 0.80, blue: 1.00, alpha: 0.50)
        ),
        unlockTowerOnComplete: .gravity
    )

    static let asteroidBelt = MapConfig(
        id: "asteroid",
        name: "Asteroid Belt",
        sector: "Sector 03 — The Belt",
        missionDescription: "Swarms are slipping through the mining corridors. Cloaked Phantom signatures detected — detection is now critical.",
        difficulty: 2,
        totalWaves: 12,
        waypoints: [
            CGPoint(x: -40,  y: 680), CGPoint(x: 220,  y: 680), CGPoint(x: 220,  y: 420),
            CGPoint(x: 470,  y: 420), CGPoint(x: 470,  y: 640), CGPoint(x: 720,  y: 640),
            CGPoint(x: 720,  y: 300), CGPoint(x: 1064, y: 300)
        ],
        theme: MapTheme(
            background: SKColorCompatible(red: 0.06, green: 0.05, blue: 0.04, alpha: 1.0),
            nebula:     SKColorCompatible(red: 0.45, green: 0.30, blue: 0.12, alpha: 0.18),
            trackOuter: SKColorCompatible(red: 0.20, green: 0.15, blue: 0.10, alpha: 1.0),
            trackInner: SKColorCompatible(red: 0.42, green: 0.33, blue: 0.22, alpha: 1.0),
            accent:     SKColorCompatible(red: 1.00, green: 0.65, blue: 0.25, alpha: 0.50)
        ),
        unlockTowerOnComplete: .scanner
    )

    static let marsColony = MapConfig(
        id: "mars",
        name: "Mars Colony",
        sector: "Sector 04 — Sol Rim",
        missionDescription: "The terraforming domes shelter thousands. Do not let the swarm breach the colony perimeter.",
        difficulty: 2,
        totalWaves: 13,
        waypoints: [
            CGPoint(x: -40, y: 650), CGPoint(x: 880, y: 650), CGPoint(x: 880, y: 150),
            CGPoint(x: 150, y: 150), CGPoint(x: 150, y: 420), CGPoint(x: 640, y: 420),
            CGPoint(x: 640, y: -40)
        ],
        theme: MapTheme(
            background: SKColorCompatible(red: 0.08, green: 0.03, blue: 0.02, alpha: 1.0),
            nebula:     SKColorCompatible(red: 0.55, green: 0.18, blue: 0.10, alpha: 0.18),
            trackOuter: SKColorCompatible(red: 0.25, green: 0.10, blue: 0.06, alpha: 1.0),
            trackInner: SKColorCompatible(red: 0.50, green: 0.24, blue: 0.14, alpha: 1.0),
            accent:     SKColorCompatible(red: 1.00, green: 0.45, blue: 0.30, alpha: 0.50)
        ),
        unlockTowerOnComplete: .satellite
    )

    static let nebulaFrontier = MapConfig(
        id: "nebula",
        name: "Nebula Frontier",
        sector: "Sector 05 — Deep Space",
        missionDescription: "Sensor interference is heavy inside the nebula. Cloaked signatures everywhere — trust your scanners.",
        difficulty: 3,
        totalWaves: 14,
        waypoints: [
            CGPoint(x: -40,  y: 200), CGPoint(x: 200,  y: 200), CGPoint(x: 200,  y: 620),
            CGPoint(x: 420,  y: 620), CGPoint(x: 420,  y: 260), CGPoint(x: 640,  y: 260),
            CGPoint(x: 640,  y: 620), CGPoint(x: 860,  y: 620), CGPoint(x: 860,  y: 200),
            CGPoint(x: 1064, y: 200)
        ],
        theme: MapTheme(
            background: SKColorCompatible(red: 0.05, green: 0.02, blue: 0.10, alpha: 1.0),
            nebula:     SKColorCompatible(red: 0.45, green: 0.15, blue: 0.60, alpha: 0.22),
            trackOuter: SKColorCompatible(red: 0.18, green: 0.08, blue: 0.26, alpha: 1.0),
            trackInner: SKColorCompatible(red: 0.36, green: 0.20, blue: 0.50, alpha: 1.0),
            accent:     SKColorCompatible(red: 0.85, green: 0.45, blue: 1.00, alpha: 0.50)
        ),
        unlockTowerOnComplete: .quantum
    )

    static let alienRuins = MapConfig(
        id: "ruins",
        name: "Alien Ruins",
        sector: "Sector 06 — Outer Reach",
        missionDescription: "The swarm draws power from the ancient ruins. Expect hardened waves and a short approach corridor.",
        difficulty: 4,
        totalWaves: 15,
        waypoints: [
            CGPoint(x: -40,  y: 560), CGPoint(x: 350,  y: 560), CGPoint(x: 350,  y: 330),
            CGPoint(x: 720,  y: 330), CGPoint(x: 720,  y: 560), CGPoint(x: 1064, y: 560)
        ],
        theme: MapTheme(
            background: SKColorCompatible(red: 0.02, green: 0.07, blue: 0.05, alpha: 1.0),
            nebula:     SKColorCompatible(red: 0.10, green: 0.45, blue: 0.30, alpha: 0.20),
            trackOuter: SKColorCompatible(red: 0.08, green: 0.20, blue: 0.14, alpha: 1.0),
            trackInner: SKColorCompatible(red: 0.18, green: 0.40, blue: 0.28, alpha: 1.0),
            accent:     SKColorCompatible(red: 0.30, green: 1.00, blue: 0.60, alpha: 0.50)
        ),
        unlockTowerOnComplete: .alien
    )

    static let blackHoleSector = MapConfig(
        id: "blackhole",
        name: "Black Hole Sector",
        sector: "Sector 07 — Event Horizon",
        missionDescription: "Gravity wells twist the battlefield at the event horizon. The swarm comes in dense, fast columns.",
        difficulty: 4,
        totalWaves: 16,
        waypoints: [
            CGPoint(x: -40,  y: 384), CGPoint(x: 380,  y: 384), CGPoint(x: 380,  y: 610),
            CGPoint(x: 660,  y: 610), CGPoint(x: 660,  y: 200), CGPoint(x: 900,  y: 200),
            CGPoint(x: 900,  y: 384), CGPoint(x: 1064, y: 384)
        ],
        theme: MapTheme(
            background: SKColorCompatible(red: 0.01, green: 0.01, blue: 0.03, alpha: 1.0),
            nebula:     SKColorCompatible(red: 0.20, green: 0.10, blue: 0.40, alpha: 0.22),
            trackOuter: SKColorCompatible(red: 0.10, green: 0.08, blue: 0.18, alpha: 1.0),
            trackInner: SKColorCompatible(red: 0.22, green: 0.18, blue: 0.36, alpha: 1.0),
            accent:     SKColorCompatible(red: 0.60, green: 0.40, blue: 1.00, alpha: 0.50)
        ),
        unlockTowerOnComplete: .darkMatter
    )

    static let galacticCore = MapConfig(
        id: "core",
        name: "Galactic Core",
        sector: "Sector 08 — The Core",
        missionDescription: "The hive nexus. Every enemy form, every trick, all at once. End the invasion here.",
        difficulty: 5,
        totalWaves: 18,
        waypoints: [
            CGPoint(x: -40,  y: 300), CGPoint(x: 300,  y: 300), CGPoint(x: 300,  y: 500),
            CGPoint(x: 760,  y: 500), CGPoint(x: 760,  y: 300), CGPoint(x: 1064, y: 300)
        ],
        theme: MapTheme(
            background: SKColorCompatible(red: 0.07, green: 0.04, blue: 0.01, alpha: 1.0),
            nebula:     SKColorCompatible(red: 0.60, green: 0.40, blue: 0.10, alpha: 0.22),
            trackOuter: SKColorCompatible(red: 0.24, green: 0.16, blue: 0.05, alpha: 1.0),
            trackInner: SKColorCompatible(red: 0.48, green: 0.36, blue: 0.14, alpha: 1.0),
            accent:     SKColorCompatible(red: 1.00, green: 0.80, blue: 0.30, alpha: 0.50)
        ),
        unlockTowerOnComplete: nil
    )
}

// MARK: - Enemy Types (Alien Swarm)

/// The invaders: alien pods, cosmic blobs, rogue drones, cloaked wisps, and void behemoths.
enum EnemyType: String, CaseIterable, Identifiable {
    case pod       // Scout Pod — 1 layer, slow
    case blob      // Cosmic Blob — 2 layers, fast (degrades into a pod)
    case drone     // Rogue Drone — robotic, 2 layers, fastest; EMP deals double damage
    case wisp      // Phantom Wisp — invisible energy entity, 3 layers
    case behemoth  // Void Behemoth — 6 layers, slow, late-game armor

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pod:      return "Scout Pod"
        case .blob:     return "Cosmic Blob"
        case .drone:    return "Rogue Drone"
        case .wisp:     return "Phantom Wisp"
        case .behemoth: return "Void Behemoth"
        }
    }

    /// Scalar movement speed in points-per-frame at a 60Hz reference rate.
    var speed: CGFloat {
        switch self {
        case .pod:      return 1.6
        case .blob:     return 2.2
        case .drone:    return 2.6
        case .wisp:     return 1.9
        case .behemoth: return 1.1
        }
    }

    /// Structural health layers (hits required to fully destroy).
    var healthLayers: Int {
        switch self {
        case .pod:      return 1
        case .blob:     return 2
        case .drone:    return 2
        case .wisp:     return 3
        case .behemoth: return 6
        }
    }

    /// Credit reward granted per full destruction.
    var reward: Int {
        switch self {
        case .pod:      return 4
        case .blob:     return 8
        case .drone:    return 10
        case .wisp:     return 14
        case .behemoth: return 30
        }
    }

    /// Whether defenses need active cloak detection to target this enemy.
    var isInvisible: Bool { self == .wisp }

    /// Robotic enemies take double damage from EMP attacks.
    var isRobotic: Bool { self == .drone }

    /// Body radius for the programmatic chassis.
    var radius: CGFloat {
        switch self {
        case .pod:      return 13
        case .blob:     return 16
        case .drone:    return 14
        case .wisp:     return 15
        case .behemoth: return 24
        }
    }

    /// Chassis color matching the current structural tier.
    var color: SKColorCompatible {
        switch self {
        case .pod:      return SKColorCompatible(red: 0.95, green: 0.35, blue: 0.25, alpha: 1.0)
        case .blob:     return SKColorCompatible(red: 0.20, green: 0.70, blue: 0.95, alpha: 1.0)
        case .drone:    return SKColorCompatible(red: 0.65, green: 0.70, blue: 0.78, alpha: 1.0)
        case .wisp:     return SKColorCompatible(red: 0.62, green: 0.40, blue: 0.95, alpha: 1.0)
        case .behemoth: return SKColorCompatible(red: 0.85, green: 0.15, blue: 0.35, alpha: 1.0)
        }
    }

    /// The visible tier an enemy degrades into when damaged but not destroyed.
    /// Cosmic Blobs shed into Scout Pods; other forms keep their skin until destroyed.
    static func tier(forRemainingHealth health: Int, original: EnemyType) -> EnemyType {
        switch original {
        case .blob: return health >= 2 ? .blob : .pod
        default:    return original
        }
    }
}

// MARK: - Defense Behaviors

enum TowerBehavior {
    case singleTarget    // tracked energy bolts at one enemy
    case radialBurst     // bolts in all directions
    case splashMissile   // tracked rocket with area damage on impact
    case chainLightning  // instant arc that jumps between enemies
    case piercingBeam    // instant beam damaging everything along a line
    case orbitalStrike   // beam from orbit, unlimited range
    case slowField       // passive aura slowing enemies
    case scannerSupport  // passive aura granting cloak detection to towers
    case rateSupport     // passive aura hastening nearby towers

    /// Whether this behavior participates in the reload/targeting cycle.
    var isAttacking: Bool {
        switch self {
        case .slowField, .scannerSupport, .rateSupport: return false
        default: return true
        }
    }

    var isSupport: Bool { !isAttacking }
}

// MARK: - Defense Types (11 unique towers)

enum TowerType: String, CaseIterable, Identifiable {
    case laser       // fast single-target; Power Lv3 reveals cloaked
    case emp         // radial bursts; double damage vs robotic drones
    case plasma      // slow, heavy single-target
    case missile     // splash damage rockets
    case ion         // chain lightning
    case gravity     // slow field
    case scanner     // detection aura support
    case satellite   // orbital strikes, unlimited range
    case quantum     // piercing beam, detects cloaked
    case alien       // haste aura support
    case darkMatter  // endgame rapid-fire, detects cloaked

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .laser:      return "Laser Turret"
        case .emp:        return "EMP Tower"
        case .plasma:     return "Plasma Cannon"
        case .missile:    return "Missile Launcher"
        case .ion:        return "Ion Blaster"
        case .gravity:    return "Gravity Well"
        case .scanner:    return "Scanner Array"
        case .satellite:  return "Satellite Uplink"
        case .quantum:    return "Quantum Beam"
        case .alien:      return "Alien Tech Spire"
        case .darkMatter: return "Dark Matter Cannon"
        }
    }

    var roleDescription: String {
        switch self {
        case .laser:      return "Rapid single-target beam"
        case .emp:        return "Radial shock, ×2 vs drones"
        case .plasma:     return "Slow, heavy plasma bolts"
        case .missile:    return "Splash-damage rockets"
        case .ion:        return "Arcs between up to 4 enemies"
        case .gravity:    return "Slows enemies in its field"
        case .scanner:    return "Nearby towers see cloaked"
        case .satellite:  return "Orbital strikes, any range"
        case .quantum:    return "Piercing beam, sees cloaked"
        case .alien:      return "Hastens nearby towers"
        case .darkMatter: return "Endgame annihilation beam"
        }
    }

    var behavior: TowerBehavior {
        switch self {
        case .laser, .plasma, .darkMatter: return .singleTarget
        case .emp:        return .radialBurst
        case .missile:    return .splashMissile
        case .ion:        return .chainLightning
        case .quantum:    return .piercingBeam
        case .satellite:  return .orbitalStrike
        case .gravity:    return .slowField
        case .scanner:    return .scannerSupport
        case .alien:      return .rateSupport
        }
    }

    /// Fixed credit purchase cost.
    var cost: Int {
        switch self {
        case .laser:      return 100
        case .emp:        return 180
        case .plasma:     return 250
        case .missile:    return 320
        case .ion:        return 380
        case .gravity:    return 300
        case .scanner:    return 280
        case .satellite:  return 450
        case .quantum:    return 550
        case .alien:      return 500
        case .darkMatter: return 900
        }
    }

    /// Circular targeting (or aura) range radius in canvas points.
    var range: CGFloat {
        switch self {
        case .laser:      return 150
        case .emp:        return 95
        case .plasma:     return 170
        case .missile:    return 200
        case .ion:        return 160
        case .gravity:    return 120
        case .scanner:    return 180
        case .satellite:  return 2000   // covers the whole battlefield
        case .quantum:    return 220
        case .alien:      return 150
        case .darkMatter: return 280
        }
    }

    /// Weapon cycle cooldown in seconds between shots (supports never fire).
    var fireCooldown: TimeInterval {
        switch self {
        case .laser:      return 0.6
        case .plasma:     return 1.6
        case .emp:        return 1.1
        case .missile:    return 1.8
        case .ion:        return 1.0
        case .satellite:  return 2.5
        case .quantum:    return 1.3
        case .darkMatter: return 0.2
        case .gravity, .scanner, .alien: return 999
        }
    }

    /// Damage applied per hit (0 for pure support towers).
    var projectileDamage: Int {
        switch self {
        case .laser:      return 1
        case .emp:        return 1
        case .plasma:     return 3
        case .missile:    return 2
        case .ion:        return 2
        case .satellite:  return 3
        case .quantum:    return 2
        case .darkMatter: return 2
        case .gravity, .scanner, .alien: return 0
        }
    }

    /// Whether this defense can target cloaked enemies without external help.
    var detectsInvisibleBase: Bool {
        self == .scanner || self == .quantum || self == .darkMatter
    }

    /// Area-of-effect radius on impact (missiles and orbital strikes).
    var splashRadius: CGFloat {
        switch self {
        case .missile:   return 60
        case .satellite: return 40
        default:         return 0
        }
    }

    /// Chain lightning tuning.
    var chainHops: Int { 4 }
    var chainJumpDistance: CGFloat { 110 }

    /// Gravity Well base slow strength (fraction of speed removed).
    var slowStrength: Double { 0.45 }

    /// Alien Tech base haste strength (fraction of cooldown removed).
    var hasteStrength: Double { 0.20 }

    /// Body color for the programmatic turret chassis.
    var color: SKColorCompatible {
        switch self {
        case .laser:      return SKColorCompatible(red: 0.15, green: 0.62, blue: 0.95, alpha: 1.0)
        case .emp:        return SKColorCompatible(red: 0.95, green: 0.62, blue: 0.12, alpha: 1.0)
        case .plasma:     return SKColorCompatible(red: 0.20, green: 0.85, blue: 0.55, alpha: 1.0)
        case .missile:    return SKColorCompatible(red: 0.80, green: 0.35, blue: 0.25, alpha: 1.0)
        case .ion:        return SKColorCompatible(red: 0.45, green: 0.75, blue: 1.00, alpha: 1.0)
        case .gravity:    return SKColorCompatible(red: 0.50, green: 0.30, blue: 0.90, alpha: 1.0)
        case .scanner:    return SKColorCompatible(red: 0.30, green: 0.95, blue: 0.85, alpha: 1.0)
        case .satellite:  return SKColorCompatible(red: 0.75, green: 0.78, blue: 0.85, alpha: 1.0)
        case .quantum:    return SKColorCompatible(red: 0.95, green: 0.85, blue: 0.25, alpha: 1.0)
        case .alien:      return SKColorCompatible(red: 0.55, green: 0.95, blue: 0.35, alpha: 1.0)
        case .darkMatter: return SKColorCompatible(red: 0.60, green: 0.20, blue: 0.80, alpha: 1.0)
        }
    }

    /// Tint of the energy this defense fires.
    var projectileTint: SKColorCompatible {
        switch self {
        case .laser:      return SKColorCompatible(red: 0.45, green: 0.92, blue: 1.00, alpha: 1.0)
        case .emp:        return SKColorCompatible(red: 1.00, green: 0.80, blue: 0.30, alpha: 1.0)
        case .plasma:     return SKColorCompatible(red: 0.40, green: 1.00, blue: 0.70, alpha: 1.0)
        case .missile:    return SKColorCompatible(red: 1.00, green: 0.55, blue: 0.35, alpha: 1.0)
        case .ion:        return SKColorCompatible(red: 0.65, green: 0.85, blue: 1.00, alpha: 1.0)
        case .gravity:    return SKColorCompatible(red: 0.70, green: 0.50, blue: 1.00, alpha: 1.0)
        case .scanner:    return SKColorCompatible(red: 0.45, green: 1.00, blue: 0.95, alpha: 1.0)
        case .satellite:  return SKColorCompatible(red: 0.90, green: 0.95, blue: 1.00, alpha: 1.0)
        case .quantum:    return SKColorCompatible(red: 1.00, green: 0.95, blue: 0.45, alpha: 1.0)
        case .alien:      return SKColorCompatible(red: 0.70, green: 1.00, blue: 0.50, alpha: 1.0)
        case .darkMatter: return SKColorCompatible(red: 0.85, green: 0.45, blue: 1.00, alpha: 1.0)
        }
    }

    var bodyRadius: CGFloat {
        switch self {
        case .darkMatter, .satellite: return 22
        default: return 18
        }
    }

    // MARK: Active Abilities

    /// Human-readable active ability string signature.
    var abilitySignature: String {
        switch self {
        case .laser:      return "Phase Scanner"
        case .emp:        return "EMP Shockwave"
        case .plasma:     return "Overload"
        case .missile:    return "Barrage"
        case .ion:        return "Storm Discharge"
        case .gravity:    return "Stasis Field"
        case .scanner:    return "Deep Scan"
        case .satellite:  return "Orbital Bombardment"
        case .quantum:    return "Phase Lance"
        case .alien:      return "Harmonic Surge"
        case .darkMatter: return "Singularity"
        }
    }

    var abilityDescription: String {
        switch self {
        case .laser:      return "Self-detects cloaked for 8s"
        case .emp:        return "3 dmg in range, ×2 vs drones"
        case .plasma:     return "Double damage for 6s"
        case .missile:    return "Rockets strike 5 enemies in range"
        case .ion:        return "2 dmg to every enemy in range"
        case .gravity:    return "90% slow in field for 4s"
        case .scanner:    return "Reveal all cloaked for 10s"
        case .satellite:  return "Strike the 3 deepest enemies"
        case .quantum:    return "Map-wide piercing lance"
        case .alien:      return "All towers +50% rate for 6s"
        case .darkMatter: return "6 dmg to every enemy onscreen"
        }
    }

    /// Independent ability cooldown window in seconds.
    var abilityCooldown: TimeInterval {
        switch self {
        case .laser:      return 12.0
        case .emp:        return 15.0
        case .plasma:     return 18.0
        case .missile:    return 20.0
        case .ion:        return 18.0
        case .gravity:    return 22.0
        case .scanner:    return 25.0
        case .satellite:  return 25.0
        case .quantum:    return 22.0
        case .alien:      return 30.0
        case .darkMatter: return 30.0
        }
    }

    /// Duration of the laser phase-scanner cloak detection.
    var camoVisionDuration: TimeInterval { 8.0 }

    /// Damage dealt by the EMP Tower's localized shockwave ability.
    var ringBurstDamage: Int { 3 }

    /// Damage dealt by Dark Matter's screen flash to all onscreen enemies.
    var screenFlashDamage: Int { 6 }
}

// MARK: - Tower unlock mapping

extension TowerType {
    /// The campaign mission that unlocks this defense, if it is not a starter.
    var unlockingMap: MapConfig? {
        guard !GameConfig.starterTowers.contains(self) else { return nil }
        return GameConfig.maps.first { $0.unlockTowerOnComplete == self }
    }
}

// MARK: - Upgrade Paths

/// Two distinct advancement tracks per defense:
/// alpha = speed/utility, beta = damage/range (power).
enum UpgradePath: String, CaseIterable, Identifiable {
    case alpha
    case beta

    var id: String { rawValue }
}

extension TowerType {
    static let maxUpgradeLevel = 3

    /// Per-level fire-cooldown multiplier on path alpha (compounding).
    static let alphaCooldownFactor = 0.8
    /// Per-level damage bonus on path beta.
    static let betaDamageBonus = 1
    /// Per-level range multiplier on path beta (compounding).
    static let betaRangeFactor = 1.12
    /// Per-level effect-strength bonus on path alpha for field/support towers.
    static let alphaEffectBonus = 0.08

    var pathATitle: String {
        switch self {
        case .laser:      return "Hyper Coils"
        case .emp:        return "Rapid Capacitors"
        case .plasma:     return "Magnetic Loader"
        case .missile:    return "Auto-Loader"
        case .ion:        return "Supercharged Arcs"
        case .gravity:    return "Denser Field"
        case .scanner:    return "Signal Boost"
        case .satellite:  return "Fast Relay"
        case .quantum:    return "Phase Cycler"
        case .alien:      return "Resonance"
        case .darkMatter: return "Event Cycler"
        }
    }

    var pathADetail: String {
        switch self {
        case .gravity: return "+8% slow strength per level"
        case .alien:   return "+8% haste strength per level"
        case .scanner: return "Aura also hastens towers +6%/level"
        default:       return "+25% fire rate per level"
        }
    }

    var pathBTitle: String {
        switch self {
        case .laser:      return "Tachyon Optics"
        case .emp:        return "Wide Spectrum"
        case .plasma:     return "Star Core"
        case .missile:    return "Heavy Warheads"
        case .ion:        return "Conductor Array"
        case .gravity:    return "Field Expander"
        case .scanner:    return "Long-Range Array"
        case .satellite:  return "Tungsten Rods"
        case .quantum:    return "Wide Lance"
        case .alien:      return "Broadcast Array"
        case .darkMatter: return "Collapsed Core"
        }
    }

    var pathBDetail: String {
        switch self {
        case .laser:                       return "+1 dmg, +12% range/level — Lv3 reveals cloaked"
        case .gravity, .scanner, .alien:   return "+12% field radius per level"
        default:                           return "+1 damage, +12% range per level"
        }
    }

    /// Cost of the next tier on a path, or nil when the path is maxed.
    /// Scales off the tower's base cost so progression stays balanced across the roster.
    func upgradeCost(path: UpgradePath, currentLevel: Int) -> Int? {
        guard currentLevel < Self.maxUpgradeLevel else { return nil }
        let base = Double(cost)
        let pathFactor = path == .alpha ? 0.75 : 0.95
        let tierScale = [1.0, 1.7, 2.8][currentLevel]
        return max(10, Int((base * pathFactor * tierScale / 10.0).rounded()) * 10)
    }
}

// MARK: - Cross-framework color container

/// Small RGBA value container so config stays import-light;
/// converted to SKColor/Color at the rendering layer.
struct SKColorCompatible {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    var swiftUIColor: Color {
        Color(red: Double(red), green: Double(green), blue: Double(blue)).opacity(Double(alpha))
    }
}
