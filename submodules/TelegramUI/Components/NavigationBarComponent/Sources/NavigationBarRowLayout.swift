import Foundation
import UIKit
import Display
import GlassBackgroundComponent
import SideColumnLayout

/// UIKit's gap between two platters of one side of the bar (`NavigationButtonBar.Layout.Metrics.interSectionSpacing`,
/// read on iOS 27): the capsule and an accent button's circle beside it.
let navigationBarInterSectionSpacing: CGFloat = 12.0

/// How far an accent circle of `width` takes the capsule in from the edge: the circle and UIKit's gap (0 without one).
func navigationBarRightCircleExtent(_ width: CGFloat) -> CGFloat {
    return width > 0.0 ? width + navigationBarInterSectionSpacing : 0.0
}

/// How far a content's right platters reach from its inset: the capsule, and beyond it the accent circle with the gap.
func navigationBarRightButtonsExtent(capsuleWidth: CGFloat, circleWidth: CGFloat) -> CGFloat {
    if capsuleWidth == 0.0 {
        return circleWidth
    }
    return capsuleWidth + navigationBarRightCircleExtent(circleWidth)
}

/// iPhone Duo: whether a button goes into the side column. Icon, image, more and custom buttons do; text buttons stay
/// in the row (Apple: text-only items stay horizontal). A screen's node rides in its button's view, which the bar alone
/// hosts, so it can move with it; it does when it fits a column cell (the chat's avatar and "…", a spinner), and a
/// node that draws text (Calls' "Delete All", a mini app's "Close") stays in the row, where the column would cut it.
func navigationBarIsColumnItem(_ button: NavigationBarComponent.Button) -> Bool {
    switch button.content {
    case .text:
        return false
    case let .node(node):
        return node.measure(CGSize(width: 100.0, height: 44.0)).width <= sideColumnWidth
    case .icon, .image, .more, .custom:
        return true
    }
}

/// Whether UIKit gives a bar button a section (a glass pill) of its own: `-[UIBarButtonItem _requiresOwnSection]`,
/// asked of UIKit on iOS 27 (spec 2026-10-15-navbar-split-right-buttons-design.md): true for every text item and every
/// prominent one (the Done checkmark included); false for image, system-image and custom-view items.
func navigationBarButtonRequiresOwnSection(_ button: NavigationBarComponent.Button) -> Bool {
    if case .text = button.content {
        return true
    }
    return button.tint != .generic
}

/// The right side's pills, as `-[UINavigationItem _addImplicitTopBarSectionsFromItems:toSections:forPlacement:]` builds
/// sections: walking the buttons outermost first, one that requires its own section closes the current pill and takes
/// one alone; any other joins the current pill. Pills and their buttons are outermost first.
func navigationBarRightSections(_ buttons: [NavigationBarComponent.Button]) -> [[NavigationBarComponent.Button]] {
    var sections: [[NavigationBarComponent.Button]] = []
    var current: [NavigationBarComponent.Button] = []
    for button in buttons {
        if navigationBarButtonRequiresOwnSection(button) {
            if !current.isEmpty {
                sections.append(current)
                current = []
            }
            sections.append([button])
        } else {
            current.append(button)
        }
    }
    if !current.isEmpty {
        sections.append(current)
    }
    return sections
}

/// Where one content's buttons go: the row, or iPhone Duo's side column.
struct NavigationBarButtonPlacement {
    /// Nil without a column, or when the column cannot hold what must stay; every button is then in the row.
    var columnLayout: SideColumnItemsLayout?
    /// The capsule's candidates in column order (a left icon button first); `columnLayout` indexes into it.
    var columnItems: [NavigationBarComponent.Button]
    /// The confirming button (the Done checkmark) in the column's own circle below the capsule; nil without a column.
    var trailingCircleItem: NavigationBarComponent.Button?
    var leftButtonInColumn: Bool
    var rowLeftButton: NavigationBarComponent.Button?
    var rowRightButtons: [NavigationBarComponent.Button]
    /// The first accent right button, in a glass circle of its own outermost in the row (UIKit gives a prominent item a
    /// section of its own: spec 2026-10-15-accent-right-button-circle-design.md). Nil with a column, and when it is the
    /// row's only right button: the capsule is then that circle already, and Edit -> Done stays one capsule, as UIKit's
    /// section 0 does.
    var rowCircleItem: NavigationBarComponent.Button?
}

func navigationBarButtonPlacement(leftButton: NavigationBarComponent.Button?, rightButtons: [NavigationBarComponent.Button], hasBack: Bool, columnLength: CGFloat?) -> NavigationBarButtonPlacement {
    var columnItems: [NavigationBarComponent.Button] = []
    var leftButtonInColumn = false
    var trailingCircleItem: NavigationBarComponent.Button?
    if columnLength != nil {
        if let leftButton, navigationBarIsColumnItem(leftButton) {
            columnItems.append(leftButton)
            leftButtonInColumn = true
        }
        for button in rightButtons where navigationBarIsColumnItem(button) {
            if trailingCircleItem == nil && button.tint != .generic {
                trailingCircleItem = button
            } else {
                columnItems.append(button)
            }
        }
    }
    let columnLayout: SideColumnItemsLayout? = columnLength.flatMap { columnLength in
        return sideColumnItemsLayout(regionLength: columnLength, hasBack: hasBack, priorities: columnItems.map { $0.overflow?.priority }, hasTrailingCircle: trailingCircleItem != nil)
    }
    if columnLayout == nil {
        leftButtonInColumn = false
        trailingCircleItem = nil
    }
    var rowRightButtons = columnLayout != nil ? rightButtons.filter { !navigationBarIsColumnItem($0) } : rightButtons
    var rowCircleItem: NavigationBarComponent.Button?
    if columnLayout == nil, rowRightButtons.count > 1, let index = rowRightButtons.firstIndex(where: { $0.tint != .generic }) {
        rowCircleItem = rowRightButtons.remove(at: index)
    }
    return NavigationBarButtonPlacement(
        columnLayout: columnLayout,
        columnItems: columnItems,
        trailingCircleItem: trailingCircleItem,
        leftButtonInColumn: leftButtonInColumn,
        rowLeftButton: leftButtonInColumn ? nil : leftButton,
        rowRightButtons: rowRightButtons,
        rowCircleItem: rowCircleItem
    )
}

