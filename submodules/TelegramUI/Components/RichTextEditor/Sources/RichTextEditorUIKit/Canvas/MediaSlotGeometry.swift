#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import MosaicLayout

/// The prompt the ENGINE editor shows under an image while its caption is empty. The legacy canvas
/// draws the host's localized `RichTextEditorPlaceholders.caption` instead; the engine does not take
/// host placeholders yet, so it shows the default.
public let mediaCaptionPlaceholderText = RichTextEditorPlaceholders.default.caption

/// The slot a media block reserves, as pure geometry: the numbers `MediaBlockBox` reserves and
/// `MediaItemNodeView.updateMosaic` fills, and — since R7-media — what the engine editor's
/// `MediaTextAttachment` reserves too. ONE copy, because the package `CLAUDE.md` records that the
/// box and the renderer must stay in lockstep, and a third copy would be a third thing to keep.
public enum MediaSlotGeometry {
    /// Media is never taller than its display width, up to this.
    public static let heightCap: CGFloat = 1000
    /// Above the medium and below the unit's last line.
    public static let verticalInset: CGFloat = 8
    /// Between the medium and its caption.
    public static let captionGap: CGFloat = 4
    /// A caption-less block renders as a fixed-height row (NOT aspect-scaled). Both heights match the V2
    /// renderer's frame height in `InstantPageV2Layout.swift` (`audioFrame` / `documentFrame`).
    public static let audioRowHeight: CGFloat = 44
    public static let documentRowHeight: CGFloat = 52

    public static func rowHeight(kind: MediaKind) -> CGFloat {
        kind == .document ? documentRowHeight : audioRowHeight
    }

    /// Displayed image slot: `displayWidth` clamped to `maxWidth` (or fills `maxWidth`), height = the
    /// aspect-preserving height CAPPED at `min(heightCap, maxWidth)`.
    public static func imageDisplaySize(naturalSize: Size2D, displayWidth: Double?, maxWidth: CGFloat) -> CGSize {
        let naturalW = CGFloat(naturalSize.width), naturalH = CGFloat(naturalSize.height)
        let targetW = displayWidth.map { min(CGFloat($0), maxWidth) } ?? maxWidth
        let cap = min(heightCap, maxWidth)
        guard naturalW > 0, naturalH > 0 else { return CGSize(width: targetW, height: min(targetW * 0.5625, cap)) }
        let aspectHeight = naturalH * (targetW / naturalW)
        return CGSize(width: targetW, height: min(aspectHeight, cap))
    }

    /// Mosaic-assembled size at `maxWidth`, the SAME engine + cap the renderer applies. When the
    /// packed height exceeds the cap, the mosaic is reserved at full width × cap.
    public static func mosaicSize(itemSizes: [CGSize], maxWidth: CGFloat) -> CGSize {
        let cap = min(heightCap, maxWidth)
        let (_, size) = chatMessageBubbleMosaicLayout(maxSize: CGSize(width: maxWidth, height: cap), itemSizes: itemSizes)
        if size.height > cap {
            return CGSize(width: maxWidth, height: cap)
        }
        return size
    }

    /// Full width × the TALLEST item's aspect height fitted to `maxWidth`, capped.
    public static func slideshowSize(itemSizes: [CGSize], maxWidth: CGFloat) -> CGSize {
        let cap = min(heightCap, maxWidth)
        var tallest: CGFloat = 0
        for size in itemSizes {
            let fitted = (size.width > 0 && size.height > 0) ? size.height * (maxWidth / size.width) : maxWidth * 0.5625
            tallest = max(tallest, fitted)
        }
        return CGSize(width: maxWidth, height: min(tallest, cap))
    }

    /// The slot for a whole block: a caption-less row, an album in its mode, or a single image.
    public static func slotSize(items: [MediaItem], displayMode: MediaDisplayMode,
                                displayWidth: Double?, maxWidth: CGFloat) -> CGSize {
        let maxWidth = max(maxWidth, 1)
        if items.first?.kind.isCaptionless ?? false {
            return CGSize(width: maxWidth, height: rowHeight(kind: items.first?.kind ?? .audio))
        }
        if items.count >= 2 {
            let sizes = items.map { CGSize(width: $0.naturalSize.width, height: $0.naturalSize.height) }
            return displayMode == .slideshow ? slideshowSize(itemSizes: sizes, maxWidth: maxWidth)
                                             : mosaicSize(itemSizes: sizes, maxWidth: maxWidth)
        }
        return imageDisplaySize(naturalSize: items.first?.naturalSize ?? Size2D(width: 0, height: 0),
                                displayWidth: displayWidth, maxWidth: maxWidth)
    }
}
#endif
