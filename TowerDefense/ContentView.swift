import SwiftUI
import SpriteKit

// MARK: - Root: phase routing + campaign persistence

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    @StateObject private var store = CampaignStore()
    @State private var scene: GameScene?
    @State private var currentMap: MapConfig?

    var body: some View {
        ZStack {
            if viewModel.phase == .playing, let scene, let currentMap {
                GameContainerView(scene: scene,
                                  map: currentMap,
                                  viewModel: viewModel,
                                  store: store,
                                  onReplay: replay,
                                  onHome: goHome,
                                  onNextMission: { next in start(next) })
                    .transition(.opacity)
            } else {
                HomeView(store: store) { map in start(map) }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.phase == .playing)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onChange(of: viewModel.isVictory) { _, won in
            guard won, let map = currentMap else { return }
            store.recordBestWave(map, wave: viewModel.currentWave)
            store.markCompleted(map)
        }
        .onChange(of: viewModel.isGameOver) { _, lost in
            guard lost, let map = currentMap else { return }
            store.recordBestWave(map, wave: viewModel.currentWave)
        }
    }

    /// Builds a fresh scene for the chosen sector and enters gameplay.
    private func start(_ map: MapConfig) {
        viewModel.reset()
        viewModel.totalWaves = map.totalWaves
        let newScene = GameScene(size: GameConfig.canvasSize)
        newScene.scaleMode = .aspectFit
        newScene.map = map
        newScene.viewModel = viewModel
        scene = newScene
        currentMap = map
        viewModel.statusMessage = "\(map.name) — survive \(map.totalWaves) waves!"
        viewModel.phase = .playing
    }

    private func replay() {
        guard let map = currentMap else { return }
        viewModel.reset()
        viewModel.totalWaves = map.totalWaves
        scene?.resetSimulation()
    }

    private func goHome() {
        viewModel.reset()
        viewModel.phase = .home
        scene = nil
        currentMap = nil
    }
}

// MARK: - Gameplay container: canvas + responsive HUD + sidebar

private struct GameContainerView: View {
    let scene: GameScene
    let map: MapConfig
    @ObservedObject var viewModel: GameViewModel
    @ObservedObject var store: CampaignStore
    let onReplay: () -> Void
    let onHome: () -> Void
    let onNextMission: (MapConfig) -> Void

