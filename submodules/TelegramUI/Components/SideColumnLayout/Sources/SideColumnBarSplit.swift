import Foundation

/// What a navigation bar button is, for iPhone Duo's side column (ItemList screens).
public enum SideColumnBarButtonKind: Equatable {
    /// No title, image or node.
    case spacer
    case text
    /// An image or a custom node.
    case icon
    /// The close X.
    case close
    /// The accent checkmark.
    case confirm
}

/// What the bar shows on the left when the screen has no left button.
public enum SideColumnBarNavigation: Equatable {
    case none
    case back
    case close
}

public enum SideColumnBarEntry: Equatable {
    /// The bar's own back or close (per `SideColumnBarNavigation`).
    case navigation
    case left
    /// The right button at this index, in the order the caller passed (primary first).
    case right(index: Int)
}

public struct SideColumnBarSplit: Equatable {
    /// The circle at the top: back, close, or the left close X.
    public var top: SideColumnBarEntry?
    /// The capsule's cells, top to bottom.
    public var capsule: [SideColumnBarEntry]
    /// The accent circle.
    public var confirm: SideColumnBarEntry?
    /// Whether the left button stays in the top row (text or a spacer).
    public var keepsLeftInTopRow: Bool
    /// The right buttons that stay in the top row, as indices into `right`.
    public var topRowRightIndices: [Int]

    public init(top: SideColumnBarEntry?, capsule: [SideColumnBarEntry], confirm: SideColumnBarEntry?, keepsLeftInTopRow: Bool, topRowRightIndices: [Int]) {
        self.top = top
        self.capsule = capsule
        self.confirm = confirm
        self.keepsLeftInTopRow = keepsLeftInTopRow
        self.topRowRightIndices = topRowRightIndices
    }
}

/// Text buttons and spacers stay in the top row. With no left button the top circle is the bar's own back
/// or close; a left close X takes it instead. The first checkmark takes the accent circle; icons, a right
/// close and further checkmarks join the capsule, the left one first, then the right ones in order. Nil
/// when nothing would move into the column (the bar stays as it is).
public func sideColumnBarSplit(navigation: SideColumnBarNavigation, left: SideColumnBarButtonKind?, right: [SideColumnBarButtonKind]) -> SideColumnBarSplit? {
    var top: SideColumnBarEntry?
    var capsule: [SideColumnBarEntry] = []
    var confirm: SideColumnBarEntry?
    var keepsLeftInTopRow = false
    switch left {
    case .none:
        if navigation != .none {
            top = .navigation
        }
    case .spacer?, .text?:
        keepsLeftInTopRow = true
    case .close?:
        top = .left
    case .confirm?:
        confirm = .left
    case .icon?:
        capsule.append(.left)
    }

    var topRowRightIndices: [Int] = []
    for (index, kind) in right.enumerated() {
        switch kind {
        case .spacer, .text:
            topRowRightIndices.append(index)
        case .icon, .close:
            capsule.append(.right(index: index))
        case .confirm:
            if confirm == nil {
                confirm = .right(index: index)
            } else {
                capsule.append(.right(index: index))
            }
        }
    }

    if top == nil && capsule.isEmpty && confirm == nil {
        return nil
    }
    return SideColumnBarSplit(top: top, capsule: capsule, confirm: confirm, keepsLeftInTopRow: keepsLeftInTopRow, topRowRightIndices: topRowRightIndices)
}
