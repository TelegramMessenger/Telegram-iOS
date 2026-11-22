import Foundation
import UIKit
import Display
import TelegramCore

/// The selection checkmark without bubbles sits inside the row band, 14pt from the safe edge (master's: 6pt).
public let chatMessageBubblelessSelectionCheckX: CGFloat = 14.0
public let chatMessageSelectionCheckSize: CGFloat = 28.0

/// Whether the checkmark takes the list's plain ring rather than the one drawn for wallpapers: on the theme's own colour
/// wallpaper (master), and without bubbles, where every theme shows the list's plain page.
public func chatMessageSelectionCheckIsPlain(wallpaper: TelegramWallpaper, defaultWallpaper: TelegramWallpaper, bubbleMode: Bool) -> Bool {
    guard case .color = wallpaper else {
        return false
    }
    return !bubbleMode || wallpaper == defaultWallpaper
}

/// How far a message's content moves in selection: incoming content makes room for the checkmark (as on master); without
/// bubbles your own messages also step 6pt away from the right edge.
public func chatMessageSelectionContentOffset(incoming: Bool, bubbleMode: Bool) -> CGFloat {
    if incoming {
        return chatMessageBubblelessSelectionRoom
    }
    return bubbleMode ? 0.0 : -6.0
}

/// What the checkmark centres on without bubbles (spec 5.8).
public enum ChatMessageBubblelessCheckAnchor {
    /// A run's first message: the lead, the middle of its name and first line.
    case lead(centerY: CGFloat)
    /// A follower that starts with its forward header.
    case forwardHeader(top: CGFloat, lineHeight: CGFloat)
    /// A follower that starts with text.
    case firstTextLine(top: CGFloat, lineHeight: CGFloat)
    /// A follower that starts with anything else: 17pt down, half the avatar.
    case block(top: CGFloat)
    /// A message in a bubble (your own): its first line.
    case bubble(CGRect)
    /// A torn strip: its middle.
    case strip(CGRect)
}

public func chatMessageBubblelessCheckCenterY(_ anchor: ChatMessageBubblelessCheckAnchor) -> CGFloat {
    switch anchor {
    case let .lead(centerY):
        return centerY
    case let .forwardHeader(top, lineHeight):
        return top + lineHeight * 0.5
    case let .firstTextLine(top, lineHeight):
        return top + ceil(lineHeight) * 0.5
    case let .block(top):
        return top + 17.0
    case let .bubble(frame):
        return frame.minY + min(frame.height * 0.5, 17.5)
    case let .strip(frame):
        return frame.midY
    }
}

/// A message taller than the screen keeps its checkmark 17pt under the visible top (level with the parked avatar) while
/// it scrolls, and never lets it leave the row. `visibleTop` is in the row's coordinates; `-greatestFiniteMagnitude`
/// leaves the check where it is.
public func chatMessageBubblelessStickyCheckY(checkY: CGFloat, visibleTop: CGFloat, rowHeight: CGFloat) -> CGFloat {
    let stickyY = floor(visibleTop + 17.0 - chatMessageSelectionCheckSize * 0.5)
    if checkY < stickyY {
        return max(checkY, min(stickyY, rowHeight - chatMessageSelectionCheckSize - 4.0))
    }
    return checkY
}

/// The rounded band behind a selected or highlighted row: 8pt from the safe edges, from `top` to the row's bottom.
public let chatMessageBubblelessRowBandInset: CGFloat = 8.0
/// A band's first row starts this far above the author's name.
public let chatMessageBubblelessRowBandNameTopPadding: CGFloat = 5.5
public let chatMessageBubblelessSelectionBandAlpha: CGFloat = 0.10
public let chatMessageBubblelessHighlightBandAlpha: CGFloat = 0.12
/// A selected album item's own plate: the page mixed with this much accent.
public let chatMessageBubblelessAlbumItemPlateAccentFraction: CGFloat = 0.08
public let chatMessageBubblelessBandFadeInDuration: Double = 0.2
public let chatMessageBubblelessSelectionBandFadeOutDuration: Double = 0.2
public let chatMessageBubblelessHighlightBandFadeOutDuration: Double = 0.4

public func chatMessageBubblelessRowBandFrame(rowSize: CGSize, leftSafeInset: CGFloat, rightSafeInset: CGFloat, top: CGFloat) -> CGRect {
    let inset = chatMessageBubblelessRowBandInset
    return CGRect(x: inset + leftSafeInset, y: top, width: max(0.0, rowSize.width - inset * 2.0 - leftSafeInset - rightSafeInset), height: max(0.0, rowSize.height - top))
}

