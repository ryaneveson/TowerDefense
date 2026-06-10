// Standalone test runner for layout responsiveness and game-config invariants.
// Lives outside the app target; run with:
//   swiftc Tests/main.swift TowerDefense/GameConfig.swift TowerDefense/LayoutMetrics.swift -o /tmp/td-tests && /tmp/td-tests

import Foundation
import CoreGraphics

var failures = 0
var passes = 0

func expect(_ condition: Bool, _ label: String) {
    if condition {
        passes += 1
    } else {
        failures += 1
        print("FAIL  \(label)")
    }
}

// MARK: - 1. Responsive layout across device resolutions

let resolutions: [(String, CGSize)] = [
    ("iPhone SE (landscape)",      CGSize(width: 667,  height: 375)),
    ("iPhone 15 (landscape)",      CGSize(width: 852,  height: 393)),
    ("iPhone Pro Max (landscape)", CGSize(width: 932,  height: 430)),
    ("iPad mini (landscape)",      CGSize(width: 1133, height: 744)),
    ("iPad Pro 12.9 (landscape)",  CGSize(width: 1366, height: 1024)),
    ("Laptop 1440x900",            CGSize(width: 1440, height: 900)),
    ("Desktop 1080p",              CGSize(width: 1920, height: 1080)),
    ("Desktop 4K",                 CGSize(width: 3840, height: 2160)),
    ("Ultrawide 3440x1440",        CGSize(width: 3440, height: 1440)),
]

for (name, size) in resolutions {
    let metrics = LayoutMetrics(size: size)
    expect(metrics.allElementsFit, "All HUD elements fit on \(name)")
    expect(metrics.sidebarWidth <= size.width * 0.6, "Sidebar leaves the playfield visible on \(name)")
    expect(metrics.dockCellWidth >= 80, "Dock cells remain tappable on \(name)")
    expect(metrics.topBarHeight + metrics.dockHeight < size.height,
           "Chrome shorter than screen on \(name)")
}

// MARK: - 2. Campaign map invariants

expect(GameConfig.maps.count >= 8, "Campaign has at least 8 sectors")

for map in GameConfig.maps {
    expect(map.waypoints.count >= 2, "\(map.name): has a flight path")
    expect(map.totalWaves >= 8, "\(map.name): meaningful wave count")
    expect((1...5).contains(map.difficulty), "\(map.name): difficulty in 1...5")

    // Interior waypoints must sit inside the virtual canvas (entry/exit may be offscreen).
    for (index, point) in map.waypoints.enumerated()
    where index != 0 && index != map.waypoints.count - 1 {
        expect(point.x >= 0 && point.x <= GameConfig.canvasWidth &&
               point.y >= 0 && point.y <= GameConfig.canvasHeight,
               "\(map.name): waypoint \(index) inside canvas")
    }
}

let difficulties = GameConfig.maps.map(\.difficulty)
expect(difficulties == difficulties.sorted(), "Difficulty never decreases across the campaign")

let waveCounts = GameConfig.maps.map(\.totalWaves)
expect(waveCounts == waveCounts.sorted(), "Wave counts never decrease across the campaign")

expect(Set(GameConfig.maps.map(\.id)).count == GameConfig.maps.count, "Map IDs are unique")

// MARK: - 3. Defense roster invariants

expect(TowerType.allCases.count >= 8, "At least 8 unique defenses (\(TowerType.allCases.count) found)")

for tower in TowerType.allCases {
    expect(tower.cost > 0, "\(tower.displayName): positive cost")
    expect(tower.range > 0, "\(tower.displayName): positive range")
    if tower.behavior.isAttacking {
        expect(tower.projectileDamage > 0, "\(tower.displayName): attacking tower deals damage")
        expect(tower.fireCooldown < 100, "\(tower.displayName): attacking tower has a real cooldown")
    }
    expect(tower.abilityCooldown > 0, "\(tower.displayName): ability cooldown set")

    // Upgrade costs must exist for 3 tiers and increase monotonically per path.
    for path in UpgradePath.allCases {
        var previous = 0
        for level in 0..<TowerType.maxUpgradeLevel {
            guard let cost = tower.upgradeCost(path: path, currentLevel: level) else {
                expect(false, "\(tower.displayName): upgrade tier \(level) on \(path.rawValue) exists")
                continue
            }
            expect(cost > previous, "\(tower.displayName): \(path.rawValue) tier \(level) cost increases")
            previous = cost
        }
        expect(tower.upgradeCost(path: path, currentLevel: TowerType.maxUpgradeLevel) == nil,
               "\(tower.displayName): \(path.rawValue) caps at level \(TowerType.maxUpgradeLevel)")
    }
}

// Costs should generally rise through the roster from starter to endgame.
expect(TowerType.laser.cost < TowerType.darkMatter.cost, "Endgame tower costs more than starter")

// MARK: - 4. Invisible-enemy mechanics

expect(EnemyType.allCases.contains { $0.isInvisible }, "An invisible enemy type exists")
expect(EnemyType.allCases.contains { $0.isRobotic }, "A robotic enemy type exists")

let detectors = TowerType.allCases.filter { $0.detectsInvisibleBase }
let nonDetectors = TowerType.allCases.filter { !$0.detectsInvisibleBase }
expect(!detectors.isEmpty, "Some defenses detect cloaked enemies (\(detectors.count))")
expect(!nonDetectors.isEmpty, "Some defenses cannot detect cloaked enemies (\(nonDetectors.count))")
expect(detectors.count < TowerType.allCases.count / 2,
       "Detection is scarce enough to force strategy")

// MARK: - 5. Campaign unlock chain

expect(!GameConfig.starterTowers.isEmpty, "Starter defenses exist")

let rewardTowers = GameConfig.maps.compactMap(\.unlockTowerOnComplete)
expect(Set(rewardTowers).count == rewardTowers.count, "Each reward tower unlocks exactly once")

for tower in TowerType.allCases {
    let isStarter = GameConfig.starterTowers.contains(tower)
    let isReward = rewardTowers.contains(tower)
    expect(isStarter != isReward, "\(tower.displayName): is either a starter or a campaign reward")
}

for tower in rewardTowers {
    expect(tower.unlockingMap != nil, "\(tower.displayName): unlock hint resolves to a mission")
}

// MARK: - 6. Enemy stat sanity

for enemy in EnemyType.allCases {
    expect(enemy.speed > 0, "\(enemy.displayName): positive speed")
    expect(enemy.healthLayers > 0, "\(enemy.displayName): positive health")
    expect(enemy.reward > 0, "\(enemy.displayName): positive reward")
    expect(enemy.radius > 0, "\(enemy.displayName): positive radius")
}
expect(EnemyType.tier(forRemainingHealth: 1, original: .blob) == .pod,
       "Damaged blob degrades into a pod")
expect(EnemyType.tier(forRemainingHealth: 1, original: .wisp) == .wisp,
       "Wisp keeps its cloak until destroyed")

// MARK: - Summary

print("\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
