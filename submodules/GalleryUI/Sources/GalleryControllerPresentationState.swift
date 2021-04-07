import Foundation

public final class GalleryControllerPresentationState {
    public let footerContentNode: GalleryFooterContentNode?
    public let overlayContentNode: GalleryOverlayContentNode?
    
    public init() {
        self.footerContentNode = nil
        self.overlayContentNode = nil
    }
    
    public init(footerContentNode: GalleryFooterContentNode?, overlayContentNode: GalleryOverlayContentNode?) {
        self.footerContentNode = footerContentNode
        self.overlayContentNode = overlayContentNode
    }
    
    public func withUpdatedFooterContentNode(_ footerContentNode: GalleryFooterContentNode?) -> GalleryControllerPresentationState {
        return GalleryControllerPresentationState(footerContentNode: footerContentNode, overlayContentNode: self.overlayContentNode)
    }
    
    public func withUpdatedOverlayContentNode(_ overlayContentNode: GalleryOverlayContentNode?) -> GalleryControllerPresentationState {
        return GalleryControllerPresentationState(footerContentNode: self.footerContentNode, overlayContentNode: overlayContentNode)
    }
}
