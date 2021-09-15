import Foundation
import AccountContext

public protocol GalleryItemTransitionNode: AnyObject {
    func isAvailableForGalleryTransition() -> Bool
    func isAvailableForInstantPageTransition() -> Bool
    var decoration: UniversalVideoDecoration? { get }
}
