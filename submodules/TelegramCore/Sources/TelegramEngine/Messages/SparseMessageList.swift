import SwiftSignalKit
import Postbox
import TelegramApi

public final class SparseMessageList {
    private final class Impl {
        private let queue: Queue
        private let account: Account
        private let peerId: PeerId
        private let messageTag: MessageTags

        private struct TopSection: Equatable {
            var messages: [Message]

            static func ==(lhs: TopSection, rhs: TopSection) -> Bool {
                if lhs.messages.count != rhs.messages.count {
                    return false
                }
                for i in 0 ..< lhs.messages.count {
                    if lhs.messages[i].id != rhs.messages[i].id {
                        return false
                    }
                    if lhs.messages[i].stableVersion != rhs.messages[i].stableVersion {
                        return false
                    }
                }
                return true
            }
        }

        private struct SparseItems: Equatable {
            enum Item: Equatable {
                case range(count: Int)
                case anchor(id: MessageId, timestamp: Int32, message: Message?)

                static func ==(lhs: Item, rhs: Item) -> Bool {
                    switch lhs {
                    case let .range(count):
                        if case .range(count) = rhs {
                            return true
                        } else {
                            return false
                        }
                    case let .anchor(lhsId, lhsTimestamp, lhsMessage):
                        if case let .anchor(rhsId, rhsTimestamp, rhsMessage) = rhs {
                            if lhsId != rhsId {
                                return false
                            }
                            if lhsTimestamp != rhsTimestamp {
                                return false
                            }
                            if let lhsMessage = lhsMessage, let rhsMessage = rhsMessage {
                                if lhsMessage.id != rhsMessage.id {
                                    return false
                                }
                                if lhsMessage.stableVersion != rhsMessage.stableVersion {
                                    return false
                                }
                            } else if (lhsMessage != nil) != (rhsMessage != nil) {
                                return false
                            }
                            return true
                        } else {
                            return false
                        }
                    }
                }
            }

            var items: [Item]
        }

        private var topSectionItemRequestCount: Int = 100
        private var topSection: TopSection?
        private var topItemsDisposable = MetaDisposable()

        private var sparseItems: SparseItems?
        private var sparseItemsDisposable: Disposable?

        private struct LoadingHole: Equatable {
            var anchor: MessageId
            var direction: LoadHoleDirection
        }
        private let loadHoleDisposable = MetaDisposable()
        private var loadingHole: LoadingHole?

        private var loadingPlaceholders: [MessageId: Disposable] = [:]
        private var loadedPlaceholders: [MessageId: Message] = [:]

        let statePromise = Promise<SparseMessageList.State>()

        init(queue: Queue, account: Account, peerId: PeerId, messageTag: MessageTags) {
            self.queue = queue
            self.account = account
            self.peerId = peerId
            self.messageTag = messageTag

            self.resetTopSection()

            self.sparseItemsDisposable = (self.account.postbox.transaction { transaction -> Api.InputPeer? in
                return transaction.getPeer(peerId).flatMap(apiInputPeer)
            }
            |> mapToSignal { inputPeer -> Signal<SparseItems, NoError> in
                guard let inputPeer = inputPeer else {
                    return .single(SparseItems(items: []))
                }
                guard let messageFilter = messageFilterForTagMask(messageTag) else {
                    return .single(SparseItems(items: []))
                }
                return account.network.request(Api.functions.messages.getSearchResultsPositions(peer: inputPeer, filter: messageFilter, offsetId: 0, limit: 1000))
                |> map { result -> SparseItems in
                    switch result {
                    case let .searchResultsPositions(totalCount, positions):
                        struct Position: Equatable {
                            var id: Int32
                            var date: Int32
                            var offset: Int
                        }
                        var positions: [Position] = positions.map { position -> Position in
                            switch position {
                            case let .searchResultPosition(id, date, offset):
                                return Position(id: id, date: date, offset: Int(offset))
                            }
                        }
                        positions.sort(by: { lhs, rhs in
                            return lhs.id > rhs.id
                        })

                        var result = SparseItems(items: [])
                        for i in 0 ..< positions.count {
                            if i != 0 {
                                let deltaCount = positions[i].offset - 1 - positions[i - 1].offset
                                if deltaCount > 0 {
                                    result.items.append(.range(count: deltaCount))
                                }
                            }
                            result.items.append(.anchor(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: positions[i].id), timestamp: positions[i].date, message: nil))
                            if i == positions.count - 1 {
                                let remainingCount = Int(totalCount) - 1 - positions[i].offset
                                if remainingCount > 0 {
                                    result.items.append(.range(count: remainingCount))
                                }
                            }
                        }

                        return result
                    }
                }
                |> `catch` { _ -> Signal<SparseItems, NoError> in
                    return .single(SparseItems(items: []))
                }
            }
            |> deliverOnMainQueue).start(next: { [weak self] sparseItems in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.sparseItems = sparseItems
                if strongSelf.topSection != nil {
                    strongSelf.updateState()
                }
            })
        }

