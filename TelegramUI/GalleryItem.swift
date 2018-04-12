import Foundation

struct GalleryItemOriginData: Equatable {
    let title: String?
    let timestamp: Int32?
    
    static func ==(lhs: GalleryItemOriginData, rhs: GalleryItemOriginData) -> Bool {
        return lhs.title == rhs.title && lhs.timestamp == rhs.timestamp
    }
}

struct GalleryItemIndexData: Equatable {
    let position: Int32
    let totalCount: Int32
    
    static func ==(lhs: GalleryItemIndexData, rhs: GalleryItemIndexData) -> Bool {
        return lhs.position == rhs.position && lhs.totalCount == rhs.totalCount
    }
}

protocol GalleryItem {
    func node() -> GalleryItemNode
    func updateNode(node: GalleryItemNode)
    func thumbnailItem() -> (Int64, GalleryThumbnailItem)?
}
