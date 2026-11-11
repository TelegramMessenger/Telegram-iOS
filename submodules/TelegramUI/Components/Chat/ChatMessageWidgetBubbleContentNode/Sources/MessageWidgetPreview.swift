import Foundation
import UIKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ChatMessageItemCommon
import MessageWidget

/// widget-sandbox v0.2 (sdk-v1 §2.16; design W3): the inline result to preview as a widget; nil for any other result,
/// and while widgets are off (the kill switch), when the result draws as any other result does.
public func messageWidgetPreviewWidget(_ message: ChatContextResultMessage, renderingEnabled: Bool) -> TelegramMediaWidget? {
    guard renderingEnabled, case let .widget(media, _, _, _) = message else {
        return nil
    }
    return media
}

/// A preview's theme: the chat's outgoing bubble, which the sent result will be in.
public func messageWidgetPreviewTheme(theme: PresentationTheme, wallpaper: TelegramWallpaper, fontSize: PresentationFontSize) -> MessageWidgetInstance.Theme {
    return messageWidgetTheme(theme: theme, wallpaper: wallpaper, incoming: false, fontSize: fontSize, textInsets: ChatMessageItemLayoutConstants.compact.text.bubbleInsets)
}

/// The size of an inline result's widget preview (sdk-v1 §2.16: "draw the same first state a sent widget would draw").
public enum MessageWidgetPreviewLayout {
    /// The tallest a results row draws a widget; a taller one is scaled down to it (the user, 2026-10-27).
    public static let maximumListHeight: CGFloat = 240.0

    /// The widget as its sent bubble lays it out `availableWidth` wide: the anchors' width rule, and its height (fixed;
    /// else the reported one; else the 160 pt placeholder), clamped as the bubble clamps them.
    public static func contentSize(anchors: MessageWidgetAnchors, availableWidth: CGFloat, reportedHeight: CGFloat?) -> CGSize {
        return CGSize(width: MessageWidgetBubbleSize.width(anchors: anchors, maximumWidth: availableWidth), height: MessageWidgetBubbleSize.height(anchors: anchors, reported: reportedHeight, cached: nil))
    }

    /// `content` scaled down, never up, to fit `bounds`: the drawn size and its scale.
    public static func fitted(_ content: CGSize, in bounds: CGSize) -> (size: CGSize, scale: CGFloat) {
        guard content.width > 0.0, content.height > 0.0 else {
            return (CGSize(), 1.0)
        }
        let scale = min(1.0, bounds.width / content.width, bounds.height / content.height)
        return (CGSize(width: content.width * scale, height: content.height * scale), scale)
    }
}
