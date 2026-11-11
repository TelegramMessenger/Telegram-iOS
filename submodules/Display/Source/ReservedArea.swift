import UIKit

/// The block the system reserves in each corner of a layout (iPhone Duo's status corner), measured
/// from that corner: `width` along the horizontal edge, `height` along the vertical one. `nil` means
/// the corner is free. Additional to `ContainerViewLayout.safeInsets`, which are unchanged.
public struct ContainerViewLayoutCorners: Equatable {
    public var topLeft: CGSize?
    public var topRight: CGSize?
    public var bottomLeft: CGSize?
    public var bottomRight: CGSize?

    public init(topLeft: CGSize?, topRight: CGSize?, bottomLeft: CGSize?, bottomRight: CGSize?) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    public static let none = ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: nil)

    /// For a layout whose top edge sits `topInset` below this layout's top edge (a sheet below the
    /// status bar): a top block keeps the part that reaches below that edge, and is dropped when it
    /// ends above it. iPhone Duo's status block is up to 170pt tall, so it overlaps a sheet's top corner.
    public func offsettingTop(by topInset: CGFloat) -> ContainerViewLayoutCorners {
        func offset(_ size: CGSize?) -> CGSize? {
            guard let size else {
                return nil
            }
            let height = size.height - topInset
            return height > 0.0 ? CGSize(width: size.width, height: height) : nil
        }
        return ContainerViewLayoutCorners(topLeft: offset(self.topLeft), topRight: offset(self.topRight), bottomLeft: self.bottomLeft, bottomRight: self.bottomRight)
    }
}

private let reservedAreaEdgeTolerance: CGFloat = 0.5

private func portraitSize(_ size: CGSize) -> CGSize {
    return CGSize(width: min(size.width, size.height), height: max(size.width, size.height))
}

private func matchesSize(_ lhs: CGSize, _ rhs: CGSize) -> Bool {
    return abs(lhs.width - rhs.width) <= 1.0 && abs(lhs.height - rhs.height) <= 1.0
}

/// iPhone Duo (iPhone19,4): the block the system status corner reserves, per posture, as the simulator settled on it.
///
/// The table names the posture: which corner holds the block. Its sizes are what a layout gets only while the system's
/// own report does not fit that posture (`iPhoneDuoReservedArea`), which happens for up to 0.6s after every rotation
/// and fold. The screen is identified by the window's own size: only a window that fills a screen gets corners, and
/// during an unfold the scene still reports the cover screen when `updateSize` runs. Anything else gets `.none`, which
/// is safe because `safeInsets` already keeps content clear of the status corner along a full edge.
func iPhoneDuoReservedCorners(windowSize: CGSize, orientation: UIInterfaceOrientation) -> ContainerViewLayoutCorners {
    // The size decides portrait vs landscape; the orientation only tells the two landscapes apart.
    // It can be stale (the window layout keeps the orientation of its last size change, and a
    // launch can report portrait for a landscape window), so it is not trusted against the size.
    let window = portraitSize(windowSize)
    let isLandscape = windowSize.width > windowSize.height
    if matchesSize(window, CGSize(width: 466.0, height: 678.0)) {
        if !isLandscape {
            if orientation == .portraitUpsideDown {
                return .none
            }
            return ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil)
        }
        switch orientation {
        case .landscapeLeft:
            return ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: CGSize(width: 84.0, height: 82.0))
        case .landscapeRight:
            // The union of the 82x84 the system once settled at and the 84x82 it settles at now (and showed during a
            // rotation and as the hinge starts to open then).
            return ContainerViewLayoutCorners(topLeft: CGSize(width: 84.0, height: 84.0), topRight: nil, bottomLeft: nil, bottomRight: nil)
        default:
            // Which landscape is unknown; the next layout pass reads the orientation again.
            return .none
        }
    } else if matchesSize(window, CGSize(width: 669.0, height: 951.0)) {
        if !isLandscape {
            // Upside-down too: the simulator's portrait for the unfolded screen reports `.portraitUpsideDown`, and the
            // block is still at the top-right with a 82pt top inset (measured 2026-10-08).
            return ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 134.0, height: 82.0), bottomLeft: nil, bottomRight: nil)
        }
        // Both landscapes put the block in the top-right corner.
        return ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 120.0), bottomLeft: nil, bottomRight: nil)
    }
    return .none
}