        deinit {
            self.topItemsDisposable.dispose()
            self.sparseItemsDisposable?.dispose()
            self.loadHoleDisposable.dispose()
        }

        private func resetTopSection() {
            let count: Int
            #if DEBUG
            count = 20
            #else
            count = 200
            #endif
            self.topItemsDisposable.set((self.account.postbox.aroundMessageHistoryViewForLocation(.peer(peerId), anchor: .upperBound, count: count, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: Set(), tagMask: self.messageTag, appendMessagesFromTheSameGroup: false, namespaces: .not(Set(Namespaces.Message.allScheduled)), orderStatistics: [])
            |> deliverOn(self.queue)).start(next: { [weak self] view, updateType, _ in
                guard let strongSelf = self else {
                    return
                }
                switch updateType {
                case .FillHole:
                    strongSelf.resetTopSection()
                default:
                    strongSelf.updateTopSection(view: view)
                }
            }))
        }

        func loadMoreFromTopSection() {
            self.topSectionItemRequestCount += 100
            self.resetTopSection()
        }

        func loadPlaceholders(ids: [MessageId]) {
            var loadGlobalIds: [MessageId] = []
            var loadChannelIds: [PeerId: [MessageId]] = [:]
            for id in ids {
                if self.loadingPlaceholders[id] != nil {
                    continue
                }
                self.loadingPlaceholders[id] = MetaDisposable()
                if id.peerId.namespace == Namespaces.Peer.CloudUser || id.peerId.namespace == Namespaces.Peer.CloudGroup {
                    loadGlobalIds.append(id)
                } else if id.peerId.namespace == Namespaces.Peer.CloudChannel {
                    if loadChannelIds[id.peerId] == nil {
                        loadChannelIds[id.peerId] = []
                    }
                    loadChannelIds[id.peerId]!.append(id)
                }
            }

            var loadSignals: [Signal<(messages: [Api.Message], chats: [Api.Chat], users: [Api.User]), NoError>] = []
            let account = self.account

            if !loadGlobalIds.isEmpty {
                loadSignals.append(self.account.postbox.transaction { transaction -> [Api.InputMessage] in
                    var result: [Api.InputMessage] = []
                    for id in loadGlobalIds {
                        let inputMessage: Api.InputMessage = .inputMessageID(id: id.id)
                        result.append(inputMessage)
                    }
                    return result
                }
                |> mapToSignal { inputMessages -> Signal<(messages: [Api.Message], chats: [Api.Chat], users: [Api.User]), NoError> in
                    return account.network.request(Api.functions.messages.getMessages(id: inputMessages))
                    |> map { result -> (messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) in
                        switch result {
                        case let .messages(messages, chats, users):
                            return (messages, chats, users)
                        case let .messagesSlice(_, _, _, _, messages, chats, users):
                            return (messages, chats, users)
                        case let .channelMessages(_, _, _, _, messages, chats, users):
                            return (messages, chats, users)
                        case .messagesNotModified:
                            return ([], [], [])
                        }
                    }
                    |> `catch` { _ -> Signal<(messages: [Api.Message], chats: [Api.Chat], users: [Api.User]), NoError> in
                        return .single(([], [], []))
                    }
                })
            }

            if !loadChannelIds.isEmpty {
                for (channelId, ids) in loadChannelIds {
                    loadSignals.append(self.account.postbox.transaction { transaction -> Api.InputChannel? in
                        return transaction.getPeer(channelId).flatMap(apiInputChannel)
                    }
                    |> mapToSignal { inputChannel -> Signal<(messages: [Api.Message], chats: [Api.Chat], users: [Api.User]), NoError> in
                        guard let inputChannel = inputChannel else {
                            return .single(([], [], []))
                        }

                        return account.network.request(Api.functions.channels.getMessages(channel: inputChannel, id: ids.map { Api.InputMessage.inputMessageID(id: $0.id) }))
                        |> map { result -> (messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) in
                            switch result {
                            case let .messages(messages, chats, users):
                                return (messages, chats, users)
                            case let .messagesSlice(_, _, _, _, messages, chats, users):
                                return (messages, chats, users)
                            case let .channelMessages(_, _, _, _, messages, chats, users):
                                return (messages, chats, users)
                            case .messagesNotModified:
                                return ([], [], [])
                            }
                        }
                        |> `catch` { _ -> Signal<(messages: [Api.Message], chats: [Api.Chat], users: [Api.User]), NoError> in
                            return .single(([], [], []))
                        }
                    })
                }
            }

            let _ = (combineLatest(queue: self.queue, loadSignals)
            |> mapToSignal { messageLists -> Signal<[Message], NoError> in
                return account.postbox.transaction { transaction -> [Message] in
                    var parsedMessages: [StoreMessage] = []
                    var peers: [Peer] = []
                    var peerPresences: [PeerId: PeerPresence] = [:]

                    for (messages, chats, users) in messageLists {
                        for chat in chats {
                            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                peers.append(groupOrChannel)
                            }
                        }
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                            if let presence = TelegramUserPresence(apiUser: user) {
                                peerPresences[telegramUser.id] = presence
                            }
                        }

                        for message in messages {
                            if let parsedMessage = StoreMessage(apiMessage: message) {
                                parsedMessages.append(parsedMessage)
                            }
                        }
                    }

                    updatePeers(transaction: transaction, peers: peers, update: { _, updated in updated })
                    updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                    let _ = transaction.addMessages(parsedMessages, location: .Random)

                    var result: [Message] = []
                    for parsedMessage in parsedMessages {
                        switch parsedMessage.id {
                        case let .Id(id):
                            if let message = transaction.getMessage(id) {
                                result.append(message)
                            }
                        case .Partial:
                            break
                        }
                    }

                    return result
                }
            }
            |> deliverOn(self.queue)).start(next: { [weak self] messages in
                guard let strongSelf = self else {
                    return
                }
                for message in messages {
                    strongSelf.loadedPlaceholders[message.id] = message
                }
                if strongSelf.sparseItems != nil {
                    for i in 0 ..< strongSelf.sparseItems!.items.count {
                        switch strongSelf.sparseItems!.items[i] {
                        case let .anchor(id, timestamp, _):
                            if let message = strongSelf.loadedPlaceholders[id] {
                                strongSelf.sparseItems!.items[i] = .anchor(id: id, timestamp: timestamp, message: message)
                            }
                        case .range:
                            break
                        }
                    }
                }

                strongSelf.updateState()
            })
        }

        func loadHole(anchor: MessageId, direction: LoadHoleDirection, completion: @escaping () -> Void) {
            let loadingHole = LoadingHole(anchor: anchor, direction: direction)
            if self.loadingHole == loadingHole {
                completion()
                return
            }

            if self.loadingHole != nil {
                completion()
                return
            }

            self.loadingHole = loadingHole
            let mappedDirection: MessageHistoryViewRelativeHoleDirection
            switch direction {
            case .around:
                mappedDirection = .aroundId(anchor)
            case .earlier:
                mappedDirection = .range(start: anchor, end: MessageId(peerId: anchor.peerId, namespace: anchor.namespace, id: 1))
            case .later:
                mappedDirection = .range(start: anchor, end: MessageId(peerId: anchor.peerId, namespace: anchor.namespace, id: Int32.max - 1))
            }
            let account = self.account
            self.loadHoleDisposable.set((fetchMessageHistoryHole(accountPeerId: self.account.peerId, source: .network(self.account.network), postbox: self.account.postbox, peerInput: .direct(peerId: self.peerId, threadId: nil), namespace: Namespaces.Message.Cloud, direction: mappedDirection, space: .tag(self.messageTag), count: 100)
            |> mapToSignal { result -> Signal<[Message], NoError> in
                guard let result = result else {
                    return .single([])
                }
                return account.postbox.transaction { transaction -> [Message] in
                    return result.ids.sorted(by: { $0 > $1 }).compactMap(transaction.getMessage)
                }
            }
            |> deliverOn(self.queue)).start(next: { [weak self] messages in
                guard let strongSelf = self else {
                    completion()
                    return
                }

                if strongSelf.sparseItems != nil {
                    var sparseHoles: [(itemIndex: Int, leftId: MessageId, rightId: MessageId)] = []
                    for i in 0 ..< strongSelf.sparseItems!.items.count {
                        switch strongSelf.sparseItems!.items[i] {
                        case let .anchor(id, timestamp, _):
                            for messageIndex in 0 ..< messages.count {
                                if messages[messageIndex].id == id {
                                    strongSelf.sparseItems!.items[i] = .anchor(id: id, timestamp: timestamp, message: messages[messageIndex])
                                }
                            }
                        case .range:
                            if i == 0 {
                                assertionFailure()
                            } else {
                                var leftId: MessageId?
                                switch strongSelf.sparseItems!.items[i - 1] {
                                case .range:
                                    assertionFailure()
                                case let .anchor(id, _, _):
                                    leftId = id
                                }
                                var rightId: MessageId?
                                if i != strongSelf.sparseItems!.items.count - 1 {
                                    switch strongSelf.sparseItems!.items[i + 1] {
                                    case .range:
                                        assertionFailure()
                                    case let .anchor(id, _, _):
                                        rightId = id
                                    }
                                }
                                if let leftId = leftId, let rightId = rightId {
                                    sparseHoles.append((itemIndex: i, leftId: leftId, rightId: rightId))
                                } else if let leftId = leftId, i == strongSelf.sparseItems!.items.count - 1 {
                                    sparseHoles.append((itemIndex: i, leftId: leftId, rightId: MessageId(peerId: leftId.peerId, namespace: leftId.namespace, id: 1)))
                                } else {
                                    assertionFailure()
                                }
                            }
                        }
                    }

                    for (itemIndex, initialLeftId, initialRightId) in sparseHoles.reversed() {
                        var leftCovered = false
                        var rightCovered = false
                        for message in messages {
                            if message.id == initialLeftId {
                                leftCovered = true
                            }
                            if message.id == initialRightId {
                                rightCovered = true
                            }
                        }
                        if leftCovered && rightCovered {
                            strongSelf.sparseItems!.items.remove(at: itemIndex)
                            var insertIndex = itemIndex
                            for message in messages {
                                if message.id < initialLeftId && message.id > initialRightId {
                                    strongSelf.sparseItems!.items.insert(.anchor(id: message.id, timestamp: message.timestamp, message: message), at: insertIndex)
                                    insertIndex += 1
                                }
                            }
                        } else if leftCovered {
                            for i in 0 ..< messages.count {
                                if messages[i].id == initialLeftId {
                                    var spaceItemIndex = itemIndex
                                    for j in i + 1 ..< messages.count {
                                        switch strongSelf.sparseItems!.items[spaceItemIndex] {
                                        case let .range(count):
                                            strongSelf.sparseItems!.items[spaceItemIndex] = .range(count: count - 1)
                                        case .anchor:
                                            assertionFailure()
                                        }
                                        strongSelf.sparseItems!.items.insert(.anchor(id: messages[j].id, timestamp: messages[j].timestamp, message: messages[j]), at: spaceItemIndex)
                                        spaceItemIndex += 1
                                    }
                                    switch strongSelf.sparseItems!.items[spaceItemIndex] {
                                    case let .range(count):
                                        if count <= 0 {
                                            strongSelf.sparseItems!.items.remove(at: spaceItemIndex)
                                        }
                                    case .anchor:
                                        assertionFailure()
                                    }
                                    break
                                }
                            }
                        } else if rightCovered {
                            for i in (0 ..< messages.count).reversed() {
                                if messages[i].id == initialRightId {
                                    for j in (0 ..< i).reversed() {
                                        switch strongSelf.sparseItems!.items[itemIndex] {
                                        case let .range(count):
                                            strongSelf.sparseItems!.items[itemIndex] = .range(count: count - 1)
                                        case .anchor:
                                            assertionFailure()
                                        }
                                        strongSelf.sparseItems!.items.insert(.anchor(id: messages[j].id, timestamp: messages[j].timestamp, message: messages[j]), at: itemIndex + 1)
                                    }
                                    switch strongSelf.sparseItems!.items[itemIndex] {
                                    case let .range(count):
                                        if count <= 0 {
                                            strongSelf.sparseItems!.items.remove(at: itemIndex)
                                        }
                                    case .anchor:
                                        assertionFailure()
                                    }
                                    break
                                }
                            }
                        }
                    }

                    strongSelf.updateState()
                }

                if strongSelf.loadingHole == loadingHole {
                    strongSelf.loadingHole = nil
                }

                completion()
            }))
        }

        private func updateTopSection(view: MessageHistoryView) {
            var topSection: TopSection?

            if view.isLoading {
                topSection = nil
            } else {
                topSection = TopSection(messages: view.entries.lazy.reversed().map { entry in
                    return entry.message
                })
            }

            if self.topSection != topSection {
                self.topSection = topSection
            }
            self.updateState()
        }

        private func updateState() {
            var items: [SparseMessageList.State.Item] = []
            var minMessageId: MessageId?
            if let topSection = self.topSection {
                for i in 0 ..< topSection.messages.count {
                    let message = topSection.messages[i]
                    items.append(SparseMessageList.State.Item(index: items.count, content: .message(message: message, isLocal: true)))
                    if let minMessageIdValue = minMessageId {
                        if message.id < minMessageIdValue {
                            minMessageId = message.id
                        }
                    } else {
                        minMessageId = message.id
                    }
                }
            }

            let topItemCount = items.count
            var totalCount = items.count
            if let minMessageId = minMessageId, let sparseItems = self.sparseItems {
                var sparseIndex = 0
                let _ = minMessageId
                for i in 0 ..< sparseItems.items.count {
                    switch sparseItems.items[i] {
                    case let .anchor(id, timestamp, message):
                        if sparseIndex >= topItemCount {
                            if let message = message {
                                items.append(SparseMessageList.State.Item(index: totalCount, content: .message(message: message, isLocal: false)))
                            } else {
                                items.append(SparseMessageList.State.Item(index: totalCount, content: .placeholder(id: id, timestamp: timestamp)))
                            }
                            totalCount += 1
                        }
                        sparseIndex += 1
                    case let .range(count):
                        if sparseIndex >= topItemCount {
                            totalCount += count
                        } else {
                            let overflowCount = sparseIndex + count - topItemCount
                            if overflowCount > 0 {
                                totalCount += count
                            }
                        }
                        sparseIndex += count
                    }
                }
            }

            self.statePromise.set(.single(SparseMessageList.State(
                items: items,
                totalCount: totalCount,
                isLoading: self.topSection == nil
            )))
        }
    }

    private let queue: Queue
    private let impl: QueueLocalObject<Impl>

    public struct State {
        public final class Item {
            public enum Content {
                case message(message: Message, isLocal: Bool)
                case placeholder(id: MessageId, timestamp: Int32)
            }

            public let index: Int
            public let content: Content

            init(index: Int, content: Content) {
                self.index = index
                self.content = content
            }
        }

        public var items: [Item]
        public var totalCount: Int
        public var isLoading: Bool
    }

    public enum LoadHoleDirection {
        case around
        case earlier
        case later
    }

    public var state: Signal<State, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()

            self.impl.with { impl in
                disposable.set(impl.statePromise.get().start(next: subscriber.putNext))
            }

            return disposable
        }
    }

    init(account: Account, peerId: PeerId, messageTag: MessageTags) {
        self.queue = .mainQueue()
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, peerId: peerId, messageTag: messageTag)
        })
    }

    public func loadMoreFromTopSection() {
        self.impl.with { impl in
            impl.loadMoreFromTopSection()
        }
    }

    public func loadHole(anchor: MessageId, direction: LoadHoleDirection, completion: @escaping () -> Void) {
        self.impl.with { impl in
            impl.loadHole(anchor: anchor, direction: direction, completion: completion)
        }
    }
}

