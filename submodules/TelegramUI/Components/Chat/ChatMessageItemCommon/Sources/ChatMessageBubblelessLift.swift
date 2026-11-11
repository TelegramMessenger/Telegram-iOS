import Foundation
import UIKit
import Display

/// What a piece of a message shows, for the card it lifts on without bubbles (spec 5.9, 6.9). Content nodes report these in
/// their own coordinates from frames they already laid out; the item node moves them by the content frames it has.
public enum ChatMessageBubblelessLiftPart: Equatable {
    /// Line boxes of text, from the first line's top to the last line's bottom.
    case textLines(CGRect)
    /// Media, a quote or code background, a link preview's block, a file, a banner.
    case block(CGRect)
    /// Something that widens the card but leaves its height alone (the time beside the name).
    case widthOnly(CGRect)
    /// An outlined card (a poll, a checklist, a call): it lifts by its outline and nothing else is measured.
    case outline(CGRect)
    /// A round video's circle or a service message's plate: it lifts alone, without a card.
    case standalone(CGRect)

    public func offsetBy(_ offset: CGPoint) -> ChatMessageBubblelessLiftPart {
        switch self {
        case let .textLines(rect):
            return .textLines(rect.offsetBy(dx: offset.x, dy: offset.y))
        case let .block(rect):
            return .block(rect.offsetBy(dx: offset.x, dy: offset.y))
        case let .widthOnly(rect):
            return .widthOnly(rect.offsetBy(dx: offset.x, dy: offset.y))
        case let .outline(rect):
            return .outline(rect.offsetBy(dx: offset.x, dy: offset.y))
        case let .standalone(rect):
            return .standalone(rect.offsetBy(dx: offset.x, dy: offset.y))
        }
    }
}

/// The rect a pressed message lifts out by, and whether it lifts on a card.
public struct ChatMessageBubblelessLift: Equatable {
    public var rect: CGRect
    public var hasCard: Bool

    public init(rect: CGRect, hasCard: Bool) {
        self.rect = rect
        self.hasCard = hasCard
    }
}

/// The card around text lines: 11pt beside them, 6pt and a pixel above, 6pt less a pixel below.
public let chatMessageBubblelessLiftTextInsets = UIEdgeInsets(top: 6.0 + UIScreenPixel, left: 11.0, bottom: 6.0 - UIScreenPixel, right: 11.0)
/// The card around blocks.
public let chatMessageBubblelessLiftBlockInset: CGFloat = 11.0

/// The line boxes of a text node for its lift: the node's frame inside its insets, narrowed to its lines' own extent
/// (`lineRects` in the layout's coordinates, inside the insets), since text can be laid out wider than its lines (a
/// caption under files spans the column).
public func chatMessageBubblelessTextLinesFrame(nodeFrame: CGRect, insets: UIEdgeInsets, lineRects: [CGRect]) -> CGRect {
    var frame = nodeFrame.inset(by: insets)
    guard let minX = lineRects.map(\.minX).min(), let maxX = lineRects.map(\.maxX).max(), maxX > minX else {
        return frame
    }
    frame.origin.x += minX
    frame.size.width = maxX - minX
    return frame
}

public func chatMessageBubblelessLift(parts: [ChatMessageBubblelessLiftPart]) -> ChatMessageBubblelessLift? {
    for part in parts {
        if case let .standalone(rect) = part {
            return ChatMessageBubblelessLift(rect: rect, hasCard: false)
        }
    }
    for part in parts {
        if case let .outline(rect) = part {
            let outset = 1.0 + UIScreenPixel * 2.0
            return ChatMessageBubblelessLift(rect: rect.insetBy(dx: -outset, dy: -outset), hasCard: true)
        }
    }
    var rect: CGRect?
    var minX: CGFloat?
    var maxX: CGFloat?
    for part in parts {
        let padded: CGRect
        switch part {
        case let .textLines(lines):
            let insets = chatMessageBubblelessLiftTextInsets
            padded = CGRect(x: lines.minX - insets.left, y: lines.minY - insets.top, width: lines.width + insets.left + insets.right, height: lines.height + insets.top + insets.bottom)
        case let .block(block):
            padded = block.insetBy(dx: -chatMessageBubblelessLiftBlockInset, dy: -chatMessageBubblelessLiftBlockInset)
        case let .widthOnly(widthOnly):
            minX = min(minX ?? .greatestFiniteMagnitude, widthOnly.minX - chatMessageBubblelessLiftBlockInset)
            maxX = max(maxX ?? -.greatestFiniteMagnitude, widthOnly.maxX + chatMessageBubblelessLiftBlockInset)
            continue
        case .outline, .standalone:
            continue
        }
        rect = rect?.union(padded) ?? padded
    }
    guard var result = rect else {
        return nil
    }
    if let minX, minX < result.minX {
        result.size.width += result.minX - minX
        result.origin.x = minX
    }
    if let maxX, maxX > result.maxX {
        result.size.width = maxX - result.minX
    }
    return ChatMessageBubblelessLift(rect: result, hasCard: true)
}

/// Whether a message lifts without its name and time: round videos and torn strips (spec 5.9), and cards, which lift by
/// their outline alone, so their header would sit outside the card, under the reaction picker.
public func chatMessageBubblelessLiftHidesHeader(isTornStrip: Bool, isRoundVideo: Bool, hasCardOutline: Bool) -> Bool {
    return isTornStrip || isRoundVideo || hasCardOutline
}

