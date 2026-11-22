import XCTest
import UIKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ChatMessageItemCommon
import MessageWidget
@testable import ChatMessageWidgetBubbleContentNode

/// SDK v1 §2.3, §2.4 and §5.1 (V2b plan, Task 7; v0.1.1 plan, Task 5): the widget's theme from the chat's bubble the
/// widget sits in, incoming or outgoing.
final class MessageWidgetChatThemeTests: XCTestCase {
    private let keys = ["bg_color", "text_color", "hint_color", "link_color", "button_color", "button_text_color", "secondary_bg_color",
                        "accent_text_color", "subtitle_text_color", "destructive_text_color", "section_bg_color",
                        "section_header_text_color", "section_separator_color", "header_bg_color", "bottom_bar_bg_color"]

    private func widgetTheme(_ theme: PresentationTheme, _ wallpaper: TelegramWallpaper, incoming: Bool = true) -> MessageWidgetInstance.Theme {
        return messageWidgetTheme(theme: theme, wallpaper: wallpaper, incoming: incoming, fontSize: .regular, textInsets: ChatMessageItemLayoutConstants.compact.text.bubbleInsets)
    }

    /// The day theme with a two-colour outgoing bubble.
    private let gradientTheme = customizeDefaultDayTheme(theme: makeDefaultDayPresentationTheme(serviceBackgroundColor: nil, day: true, preview: false), editing: false, title: nil, accentColor: UIColor(rgb: 0x0088ff), outgoingAccentColor: nil, backgroundColors: [], bubbleColors: [0xff0000, 0x0000ff], animateBubbleColors: false, serviceBackgroundColor: nil)

    /// The colours' mean, channel by channel, alpha included (the dark theme's incoming bubble is translucent).
    private func average(_ colors: [UIColor]) -> UIColor {
        var sum: (CGFloat, CGFloat, CGFloat, CGFloat) = (0.0, 0.0, 0.0, 0.0)
        for color in colors {
            var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            sum = (sum.0 + r, sum.1 + g, sum.2 + b, sum.3 + a)
        }
        let count = CGFloat(colors.count)
        return UIColor(red: sum.0 / count, green: sum.1 / count, blue: sum.2 / count, alpha: sum.3 / count)
    }

