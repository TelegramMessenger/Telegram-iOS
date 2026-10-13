import Foundation
import UIKit

/// The body size the chat-message table below is authored against — the `.regular` Text Size step. A
/// chat host passes `baseDisplaySize / instantPageChatMessageAuthoredFontSize` as the layout's
/// `contentScale`, so `.regular` is exactly 1.0 and every other step scales the whole page.
public let instantPageChatMessageAuthoredFontSize: CGFloat = 17.0

/// The `contentScale` a chat host passes to `layoutInstantPageV2` for a body size — `.regular` (17) is exactly
/// 1.0. One function so every chat surface (bubble, send preview, attachment editor previews) derives it the
/// same way and a policy change lands once.
public func instantPageChatMessageContentScale(baseFontSize: CGFloat) -> CGFloat {
    return baseFontSize / instantPageChatMessageAuthoredFontSize
}

public extension InstantPageTextCategories {
    /// The text categories a rich message renders with in a chat bubble.
    ///
    /// This was three hand-copied tables — the bubble, the long-press send preview, and the
    /// TextProcessing screen — which had DRIFTED apart: the bubble carried heading
    /// `lineSpacingFactor` 1.0 and body 0.9, the other two 0.685 and 1.0, so the send preview did not
    /// match the bubble it was previewing. The bubble's values won because it is the surface the
    /// recipient actually sees.
    ///
    /// It is also what both rich-text editor hosts lay text out with, via
    /// `InstantPageTheme.richTextRenderMetrics()` — so the composer and the article editor are
    /// WYSIWYG against this table. Changing a value here moves the editor too, by design.
    static func chatMessage(primaryText: UIColor, secondaryText: UIColor) -> InstantPageTextCategories {
        return InstantPageTextCategories(
            kicker: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: primaryText),
            header: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 24.0, lineSpacingFactor: 1.0, weight: .medium), color: primaryText),
            subheader: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: instantPageNominalSubheaderFontSize, lineSpacingFactor: 1.0, weight: .medium), color: primaryText),
            paragraph: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 0.9), color: primaryText),
            caption: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: secondaryText),
            credit: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 13.0, lineSpacingFactor: 1.0), color: secondaryText),
            table: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: primaryText),
            article: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 18.0, lineSpacingFactor: 1.0), color: primaryText),
            // One step below body, like `table` and a quote's body — 15, not the Instant View themes' 14.
            // V2's `layoutCodeBlock` sizes code from `InstantPageMetrics.codeBlockFontSize` (the same 15
            // at page scale), so this is what actually renders, stated here so the table reads true.
            codeBlock: InstantPageTextAttributes(font: InstantPageFont(style: .monospace, size: 15.0, lineSpacingFactor: 1.0), color: primaryText)
        )
    }
}
