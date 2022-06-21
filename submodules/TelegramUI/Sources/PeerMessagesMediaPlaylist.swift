import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import AccountContext
import MusicAlbumArtResources

private enum PeerMessagesMediaPlaylistLoadAnchor {
    case messageId(MessageId)
    case index(MessageIndex)
    
    var id: MessageId {
        switch self {
            case let .messageId(id):
                return id
            case let .index(index):
                return index.id
        }
    }
}

private enum PeerMessagesMediaPlaylistNavigation {
    case earlier
    case later
    case random(previous: Bool)
}

struct MessageMediaPlaylistItemStableId: Hashable {
    let stableId: UInt32
}

private func extractFileMedia(_ message: Message) -> TelegramMediaFile? {
    var file: TelegramMediaFile?
    for media in message.media {
        if let media = media as? TelegramMediaFile {
            file = media
            break
        } else if let media = media as? TelegramMediaWebpage, case let .Loaded(content) = media.content, let f = content.file {
            file = f
            break
        }
    }
    return file
}

final class MessageMediaPlaylistItem: SharedMediaPlaylistItem {
    let id: SharedMediaPlaylistItemId
    let message: Message
    
    init(message: Message) {
        self.id = PeerMessagesMediaPlaylistItemId(messageId: message.id, messageIndex: message.index)
        self.message = message
    }
    
    var stableId: AnyHashable {
        return MessageMediaPlaylistItemStableId(stableId: message.stableId)
    }
    
    var playbackData: SharedMediaPlaybackData? {
        if let file = extractFileMedia(self.message) {
            let fileReference = FileMediaReference.message(message: MessageReference(self.message), media: file)
            let source = SharedMediaPlaybackDataSource.telegramFile(reference: fileReference, isCopyProtected: self.message.isCopyProtected())
            for attribute in file.attributes {
                switch attribute {
                    case let .Audio(isVoice, _, _, _, _):
                        if isVoice {
                            return SharedMediaPlaybackData(type: .voice, source: source)
                        } else {
                            return SharedMediaPlaybackData(type: .music, source: source)
                        }
                    case let .Video(_, _, flags):
                        if flags.contains(.instantRoundVideo) {
                            return SharedMediaPlaybackData(type: .instantVideo, source: source)
                        } else {
                            return nil
                        }
                    default:
                        break
                }
            }
            if file.mimeType.hasPrefix("audio/") {
                return SharedMediaPlaybackData(type: .music, source: source)
            }
            if let fileName = file.fileName {
                let ext = (fileName as NSString).pathExtension.lowercased()
                if ext == "wav" || ext == "opus" {
                    return SharedMediaPlaybackData(type: .music, source: source)
                }
            }
        }
        return nil
    }

    var displayData: SharedMediaPlaybackDisplayData? {
        if let file = extractFileMedia(self.message) {
            for attribute in file.attributes {
                switch attribute {
                    case let .Audio(isVoice, duration, title, performer, _):
                        if isVoice {
                            return SharedMediaPlaybackDisplayData.voice(author: self.message.effectiveAuthor, peer: self.message.peers[self.message.id.peerId])
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
                                albumArt = SharedMediaPlaybackAlbumArt(thumbnailResource: ExternalMusicAlbumArtResource(title: updatedTitle ?? "", performer: updatedPerformer ?? "", isThumbnail: true), fullSizeResource: ExternalMusicAlbumArtResource(title: updatedTitle ?? "", performer: updatedPerformer ?? "", isThumbnail: false))
                            }
                            
                            return SharedMediaPlaybackDisplayData.music(title: updatedTitle, performer: updatedPerformer, albumArt: albumArt, long: CGFloat(duration) > 10.0 * 60.0)
                        }
                    case let .Video(_, _, flags):
                        if flags.contains(.instantRoundVideo) {
                            return SharedMediaPlaybackDisplayData.instantVideo(author: self.message.effectiveAuthor, peer: self.message.peers[self.message.id.peerId], timestamp: self.message.timestamp)
                        } else {
                            return nil
                        }
                    default:
                        break
                }
            }
            
            return SharedMediaPlaybackDisplayData.music(title: file.fileName ?? "", performer: self.message.effectiveAuthor?.debugDisplayTitle ?? "", albumArt: nil, long: false)
        }
        return nil
    }
}

private enum NavigatedMessageFromViewPosition {
    case later
    case earlier
    case exact
}

