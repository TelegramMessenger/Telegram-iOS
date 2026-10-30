import Foundation
import UIKit
import Display

// Bubble mode off: every number the bubble-free layout shares, in one place (spec 6.5). Values from the reference
// patch.

/// The run's avatar: its inset from the row's leading edge and its size (`ChatMessageAvatarHeader`).
public let chatMessageAvatarHeaderInset: CGFloat = 7.0
public let chatMessageAvatarHeaderSize: CGFloat = 34.0
/// Between the avatar and the text column.
public let chatMessageBubblelessAvatarGap: CGFloat = 10.0
/// The page margin: where the text column starts without an avatar column, and where it ends.
public let chatMessageBubblelessMargin: CGFloat = 16.0
/// What selection moves incoming content right by (the checkmark's room), so content running to the margin makes room
/// for the move.
public let chatMessageBubblelessSelectionRoom: CGFloat = 42.0
/// The side buttons' column beside a message that keeps them (an ad).
public let chatMessageBubblelessSideButtonsWidth: CGFloat = 45.0
/// Between the bottom of the author header and media, a map, a game or a card that opens the message under it: their
/// hard edges read as closer to the name than a first line of text does.
public let chatMessageBubblelessHeaderMediaSpacing: CGFloat = 10.0
/// Between two blocks that follow each other in a run (media, cards): each keeps half of it beyond its visible edge.
public let chatMessageBubblelessBlockGap: CGFloat = 8.0
/// Under the last line of text. A bubble's padding there would only widen the gap to the next message.
public let chatMessageBubblelessTextBottomInset: CGFloat = 3.0 - UIScreenPixel
/// Bot buttons under text sit this much higher: the text's own bottom inset already keeps most of the room.
public let chatMessageBubblelessActionButtonsLift: CGFloat = 3.0
/// The incoming reply icon's offset while swiping to reply: content runs to the margin, so the icon trails it.
public let chatMessageBubblelessReplySwipeOffset: CGFloat = -8.0
/// A giveaway keeps its own width: spread across the column its centered contents drift apart.
public let chatMessageBubblelessGiveawayMaxWidth: CGFloat = 305.0

/// The author header: the time follows the name, at 11/17 of the body size, on the name's baseline. With a rank, the
/// badge follows the name and the time follows the badge. A post's views follow the time: an eye icon, then the count.
public func chatMessageBubblelessHeaderTimeFontSize(baseDisplaySize: CGFloat) -> CGFloat {
    return floor(baseDisplaySize * 11.0 / 17.0)
}
public let chatMessageBubblelessHeaderTimeSpacing: CGFloat = 6.0
public let chatMessageBubblelessHeaderRankSpacing: CGFloat = 5.0
public let chatMessageBubblelessHeaderRankTrailingSpacing: CGFloat = 10.0
public let chatMessageBubblelessHeaderViewsSpacing: CGFloat = 8.0
public let chatMessageBubblelessHeaderViewsIconSpacing: CGFloat = 2.0

/// The text column of an incoming message without a bubble: past the avatar column when the chat shows avatars, at the
/// page margin otherwise, ending at the margin. `baseWidth` excludes the row's safe insets. On wide layouts the column
/// is never wider than a bubble may be (spec 5.12); in compact widths, where the reference shows the full column, it is
/// not capped.
public func chatMessageBubblelessColumn(baseWidth: CGFloat, leftInset: CGFloat, hasAvatarColumn: Bool, inSelection: Bool, deliveryFailedInset: CGFloat, hasSideButtons: Bool, widthFill: ChatMessageItemWidthFill) -> (originX: CGFloat, width: CGFloat) {
    let columnInset = hasAvatarColumn ? (chatMessageAvatarHeaderInset + chatMessageAvatarHeaderSize + chatMessageBubblelessAvatarGap) : chatMessageBubblelessMargin
    var width = floor(baseWidth - columnInset - chatMessageBubblelessMargin - deliveryFailedInset)
    if hasSideButtons {
        width -= chatMessageBubblelessSideButtonsWidth
    }
    if inSelection {
        width -= chatMessageBubblelessSelectionRoom
    }
    if baseWidth > widthFill.compactWidthBoundary {
        width = min(width, widthFill.widthFor(baseWidth))
    }
    return (leftInset + columnInset, max(1.0, width))
}

