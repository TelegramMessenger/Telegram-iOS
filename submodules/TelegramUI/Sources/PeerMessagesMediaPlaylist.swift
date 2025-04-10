import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import AccountContext
import MusicAlbumArtResources
import TextFormat

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
    if let attribute = message.attributes.first(where: { $0 is TextTranscriptionMessageAttribute }) as? TextTranscriptionMessageAttribute {
        file = attribute.file
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
    
    lazy var playbackData: SharedMediaPlaybackData? = {
        if let file = extractFileMedia(self.message) {
            let fileReference = FileMediaReference.message(message: MessageReference(self.message), media: file)
            let source = SharedMediaPlaybackDataSource.telegramFile(reference: fileReference, isCopyProtected: self.message.isCopyProtected(), isViewOnce: self.message.minAutoremoveOrClearTimeout == viewOnceTimeout)
            for attribute in file.attributes {
                switch attribute {
                    case let .Audio(isVoice, _, _, _, _):
                        if isVoice {
                            return SharedMediaPlaybackData(type: .voice, source: source)
                        } else {
                            return SharedMediaPlaybackData(type: .music, source: source)
                        }
                    case let .Video(_, _, flags, _, _, _):
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
    }()

    lazy var displayData: SharedMediaPlaybackDisplayData? = {
        if let file = extractFileMedia(self.message) {
            let text = self.message.text
            var entities: [MessageTextEntity] = []
            if let result = addLocallyGeneratedEntities(text, enabledTypes: [.timecode], entities: [], mediaDuration: file.duration.flatMap(Double.init)) {
                entities = result
            }
              
            let textFont = Font.regular(14.0)
            let caption = stringWithAppliedEntities(text, entities: entities, baseColor: .white, linkColor: .white, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: textFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont, underlineLinks: false, message: self.message)
                        
            for attribute in file.attributes {
                switch attribute {
                case let .Audio(isVoice, duration, title, performer, _):
                    let displayData: SharedMediaPlaybackDisplayData
                    if isVoice {
                        displayData = SharedMediaPlaybackDisplayData.voice(author: self.message.effectiveAuthor.flatMap(EnginePeer.init), peer: self.message.peers[self.message.id.peerId].flatMap(EnginePeer.init))
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
                            albumArt = SharedMediaPlaybackAlbumArt(thumbnailResource: ExternalMusicAlbumArtResource(file: .message(message: MessageReference(self.message), media: file), title: updatedTitle ?? "", performer: updatedPerformer ?? "", isThumbnail: true), fullSizeResource: ExternalMusicAlbumArtResource(file: .message(message: MessageReference(self.message), media: file), title: updatedTitle ?? "", performer: updatedPerformer ?? "", isThumbnail: false))
                        }
                        
                        displayData = SharedMediaPlaybackDisplayData.music(title: updatedTitle, performer: updatedPerformer, albumArt: albumArt, long: CGFloat(duration) > 10.0 * 60.0, caption: caption)
                    }
                    return displayData
                case let .Video(_, _, flags, _, _, _):
                    if flags.contains(.instantRoundVideo) {
                        return SharedMediaPlaybackDisplayData.instantVideo(author: self.message.effectiveAuthor.flatMap(EnginePeer.init), peer: self.message.peers[self.message.id.peerId].flatMap(EnginePeer.init), timestamp: self.message.timestamp)
                    } else {
                        return nil
                    }
                default:
                    break
                }
            }
            
            return SharedMediaPlaybackDisplayData.music(title: file.fileName ?? "", performer: self.message.effectiveAuthor?.debugDisplayTitle ?? "", albumArt: nil, long: false, caption: caption)
        }
        return nil
    }()
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
    let filteredEntries = view.entries.filter { entry in
        if entry.message.minAutoremoveOrClearTimeout == viewOnceTimeout {
            return false
        } else {
            return true
        }
    }
    
    guard let index = filteredEntries.firstIndex(where: { $0.index.id == centralIndex.id }) else {
        return []
    }
    var result: [Message] = []
    if index != 0 {
        for i in (0 ..< index).reversed() {
            result.append(filteredEntries[i].message)
            break
        }
    }
    if index != filteredEntries.count - 1 {
        for i in index + 1 ..< filteredEntries.count {
            result.append(filteredEntries[i].message)
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

private func navigatedMessageFromView(_ view: MessageHistoryView, anchorIndex: MessageIndex, position: NavigatedMessageFromViewPosition, reversed: Bool) -> (message: Message, around: [Message], exact: Bool)? {
    var index = 0
    
    let filteredEntries = view.entries.filter { entry in
        if entry.message.minAutoremoveOrClearTimeout == viewOnceTimeout {
            return false
        } else {
            return true
        }
    }
    
    for entry in filteredEntries {
        if entry.index.id == anchorIndex.id {
            let currentGroupKey = entry.message.groupingKey
            
            switch position {
                case .exact:
                    return (entry.message, aroundMessagesFromView(view: view, centralIndex: entry.index), true)
                case .later:
                    if !reversed, let currentGroupKey {
                        if index - 1 > 0, filteredEntries[index - 1].message.groupingKey == currentGroupKey {
                            let message = filteredEntries[index - 1].message
                            return (message, aroundMessagesFromView(view: view, centralIndex: filteredEntries[index - 1].index), true)
                        } else {
                            for i in index ..< filteredEntries.count {
                                if filteredEntries[i].message.groupingKey != currentGroupKey {
                                    let message = filteredEntries[i].message
                                    return (message, aroundMessagesFromView(view: view, centralIndex: filteredEntries[i].index), true)
                                }
                            }
                        }
                    } else if index + 1 < filteredEntries.count {
                        let message = filteredEntries[index + 1].message
                        return (message, aroundMessagesFromView(view: view, centralIndex: filteredEntries[index + 1].index), true)
                    } else {
                        return nil
                    }
                case .earlier:
                    if !reversed, let currentGroupKey {
                        if index + 1 < filteredEntries.count, filteredEntries[index + 1].message.groupingKey == currentGroupKey {
                            let message = filteredEntries[index + 1].message
                            return (message, aroundMessagesFromView(view: view, centralIndex: filteredEntries[index + 1].index), true)
                        } else {
                            var nextGroupingKey: Int64?
                            for i in (0 ..< index).reversed() {
                                if let nextGroupingKey {
                                    if filteredEntries[i].message.groupingKey != nextGroupingKey {
                                        let message = filteredEntries[i + 1].message
                                        return (message, aroundMessagesFromView(view: view, centralIndex: filteredEntries[i + 1].index), true)
                                    } else if i == 0 {
                                        let message = filteredEntries[i].message
                                        return (message, aroundMessagesFromView(view: view, centralIndex: filteredEntries[i].index), true)
                                    }
                                } else if filteredEntries[i].message.groupingKey != currentGroupKey {
                                    if let groupingKey = filteredEntries[i].message.groupingKey {
                                        nextGroupingKey = groupingKey
                                    } else {
                                        let message = filteredEntries[i].message
                                        return (message, aroundMessagesFromView(view: view, centralIndex: filteredEntries[i].index), true)
                                    }
                                }
                            }
                        }
                    } else if index != 0 {
                        let message = filteredEntries[index - 1].message
                        if !reversed, let nextGroupingKey = message.groupingKey {
                            for i in (0 ..< index).reversed() {
                                if filteredEntries[i].message.groupingKey != nextGroupingKey {
                                    let message = filteredEntries[i + 1].message
                                    return (message, aroundMessagesFromView(view: view, centralIndex: filteredEntries[i + 1].index), true)
                                } else if i == 0 {
                                    let message = filteredEntries[i].message
                                    return (message, aroundMessagesFromView(view: view, centralIndex: filteredEntries[i].index), true)
                                }
                            }
                        }
                        return (message, aroundMessagesFromView(view: view, centralIndex: filteredEntries[index - 1].index), true)
                    } else {
                        return nil
                    }
            }
        }
        index += 1
    }
    if !filteredEntries.isEmpty {
        switch position {
            case .later, .exact:
                let message = filteredEntries[filteredEntries.count - 1].message
                return (message, aroundMessagesFromView(view: view, centralIndex: filteredEntries[filteredEntries.count - 1].index), false)
            case .earlier:
                let message = filteredEntries[0].message
                return (message, aroundMessagesFromView(view: view, centralIndex: filteredEntries[0].index), false)
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
    let context: AccountContext
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
            self.loadItem(anchor: .messageId(messageId), navigation: .later, reversed: self.order == .reversed)
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
                            self.loadItem(anchor: .index(currentItem.current.index), navigation: navigation, reversed: self.order == .reversed)
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
                self.currentlyObservedMessageDisposable.set((self.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.Message(id: id))
                |> filter { message in
                    if let _ = message {
                        return false
                    } else {
                        return true
                    }
                }
                |> take(1)
                |> deliverOnMainQueue).startStrict(next: { [weak self] _ in
                    self?.currentItemDisappeared?()
                }))
            } else {
                self.currentlyObservedMessageDisposable.set(nil)
            }
        }
    }
    
    private func loadItem(anchor: PeerMessagesMediaPlaylistLoadAnchor, navigation: PeerMessagesMediaPlaylistNavigation, reversed: Bool) {
        self.loadingItem = true
        self.updateState()
        
        let namespaces: MessageIdNamespaces
        if Namespaces.Message.allScheduled.contains(anchor.id.namespace) {
            namespaces = .just(Namespaces.Message.allScheduled)
        } else if Namespaces.Message.allQuickReply.contains(anchor.id.namespace) {
            namespaces = .just(Namespaces.Message.allQuickReply)
        } else {
            namespaces = .not(Namespaces.Message.allNonRegular)
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
                            
                            return self.context.account.postbox.aroundMessageHistoryViewForLocation(self.context.chatLocationInput(for: chatLocation, contextHolder: self.chatLocationContextHolder ?? Atomic<ChatLocationContextHolder?>(value: nil)), anchor: .index(message.index), ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), count: 10, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tag: .tag(tagMask), appendMessagesFromTheSameGroup: false, namespaces: namespaces, orderStatistics: [])
                            |> mapToSignal { view -> Signal<(Message, [Message])?, NoError> in
                                if let (message, aroundMessages, _) = navigatedMessageFromView(view.0, anchorIndex: message.index, position: .exact, reversed: reversed) {
                                    return .single((message, aroundMessages))
                                } else {
                                    return .single((message, []))
                                }
                            }
                        }
                        |> take(1)
                        |> deliverOnMainQueue
                        self.navigationDisposable.set(historySignal.startStrict(next: { [weak self] messageAndAroundMessages in
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
                        |> deliverOnMainQueue).startStrict(next: { [weak self] messages in
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
                        |> deliverOnMainQueue).startStrict(next: { [weak self] message in
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
                        var inputIndex: Signal<MessageIndex?, NoError>?
                        let looping = self.looping
                        switch self.order {
                            case .regular, .reversed:
                                inputIndex = .single(index)
                            case .random:
                                var playbackStack = self.playbackStack
                            
                                if case let .random(previous) = navigation, previous {
                                    let _ = playbackStack.pop()
                                    inner: while true {
                                        if let id = playbackStack.pop() {
                                            inputIndex = self.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: id))
                                            |> map { message in
                                                return message?.index
                                            }
                                            break inner
                                        } else {
                                            break
                                        }
                                    }
                                }
                            
                                if inputIndex == nil {
                                    if let peerId = chatLocation.peerId {
                                        inputIndex = self.context.engine.messages.findRandomMessage(peerId: peerId, namespace: Namespaces.Message.Cloud, tag: tagMask, ignoreIds: (playbackStack.ids, playbackStack.set))
                                        |> map { result in
                                            return result ?? index
                                        }
                                    } else {
                                        inputIndex = .single(nil)
                                    }
                                }
                        }
                        let historySignal = (inputIndex ?? .single(nil))
                        |> mapToSignal { inputIndex -> Signal<(Message, [Message])?, NoError> in
                            guard let inputIndex = inputIndex else {
                                return .single(nil)
                            }
                            return self.context.account.postbox.aroundMessageHistoryViewForLocation(self.context.chatLocationInput(for: chatLocation, contextHolder: self.chatLocationContextHolder ?? Atomic<ChatLocationContextHolder?>(value: nil)), anchor: .index(inputIndex), ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), count: 10, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tag: .tag(tagMask), appendMessagesFromTheSameGroup: false, namespaces: namespaces, orderStatistics: [])
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
                                
                                if let (message, aroundMessages, exact) = navigatedMessageFromView(view.0, anchorIndex: inputIndex, position: position, reversed: reversed) {
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
                                    return self.context.account.postbox.aroundMessageHistoryViewForLocation(self.context.chatLocationInput(for: chatLocation, contextHolder: self.chatLocationContextHolder ?? Atomic<ChatLocationContextHolder?>(value: nil)), anchor: viewIndex, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), count: 10, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tag: .tag(tagMask), appendMessagesFromTheSameGroup: false, namespaces: namespaces, orderStatistics: [])
                                    |> mapToSignal { view -> Signal<(Message, [Message])?, NoError> in
                                        let position: NavigatedMessageFromViewPosition
                                        switch navigation {
                                            case .later, .random:
                                                position = .earlier
                                            case .earlier:
                                                position = .later
                                        }
                                        if let (message, aroundMessages, _) = navigatedMessageFromView(view.0, anchorIndex: MessageIndex.absoluteLowerBound(), position: position, reversed: reversed) {
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
                        self.navigationDisposable.set(historySignal.startStrict(next: { [weak self] messageAndAroundMessages in
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
                        |> deliverOnMainQueue).startStrict(next: { [weak self] message in
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
                        self.navigationDisposable.set(historySignal.startStrict(next: { [weak self] messageAndAroundMessages, previousMessagesCount, shouldLoadMore in
                            if let strongSelf = self {
                                assert(strongSelf.loadingItem)
                                
                                if shouldLoadMore {
                                    if strongSelf.loadingMore {
                                        return
                                    }
                                    strongSelf.loadingMore = true
                                    loadMore?()
                                    
                                    strongSelf.loadMoreDisposable.set((messages
                                    |> deliverOnMainQueue).startStrict(next: { messages, totalCount, hasMore in
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        
                                        if messages.count > previousMessagesCount {
                                            strongSelf.loadItem(anchor: anchor, navigation: navigation, reversed: strongSelf.order == .reversed)
                                            
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
            let _ = self.context.engine.messages.markMessageContentAsConsumedInteractively(messageId: item.message.id).startStandalone()
        }
    }
}
