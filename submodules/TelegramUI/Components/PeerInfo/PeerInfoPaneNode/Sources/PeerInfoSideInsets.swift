import Foundation
import UIKit
import Display

/// The profile screen's horizontal insets. Symmetric on every device except iPhone Duo, whose status
/// corner widens into a side strip on one side (`ContainerViewLayout.sideStrip(edge:)`); everything is
/// kept out of that strip. Without a strip every value is today's.
public struct PeerInfoSideInsets: Equatable {
    /// Today's symmetric margin of the sections and the header.
    public var base: CGFloat
    /// The safe inset of a side that has a strip, else 0.
    public var stripLeft: CGFloat
    public var stripRight: CGFloat
    /// The side safe insets: the navigation row sits between them.
    public var navigationLeft: CGFloat
    public var navigationRight: CGFloat
    /// Section margins: the base, widened on a strip's side to clear it by 16pt.
    public var sectionLeft: CGFloat
    public var sectionRight: CGFloat
    /// The single inset each pane applies to both sides: the left safe inset without a strip, 0 with one
    /// (the pane container keeps the panes out of the strip).
    public var paneSideInset: CGFloat

    public init(base: CGFloat, stripLeft: CGFloat, stripRight: CGFloat, navigationLeft: CGFloat, navigationRight: CGFloat, sectionLeft: CGFloat, sectionRight: CGFloat, paneSideInset: CGFloat) {
        self.base = base
        self.stripLeft = stripLeft
        self.stripRight = stripRight
        self.navigationLeft = navigationLeft
        self.navigationRight = navigationRight
        self.sectionLeft = sectionLeft
        self.sectionRight = sectionRight
        self.paneSideInset = paneSideInset
    }
}

public func peerInfoSideInsets(layout: ContainerViewLayout) -> PeerInfoSideInsets {
    let base: CGFloat = layout.size.width >= 320.0 ? max(16.0, floor((layout.size.width - 674.0) / 2.0)) : 0.0
    let stripLeft: CGFloat = layout.sideStrip(edge: .left) != nil ? layout.safeInsets.left : 0.0
    let stripRight: CGFloat = layout.sideStrip(edge: .right) != nil ? layout.safeInsets.right : 0.0
    let hasStrip = stripLeft > 0.0 || stripRight > 0.0
    return PeerInfoSideInsets(
        base: base,
        stripLeft: stripLeft,
        stripRight: stripRight,
        navigationLeft: layout.safeInsets.left,
        navigationRight: layout.safeInsets.right,
        sectionLeft: stripLeft > 0.0 ? max(base, stripLeft + 16.0) : base,
        sectionRight: stripRight > 0.0 ? max(base, stripRight + 16.0) : base,
        paneSideInset: hasStrip ? 0.0 : layout.safeInsets.left
    )
}

/// The panes stop at a side strip, so a touch in the strip lands on the pane container and the profile's
/// scroll view would take the drag (collapsing expanded panes). The pane beside the strip takes it instead,
/// as it did while panes reached into the strip: the point moved into `paneFrame` at the same height, or
/// nil when the point is not in a strip beside the pane.
public func peerInfoStripTouchForwardingPoint(_ point: CGPoint, containerWidth: CGFloat, stripLeft: CGFloat, stripRight: CGFloat, paneFrame: CGRect) -> CGPoint? {
    let inLeftStrip = stripLeft > 0.0 && point.x < stripLeft
    let inRightStrip = stripRight > 0.0 && point.x >= containerWidth - stripRight
    if !(inLeftStrip || inRightStrip) || paneFrame.width < 1.0 {
        return nil
    }
    if point.y < paneFrame.minY || point.y >= paneFrame.maxY {
        return nil
    }
    return CGPoint(x: max(paneFrame.minX, min(point.x, paneFrame.maxX - 1.0)), y: point.y)
}

/// The gifts cover's exclusion rectangles at the sides: the navigation buttons, and on a layout with a
/// strip the strip over the cover's whole height. With a strip the navigation row sits between the side
/// safe insets; without one the buttons are taken at the screen edges, as before.
public func peerInfoGiftsCoverSideExclusionRects(width: CGFloat, height: CGFloat, statusBarHeight: CGFloat, topLeftButtonsSize: CGSize, topRightButtonsSize: CGSize, sideInsets: PeerInfoSideInsets) -> [CGRect] {
    let hasStrip = sideInsets.stripLeft > 0.0 || sideInsets.stripRight > 0.0
    let buttonsLeft: CGFloat = hasStrip ? sideInsets.navigationLeft : 0.0
    let buttonsRight: CGFloat = hasStrip ? sideInsets.navigationRight : 0.0
    var rects: [CGRect] = [
        CGRect(origin: CGPoint(x: buttonsLeft, y: statusBarHeight), size: topLeftButtonsSize),
        CGRect(origin: CGPoint(x: width - buttonsRight - topRightButtonsSize.width, y: statusBarHeight), size: topRightButtonsSize)
    ]
    if sideInsets.stripLeft > 0.0 {
        rects.append(CGRect(x: 0.0, y: 0.0, width: sideInsets.stripLeft, height: height))
    }
    if sideInsets.stripRight > 0.0 {
        rects.append(CGRect(x: width - sideInsets.stripRight, y: 0.0, width: sideInsets.stripRight, height: height))
    }
    return rects
}
