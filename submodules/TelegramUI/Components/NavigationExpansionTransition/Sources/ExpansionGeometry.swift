import Foundation
import UIKit
import Display

/// Which way the upper screen arrives: out of the origin (the pill), or straight into its expanded photo (a tap on the
/// avatar), where everything follows the photo.
public enum ExpansionPath: Equatable {
    case origin
    case photo
}

/// One label (the title, the status line) in both screens' layouts, in screen coordinates.
public struct ExpansionLabelGeometry: Equatable {
    public var sourceCenter: CGPoint
    public var sourceSize: CGSize
    public var destinationCenter: CGPoint
    public var destinationSize: CGSize
    /// The photo path's resting place and size under the expanded photo; nil uses the destination's.
    public var photoCenter: CGPoint?
    public var photoSize: CGSize?

    public init(sourceCenter: CGPoint, sourceSize: CGSize, destinationCenter: CGPoint, destinationSize: CGSize, photoCenter: CGPoint? = nil, photoSize: CGSize? = nil) {
        self.sourceCenter = sourceCenter
        self.sourceSize = sourceSize
        self.destinationCenter = destinationCenter
        self.destinationSize = destinationSize
        self.photoCenter = photoCenter
        self.photoSize = photoSize
    }
}

/// What an expansion is measured from, in screen coordinates: the lower screen's origin and companion, the upper
/// screen's avatar, photo, labels and appearing items.
public struct ExpansionGeometry: Equatable {
    public var screenSize: CGSize
    /// The screen's corner radii (`ContainerViewLayout.screenCornerRadii`): the card's corners once it fills the screen.
    /// They differ per corner on iPhone Duo's cover screen.
    public var screenCornerRadii: CornerRadii
    /// The glass shape that becomes the card (the chat's title pill).
    public var origin: CGRect
    /// The companion's glass circle (the chat's avatar button: 44 pt in the bar's row, 48 pt in iPhone Duo's side
    /// column); nil without one.
    public var companion: CGRect?
    /// The photo inside the companion's circle (38 pt).
    public var companionPhotoDiameter: CGFloat
    /// Where the companion lands (the profile's avatar circle).
    public var avatar: CGRect?
    /// The photo path's end (the expanded photo).
    public var photo: CGRect?
    /// The labels; the last is the anchor the card's edge carries, the others keep their offset from it.
    public var labels: [ExpansionLabelGeometry]
    /// The edge the labels ride down to: the upper screen's header bottom (the prototype's `liquidBottom`).
    public var carriedEdge: CGFloat
    /// The upper screen's appearing items in order (the action buttons), at rest.
    public var appearing: [CGRect]
    /// The avatar's corner radius over its side (`NavigationExpansionDestinationLoan.avatarCornerFraction`).
    public var avatarCornerFraction: CGFloat = 0.5
    public var backgroundOpening: ClosedRange<CGFloat> = 0.06 ... 0.45
    public var backgroundClosing: ClosedRange<CGFloat> = 0.30 ... 0.85

    /// The glass ring around the companion's photo: 3 pt in the bar's row (44 around 38), 5 pt in the side column.
    public var companionRing: CGFloat {
        guard let companion = self.companion else {
            return 0.0
        }
        return max(0.0, (companion.width - self.companionPhotoDiameter) * 0.5)
    }

    /// How close the drops come before they merge (the glass container's spacing): the prototype's 30 pt, but no more
    /// than the origin and the companion stand apart at rest, or they would join in a neck where the transition starts
    /// and ends (a long title on a narrow phone takes the pill to 10 pt from the capsule).
    public var dropMergeSpacing: CGFloat {
        let maximum: CGFloat = 30.0
        guard let companion = self.companion else {
            return maximum
        }
        let dx = max(0.0, max(companion.minX - self.origin.maxX, self.origin.minX - companion.maxX))
        let dy = max(0.0, max(companion.minY - self.origin.maxY, self.origin.minY - companion.maxY))
        return min(maximum, (dx * dx + dy * dy).squareRoot())
    }

    public init(screenSize: CGSize, screenCornerRadii: CornerRadii, origin: CGRect, companion: CGRect?, companionPhotoDiameter: CGFloat, avatar: CGRect?, photo: CGRect?, labels: [ExpansionLabelGeometry], carriedEdge: CGFloat, appearing: [CGRect]) {
        self.screenSize = screenSize
        self.screenCornerRadii = screenCornerRadii
        self.origin = origin
        self.companion = companion
        self.companionPhotoDiameter = companionPhotoDiameter
        self.avatar = avatar
        self.photo = photo
        self.labels = labels
        self.carriedEdge = carriedEdge
        self.appearing = appearing
    }
}
