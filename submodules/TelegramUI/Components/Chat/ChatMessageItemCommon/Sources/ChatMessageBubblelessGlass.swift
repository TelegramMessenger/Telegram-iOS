import Foundation
import CoreGraphics
import UIKit

/// Without bubbles reactions on the page are glass capsules (spec 5.5): an incoming message's, and the freeform ones
/// under stickers and media in both directions. Reactions inside your own bubble keep the bubble's plates.
public func chatMessageBubblelessReactionsAreGlass(bubbleMode: Bool, isInsideOutgoingBubble: Bool) -> Bool {
    return !bubbleMode && !isInsideOutgoingBubble
}

/// A date header without bubbles parks at the top once its stick factor reaches half way.
public func chatMessageBubblelessDateIsParked(stickDistanceFactor: CGFloat) -> Bool {
    return stickDistanceFactor >= 0.5
}

/// What a date header shows without bubbles (spec 5.7): gray text in the history; parked at the top, the date in the
/// primary text colour on a glass island, while the chat scrolls; once scrolling stops the parked date goes and takes no
/// taps.
public struct ChatMessageBubblelessDateState: Equatable {
    public var showsIsland: Bool
    public var showsHistoryLabel: Bool
    public var showsParkedLabel: Bool
    public var takesTaps: Bool

    public init(showsIsland: Bool, showsHistoryLabel: Bool, showsParkedLabel: Bool, takesTaps: Bool) {
        self.showsIsland = showsIsland
        self.showsHistoryLabel = showsHistoryLabel
        self.showsParkedLabel = showsParkedLabel
        self.takesTaps = takesTaps
    }
}

public func chatMessageBubblelessDateState(stickDistanceFactor: CGFloat, isFlashing: Bool) -> ChatMessageBubblelessDateState {
    if !chatMessageBubblelessDateIsParked(stickDistanceFactor: stickDistanceFactor) {
        return ChatMessageBubblelessDateState(showsIsland: false, showsHistoryLabel: true, showsParkedLabel: false, takesTaps: true)
    }
    return ChatMessageBubblelessDateState(showsIsland: isFlashing, showsHistoryLabel: false, showsParkedLabel: isFlashing, takesTaps: isFlashing)
}

/// Without bubbles inline buttons and the comments row are glass capsules this tall (radius half of it).
public let chatMessageBubblelessGlassCapsuleHeight: CGFloat = 42.0
/// Between glass capsules: inline buttons, and the comments row under the content.
public let chatMessageBubblelessGlassCapsuleSpacing: CGFloat = 6.0
/// A styled inline button (primary, danger, success) tints its glass with the style's colour at this alpha.
public let chatMessageBubblelessGlassTintAlpha: CGFloat = 0.85

/// Between inline buttons: glass capsules stand apart, bubble plates nearly touch.
public func chatMessageActionButtonSpacing(bubbleMode: Bool) -> CGFloat {
    return bubbleMode ? 2.0 : chatMessageBubblelessGlassCapsuleSpacing
}

/// A glass capsule has no corner for an inline button's type icon (a link, a web app): it sits in the middle of the
/// capsule's right end, concentric with it.
public func chatMessageBubblelessGlassTypeIconFrame(buttonWidth: CGFloat) -> CGRect {
    let size: CGFloat = 12.0
    let endRadius = chatMessageBubblelessGlassCapsuleHeight * 0.5
    return CGRect(x: buttonWidth - endRadius - size * 0.5, y: floor((chatMessageBubblelessGlassCapsuleHeight - size) * 0.5), width: size, height: size)
}

/// How far the centred title of a glass button with a type icon keeps from each end: clear of the icon by 4pt.
public func chatMessageBubblelessGlassTitleSideInset(iconWidth: CGFloat) -> CGFloat {
    return chatMessageBubblelessGlassCapsuleHeight * 0.5 + iconWidth * 0.5 + 4.0
}

/// The tint of an inline button's icon on a glass capsule: on a styled (tinted) capsule the title's colour, as the
/// theme's icons are drawn in the plain text colour; otherwise the icon's own tint, if any.
public func chatMessageBubblelessGlassIconTint(isStyled: Bool, iconTint: UIColor?, titleColor: UIColor) -> UIColor? {
    return isStyled ? titleColor : iconTint
}

/// The horizontal layout of a channel post's comments row as a glass capsule, laid out like a bot's button.
public struct ChatMessageBubblelessCommentsCapsuleLayout: Equatable {
    /// Where the text starts: past the commenters' avatars (concentric with the left end) or the comments icon.
    public var leading: CGFloat
    /// From the end of the text (or the unread dot) to the capsule's right end, the chevron included.
    public var trailing: CGFloat
    public var textMaxWidth: CGFloat

    public init(leading: CGFloat, trailing: CGFloat, textMaxWidth: CGFloat) {
        self.leading = leading
        self.trailing = trailing
        self.textMaxWidth = textMaxWidth
    }
}

/// Avatars (30pt, a 20pt step, up to three) start 6pt in and the text 10pt after them; without avatars the icon starts
/// 12pt in and the text 8pt after it; the chevron ends 14pt from the right end, 12pt after the text.
public func chatMessageBubblelessCommentsCapsuleLayout(avatarCount: Int, iconWidth: CGFloat, arrowWidth: CGFloat, unreadWidth: CGFloat, constrainedWidth: CGFloat) -> ChatMessageBubblelessCommentsCapsuleLayout {
    let leading: CGFloat
    if avatarCount > 0 {
        let avatarsWidth = 30.0 + 20.0 * CGFloat(min(2, avatarCount - 1))
        leading = 6.0 + avatarsWidth + 10.0
    } else {
        leading = 12.0 + iconWidth + 8.0
    }
    let trailing = 12.0 + arrowWidth + 14.0
    return ChatMessageBubblelessCommentsCapsuleLayout(leading: leading, trailing: trailing, textMaxWidth: max(1.0, constrainedWidth - leading - trailing - unreadWidth))
}

/// The share button's top button: with bubbles the 30pt circle, so a channel post's reply count under the comment icon
/// stays outside it; a glass capsule without a second button opens the message from all of it.
public func chatMessageShareButtonTopButtonHeight(size: CGSize, hasBottomButton: Bool, isGlass: Bool) -> CGFloat {
    if isGlass && !hasBottomButton {
        return size.height
    }
    return size.width
}

/// Without bubbles, whether the text column makes room for buttons beside it: the share button, a summarize button, or
/// an ad's close and more buttons.
public func chatMessageBubblelessHasSideButtons(needsShareButton: Bool, needsSummarizeButton: Bool, isAd: Bool, isSidePanelOpen: Bool) -> Bool {
    return ((needsShareButton || needsSummarizeButton) && !isSidePanelOpen) || isAd
}
