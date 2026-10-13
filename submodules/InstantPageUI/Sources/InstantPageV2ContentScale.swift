import Foundation
import UIKit
import Display

/// Everything `layoutInstantPageV2` derives from the host's content scale, computed ONCE per page.
///
/// Two scales meet here: the host's `contentScale` (the chat's Text Size over the authored 17pt, 1.0
/// everywhere else) and the renderer's own `InstantPageMetrics.quoteScale` (quoted content one step
/// below body). Each output is the BASE theme or the raw literals times ONE product, rounded once —
/// never a scaled theme scaled again. Rounding twice (`floor(floor(17·s)·q)`) happens to agree with
/// rounding once for the paragraph at all seven Text Size steps, but that is luck per category, not
/// a property; the metrics test that says "the quote scale applied twice is not the quote scale"
/// encodes the same policy.
struct InstantPageV2ScaledLayoutInputs {
    let theme: InstantPageTheme
    let metrics: InstantPageMetrics
    let quoteTheme: InstantPageTheme
    let quoteMetrics: InstantPageMetrics

    /// `baseTheme` must be UNSCALED (`fontSizeMultiplier == 1.0`) unless `contentScale` is 1.0; the layout
    /// entry point asserts this. `screenScale` is injectable for the same reason as on
    /// `InstantPageMetrics`: the test process reports a 1x screen, on which a pixel snap is a floor.
    init(baseTheme: InstantPageTheme, contentScale: CGFloat, screenScale: CGFloat = UIScreenScale) {
        // Quoted content sits one step below body. `lineSpacingFactor: 1.0` because that field is
        // already a FACTOR on the font size and would double-apply; `forceSerif: theme.serif` preserves
        // the reader's serif setting rather than silently clearing it.
        //
        // No special case for `contentScale == 1.0`: `floor(x · 1.0) == x` and `InstantPageMetrics(scale:
        // 1.0)` is bit-identical to `.unscaled` by that type's invariant, so the general path IS today's
        // page. Nothing keys on the theme object's identity (the bubble's cache keys on the
        // `PresentationTheme`), so handing back a fresh theme costs nothing.
        //
        // NOTE: `withUpdatedFontStyles` reconstructs the theme field by field, and any field it omits
        // silently reverts to an `init` default — the chat bubble's theme carries eight theme-derived
        // colours that would revert with no compile error. Re-read it before changing it.
        let quoteScale = InstantPageMetrics.quoteScale
        self.theme = baseTheme.withUpdatedFontStyles(
            sizeMultiplier: contentScale,
            lineSpacingFactor: 1.0,
            forceSerif: baseTheme.serif
        )
        self.metrics = InstantPageMetrics(scale: contentScale, screenScale: screenScale)
        self.quoteTheme = baseTheme.withUpdatedFontStyles(
            sizeMultiplier: contentScale * quoteScale,
            lineSpacingFactor: 1.0,
            forceSerif: baseTheme.serif
        )
        self.quoteMetrics = InstantPageMetrics(scale: contentScale * quoteScale, screenScale: screenScale)
    }
}
