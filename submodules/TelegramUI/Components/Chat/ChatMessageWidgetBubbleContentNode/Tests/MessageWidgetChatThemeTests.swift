import XCTest
import UIKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import MessageWidget
@testable import ChatMessageWidgetBubbleContentNode

/// SDK v1 §2.3, §2.4 and §5.1 (V2b plan, Task 7): the widget's theme from the chat's incoming bubble.
final class MessageWidgetChatThemeTests: XCTestCase {
    private let keys = ["bg_color", "text_color", "hint_color", "link_color", "button_color", "button_text_color", "secondary_bg_color",
                        "accent_text_color", "subtitle_text_color", "destructive_text_color", "section_bg_color",
                        "section_header_text_color", "section_separator_color", "header_bg_color", "bottom_bar_bg_color"]

    func testEveryKeyIsPresentAndHex() {
        for (theme, scheme) in [(defaultPresentationTheme, MessageWidgetInstance.Theme.ColorScheme.light), (defaultDarkPresentationTheme, .dark)] {
            let widgetTheme = messageWidgetTheme(theme: theme, wallpaper: .builtin(WallpaperSettings()))
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
        let widgetTheme = messageWidgetTheme(theme: defaultPresentationTheme, wallpaper: wallpaper)
        XCTAssertEqual(widgetTheme.params["bg_color"], messageWidgetHex(messageWidgetComposite(fill, alpha: 1.0, over: .white)))
    }

    /// A colour with alpha is composited over the bubble: half black over white is #808080.
    func testAlphaIsComposited() {
        XCTAssertEqual(messageWidgetHex(messageWidgetComposite(UIColor(white: 0.0, alpha: 0.5), alpha: 1.0, over: .white)), "#808080")
        XCTAssertEqual(messageWidgetHex(messageWidgetComposite(UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0), alpha: 0.25, over: .black)), "#400000")
    }

    func testTheButtonTokensAreSolid() {
        let widgetTheme = messageWidgetTheme(theme: defaultPresentationTheme, wallpaper: .builtin(WallpaperSettings()))
        XCTAssertEqual(widgetTheme.button.bg, widgetTheme.params["button_color"])
        XCTAssertEqual(widgetTheme.button.text, widgetTheme.params["button_text_color"])
        XCTAssertNil(widgetTheme.button.radius)
        XCTAssertNil(widgetTheme.button.font)
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
