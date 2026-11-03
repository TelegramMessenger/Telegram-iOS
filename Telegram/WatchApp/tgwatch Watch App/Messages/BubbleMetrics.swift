import SwiftUI
import WatchKit

/// Single source of truth for chat-history bubble width caps. Every cap is derived
/// from one input — the screen width — so bubbles fit continuously from 40mm (162pt)
/// up to 46mm (208pt) / 49mm Ultra (205pt) with no per-device branching.
///
/// Injected via `EnvironmentValues.bubbleMetrics`, whose default reads the live
/// device. Because the default is device-derived, every `#Preview` auto-sizes to
/// whatever sim canvas the snapshot run uses — render at 40mm and bubbles size for
/// 40mm with no per-preview overrides.
struct BubbleMetrics: Equatable {
    /// Usable width for one bubble's content.
    ///
    /// `screenWidth − 24` (8 + 16): the ScrollView content has `.padding(.horizontal, 4)` (8 total)
    /// and each `MessageBubbleView` HStack reserves a `Spacer(minLength: 16)` on the
    /// non-content side. Floored at 120 so a degenerate/zero bounds read can't collapse
    /// bubbles to nothing.
    let contentWidth: CGFloat

    init(screenWidth: CGFloat) {
        contentWidth = max(120, screenWidth - 8 - 16)
    }

    /// Photo / video aspect-fit image box. `contentWidth − 8` leaves room for the
    /// bubble's own `.padding(4)` (8pt total) so the padded bubble's outer width
    /// still fits `contentWidth`.
    var photoMaxWidth: CGFloat { contentWidth - 8 }
    /// Keeps the legacy 200/180 ≈ 1.11 height ratio so a tall portrait photo can't
    /// dominate a short 40mm screen — no need to read screen height.
    var photoMaxHeight: CGFloat { photoMaxWidth * (200.0 / 180.0) }

    /// Voice / audio / poll chrome max width.
    var bubbleMaxWidth: CGFloat { contentWidth }

    /// Static / venue / live-location map width (height stays fixed at its caller's value).
    var mapWidth: CGFloat { contentWidth }

    /// Round video-note circle. Holds its current 150pt visual size on big screens,
    /// shrinks only when the screen forces it.
    var videoNoteDiameter: CGFloat { min(contentWidth, 150) }

    /// Sticker image edge. Holds 120pt on big screens (already fits 40mm).
    /// Always 120 on current hardware (contentWidth ≥ 120 via the floor); the cap is a stable injection point.
    var stickerMaxEdge: CGFloat { min(contentWidth, 120) }

    /// Reply card rendered above a chrome-less sticker.
    var stickerReplyCardMaxWidth: CGFloat { min(contentWidth, 160) }
}

private struct BubbleMetricsKey: EnvironmentKey {
    static var defaultValue: BubbleMetrics {
        BubbleMetrics(screenWidth: WKInterfaceDevice.current().screenBounds.width)
    }
}

extension EnvironmentValues {
    var bubbleMetrics: BubbleMetrics {
        get { self[BubbleMetricsKey.self] }
        set { self[BubbleMetricsKey.self] = newValue }
    }
}
