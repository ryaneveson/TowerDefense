import SwiftUI
import SpriteKit

// MARK: - Root: phase routing

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    @State private var scene: GameScene?

    var body: some View {
        ZStack {
            if viewModel.phase == .playing, let scene {
                GameContainerView(scene: scene,
                                  viewModel: viewModel,
                                  onReplay: replay,
                                  onHome: goHome)
                    .transition(.opacity)
            } else {
                HomeView { map in start(map) }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.phase == .playing)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    /// Builds a fresh scene for the chosen battleground and enters gameplay.
    private func start(_ map: MapConfig) {
        viewModel.reset()
        let newScene = GameScene(size: GameConfig.canvasSize)
        newScene.scaleMode = .aspectFit
        newScene.map = map
        newScene.viewModel = viewModel
        scene = newScene
        viewModel.statusMessage = "Defend \(map.name)! Deploy your first turret."
        viewModel.phase = .playing
    }

    private func replay() {
        viewModel.reset()
        scene?.resetSimulation()
    }

    private func goHome() {
        viewModel.reset()
        viewModel.phase = .home
        scene = nil
    }
}

// MARK: - Gameplay container: canvas + HUD + sidebar

private struct GameContainerView: View {
    let scene: GameScene
    @ObservedObject var viewModel: GameViewModel
    let onReplay: () -> Void
    let onHome: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [Color(red: 0.03, green: 0.03, blue: 0.08), .black],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                SpriteView(scene: scene)
                    .aspectRatio(GameConfig.canvasWidth / GameConfig.canvasHeight, contentMode: .fit)
                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)

                VStack(spacing: 0) {
                    topDashboard
                    Spacer()
                    statusBanner
                    purchaseDock
                }

                // Slide-out defense upgrade sidebar.
                if let info = viewModel.selectedTowerInfo {
                    UpgradeSidebar(info: info,
                                   viewModel: viewModel,
                                   onUpgrade: { path in scene.upgrade(towerID: info.id, path: path) },
                                   onAbility: { scene.activateAbility(towerID: info.id) },
                                   onClose: { scene.deselectTower() })
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .zIndex(2)
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

    private var topDashboard: some View {
        HStack(spacing: 12) {
            dashboardChip(icon: "hexagon.fill", tint: .yellow, label: "\(viewModel.gold)")
            dashboardChip(icon: "shield.lefthalf.filled", tint: .red, label: "\(viewModel.lives)")
            dashboardChip(icon: "antenna.radiowaves.left.and.right", tint: .cyan, label: "Wave \(viewModel.currentWave)")

            Spacer()

            if viewModel.selectedTowerType != nil {
                Label("Tap the field to deploy", systemImage: "hand.tap.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.6), in: Capsule())
                    .overlay(Capsule().stroke(.green.opacity(0.4), lineWidth: 1))
            }

            speedToggle

            Button(action: onHome) {
                Image(systemName: "house.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.6), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(colors: [.black.opacity(0.75), .black.opacity(0.35)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private var speedToggle: some View {
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
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
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

    private func dashboardChip(icon: String, tint: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .shadow(color: tint.opacity(0.7), radius: 4)
            Text(label)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(.black.opacity(0.6), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
    }

    // MARK: Status Banner

    private var statusBanner: some View {
        Text(viewModel.statusMessage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(.black.opacity(0.6), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
            .padding(.bottom, 8)
            .animation(.easeInOut(duration: 0.2), value: viewModel.statusMessage)
    }

    // MARK: Purchase Dock

    private var purchaseDock: some View {
        HStack(spacing: 14) {
            ForEach(TowerType.allCases) { type in
                towerCell(for: type)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.75)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private func towerCell(for type: TowerType) -> some View {
        let affordable = viewModel.canAfford(type)
        let isSelected = viewModel.selectedTowerType == type

        return Button {
            scene.deselectTower()
            viewModel.selectedTowerType = isSelected ? nil : type
            viewModel.statusMessage = isSelected
                ? "Deployment cancelled."
                : "Deploying \(type.displayName) — tap an open spot on the field."
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(type.color.swiftUIColor)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1.5))
                    .shadow(color: type.color.swiftUIColor.opacity(0.8), radius: 6)

                Text(type.displayName)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 3) {
                    Image(systemName: "hexagon.fill")
                        .font(.system(size: 8))
                    Text("\(type.cost)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                }
                .foregroundStyle(affordable ? .yellow : .gray)

                Text(type.roleDescription)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(isSelected ? Color.cyan.opacity(0.25) : Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(isSelected ? .cyan : .white.opacity(0.18), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? .cyan.opacity(0.4) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .disabled(!affordable && !isSelected)
        .opacity(affordable || isSelected ? 1.0 : 0.45)
    }

    // MARK: Game Over Overlay

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 18) {
                Text("CORE BREACHED")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.red, .orange],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .shadow(color: .red.opacity(0.6), radius: 12)

                Text("You survived to wave \(viewModel.currentWave).")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)

                HStack(spacing: 14) {
                    Button(action: onReplay) {
                        Label("Play Again", systemImage: "arrow.counterclockwise.circle.fill")
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
            .padding(40)
            .background(
                LinearGradient(colors: [Color(red: 0.08, green: 0.08, blue: 0.16),
                                        Color(red: 0.12, green: 0.06, blue: 0.18)],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 26)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.7), radius: 30)
        }
        .transition(.scale.combined(with: .opacity))
    }
}
