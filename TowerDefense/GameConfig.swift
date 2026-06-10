import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Global Canvas Constants

enum GameConfig {
    /// Fixed virtual canvas size the whole game is laid out against.
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

    /// All selectable battlegrounds.
    static let maps: [MapConfig] = [.forestPath, .desertDunes]
}

// MARK: - Maps

/// Procedural color palette for a battleground.
struct MapTheme {
    let background: SKColorCompatible
    let scenery: SKColorCompatible
    let trackOuter: SKColorCompatible
    let trackInner: SKColorCompatible
    /// Neon accent used for the energized center line of the track.
    let accent: SKColorCompatible
}

struct MapConfig: Identifiable, Equatable {
    let id: String
    let name: String
    let tagline: String
    let waypoints: [CGPoint]
    let theme: MapTheme

    static func == (lhs: MapConfig, rhs: MapConfig) -> Bool { lhs.id == rhs.id }

    static let forestPath = MapConfig(
        id: "forest",
        name: "Forest Path",
        tagline: "Winding woodland corridor with tight chokepoints.",
        waypoints: [
            CGPoint(x: -40,  y: 600),
            CGPoint(x: 180,  y: 600),
            CGPoint(x: 180,  y: 220),
            CGPoint(x: 420,  y: 220),
            CGPoint(x: 420,  y: 560),
            CGPoint(x: 650,  y: 560),
            CGPoint(x: 650,  y: 160),
            CGPoint(x: 860,  y: 160),
            CGPoint(x: 860,  y: 430),
            CGPoint(x: 1064, y: 430)
        ],
        theme: MapTheme(
            background: SKColorCompatible(red: 0.07, green: 0.20, blue: 0.12, alpha: 1.0),
            scenery:    SKColorCompatible(red: 0.05, green: 0.15, blue: 0.09, alpha: 0.7),
            trackOuter: SKColorCompatible(red: 0.24, green: 0.19, blue: 0.12, alpha: 1.0),
            trackInner: SKColorCompatible(red: 0.45, green: 0.38, blue: 0.26, alpha: 1.0),
            accent:     SKColorCompatible(red: 0.35, green: 0.95, blue: 0.55, alpha: 0.45)
        )
    )

    static let desertDunes = MapConfig(
        id: "desert",
        name: "Desert Dunes",
        tagline: "Long serpentine flats — wide open firing lanes.",
        waypoints: [
            CGPoint(x: -40,  y: 150),
            CGPoint(x: 190,  y: 150),
            CGPoint(x: 190,  y: 610),
            CGPoint(x: 430,  y: 610),
            CGPoint(x: 430,  y: 250),
            CGPoint(x: 640,  y: 250),
            CGPoint(x: 640,  y: 560),
            CGPoint(x: 860,  y: 560),
            CGPoint(x: 860,  y: 330),
            CGPoint(x: 1064, y: 330)
        ],
        theme: MapTheme(
            background: SKColorCompatible(red: 0.38, green: 0.29, blue: 0.16, alpha: 1.0),
            scenery:    SKColorCompatible(red: 0.32, green: 0.24, blue: 0.13, alpha: 0.7),
            trackOuter: SKColorCompatible(red: 0.24, green: 0.17, blue: 0.10, alpha: 1.0),
            trackInner: SKColorCompatible(red: 0.58, green: 0.47, blue: 0.30, alpha: 1.0),
            accent:     SKColorCompatible(red: 1.00, green: 0.72, blue: 0.25, alpha: 0.45)
        )
    )
}

// MARK: - Enemy Types ("Glitch Bugs")

/// The swarm: digital glitch-bugs that crawl the data-track.
/// Case names are kept stable (red/blue/camo) because the tier-degrade
/// logic keys off them; the visual identity is fully re-themed.
enum EnemyType: String, CaseIterable, Identifiable {
    case red    // Glitch Mite  — 1 layer, slow
    case blue   // Volt Beetle  — 2 layers, fast
    case camo   // Phantom Crawler — 3 layers, cloaked

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .red:  return "Glitch Mite"
        case .blue: return "Volt Beetle"
        case .camo: return "Phantom Crawler"
        }
    }

    /// Scalar movement speed in points-per-frame at a 60Hz reference rate.
    var speed: CGFloat {
        switch self {
        case .red:  return 1.6
        case .blue: return 2.2
        case .camo: return 1.9
        }
    }

    /// Structural health layers (hits required to fully destroy).
    var healthLayers: Int {
        switch self {
        case .red:  return 1
        case .blue: return 2
        case .camo: return 3
        }
    }

    /// Credit reward granted per full destruction.
    var reward: Int {
        switch self {
        case .red:  return 4
        case .blue: return 8
        case .camo: return 14
        }
    }

    /// Whether defenses need an active phase scanner to target this enemy.
    var isCamo: Bool { self == .camo }

    /// Body radius for the programmatic bug chassis.
    var radius: CGFloat {
        switch self {
        case .red:  return 14
        case .blue: return 16
        case .camo: return 15
        }
    }

    /// Chassis color matching the current structural tier.
    var color: SKColorCompatible {
        switch self {
        case .red:  return SKColorCompatible(red: 0.96, green: 0.25, blue: 0.38, alpha: 1.0)
        case .blue: return SKColorCompatible(red: 0.10, green: 0.75, blue: 0.95, alpha: 1.0)
        case .camo: return SKColorCompatible(red: 0.62, green: 0.40, blue: 0.95, alpha: 1.0)
        }
    }

    /// The tier an enemy degrades into when damaged but not destroyed.
    /// Volt Beetle -> Glitch Mite. Phantom keeps its cloaked skin until destroyed;
    /// the tier is resolved purely from remaining health.
    static func tier(forRemainingHealth health: Int, original: EnemyType) -> EnemyType {
        if original == .camo { return .camo }
        switch health {
        case 2...: return .blue
        default:   return .red
        }
    }
}