public extension DeviceMetrics {
    /// iPhone Duo: whether a layout of `size` fills the unfolded inner screen (669x951, either orientation), a phone
    /// screen as large as a small tablet's, rather than the cover screen. False on every other device.
    func isIPhoneDuoInnerScreen(size: CGSize) -> Bool {
        guard case .iPhoneDuo = self else {
            return false
        }
        return matchesSize(portraitSize(size), CGSize(width: 669.0, height: 951.0))
    }

    /// The device position, as `UIDevice.orientation` reports it, in which the portrait of the screen showing a window of
    /// `size` reads upright. `UIDevice.orientation` is measured against the device body on both of iPhone Duo's screens,
    /// while a window's interface orientation is measured against its own screen, and the inner screen's portrait is the
    /// body held in landscape-left (measured on an iPhone19,4, iOS 27.1, with `AVCaptureDevice.RotationCoordinator`: in
    /// the inner screen's portrait the coordinator's capture angle is the one the cover screen gets in landscape-left,
    /// and the inner screen's landscape-right is the body upside down). Portrait on every other device and screen.
    func screenPortraitDeviceOrientation(size: CGSize) -> UIDeviceOrientation {
        if self.isIPhoneDuoInnerScreen(size: size) {
            return .landscapeLeft
        }
        return .portrait
    }
}

/// `DeviceMetrics.screenPortraitDeviceOrientation(size:)` for a view that reads its window rather than a layout (a camera
/// preview setting its connection's orientation from the window scene): on the device the app runs on, the body position
/// in which the portrait of the screen showing a window of `size` reads upright. Portrait on every device but iPhone Duo.
public func screenPortraitDeviceOrientationForWindow(size: CGSize) -> UIDeviceOrientation {
    guard DeviceMetrics.hasMultipleDisplays else {
        return .portrait
    }
    return DeviceMetrics.iPhoneDuo.screenPortraitDeviceOrientation(size: size)
}

/// The reserved corners for a full-screen layout built outside the window's own layout pass (a legacy host that hands
/// a size and insets to a Display screen), as the window's own layout gets them (`iPhoneDuoReservedArea`): iPhone
/// Duo's status corners for a window of `size` in `orientation`, `.none` on every other device.
public func reservedCornersForHostedLayout(size: CGSize, orientation: UIInterfaceOrientation) -> ContainerViewLayoutCorners {
    guard DeviceMetrics.hasMultipleDisplays else {
        return .none
    }
    // The system's report comes from the app's window when the hosted layout fills it and the report has settled, as
    // for the window's own layout.
    var systemSafeInsets = UIEdgeInsets()
    var systemOcclusions: [CGRect] = []
    if iPhoneDuoSystemReportIsSettled, let window = registeredMainWindow, matchesSize(window.bounds.size, size) {
        systemSafeInsets = window.safeAreaInsets
        systemOcclusions = activeOcclusionFrames(in: window)
    }
    return iPhoneDuoReservedArea(windowSize: size, orientation: orientation, systemSafeInsets: systemSafeInsets, systemOcclusions: systemOcclusions).corners
}

/// iPhone Duo: how long the system's reserved regions and safe insets stay transitional after a rotation or a fold. The
/// longest measured on the simulator was 0.65s (an unfold: the cover's block, then the island rotated into the top-left
/// corner); folded landscape-left to portrait reported landscape's block in portrait's corner for 47ms, which fits
/// portrait's posture.
let iPhoneDuoSystemReportSettleDelay: Double = 0.7

private var iPhoneDuoSystemReportUnsettledUntil: Double = 0.0

/// Notes that the window's posture changes (it rotates, or moves to the other screen): the system's report is not taken
/// for `iPhoneDuoSystemReportSettleDelay`, and the table's settled sizes stand in.
func iPhoneDuoPostureWillChange() {
    iPhoneDuoSystemReportUnsettledUntil = CACurrentMediaTime() + iPhoneDuoSystemReportSettleDelay
}

/// Whether the system's report has settled since the window's posture last changed.
var iPhoneDuoSystemReportIsSettled: Bool {
    return CACurrentMediaTime() >= iPhoneDuoSystemReportUnsettledUntil
}