    /// WCAG's contrast ratio of two opaque `#rrggbb` colours.
    private func contrast(_ first: String, _ second: String) -> CGFloat {
        let luminance: (String) -> CGFloat = { hex in
            let value = Int(hex.dropFirst(), radix: 16) ?? 0
            let channel: (Int) -> CGFloat = { shift in
                let c = CGFloat((value >> shift) & 0xff) / 255.0
                return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
        }
        let (a, b) = (luminance(first), luminance(second))
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    func testEveryKeyIsPresentAndHex() {
        for (theme, scheme) in [(defaultPresentationTheme, MessageWidgetInstance.Theme.ColorScheme.light), (defaultDarkPresentationTheme, .dark)] {
            let widgetTheme = self.widgetTheme(theme, .builtin(WallpaperSettings()))
            XCTAssertEqual(widgetTheme.colorScheme, scheme)
            XCTAssertEqual(Set(widgetTheme.params.keys), Set(self.keys))
            for (key, value) in widgetTheme.params {
                XCTAssertNotNil(value.range(of: "^#[0-9a-f]{6}$", options: .regularExpression), "\(key) \(value)")
            }
        }
    }

    func testTheBackgroundIsTheIncomingBubble() {
        let wallpaper = TelegramWallpaper.color(0x88aacc)
        let fill = bubbleColorComponents(theme: defaultPresentationTheme, incoming: true, wallpaper: true).fill.first!
        let widgetTheme = self.widgetTheme(defaultPresentationTheme, wallpaper)
        XCTAssertEqual(widgetTheme.params["bg_color"], messageWidgetHex(messageWidgetComposite(fill, alpha: 1.0, over: .white)))
    }

    /// A colour with alpha is composited over the bubble: half black over white is #808080.
    func testAlphaIsComposited() {
        XCTAssertEqual(messageWidgetHex(messageWidgetComposite(UIColor(white: 0.0, alpha: 0.5), alpha: 1.0, over: .white)), "#808080")
        XCTAssertEqual(messageWidgetHex(messageWidgetComposite(UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0), alpha: 0.25, over: .black)), "#400000")
    }

    func testTheButtonTokensAreSolid() {
        let widgetTheme = self.widgetTheme(defaultPresentationTheme, .builtin(WallpaperSettings()))
        XCTAssertEqual(widgetTheme.button.bg, widgetTheme.params["button_color"])
        XCTAssertEqual(widgetTheme.button.text, widgetTheme.params["button_text_color"])
        XCTAssertNil(widgetTheme.button.radius)
        XCTAssertNil(widgetTheme.button.font)
    }

    /// SDK v1 §2.3 and §5.1 (v0.1.1): the palette is the bubble the widget sits in. An outgoing bubble (a widget the user
    /// sent or forwarded) passes its own fill, text, hint, link and accent, not the incoming ones.
    func testEachSideIsItsOwnBubble() {
        let wallpaper = TelegramWallpaper.builtin(WallpaperSettings())
        for theme in [defaultPresentationTheme, defaultDarkPresentationTheme] {
            for incoming in [true, false] {
                let message = incoming ? theme.chat.message.incoming : theme.chat.message.outgoing
                let base: UIColor = theme.overallDarkAppearance ? .black : .white
                let fill = bubbleColorComponents(theme: theme, incoming: incoming, wallpaper: !wallpaper.isEmpty).fill
                let background = messageWidgetComposite(self.average(fill), alpha: 1.0, over: base)
                let hex: (UIColor) -> String = { messageWidgetHex(messageWidgetComposite($0, alpha: 1.0, over: background)) }
                let params = self.widgetTheme(theme, wallpaper, incoming: incoming).params
                XCTAssertEqual(params["bg_color"], messageWidgetHex(background))
                XCTAssertEqual(params["text_color"], hex(message.primaryTextColor))
                XCTAssertEqual(params["hint_color"], hex(message.secondaryTextColor))
                XCTAssertEqual(params["link_color"], hex(message.linkTextColor))
                XCTAssertEqual(params["accent_text_color"], hex(message.accentTextColor))
            }
            XCTAssertNotEqual(self.widgetTheme(theme, wallpaper, incoming: true).params["bg_color"], self.widgetTheme(theme, wallpaper, incoming: false).params["bg_color"])
        }
    }

    /// R3: a gradient bubble has no single colour; it passes the average of its fill colours.
    func testAGradientBubbleIsItsAverage() {
        let wallpaper = TelegramWallpaper.builtin(WallpaperSettings())
        let fill = bubbleColorComponents(theme: self.gradientTheme, incoming: false, wallpaper: !wallpaper.isEmpty).fill
        XCTAssertGreaterThan(fill.count, 1)
        XCTAssertEqual(self.widgetTheme(self.gradientTheme, wallpaper, incoming: false).params["bg_color"], messageWidgetHex(messageWidgetComposite(self.average(fill), alpha: 1.0, over: .white)))
    }

    /// The button is the bubble's own filled control on either side, so its label stays legible where the outgoing
    /// bubble's controls are white on the bubble's colour: at least 3:1, or as legible as the bubble's own text when the
    /// theme sets that lower (the night theme's outgoing gradient: white text at 2.7:1).
    func testTheButtonIsLegibleOnBothSides() throws {
        let wallpaper = TelegramWallpaper.builtin(WallpaperSettings())
        for theme in [defaultPresentationTheme, defaultDarkPresentationTheme, self.gradientTheme] {
            for incoming in [true, false] {
                let widgetTheme = self.widgetTheme(theme, wallpaper, incoming: incoming)
                let bg = try XCTUnwrap(widgetTheme.button.bg)
                let text = try XCTUnwrap(widgetTheme.button.text)
                let messageText = self.contrast(try XCTUnwrap(widgetTheme.params["text_color"]), try XCTUnwrap(widgetTheme.params["bg_color"]))
                XCTAssertGreaterThanOrEqual(self.contrast(bg, text), min(3.0, messageText), "\(theme.name) incoming \(incoming): \(bg) on \(text)")
            }
        }
    }

    /// SDK v1 §2.4 (v0.1.1): the text tokens are the chat's message text: the Text Size setting's font size, a line
    /// height of 1.3, and the text bubble's insets as the padding (6 pt above and below; 11 pt at the sides in the
    /// compact layout, 10 pt in the regular one).
    func testTheTextTokensFollowTheChat() {
        let compact = messageWidgetTheme(theme: defaultPresentationTheme, wallpaper: .builtin(WallpaperSettings()), incoming: true, fontSize: .regular, textInsets: ChatMessageItemLayoutConstants.compact.text.bubbleInsets)
        XCTAssertEqual(compact.text, MessageWidgetInstance.Theme.TextTokens(fontSize: 17.0, lineHeight: 1.3, padding: "6px 11px"))
        let regular = messageWidgetTheme(theme: defaultDarkPresentationTheme, wallpaper: .builtin(WallpaperSettings()), incoming: false, fontSize: .extraLarge, textInsets: ChatMessageItemLayoutConstants.regular.text.bubbleInsets)
        XCTAssertEqual(regular.text, MessageWidgetInstance.Theme.TextTokens(fontSize: 23.0, lineHeight: 1.3, padding: "6px 10px"))
    }
}

/// Review Focus 1 (V2b plan, Task 9): a widget shown where the message id is not the real message's own (the admin
/// log's synthetic ids, a preview) keeps its storage in memory and never writes it.
final class MessageWidgetStoragePersistsTests: XCTestCase {
    private func associatedData(isRecentActions: Bool) -> ChatMessageItemAssociatedData {
        return ChatMessageItemAssociatedData(automaticDownloadPeerType: .contact, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .wifi, isRecentActions: isRecentActions, availableReactions: nil, availableMessageEffects: nil, savedMessageTags: nil, defaultReaction: nil, areStarReactionsEnabled: false, isPremium: false, accountPeer: nil)
    }

    func testAChatMessagePersists() {
        XCTAssertTrue(messageWidgetStoragePersists(associatedData: self.associatedData(isRecentActions: false), isPreview: false))
    }

    func testTheAdminLogNeverPersists() {
        XCTAssertFalse(messageWidgetStoragePersists(associatedData: self.associatedData(isRecentActions: true), isPreview: false))
    }

    func testAPreviewNeverPersists() {
        XCTAssertFalse(messageWidgetStoragePersists(associatedData: self.associatedData(isRecentActions: false), isPreview: true))
    }
}
