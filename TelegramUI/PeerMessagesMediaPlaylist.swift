import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore

private enum PeerMessagesMediaPlaylistLoadAnchor {
    case messageId(MessageId)
    case index(MessageIndex)
}

struct MessageMediaPlaylistItemId: Hashable {
    let stableId: UInt32
    
    var hashValue: Int {
        return self.stableId.hashValue
    }
    
    static func ==(lhs: MessageMediaPlaylistItemId, rhs: MessageMediaPlaylistItemId) -> Bool {
        return lhs.stableId == rhs.stableId
    }
}

final class MessageMediaPlaylistItem: SharedMediaPlaylistItem {
    let message: Message
    
    init(message: Message) {
        self.message = message
    }
    
    var stableId: AnyHashable {
        return MessageMediaPlaylistItemId(stableId: message.stableId)
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
                                return SharedMediaPlaybackDisplayData.music(title: title, performer: performer)
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

private func navigatedMessageFromView(_ view: MessageHistoryView, anchorIndex: MessageIndex, next: Bool) -> Message? {
    var index = 0
    for entry in view.entries {
        if entry.index.id == anchorIndex.id {
            if next {
                if index + 1 < view.entries.count {
                    switch view.entries[index + 1] {
                        case let .MessageEntry(message, _, _, _):
                            return message
                        default:
                            return nil
                    }
                } else {
                    return nil
                }
            } else {
                if index != 0 {
                    switch view.entries[index - 1] {
                        case let .MessageEntry(message, _, _, _):
                            return message
                        default:
                            return nil
                    }
                } else {
                    switch view.entries[0] {
                        case let .MessageEntry(message, _, _, _):
                            return message
                        default:
                            return nil
                    }
                }
            }
        }
        index += 1
    }
    if !view.entries.isEmpty {
        switch view.entries[0] {
            case let .MessageEntry(message, _, _, _):
                return message
            default:
                return nil
        }
    } else {
        return nil
    }
}

enum PeerMessagesMediaPlaylistLocation {
    case messages(peerId: PeerId, tagMask: MessageTags, at: MessageId)
    case singleMessage(MessageId)
}

final class PeerMessagesMediaPlaylist: SharedMediaPlaylist {
    private let postbox: Postbox
    private let network: Network
    private let location: PeerMessagesMediaPlaylistLocation
    
    private let navigationDisposable = MetaDisposable()
    
    private var currentItem: Message?
    private var loadingItem: Bool = false
    
    private let stateValue = Promise<SharedMediaPlaylistState>()
    var state: Signal<SharedMediaPlaylistState, NoError> {
        return self.stateValue.get()
    }
    
    init(postbox: Postbox, network: Network, location: PeerMessagesMediaPlaylistLocation) {
        assert(Queue.mainQueue().isCurrent())
        
        self.postbox = postbox
        self.network = network
        self.location = location
        
        switch self.location {
            case let .messages(_, _, messageId):
                self.loadItem(anchor: .messageId(messageId), lookForward: true)
            case let .singleMessage(messageId):
                self.loadItem(anchor: .messageId(messageId), lookForward: true)
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
                        let lookForward: Bool
                        if case .next = action {
                            lookForward = true
                        } else {
                            lookForward = false
                        }
                        self.loadItem(anchor: .index(MessageIndex(currentItem)), lookForward: lookForward)
                    }
                }
        }
    }
    
    private func updateState() {
        self.stateValue.set(.single(SharedMediaPlaylistState(loading: self.loadingItem, item: self.currentItem.flatMap(MessageMediaPlaylistItem.init))))
    }
    
    private func loadItem(anchor: PeerMessagesMediaPlaylistLoadAnchor, lookForward: Bool) {
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
                switch self.location {
                    case let .messages(peerId, tagMask, _):
                        self.navigationDisposable.set((self.postbox.aroundMessageHistoryViewForPeerId(peerId, index: index, count: 10, clipHoles: false, anchorIndex: index, fixedCombinedReadState: nil, topTaggedMessageIdNamespaces: [], tagMask: tagMask, orderStatistics: []) |> take(1) |> deliverOnMainQueue).start(next: { [weak self] view in
                            if let strongSelf = self {
                                assert(strongSelf.loadingItem)
                                
                                strongSelf.loadingItem = false
                                strongSelf.currentItem = navigatedMessageFromView(view.0, anchorIndex: index, next: lookForward)
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
}
