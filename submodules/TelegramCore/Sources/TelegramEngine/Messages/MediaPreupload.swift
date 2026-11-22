import Foundation
import Postbox
import SwiftSignalKit
import MediaPreuploadRegistry

/// What the app sees of one medium's pre-upload.
public enum EngineMediaPreuploadState {
    case progress(Float)
    case done(EngineMedia)
    case failed
}

/// A reconciled set of "media that should be uploading right now".
///
/// Both holders use this — `updatePeerMediaNeeds` for the persisted draft (durable) and the editor
/// screens for their live document (transient) — so the two cannot drift apart.
///
/// Reconciliation is ADD BEFORE DISPOSE: a medium present in both the old and the new set is held
/// twice for an instant rather than dropping to zero holders, so a surviving upload is never
/// needlessly cancelled and restarted.
public final class MediaPreuploadNeeds {
    // Deliberately NOT an `Account`: the durable holder lives inside
    // `managedSynchronizeChatInputStateOperations`, which only has these three. Taking the pieces is
    // what lets both holders share this one implementation.
    private let network: Network
    private let postbox: Postbox
    private let manager: MessageMediaPreuploadManager
    private var current: [EngineMedia.Id: Disposable] = [:]

    init(network: Network, postbox: Postbox, manager: MessageMediaPreuploadManager) {
        self.network = network
        self.postbox = postbox
        self.manager = manager
    }

    deinit {
        for (_, disposable) in self.current {
            disposable.dispose()
        }
    }

    public func update(peerId: EnginePeer.Id, media: [EngineMedia]) {
        var next: [EngineMedia.Id: Disposable] = [:]
        for item in media {
            let raw = item._asMedia()
            guard let mediaId = raw.id, next[mediaId] == nil else {
                continue
            }
            next[mediaId] = self.manager.addMedia(
                network: self.network,
                postbox: self.postbox,
                peerId: peerId,
                media: raw
            )
        }
        let previous = self.current
        self.current = next
        for (_, disposable) in previous {
            disposable.dispose()
        }
    }
}

public extension TelegramEngine.Messages {
    /// Create a need-set. Hold it for as long as the content that references the media is live;
    /// releasing it (or letting it deinit) releases every need it holds.
    func makeMediaPreuploadNeeds() -> MediaPreuploadNeeds {
        return MediaPreuploadNeeds(
            network: self.account.network,
            postbox: self.account.postbox,
            manager: self.account.messageMediaPreuploadManager
        )
    }

    /// Watch a medium's pre-upload WITHOUT keeping it alive. `nil` means nothing is uploading it.
    func mediaPreuploadState(id: EngineMedia.Id) -> Signal<EngineMediaPreuploadState?, NoError> {
        return self.account.messageMediaPreuploadManager.mediaState(id: id)
        |> map { state -> EngineMediaPreuploadState? in
            guard let state else {
                return nil
            }
            switch state {
            case let .progress(value):
                return .progress(value)
            case let .done(media):
                return .done(media)
            case .failed:
                return .failed
            }
        }
    }
}
