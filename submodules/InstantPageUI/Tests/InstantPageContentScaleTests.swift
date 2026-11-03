import XCTest
import UIKit
import Display
import TelegramUIPreferences
import TelegramPresentationData
@testable import InstantPageUI

/// A rich message in a chat bubble follows Settings ▸ Appearance ▸ Text Size (bugs.telegram.org/c/62776).
/// The bubble expresses the setting as ONE content scale, `baseDisplaySize / 17`, which the renderer applies
/// once to the theme's fonts and once to `InstantPageMetrics`. These tests pin the rounding contract that
/// makes the fractional scale safe: fonts land on whole points, and the three "one step below body"
/// sizes — table, code, quote body — stay equal at every step.
///
/// Anything asserting pixel-grid behaviour passes `screenScale: 3.0` explicitly. Measured 2026-09-22: this
/// test process reports `UIScreen.main.scale == 1.0`, so a default-grid `floorToScreenPixels` IS a plain
/// `floor` here and an assertion that "the snap differs from the floor" can never fail.
final class InstantPageContentScaleTests: XCTestCase {
    /// The seven Text Size steps, as the scale the bubble derives from them. `.regular` is exactly 1.0.
    private static let stepScales: [CGFloat] = PresentationFontSize.allCases.map { $0.baseDisplaySize / 17.0 }

    private static let quoteScale = InstantPageMetrics.quoteScale

    /// The one derivation every chat surface uses: `.regular` is exactly 1.0, other steps are their ratio to 17.
    func testChatMessageContentScaleIsTheRatioToTheAuthoredSize() {
        XCTAssertEqual(instantPageChatMessageContentScale(baseFontSize: 17.0), 1.0)
        XCTAssertEqual(instantPageChatMessageContentScale(baseFontSize: 19.0), 19.0 / 17.0)
        for step in PresentationFontSize.allCases {
            XCTAssertEqual(instantPageChatMessageContentScale(baseFontSize: step.baseDisplaySize), step.baseDisplaySize / 17.0)
        }
    }

    // MARK: Code = table = quote body

    /// The chat-message table says what the renderer actually draws. Code was declared 14pt and overridden
    /// to 15 at layout time, so the table lied about the one category the editor host also reads.
    func testChatMessageCodeBlockCategoryIsOneStepBelowBodyLikeTable() {
        let categories = InstantPageTheme.chatMessageGeometryTheme().textCategories
        XCTAssertEqual(categories.codeBlock.font.size, 15.0)
        XCTAssertEqual(categories.codeBlock.font.size, categories.table.font.size)
        XCTAssertEqual(categories.codeBlock.font.style, .monospace)
    }

    /// Code, table and quote body are one typographic step below the paragraph, and remain equal at every
    /// Text Size step AND inside a quote at every step. Code rides `InstantPageMetrics`, so it must take
    /// the fonts' whole-point floor, not the pixel-grid snap the geometry constants take — otherwise it
    /// drifts to 16.67pt at `.large` while the table sits at 16.
    func testCodeFontEqualsTableAndQuoteBodyAtEveryStep() {
        let base = InstantPageTheme.chatMessageGeometryTheme()
        var scales = Self.stepScales
        scales.append(contentsOf: Self.stepScales.map { $0 * Self.quoteScale })

        for scale in scales {
            // Pinned to 3x: at 1x a pixel snap IS a floor and the assertion cannot fail.
            let metrics = InstantPageMetrics(scale: scale, screenScale: 3.0)
            let scaledTheme = base.withUpdatedFontStyles(sizeMultiplier: scale, lineSpacingFactor: 1.0, forceSerif: false)
            let quoteBody = base.withUpdatedFontStyles(sizeMultiplier: scale * Self.quoteScale, lineSpacingFactor: 1.0, forceSerif: false).textCategories.paragraph

            XCTAssertEqual(metrics.codeBlockFontSize, floor(15.0 * scale), "code is whole points at scale \(scale)")
            XCTAssertEqual(metrics.codeBlockFontSize, scaledTheme.textCategories.table.font.size, "code == table at scale \(scale)")
            XCTAssertEqual(metrics.codeBlockFontSize, quoteBody.font.size, "code == quote body at scale \(scale)")
        }
    }

    // MARK: Heading ladder

    /// The H1–H6 ladder must scale by the multiplier that was actually applied, not by a ratio recovered
    /// from the already-floored subheader. At `.large` the recovered ratio is 24/22 = 1.091 instead of
    /// 19/17 = 1.118, which lands H2 on 21 where floor(20 × 19/17) is 22.
    func testHeadingLadderScalesByTheAppliedMultiplierNotTheRoundedSubheader() {
        let scale: CGFloat = 19.0 / 17.0
        let theme = InstantPageTheme.chatMessageGeometryTheme().withUpdatedFontStyles(sizeMultiplier: scale, lineSpacingFactor: 1.0, forceSerif: false)

        let ladder = (1...6).map { theme.headingTextAttributes(level: Int32($0), link: false).font.size }
        let expected: [CGFloat] = [22.0, 20.0, 18.0, 17.0, 16.0, 15.0].map { floor($0 * scale) }
        XCTAssertEqual(ladder, expected)
        XCTAssertEqual(ladder[1], 22.0)
    }

    // MARK: One scale, applied once

