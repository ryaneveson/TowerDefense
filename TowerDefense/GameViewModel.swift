import Foundation
import Combine

// MARK: - App Phase

enum GamePhase {
    case home
    case playing
}

// MARK: - Sidebar Snapshot

/// Immutable snapshot of a placed defense, published to drive the upgrade sidebar.
struct TowerPanelInfo: Equatable {
    let id: String
    let type: TowerType
    var pathALevel: Int
    var pathBLevel: Int
    var damage: Int
    var range: Int
    var fireRate: Double
}

/// Unified ObservableObject acting as the data bridge between the SpriteKit
/// simulation and the SwiftUI HUD. Handles balance transactions, lives,
/// wave tracking, game speed, and per-tower ability cooldown timestamps.
final class GameViewModel: ObservableObject {

    // MARK: - Published Metrics

    @Published var phase: GamePhase = .home
    @Published var gold: Int = GameConfig.startingGold
    @Published var lives: Int = GameConfig.startingLives
    @Published var currentWave: Int = 1
    @Published var isSimulationActive: Bool = true
    @Published var isGameOver: Bool = false
    @Published var isVictory: Bool = false
    @Published var selectedTowerType: TowerType? = nil

    /// Waves required to secure the current sector (set at mission start).
    @Published var totalWaves: Int = 10

    /// Simulation tick multiplier: 1.0 normal, 2.0 fast-forward.
    @Published var gameSpeed: Double = 1.0

    /// Snapshot of the currently selected placed defense (drives the sidebar).
    @Published var selectedTowerInfo: TowerPanelInfo? = nil

    /// Transient HUD message (e.g. ability fired, insufficient funds).
    @Published var statusMessage: String = "Select a defense to begin!"

    // MARK: - Guide Robot

    /// Latest briefing shown by the on-screen guide robot ("ARC-7").
    @Published var guideMessage: String =
        "Hi Commander, I'm ARC-7! Tap a defense at the bottom, then tap an open spot on the map to deploy it. I'll pop in whenever a new threat appears."
    /// Bumps whenever a new guide message arrives so the UI can re-animate.
    @Published var guideMessageID: Int = 0

    /// Guide keys already shown this mission, so one-time tips don't repeat.
    private var shownGuideKeys: Set<String> = []

    /// Shows a guide briefing. One-time keys are suppressed after first use.
    func showGuide(key: String, message: String, repeatable: Bool = false) {
        if !repeatable {
            guard !shownGuideKeys.contains(key) else { return }
            shownGuideKeys.insert(key)
        }
        guideMessage = message
        guideMessageID += 1
    }

    // MARK: - Ability Cooldown Index

    /// Maps tower ID signatures to the Date its ability was last executed.
    private(set) var abilityTimestamps: [String: Date] = [:]

    // MARK: - Currency Transactions

    /// Attempts to clear `amount` from the balance.
    /// Returns true when the purchase succeeded.
    @discardableResult
    func spendGold(_ amount: Int) -> Bool {
        guard gold >= amount else { return false }
        gold -= amount
        return true
    }

    func earnGold(_ amount: Int) {
        gold += amount
    }

    func canAfford(_ type: TowerType) -> Bool {
        gold >= type.cost
    }

    // MARK: - Lives / Game Over

    /// Decrease lives when an enemy leaks past the final waypoint.
    func loseLife(_ amount: Int = 1) {
        guard !isGameOver else { return }
        lives = max(0, lives - amount)
        if lives <= 0 {
            isGameOver = true
            isSimulationActive = false
            selectedTowerInfo = nil
            statusMessage = "Core breached — the swarm broke through!"
        } else if lives <= 8 {
            showGuide(key: "lowLives",
                      message: "Core integrity is critical! Every enemy that leaks past the end of the track costs you a life. Upgrade your strongest towers and seal the gaps before the next wave overwhelms you.")
        }
    }

    // MARK: - Wave Tracking

    func advanceWave() {
        currentWave += 1
        statusMessage = "Wave \(currentWave) of \(totalWaves) incoming!"
    }

    // MARK: - Mission Victory

    /// Called by the scene once the final wave is cleared.
    func winMission() {
        guard !isVictory && !isGameOver else { return }
        isVictory = true
        isSimulationActive = false
        selectedTowerType = nil
        selectedTowerInfo = nil
        statusMessage = "Sector secured — invasion repelled!"
    }

    // MARK: - Game Speed

    func toggleGameSpeed() {
        gameSpeed = gameSpeed >= 2.0 ? 1.0 : 2.0
    }

    // MARK: - Ability Cooldown Verification

    /// Returns true when the tower identified by `towerID` is allowed to
    /// trigger its ability (its full cooldown window has elapsed).
    func isAbilityReady(towerID: String, type: TowerType, at date: Date = Date()) -> Bool {
        guard let last = abilityTimestamps[towerID] else { return true }
        return date.timeIntervalSince(last) >= type.abilityCooldown
    }

    /// Seconds remaining until the tower's ability becomes available again.
    func abilityCooldownRemaining(towerID: String, type: TowerType, at date: Date = Date()) -> TimeInterval {
        guard let last = abilityTimestamps[towerID] else { return 0 }
        return max(0, type.abilityCooldown - date.timeIntervalSince(last))
    }

    /// Records an ability execution timestamp for the given tower ID.
    func recordAbilityUse(towerID: String, at date: Date = Date()) {
        abilityTimestamps[towerID] = date
    }

    // MARK: - Reset

    /// Wipes all gameplay state back to default configuration values.
    /// Does not change the app phase — callers decide where to navigate.
    func reset() {
        gold = GameConfig.startingGold
        lives = GameConfig.startingLives
        currentWave = 1
        isSimulationActive = true
        isGameOver = false
        isVictory = false
        selectedTowerType = nil
        selectedTowerInfo = nil
        gameSpeed = 1.0
        abilityTimestamps.removeAll()
        statusMessage = "Deploy your first defense!"
        shownGuideKeys.removeAll()
        guideMessage = "Hi Commander, I'm ARC-7! Tap a defense at the bottom, then tap an open spot on the map to deploy it. I'll pop in whenever a new threat appears."
        guideMessageID += 1
    }
}
