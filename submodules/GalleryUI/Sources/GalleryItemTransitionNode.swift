import Foundation
import AccountContext

public protocol GalleryItemTransitionNode: class {
    func isAvailableForGalleryTransition() -> Bool
    func isAvailableForInstantPageTransition() -> Bool
    var decoration: UniversalVideoDecoration? { get }
}
