import CoreGraphics

/// Pure layout math for the HUD so responsive sizing is deterministic and testable.
/// The SpriteKit playfield always renders aspect-fit; these metrics size the
/// SwiftUI chrome (top bar, dock, sidebar) so nothing is ever cut off.
struct LayoutMetrics: Equatable {
    let size: CGSize

    init(size: CGSize) {
        self.size = size
    }

    /// Phones and small windows get compacted chrome.
    var isCompact: Bool {
        size.width < 760 || size.height < 430
    }

    var hudFontScale: CGFloat { isCompact ? 0.85 : 1.0 }

    var topBarHeight: CGFloat { isCompact ? 42 : 52 }

    /// The purchase dock scrolls horizontally, so cells keep a tappable fixed width.
    var dockCellWidth: CGFloat { isCompact ? 86 : 104 }

    var dockHeight: CGFloat { isCompact ? 92 : 110 }

    /// Upgrade sidebar never exceeds roughly half the screen.
    var sidebarWidth: CGFloat { min(280, size.width * 0.46) }

    /// Inline helper text (placement hints, mission name) only on roomy screens.
    var showsInlineHints: Bool { size.width >= 900 }

    /// Verifies every fixed HUD element fits with a visible playfield remaining.
    var allElementsFit: Bool {
        let verticalChrome = topBarHeight + dockHeight + 36 // banner allowance
        let minPlayfieldHeight: CGFloat = 120
        let minTopBarWidth: CGFloat = isCompact ? 420 : 560
        return size.height - verticalChrome >= minPlayfieldHeight
            && size.width >= minTopBarWidth
            && sidebarWidth <= size.width * 0.6
            && dockCellWidth >= 80
    }
}