/// Where a row's band starts: under its date header; a band's first row (not joined above) is trimmed to 5.5pt above
/// the name, or to just under the spacing above a row without one.
public func chatMessageBubblelessRowBandTop(dateHeaderInset: CGFloat, nameTop: CGFloat?, layoutTopInset: CGFloat, joinsAbove: Bool) -> CGFloat {
    if joinsAbove {
        return dateHeaderInset
    }
    let trimmedTop: CGFloat
    if let nameTop {
        trimmedTop = nameTop - chatMessageBubblelessRowBandNameTopPadding
    } else {
        trimmedTop = layoutTopInset - 0.66
    }
    return max(dateHeaderInset, trimmedTop)
}

public func chatMessageBubblelessRowBandCornerRadius(mainRadius: CGFloat, height: CGFloat) -> CGFloat {
    return min(mainRadius + 8.0, floor(height * 0.5))
}

/// Which ends of a row's band meet the next selected row's: joined rows meet square and cover the spacing between them.
public struct ChatMessageBubblelessBandJoins: Equatable {
    public var above: Bool
    public var below: Bool

    public init(above: Bool, below: Bool) {
        self.above = above
        self.below = below
    }
}

/// Two rows join when both are selected and no date or topic header lies between them.
public func chatMessageBubblelessBandJoins(isSelected: Bool, aboveSelected: Bool, belowSelected: Bool, headerBetweenAbove: Bool, headerBetweenBelow: Bool) -> ChatMessageBubblelessBandJoins {
    guard isSelected else {
        return ChatMessageBubblelessBandJoins(above: false, below: false)
    }
    return ChatMessageBubblelessBandJoins(above: aboveSelected && !headerBetweenAbove, below: belowSelected && !headerBetweenBelow)
}

/// The selected neighbours a row's band joins. Leaving selection, the rows are laid out without it (their neighbours no
/// longer selected) a moment before their bands fade out, so a row out of selection keeps the joins it had and the joined
/// band fades as one.
public func chatMessageBubblelessBandSelectedNeighbors(inSelection: Bool, above: Bool, below: Bool, previous: ChatMessageBubblelessRowBandInputs?) -> (above: Bool, below: Bool) {
    if !inSelection, let previous {
        return (previous.selectedAbove, previous.selectedBelow)
    }
    return (above, below)
}

/// Every selected message gets a band without bubbles, your own included, except round videos and torn strips, which get
/// only the checkmark.
public func chatMessageBubblelessHasSelectionBand(bubbleMode: Bool, isRoundVideo: Bool, isTornStrip: Bool) -> Bool {
    return !bubbleMode && !isRoundVideo && !isTornStrip
}

/// Whether a row draws a selection band without bubbles, as its neighbours learn it: not a round video, and not a message
/// this build cannot show where it is a torn strip (incoming); your own keeps its bubble and its band.
public func chatMessageBubblelessItemDrawsSelectionBand(style: ChatMessageBubbleStyle, isRoundVideo: Bool, isUnsupportedMessage: Bool) -> Bool {
    return chatMessageBubblelessHasSelectionBand(bubbleMode: false, isRoundVideo: isRoundVideo, isTornStrip: style.isBubbleless && isUnsupportedMessage)
}

/// A message jumped to (a reply, a link) flashes a band in its author's colour where it has no bubble to flash: not your
/// own messages, service messages, round videos or torn strips, and not for a quote's or a task's own highlight.
public func chatMessageBubblelessHasHighlightBand(style: ChatMessageBubbleStyle, isRoundVideo: Bool, isTornStrip: Bool, isQuoteOrTaskHighlight: Bool) -> Bool {
    return style.isBubbleless && !isRoundVideo && !isTornStrip && !isQuoteOrTaskHighlight
}

/// What a row's bands are laid out from without bubbles, recorded at its last layout.
public struct ChatMessageBubblelessRowBandInputs: Equatable {
    /// The top of the author's name in content coordinates, when the row is headed by it.
    public var nameTop: CGFloat?
    /// Whether the rows right above and below are selected, with no header between (`ChatMessageHeaderSpec`).
    public var selectedAbove: Bool
    public var selectedBelow: Bool
    public var hasSelectionBand: Bool
    public var hasHighlightBand: Bool
    
    public init(nameTop: CGFloat?, selectedAbove: Bool, selectedBelow: Bool, hasSelectionBand: Bool, hasHighlightBand: Bool) {
        self.nameTop = nameTop
        self.selectedAbove = selectedAbove
        self.selectedBelow = selectedBelow
        self.hasSelectionBand = hasSelectionBand
        self.hasHighlightBand = hasHighlightBand
    }
}