/// The frames of the occlusion regions the system reports as active in `view` (iPhone Duo's status corner and its
/// camera), in the view's coordinates. Empty before iOS 27.1.
func activeOcclusionFrames(in view: UIView) -> [CGRect] {
    if #available(iOS 27.1, *) {
        return view.reservedRegions(kind: .occlusion).filter(\.isActive).map(\.frame)
    }
    return []
}

/// iPhone Duo (iPhone19,4): a window's status corner block and safe insets, at the size the system gives them.
///
/// The posture comes from the table (`iPhoneDuoReservedCorners`, `iPhoneDuoSafeInsets`): which corner holds the block
/// and which edge's inset the system widens it into. The sizes come from the system when its report fits that
/// posture: an active occlusion region that fills the table's corner, as thick as the system's own safe inset on that
/// edge, with no inset on the other edges. The block is the system's to size, not the device's: what the clock and
/// the camera take can change without a new device (measured on the simulator: the folded landscape-right block,
/// tabulated as 84x84 after it settled at 82x84, now settles at 84x82).
///
/// For up to 0.65s after every rotation and fold the system reports something else (measured on the simulator: the
/// previous posture's block or insets, a stray block, none), and the table's sizes stand in. Most such reports do not
/// fit the posture; one that does (folded landscape's 84x82 block in folded portrait's corner, beside portrait's inset)
/// is kept out by not passing the system's report until it has settled (`iPhoneDuoSystemReportIsSettled`). The safe
/// insets are nil where the table does not know the posture (the live insets apply, with the table's corners).
func iPhoneDuoReservedArea(windowSize: CGSize, orientation: UIInterfaceOrientation, systemSafeInsets: UIEdgeInsets, systemOcclusions: [CGRect]) -> (safeInsets: UIEdgeInsets?, corners: ContainerViewLayoutCorners) {
    let tableCorners = iPhoneDuoReservedCorners(windowSize: windowSize, orientation: orientation)
    guard let tableInsets = iPhoneDuoSafeInsets(windowSize: windowSize, orientation: orientation) else {
        return (nil, tableCorners)
    }
    let tolerance = reservedAreaEdgeTolerance

    enum Corner {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
    let corner: Corner
    if tableCorners.topLeft != nil {
        corner = .topLeft
    } else if tableCorners.topRight != nil {
        corner = .topRight
    } else if tableCorners.bottomLeft != nil {
        corner = .bottomLeft
    } else if tableCorners.bottomRight != nil {
        corner = .bottomRight
    } else {
        return (tableInsets, tableCorners)
    }

    // The system's insets must be on the posture's edge alone; the bottom is the home indicator's.
    let insetsFitPosture = (tableInsets.top > 0.0) == (systemSafeInsets.top > tolerance) && (tableInsets.left > 0.0) == (systemSafeInsets.left > tolerance) && (tableInsets.right > 0.0) == (systemSafeInsets.right > tolerance)
    if !insetsFitPosture {
        return (tableInsets, tableCorners)
    }

    let block = systemOcclusions.first(where: { frame in
        if frame.width <= 0.0 || frame.height <= 0.0 {
            return false
        }
        let fillsCorner: Bool
        switch corner {
        case .topLeft:
            fillsCorner = abs(frame.minX) <= tolerance && abs(frame.minY) <= tolerance
        case .topRight:
            fillsCorner = abs(frame.maxX - windowSize.width) <= tolerance && abs(frame.minY) <= tolerance
        case .bottomLeft:
            fillsCorner = abs(frame.minX) <= tolerance && abs(frame.maxY - windowSize.height) <= tolerance
        case .bottomRight:
            fillsCorner = abs(frame.maxX - windowSize.width) <= tolerance && abs(frame.maxY - windowSize.height) <= tolerance
        }
        if !fillsCorner {
            return false
        }
        // As thick as the inset the system widens it into: a block of another posture is not.
        if tableInsets.top > 0.0 {
            return abs(frame.height - systemSafeInsets.top) <= tolerance
        } else if tableInsets.left > 0.0 {
            return abs(frame.width - systemSafeInsets.left) <= tolerance
        } else {
            return abs(frame.width - systemSafeInsets.right) <= tolerance
        }
    })
    guard let block else {
        return (tableInsets, tableCorners)
    }

    let size = block.size
    let corners: ContainerViewLayoutCorners
    switch corner {
    case .topLeft:
        corners = ContainerViewLayoutCorners(topLeft: size, topRight: nil, bottomLeft: nil, bottomRight: nil)
    case .topRight:
        corners = ContainerViewLayoutCorners(topLeft: nil, topRight: size, bottomLeft: nil, bottomRight: nil)
    case .bottomLeft:
        corners = ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: size, bottomRight: nil)
    case .bottomRight:
        corners = ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: size)
    }
    return (UIEdgeInsets(top: systemSafeInsets.top, left: systemSafeInsets.left, bottom: 0.0, right: systemSafeInsets.right), corners)
}

