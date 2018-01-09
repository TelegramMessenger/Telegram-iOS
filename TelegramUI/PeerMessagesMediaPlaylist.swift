import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore

private enum PeerMessagesMediaPlaylistLoadAnchor {
    case messageId(MessageId)
    case index(MessageIndex)
}

private enum PeerMessagesMediaPlaylistNavigation {
    case earlier
    case later
    case random
}

struct MessageMediaPlaylistItemStableId: Hashable {
    let stableId: UInt32
    
    var hashValue: Int {
        return self.stableId.hashValue
    }
    
    static func ==(lhs: MessageMediaPlaylistItemStableId, rhs: MessageMediaPlaylistItemStableId) -> Bool {
        return lhs.stableId == rhs.stableId
    }
}

struct PeerMessagesMediaPlaylistItemId: SharedMediaPlaylistItemId {
    let messageId: MessageId
    
    func isEqual(to: SharedMediaPlaylistItemId) -> Bool {
        if let to = to as? PeerMessagesMediaPlaylistItemId {
            if self.messageId != to.messageId {
                return false
            }
            return true
        }
        return false
    }
}

final class MessageMediaPlaylistItem: SharedMediaPlaylistItem {
    let id: SharedMediaPlaylistItemId
    let message: Message
    
    init(message: Message) {
        self.id = PeerMessagesMediaPlaylistItemId(messageId: message.id)
        self.message = message
    }
    
    var stableId: AnyHashable {
        return MessageMediaPlaylistItemStableId(stableId: message.stableId)
    }
    
    var playbackData: SharedMediaPlaybackData? {
        for media in self.message.media {
            if let file = media as? TelegramMediaFile {
                for attribute in file.attributes {
                    switch attribute {
                        case let .Audio(isVoice, _, _, _, _):
                            if isVoice {
                                return SharedMediaPlaybackData(type: .voice, source: .telegramFile(file))
                            } else {
                                return SharedMediaPlaybackData(type: .music, source: .telegramFile(file))
                            }
                        case let .Video(_, _, flags):
                            if flags.contains(.instantRoundVideo) {
                                return SharedMediaPlaybackData(type: .instantVideo, source: .telegramFile(file))
                            } else {
                                return nil
                            }
                        default:
                            break
                    }
                }
            }
        }
        return nil
    }

    var displayData: SharedMediaPlaybackDisplayData? {
        for media in self.message.media {
            if let file = media as? TelegramMediaFile {
                for attribute in file.attributes {
                    switch attribute {
                        case let .Audio(isVoice, _, title, performer, _):
                            if isVoice {
                                return SharedMediaPlaybackDisplayData.voice(author: self.message.author, peer: self.message.peers[self.message.id.peerId])
                            } else {
                                return SharedMediaPlaybackDisplayData.music(title: title, performer: performer, albumArt: SharedMediaPlaybackAlbumArt(thumbnailResource: ExternalMusicAlbumArtResource(title: title ?? "", performer: performer ?? "", isThumbnail: true), fullSizeResource: ExternalMusicAlbumArtResource(title: title ?? "", performer: performer ?? "", isThumbnail: false)))
                            }
                        case let .Video(_, _, flags):
                            if flags.contains(.instantRoundVideo) {
                                return SharedMediaPlaybackDisplayData.instantVideo(author: self.message.author, peer: self.message.peers[self.message.id.peerId])
                            } else {
                                return nil
                            }
                        default:
                            break
                    }
                }
            }
        }
        return nil
    }
}

private enum NavigatedMessageFromViewPosition {
    case later
    case earlier
    case exact
}

private func navigatedMessageFromView(_ view: MessageHistoryView, anchorIndex: MessageIndex, position: NavigatedMessageFromViewPosition) -> (message: Message, exact: Bool)? {
    var index = 0
    for entry in view.entries {
        if entry.index.id == anchorIndex.id {
            switch position {
                case .exact:
                    switch entry {
                        case let .MessageEntry(message, _, _, _):
                            return (message, true)
                        default:
                            return nil
                    }
                case .later:
                    if index + 1 < view.entries.count {
                        switch view.entries[index + 1] {
                            case let .MessageEntry(message, _, _, _):
                                return (message, true)
                            default:
                                return nil
                        }
                    } else {
                        return nil
                    }
                case .earlier:
                    if index != 0 {
                        switch view.entries[index - 1] {
                            case let .MessageEntry(message, _, _, _):
                                return (message, true)
                            default:
                                return nil
                        }
                    } else {
                        return nil
                    }
            }
        }
        index += 1
    }
    if !view.entries.isEmpty {
        switch position {
            case .later, .exact:
                switch view.entries[view.entries.count - 1] {
                    case let .MessageEntry(message, _, _, _):
                        return (message, false)
                    default:
                        return nil
                }
            case .earlier:
                switch view.entries[0] {
                    case let .MessageEntry(message, _, _, _):
                        return (message, false)
                    default:
                        return nil
                }
        }
    } else {
        return nil
    }
}

