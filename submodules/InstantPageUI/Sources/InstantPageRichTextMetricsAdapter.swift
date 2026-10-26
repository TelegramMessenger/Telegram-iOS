import Foundation
import UIKit
import RichTextEditorUIKit
import RichTextButtonIcons

private func richTextFontSpec(_ attributes: InstantPageTextAttributes) -> RichTextFontSpec {
    let style: RichTextFontStyle
    switch attributes.font.style {
    case .sans:      style = .sans
    case .serif:     style = .serif
    case .monospace: style = .monospace
    }
    let weight: RichTextFontWeight
    switch attributes.font.weight {
    case .regular:  weight = .regular
    case .medium:   weight = .medium
    case .semibold: weight = .semibold
    }
    return RichTextFontSpec(style: style, size: attributes.font.size,
                            lineSpacingFactor: attributes.font.lineSpacingFactor, weight: weight)
}

@available(iOS 13.0, *)
public extension InstantPageTheme {
    /// This theme's fonts and block rhythm, in the shape the rich-text editor lays text out with — so
    /// an editor host can hand the editor the exact numbers the V2 renderer will use for the same
    /// content.
    ///
    /// The heading ladder comes from `headingTextAttributes(level:link:)` rather than being restated,
    /// so H1–H6's scaling by the theme's `fontSizeMultiplier` (the reader's slider, the chat's Text Size)
    /// is shared rather than duplicated. The block scalars come from `InstantPageMetrics.unscaled`, the
    /// same source the renderer reads at page scale — this projection is of the UNSCALED page; the
    /// editor hosts do not follow Text Size today (see docs/instantpage-richtext.md, "Text Size").
    ///
    /// `codeBlock` reports the metrics' `codeBlockFontSize` (15 at page scale), because that — not the
    /// theme's `codeBlock` category — is what `layoutCodeBlock` sizes code from. The chat table declares
    /// 15 too; the Instant View themes still say 14, a size V2 never draws.
    func richTextRenderMetrics(edgeSpacingReduction: CGFloat = 0.0) -> RichTextRenderMetrics {
        let m = InstantPageMetrics.unscaled
        var codeBlock = richTextFontSpec(self.textCategories.codeBlock)
        codeBlock.size = m.codeBlockFontSize
        return RichTextRenderMetrics(
            heading1: richTextFontSpec(self.headingTextAttributes(level: 1, link: false)),
            heading2: richTextFontSpec(self.headingTextAttributes(level: 2, link: false)),
            heading3: richTextFontSpec(self.headingTextAttributes(level: 3, link: false)),
            heading4: richTextFontSpec(self.headingTextAttributes(level: 4, link: false)),
            heading5: richTextFontSpec(self.headingTextAttributes(level: 5, link: false)),
            heading6: richTextFontSpec(self.headingTextAttributes(level: 6, link: false)),
            body: richTextFontSpec(self.textCategories.paragraph),
            caption: richTextFontSpec(self.textCategories.caption),
            table: richTextFontSpec(self.textCategories.table),
            codeBlock: codeBlock,
            baseBlockSpacing: m.baseBlockSpacing,
            blockVerticalPadding: m.blockVerticalPadding,
            headingVerticalPadding: m.headingVerticalPadding,
            dividerVerticalPadding: m.dividerVerticalPadding,
            detailsAdjacentSpacing: m.detailsAdjacentSpacing,
            edgeSpacingReduction: edgeSpacingReduction,
            // Sourced from the renderer's own metrics, so the editor cannot drift from what it will
            // render as — the same arrangement as `button:` below.
            code: RichTextCodeMetrics(
                verticalInset: m.codeBlockVerticalInset,
                languageSpacing: m.codeBlockLanguageSpacing),
            // Sourced from the renderer's OWN constants rather than from `RichTextButtonMetrics.default`,
            // so the article editor cannot drift from what it will render as. The composer, which cannot
            // import this module, gets the pinned default instead — `RichTextV2ButtonParityTests` asserts
            // the two are equal.
            button: RichTextButtonMetrics(
                inlineFontSize: instantPageInlineButtonFontSize,
                blockFontSize: instantPageBlockButtonFontSize,
                inlineHorizontalPadding: instantPageInlineButtonHorizontalPadding,
                blockHorizontalPadding: instantPageBlockButtonHorizontalPadding,
                blockMinimumHorizontalPadding: instantPageBlockButtonMinimumHorizontalPadding,
                verticalPadding: instantPageInlineButtonVerticalPadding,
                adjacentSpacing: instantPageInlineButtonAdjacentSpacing,
                blockRowHeight: instantPageBlockButtonHeight,
                blockSpacing: instantPageBlockButtonSpacing,
                blockIconReserve: richTextBlockButtonIconReserve,
                inlineIconReserve: richTextInlineButtonIconReserve,
                blockIconInset: richTextBlockButtonIconInset,
                maximumButtonsPerRow: instantPageBlockButtonsPerRow
            )
        )
    }

    /// A chat-message theme with plain colours. Colours play no part in geometry, so this exists so a
    /// caller that only wants the METRICS (an editor host, a parity test) does not have to assemble a
    /// fully themed instance from presentation data it may not have.
    static func chatMessageGeometryTheme() -> InstantPageTheme {
        return InstantPageTheme(
            type: .light,
            pageBackgroundColor: .clear,
            textCategories: .chatMessage(primaryText: .black, secondaryText: .gray),
            serif: false,
            codeBlockBackgroundColor: .clear,
            linkColor: .blue,
            textHighlightColor: .clear,
            linkHighlightColor: .clear,
            markerColor: .clear,
            panelBackgroundColor: .clear,
            panelHighlightedBackgroundColor: .clear,
            panelPrimaryColor: .black,
            panelSecondaryColor: .gray,
            panelAccentColor: .blue,
            tableBorderColor: .clear,
            tableHeaderColor: .clear,
            controlColor: .blue,
            imageTintColor: nil,
            overlayPanelColor: .clear,
            separatorColor: .clear,
            secondaryControlColor: .clear,
            quoteAccentColor: .blue
        )
    }

    /// The render metrics a rich message lays out with in a chat bubble — what an author composing one
    /// should see. This is what both editor hosts pass.
    static func chatMessageRenderMetrics(edgeSpacingReduction: CGFloat = 0.0) -> RichTextRenderMetrics {
        return chatMessageGeometryTheme().richTextRenderMetrics(edgeSpacingReduction: edgeSpacingReduction)
    }
}