/// The card's colour: the page in light themes, a raised gray in dark ones, so it reads over the dimmed chat.
public func chatMessageBubblelessLiftColor(dark: Bool, pageColor: UIColor) -> UIColor {
    return dark ? UIColor(rgb: 0x1c1c1e) : pageColor
}

/// A round video's duration text: on the dark media glass (bubble mode off) the time-over-media colour, which stays
/// readable where the service colour would sink into the glass on a light page; otherwise the service colour.
public func chatMessageBubblelessRoundVideoDurationTextColor(onGlass: Bool, serviceTextColor: UIColor, mediaTextColor: UIColor) -> UIColor {
    return onGlass ? mediaTextColor : serviceTextColor
}

/// The fill your own message comes out on for its menu, or nil where its bubble stands out from the dimmed chat by
/// itself: a light theme's gray bubble is barely lighter than the dimmed chat, so it comes out as light as the menu (the
/// page); a dark theme's gray bubble is lighter than the menu already, and a coloured bubble keeps its colour.
public func chatMessageBubblelessContextLiftColor(bubbleIsGray: Bool, dark: Bool, pageColor: UIColor) -> UIColor? {
    guard bubbleIsGray, !dark else {
        return nil
    }
    return pageColor
}

/// How your own message's bubble runs on into its neighbours (`ChatMessageBackgroundMergeType` without the extracted
/// case, which is `none` here).
public enum ChatMessageBubblelessBubbleMerge: Equatable {
    case none
    case both
    case bottom
    case side
    case top(side: Bool)
}

public struct ChatMessageBubblelessCornerRadii: Equatable {
    public var topLeft: CGFloat
    public var topRight: CGFloat
    public var bottomLeft: CGFloat
    public var bottomRight: CGFloat

    public init(topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }
}

/// The shape a fill in place of your own message's bubble takes: the bubble image stands its body 1pt inside its frame
/// and keeps a 6pt tail column on the right; the corners toward the messages it runs on take the smaller radius.
public func chatMessageBubblelessOutgoingBubbleShape(backgroundFrame: CGRect, merge: ChatMessageBubblelessBubbleMerge, mainRadius: CGFloat, smallRadius: CGFloat) -> (frame: CGRect, radii: ChatMessageBubblelessCornerRadii) {
    let main = mainRadius
    let small = smallRadius
    let radii: ChatMessageBubblelessCornerRadii
    switch merge {
    case .none:
        radii = ChatMessageBubblelessCornerRadii(topLeft: main, topRight: main, bottomLeft: main, bottomRight: main)
    case .both:
        radii = ChatMessageBubblelessCornerRadii(topLeft: main, topRight: small, bottomLeft: main, bottomRight: small)
    case .bottom:
        radii = ChatMessageBubblelessCornerRadii(topLeft: main, topRight: small, bottomLeft: main, bottomRight: main)
    case .side:
        radii = ChatMessageBubblelessCornerRadii(topLeft: main, topRight: main, bottomLeft: small, bottomRight: small)
    case let .top(side):
        radii = ChatMessageBubblelessCornerRadii(topLeft: main, topRight: main, bottomLeft: side ? small : main, bottomRight: small)
    }
    let frame = CGRect(x: backgroundFrame.minX + 1.0, y: backgroundFrame.minY + 1.0, width: max(1.0, backgroundFrame.width - 8.0), height: max(1.0, backgroundFrame.height - 2.0))
    return (frame, radii)
}

public func chatMessageBubblelessLiftCornerRadius(mainRadius: CGFloat, height: CGFloat) -> CGFloat {
    return min(mainRadius, floor(height * 0.5))
}

/// Without bubbles an incoming message's time and author leave the message, so its menu starts with them: not for your
/// own messages, ads, service messages or the reply and forward options screens.
public func chatMessageBubblelessMenuShowsInfoRows(bubbleMode: Bool, isMessageOptions: Bool, incoming: Bool, isAd: Bool, isService: Bool) -> Bool {
    return !bubbleMode && !isMessageOptions && incoming && !isAd && !isService
}

public enum ChatMessageBubblelessMenuInfoRow: Equatable {
    case sent
    case author
}

/// The rows those menus start with: when it was sent and, if there is one, by whom. An edited message whose "Edited" row
/// already shows when it was sent (the server's `message_primary_edited_date`) gets no second "Sent" row, and its author
/// follows that row.
public func chatMessageBubblelessMenuInfoRows(hasAuthor: Bool, editedRowShowsSentTime: Bool) -> [ChatMessageBubblelessMenuInfoRow] {
    var rows: [ChatMessageBubblelessMenuInfoRow] = editedRowShowsSentTime ? [] : [.sent]
    if hasAuthor {
        rows.append(.author)
    }
    return rows
}

/// The menu's read-report row is compact in private chats (master) and for the bubble-free info rows; the "Edited" row in
/// groups and channels keeps master's metrics.
public func chatReadReportRowUsesCompactMetrics(isCloudUserChat: Bool, isBubblelessInfoRow: Bool) -> Bool {
    return isCloudUserChat || isBubblelessInfoRow
}
