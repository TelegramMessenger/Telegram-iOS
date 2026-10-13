import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import AccountContext
import MusicAlbumArtResources

struct InstantPageMediaPlaylistItemId: SharedMediaPlaylistItemId, InstantPagePlaylistItemIndexProviding {
    let index: Int

    var instantPageMediaIndex: Int {
        return self.index
    }
    
    func isEqual(to: SharedMediaPlaylistItemId) -> Bool {
        // Matched through the protocol, not the concrete type: a host outside InstantPageUI cannot
        // construct this type and passes RichMessagePlaylistItemId instead. This type conforms to
        // the same protocol, so same-type comparisons still work.
        guard let to = to as? InstantPagePlaylistItemIndexProviding else {
            return false
        }
        return self.index == to.instantPageMediaIndex
    }
}

private func extractFileMedia(_ item: InstantPageMedia) -> TelegramMediaFile? {
    if case let .file(file) = item.media {
        return file
    } else {
        return nil
    }
}

final class InstantPageMediaPlaylistItem: SharedMediaPlaylistItem {
    let webPage: TelegramMediaWebpage
    let messageReference: MessageReference?
    let id: SharedMediaPlaylistItemId
    let item: InstantPageMedia

    init(webPage: TelegramMediaWebpage, messageReference: MessageReference?, item: InstantPageMedia) {
        self.webPage = webPage
        self.messageReference = messageReference
        self.id = InstantPageMediaPlaylistItemId(index: item.index)
        self.item = item
    }

    private func fileReference(_ file: TelegramMediaFile) -> FileMediaReference {
        // Require a resolvable message id (mirrors the playlist-key fallback in
        // InstantPageV2MediaAudioView): a `.none`-content reference can't revalidate, so fall
        // back to the webpage reference in that case.
        if let messageReference = self.messageReference, messageReference.id != nil {
            return .message(message: messageReference, media: file)
        } else {
            return .webPage(webPage: WebpageReference(self.webPage), media: file)
        }
    }

    var stableId: AnyHashable {
        return self.item.index
    }
    
    var playbackData: SharedMediaPlaybackData? {
        if let file = extractFileMedia(self.item) {
            for attribute in file.attributes {
                switch attribute {
                    case let .Audio(isVoice, _, _, _, _):
                        if isVoice {
                            return SharedMediaPlaybackData(type: .voice, source: .telegramFile(reference: self.fileReference(file), isCopyProtected: false, isViewOnce: false))
                        } else {
                            return SharedMediaPlaybackData(type: .music, source: .telegramFile(reference: self.fileReference(file), isCopyProtected: false, isViewOnce: false))
                        }
                    case let .Video(_, _, flags, _, _, _):
                        if flags.contains(.instantRoundVideo) {
                            return SharedMediaPlaybackData(type: .instantVideo, source: .telegramFile(reference: self.fileReference(file), isCopyProtected: false, isViewOnce: false))
                        } else {
                            return nil
                        }
                    default:
                        break
                }
            }
            if file.mimeType.hasPrefix("audio/") {
                return SharedMediaPlaybackData(type: .music, source: .telegramFile(reference: self.fileReference(file), isCopyProtected: false, isViewOnce: false))
            }
            if let fileName = file.fileName {
                let ext = (fileName as NSString).pathExtension.lowercased()
                if ext == "wav" || ext == "opus" {
                    return SharedMediaPlaybackData(type: .music, source: .telegramFile(reference: self.fileReference(file), isCopyProtected: false, isViewOnce: false))
                }
            }
        }
        return nil
    }
    
    var displayData: SharedMediaPlaybackDisplayData? {
        if let file = extractFileMedia(self.item) {
            for attribute in file.attributes {
                switch attribute {
                    case let .Audio(isVoice, duration, title, performer, _):
                        if isVoice {
                            return SharedMediaPlaybackDisplayData.voice(author: nil, peer: nil)
                        } else {
                            var updatedTitle = title
                            let updatedPerformer = performer
                            if (title ?? "").isEmpty && (performer ?? "").isEmpty {
                                updatedTitle = file.fileName ?? ""
                            }
                            
                            let albumArt: SharedMediaPlaybackAlbumArt?
                            if file.fileName?.lowercased().hasSuffix(".ogg") == true {
                                albumArt = nil
                            } else {
                                albumArt = SharedMediaPlaybackAlbumArt(thumbnailResource: ExternalMusicAlbumArtResource(file: .standalone(media: file), title: updatedTitle ?? "", performer: updatedPerformer ?? "", isThumbnail: true), fullSizeResource: ExternalMusicAlbumArtResource(file: .standalone(media: file), title: updatedTitle ?? "", performer: updatedPerformer ?? "", isThumbnail: false))
                            }
                            
                            return SharedMediaPlaybackDisplayData.music(title: updatedTitle, performer: updatedPerformer, albumArt: albumArt, long: CGFloat(duration) > 10.0 * 60.0, caption: nil)
                        }
                    case let .Video(_, _, flags, _, _, _):
                        if flags.contains(.instantRoundVideo) {
                            return SharedMediaPlaybackDisplayData.instantVideo(author: nil, peer: nil, timestamp: 0)
                        } else {
                            return nil
                        }
                    default:
                        break
                }
            }
            
            return SharedMediaPlaybackDisplayData.music(title: file.fileName ?? "", performer: "", albumArt: nil, long: false, caption: nil)
        }
        return nil
    }
}

