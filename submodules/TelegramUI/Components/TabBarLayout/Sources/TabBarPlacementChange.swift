import Foundation
import UIKit
import Display

/// What a layout pass applied to the bar, for deciding how the next pass moves it.
public struct TabBarAppliedPlacement: Equatable {
    /// Nil for the horizontal bar.
    public var placement: TabBarSidePlacement?
    public var containerSize: CGSize
    public var isHidden: Bool

    public init(placement: TabBarSidePlacement?, containerSize: CGSize, isHidden: Bool) {
        self.placement = placement
        self.containerSize = containerSize
        self.isHidden = isHidden
    }
}

public enum TabBarPlacementChange: Equatable {
    /// The frames follow the layout's transition.
    case animate
    /// The frames are set without animation: the bar switches axis (folding, unfolding), or it is hidden
    /// before and after a move.
    case immediate
    /// A rotation moves the vertical bar to another place: a snapshot of it fades out and the bar fades
    /// in at its new frame, instead of flying across the screen.
    case crossfade
}

public func tabBarPlacementChange(from previous: TabBarAppliedPlacement?, to current: TabBarAppliedPlacement) -> TabBarPlacementChange {
    guard let previous else {
        return .animate
    }
    switch (previous.placement, current.placement) {
    case (nil, nil):
        return .animate
    case (nil, _), (_, nil):
        return .immediate
    case let (previousPlacement?, currentPlacement?):
        if previousPlacement.edge == currentPlacement.edge && previous.containerSize == current.containerSize {
            return .animate
        }
        if previous.isHidden && current.isHidden {
            return .immediate
        }
        return .crossfade
    }
}

public extension TabBarSidePlacement {
    /// The frame at the same distance from its own side edge and from the bottom edge in a container of
    /// another size: where the fading snapshot of the bar sits after a rotation.
    func movedFrame(from previousContainerSize: CGSize, to containerSize: CGSize) -> CGRect {
        var frame = self.frame
        switch self.edge {
        case .left:
            break
        case .right:
            frame.origin.x = containerSize.width - (previousContainerSize.width - self.frame.minX)
        }
        frame.origin.y = containerSize.height - (previousContainerSize.height - self.frame.minY)
        return frame
    }
}
