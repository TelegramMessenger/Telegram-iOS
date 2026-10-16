import Foundation
import UIKit

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
    /// The device's corner radius: the card's corners once it is taller than two of them.
    public var screenCornerRadius: CGFloat
    /// The glass shape that becomes the card (the chat's title pill).
    public var origin: CGRect
    /// The companion's glass capsule (the chat's avatar button, 44 pt); nil without one.
    public var companion: CGRect?
    /// The photo inside the companion's capsule (38 pt).
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

    public init(screenSize: CGSize, screenCornerRadius: CGFloat, origin: CGRect, companion: CGRect?, companionPhotoDiameter: CGFloat, avatar: CGRect?, photo: CGRect?, labels: [ExpansionLabelGeometry], carriedEdge: CGFloat, appearing: [CGRect]) {
        self.screenSize = screenSize
        self.screenCornerRadius = screenCornerRadius
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