    var body: some View {
        GeometryReader { geometry in
            let metrics = LayoutMetrics(size: geometry.size)

            ZStack {
                LinearGradient(colors: [Color(red: 0.02, green: 0.02, blue: 0.07), .black],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                // The playfield always renders aspect-fit, so the full map is
                // visible on every screen size and aspect ratio.
                SpriteView(scene: scene)
                    .aspectRatio(GameConfig.canvasWidth / GameConfig.canvasHeight, contentMode: .fit)
                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)

                VStack(spacing: 0) {
                    topDashboard(metrics)
                    Spacer(minLength: 0)
                    statusBanner(metrics)
                    purchaseDock(metrics)
                }

                // Slide-out defense upgrade sidebar.
                if let info = viewModel.selectedTowerInfo {
                    UpgradeSidebar(info: info,
                                   width: metrics.sidebarWidth,
                                   viewModel: viewModel,
                                   onUpgrade: { path in scene.upgrade(towerID: info.id, path: path) },
                                   onAbility: { scene.activateAbility(towerID: info.id) },
                                   onClose: { scene.deselectTower() })
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .zIndex(2)
                }

                if viewModel.isVictory {
                    victoryOverlay
                        .zIndex(3)
                }

                if viewModel.isGameOver {
                    gameOverOverlay
                        .zIndex(3)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.selectedTowerInfo)
        }
    }

    // MARK: Top Dashboard

    private func topDashboard(_ metrics: LayoutMetrics) -> some View {
        HStack(spacing: metrics.isCompact ? 8 : 12) {
            dashboardChip(icon: "hexagon.fill", tint: .yellow,
                          label: "\(viewModel.gold)", metrics: metrics)
            dashboardChip(icon: "shield.lefthalf.filled", tint: .red,
                          label: "\(viewModel.lives)", metrics: metrics)
            dashboardChip(icon: "antenna.radiowaves.left.and.right", tint: .cyan,
                          label: "Wave \(viewModel.currentWave)/\(viewModel.totalWaves)", metrics: metrics)

            if metrics.showsInlineHints {
                Text(map.name.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if viewModel.selectedTowerType != nil && metrics.showsInlineHints {
                Label("Tap the field to deploy", systemImage: "hand.tap.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.6), in: Capsule())
                    .overlay(Capsule().stroke(.green.opacity(0.4), lineWidth: 1))
            }

            speedToggle(metrics)

            Button(action: onHome) {
                Image(systemName: "house.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(metrics.isCompact ? 8 : 10)
                    .background(.black.opacity(0.6), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, metrics.isCompact ? 10 : 16)
        .padding(.vertical, metrics.isCompact ? 6 : 10)
        .frame(height: metrics.topBarHeight)
        .background(
            LinearGradient(colors: [.black.opacity(0.75), .black.opacity(0.35)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private func speedToggle(_ metrics: LayoutMetrics) -> some View {
        let isFast = viewModel.gameSpeed >= 2.0
        return Button {
            viewModel.toggleGameSpeed()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "forward.fill")
                    .font(.caption2)
                Text(isFast ? "2×" : "1×")
                    .font(.caption.weight(.heavy).monospacedDigit())
            }
            .foregroundStyle(isFast ? .black : .white)
            .padding(.horizontal, metrics.isCompact ? 10 : 13)
            .padding(.vertical, metrics.isCompact ? 6 : 8)
            .background(
                isFast
                    ? AnyShapeStyle(LinearGradient(colors: [.cyan, .green],
                                                   startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(.black.opacity(0.6)),
                in: Capsule()
            )
            .overlay(Capsule().stroke(isFast ? .clear : .white.opacity(0.25), lineWidth: 1))
            .shadow(color: isFast ? .cyan.opacity(0.5) : .clear, radius: 7)
        }
        .buttonStyle(.plain)
    }

    private func dashboardChip(icon: String, tint: Color, label: String, metrics: LayoutMetrics) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(metrics.isCompact ? .caption : .body)
                .foregroundStyle(tint)
                .shadow(color: tint.opacity(0.7), radius: 4)
            Text(label)
                .font((metrics.isCompact ? Font.subheadline : .headline).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, metrics.isCompact ? 9 : 13)
        .padding(.vertical, metrics.isCompact ? 5 : 7)
        .background(.black.opacity(0.6), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
    }

    // MARK: Status Banner

    private func statusBanner(_ metrics: LayoutMetrics) -> some View {
        Text(viewModel.statusMessage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.92))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(.black.opacity(0.6), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .animation(.easeInOut(duration: 0.2), value: viewModel.statusMessage)
    }

    // MARK: Purchase Dock (horizontally scrollable — fits any screen width)

    private func purchaseDock(_ metrics: LayoutMetrics) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TowerType.allCases) { type in
                    towerCell(for: type, metrics: metrics)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(height: metrics.dockHeight)
        .background(
            LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.8)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private func towerCell(for type: TowerType, metrics: LayoutMetrics) -> some View {
        let unlocked = store.isTowerUnlocked(type)
        let affordable = viewModel.canAfford(type)
        let isSelected = viewModel.selectedTowerType == type

        return Button {
            scene.deselectTower()
            viewModel.selectedTowerType = isSelected ? nil : type
            viewModel.statusMessage = isSelected
                ? "Deployment cancelled."
                : "Deploying \(type.displayName) — tap an open spot on the field."
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(type.color.swiftUIColor.opacity(unlocked ? 1.0 : 0.3))
                        .frame(width: 26, height: 26)
                        .overlay(Circle().stroke(.white.opacity(unlocked ? 0.7 : 0.25), lineWidth: 1.5))
                        .shadow(color: unlocked ? type.color.swiftUIColor.opacity(0.8) : .clear, radius: 6)
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }

                Text(type.displayName)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if unlocked {
                    HStack(spacing: 4) {
                        HStack(spacing: 2) {
                            Image(systemName: "hexagon.fill")
                                .font(.system(size: 7))
                            Text("\(type.cost)")
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                        }
                        .foregroundStyle(affordable ? .yellow : .gray)

                        Image(systemName: type.detectsInvisibleBase ? "eye.fill" : "eye.slash")
                            .font(.system(size: 8))
                            .foregroundStyle(type.detectsInvisibleBase ? .green : .white.opacity(0.3))
                    }

                    Text(type.roleDescription)
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } else {
                    Text("LOCKED")
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(type.unlockingMap.map { "Clear \($0.name)" } ?? "Campaign reward")
                        .font(.system(size: 7.5))
                        .foregroundStyle(.yellow.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .foregroundStyle(.white)
            .frame(width: metrics.dockCellWidth)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.cyan.opacity(0.25) : Color.white.opacity(unlocked ? 0.07 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? .cyan : .white.opacity(unlocked ? 0.18 : 0.08),
                            lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? .cyan.opacity(0.4) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked || (!affordable && !isSelected))
        .opacity(unlocked ? (affordable || isSelected ? 1.0 : 0.5) : 0.55)
    }

    // MARK: Victory Overlay

    private var victoryOverlay: some View {
        let mapIndex = GameConfig.maps.firstIndex(of: map) ?? 0
        let nextMap: MapConfig? = mapIndex + 1 < GameConfig.maps.count ? GameConfig.maps[mapIndex + 1] : nil

        return ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("SECTOR SECURED")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.green, .cyan],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .shadow(color: .green.opacity(0.6), radius: 12)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text("\(map.name) held for all \(map.totalWaves) waves.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                VStack(spacing: 6) {
                    if let reward = map.unlockTowerOnComplete {
                        Label("New defense unlocked: \(reward.displayName)", systemImage: "gift.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.yellow)
                    }
                    if let nextMap {
                        Label("Next sector unlocked: \(nextMap.name)", systemImage: "map.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.cyan)
                    } else {
                        Label("The invasion has been repelled. The galaxy is safe!", systemImage: "trophy.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.yellow)
                    }
                }
                .padding(.vertical, 4)

                HStack(spacing: 12) {
                    if let nextMap {
                        Button { onNextMission(nextMap) } label: {
                            Label("Next Mission", systemImage: "arrow.right.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(.green, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onReplay) {
                        Label("Replay", systemImage: "arrow.counterclockwise.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.14), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button(action: onHome) {
                        Label("Home", systemImage: "house.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.14), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(36)
            .background(
                LinearGradient(colors: [Color(red: 0.05, green: 0.12, blue: 0.10),
                                        Color(red: 0.04, green: 0.10, blue: 0.16)],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 26)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(.green.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.7), radius: 30)
            .padding(20)
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: Game Over Overlay

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("SECTOR LOST")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.red, .orange],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .shadow(color: .red.opacity(0.6), radius: 12)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text("The swarm broke through at wave \(viewModel.currentWave) of \(viewModel.totalWaves).")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                HStack(spacing: 14) {
                    Button(action: onReplay) {
                        Label("Try Again", systemImage: "arrow.counterclockwise.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(.yellow, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onHome) {
                        Label("Home", systemImage: "house.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.14), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(36)
            .background(
                LinearGradient(colors: [Color(red: 0.10, green: 0.05, blue: 0.07),
                                        Color(red: 0.12, green: 0.06, blue: 0.14)],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 26)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.7), radius: 30)
            .padding(20)
        }
        .transition(.scale.combined(with: .opacity))
    }
}
