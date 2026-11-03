import Foundation
import Postbox
import SwiftSignalKit
import MediaPreuploadRegistry

extension MessageMediaPreuploadManager {
    /// The registry's producer for one medium: bytes -> uploadMedia -> cloud media, with the error
    /// channel folded into `.failed` (the registry's producer signal cannot fail).
    private func mediaProducer(network: Network, postbox: Postbox, peerId: PeerId, media: Media) -> Signal<PreuploadState<EngineMedia>, NoError> {
        return uploadMediaToCloud(network: network, postbox: postbox, messageMediaPreuploadManager: self, peerId: peerId, media: media)
        |> map { event -> PreuploadState<EngineMedia> in
            switch event {
            case let .progress(value):
                return .progress(value)
            case let .done(cloudMedia):
                return .done(EngineMedia(cloudMedia))
            }
        }
        |> `catch` { _ -> Signal<PreuploadState<EngineMedia>, NoError> in
            return .single(.failed)
        }
    }

    /// Hold a need on `media`. Nothing happens for media that cannot be pre-uploaded (no bytes, or
    /// already cloud) or for a secret chat, where rich content is never sent.
    func addMedia(network: Network, postbox: Postbox, peerId: PeerId, media: Media) -> Disposable {
        guard let mediaId = media.id, isPreuploadableMedia(media), peerId.namespace != Namespaces.Peer.SecretChat else {
            return EmptyDisposable
        }
        return self.mediaRegistry.hold(mediaId, produce: { [weak self] in
            guard let self else {
                return .single(.failed)
            }
            return self.mediaProducer(network: network, postbox: postbox, peerId: peerId, media: media)
        })
    }

    /// Observe without wanting. `nil` means nothing is uploading this medium.
    func mediaState(id: MediaId) -> Signal<PreuploadState<EngineMedia>?, NoError> {
        return self.mediaRegistry.observe(id)
    }

    /// Create-or-join, holding a need for the subscription. The send / edit / draft-save entry point.
    func mediaSignal(network: Network, postbox: Postbox, peerId: PeerId, media: Media, forceReupload: Bool = false) -> Signal<PreuploadState<EngineMedia>, NoError> {
        guard let mediaId = media.id, isPreuploadableMedia(media, allowAlreadyCloud: forceReupload), peerId.namespace != Namespaces.Peer.SecretChat else {
            return .single(.failed)
        }
        return self.mediaRegistry.join(mediaId, produce: { [weak self] in
            guard let self else {
                return .single(.failed)
            }
            return self.mediaProducer(network: network, postbox: postbox, peerId: peerId, media: media)
        })
    }

    /// Drop any parked result and any failure backoff. For a forced re-upload, which must not reuse
    /// a previous result.
    func evictMedia(id: MediaId) {
        self.mediaRegistry.evict(id)
    }
}