/// iPhone Duo (iPhone19,4): the safe insets per posture, as the simulator settled on them (bottom 0: the home
/// indicator is carried by the on-screen navigation height). Like the corner table, they apply while the system's
/// report does not fit the posture (`iPhoneDuoReservedArea`): the system's insets lag behind rotations and folds
/// (measured `t82` on the landscape inner screen after an unfold, and portrait's `t82 r0` kept after rotating the
/// inner screen back to landscape), and a stale inset paired with the posture's corners loses the side strip. Nil
/// for a window of another size or a posture the table does not list, which keeps the live system insets.
func iPhoneDuoSafeInsets(windowSize: CGSize, orientation: UIInterfaceOrientation) -> UIEdgeInsets? {
    // As `iPhoneDuoReservedCorners`: the size decides portrait vs landscape, the orientation only tells
    // the two landscapes apart.
    let window = portraitSize(windowSize)
    let isLandscape = windowSize.width > windowSize.height
    if matchesSize(window, CGSize(width: 466.0, height: 678.0)) {
        if !isLandscape {
            if orientation == .portraitUpsideDown {
                return nil
            }
            return UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)
        }
        switch orientation {
        case .landscapeLeft:
            return UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)
        case .landscapeRight:
            return UIEdgeInsets(top: 0.0, left: 84.0, bottom: 0.0, right: 0.0)
        default:
            return nil
        }
    } else if matchesSize(window, CGSize(width: 669.0, height: 951.0)) {
        if !isLandscape {
            // As the corner table: upside-down is the same posture on the unfolded screen (measured).
            return UIEdgeInsets(top: 82.0, left: 0.0, bottom: 0.0, right: 0.0)
        }
        return UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)
    }
    return nil
}

/// iPhone Duo (iPhone19,4): the screen's corner radii in a window that fills it, per posture. The cover
/// screen's corners are 8pt on the hinge side and 59pt on the outer side (the simulator profile's
/// `cornerRadiusUL/UR/LL/LR` for its "primary" display; native portrait has the hinge on the left); the
/// inner screen's are all 55pt. The two cover landscapes are told apart by the side strip (right in
/// landscape-left, left in landscape-right), which layouts derived from the window keep. Nil when the
/// side is unknown or the window does not fill a screen.
func iPhoneDuoScreenCornerRadii(windowSize: CGSize, safeInsets: UIEdgeInsets) -> CornerRadii? {
    let window = portraitSize(windowSize)
    let isLandscape = windowSize.width > windowSize.height
    if matchesSize(window, CGSize(width: 466.0, height: 678.0)) {
        let hinge: CGFloat = 8.0
        let outer: CGFloat = 59.0
        if !isLandscape {
            return CornerRadii(topLeft: hinge, topRight: outer, bottomLeft: hinge, bottomRight: outer)
        }
        if safeInsets.right > 0.0 && safeInsets.left.isZero {
            // Landscape-left: the native top-right status corner is at the bottom right, the hinge on top.
            return CornerRadii(topLeft: hinge, topRight: hinge, bottomLeft: outer, bottomRight: outer)
        } else if safeInsets.left > 0.0 && safeInsets.right.isZero {
            return CornerRadii(topLeft: outer, topRight: outer, bottomLeft: hinge, bottomRight: hinge)
        }
        return nil
    } else if matchesSize(window, CGSize(width: 669.0, height: 951.0)) {
        return CornerRadii(uniform: 55.0)
    }
    return nil
}

