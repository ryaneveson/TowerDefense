import SwiftUI

/// Polished landing page: title treatment plus battleground selection cards.
struct HomeView: View {
    let onSelect: (MapConfig) -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.05, blue: 0.13),
                                    Color(red: 0.10, green: 0.04, blue: 0.19)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                titleBlock

                Text("CHOOSE YOUR BATTLEGROUND")
                    .font(.caption.weight(.bold))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.65))

                HStack(spacing: 28) {
                    ForEach(GameConfig.maps) { map in
                        MapCard(map: map) { onSelect(map) }
                    }
                }

                Text("Buy a defense from the dock, then tap the field to deploy  •  Tap a placed turret to upgrade it or fire its ability")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.vertical, 24)
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text("NEON SWARM")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [Color.cyan, Color(red: 0.75, green: 0.35, blue: 1.0)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .shadow(color: .cyan.opacity(0.45), radius: 14, y: 2)

            Text("TOWER DEFENSE")
                .font(.subheadline.weight(.semibold))
                .tracking(10)
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}

// MARK: - Map Card

private struct MapCard: View {
    let map: MapConfig
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                MapPreview(map: map)
                    .frame(width: 290, height: 168)

                VStack(alignment: .leading, spacing: 5) {
                    Text(map.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    Text(map.tagline)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 5) {
                        Text("DEPLOY")
                            .font(.caption.weight(.heavy))
                            .tracking(2)
                        Image(systemName: "chevron.right.2")
                            .font(.caption.weight(.heavy))
                    }
                    .foregroundStyle(map.theme.accent.swiftUIColor.opacity(1.0))
                    .padding(.top, 5)
                }
                .padding(14)
                .frame(width: 290, alignment: .leading)
            }
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.55), radius: 18, y: 10)
        }
        .buttonStyle(MapCardButtonStyle())
    }
}

private struct MapCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Procedural Map Preview

/// Draws a miniature of the battleground track, matching the in-game layout.
private struct MapPreview: View {
    let map: MapConfig

    var body: some View {
        Canvas { context, size in
            let sx = size.width / GameConfig.canvasWidth
            let sy = size.height / GameConfig.canvasHeight

            // SpriteKit's origin is bottom-left; flip Y so the preview matches gameplay.
            let points = map.waypoints.map {
                CGPoint(x: $0.x * sx, y: (GameConfig.canvasHeight - $0.y) * sy)
            }

            var track = Path()
            track.move(to: points[0])
            for pt in points.dropFirst() { track.addLine(to: pt) }

            context.stroke(track,
                           with: .color(map.theme.trackOuter.swiftUIColor),
                           style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
            context.stroke(track,
                           with: .color(map.theme.trackInner.swiftUIColor),
                           style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            context.stroke(track,
                           with: .color(map.theme.accent.swiftUIColor),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .background(map.theme.background.swiftUIColor)
    }
}