private func aroundMessagesFromMessages(_ messages: [Message], centralIndex: MessageIndex) -> [Message] {
    guard let index = messages.firstIndex(where: { $0.index.id == centralIndex.id }) else {
        return []
    }
    var result: [Message] = []
    if index != 0 {
        for i in (0 ..< index).reversed() {
            result.append(messages[i])
            break
        }
    }
    if index != messages.count - 1 {
        for i in index + 1 ..< messages.count {
            result.append(messages[i])
            break
        }
    }
    return result
}

private func aroundMessagesFromView(view: MessageHistoryView, centralIndex: MessageIndex) -> [Message] {
    guard let index = view.entries.firstIndex(where: { $0.index.id == centralIndex.id }) else {
        return []
    }
    var result: [Message] = []
    if index != 0 {
        for i in (0 ..< index).reversed() {
            result.append(view.entries[i].message)
            break
        }
    }
    if index != view.entries.count - 1 {
        for i in index + 1 ..< view.entries.count {
            result.append(view.entries[i].message)
            break
        }
    }
    return result
}

private func navigatedMessageFromMessages(_ messages: [Message], anchorIndex: MessageIndex, position: NavigatedMessageFromViewPosition) -> (message: Message, around: [Message], exact: Bool)? {
    var index = 0
    for message in messages {
        if message.index.id == anchorIndex.id {
            switch position {
                case .exact:
                    return (message, aroundMessagesFromMessages(messages, centralIndex: message.index), true)
                case .earlier:
                    if index + 1 < messages.count {
                        let message = messages[index + 1]
                        return (message, aroundMessagesFromMessages(messages, centralIndex: messages[index + 1].index), true)
                    } else {
                        return nil
                    }
                case .later:
                    if index != 0 {
                        let message = messages[index - 1]
                        return (message, aroundMessagesFromMessages(messages, centralIndex: messages[index - 1].index), true)
                    } else {
                        return nil
                    }
            }
        }
        index += 1
    }
    if !messages.isEmpty {
        switch position {
            case .earlier, .exact:
                let message = messages[messages.count - 1]
                return (message, aroundMessagesFromMessages(messages, centralIndex: messages[messages.count - 1].index), false)
            case .later:
                let message = messages[0]
                return (message, aroundMessagesFromMessages(messages, centralIndex: messages[0].index), false)
        }
    } else {
        return nil
    }
}