/// iPhone Duo (iPhone19,4): the fold, from the system's reported active division, accepted only on
/// the inner screen and only when it crosses the whole window. While folding, the system briefly
/// reports the inner screen's fold in the cover screen's coordinates (measured: (455.5, -203) on
/// the 678x466 cover for 66ms); a fold that does not span the window is such a leftover.
func iPhoneDuoDivision(windowSize: CGSize, reported: CGRect?) -> CGRect? {
    guard let reported, matchesSize(portraitSize(windowSize), CGSize(width: 669.0, height: 951.0)) else {
        return nil
    }
    let tolerance = reservedAreaEdgeTolerance
    let spansHeight = reported.minY <= tolerance && reported.maxY >= windowSize.height - tolerance
    let spansWidth = reported.minX <= tolerance && reported.maxX >= windowSize.width - tolerance
    return spansHeight || spansWidth ? reported : nil
}

/// The part of a layout's reserved area that belongs to a pane at `paneFrame` inside it: a corner is
/// kept only when the pane reaches that corner of the container, and the division is translated
/// into the pane's coordinates and dropped when it does not cross the pane.
func reservedAreaForPane(corners: ContainerViewLayoutCorners, division: CGRect?, paneFrame: CGRect, containerSize: CGSize) -> (corners: ContainerViewLayoutCorners, division: CGRect?) {
    let tolerance = reservedAreaEdgeTolerance
    let reachesLeft = paneFrame.minX <= tolerance
    let reachesRight = paneFrame.maxX >= containerSize.width - tolerance
    let reachesTop = paneFrame.minY <= tolerance
    let reachesBottom = paneFrame.maxY >= containerSize.height - tolerance

    let paneCorners = ContainerViewLayoutCorners(
        topLeft: reachesTop && reachesLeft ? corners.topLeft : nil,
        topRight: reachesTop && reachesRight ? corners.topRight : nil,
        bottomLeft: reachesBottom && reachesLeft ? corners.bottomLeft : nil,
        bottomRight: reachesBottom && reachesRight ? corners.bottomRight : nil
    )

    var paneDivision: CGRect?
    if let division {
        let translated = division.offsetBy(dx: -paneFrame.minX, dy: -paneFrame.minY)
        if translated.intersects(CGRect(origin: .zero, size: paneFrame.size)) {
            paneDivision = translated
        }
    }
    return (paneCorners, paneDivision)
}

public enum ContainerViewLayoutSideEdge: Equatable {
    case left
    case right
}

public extension ContainerViewLayout {
    /// The part of a side edge's safe inset that the system reserves only because of a corner block on
    /// that side (iPhone Duo's status corner), without the block(s), in this layout's coordinates. The
    /// system widens such a block into a full-edge inset; the rest of that inset is free for controls
    /// that stop at the block. Nil when the edge has no inset, or its inset is not the width of a corner
    /// block on that side (the inset has another cause).
    func sideStrip(edge: ContainerViewLayoutSideEdge) -> CGRect? {
        let inset: CGFloat
        let topBlock: CGSize?
        let bottomBlock: CGSize?
        switch edge {
        case .left:
            inset = self.safeInsets.left
            topBlock = self.reservedCorners.topLeft
            bottomBlock = self.reservedCorners.bottomLeft
        case .right:
            inset = self.safeInsets.right
            topBlock = self.reservedCorners.topRight
            bottomBlock = self.reservedCorners.bottomRight
        }
        if inset <= 0.0 {
            return nil
        }
        func hasInsetWidth(_ block: CGSize?) -> Bool {
            guard let block else {
                return false
            }
            return abs(block.width - inset) <= 1.0
        }
        if !hasInsetWidth(topBlock) && !hasInsetWidth(bottomBlock) {
            return nil
        }
        let minY = topBlock?.height ?? 0.0
        let maxY = self.size.height - (bottomBlock?.height ?? 0.0)
        if maxY <= minY {
            return nil
        }
        let x: CGFloat
        switch edge {
        case .left:
            x = 0.0
        case .right:
            x = self.size.width - inset
        }
        return CGRect(x: x, y: minY, width: inset, height: maxY - minY)
    }
}

public extension ContainerViewLayout {
    /// The side insets a horizontal band from `minY` to `maxY` needs. A side whose safe inset exists only
    /// because of corner blocks on that side (a block whose width is within 1pt of the inset, the test
    /// `sideStrip(edge:)` uses) needs that inset where one of its blocks reaches into the band, and none
    /// where none does; any other side keeps its safe inset. iPhone Duo's input panel runs into the strip
    /// beside a free bottom corner.
    func sideInsets(forBandFrom minY: CGFloat, to maxY: CGFloat) -> (left: CGFloat, right: CGFloat) {
        return bandSideInsets(forBandFrom: minY, to: maxY, containerHeight: self.size.height, safeInsets: self.safeInsets, reservedCorners: self.reservedCorners)
    }

