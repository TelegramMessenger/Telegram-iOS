import Foundation
import UIKit
import Display

// The bottom fade a collapsed quote's content dissolves into, ported from
// `InteractiveTextComponent`'s `generateBlockMaskImage()` so a rich bubble and a regular text
// message in the same chat fade identically.
//
// The tile is opaque everywhere except two carved regions:
//   * a radial hole centred on the bottom edge, 20pt in from the trailing side — this is where the
//     expand chevron sits, and it keeps text from running under it;
//   * a linear fade over the bottom 8pt across the full width.
//
// Only the bottom-trailing corner carries any detail, so the tile is stretched from its TOP-LEFT
// pixel: cap insets `(0, 0, h-1, w-1)` pin all 56×36 points of the interesting corner and replicate
// the opaque top-left pixel across the rest. As a `CALayer` mask that is `contentsCenter` =
// `(0, 0, 1/56, 1/36)` — the same nine-part slicing, expressed in unit coordinates.

let instantPageV2QuoteFadeTileSize = CGSize(width: 36.0 + 20.0, height: 36.0)

let instantPageV2QuoteFadeMaskImage: UIImage = {
    let size = instantPageV2QuoteFadeTileSize
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        var locations: [CGFloat] = [0.0, 0.5, 1.0]
        var colors: [CGColor] = [UIColor.black.withAlphaComponent(0.0).cgColor, UIColor.black.withAlphaComponent(0.0).cgColor, UIColor.black.cgColor]
        var gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!

        // `.copy` so the hole REPLACES the opaque fill rather than compositing over it. Nothing is
        // painted past `endRadius`, which is what leaves the rest of the tile opaque.
        context.setBlendMode(.copy)
        context.drawRadialGradient(gradient, startCenter: CGPoint(x: size.width - 20.0, y: size.height), startRadius: 0.0, endCenter: CGPoint(x: size.width - 20.0, y: size.height), endRadius: 34.0, options: CGGradientDrawingOptions())

        locations = [0.0, 0.4, 1.0]
        colors = [UIColor.black.withAlphaComponent(0.0).cgColor, UIColor.black.withAlphaComponent(0.0).cgColor, UIColor.black.cgColor]
        gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!

        context.setBlendMode(.destinationIn)
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: size.height), end: CGPoint(x: 0.0, y: size.height - 8.0), options: CGGradientDrawingOptions())
    })!
}()

/// A quote's fade, as a `CALayer` ready to be hung off some content view's `layer.mask`.
///
/// Its own class rather than a bare `SimpleLayer` so the renderer can recognise its handiwork by
/// reading `view.layer.mask` back — no side table of which views it has masked, which would have to
/// survive view reuse and removal.
///
/// **`backgroundColor` is the dissolve control, not decoration.** A mask composites its background
/// behind its contents, so an opaque white background fills the carved regions back in and the fade
/// vanishes; clear leaves the carve-out visible. Animating between the two cross-fades the fade
/// itself, which is how expanding a quote dissolves its bottom edge instead of snapping it away.
final class InstantPageV2QuoteFadeMaskLayer: SimpleLayer {
    /// Guards the dissolve's teardown. Expanding a quote animates the fade away and removes the mask
    /// on completion; collapsing it again mid-animation must not let that stale completion fire and
    /// strip the mask the reader just asked for. Both paths stamp this, and the completion checks it.
    private var dissolveToken: Int = 0

    override init() {
        super.init()

        self.contents = instantPageV2QuoteFadeMaskImage.cgImage
        self.contentsScale = instantPageV2QuoteFadeMaskImage.scale
        self.contentsCenter = CGRect(
            x: 0.0,
            y: 0.0,
            width: 1.0 / instantPageV2QuoteFadeTileSize.width,
            height: 1.0 / instantPageV2QuoteFadeTileSize.height
        )
        self.backgroundColor = UIColor.clear.cgColor
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func beginDissolve() -> Int {
        self.dissolveToken += 1
        return self.dissolveToken
    }

    func isDissolveCurrent(_ token: Int) -> Bool {
        return self.dissolveToken == token
    }

    /// Cancels any dissolve in flight, so its completion cannot tear this mask down.
    func invalidatePendingDissolve() {
        self.dissolveToken += 1
    }
}