public enum InstantPageMediaPlaylistId: Equatable, SharedMediaPlaylistId, InstantPagePlaylistIdProviding {
    case instantPage(webpageId: EngineMedia.Id)
    case richMessage(messageId: EngineMessage.Id)

    public var instantPageRichMessageId: EngineMessage.Id? {
        if case let .richMessage(messageId) = self {
            return messageId
        }
        return nil
    }

    public func isEqual(to: SharedMediaPlaylistId) -> Bool {
        if let to = to as? InstantPageMediaPlaylistId {
            return self == to
        }
        // A host outside InstantPageUI cannot construct this enum and passes RichMessagePlaylistId
        // instead; match it on the rich message id. `.instantPage` never matches, having none.
        if let to = to as? InstantPagePlaylistIdProviding, let lhs = self.instantPageRichMessageId, let rhs = to.instantPageRichMessageId {
            return lhs == rhs
        }
        return false
    }
}

public final class InstantPageMediaPlaylist: SharedMediaPlaylist {
    private let webPage: TelegramMediaWebpage
    private let messageReference: MessageReference?
    private let items: [InstantPageMedia]
    private let initialItemIndex: Int
    
    /// Carries the originating message id when this playlist is a rich message's own InstantPage, so
    /// the shared media accessory panel can open the music player for it (see
    /// `InstantPagePlaylistLocation` in AccountContext). Nil for the Instant View reader.
    public var location: SharedMediaPlaylistLocation {
        var tracks: [InstantPagePlaylistTrack] = []
        for item in self.items {
            if case let .file(file) = item.media {
                tracks.append(InstantPagePlaylistTrack(index: item.index, file: file))
            }
        }
        return InstantPagePlaylistLocation(webpageId: self.webPage.webpageId, messageId: self.messageReference?.id, tracks: tracks, webPage: self.webPage, messageReference: self.messageReference)
    }
    
    public var currentItemDisappeared: (() -> Void)?
    
    private var currentItem: InstantPageMedia?
    private var playedToEnd: Bool = false
    private var order: MusicPlaybackSettingsOrder = .regular
    public private(set) var looping: MusicPlaybackSettingsLooping = .none
    
    public let id: SharedMediaPlaylistId
    
    private let stateValue = Promise<SharedMediaPlaylistState>()
    public var state: Signal<SharedMediaPlaylistState, NoError> {
        return self.stateValue.get()
    }
    
    public init(playlistId: InstantPageMediaPlaylistId, webPage: TelegramMediaWebpage, messageReference: MessageReference?, items: [InstantPageMedia], initialItemIndex: Int) {
        assert(Queue.mainQueue().isCurrent())

        self.id = playlistId

        self.webPage = webPage
        self.messageReference = messageReference
        self.items = items
        self.initialItemIndex = initialItemIndex

        self.control(.next)
    }
    
    public func control(_ action: SharedMediaPlaylistControlAction) {
        assert(Queue.mainQueue().isCurrent())
        
        switch action {
            case .next, .previous:
                if let currentItem = self.currentItem, let currentIndex = self.items.firstIndex(where: { $0.index == currentItem.index }) {
                    let selectedIndex: Int?
                    switch self.order {
                        // `items` is in document order, so advancing is +1. This is the opposite of
                        // PeerMessagesMediaPlaylist, whose collection is a reverse-chronological
                        // chat timeline and whose `.regular` advance therefore walks to the EARLIER
                        // message; copying that arithmetic here reversed Next/Previous on screen.
                        case .regular:
                            if case .next = action {
                                if currentIndex == self.items.count - 1 {
                                    selectedIndex = nil
                                } else {
                                    selectedIndex = currentIndex + 1
                                }
                            } else {
                                selectedIndex = max(0, currentIndex - 1)
                            }
                        case .reversed:
                            if case .next = action {
                                selectedIndex = max(0, currentIndex - 1)
                            } else {
                                if currentIndex == self.items.count - 1 {
                                    selectedIndex = nil
                                } else {
                                    selectedIndex = currentIndex + 1
                                }
                            }
                        case .random:
                            selectedIndex = Int(arc4random_uniform(UInt32(self.items.count)))
                    }
                    
                    if let selectedIndex = selectedIndex {
                        self.currentItem = self.items[selectedIndex]
                        self.playedToEnd = false
                    } else {
                        self.currentItem = nil
                        self.playedToEnd = true
                    }
                    self.updateState()
                } else {
                    if self.initialItemIndex < self.items.count {
                        self.currentItem = self.items[self.initialItemIndex]
                    } else {
                        self.currentItem = nil
                    }
                    self.playedToEnd = false
                    self.updateState()
                }
        }
    }
    
    public func setOrder(_ order: MusicPlaybackSettingsOrder) {
        if self.order != order {
            self.order = order
            self.updateState()
        }
    }
    
    public func setLooping(_ looping: MusicPlaybackSettingsLooping) {
        if self.looping != looping {
            self.looping = looping
            self.updateState()
        }
    }
    
    private func updateState() {
        self.stateValue.set(.single(SharedMediaPlaylistState(loading: false, playedToEnd: self.playedToEnd, item: self.currentItem.flatMap({ InstantPageMediaPlaylistItem(webPage: self.webPage, messageReference: self.messageReference, item: $0) }), nextItem: nil, previousItem: nil, order: self.order, looping: self.looping)))
    }
    
    public func onItemPlaybackStarted(_ item: SharedMediaPlaylistItem) {
    }
}