    /// The side insets of a button or panel anchored to the bottom edge (`sideInsets(forBandFrom:to:)` for the bottom
    /// row): beside iPhone Duo's side strip a side keeps its inset only where its corner block is at the bottom (folded
    /// landscape-left), so a bottom action button spans the strip elsewhere. Equal to `safeInsets` on every other device.
    func bottomEdgeSideInsets() -> (left: CGFloat, right: CGFloat) {
        return bandSideInsets(forBandFrom: self.size.height - 1.0, to: self.size.height, containerHeight: self.size.height, safeInsets: self.safeInsets, reservedCorners: self.reservedCorners)
    }

    /// The screen's four corner radii in this layout's coordinates. They differ per corner on iPhone Duo's
    /// cover screen; every other screen, and a layout that does not fill one, has the device's uniform
    /// `screenCornerRadius`.
    var screenCornerRadii: CornerRadii {
        if case .iPhoneDuo = self.deviceMetrics, let radii = iPhoneDuoScreenCornerRadii(windowSize: self.size, safeInsets: self.safeInsets) {
            return radii
        }
        return CornerRadii(uniform: self.deviceMetrics.screenCornerRadius)
    }

    /// A list's side margins: `base` on each side, and on a side with a side strip (iPhone Duo) at least
    /// 16pt clear of the strip. Without a strip both are `base`.
    func listSideMargins(base: CGFloat) -> (left: CGFloat, right: CGFloat) {
        let stripLeft: CGFloat = self.sideStrip(edge: .left) != nil ? self.safeInsets.left : 0.0
        let stripRight: CGFloat = self.sideStrip(edge: .right) != nil ? self.safeInsets.right : 0.0
        return (
            stripLeft.isZero ? base : max(base, stripLeft + 16.0),
            stripRight.isZero ? base : max(base, stripRight + 16.0)
        )
    }

    /// A list narrowed by `base` on each side (a centred blocks-style list): its `left` and `width` in this layout,
    /// `listSideMargins(base:)` from the edges, and the safe insets its rows still need. A side strip (iPhone Duo) is
    /// outside the list then, so that side's inset is 0; rows that fill the list's width with their background while
    /// their card stops at the inset would otherwise show the strip's width of background beside the card. Without
    /// a strip: `base` on each side and `safeInsets`.
    func centeredListPlacement(base: CGFloat) -> (left: CGFloat, width: CGFloat, safeInsets: UIEdgeInsets) {
        let margins = self.listSideMargins(base: base)
        var safeInsets = self.safeInsets
        if self.sideStrip(edge: .left) != nil {
            safeInsets.left = 0.0
        }
        if self.sideStrip(edge: .right) != nil {
            safeInsets.right = 0.0
        }
        return (margins.left, self.size.width - margins.left - margins.right, safeInsets)
    }

    /// Frames for a top-anchored column of `count` controls of `itemSize`, `spacing` apart, in the side
    /// strip (the right one if there is one, else the left), 22pt from the screen edge. The first control
    /// starts 8pt below a block above the strip, and never above `minY`. Nil without a strip, without
    /// controls, or when they do not fit above the strip's end (8pt clear of a block below it).
    func sideColumnFrames(itemSize: CGSize, spacing: CGFloat, count: Int, minY: CGFloat) -> (edge: ContainerViewLayoutSideEdge, frames: [CGRect])? {
        let outerMargin: CGFloat = 22.0
        let clearance: CGFloat = 8.0
        if count <= 0 {
            return nil
        }
        let edge: ContainerViewLayoutSideEdge
        let strip: CGRect
        if let rightStrip = self.sideStrip(edge: .right) {
            edge = .right
            strip = rightStrip
        } else if let leftStrip = self.sideStrip(edge: .left) {
            edge = .left
            strip = leftStrip
        } else {
            return nil
        }
        if strip.width < outerMargin + itemSize.width {
            return nil
        }
        let hasBlockAbove = strip.minY > 0.5
        let hasBlockBelow = strip.maxY < self.size.height - 0.5
        let top = max(hasBlockAbove ? strip.minY + clearance : strip.minY, minY)
        let limit = hasBlockBelow ? strip.maxY - clearance : strip.maxY
        let height = CGFloat(count) * itemSize.height + CGFloat(count - 1) * spacing
        if top + height > limit {
            return nil
        }
        let x: CGFloat
        switch edge {
        case .left:
            x = outerMargin
        case .right:
            x = self.size.width - outerMargin - itemSize.width
        }
        let frames = (0 ..< count).map { index in
            CGRect(x: x, y: top + CGFloat(index) * (itemSize.height + spacing), width: itemSize.width, height: itemSize.height)
        }
        return (edge, frames)
    }
    