private func navigatedMessageFromView(_ view: MessageHistoryView, anchorIndex: MessageIndex, position: NavigatedMessageFromViewPosition) -> (message: Message, around: [Message], exact: Bool)? {
    var index = 0
    for entry in view.entries {
        if entry.index.id == anchorIndex.id {
            switch position {
                case .exact:
                    return (entry.message, aroundMessagesFromView(view: view, centralIndex: entry.index), true)
                case .later:
                    if index + 1 < view.entries.count {
                        let message = view.entries[index + 1].message
                        return (message, aroundMessagesFromView(view: view, centralIndex: view.entries[index + 1].index), true)
                    } else {
                        return nil
                    }
                case .earlier:
                    if index != 0 {
                        let message = view.entries[index - 1].message
                        return (message, aroundMessagesFromView(view: view, centralIndex: view.entries[index - 1].index), true)
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
                let message = view.entries[view.entries.count - 1].message
                return (message, aroundMessagesFromView(view: view, centralIndex: view.entries[view.entries.count - 1].index), false)
            case .earlier:
                let message = view.entries[0].message
                return (message, aroundMessagesFromView(view: view, centralIndex: view.entries[0].index), false)
        }
    } else {
        return nil
    }
}

private struct PlaybackStack {
    var ids: [MessageId] = []
    var set: Set<MessageId> = []
    
    mutating func resetToId(_ id: MessageId) {
        if self.set.contains(id) {
            if let index = self.ids.firstIndex(of: id) {
                for i in (index + 1) ..< self.ids.count {
                    self.set.remove(self.ids[i])
                }
                self.ids.removeLast(self.ids.count - index - 1)
            } else {
                assertionFailure()
                self.clear()
                self.ids.append(id)
                self.set.insert(id)
            }
        } else {
            self.push(id)
        }
    }
    
    mutating func push(_ id: MessageId) {
        if self.set.contains(id) {
            if let index = self.ids.firstIndex(of: id) {
                self.ids.remove(at: index)
            }
        }
        self.ids.append(id)
        self.set.insert(id)
    }
    
    mutating func pop() -> MessageId? {
        if !self.ids.isEmpty {
            let id = self.ids.removeLast()
            self.set.remove(id)
            return id
        } else {
            return nil
        }
    }
    
    mutating func clear() {
        self.ids.removeAll()
        self.set.removeAll()
    }
}

final class PeerMessagesMediaPlaylist: SharedMediaPlaylist {
    private let context: AccountContext
    private let messagesLocation: PeerMessagesPlaylistLocation
    private let chatLocationContextHolder: Atomic<ChatLocationContextHolder?>?
    
    var location: SharedMediaPlaylistLocation {
        return self.messagesLocation
    }
    
    var currentItemDisappeared: (() -> Void)?
    
    private let navigationDisposable = MetaDisposable()
    private let loadMoreDisposable = MetaDisposable()
    
    private var playbackStack = PlaybackStack()
    
    private var currentItem: (current: Message, around: [Message])?
    private var currentlyObservedMessageId: MessageId?
    private let currentlyObservedMessageDisposable = MetaDisposable()
    private var loadingItem: Bool = false
    private var loadingMore: Bool = false
    private var playedToEnd: Bool = false
    private var order: MusicPlaybackSettingsOrder = .regular
    private(set) var looping: MusicPlaybackSettingsLooping = .none
    
    let id: SharedMediaPlaylistId
    
    private let stateValue = Promise<SharedMediaPlaylistState>()
    var state: Signal<SharedMediaPlaylistState, NoError> {
        return self.stateValue.get()
    }
    
    init(context: AccountContext, location: PeerMessagesPlaylistLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>?) {
        assert(Queue.mainQueue().isCurrent())
        
        self.id = location.playlistId
        
        self.context = context
        self.chatLocationContextHolder = chatLocationContextHolder
        self.messagesLocation = location
        
        switch self.messagesLocation {
            case let .messages(_, _, messageId), let .singleMessage(messageId), let .custom(_, messageId, _):
                self.loadItem(anchor: .messageId(messageId), navigation: .later)
            case let .recentActions(message):
                self.loadingItem = false
                self.currentItem = (message, [])
                self.updateState()
        }
    }
    
    deinit {
        self.navigationDisposable.dispose()
        self.loadMoreDisposable.dispose()
        self.currentlyObservedMessageDisposable.dispose()
    }
    
    func control(_ action: SharedMediaPlaylistControlAction) {
        assert(Queue.mainQueue().isCurrent())
        
        switch action {
            case .next, .previous:
                switch self.messagesLocation {
                    case .recentActions:
                        self.loadingItem = false
                        self.currentItem = nil
                        self.updateState()
                        return
                    default:
                        break
                }
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
                                navigation = .random(previous: action == .previous)
                        }
                        
                        if case .singleMessage = self.messagesLocation {
                            self.loadingItem = false
                            self.currentItem = nil
                            self.updateState()
                        } else {
                            self.loadItem(anchor: .index(currentItem.current.index), navigation: navigation)
                        }
                    }
                }
        }
    }
    
    func setOrder(_ order: MusicPlaybackSettingsOrder) {
        if self.order != order {
            self.order = order
            self.playbackStack.clear()
            if let (message, _) = self.currentItem {
                self.playbackStack.push(message.id)
            }
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
        var item: MessageMediaPlaylistItem?
        var nextItem: MessageMediaPlaylistItem?
        var previousItem: MessageMediaPlaylistItem?
        if let (message, aroundMessages) = self.currentItem {
            item = MessageMediaPlaylistItem(message: message)
            for around in aroundMessages {
                if around.index < message.index {
                    previousItem = MessageMediaPlaylistItem(message: around)
                } else {
                    nextItem = MessageMediaPlaylistItem(message: around)
                }
            }
        }
        self.stateValue.set(.single(SharedMediaPlaylistState(loading: self.loadingItem, playedToEnd: self.playedToEnd, item: item, nextItem: nextItem, previousItem: previousItem, order: self.order, looping: self.looping)))
        if item?.message.id != self.currentlyObservedMessageId {
            self.currentlyObservedMessageId = item?.message.id
            if let id = item?.message.id {
                let key: PostboxViewKey = .messages(Set([id]))
                self.currentlyObservedMessageDisposable.set((self.context.account.postbox.combinedView(keys: [key])
                |> filter { views in
                    if let view = views.views[key] as? MessagesView {
                        if !view.messages.isEmpty {
                            return false
                        }
                    }
                    return true
                }
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] _ in
                    self?.currentItemDisappeared?()
                }))
            } else {
                self.currentlyObservedMessageDisposable.set(nil)
            }
        }
    }
    
    private func loadItem(anchor: PeerMessagesMediaPlaylistLoadAnchor, navigation: PeerMessagesMediaPlaylistNavigation) {
        self.loadingItem = true
        self.updateState()
        
        let namespaces: MessageIdNamespaces
        if Namespaces.Message.allScheduled.contains(anchor.id.namespace) {
            namespaces = .just(Namespaces.Message.allScheduled)
        } else {
            namespaces = .not(Namespaces.Message.allScheduled)
        }
        
        switch anchor {
            case let .messageId(messageId):
                switch self.messagesLocation {
                    case let .messages(chatLocation, tagMask, _):
                        let historySignal = self.context.account.postbox.messageAtId(messageId)
                        |> take(1)
                        |> mapToSignal { message -> Signal<(Message, [Message])?, NoError> in
                            guard let message = message else {
                                return .single(nil)
                            }
                            
                            return self.context.account.postbox.aroundMessageHistoryViewForLocation(self.context.chatLocationInput(for: chatLocation, contextHolder: self.chatLocationContextHolder ?? Atomic<ChatLocationContextHolder?>(value: nil)), anchor: .index(message.index), ignoreMessagesInTimestampRange: nil, count: 10, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tagMask: tagMask, appendMessagesFromTheSameGroup: false, namespaces: namespaces, orderStatistics: [])
                            |> mapToSignal { view -> Signal<(Message, [Message])?, NoError> in
                                if let (message, aroundMessages, _) = navigatedMessageFromView(view.0, anchorIndex: message.index, position: .exact) {
                                    return .single((message, aroundMessages))
                                } else {
                                    return .single((message, []))
                                }
                            }
                        }
                        |> take(1)
                        |> deliverOnMainQueue
                        self.navigationDisposable.set(historySignal.start(next: { [weak self] messageAndAroundMessages in
                            if let strongSelf = self {
                                assert(strongSelf.loadingItem)
                                
                                strongSelf.loadingItem = false
                                if let (message, aroundMessages) = messageAndAroundMessages {
                                    strongSelf.playbackStack.clear()
                                    strongSelf.playbackStack.push(message.id)
                                    strongSelf.currentItem = (message, aroundMessages)
                                    strongSelf.playedToEnd = false
                                } else {
                                    strongSelf.playedToEnd = true
                                }
                                strongSelf.updateState()
                            }
                        }))
                    case let .custom(messages, at, _):
                        self.navigationDisposable.set((messages
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { [weak self] messages in
                            if let strongSelf = self {
                                assert(strongSelf.loadingItem)
                                
                                strongSelf.loadingItem = false
                                if let message = messages.0.first(where: { $0.id == at }) {
                                    strongSelf.playbackStack.clear()
                                    strongSelf.playbackStack.push(message.id)
                                    if let (message, aroundMessages, _) = navigatedMessageFromMessages(messages.0, anchorIndex: message.index, position: .exact) {
                                        strongSelf.currentItem = (message, aroundMessages)
                                    } else {
                                        strongSelf.currentItem = (message, [])
                                    }
                                    strongSelf.playedToEnd = false
                                } else {
                                    strongSelf.currentItem = nil
                                    strongSelf.playedToEnd = true
                                }
                                strongSelf.updateState()
                            }
                        }))
                    default:
                        self.navigationDisposable.set((self.context.account.postbox.messageAtId(messageId)
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { [weak self] message in
                            if let strongSelf = self {
                                assert(strongSelf.loadingItem)
                                
                                strongSelf.loadingItem = false
                                if let message = message {
                                    strongSelf.playbackStack.clear()
                                    strongSelf.playbackStack.push(message.id)
                                    strongSelf.currentItem = (message, [])
                                } else {
                                    strongSelf.currentItem = nil
                                }
                                strongSelf.updateState()
                            }
                        }))
                }
            case let .index(index):
                switch self.messagesLocation {
                    case let .messages(chatLocation, tagMask, _):
                        let inputIndex: Signal<MessageIndex?, NoError>
                        let looping = self.looping
                        switch self.order {
                            case .regular, .reversed:
                                inputIndex = .single(index)
                            case .random:
                                var playbackStack = self.playbackStack
                                inputIndex = self.context.account.postbox.transaction { transaction -> MessageIndex? in
                                    if case let .random(previous) = navigation, previous {
                                        let _ = playbackStack.pop()
                                        while true {
                                            if let id = playbackStack.pop() {
                                                if let message = transaction.getMessage(id) {
                                                    return message.index
                                                }
                                            } else {
                                                break
                                            }
                                        }
                                    }
                                    
                                    if let peerId = chatLocation.peerId {
                                        return transaction.findRandomMessage(peerId: peerId, namespace: Namespaces.Message.Cloud, tag: tagMask, ignoreIds: (playbackStack.ids, playbackStack.set)) ?? index
                                    } else {
                                        return nil
                                    }
                                }
                        }
                        let historySignal = inputIndex
                        |> mapToSignal { inputIndex -> Signal<(Message, [Message])?, NoError> in
                            guard let inputIndex = inputIndex else {
                                return .single(nil)
                            }
                            return self.context.account.postbox.aroundMessageHistoryViewForLocation(self.context.chatLocationInput(for: chatLocation, contextHolder: self.chatLocationContextHolder ?? Atomic<ChatLocationContextHolder?>(value: nil)), anchor: .index(inputIndex), ignoreMessagesInTimestampRange: nil, count: 10, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tagMask: tagMask, appendMessagesFromTheSameGroup: false, namespaces: namespaces, orderStatistics: [])
                            |> mapToSignal { view -> Signal<(Message, [Message])?, NoError> in
                                let position: NavigatedMessageFromViewPosition
                                switch navigation {
                                    case .later:
                                        position = .later
                                    case .earlier:
                                        position = .earlier
                                    case .random:
                                        position = .exact
                                }
                                
                                if let (message, aroundMessages, exact) = navigatedMessageFromView(view.0, anchorIndex: inputIndex, position: position) {
                                    switch navigation {
                                        case .random:
                                            return .single((message, []))
                                        default:
                                            if exact {
                                                return .single((message, aroundMessages))
                                            }
                                    }
                                }
                                
                                if case .all = looping {
                                    let viewIndex: HistoryViewInputAnchor
                                    if case .earlier = navigation {
                                        viewIndex = .upperBound
                                    } else {
                                        viewIndex = .lowerBound
                                    }
                                    return self.context.account.postbox.aroundMessageHistoryViewForLocation(self.context.chatLocationInput(for: chatLocation, contextHolder: self.chatLocationContextHolder ?? Atomic<ChatLocationContextHolder?>(value: nil)), anchor: viewIndex, ignoreMessagesInTimestampRange: nil, count: 10, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tagMask: tagMask, appendMessagesFromTheSameGroup: false, namespaces: namespaces, orderStatistics: [])
                                    |> mapToSignal { view -> Signal<(Message, [Message])?, NoError> in
                                        let position: NavigatedMessageFromViewPosition
                                        switch navigation {
                                            case .later, .random:
                                                position = .earlier
                                            case .earlier:
                                                position = .later
                                        }
                                        if let (message, aroundMessages, _) = navigatedMessageFromView(view.0, anchorIndex: MessageIndex.absoluteLowerBound(), position: position) {
                                            return .single((message, aroundMessages))
                                        } else {
                                            return .single(nil)
                                        }
                                    }
                                } else {
                                    return .single(nil)
                                }
                            }
                        }
                        |> take(1)
                        |> deliverOnMainQueue
                        self.navigationDisposable.set(historySignal.start(next: { [weak self] messageAndAroundMessages in
                            if let strongSelf = self {
                                assert(strongSelf.loadingItem)
                                
                                strongSelf.loadingItem = false
                                if let (message, aroundMessages) = messageAndAroundMessages {
                                    if case let .random(previous) = navigation, previous {
                                        strongSelf.playbackStack.resetToId(message.id)
                                    } else {
                                        strongSelf.playbackStack.push(message.id)
                                    }
                                    strongSelf.currentItem = (message, aroundMessages)
                                    strongSelf.playedToEnd = false
                                } else {
                                    strongSelf.playedToEnd = true
                                }
                                strongSelf.updateState()
                            }
                        }))
                    case .singleMessage:
                        self.navigationDisposable.set((self.context.account.postbox.messageAtId(index.id)
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { [weak self] message in
                            if let strongSelf = self {
                                assert(strongSelf.loadingItem)
                                
                                strongSelf.loadingItem = false
                                if let message = message {
                                    strongSelf.currentItem = (message, [])
                                } else {
                                    strongSelf.currentItem = nil
                                }
                                strongSelf.updateState()
                            }
                        }))
                    case let .recentActions(message):
                        self.loadingItem = false
                        self.currentItem = (message, [])
                        self.updateState()
                    case let .custom(messages, _, loadMore):
                        let inputIndex: Signal<MessageIndex, NoError>
                        let looping = self.looping
                        switch self.order {
                            case .regular, .reversed:
                                inputIndex = .single(index)
                            case .random:
                                var playbackStack = self.playbackStack
                                inputIndex = messages
                                |> take(1)
                                |> map { messages, _, _ -> MessageIndex in
                                    if case let .random(previous) = navigation, previous {
                                        let _ = playbackStack.pop()
                                        while true {
                                            if let id = playbackStack.pop() {
                                                if let message = messages.first(where: { $0.id == id }) {
                                                    return message.index
                                                }
                                            } else {
                                                break
                                            }
                                        }
                                    }
                                    return messages.randomElement()?.index ?? index
                                }
                        }
                        let historySignal = inputIndex
                        |> mapToSignal { inputIndex -> Signal<((Message, [Message])?, Int, Bool), NoError> in
                            return messages
                            |> take(1)
                            |> mapToSignal { messages, _, hasMore -> Signal<((Message, [Message])?, Int, Bool), NoError> in
                                let position: NavigatedMessageFromViewPosition
                                switch navigation {
                                    case .later:
                                        position = .later
                                    case .earlier:
                                        position = .earlier
                                    case .random:
                                        position = .exact
                                }
                                
                                if let (message, aroundMessages, exact) = navigatedMessageFromMessages(messages, anchorIndex: inputIndex, position: position) {
                                    switch navigation {
                                        case .random:
                                            return .single(((message, []), messages.count, false))
                                        default:
                                            if exact {
                                                return .single(((message, aroundMessages), messages.count, false))
                                            }
                                    }
                                }
                                
                                if case .all = looping {
                                    return .single((nil, messages.count, false))
                                } else {
                                    if hasMore {
                                        return .single((nil, messages.count, true))
                                    } else {
                                        return .single((nil, messages.count, false))
                                    }
                                }
                            }
                        }
                        |> take(1)
                        |> deliverOnMainQueue
                        self.navigationDisposable.set(historySignal.start(next: { [weak self] messageAndAroundMessages, previousMessagesCount, shouldLoadMore in
                            if let strongSelf = self {
                                assert(strongSelf.loadingItem)
                                
                                if shouldLoadMore {
                                    if strongSelf.loadingMore {
                                        return
                                    }
                                    strongSelf.loadingMore = true
                                    loadMore?()
                                    
                                    strongSelf.loadMoreDisposable.set((messages
                                    |> deliverOnMainQueue).start(next: { messages, totalCount, hasMore in
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        
                                        if messages.count > previousMessagesCount {
                                            strongSelf.loadItem(anchor: anchor, navigation: navigation)
                                            
                                            strongSelf.loadMoreDisposable.set(nil)
                                            strongSelf.loadingMore = false
                                        }
                                    }))
                                } else {
                                    strongSelf.loadingItem = false
                                    if let (message, aroundMessages) = messageAndAroundMessages {
                                        if case let .random(previous) = navigation, previous {
                                            strongSelf.playbackStack.resetToId(message.id)
                                        } else {
                                            strongSelf.playbackStack.push(message.id)
                                        }
                                        strongSelf.currentItem = (message, aroundMessages)
                                        strongSelf.playedToEnd = false
                                    } else {
                                        strongSelf.playedToEnd = true
                                    }
                                    strongSelf.updateState()
                                }
                            }
                        }))
            }
        }
    }
    
    func onItemPlaybackStarted(_ item: SharedMediaPlaylistItem) {
        if let item = item as? MessageMediaPlaylistItem {
            switch self.messagesLocation {
                case .recentActions:
                    return
                default:
                    break
            }
            let _ = self.context.engine.messages.markMessageContentAsConsumedInteractively(messageId: item.message.id).start()
        }
    }
}
