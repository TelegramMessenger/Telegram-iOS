import Foundation
import Display
import AsyncDisplayKit

final class ChatHoleGalleryItem: GalleryItem {
    func node() -> GalleryItemNode {
        return ChatHoleGalleryItemNode()
    }
    
    func updateNode(node: GalleryItemNode) {
        
    }
}

final class ChatHoleGalleryItemNode: GalleryItemNode {
    override init() {
        super.init()
        
        self.backgroundColor = UIColor.blue
    }
}
