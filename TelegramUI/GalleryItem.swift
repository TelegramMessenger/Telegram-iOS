import Foundation



protocol GalleryItem {
    func node() -> GalleryItemNode
    func updateNode(node: GalleryItemNode)
}