    /// The layout derives page theme, page metrics, quote theme and quote metrics from the BASE theme
    /// and one product each. At `.large`: paragraph 19, code 16, quote body floor(17 × 19/17 × 15/17) = 16,
    /// quote code 14 — and the quote theme records the product, not the quote scale alone.
    func testScaledLayoutInputsApplyTheContentScaleOnceToFontsAndGeometry() {
        let base = InstantPageTheme.chatMessageGeometryTheme()
        let scale: CGFloat = 19.0 / 17.0
        let inputs = InstantPageV2ScaledLayoutInputs(baseTheme: base, contentScale: scale, screenScale: 3.0)

        XCTAssertEqual(inputs.theme.textCategories.paragraph.font.size, 19.0)
        XCTAssertEqual(inputs.theme.fontSizeMultiplier, scale)
        XCTAssertEqual(inputs.metrics.codeBlockFontSize, 16.0)
        // 18 × 19/17 = 20.12 → 20.0 on a 3x grid (and 20.0 as a plain floor, so the second constant is
        // the one that tells the grid from the floor: 9 × 19/17 × 15/17 = 8.87 → 8.67 on 3x, 8 floored).
        XCTAssertEqual(inputs.metrics.checklistMarkerSize.width, floor(18.0 * scale * 3.0) / 3.0)

        XCTAssertEqual(inputs.quoteTheme.textCategories.paragraph.font.size, 16.0)
        XCTAssertEqual(inputs.quoteTheme.fontSizeMultiplier, scale * Self.quoteScale, accuracy: 1e-12)
        XCTAssertEqual(inputs.quoteMetrics.codeBlockFontSize, 14.0)
        XCTAssertEqual(inputs.quoteMetrics.quoteLeadingInset, floor(9.0 * scale * Self.quoteScale * 3.0) / 3.0)
        XCTAssertEqual(inputs.quoteMetrics.quoteLeadingInset, 26.0 / 3.0, accuracy: 1e-9)
    }

    /// At scale 1.0 the inputs are today's: the base theme's sizes, `.unscaled`, and the quote pair at
    /// the bare quote scale. Every non-chat V2 surface relies on this.
    func testScaledLayoutInputsAtScaleOneAreTodays() {
        let base = InstantPageTheme.chatMessageGeometryTheme()
        let inputs = InstantPageV2ScaledLayoutInputs(baseTheme: base, contentScale: 1.0)

        XCTAssertEqual(inputs.theme.fontSizeMultiplier, 1.0)
        XCTAssertEqual(inputs.theme.textCategories.paragraph.font.size, base.textCategories.paragraph.font.size)
        XCTAssertEqual(inputs.theme.textCategories.header.font.size, base.textCategories.header.font.size)
        XCTAssertEqual(inputs.theme.textCategories.codeBlock.font.style, base.textCategories.codeBlock.font.style)
        XCTAssertEqual(inputs.metrics.codeBlockFontSize, InstantPageMetrics.unscaled.codeBlockFontSize)
        XCTAssertEqual(inputs.metrics.tableCellInsets, InstantPageMetrics.unscaled.tableCellInsets)
        XCTAssertEqual(inputs.quoteTheme.textCategories.paragraph.font.size, 15.0)
        XCTAssertEqual(inputs.quoteMetrics.codeBlockFontSize, InstantPageMetrics(scale: Self.quoteScale).codeBlockFontSize)
    }

    /// The full-page Instant View reader's own font-size slider goes through the same `withUpdatedFontStyles`,
    /// so its H1–H6 ladder now scales by the multiplier that scaled its body — not by the ratio recovered from
    /// the floored subheader, which moved headings by a point at every non-standard reader size. This is a
    /// deliberate behaviour change for those readers (e.g. `.large` = 1.15: H2 was floor(20 × 25/22) = 22, is
    /// floor(20 × 1.15) = 23), pinned here so it is a decision and not a side effect.
    func testInstantViewReaderLadderScalesWithItsBodyAtEveryReaderSize() {
        let variants: [InstantPagePresentationFontSize] = [.xxsmall, .xsmall, .small, .standard, .large, .xlarge, .xxlarge]
        for variant in variants {
            let settings = InstantPagePresentationSettings(themeType: .light, fontSize: variant, lineSpacingFactor: 1.0, forceSerif: false, autoNightMode: false, ignoreAutoNightModeUntil: 0)
            let theme = instantPageThemeForType(.light, settings: settings)
            let multiplier = theme.fontSizeMultiplier

            XCTAssertEqual(theme.textCategories.paragraph.font.size, floor(17.0 * multiplier), "body at \(variant)")
            let ladder = (1...6).map { theme.headingTextAttributes(level: Int32($0), link: false).font.size }
            XCTAssertEqual(ladder, [22.0, 20.0, 18.0, 17.0, 16.0, 15.0].map { floor($0 * multiplier) }, "ladder at \(variant)")
        }

        let large = instantPageThemeForType(.light, settings: InstantPagePresentationSettings(themeType: .light, fontSize: .large, lineSpacingFactor: 1.0, forceSerif: false, autoNightMode: false, ignoreAutoNightModeUntil: 0))
        XCTAssertEqual(large.fontSizeMultiplier, 1.15)
        XCTAssertEqual(large.headingTextAttributes(level: 2, link: false).font.size, 23.0)
    }

    /// At the regular step nothing may move: the ladder is exactly its authored base sizes.
    func testHeadingLadderIsUnchangedAtScaleOne() {
        let theme = InstantPageTheme.chatMessageGeometryTheme()
        let ladder = (1...6).map { theme.headingTextAttributes(level: Int32($0), link: false).font.size }
        XCTAssertEqual(ladder, [22.0, 20.0, 18.0, 17.0, 16.0, 15.0])
    }
}