/// The side column's "…" menu: the column buttons that did not fit, each running its own button's action.
func navigationBarOverflowItems(placement: NavigationBarButtonPlacement) -> [NavigationBarComponent.OverflowItem] {
    guard let columnLayout = placement.columnLayout else {
        return []
    }
    return columnLayout.overflowItems.map { index in
        let item = placement.columnItems[index]
        return NavigationBarComponent.OverflowItem(id: item.id, title: item.overflow?.title ?? "", iconName: item.overflow?.iconName, image: item.overflow?.image, action: item.action)
    }
}

/// The tint a capsule takes from its buttons: theirs when they all share one, else generic.
func navigationBarCapsuleTint(_ buttons: [NavigationBarComponent.Button]) -> NavigationBarComponent.Button.Tint {
    guard let first = buttons.first else {
        return .generic
    }
    return buttons.allSatisfy({ $0.tint == first.tint }) ? first.tint : .generic
}

/// The glass of a capsule or circle with `tint`, as the old glass bar drew it.
func navigationBarGlassTintColor(_ tint: NavigationBarComponent.Button.Tint, theme: NavigationBarTheme) -> GlassBackgroundView.TintColor {
    switch tint {
    case .generic:
        return .init(kind: theme.glassStyle == .clear ? .clear : .panel)
    case .accent:
        return .init(kind: .custom(style: theme.glassStyle == .clear ? .clear : .default, color: theme.accentButtonColor))
    case .accentDisabled:
        return .init(kind: .custom(style: theme.glassStyle == .clear ? .clear : .default, color: theme.accentDisabledButtonColor))
    }
}

/// A button's content color. Accent buttons draw on their accent capsule in the accent foreground color; a disabled
/// text button takes the disabled color while images keep theirs, as the old bar drew them.
func navigationButtonContentColor(theme: NavigationBarTheme, tint: NavigationBarComponent.Button.Tint, isEnabled: Bool, isText: Bool) -> UIColor {
    switch tint {
    case .generic:
        return (isText && !isEnabled) ? theme.disabledButtonColor : theme.buttonColor
    case .accent, .accentDisabled:
        return (isText && !isEnabled) ? theme.accentForegroundColor.withMultipliedAlpha(0.5) : theme.accentForegroundColor
    }
}

/// The width a centered title may take: the row narrowed symmetrically to clear the wider side's buttons.
/// `leftExtent` / `rightExtent` run from each edge to the end of that side's buttons, inset included.
func navigationBarTitleAvailableWidth(rowWidth: CGFloat, leftExtent: CGFloat, rightExtent: CGFloat) -> CGFloat {
    let commonInset: CGFloat = max(leftExtent, rightExtent) + 8.0
    return rowWidth - commonInset * 2.0
}

/// `size` centered in a row of `rowSize`, on whole points.
func navigationBarCenteredFrame(size: CGSize, rowSize: CGSize) -> CGRect {
    return CGRect(origin: CGPoint(x: floor((rowSize.width - size.width) / 2.0), y: floor((rowSize.height - size.height) / 2.0)), size: size)
}

/// The band the chat list's story list centers its title in, measured from the row's edges (each side includes
/// its own inset; they differ where the system reserves one side, e.g. iPhone Duo's vertical status bar). With the
/// standard 16pt inset these equal the former `nextLeftButtonX + 4.0` / `nextRightButtonX + 20.0`.
func navigationBarCenterContentInsets(leftExtent: CGFloat, rightExtent: CGFloat) -> (left: CGFloat, right: CGFloat) {
    return (leftExtent - 12.0, rightExtent + 4.0)
}

public extension NavigationBarComponent {
    /// iPhone Duo: the frame the side column's shapes (back circle, capsule, trailing circle) span for `content` in a
    /// column of `columnLength`, in the column's coordinates: what `View.update` lays out. Nil when `content` puts
    /// nothing in the column, or the column cannot hold what must stay (every button is then in the row).
    static func sideColumnContentFrame(content: Content, columnLength: CGFloat) -> CGRect? {
        let placement = navigationBarButtonPlacement(leftButton: content.leftButton, rightButtons: content.rightButtons, hasBack: content.back != nil, columnLength: columnLength)
        guard let columnLayout = placement.columnLayout else {
            return nil
        }
        var frames: [CGRect] = []
        if content.back != nil, let backFrame = columnLayout.backFrame {
            frames.append(backFrame)
        }
        if let capsuleFrame = columnLayout.capsuleFrame {
            frames.append(capsuleFrame)
        }
        if placement.trailingCircleItem != nil, let trailingFrame = columnLayout.trailingFrame {
            frames.append(trailingFrame)
        }
        guard var result = frames.first else {
            return nil
        }
        for frame in frames.dropFirst() {
            result = result.union(frame)
        }
        return result
    }
}
