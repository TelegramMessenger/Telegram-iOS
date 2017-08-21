import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

private struct WrappedStickerPackCollectionInfo: Equatable {
    let info: StickerPackCollectionInfo?
    
    static func ==(lhs: WrappedStickerPackCollectionInfo, rhs: WrappedStickerPackCollectionInfo) -> Bool {
        return lhs.info == rhs.info
    }
}

public func peerSpecificStickerPack(postbox: Postbox, network: Network, peerId: PeerId) -> Signal<(StickerPackCollectionInfo, [ItemCollectionItem])?, NoError> {
    if peerId.namespace == Namespaces.Peer.CloudChannel {
        return postbox.combinedView(keys: [.cachedPeerData(peerId: peerId)])
            |> map { view -> WrappedStickerPackCollectionInfo in
                let dataView = view.views[.cachedPeerData(peerId: peerId)] as? CachedPeerDataView
                return WrappedStickerPackCollectionInfo(info: (dataView?.cachedPeerData as? CachedChannelData)?.stickerPack)
            }
            |> distinctUntilChanged
            |> mapToSignal { info -> Signal<(StickerPackCollectionInfo, [ItemCollectionItem])?, NoError> in
                if let info = info.info {
                    return cachedStickerPack(postbox: postbox, network: network, info: info)
                } else {
                    return .single(nil)
                }
            }
    } else {
        return .single(nil)
    }
}
