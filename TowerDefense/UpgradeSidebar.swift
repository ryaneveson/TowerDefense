import SwiftUI

/// Slide-out panel shown when a placed defense is selected.
/// Displays stats, the active ability trigger, and two upgrade paths.
struct UpgradeSidebar: View {
    let info: TowerPanelInfo
    @ObservedObject var viewModel: GameViewModel
    let onUpgrade: (UpgradePath) -> Void
    let onAbility: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            statsRow
            abilitySection
            pathSection(.alpha)
            pathSection(.beta)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 270)
        .frame(maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color(red: 0.07, green: 0.08, blue: 0.16).opacity(0.97),
                                    Color(red: 0.11, green: 0.06, blue: 0.20).opacity(0.97)],
                           startPoint: .top, endPoint: .bottom)
        )
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22))
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.6), radius: 20, x: -6)
        .padding(.vertical, 8)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(info.type.color.swiftUIColor)
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1.5))
                .shadow(color: info.type.color.swiftUIColor.opacity(0.8), radius: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(info.type.displayName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text(info.type.roleDescription)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: 8) {
            statTile(label: "DMG", value: "\(info.damage)", icon: "bolt.fill", tint: .orange)
            statTile(label: "RNG", value: "\(info.range)", icon: "scope", tint: .cyan)
            statTile(label: "RATE", value: String(format: "%.1f/s", info.fireRate), icon: "timer", tint: .green)
        }
    }

    private func statTile(label: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Ability

    private var abilitySection: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            let ready = viewModel.isAbilityReady(towerID: info.id, type: info.type)
            let remaining = viewModel.abilityCooldownRemaining(towerID: info.id, type: info.type)

            Button(action: onAbility) {
                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text(info.type.abilitySignature)
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text(ready ? "FIRE" : "\(Int(ceil(remaining)))s")
                            .font(.caption.weight(.heavy).monospacedDigit())
                            .foregroundStyle(ready ? .black : .white.opacity(0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(ready ? AnyShapeStyle(.yellow) : AnyShapeStyle(.white.opacity(0.12)),
                                        in: Capsule())
                    }
                    Text(info.type.abilityDescription)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(.white)
                .padding(12)
                .background(Color.white.opacity(ready ? 0.10 : 0.05), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ready ? .yellow.opacity(0.6) : .white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(!ready)
        }
    }

    // MARK: Upgrade Paths

    private func pathSection(_ path: UpgradePath) -> some View {
        let level = path == .alpha ? info.pathALevel : info.pathBLevel
        let title = path == .alpha ? info.type.pathATitle : info.type.pathBTitle
        let detail = path == .alpha ? info.type.pathADetail : info.type.pathBDetail
        let cost = info.type.upgradeCost(path: path, currentLevel: level)
        let tint: Color = path == .alpha ? .cyan : .orange

        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(0..<TowerType.maxUpgradeLevel, id: \.self) { i in
                        Circle()
                            .fill(i < level ? tint : Color.white.opacity(0.15))
                            .frame(width: 7, height: 7)
                    }
                }
            }

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))

            if let cost {
                let affordable = viewModel.gold >= cost
                Button {
                    onUpgrade(path)
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Upgrade")
                            .font(.caption.weight(.bold))
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "hexagon.fill")
                                .font(.system(size: 8))
                            Text("\(cost)")
                                .font(.caption.weight(.bold).monospacedDigit())
                        }
                    }
                    .foregroundStyle(affordable ? .black : .white.opacity(0.4))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(affordable ? AnyShapeStyle(tint) : AnyShapeStyle(.white.opacity(0.08)),
                                in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .disabled(!affordable)
            } else {
                Text("MAX LEVEL")
                    .font(.caption.weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(tint.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}
