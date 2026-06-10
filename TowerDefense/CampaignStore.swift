import Foundation
import Combine

/// Persistent campaign progress: completed sectors, best waves, and the
/// derived unlock state for maps and defenses. Saved to UserDefaults and
/// loaded automatically at launch.
final class CampaignStore: ObservableObject {

    private static let completedKey = "campaign.completedMapIDs"
    private static let bestWavesKey = "campaign.bestWaves"

    @Published private(set) var completedMapIDs: Set<String>
    @Published private(set) var bestWaves: [String: Int]

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.completedKey),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            completedMapIDs = ids
        } else {
            completedMapIDs = []
        }
        if let data = defaults.data(forKey: Self.bestWavesKey),
           let waves = try? JSONDecoder().decode([String: Int].self, from: data) {
            bestWaves = waves
        } else {
            bestWaves = [:]
        }
    }

    // MARK: - Queries

    func isCompleted(_ map: MapConfig) -> Bool {
        completedMapIDs.contains(map.id)
    }

    /// Mission 1 is always open; each later sector requires the previous one.
    func isUnlocked(_ map: MapConfig) -> Bool {
        guard let index = GameConfig.maps.firstIndex(of: map) else { return false }
        if index == 0 { return true }
        return completedMapIDs.contains(GameConfig.maps[index - 1].id)
    }

    func bestWave(for map: MapConfig) -> Int? {
        bestWaves[map.id]
    }

    /// Starter defenses plus every reward earned from completed missions.
    var unlockedTowers: Set<TowerType> {
        var towers = Set(GameConfig.starterTowers)
        for map in GameConfig.maps where completedMapIDs.contains(map.id) {
            if let reward = map.unlockTowerOnComplete {
                towers.insert(reward)
            }
        }
        return towers
    }

    func isTowerUnlocked(_ type: TowerType) -> Bool {
        unlockedTowers.contains(type)
    }

    // MARK: - Mutations

    func markCompleted(_ map: MapConfig) {
        guard !completedMapIDs.contains(map.id) else { return }
        completedMapIDs.insert(map.id)
        persist()
    }

    func recordBestWave(_ map: MapConfig, wave: Int) {
        let current = bestWaves[map.id] ?? 0
        guard wave > current else { return }
        bestWaves[map.id] = wave
        persist()
    }

    func resetProgress() {
        completedMapIDs = []
        bestWaves = [:]
        persist()
    }

    private func persist() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(completedMapIDs) {
            defaults.set(data, forKey: Self.completedKey)
        }
        if let data = try? JSONEncoder().encode(bestWaves) {
            defaults.set(data, forKey: Self.bestWavesKey)
        }
    }
}
