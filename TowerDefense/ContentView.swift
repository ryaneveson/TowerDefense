import SwiftUI
import SpriteKit

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()

    /// One scene instance for the lifetime of the view; sized to the fixed virtual canvas.
    @State private var scene: GameScene = {
        let scene = GameScene(size: GameConfig.canvasSize)
        scene.scaleMode = .aspectFit
        return scene
    }()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                SpriteView(scene: configuredScene())
                    .aspectRatio(GameConfig.canvasWidth / GameConfig.canvasHeight, contentMode: .fit)
                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)

                VStack(spacing: 0) {
                    topDashboard
                    Spacer()
                    statusBanner
                    purchaseDock
                }

                if viewModel.isGameOver {
                    gameOverOverlay
                }
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    private func configuredScene() -> GameScene {
        if scene.viewModel == nil {
            scene.viewModel = viewModel
        }
        return scene
    }

    // MARK: - Top Inventory Dashboard Bar

    private var topDashboard: some View {
        HStack(spacing: 18) {
            dashboardChip(icon: "dollarsign.circle.fill",
                          tint: .yellow,
                          label: "\(viewModel.gold)")

            dashboardChip(icon: "heart.fill",
                          tint: .red,
                          label: "\(viewModel.lives)")

            dashboardChip(icon: "flag.checkered",
                          tint: .cyan,
                          label: "Wave \(viewModel.currentWave)")

            Spacer()

            if viewModel.selectedTowerType != nil {
                Label("Tap the map to place", systemImage: "hand.tap.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.65), in: Capsule())
            }

            Button {
                viewModel.reset()
                scene.resetSimulation()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.65), in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.55))
    }

    private func dashboardChip(icon: String, tint: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(label)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.black.opacity(0.65), in: Capsule())
    }

    // MARK: - Status Banner

    private var statusBanner: some View {
        Text(viewModel.statusMessage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(.bottom, 8)
            .animation(.easeInOut(duration: 0.2), value: viewModel.statusMessage)
    }

    // MARK: - Lower Grid Purchase Dock

    private var purchaseDock: some View {
        HStack(spacing: 14) {
            ForEach(TowerType.allCases) { type in
                towerCell(for: type)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.55))
    }

    private func towerCell(for type: TowerType) -> some View {
        let affordable = viewModel.canAfford(type)
        let isSelected = viewModel.selectedTowerType == type

        return Button {
            viewModel.selectedTowerType = isSelected ? nil : type
            viewModel.statusMessage = isSelected
                ? "Placement cancelled."
                : "Placing \(type.displayName) — tap an open spot on the map."
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(type.color.swiftUIColor)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1.5))

                Text(type.displayName)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Label("\(type.cost)", systemImage: "dollarsign.circle")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(affordable ? .yellow : .gray)

                Text(type.abilitySignature)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.green.opacity(0.35) : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? .green : .white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!affordable && !isSelected)
        .opacity(affordable || isSelected ? 1.0 : 0.45)
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        VStack(spacing: 18) {
            Text("GAME OVER")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.red)

            Text("You survived to wave \(viewModel.currentWave).")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white)

            Button {
                viewModel.reset()
                scene.resetSimulation()
            } label: {
                Label("Play Again", systemImage: "arrow.counterclockwise.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.yellow, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(40)
        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 24))
        .transition(.scale.combined(with: .opacity))
    }
}