/// The layout constants of an incoming message without a bubble: content sits on the column with no bubble padding
/// beside it, media keeps no room around it and rounds like a card. A card keeps a bubble's constants inside its outline.
public func chatMessageBubblelessLayoutConstants(_ constants: ChatMessageItemLayoutConstants, mainRadius: CGFloat, isCard: Bool) -> ChatMessageItemLayoutConstants {
    if isCard {
        return constants
    }
    var constants = constants
    constants.image.defaultCornerRadius = mainRadius
    constants.bubble.contentInsets.left = 0.0
    constants.bubble.contentInsets.right = 0.0
    constants.text.bubbleInsets.left = 0.0
    constants.text.bubbleInsets.right = 0.0
    constants.text.bubbleInsets.bottom = chatMessageBubblelessTextBottomInset
    constants.image.bubbleInsets = .zero
    constants.file.bubbleInsets.left = 0.0
    return constants
}

/// The middle of the lead of a run (the author's name and the first line under it), from the top of the name: halfway
/// between the name's cap line and the first line's baseline, which is where the eye puts the middle of two lines. The
/// run's avatar centers on it. `firstLineFont` is the font the message's first line is set in.
public func chatMessageBubblelessLeadCenterY(nameFont: UIFont, firstLineFont: UIFont, nameHeight: CGFloat) -> CGFloat {
    // The header leaves the first line 1pt and a pixel under the name.
    let firstLineTop = nameHeight + 1.0 + UIScreenPixel
    let nameCapTop = nameFont.ascender - nameFont.capHeight
    let firstBaseline = firstLineTop + firstLineFont.ascender
    return floorToScreenPixels((nameCapTop + firstBaseline) * 0.5)
}

/// What a message starts or ends with, for the spacing inside a run: text brings the room of its own lines (as do rich
/// data, a file and a contact, which keep their half of a block gap themselves); anything else is a block.
public enum ChatMessageBubblelessBlockKind {
    case text
    case block
}

/// What the bubble-free mode adds to a message's spacing above and below it.
/// - Messages without a bubble follow each other like paragraphs, a little further apart between authors; inside a
///   run, a block keeps half of the block gap beyond its edge where nothing else (a header, buttons) stands there.
/// - Bubbles keep a little more air next to messages without one, and a run of outgoing bubbles more above it.
/// - Service messages keep their hidden plate's room, more above them under a message than under a date, and less next
///   to another service message.
public func chatMessageBubblelessRhythm(style: ChatMessageBubbleStyle, incoming: Bool, mergedTop: Bool, mergedBottom: Bool, hasDateAbove: Bool, hasBubbleAbove: Bool, hasBubbleBelow: Bool, hasHeader: Bool, firstBlock: ChatMessageBubblelessBlockKind?, lastBlock: ChatMessageBubblelessBlockKind?, hasButtonsOrReactionsBelow: Bool) -> (top: CGFloat, bottom: CGFloat) {
    var top: CGFloat = 0.0
    var bottom: CGFloat = 0.0
    let isService = style == .bubblelessService
    if style.isBubbleless {
        top += mergedTop ? 0.0 : 3.0
        bottom += mergedBottom ? 0.0 : 1.0
        if mergedTop, !hasHeader, firstBlock == .block {
            top += chatMessageBubblelessBlockGap * 0.5
        }
        if mergedBottom, !hasButtonsOrReactionsBelow, lastBlock == .block {
            bottom += chatMessageBubblelessBlockGap * 0.5
        }
    } else {
        let isBubble = !isService
        if !(isBubble && hasBubbleAbove) {
            top += mergedTop ? 1.0 : 3.0
            if !incoming && !mergedTop && isBubble {
                top += 3.0
            }
        }
        if !(isBubble && hasBubbleBelow) {
            bottom += mergedBottom ? 1.0 : 3.0
        }
    }
    if isService {
        if mergedTop {
            top += 1.0
        } else {
            top += hasDateAbove ? 5.0 : 9.0
        }
        bottom += mergedBottom ? 1.0 : -1.0
    }
    return (top, bottom)
}

