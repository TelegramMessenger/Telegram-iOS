import Foundation

final class GalleryControllerPresentationState {
    let footerContentNode: GalleryFooterContentNode?
    
    init() {
        self.footerContentNode = nil
    }
    
    init(footerContentNode: GalleryFooterContentNode?) {
        self.footerContentNode = footerContentNode
    }
    
    func withUpdatedFooterContentNode(_ footerContentNode: GalleryFooterContentNode?) -> GalleryControllerPresentationState {
        return GalleryControllerPresentationState(footerContentNode: footerContentNode)
    }
}
