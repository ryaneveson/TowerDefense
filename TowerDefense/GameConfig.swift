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

    /// Linear waypoint map track for enemies, mapped across the 1024x768 system.
    /// Enemies enter on the left edge and exit on the right edge.
    static let waypoints: [CGPoint] = [
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
    ]
}

// MARK: - Enemy Types

enum EnemyType: String, CaseIterable, Identifiable {
    case red
    case blue
    case camo

    var id: String { rawValue }

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

    /// Gold reward granted per full destruction.
    var reward: Int {
        switch self {
        case .red:  return 4
        case .blue: return 8
        case .camo: return 14
        }
    }

    /// Whether towers need active camo detection to target this enemy.
    var isCamo: Bool { self == .camo }

    /// Body radius for the programmatic balloon shape.
    var radius: CGFloat {
        switch self {
        case .red:  return 14
        case .blue: return 16
        case .camo: return 15
        }
    }

    /// Fill color matching the current structural tier.
    var color: SKColorCompatible {
        switch self {
        case .red:  return SKColorCompatible(red: 0.90, green: 0.16, blue: 0.16, alpha: 1.0)
        case .blue: return SKColorCompatible(red: 0.18, green: 0.42, blue: 0.92, alpha: 1.0)
        case .camo: return SKColorCompatible(red: 0.22, green: 0.48, blue: 0.24, alpha: 1.0)
        }
    }

    /// The tier an enemy degrades into when popped but not destroyed.
    /// Blue -> Red. Camo degrades Camo(3) -> Blue-equivalent(2) -> Red-equivalent(1)
    /// purely via health count; color tiers are resolved from remaining health.
    static func tier(forRemainingHealth health: Int, original: EnemyType) -> EnemyType {
        if original == .camo { return .camo } // camo keeps camo skin & status until destroyed
        switch health {
        case 2...: return .blue
        default:   return .red
        }
    }
}

// MARK: - Tower Types

enum TowerType: String, CaseIterable, Identifiable {
    case dartNode
    case tackNode
    case superNode

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dartNode:  return "Dart Monkey"
        case .tackNode:  return "Tack Shooter"
        case .superNode: return "Super Monkey"
        }
    }

    /// Fixed gold purchase cost.
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

    /// Whether the tower fires a radial burst (all directions) instead of single-target darts.
    var firesRadially: Bool { self == .tackNode }

    /// Body color for the programmatic tower shape.
    var color: SKColorCompatible {
        switch self {
        case .dartNode:  return SKColorCompatible(red: 0.62, green: 0.40, blue: 0.20, alpha: 1.0)
        case .tackNode:  return SKColorCompatible(red: 0.55, green: 0.55, blue: 0.60, alpha: 1.0)
        case .superNode: return SKColorCompatible(red: 0.95, green: 0.78, blue: 0.12, alpha: 1.0)
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
        case .dartNode:  return "Camo Vision Flare"
        case .tackNode:  return "Ring Burst"
        case .superNode: return "Solar Annihilation"
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

    /// Duration of the dart monkey camo-vision effect (only meaningful for dartNode).
    var camoVisionDuration: TimeInterval { 8.0 }

    /// Damage dealt by the tack shooter's localized ring burst ability.
    var ringBurstDamage: Int { 3 }

    /// Damage dealt by super monkey's screen flash to all onscreen enemies.
    var screenFlashDamage: Int { 5 }
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
