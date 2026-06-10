import Foundation
import Combine

/// Unified ObservableObject acting as the data bridge between the SpriteKit
/// simulation and the SwiftUI HUD. Handles balance transactions, lives,
/// wave tracking, and per-tower ability cooldown timestamps.
final class GameViewModel: ObservableObject {

    // MARK: - Published Metrics

    @Published var gold: Int = GameConfig.startingGold
    @Published var lives: Int = GameConfig.startingLives
    @Published var currentWave: Int = 1
    @Published var isSimulationActive: Bool = true
    @Published var isGameOver: Bool = false
    @Published var selectedTowerType: TowerType? = nil

    /// Transient HUD message (e.g. ability fired, insufficient funds).
    @Published var statusMessage: String = "Select a tower to begin defending!"

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
            statusMessage = "Game Over — the balloons broke through!"
        }
    }

    // MARK: - Wave Tracking

    func advanceWave() {
        currentWave += 1
        statusMessage = "Wave \(currentWave) incoming!"
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

    /// Wipes all state back to default configuration values.
    func reset() {
        gold = GameConfig.startingGold
        lives = GameConfig.startingLives
        currentWave = 1
        isSimulationActive = true
        isGameOver = false
        selectedTowerType = nil
        abilityTimestamps.removeAll()
        statusMessage = "New game started. Place your first tower!"
    }
}
