import XCTest
import UIKit
import Display
import TelegramCore
import TelegramUIPreferences
@testable import InstantPageUI

/// A pressed pill shows `instantPageButtonHighlightedFill(...)`. A plain pill keeps the host's
/// `panelHighlightedBackgroundColor` (in a chat bubble, the accent colour), but a coloured one must be
/// a shade of its own fill: before, a red `danger` pill turned blue under the finger.
final class InstantPageButtonHighlightTests: XCTestCase {
    private let accentHighlight = UIColor(rgb: 0x007aff).withMultipliedAlpha(0.8)
    private let danger = UIColor(rgb: 0xff3b30)
    private let success = UIColor(rgb: 0x34c759)
    private let primary = UIColor(rgb: 0x007aff)

    /// The colours `ChatMessageRichDataBubbleContentNode` hands the renderer: an incoming bubble tints
    /// `danger`/`success` at 15%, an outgoing one fills them solid; `primary` is solid in both, and in an
    /// outgoing bubble it is the theme's `accentControlColor` (white in Night), which `primaryFill` stands in for.
    private func theme(isDark: Bool, isIncoming: Bool, primaryFill: UIColor? = nil) -> InstantPageTheme {
        return InstantPageTheme(
            type: isDark ? .dark : .light,
            pageBackgroundColor: .clear,
            textCategories: .chatMessage(primaryText: .black, secondaryText: .gray),
            serif: false,
            codeBlockBackgroundColor: .clear,
            linkColor: .blue,
            textHighlightColor: .clear,
            linkHighlightColor: .clear,
            markerColor: .clear,
            panelBackgroundColor: UIColor(rgb: 0x007aff).withMultipliedAlpha(0.1),
            panelHighlightedBackgroundColor: self.accentHighlight,
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
            quoteAccentColor: .blue,
            buttonDangerBackgroundColor: isIncoming ? self.danger.withMultipliedAlpha(0.15) : self.danger,
            buttonDangerForegroundColor: isIncoming ? self.danger : .white,
            buttonSuccessBackgroundColor: isIncoming ? self.success.withMultipliedAlpha(0.15) : self.success,
            buttonSuccessForegroundColor: isIncoming ? self.success : .white,
            checkboxFill: primaryFill ?? self.primary,
            checkboxForeground: .white
        )
    }

    private func rgba(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
        XCTAssertTrue(color.getRed(&r, green: &g, blue: &b, alpha: &a))
        return (r, g, b, a)
    }

    private func luminance(_ color: UIColor) -> CGFloat {
        let c = self.rgba(color)
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
    }

    private let styles: [ReplyMarkupButton.Style.Color] = [.primary, .danger, .success]

    // MARK: - Plain pills are unchanged

    func testAPlainPillKeepsThePanelHighlight() {
        for isDark in [false, true] {
            for isIncoming in [false, true] {
                for isInline in [false, true] {
                    let theme = self.theme(isDark: isDark, isIncoming: isIncoming)
                    XCTAssertEqual(instantPageButtonHighlightedFill(nil, theme: theme, isInline: isInline), self.accentHighlight)
                }
            }
        }
    }

    func testALinkStyledPillKeepsThePanelHighlight() {
        let theme = self.theme(isDark: false, isIncoming: true)
        XCTAssertEqual(instantPageButtonHighlightedFill(.danger, theme: theme, isInline: false, isLink: true), self.accentHighlight)
    }

    // MARK: - Coloured pills highlight in their own colour

    /// A 15% tint deepens: the same colour, at twice the opacity.
    func testATintedPillDeepensItsOwnTint() {
        let theme = self.theme(isDark: false, isIncoming: true)
        for style in [ReplyMarkupButton.Style.Color.danger, .success] {
            let fill = instantPageButtonColors(style, theme: theme, isInline: false, isDisabled: false).fill
            let highlighted = self.rgba(instantPageButtonHighlightedFill(style, theme: theme, isInline: false))
            let base = self.rgba(fill)
            XCTAssertEqual(highlighted.r, base.r, accuracy: 0.001)
            XCTAssertEqual(highlighted.g, base.g, accuracy: 0.001)
            XCTAssertEqual(highlighted.b, base.b, accuracy: 0.001)
            XCTAssertEqual(highlighted.a, base.a * 2.0, accuracy: 0.001)
        }
    }

    /// A solid fill stays opaque and goes darker in a light theme...
    func testASolidPillDarkensInALightTheme() {
        let theme = self.theme(isDark: false, isIncoming: false)
        for style in self.styles {
            let fill = instantPageButtonColors(style, theme: theme, isInline: false, isDisabled: false).fill
            let highlighted = instantPageButtonHighlightedFill(style, theme: theme, isInline: false)
            XCTAssertEqual(self.rgba(highlighted).a, 1.0, accuracy: 0.001)
            XCTAssertLessThan(self.luminance(highlighted), self.luminance(fill) - 0.05)
        }
    }

    /// ...and lighter in a dark one, where a darker shade would sink into the bubble.
    func testASolidPillLightensInADarkTheme() {
        let theme = self.theme(isDark: true, isIncoming: false)
        for style in self.styles {
            let fill = instantPageButtonColors(style, theme: theme, isInline: false, isDisabled: false).fill
            let highlighted = instantPageButtonHighlightedFill(style, theme: theme, isInline: false)
            XCTAssertEqual(self.rgba(highlighted).a, 1.0, accuracy: 0.001)
            XCTAssertGreaterThan(self.luminance(highlighted), self.luminance(fill) + 0.05)
        }
    }

    /// A fill already at the theme's end goes the other way, or pressing would not change it: Night's
    /// outgoing `primary` pill is white, and lightening white is white.
    func testAWhitePillDarkensEvenInADarkTheme() {
        let theme = self.theme(isDark: true, isIncoming: false, primaryFill: .white)
        let highlighted = instantPageButtonHighlightedFill(.primary, theme: theme, isInline: false)
        XCTAssertEqual(self.rgba(highlighted).a, 1.0, accuracy: 0.001)
        XCTAssertLessThan(self.luminance(highlighted), self.luminance(.white) - 0.05)
    }

    func testANearBlackPillLightensEvenInALightTheme() {
        let fill = UIColor(rgb: 0x101010)
        let theme = self.theme(isDark: false, isIncoming: false, primaryFill: fill)
        let highlighted = instantPageButtonHighlightedFill(.primary, theme: theme, isInline: false)
        XCTAssertGreaterThan(self.luminance(highlighted), self.luminance(fill) + 0.05)
    }

    /// Doubling the opacity of a nearly opaque fill would barely change it, so it shades instead.
    func testANearlyOpaquePillShadesInsteadOfDoublingItsOpacity() {
        let fill = self.primary.withMultipliedAlpha(0.9)
        let theme = self.theme(isDark: false, isIncoming: false, primaryFill: fill)
        let highlighted = instantPageButtonHighlightedFill(.primary, theme: theme, isInline: false)
        XCTAssertLessThan(self.luminance(highlighted), self.luminance(fill) - 0.05)
    }

    /// The bug itself: no coloured pill, in any bubble or theme, highlights in the accent colour.
    func testNoColouredPillHighlightsInTheAccentColour() {
        for isDark in [false, true] {
            for isIncoming in [false, true] {
                for isInline in [false, true] {
                    let theme = self.theme(isDark: isDark, isIncoming: isIncoming)
                    for style in self.styles {
                        XCTAssertNotEqual(instantPageButtonHighlightedFill(style, theme: theme, isInline: isInline), self.accentHighlight)
                    }
                }
            }
        }
    }
}