public final class SparseMessageCalendar {
    private final class Impl {
        struct InternalState {
            var nextRequestOffset: Int32?
            var minTimestamp: Int32?
            var messagesByDay: [Int32: Message]
        }

        private let queue: Queue
        private let account: Account
        private let peerId: PeerId
        private let messageTag: MessageTags

        private var state: InternalState
        let statePromise = Promise<InternalState>()

        private let disposable = MetaDisposable()
        private var isLoadingMore: Bool = false {
            didSet {
                self.isLoadingMorePromise.set(.single(self.isLoadingMore))
            }
        }

        private let isLoadingMorePromise = Promise<Bool>(false)
        var isLoadingMoreSignal: Signal<Bool, NoError> {
            return self.isLoadingMorePromise.get()
        }

        init(queue: Queue, account: Account, peerId: PeerId, messageTag: MessageTags) {
            self.queue = queue
            self.account = account
            self.peerId = peerId
            self.messageTag = messageTag

            self.state = InternalState(nextRequestOffset: 0, minTimestamp: nil, messagesByDay: [:])
            self.statePromise.set(.single(self.state))

            self.maybeLoadMore()
        }

        deinit {
            self.disposable.dispose()
        }

        func maybeLoadMore() {
            if self.isLoadingMore {
                return
            }
            self.loadMore()
        }