    /// Where a screen's back or close button goes in the side strip: a 48pt circle at the top of the column,
    /// 8pt below the status bar at the least (the ItemList, chat and profile columns' back circle). Nil
    /// without a strip that holds it, and in a form sheet (the button stays in the navigation bar).
    var sideColumnNavigationButtonFrame: CGRect? {
        if self.presentedInFormSheet {
            return nil
        }
        return self.sideColumnFrames(itemSize: CGSize(width: 48.0, height: 48.0), spacing: 12.0, count: 1, minY: (self.statusBarHeight ?? 0.0) + 8.0)?.frames.first
    }
}

public extension ContainerViewLayout {
    /// Whether the status bar is a corner block rather than a bar across the top (iPhone Duo): nothing
    /// that stands in for the status bar, such as the window's scroll-to-top views, belongs across the top.
    var statusBarIsInCorner: Bool {
        return self.reservedCorners != .none
    }

    /// Whether a surface at `frame` (in this layout's coordinates) still covers part of a corner block, so that the
    /// status bar in it (iPhone Duo) shows over that surface rather than over what lies beneath. A modal card dragged
    /// down, or aside, stops covering the block only once it has left it entirely. False without corner blocks.
    func coversStatusCorner(frame: CGRect) -> Bool {
        let size = self.size
        let blocks: [CGRect] = [
            self.reservedCorners.topLeft.map { CGRect(origin: CGPoint(), size: $0) },
            self.reservedCorners.topRight.map { CGRect(origin: CGPoint(x: size.width - $0.width, y: 0.0), size: $0) },
            self.reservedCorners.bottomLeft.map { CGRect(origin: CGPoint(x: 0.0, y: size.height - $0.height), size: $0) },
            self.reservedCorners.bottomRight.map { CGRect(origin: CGPoint(x: size.width - $0.width, y: size.height - $0.height), size: $0) }
        ].compactMap { $0 }
        return blocks.contains(where: { block in
            let intersection = block.intersection(frame)
            return !intersection.isNull && intersection.width > 0.0 && intersection.height > 0.0
        })
    }
}

/// The x of an element `width` wide centered on `containerWidth`, shifted to stay within `minX...maxX`
/// when centering would cross a bound, and pinned to `minX` when it does not fit. Used where a side strip
/// (iPhone Duo) makes the side insets differ: a title stays centered on the screen while it fits.
public func horizontallyCenteredOrigin(width: CGFloat, containerWidth: CGFloat, minX: CGFloat, maxX: CGFloat) -> CGFloat {
    var x = floorToScreenPixels((containerWidth - width) / 2.0)
    if x + width > maxX {
        x = maxX - width
    }
    if x < minX {
        x = minX
    }
    return x
}

/// iPhone Duo: the status bar height layouts place their headers below. Where the status bar shares the top with a
/// corner block (the unfolded screen in portrait) the system reports it as a 2pt sliver while the block fills the
/// 82pt top inset, so a header placed below the sliver sits under the clock; it is never less than the top inset.
/// Nil stays nil (no status bar).
func iPhoneDuoStatusBarHeight(systemHeight: CGFloat?, safeInsetTop: CGFloat) -> CGFloat? {
    guard let systemHeight else {
        return nil
    }
    return max(systemHeight, safeInsetTop)
}

/// iPhone Duo, unfolded screen in portrait: the status bar height a horizontal top bar lays out below. The status
/// there is a corner island (134x82, top-right) rather than a bar across the top, so the bar stays near the top
/// beside the island, its trailing buttons moved clear of it, instead of starting below the island's 82pt.
/// 16 puts a default (60pt) bar's buttons on the island clock's centre line (measured on the simulator: clock text
/// 42.3...53.3pt, bar icons centred at 46-47pt).
let iPhoneDuoTopBarStatusBarHeight: CGFloat = 16.0

