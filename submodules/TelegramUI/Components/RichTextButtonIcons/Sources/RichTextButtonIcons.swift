import Foundation
import UIKit
import Display
import AppBundle
import TelegramCore

/// The type icon a button pill carries — the same asset set and the same action → icon mapping as a
/// bot keyboard button (`ChatMessageActionButtonsNode.swift:262-306`), so a `pageBlockButtonRow`, an
/// inline `RichText.textButton` and a reply-markup row all read alike.
///
/// This lives in its own module rather than in `InstantPageUI` because BOTH the V2 renderer and the
/// rich-text editor draw these, and the editor's host (`ChatRichTextEditorComposer`) cannot import
/// `InstantPageUI` — that edge is a cycle, since `InstantPageUI` already depends on the composer
/// (`InstantPageUI/BUILD`). A leaf module both sides can reach is the only shape that works, and it
/// keeps the mapping single-sourced.
///
/// Two deliberate differences from the keyboard mapping:
/// - `.url` cannot be resolved into an app / attach-bot link here. That test needs an
///   `AccountContext`, which neither surface is handed; a bare `?startgroup=` check is all that
///   survives, so app links get the plain link icon.
/// - `.openWebApp` gets the web-app icon. The keyboard path leaves it iconless, but only because its
///   switch predates the case — the icon is unambiguous.
///
/// Actions absent here are iconless by intent: `.callback` (nothing to promise the user),
/// `.requestPeer` / `.setupPoll` (keyboard-only, unreachable from `Api.InlineButtonType`), and
/// `.disabled`, which must read as inert.
public func richTextButtonIconName(for action: ReplyMarkupButtonAction) -> String? {
    switch action {
    case .text:
        return "Chat/Message/BotMessage"
    case let .url(value):
        if value.lowercased().contains("?startgroup=") {
            return "Chat/Message/BotAddToChat"
        }
        return "Chat/Message/BotLink"
    case .urlAuth:
        return "Chat/Message/BotLink"
    case .requestPhone:
        return "Chat/Message/BotPhone"
    case .requestMap:
        return "Chat/Message/BotLocation"
    case .switchInline:
        return "Chat/Message/BotShare"
    case .payment:
        return "Chat/Message/BotPayment"
    case .openUserProfile:
        return "Chat/Message/BotProfile"
    case .openWebView, .openWebApp:
        return "Chat/Message/BotWebApp"
    case .copyText:
        return "Chat/Message/BotCopy"
    default:
        return nil
    }
}

/// The icon's own size, shared by both placements. The assets are 10x10 vectors rasterised at that
/// natural size (no `preserves-vector-representation`), so this is also the largest size that draws
/// without softening; the keyboard path draws them into a 12x12 node with `contentMode = .center`,
/// which comes to the same ink.
public let richTextButtonIconSize = CGSize(width: 10.0, height: 10.0)

// MARK: - Block placement (a corner badge)

/// Distance from a BLOCK pill's top-right corner. Larger than the keyboard button's 4pt because a pill
/// is fully rounded (`cornerRadius = height / 2`) rather than a rounded rect: at these insets the whole
/// badge box stays inside the arc on a 40pt-tall pill, where the keyboard button's own 4/4 would put
/// the badge's outer corner past it and `clipsToBounds` would shave it.
public let richTextBlockButtonIconInset = CGPoint(x: 8.0, y: 6.0)

/// Horizontal room a badge-bearing BLOCK pill must keep clear on *each* side, so a centred label cannot
/// run under the badge. Mirrors the keyboard path's `minimumSideInset` (`4.0 + iconWidth`).
public let richTextBlockButtonIconReserve: CGFloat = richTextButtonIconSize.width + richTextBlockButtonIconInset.x

// MARK: - Inline placement (trailing the label)

/// Gap between an INLINE pill's label ink and the leading edge of its icon box.
///
/// An inline pill is far too short to carry a corner badge — its height is the label's ink box plus
/// 2pt — so the icon sits after the label instead, on the same optical line, and the pill simply grows
/// to hold it. The icon's trailing edge then lands on the pill's ordinary horizontal padding, exactly
/// where the label's would have.
public let richTextInlineButtonIconSpacing: CGFloat = 4.0

/// Width an icon-bearing INLINE pill adds to its own box: the gap plus the icon.
///
/// Unlike `richTextBlockButtonIconReserve`, which is a side inset that only binds in the row layout's
/// tight fallback, this is unconditional — it widens the pill, and therefore moves the line break of
/// the paragraph the pill sits in. That is why the editor must reserve the identical amount
/// (`RichTextButtonMetrics.inlineIconReserve`) even where it resolves no image.
public let richTextInlineButtonIconReserve: CGFloat = richTextButtonIconSize.width + richTextInlineButtonIconSpacing

// MARK: - Rasterisation

/// Tinted icon for `action`, or nil when the action has none.
///
/// Rasterises on every call rather than caching: the keyboard path pre-generates these per theme in
/// `PresentationThemeEssentialGraphics`, which neither surface has an equivalent of, and a 10x10 tint
/// is far cheaper than the global mutable cache it would take to avoid.
public func richTextButtonIcon(for action: ReplyMarkupButtonAction, color: UIColor) -> UIImage? {
    guard let name = richTextButtonIconName(for: action) else {
        return nil
    }
    return generateTintedImage(image: UIImage(bundleImageName: name), color: color)
}
