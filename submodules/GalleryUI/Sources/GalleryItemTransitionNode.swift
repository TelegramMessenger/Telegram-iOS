import Foundation
import AccountContext

public protocol GalleryItemTransitionNode: class {
    func isAvailableForGalleryTransition() -> Bool
    var decoration: UniversalVideoDecoration? { get }
}
