import Foundation

public final class GalleryControllerPresentationState {
    public let footerContentNode: GalleryFooterContentNode?
    
    public init() {
        self.footerContentNode = nil
    }
    
    public init(footerContentNode: GalleryFooterContentNode?) {
        self.footerContentNode = footerContentNode
    }
    
    public func withUpdatedFooterContentNode(_ footerContentNode: GalleryFooterContentNode?) -> GalleryControllerPresentationState {
        return GalleryControllerPresentationState(footerContentNode: footerContentNode)
    }
}