// Content without a bubble (spec 5.5).

/// A file or music block's top under the author header: its icon starts as far under the name as in a bubble, so the
/// big round icon does not crowd the name.
public let chatMessageBubblelessHeaderFileSpacing: CGFloat = 15.0
/// A contact block's top under the author header, as far under the name as in a bubble.
public let chatMessageBubblelessHeaderContactSpacing: CGFloat = 11.0 + UIScreenPixel

/// A file's top inset: under the author header it starts at the header's file spacing, its voice button no higher;
/// elsewhere a voice message's button, which rides above its row, starts where a file's icon would.
public func chatMessageBubblelessFileTopInset(baseTop: CGFloat, underHeader: Bool, voiceButtonOverhang: CGFloat) -> CGFloat {
    if underHeader {
        return chatMessageBubblelessHeaderFileSpacing
    }
    return baseTop + voiceButtonOverhang
}
/// Inline blocks (reply quotes, link previews, fact checks, quotes and code in text, contacts) round at this radius.
public let chatMessageBubblelessInlineBlockCornerRadius: CGFloat = 10.0
/// The text inset inside a card that has its own layout (a place or a live location).
public let chatMessageBubblelessCardTextInset: CGFloat = 12.0
/// A gift without a backdrop of its own is outlined at this radius.
public let chatMessageBubblelessGiftOutlineRadius: CGFloat = 24.0
/// A file with a preview is a plain row with a thumbnail this size and radius.
public let chatMessageBubblelessFileThumbnailSize: CGFloat = 44.0
public let chatMessageBubblelessFileThumbnailCornerRadius: CGFloat = 12.0
/// How far a voice message's play button overhangs its row on each side.
public let chatMessageBubblelessVoiceButtonOverhang: CGFloat = 3.0
/// A rich-text code band keeps at least this much room between its edge and its text.
public let chatMessageBubblelessCodeBlockMinimumPadding: CGFloat = 12.0
/// Two media blocks of a rich-text page that would stack stand this far apart.
public let chatMessageBubblelessSeparateMediaSpacing: CGFloat = 8.0
/// How deep each torn edge of the strip the chat tears around unsupported content is.
public let chatMessageBubblelessUnsupportedTearDepth: CGFloat = 10.0
/// How far a failed outgoing message moves in to make room for its icon: the icon and a gap.
public let chatMessageBubblelessDeliveryFailedInset: CGFloat = 28.0
/// Around the author header of a sticker or large-emoji row.
public let chatMessageBubblelessStickerHeaderSpacing: (above: CGFloat, below: CGFloat) = (7.0, 4.0)

public extension ChatMessageBubbleStyle {
    /// Incoming content without a bubble shows no time of its own: the author header has it. Cards neither.
    var hidesIncomingStatus: Bool {
        return self.isBubbleless
    }
}

/// A caption under media starts with its cap line a block gap under the media's edge.
public func chatMessageBubblelessCaptionTopInset(ascender: CGFloat, capHeight: CGFloat) -> CGFloat {
    return max(0.0, chatMessageBubblelessBlockGap - (ascender - capHeight))
}

/// Media may span the text column, as text does: landscape media reaches it while upright media stays bound by the
/// height limit. In a channel post that limit grows in proportion too, never past what a bubble at that width allows
/// (spec 5.12).
public func chatMessageBubblelessMediaMaxDimensions(_ maxDimensions: CGSize, columnWidth: CGFloat, isChannelPost: Bool, bubbleMaxWidth: CGFloat) -> CGSize {
    guard columnWidth > maxDimensions.width, maxDimensions.width > 0.0 else {
        return maxDimensions
    }
    var result = maxDimensions
    result.width = columnWidth
    if isChannelPost {
        let scaledHeight = floor(maxDimensions.height * columnWidth / maxDimensions.width)
        let cappedHeight = floor(maxDimensions.height * max(bubbleMaxWidth, maxDimensions.width) / maxDimensions.width)
        result.height = min(scaledHeight, cappedHeight)
    }
    return result
}