        private func loadMore() {
            guard let nextRequestOffset = self.state.nextRequestOffset else {
                return
            }

            self.isLoadingMore = true

            struct LoadResult {
                var messagesByDay: [Int32: Message]
                var nextOffset: Int32?
                var minMessageId: MessageId?
                var minTimestamp: Int32?
            }

            let account = self.account
            let peerId = self.peerId
            let messageTag = self.messageTag
            self.disposable.set((self.account.postbox.transaction { transaction -> Api.InputPeer? in
                return transaction.getPeer(peerId).flatMap(apiInputPeer)
            }
            |> mapToSignal { inputPeer -> Signal<LoadResult, NoError> in
                guard let inputPeer = inputPeer else {
                    return .single(LoadResult(messagesByDay: [:], nextOffset: nil, minMessageId: nil, minTimestamp: nil))
                }
                guard let messageFilter = messageFilterForTagMask(messageTag) else {
                    return .single(LoadResult(messagesByDay: [:], nextOffset: nil, minMessageId: nil, minTimestamp: nil))
                }
                return self.account.network.request(Api.functions.messages.getSearchResultsCalendar(peer: inputPeer, filter: messageFilter, offsetId: nextRequestOffset, offsetDate: 0))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.SearchResultsCalendar?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<LoadResult, NoError> in
                    return account.postbox.transaction { transaction -> LoadResult in
                        guard let result = result else {
                            return LoadResult(messagesByDay: [:], nextOffset: nil, minMessageId: nil, minTimestamp: nil)
                        }

                        switch result {
                        case let .searchResultsCalendar(_, _, minDate, minMsgId, _, periods, messages, chats, users):
                            var parsedMessages: [StoreMessage] = []
                            var peers: [Peer] = []
                            var peerPresences: [PeerId: PeerPresence] = [:]

                            for chat in chats {
                                if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                    peers.append(groupOrChannel)
                                }
                            }
                            for user in users {
                                let telegramUser = TelegramUser(user: user)
                                peers.append(telegramUser)
                                if let presence = TelegramUserPresence(apiUser: user) {
                                    peerPresences[telegramUser.id] = presence
                                }
                            }

                            for message in messages {
                                if let parsedMessage = StoreMessage(apiMessage: message) {
                                    parsedMessages.append(parsedMessage)
                                }
                            }

                            updatePeers(transaction: transaction, peers: peers, update: { _, updated in updated })
                            updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                            let _ = transaction.addMessages(parsedMessages, location: .Random)

                            var minMessageId: Int32?
                            var messagesByDay: [Int32: Message] = [:]
                            for period in periods {
                                switch period {
                                case let .searchResultsCalendarPeriod(date, minMsgId, maxMsgId, _):
                                    if let message = transaction.getMessage(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: maxMsgId)) {
                                        messagesByDay[date] = message
                                    }
                                    if let minMessageIdValue = minMessageId {
                                        if minMsgId < minMessageIdValue {
                                            minMessageId = minMsgId
                                        }
                                    } else {
                                        minMessageId = minMsgId
                                    }
                                }
                            }

                            return LoadResult(messagesByDay: messagesByDay, nextOffset: minMessageId, minMessageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: minMsgId), minTimestamp: minDate)
                        }
                    }
                }
            }
            |> deliverOn(self.queue)).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }

                if let minTimestamp = result.minTimestamp {
                    strongSelf.state.minTimestamp = minTimestamp
                }
                strongSelf.state.nextRequestOffset = result.nextOffset

                for (timestamp, message) in result.messagesByDay {
                    strongSelf.state.messagesByDay[timestamp] = message
                }

                strongSelf.statePromise.set(.single(strongSelf.state))
                strongSelf.isLoadingMore = false
            }))
        }
    }

    public struct State {
        public var messagesByDay: [Int32: Message]
        public var minTimestamp: Int32?
        public var hasMore: Bool
    }

    private let queue: Queue
    private let impl: QueueLocalObject<Impl>

    init(account: Account, peerId: PeerId, messageTag: MessageTags) {
        let queue = Queue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, peerId: peerId, messageTag: messageTag)
        })
    }

    public var state: Signal<State, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()

            self.impl.with { impl in
                disposable.set(impl.statePromise.get().start(next: { state in
                    subscriber.putNext(State(
                        messagesByDay: state.messagesByDay,
                        minTimestamp: state.minTimestamp,
                        hasMore: state.nextRequestOffset != nil
                    ))
                }))
            }

            return disposable
        }
    }

    public var isLoadingMore: Signal<Bool, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()

            self.impl.with { impl in
                disposable.set(impl.isLoadingMoreSignal.start(next: subscriber.putNext))
            }

            return disposable
        }
    }

    public func loadMore() {
        self.impl.with { impl in
            impl.maybeLoadMore()
        }
    }
}
