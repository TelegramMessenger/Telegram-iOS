import Foundation
import UIKit

/// The expanded avatar's height in a container of `containerSize`: the photo, as wide as the container and at most its
/// height less 61 pt, and the `bottomHeight` of title and buttons laid on its lower part (98 pt, 60 in Settings and My
/// Profile).
public func peerInfoExpandedAvatarHeight(containerSize: CGSize, bottomHeight: CGFloat) -> CGFloat {
    return min(containerSize.width, containerSize.height - 61.0) + bottomHeight
}

/// Whether the avatar can be expanded in a container of `containerSize`. The expanded photo takes every drag on it (for
/// its pages), so the profile scrolls, and the photo collapses, only by a drag on the list below it: at least a touch's
/// height (44 pt) of the container has to stay below the photo. Not in landscape, nor in a portrait container hardly
/// taller than wide (the unfolded iPhone Duo's detail pane in landscape, an iPad's split pane), where the photo reaches
/// past the bottom and the profile could not be scrolled.
public func peerInfoAvatarExpansionFits(containerSize: CGSize, bottomHeight: CGFloat) -> Bool {
    if containerSize.width > containerSize.height {
        return false
    }
    return containerSize.height - peerInfoExpandedAvatarHeight(containerSize: containerSize, bottomHeight: bottomHeight) >= 44.0
}