// MARK: - Defense Types (Sci-Fi Turrets)

enum TowerType: String, CaseIterable, Identifiable {
    case dartNode   // Quantum Laser — single target, modest speed
    case tackNode   // EMP Blaster   — slower, radial close-range
    case superNode  // Plasma Overlord — ultra-fast, expansive range, costly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dartNode:  return "Quantum Laser"
        case .tackNode:  return "EMP Blaster"
        case .superNode: return "Plasma Overlord"
        }
    }

    var roleDescription: String {
        switch self {
        case .dartNode:  return "Precision single-target beam"
        case .tackNode:  return "Radial close-range shockwaves"
        case .superNode: return "Rapid-fire long-range plasma"
        }
    }

    /// Fixed credit purchase cost.
    var cost: Int {
        switch self {
        case .dartNode:  return 120
        case .tackNode:  return 200
        case .superNode: return 650
        }
    }

    /// Circular targeting range radius in canvas points.
    var range: CGFloat {
        switch self {
        case .dartNode:  return 150
        case .tackNode:  return 95
        case .superNode: return 260
        }
    }

    /// Weapon cycle cooldown in seconds between shots.
    var fireCooldown: TimeInterval {
        switch self {
        case .dartNode:  return 0.75
        case .tackNode:  return 1.10
        case .superNode: return 0.18
        }
    }

    /// Damage applied per projectile hit.
    var projectileDamage: Int {
        switch self {
        case .dartNode:  return 1
        case .tackNode:  return 1
        case .superNode: return 1
        }
    }

    /// Whether the defense fires a radial burst (all directions) instead of tracked bolts.
    var firesRadially: Bool { self == .tackNode }

    /// Body color for the programmatic turret chassis.
    var color: SKColorCompatible {
        switch self {
        case .dartNode:  return SKColorCompatible(red: 0.15, green: 0.62, blue: 0.95, alpha: 1.0)
        case .tackNode:  return SKColorCompatible(red: 0.95, green: 0.62, blue: 0.12, alpha: 1.0)
        case .superNode: return SKColorCompatible(red: 0.82, green: 0.28, blue: 0.88, alpha: 1.0)
        }
    }

    /// Tint of the energy bolts this defense fires.
    var projectileTint: SKColorCompatible {
        switch self {
        case .dartNode:  return SKColorCompatible(red: 0.45, green: 0.92, blue: 1.00, alpha: 1.0)
        case .tackNode:  return SKColorCompatible(red: 1.00, green: 0.80, blue: 0.30, alpha: 1.0)
        case .superNode: return SKColorCompatible(red: 1.00, green: 0.50, blue: 1.00, alpha: 1.0)
        }
    }

    var bodyRadius: CGFloat {
        switch self {
        case .dartNode:  return 18
        case .tackNode:  return 18
        case .superNode: return 22
        }
    }

    // MARK: Active Abilities

    /// Human-readable active ability string signature.
    var abilitySignature: String {
        switch self {
        case .dartNode:  return "Phase Scanner"
        case .tackNode:  return "EMP Shockwave"
        case .superNode: return "Plasma Storm"
        }
    }

    var abilityDescription: String {
        switch self {
        case .dartNode:  return "Reveals cloaked Phantoms for 8s"
        case .tackNode:  return "Heavy burst damage in range"
        case .superNode: return "Massive damage to all enemies"
        }
    }

    /// Independent ability cooldown window in seconds.
    var abilityCooldown: TimeInterval {
        switch self {
        case .dartNode:  return 12.0
        case .tackNode:  return 15.0
        case .superNode: return 30.0
        }
    }

    /// Duration of the phase-scanner cloak detection (only meaningful for dartNode).
    var camoVisionDuration: TimeInterval { 8.0 }

    /// Damage dealt by the EMP Blaster's localized shockwave ability.
    var ringBurstDamage: Int { 3 }

    /// Damage dealt by the Plasma Overlord's screen flash to all onscreen enemies.
    var screenFlashDamage: Int { 5 }
}

// MARK: - Upgrade Paths

/// Two distinct advancement tracks per defense:
/// alpha = speed/utility, beta = damage/range.
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

    var pathATitle: String {
        switch self {
        case .dartNode:  return "Hyper Coils"
        case .tackNode:  return "Rapid Capacitors"
        case .superNode: return "Overcharge"
        }
    }

    var pathADetail: String { "+25% fire rate per level" }

    var pathBTitle: String {
        switch self {
        case .dartNode:  return "Focused Optics"
        case .tackNode:  return "Wide Spectrum"
        case .superNode: return "Star Core"
        }
    }

    var pathBDetail: String { "+1 damage, +12% range per level" }

    /// Cost of the next tier on a path, or nil when the path is maxed.
    func upgradeCost(path: UpgradePath, currentLevel: Int) -> Int? {
        guard currentLevel < Self.maxUpgradeLevel else { return nil }
        let table: [Int]
        switch (self, path) {
        case (.dartNode, .alpha):  table = [90, 150, 260]
        case (.dartNode, .beta):   table = [110, 190, 320]
        case (.tackNode, .alpha):  table = [120, 200, 340]
        case (.tackNode, .beta):   table = [150, 250, 420]
        case (.superNode, .alpha): table = [380, 650, 1000]
        case (.superNode, .beta):  table = [450, 780, 1250]
        }
        return table[currentLevel]
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
