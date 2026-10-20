import Foundation
import UIKit
import Display
import GlassBackgroundComponent
import SideColumnLayout

/// UIKit's gap between two platters of one side of the bar (`NavigationButtonBar.Layout.Metrics.interSectionSpacing`,
/// read on iOS 27): between two right pills.
let navigationBarInterSectionSpacing: CGFloat = 12.0

/// One right pill of the row as laid out: its width, and its extent, how far it takes the pills inside it in from the
/// edge (its width and UIKit's gap before the next pill; the innermost pill's extent is its width).
struct NavigationBarRightPillMetrics: Equatable {
    var width: CGFloat
    var extent: CGFloat
}

/// The metrics of pills `widths` wide, outermost first.
func navigationBarRightPillMetrics(widths: [CGFloat]) -> [NavigationBarRightPillMetrics] {
    return widths.enumerated().map { index, width in
        return NavigationBarRightPillMetrics(width: width, extent: index == widths.count - 1 ? width : width + navigationBarInterSectionSpacing)
    }
}

/// How far a content's right pills reach from its inset.
func navigationBarRightButtonsExtent(_ pills: [NavigationBarRightPillMetrics]) -> CGFloat {
    return pills.reduce(0.0, { $0 + $1.extent })
}

/// The slots two contents' pills share while one slides over the other (an inline forum over Chats), outermost first,
/// paired from the inner end: each slot's pill index in either content, nil where that content has no pill there.
func navigationBarRightPillSlots(primaryCount: Int, secondaryCount: Int) -> [(primary: Int?, secondary: Int?)] {
    let count = max(primaryCount, secondaryCount)
    return (0 ..< count).map { slot in
        let primary = slot - (count - primaryCount)
        let secondary = slot - (count - secondaryCount)
        return (primary >= 0 ? primary : nil, secondary >= 0 ? secondary : nil)
    }
}

/// The pills of a slide `fraction` of the way from `primary` to `secondary`: each slot's width and extent interpolated,
/// a pill only one content has growing from, or narrowing to, nothing at its place.
func navigationBarInterpolatedRightPills(primary: [NavigationBarRightPillMetrics], secondary: [NavigationBarRightPillMetrics], fraction: CGFloat) -> [NavigationBarRightPillMetrics] {
    return navigationBarRightPillSlots(primaryCount: primary.count, secondaryCount: secondary.count).map { slot in
        let from = slot.primary.map { primary[$0] } ?? NavigationBarRightPillMetrics(width: 0.0, extent: 0.0)
        let to = slot.secondary.map { secondary[$0] } ?? NavigationBarRightPillMetrics(width: 0.0, extent: 0.0)
        return NavigationBarRightPillMetrics(width: from.width * (1.0 - fraction) + to.width * fraction, extent: from.extent * (1.0 - fraction) + to.extent * fraction)
    }
}

/// iPhone Duo: whether a button goes into the side column. Icon, image, more and custom buttons do; text buttons stay
/// in the row (Apple: text-only items stay horizontal). A screen's node rides in its button's view, which the bar alone
/// hosts, so it can move with it; it does when it fits a column cell (the chat's avatar and "…", a spinner), and a
/// node that draws text (Calls' "Delete All", a mini app's "Close") stays in the row, where the column would cut it.
/// A button marked `staysInRow` (the Done of an Edit/Done toggle) stays in the row with the text button it replaces.
func navigationBarIsColumnItem(_ button: NavigationBarComponent.Button) -> Bool {
    if button.staysInRow {
        return false
    }
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
/// prominent one (the Done checkmark included); false for image, system-image and custom-view items, unless the button
/// asks for one (`Button.requiresOwnSection`, UIKit's `sharesBackground = false`).
func navigationBarButtonRequiresOwnSection(_ button: NavigationBarComponent.Button) -> Bool {
    if button.requiresOwnSection {
        return true
    }
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
    /// The row's right pills by UIKit's rule (`navigationBarRightSections`), outermost first.
    var rowRightSections: [[NavigationBarComponent.Button]]
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
    let rowRightButtons = columnLayout != nil ? rightButtons.filter { !navigationBarIsColumnItem($0) } : rightButtons
    return NavigationBarButtonPlacement(
        columnLayout: columnLayout,
        columnItems: columnItems,
        trailingCircleItem: trailingCircleItem,
        leftButtonInColumn: leftButtonInColumn,
        rowLeftButton: leftButtonInColumn ? nil : leftButton,
        rowRightSections: navigationBarRightSections(rowRightButtons)
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

/// The glass of a capsule or circle with `tint`, as the old glass bar drew it: a generic one takes the theme's glass
/// tint when it has one.
func navigationBarGlassTintColor(_ tint: NavigationBarComponent.Button.Tint, theme: NavigationBarTheme) -> GlassBackgroundView.TintColor {
    switch tint {
    case .generic:
        if let glassTintColor = theme.glassTintColor {
            return .init(kind: .custom(style: theme.glassStyle == .clear ? .clear : .default, color: glassTintColor))
        }
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
/// its own inset; they differ where the system reserves one side, e.g. iPhone Duo's vertical status bar): 4 pt clear
/// of each side's capsules. (The left used to be the text-button bar's `nextLeftButtonX + 4.0`, 12 pt under the left
/// capsule.)
func navigationBarCenterContentInsets(leftExtent: CGFloat, rightExtent: CGFloat) -> (left: CGFloat, right: CGFloat) {
    return (leftExtent + 4.0, rightExtent + 4.0)
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