public extension ContainerViewLayout {
    /// The top-right corner block that stands beside a horizontal top bar (iPhone Duo's unfolded screen in
    /// portrait), or nil: no block, or a block at the end of a side strip, where the bar's controls move into the
    /// strip instead.
    var topBarStatusIsland: CGSize? {
        guard let topRight = self.reservedCorners.topRight, self.sideStrip(edge: .left) == nil, self.sideStrip(edge: .right) == nil else {
            return nil
        }
        return topRight
    }

    /// The status bar height a horizontal navigation bar lays out below: beside a status island the bar stays near
    /// the top (`iPhoneDuoTopBarStatusBarHeight`); everywhere else `statusBarHeight`.
    var navigationBarStatusBarHeight: CGFloat? {
        if self.topBarStatusIsland != nil, let statusBarHeight = self.statusBarHeight {
            return min(statusBarHeight, iPhoneDuoTopBarStatusBarHeight)
        }
        return self.statusBarHeight
    }

    /// How much further than the right safe inset a navigation bar's trailing buttons stay from the right edge,
    /// to clear a status island beside the bar. The title keeps centering on the screen while it fits.
    var navigationBarTrailingButtonsInset: CGFloat {
        if let island = self.topBarStatusIsland {
            return max(0.0, island.width - self.safeInsets.right)
        }
        return 0.0
    }
}

/// How far left a control at the top right of a sheet that rises and falls with scrolling moves to clear a top-right
/// status island (iPhone Duo, unfolded portrait), given where the control's row is now: all of `inset` once the row
/// reaches the island's bottom edge, sliding in over the row's own height as it approaches, nothing further down.
public func statusIslandTrailingShift(rowMinY: CGFloat, rowHeight: CGFloat, islandHeight: CGFloat, inset: CGFloat) -> CGFloat {
    if inset <= 0.0 || rowHeight <= 0.0 {
        return 0.0
    }
    let fraction = max(0.0, min(1.0, (islandHeight + rowHeight - rowMinY) / rowHeight))
    return inset * fraction
}

/// `ContainerViewLayout.sideInsets(forBandFrom:to:)` for code that has the screen's height, safe insets and reserved
/// corners rather than its layout (a component's `ViewControllerComponentContainer.Environment`): a side's inset applies
/// to a horizontal band only where the band reaches that side's corner block, so beside iPhone Duo's side strip a row
/// away from the camera (e.g. a bottom action button in folded portrait) can span the strip. Without corner blocks
/// (every other device) the safe insets apply unchanged.
public func bandSideInsets(forBandFrom minY: CGFloat, to maxY: CGFloat, containerHeight: CGFloat, safeInsets: UIEdgeInsets, reservedCorners: ContainerViewLayoutCorners) -> (left: CGFloat, right: CGFloat) {
    func inset(_ inset: CGFloat, topBlock: CGSize?, bottomBlock: CGSize?) -> CGFloat {
        if inset <= 0.0 {
            return inset
        }
        let topMatches = topBlock.map { abs($0.width - inset) <= 1.0 } ?? false
        let bottomMatches = bottomBlock.map { abs($0.width - inset) <= 1.0 } ?? false
        if !topMatches && !bottomMatches {
            return inset
        }
        if let topBlock, minY < topBlock.height && maxY > 0.0 {
            return inset
        }
        if let bottomBlock, maxY > containerHeight - bottomBlock.height && minY < containerHeight {
            return inset
        }
        return 0.0
    }
    return (
        inset(safeInsets.left, topBlock: reservedCorners.topLeft, bottomBlock: reservedCorners.bottomLeft),
        inset(safeInsets.right, topBlock: reservedCorners.topRight, bottomBlock: reservedCorners.bottomRight)
    )
}

/// `ContainerViewLayout.bottomEdgeSideInsets()` for code without the layout (a component's environment): the side
/// insets of a row at the bottom edge, which keep a side strip's inset only where that side's corner block is at the
/// bottom. The container's height does not matter for a row at its bottom.
public func bottomEdgeSideInsets(safeInsets: UIEdgeInsets, reservedCorners: ContainerViewLayoutCorners) -> (left: CGFloat, right: CGFloat) {
    let height: CGFloat = 10000.0
    return bandSideInsets(forBandFrom: height - 1.0, to: height, containerHeight: height, safeInsets: safeInsets, reservedCorners: reservedCorners)
}