enum PeerMessagesPlaylistLocation: Equatable, SharedMediaPlaylistLocation {
    case messages(peerId: PeerId, tagMask: MessageTags, at: MessageId)
    case singleMessage(MessageId)
    
    var peerId: PeerId {
        switch self {
            case let .messages(peerId, _, _):
                return peerId
            case let .singleMessage(id):
                return id.peerId
        }
    }
    
    func isEqual(to: SharedMediaPlaylistLocation) -> Bool {
        if let to = to as? PeerMessagesPlaylistLocation {
            return self == to
        } else {
            return false
        }
    }
    
    static func ==(lhs: PeerMessagesPlaylistLocation, rhs: PeerMessagesPlaylistLocation) -> Bool {
        switch lhs {
            case let .messages(peerId, tagMask, at):
                if case .messages(peerId, tagMask, at) = rhs {
                    return true
                } else {
                    return false
                }
            case let .singleMessage(messageId):
                if case .singleMessage(messageId) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

struct PeerMessagesMediaPlaylistId: SharedMediaPlaylistId {
    let peerId: PeerId
    
    func isEqual(to: SharedMediaPlaylistId) -> Bool {
        if let to = to as? PeerMessagesMediaPlaylistId {
            return self.peerId == to.peerId
        }
        return false
    }
}
    
func peerMessageMediaPlayerType(_ message: Message) -> MediaManagerPlayerType? {
    for media in message.media {
        if let file = media as? TelegramMediaFile {
            if file.isVoice || file.isInstantVideo {
                return .voice
            } else if file.isMusic {
                return .music
            }
        }
    }
    return nil
}
    
func peerMessagesMediaPlaylistAndItemId(_ message: Message) -> (SharedMediaPlaylistId, SharedMediaPlaylistItemId)? {
    return (PeerMessagesMediaPlaylistId(peerId: message.id.peerId), PeerMessagesMediaPlaylistItemId(messageId: message.id))
}

final class PeerMessagesMediaPlaylist: SharedMediaPlaylist {
    private let postbox: Postbox
    private let network: Network
    private let messagesLocation: PeerMessagesPlaylistLocation
    
    var location: SharedMediaPlaylistLocation {
        return self.messagesLocation
    }
    
    private let navigationDisposable = MetaDisposable()
    
    private var currentItem: Message?
    private var loadingItem: Bool = false
    private var playedToEnd: Bool = false
    private var order: MusicPlaybackSettingsOrder = .regular
    private(set) var looping: MusicPlaybackSettingsLooping = .none
    
    let id: SharedMediaPlaylistId
    
    private let stateValue = Promise<SharedMediaPlaylistState>()
    var state: Signal<SharedMediaPlaylistState, NoError> {
        return self.stateValue.get()
    }
    
    init(postbox: Postbox, network: Network, location: PeerMessagesPlaylistLocation) {
        assert(Queue.mainQueue().isCurrent())
        
        self.id = PeerMessagesMediaPlaylistId(peerId: location.peerId)
        
        self.postbox = postbox
        self.network = network
        self.messagesLocation = location
        
        switch self.messagesLocation {
            case let .messages(_, _, messageId):
                self.loadItem(anchor: .messageId(messageId), navigation: .later)
            case let .singleMessage(messageId):
                self.loadItem(anchor: .messageId(messageId), navigation: .later)
        }
    }
    
    deinit {
        self.navigationDisposable.dispose()
    }
    
    func control(_ action: SharedMediaPlaylistControlAction) {
        assert(Queue.mainQueue().isCurrent())
        
        switch action {
            case .next, .previous:
                if !self.loadingItem {
                    if let currentItem = self.currentItem {
                        let navigation: PeerMessagesMediaPlaylistNavigation
                        switch self.order {
                            case .regular:
                                if case .next = action {
                                    navigation = .earlier
                                } else {
                                    navigation = .later
                                }
                            case .reversed:
                                if case .next = action {
                                    navigation = .later
                                } else {
                                    navigation = .earlier
                                }
                            case .random:
                                navigation = .random
                        }
                        self.loadItem(anchor: .index(MessageIndex(currentItem)), navigation: navigation)
                    }
                }
        }
    }
    
    func setOrder(_ order: MusicPlaybackSettingsOrder) {
        if self.order != order {
            self.order = order
            self.updateState()
        }
    }
    
    func setLooping(_ looping: MusicPlaybackSettingsLooping) {
        if self.looping != looping {
            self.looping = looping
            self.updateState()
        }
    }
    
    private func updateState() {
        self.stateValue.set(.single(SharedMediaPlaylistState(loading: self.loadingItem, playedToEnd: self.playedToEnd, item: self.currentItem.flatMap(MessageMediaPlaylistItem.init), order: self.order, looping: self.looping)))
    }
    
    private func loadItem(anchor: PeerMessagesMediaPlaylistLoadAnchor, navigation: PeerMessagesMediaPlaylistNavigation) {
        self.loadingItem = true
        self.updateState()
        switch anchor {
            case let .messageId(messageId):
                self.navigationDisposable.set((self.postbox.messageAtId(messageId) |> take(1) |> deliverOnMainQueue).start(next: { [weak self] message in
                    if let strongSelf = self {
                        assert(strongSelf.loadingItem)
                        
                        strongSelf.loadingItem = false
                        strongSelf.currentItem = message
                        strongSelf.updateState()
                    }
                }))
            case let .index(index):
                switch self.messagesLocation {
                    case let .messages(peerId, tagMask, _):
                        let inputIndex: Signal<MessageIndex, NoError>
                        let looping = self.looping
                        switch self.order {
                            case .regular, .reversed:
                                inputIndex = .single(index)
                            case .random:
                                inputIndex = self.postbox.modify { modifier -> MessageIndex in
                                    
                                    return modifier.findRandomMessage(peerId: peerId, tagMask: tagMask, ignoreId: index.id) ?? index
                                }
                        }
                        let historySignal = inputIndex |> mapToSignal { inputIndex -> Signal<Message?, NoError> in
                            return self.postbox.aroundMessageHistoryViewForLocation(.peer(peerId), index: .message(inputIndex), anchorIndex: .message(inputIndex), count: 10, clipHoles: false, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tagMask: tagMask, orderStatistics: [])
                            |> mapToSignal { view -> Signal<Message?, NoError> in
                                let position: NavigatedMessageFromViewPosition
                                switch navigation {
                                    case .later:
                                        position = .later
                                    case .earlier:
                                        position = .earlier
                                    case .random:
                                        position = .exact
                                }
                                
                                if let (message, exact) = navigatedMessageFromView(view.0, anchorIndex: inputIndex, position: position) {
                                    switch navigation {
                                        case .random:
                                            return .single(message)
                                        default:
                                            if exact {
                                                return .single(message)
                                            }
                                    }
                                }
                                
                                if case .all = looping {
                                    let viewIndex: MessageHistoryAnchorIndex
                                    if case .earlier = navigation {
                                        viewIndex = .upperBound
                                    } else {
                                        viewIndex = .lowerBound
                                    }
                                    return self.postbox.aroundMessageHistoryViewForLocation(.peer(peerId), index: viewIndex, anchorIndex: viewIndex, count: 10, clipHoles: false, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tagMask: tagMask, orderStatistics: [])
                                    |> mapToSignal { view -> Signal<Message?, NoError> in
                                        let position: NavigatedMessageFromViewPosition
                                        switch navigation {
                                            case .later, .random:
                                                position = .earlier
                                            case .earlier:
                                                position = .later
                                        }
                                        if let (message, _) = navigatedMessageFromView(view.0, anchorIndex: MessageIndex.absoluteLowerBound(), position: position) {
                                            return .single(message)
                                        } else {
                                            return .single(nil)
                                        }
                                    }
                                } else {
                                    return .single(nil)
                                }
                            }
                        } |> take(1) |> deliverOnMainQueue
                        self.navigationDisposable.set(historySignal.start(next: { [weak self] message in
                            if let strongSelf = self {
                                assert(strongSelf.loadingItem)
                                
                                strongSelf.loadingItem = false
                                if let message = message {
                                    strongSelf.currentItem = message
                                    strongSelf.playedToEnd = false
                                } else {
                                    strongSelf.playedToEnd = true
                                }
                                strongSelf.updateState()
                            }
                        }))
                    case .singleMessage:
                        self.navigationDisposable.set((self.postbox.messageAtId(index.id) |> take(1) |> deliverOnMainQueue).start(next: { [weak self] message in
                            if let strongSelf = self {
                                assert(strongSelf.loadingItem)
                                
                                strongSelf.loadingItem = false
                                strongSelf.currentItem = message
                                strongSelf.updateState()
                            }
                        }))
            }
        }
    }
    
    func onItemPlaybackStarted(_ item: SharedMediaPlaylistItem) {
        if let item = item as? MessageMediaPlaylistItem {
            let _ = markMessageContentAsConsumedInteractively(postbox: self.postbox, messageId: item.message.id).start()
        }
    }
}
