import Foundation
import Postbox
import SwiftSignalKit


private struct WrappedStickerPackCollectionInfo: Equatable {
    let info: StickerPackCollectionInfo?
    
    static func ==(lhs: WrappedStickerPackCollectionInfo, rhs: WrappedStickerPackCollectionInfo) -> Bool {
        return lhs.info == rhs.info
    }
}

public struct PeerSpecificStickerPackData {
    public let packInfo: (StickerPackCollectionInfo, [ItemCollectionItem])?
    public let canSetup: Bool
}

func _internal_peerSpecificStickerPack(postbox: Postbox, network: Network, peerId: PeerId) -> Signal<PeerSpecificStickerPackData, NoError> {
    if peerId.namespace == Namespaces.Peer.CloudChannel {
        let signal: Signal<(WrappedStickerPackCollectionInfo, Bool), NoError> = postbox.combinedView(keys: [.cachedPeerData(peerId: peerId)])
        |> map { view -> (WrappedStickerPackCollectionInfo, Bool) in
            let dataView = view.views[.cachedPeerData(peerId: peerId)] as? CachedPeerDataView
            return (WrappedStickerPackCollectionInfo(info: (dataView?.cachedPeerData as? CachedChannelData)?.stickerPack), (dataView?.cachedPeerData as? CachedChannelData)?.flags.contains(.canSetStickerSet) ?? false)
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs -> Bool in
            return lhs.0 == rhs.0 && lhs.1 == rhs.1
        })
            
        return signal
        |> mapToSignal { info, canInstall -> Signal<PeerSpecificStickerPackData, NoError> in
            if let info = info.info {
                return _internal_cachedStickerPack(postbox: postbox, network: network, reference: .id(id: info.id.id, accessHash: info.accessHash), forceRemote: false)
                |> map { result -> PeerSpecificStickerPackData in
                    if case let .result(info, items, _) = result {
                        return PeerSpecificStickerPackData(packInfo: (info, items), canSetup: canInstall)
                    } else {
                        return PeerSpecificStickerPackData(packInfo: nil, canSetup: canInstall)
                    }
                }
            } else {
                return .single(PeerSpecificStickerPackData(packInfo: nil, canSetup: canInstall))
            }
        }
    } else {
        return .single(PeerSpecificStickerPackData(packInfo: nil, canSetup: false))
    }
}
