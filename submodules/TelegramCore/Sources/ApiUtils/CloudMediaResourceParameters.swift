import Foundation

public enum CloudMediaResourceLocation: Equatable {
    case photo(id: Int64, accessHash: Int64, fileReference: Data, thumbSize: String)
    case file(id: Int64, accessHash: Int64, fileReference: Data, thumbSize: String)
    case peerPhoto(peer: PeerReference, fullSize: Bool, volumeId: Int64, localId: Int64)
    case stickerPackThumbnail(packReference: StickerPackReference, volumeId: Int64, localId: Int64)
}
