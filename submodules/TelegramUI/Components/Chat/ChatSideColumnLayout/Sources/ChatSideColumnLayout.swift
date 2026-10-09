import Foundation
import UIKit
import Display
import SideColumnLayout

/// What a chat navigation item is, for deciding where it goes beside iPhone Duo's side strip.
public enum ChatSideColumnItemKind: Equatable {
    /// A spacer: no title, image or node.
    case empty
    case text
    case icon
    case avatar
    case search
}

/// What the bar shows on the left when the chat has no left item.
public enum ChatSideColumnNavigation: Equatable {
    case none
    case back
    case close
}

public enum ChatSideColumnEntry: Equatable {
    case back
    case close
    /// The chat's left item (an icon).
    case left
    /// The search circle the column adds.
    case addedSearch
    /// The right item at this index, in the bar's order (primary, then secondary).
    case right(index: Int)
}

public struct ChatSideColumnAssignment: Equatable {
    /// The column's circles, top to bottom.
    public var column: [ChatSideColumnEntry]
    /// Whether the left item stays in the top row (text, or a spacer).
    public var keepsLeftInTopRow: Bool
    /// The right items that stay in the top row, in the bar's order.
    public var topRowRightIndices: [Int]

    public init(column: [ChatSideColumnEntry], keepsLeftInTopRow: Bool, topRowRightIndices: [Int]) {
        self.column = column
        self.keepsLeftInTopRow = keepsLeftInTopRow
        self.topRowRightIndices = topRowRightIndices
    }
}

public func chatSideColumnItemKind(title: String?, hasImage: Bool, hasCustomNode: Bool, isAvatar: Bool, isSearch: Bool) -> ChatSideColumnItemKind {
    if isAvatar {
        return .avatar
    }
    if isSearch {
        return .search
    }
    if hasImage || hasCustomNode {
        return .icon
    }
    if let title, !title.trimmingCharacters(in: .whitespaces).isEmpty {
        return .text
    }
    return .empty
}

/// Text items (and spacers) stay in the top row; icon items go to the column, the left one first; with no
/// left item the column starts with what the bar would show (back or close). Search is added just before
/// the avatar when the column holds the avatar and no item is search already.
public func chatSideColumnAssignment(navigation: ChatSideColumnNavigation, left: ChatSideColumnItemKind?, right: [ChatSideColumnItemKind]) -> ChatSideColumnAssignment {
    var column: [ChatSideColumnEntry] = []
    var keepsLeftInTopRow = false
    switch left {
    case .none:
        switch navigation {
        case .none:
            break
        case .back:
            column.append(.back)
        case .close:
            column.append(.close)
        }
    case .text?, .empty?:
        keepsLeftInTopRow = true
    case .icon?, .avatar?, .search?:
        column.append(.left)
    }

    var topRowRightIndices: [Int] = []
    for (index, kind) in right.enumerated() {
        switch kind {
        case .text, .empty:
            topRowRightIndices.append(index)
        case .icon, .avatar, .search:
            column.append(.right(index: index))
        }
    }

    let hasSearch = left == .search || right.contains(.search)
    if !hasSearch, let avatarIndex = right.firstIndex(of: .avatar), let columnIndex = column.firstIndex(of: .right(index: avatarIndex)) {
        column.insert(.addedSearch, at: columnIndex)
    }
    return ChatSideColumnAssignment(column: column, keepsLeftInTopRow: keepsLeftInTopRow, topRowRightIndices: topRowRightIndices)
}

/// The strip the chat's column goes in (the right one if there is one, else the left), or nil.
public func chatSideColumnStripEdge(_ layout: ContainerViewLayout) -> ContainerViewLayoutSideEdge? {
    if layout.sideStrip(edge: .right) != nil {
        return .right
    }
    if layout.sideStrip(edge: .left) != nil {
        return .left
    }
    return nil
}

/// The input panel's side insets for its band: the band rule, except that on the column's side the strip
/// stays reserved while the band reaches the column (the keyboard lifted the panel that high).
public func chatInputPanelSideInsets(layout: ContainerViewLayout, bandMinY: CGFloat, bandMaxY: CGFloat, column: (edge: ContainerViewLayoutSideEdge, frames: [CGRect])?) -> (left: CGFloat, right: CGFloat) {
    let columnExtent = column.flatMap { column in
        column.frames.last.map { (edge: column.edge, maxY: $0.maxY) }
    }
    return sideColumnBandInsets(layout: layout, bandMinY: bandMinY, bandMaxY: bandMaxY, column: columnExtent)
}

public enum ChatSideColumnMove: Equatable {
    /// The frames follow the layout's transition.
    case animate
    /// The frames are set without animation (there were none to animate from).
    case immediate
    /// The column moved to another place (a rotation, or the strip switching sides): set the frames
    /// without animation, fade a snapshot of the old column out and the column in.
    case fade
}

/// How the column moves from its previous frames to `frames`.
public func chatSideColumnMove(previousFrames: [CGRect], previousContainerSize: CGSize?, frames: [CGRect], containerSize: CGSize) -> ChatSideColumnMove {
    guard let previousContainerSize, let previousFirst = previousFrames.first, let first = frames.first else {
        return .immediate
    }
    let wasOnTheRight = previousFirst.midX > previousContainerSize.width * 0.5
    let isOnTheRight = first.midX > containerSize.width * 0.5
    if previousContainerSize != containerSize || wasOnTheRight != isOnTheRight {
        return .fade
    }
    return .animate
}
