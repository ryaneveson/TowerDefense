import SwiftUI

/// Campaign landing page: story header plus the sequential mission grid.
/// Missions unlock in order; progress is persisted by CampaignStore.
struct HomeView: View {
    @ObservedObject var store: CampaignStore
    let onSelect: (MapConfig) -> Void

    @State private var showResetConfirm = false

    var body: some View {
        ZStack {
            SpaceBackground()

            VStack(spacing: 14) {
                header

                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
                        ForEach(Array(GameConfig.maps.enumerated()), id: \.element.id) { index, map in
                            MissionCard(
                                map: map,
                                missionNumber: index + 1,
                                unlocked: store.isUnlocked(map),
                                completed: store.isCompleted(map),
                                bestWave: store.bestWave(for: map),
                                previousName: index > 0 ? GameConfig.maps[index - 1].name : nil
                            ) {
                                onSelect(map)
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 12)
                }

                footer
            }
            .padding(.vertical, 16)
        }
        .alert("Reset campaign progress?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) { store.resetProgress() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All completed sectors, unlocked defenses, and records will be wiped.")
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("GALACTIC DEFENSE")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [Color.cyan, Color(red: 0.75, green: 0.35, blue: 1.0)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .shadow(color: .cyan.opacity(0.45), radius: 14, y: 2)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text("NETWORK CAMPAIGN")
                .font(.caption.weight(.semibold))
                .tracking(8)
                .foregroundStyle(.white.opacity(0.55))

            Text(GameConfig.storyIntro)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
                .padding(.horizontal, 24)
        }
    }

    private var footer: some View {
        HStack {
            let completedCount = GameConfig.maps.filter { store.isCompleted($0) }.count
            Label("\(completedCount)/\(GameConfig.maps.count) sectors secured  •  \(store.unlockedTowers.count)/\(TowerType.allCases.count) defenses unlocked",
                  systemImage: "checkmark.seal.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))

            Spacer()

            Button {
                showResetConfirm = true
            } label: {
                Label("Reset Progress", systemImage: "trash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.06), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Starfield Background

/// Procedural deep-space backdrop shared by menu screens.
struct SpaceBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.02, green: 0.03, blue: 0.10),
                                    Color(red: 0.08, green: 0.03, blue: 0.16)],
                           startPoint: .top, endPoint: .bottom)

            Canvas { context, size in
                var generator = SeededGenerator(seed: 99)
                // Nebula washes.
                for _ in 0..<4 {
                    let w = CGFloat.random(in: 240...520, using: &generator)
                    let h = CGFloat.random(in: 140...300, using: &generator)
                    let x = CGFloat.random(in: 0...size.width, using: &generator)
                    let y = CGFloat.random(in: 0...size.height, using: &generator)
                    let hue = Double.random(in: 0.55...0.85, using: &generator)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h)),
                        with: .color(Color(hue: hue, saturation: 0.7, brightness: 0.45).opacity(0.14))
                    )
                }
                // Stars.
                for _ in 0..<140 {
                    let r = CGFloat.random(in: 0.5...1.8, using: &generator)
                    let x = CGFloat.random(in: 0...size.width, using: &generator)
                    let y = CGFloat.random(in: 0...size.height, using: &generator)
                    let brightness = Double.random(in: 0.3...1.0, using: &generator)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                        with: .color(.white.opacity(brightness * 0.8))
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Mission Card

private struct MissionCard: View {
    let map: MapConfig
    let missionNumber: Int
    let unlocked: Bool
    let completed: Bool
    let bestWave: Int?
    let previousName: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    MapPreview(map: map)
                        .frame(height: 118)
                        .clipped()
                        .opacity(unlocked ? 1.0 : 0.35)

                    statusBadge
                        .padding(8)

                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: 118)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(String(format: "%02d", missionNumber)) — \(map.name)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(map.sector)
                        .font(.caption2.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(map.theme.accent.swiftUIColor.opacity(1.0))

                    Text(unlocked ? map.missionDescription
                                  : "Secure \(previousName ?? "the previous sector") to unlock.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 10) {
                        difficultyStars
                        Label("\(map.totalWaves) waves", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                        if let bestWave {
                            Label("Best: \(bestWave)", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                    }

                    if let reward = map.unlockTowerOnComplete {
                        Label("Reward: \(reward.displayName)", systemImage: "gift.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(completed ? .green.opacity(0.7) : .yellow.opacity(0.85))
                    }
                }
                .padding(12)
            }
            .background(Color.white.opacity(unlocked ? 0.07 : 0.03))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: completed ? 1.5 : 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
        }
        .buttonStyle(MissionCardButtonStyle())
        .disabled(!unlocked)
    }

    private var borderColor: Color {
        if completed { return .green.opacity(0.5) }
        if unlocked { return .white.opacity(0.18) }
        return .white.opacity(0.08)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if completed {
            Label("SECURED", systemImage: "checkmark.seal.fill")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.green, in: Capsule())
        } else if unlocked {
            Text("ENGAGE")
                .font(.system(size: 9, weight: .heavy))
                .tracking(1)
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.cyan, in: Capsule())
        } else {
            Text("LOCKED")
                .font(.system(size: 9, weight: .heavy))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.6), in: Capsule())
        }
    }

    private var difficultyStars: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < map.difficulty ? "star.fill" : "star")
                    .font(.system(size: 8))
                    .foregroundStyle(i < map.difficulty ? .orange : .white.opacity(0.25))
            }
        }
    }
}

private struct MissionCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Procedural Map Preview

/// Draws a miniature of the sector's flight corridor, matching the in-game layout.
struct MapPreview: View {
    let map: MapConfig

    var body: some View {
        Canvas { context, size in
            let sx = size.width / GameConfig.canvasWidth
            let sy = size.height / GameConfig.canvasHeight

            // Star dust.
            var generator = SeededGenerator(seed: UInt64(map.totalWaves * 31 + map.difficulty))
            for _ in 0..<26 {
                let x = CGFloat.random(in: 0...size.width, using: &generator)
                let y = CGFloat.random(in: 0...size.height, using: &generator)
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)),
                             with: .color(.white.opacity(Double.random(in: 0.2...0.7, using: &generator))))
            }

            // SpriteKit's origin is bottom-left; flip Y so the preview matches gameplay.
            let points = map.waypoints.map {
                CGPoint(x: $0.x * sx, y: (GameConfig.canvasHeight - $0.y) * sy)
            }

            var track = Path()
            track.move(to: points[0])
            for pt in points.dropFirst() { track.addLine(to: pt) }

            context.stroke(track,
                           with: .color(map.theme.trackOuter.swiftUIColor),
                           style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
            context.stroke(track,
                           with: .color(map.theme.trackInner.swiftUIColor),
                           style: StrokeStyle(lineWidth: 5.5, lineCap: .round, lineJoin: .round))
            context.stroke(track,
                           with: .color(map.theme.accent.swiftUIColor),
                           style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
        }
        .background(map.theme.background.swiftUIColor)
    }
}