/// Large emoji sit closer to their header and their neighbours: no room above, the glyphs' own empty bottom taken back
/// without reactions, and under a header they move up into it.
public func chatMessageBubblelessLargeEmojiInsets(emojiHeight: CGFloat, hasReactions: Bool, underHeader: Bool) -> (top: CGFloat, bottom: CGFloat, headerOverlap: CGFloat) {
    let bottom: CGFloat = hasReactions ? 0.0 : -floor(emojiHeight * 0.11)
    let headerOverlap: CGFloat = underHeader ? floor(emojiHeight * 0.1) : 0.0
    return (0.0, bottom, headerOverlap)
}

/// The avatar inset a sticker row lays out with so that the sticker's visible edge lands on the text column: the
/// column's inset less the bubble's edge and content insets and the sticker's own transparent inset.
public func chatMessageBubblelessStickerInset(hasAvatarColumn: Bool, edgeInset: CGFloat, contentInsetLeft: CGFloat, transparentInset: CGFloat) -> CGFloat {
    let columnInset = hasAvatarColumn ? (chatMessageAvatarHeaderInset + chatMessageAvatarHeaderSize + chatMessageBubblelessAvatarGap) : chatMessageBubblelessMargin
    return columnInset - edgeInset - contentInsetLeft - transparentInset
}

/// A failed message's icon takes the place of its bubble's visible edge, which `inset` moved in, a gap past it. It sits
/// level with the middle of a short message, and as far from the bottom of a taller one.
public func chatMessageBubblelessDeliveryFailedFrame(iconSize: CGSize, contentFrame: CGRect, inset: CGFloat) -> CGRect {
    let centerY = contentFrame.maxY - min(contentFrame.height * 0.5, 16.5)
    return CGRect(origin: CGPoint(x: contentFrame.maxX + inset - iconSize.width, y: floorToScreenPixels(centerY - iconSize.height * 0.5)), size: iconSize)
}

/// Without bubbles, where a message's reactions go when its content hid the status that held them (text, captions, link
/// previews, rich pages, fact checks, files, games, invoices, restricted messages).
public enum ChatMessageBubblelessReactionsPlacement: Equatable {
    /// Where they already are: a reactions footer, the item's row, or a status that still shows.
    case unchanged
    /// The item's reactions row under the message.
    case row
    /// A reactions footer: above a comments row, under which it would read as reactions to the comments, and after an
    /// album of files, whose files each stand in a container of their own.
    case footer
}

public func chatMessageBubblelessReactionsPlacement(style: ChatMessageBubbleStyle, hasReactions: Bool, statusHeldReactions: Bool, hasReactionsFooter: Bool, endsWithComments: Bool, hasSeparateContainers: Bool) -> ChatMessageBubblelessReactionsPlacement {
    if !style.isBubbleless || !hasReactions || !statusHeldReactions || hasReactionsFooter {
        return .unchanged
    }
    if endsWithComments || hasSeparateContainers {
        return .footer
    }
    return .row
}

/// Without bubbles, the zones the chat tears a strip across: only around a message this build cannot show at all, whose
/// banner stands in the strip. A rich page's unsupported blocks keep their pill, and with bubbles the bubble tears instead.
public func chatMessageBubblelessTornStripZones(style: ChatMessageBubbleStyle, isUnsupportedMessage: Bool, zones: [CGRect]) -> [CGRect] {
    if style.isBubbleless && isUnsupportedMessage {
        return zones
    }
    return []
}

/// Without bubbles, the room around a contact block's content: past its accent line, the avatar and their padding, and
/// the same padding again from the block's right edge.
public let chatMessageBubblelessContactPadding: CGFloat = 10.0

public func chatMessageBubblelessContactTextInsets(lineWidth: CGFloat, avatarWidth: CGFloat) -> (leading: CGFloat, trailing: CGFloat) {
    return (lineWidth + chatMessageBubblelessContactPadding + avatarWidth + chatMessageBubblelessContactPadding, chatMessageBubblelessContactPadding)
}
