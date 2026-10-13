import SwiftSignalKit
import Postbox
import TelegramApi

public final class SparseMessageList {
    /// One peer's shared media: its newest local messages (the top section) joined with the
    /// server skeleton. The group a channel was migrated from gets a segment of the same kind:
    /// `SparseItemGrid` requests holes only once some cell holds a loaded message, so a list of
    /// placeholders alone (a group's skeleton behind a channel without media of its own) would
    /// never load.
    private final class PeerSegment {
        let peerId: PeerId
        private let queue: Queue
        private let account: Account
        private let threadId: Int64?
        private let messageTag: MessageTags
        private let initialMessageIndex: MessageIndex?

        private var stateUpdated: ((SparseMessageList.State) -> Void)?

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

        private var topSectionItemRequestCount: Int = 100
        private var topSection: TopSection?
        private var topItemsDisposable = MetaDisposable()

        private var deletedMessagesDisposable: Disposable?

        private var sparseItems: SparseMessageSkeleton?
        private var sparseItemsDisposable: Disposable?

        private struct LoadingHole: Equatable {
            var anchor: MessageId
            var direction: LoadHoleDirection
        }
        private let loadHoleDisposable = MetaDisposable()
        private var loadingHole: LoadingHole?
        private var loadingHoleCompletion: (() -> Void)?
        private var isLoadingInitial: Bool = false

        private var loadingPlaceholders: [MessageId: Disposable] = [:]
        private var loadedPlaceholders: [MessageId: Message] = [:]

        init(queue: Queue, account: Account, peerId: PeerId, threadId: Int64?, messageTag: MessageTags, initialMessageIndex: MessageIndex?) {
            self.queue = queue
            self.account = account
            self.peerId = peerId
            self.threadId = threadId
            self.messageTag = messageTag
            self.initialMessageIndex = initialMessageIndex
        }

        deinit {
            self.topItemsDisposable.dispose()
            self.sparseItemsDisposable?.dispose()
            self.loadHoleDisposable.dispose()
            self.deletedMessagesDisposable?.dispose()
        }

        /// Starts loading. Kept out of `init`: `deliverOn` runs inline when already on the queue,
        /// so a state can be reported before the owner has stored this segment.
        func start(stateUpdated: @escaping (SparseMessageList.State) -> Void) {
            self.stateUpdated = stateUpdated

            let account = self.account
            let peerId = self.peerId
            let messageTag = self.messageTag
            let initialMessageIndex = self.initialMessageIndex

            self.resetTopSection()

            if self.threadId == nil {
                if initialMessageIndex != nil {
                    self.isLoadingInitial = true
                    self.updateState()
                }

                self.sparseItemsDisposable = (account.postbox.transaction { transaction -> Api.InputPeer? in
                    return transaction.getPeer(peerId).flatMap(apiInputPeer)
                }
                |> mapToSignal { inputPeer -> Signal<SparseMessageSkeleton, NoError> in
                    guard let inputPeer = inputPeer else {
                        return .single(SparseMessageSkeleton(items: []))
                    }
                    guard let messageFilter = messageFilterForTagMask(messageTag) else {
                        return .single(SparseMessageSkeleton(items: []))
                    }

                    return account.network.request(Api.functions.messages.getSearchResultsPositions(flags: 0, peer: inputPeer, savedPeerId: nil, filter: messageFilter, offsetId: 0, limit: 1000))
                    |> map { result -> SparseMessageSkeleton in
                        switch result {
                        case let .searchResultsPositions(searchResultsPositionsData):
                            let positions = searchResultsPositionsData.positions.map { position -> SparseMessagePosition in
                                switch position {
                                case let .searchResultPosition(searchResultPositionData):
                                    return SparseMessagePosition(id: searchResultPositionData.msgId, date: searchResultPositionData.date, offset: Int(searchResultPositionData.offset))
                                }
                            }
                            return sparseMessageSkeleton(peerId: peerId, positions: positions, totalCount: Int(searchResultsPositionsData.count), includeLeadingRange: initialMessageIndex != nil)
                        }
                    }
                    |> `catch` { _ -> Signal<SparseMessageSkeleton, NoError> in
                        return .single(SparseMessageSkeleton(items: []))
                    }
                }
                |> deliverOn(self.queue)).start(next: { [weak self] sparseItems in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.isLoadingInitial = false
                    strongSelf.sparseItems = sparseItems
                    if let initialMessageIndex {
                        var loadHoleAnchor: MessageId?
                        loop: for item in sparseItems.items {
                            switch item {
                            case let .anchor(id, timestamp, _):
                                let anchorIndex = MessageIndex(id: id, timestamp: timestamp)
                                if anchorIndex <= initialMessageIndex {
                                    loadHoleAnchor = id
                                    break loop
                                }
                            case .range:
                                break
                            }
                        }
                        if let loadHoleAnchor {
                            strongSelf.loadHole(anchor: loadHoleAnchor, direction: .around, completion: {
                            })
                        } else {
                            if strongSelf.topSection != nil {
                                strongSelf.updateState()
                            }
                        }
                    } else {
                        if strongSelf.topSection != nil {
                            strongSelf.updateState()
                        }
                    }
                })
            }

            self.deletedMessagesDisposable = (account.postbox.combinedView(keys: [.deletedMessages(peerId: peerId)])
            |> deliverOn(self.queue)).start(next: { [weak self] views in
                guard let strongSelf = self else {
                    return
                }
                guard let view = views.views[.deletedMessages(peerId: peerId)] as? DeletedMessagesView else {
                    return
                }
                strongSelf.processDeletedMessages(ids: view.currentDeletedMessages)
            })
        }

        /// The server skeleton, once it has arrived.
        var skeleton: SparseMessageSkeleton? {
            return self.sparseItems
        }

        /// Whether this segment's count is its full length (`sparseMessageListSegmentCountIsFinal`).
        var countIsFinal: Bool {
            return sparseMessageListSegmentCountIsFinal(peerId: self.peerId, topMessages: self.topSection?.messages ?? [], skeleton: self.sparseItems)
        }

        /// Stops the segment for good. A hole load in flight is reported complete, so the grid's
        /// request for it finishes instead of waiting forever.
        func cancel() {
            self.stateUpdated = nil
            self.topItemsDisposable.dispose()
            self.sparseItemsDisposable?.dispose()
            self.deletedMessagesDisposable?.dispose()
            self.loadHoleDisposable.dispose()
            self.loadingHole = nil
            if let completion = self.loadingHoleCompletion {
                self.loadingHoleCompletion = nil
                completion()
            }
        }

        private func resetTopSection() {
            let count: Int
            count = 200
            
            let location: ChatLocationInput = .peer(peerId: self.peerId, threadId: self.threadId)
            
            self.topItemsDisposable.set((self.account.postbox.aroundMessageHistoryViewForLocation(location, anchor: .upperBound, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), count: count, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: Set(), tag: .tag(self.messageTag), appendMessagesFromTheSameGroup: false, namespaces: .not(Namespaces.Message.allNonRegular), orderStatistics: [])
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

        private func processDeletedMessages(ids: [MessageId]) {
            if let sparseItems = self.sparseItems {
                let idsSet = Set(ids)

                var removeIndices: [Int] = []
                for i in 0 ..< sparseItems.items.count {
                    switch sparseItems.items[i] {
                    case let .anchor(id, _, _):
                        if idsSet.contains(id) {
                            removeIndices.append(i)
                        }
                    default:
                        break
                    }
                }

                if !removeIndices.isEmpty {
                    for index in removeIndices.reversed() {
                        self.sparseItems?.items.remove(at: index)
                    }

                    self.updateState()
                }
            }
        }

        func loadMoreFromTopSection() {
            self.topSectionItemRequestCount += 100
            self.resetTopSection()
        }

        func loadHole(anchor: MessageId, direction: LoadHoleDirection, completion: @escaping () -> Void) {
            guard let sparseItems = self.sparseItems else {
                completion()
                return
            }

            var loadRange: ClosedRange<Int32>?
            var loadCount: Int?

            centralItemSearch: for i in 0 ..< sparseItems.items.count {
                switch sparseItems.items[i] {
                case let .anchor(id, _, _):
                    if id == anchor {
                        func lowerStep(index: Int, holeRange: inout ClosedRange<Int32>, holeCount: inout Int) -> Bool {
                            switch sparseItems.items[index] {
                            case let .anchor(id, _, message):
                                holeRange = id.id ... holeRange.upperBound
                                holeCount += 1

                                if message != nil {
                                    return false
                                } else {
                                    if holeCount > 90 {
                                        return false
                                    }
                                }
                            case let .range(count):
                                if holeCount + count > 90 {
                                    return false
                                }
                                holeCount += count
                            }
                            return true
                        }

                        func upperStep(index: Int, holeRange: inout ClosedRange<Int32>, holeCount: inout Int) -> Bool {
                            switch sparseItems.items[index] {
                            case let .anchor(id, _, message):
                                holeRange = holeRange.lowerBound ... id.id
                                holeCount += 1

                                if message != nil {
                                    return false
                                } else {
                                    if holeCount > 90 {
                                        return false
                                    }
                                }
                            case let .range(count):
                                if holeCount + count > 90 {
                                    return false
                                }
                                holeCount += count
                            }
                            return true
                        }

                        var holeCount = 1
                        var holeRange: ClosedRange<Int32> = id.id ... id.id
                        var lowerIndex = i - 1
                        var upperIndex = i + 1
                        while true {
                            if holeCount > 90 {
                                break
                            }
                            if lowerIndex == -1 && upperIndex == sparseItems.items.count {
                                break
                            }
                            if lowerIndex >= 0 {
                                if !upperStep(index: lowerIndex, holeRange: &holeRange, holeCount: &holeCount) {
                                    lowerIndex = -1
                                } else {
                                    lowerIndex -= 1
                                    if lowerIndex == -1 {
                                        holeRange = holeRange.lowerBound ... (Int32.max - 1)
                                    }
                                }
                            }
                            if upperIndex < sparseItems.items.count {
                                if !lowerStep(index: upperIndex, holeRange: &holeRange, holeCount: &holeCount) {
                                    upperIndex = sparseItems.items.count
                                } else {
                                    upperIndex += 1
                                    if upperIndex == sparseItems.items.count {
                                        holeRange = 1 ... holeRange.upperBound
                                    }
                                }
                            }
                        }

                        loadRange = holeRange
                        loadCount = holeCount

                        break centralItemSearch
                    }
                default:
                    break
                }
            }

            guard let range = loadRange, let expectedCount = loadCount else {
                completion()
                return
            }

            let loadingHole = LoadingHole(anchor: anchor, direction: direction)
            if self.loadingHole != nil {
                completion()
                return
            }
            self.loadingHole = loadingHole
            self.loadingHoleCompletion = completion

            let mappedDirection: MessageHistoryViewRelativeHoleDirection = .range(start: MessageId(peerId: anchor.peerId, namespace: anchor.namespace, id: range.upperBound), end: MessageId(peerId: anchor.peerId, namespace: anchor.namespace, id: range.lowerBound - 1))

            let account = self.account
            self.loadHoleDisposable.set((fetchMessageHistoryHole(
                accountPeerId: self.account.peerId,
                source: .network(self.account.network),
                postbox: self.account.postbox,
                peerInput: .direct(peerId: self.peerId, threadId: nil),
                namespace: Namespaces.Message.Cloud,
                direction: mappedDirection,
                space: .tag(self.messageTag),
                count: 100
            )
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

                if messages.count != expectedCount {
                    Logger.shared.log("SparseMessageList", "unexpected message count")
                }

                var lowerIndex: Int?
                var upperIndex: Int?
                for i in 0 ..< strongSelf.sparseItems!.items.count {
                    switch strongSelf.sparseItems!.items[i] {
                    case let .anchor(id, _, _):
                        if id.id == range.lowerBound {
                            lowerIndex = i
                        }
                        if id.id == range.upperBound {
                            upperIndex = i
                        }
                    default:
                        break
                    }
                }
                if range.lowerBound <= 1 {
                    lowerIndex = strongSelf.sparseItems!.items.count - 1
                }
                if range.upperBound >= Int32.max - 1 {
                    upperIndex = 0
                }

                if let lowerIndex = lowerIndex, let upperIndex = upperIndex {
                    strongSelf.sparseItems!.items.removeSubrange(upperIndex ... lowerIndex)
                    var insertIndex = upperIndex
                    for message in messages.sorted(by: { $0.id > $1.id }) {
                        strongSelf.sparseItems!.items.insert(.anchor(id: message.id, timestamp: message.timestamp, message: message), at: insertIndex)
                        insertIndex += 1
                    }
                }

                let anchors = strongSelf.sparseItems!.items.compactMap { item -> MessageId? in
                    if case let .anchor(id, _, _) = item {
                        return id
                    } else {
                        return nil
                    }
                }
                assert(anchors.sorted(by: >) == anchors)

                strongSelf.updateState()

                if strongSelf.loadingHole == loadingHole {
                    strongSelf.loadingHole = nil
                    strongSelf.loadingHoleCompletion = nil
                }

                completion()
            }))

            /*let mappedDirection: MessageHistoryViewRelativeHoleDirection
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
            }))*/
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
            if self.loadingHole == nil && !self.isLoadingInitial {
                self.updateState()
            }
        }

        private func updateState() {
            guard let stateUpdated = self.stateUpdated else {
                return
            }
            if self.isLoadingInitial {
                stateUpdated(SparseMessageList.State(
                    items: [],
                    totalCount: 0,
                    isLoading: true
                ))
                return
            }

            let layout = sparseMessageListSegmentItems(peerId: self.peerId, topMessages: self.topSection?.messages ?? [], skeleton: self.sparseItems)
            stateUpdated(SparseMessageList.State(
                items: layout.items,
                totalCount: layout.totalCount,
                isLoading: self.topSection == nil
            ))
        }
    }

    private let queue: Queue
    private let impl: QueueLocalObject<Impl>

    /// The shared media of a peer and, for a channel migrated from a basic group, of that group
    /// after it: one `PeerSegment` per peer, published as one list (`mergedSparseMessageListState`).
    private final class Impl {
        private let queue: Queue
        private let account: Account
        private let messageTag: MessageTags

        private let mainSegment: PeerSegment
        private var mainState: SparseMessageList.State?
        private var legacySegment: PeerSegment?
        private var legacyState: SparseMessageList.State?
        /// The initial focus while it is another peer's message, which only the group's segment
        /// can hold. Cleared when the cached data names no such group, and once delivered.
        private var legacyFocus: MessageIndex?
        private var legacyPeerDisposable: Disposable?

        let statePromise = Promise<SparseMessageList.State>()

        init(queue: Queue, account: Account, peerId: PeerId, threadId: Int64?, messageTag: MessageTags, initialMessageIndex: MessageIndex?) {
            self.queue = queue
            self.account = account
            self.messageTag = messageTag

            let focus = sparseMessageListFocus(initialMessageIndex: initialMessageIndex, peerId: peerId, threadId: threadId)
            self.legacyFocus = focus.legacy

            self.mainSegment = PeerSegment(queue: queue, account: account, peerId: peerId, threadId: threadId, messageTag: messageTag, initialMessageIndex: focus.main)
            self.mainSegment.start(stateUpdated: { [weak self] state in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.mainState = state
                strongSelf.updateState()
            })

            if threadId == nil {
                // The group is read the way Postbox's history views read it.
                let key: PostboxViewKey = .cachedPeerData(peerId: peerId)
                self.legacyPeerDisposable = (account.postbox.combinedView(keys: [key])
                |> map { views -> PeerId? in
                    return channelMigratedFromGroupId(channelId: peerId, cachedData: (views.views[key] as? CachedPeerDataView)?.cachedPeerData)
                }
                |> distinctUntilChanged
                |> deliverOn(queue)).start(next: { [weak self] legacyPeerId in
                    self?.updateLegacyPeer(legacyPeerId)
                })
            }
        }

        deinit {
            self.legacyPeerDisposable?.dispose()
        }

        private func updateLegacyPeer(_ legacyPeerId: PeerId?) {
            let change = sparseMessageListLegacyPeerChange(currentPeerId: self.legacySegment?.peerId, updatedPeerId: legacyPeerId, focus: self.legacyFocus)
            self.legacyFocus = change.focus
            if change.replacesSegment {
                self.legacySegment?.cancel()
                self.legacySegment = nil
                self.legacyState = nil

                if let legacyPeerId {
                    let segment = PeerSegment(queue: self.queue, account: self.account, peerId: legacyPeerId, threadId: nil, messageTag: self.messageTag, initialMessageIndex: self.legacyFocus)
                    self.legacySegment = segment
                    segment.start(stateUpdated: { [weak self] state in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.legacyState = state
                        strongSelf.updateState()
                    })
                }
            }
            self.updateState()
        }

        private func updateState() {
            guard let state = mergedSparseMessageListState(main: self.mainState, mainCountIsFinal: self.mainSegment.countIsFinal, legacy: self.legacyState, holdForLegacyFocus: self.legacyFocus != nil) else {
                return
            }
            self.legacyFocus = sparseMessageListHeldFocus(afterPublishing: state, focus: self.legacyFocus)
            self.statePromise.set(.single(state))
        }

        func loadMoreFromTopSection() {
            self.mainSegment.loadMoreFromTopSection()
        }

        func loadHole(anchor requestedAnchor: MessageId, direction: LoadHoleDirection, completion: @escaping () -> Void) {
            guard let target = sparseMessageListHoleTarget(requested: requestedAnchor, mainPeerId: self.mainSegment.peerId, mainSkeleton: self.mainSegment.skeleton, legacyPeerId: self.legacySegment?.peerId, legacySkeleton: self.legacySegment?.skeleton) else {
                completion()
                return
            }
            switch target.segment {
            case .main:
                self.mainSegment.loadHole(anchor: target.anchor, direction: direction, completion: completion)
            case .legacy:
                if let legacySegment = self.legacySegment {
                    legacySegment.loadHole(anchor: target.anchor, direction: direction, completion: completion)
                } else {
                    completion()
                }
            }
        }
    }

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

    init(account: Account, peerId: PeerId, threadId: Int64?, messageTag: MessageTags, initialMessageIndex: MessageIndex?) {
        self.queue = Queue()
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, peerId: peerId, threadId: threadId, messageTag: messageTag, initialMessageIndex: initialMessageIndex)
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

/// One page of `peer`'s `messages.getSearchResultsCalendar`, with its messages stored. A failed
/// request ends that peer's paging, as it ended the whole calendar before.
private func loadSparseCalendarPage(account: Account, peer: Peer, messageTag: MessageTags, offset: Int32) -> Signal<SparseCalendarPagingState.Page, NoError> {
    let accountPeerId = account.peerId
    let peerId = peer.id
    let emptyPage = SparseCalendarPagingState.Page(peerId: peerId, messagesByDay: [:], nextOffset: nil, bounds: nil)
    guard let inputPeer = apiInputPeer(peer), let messageFilter = messageFilterForTagMask(messageTag) else {
        return .single(emptyPage)
    }

    return account.network.request(Api.functions.messages.getSearchResultsCalendar(flags: 0, peer: inputPeer, savedPeerId: nil, filter: messageFilter, offsetId: offset, offsetDate: 0))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.messages.SearchResultsCalendar?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<SparseCalendarPagingState.Page, NoError> in
        guard let result = result else {
            return .single(emptyPage)
        }
        return account.postbox.transaction { transaction -> SparseCalendarPagingState.Page in
            switch result {
            case let .searchResultsCalendar(searchResultsCalendarData):
                var parsedMessages: [StoreMessage] = []

                let parsedPeers = AccumulatedPeers(transaction: transaction, chats: searchResultsCalendarData.chats, users: searchResultsCalendarData.users)

                for message in searchResultsCalendarData.messages {
                    if let parsedMessage = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peer.isForumOrMonoForum) {
                        parsedMessages.append(parsedMessage)
                    }
                }

                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                let _ = transaction.addMessages(parsedMessages, location: .Random)

                var minMessageId: Int32?
                var messagesByDay: [Int32: SparseMessageCalendar.Entry] = [:]
                for period in searchResultsCalendarData.periods {
                    switch period {
                    case let .searchResultsCalendarPeriod(searchResultsCalendarPeriodData):
                        let (date, minMsgId, count) = (searchResultsCalendarPeriodData.date, searchResultsCalendarPeriodData.minMsgId, searchResultsCalendarPeriodData.count)
                        if let message = transaction.getMessage(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: minMsgId)) {
                            messagesByDay[date] = SparseMessageCalendar.Entry(message: message, count: Int(count))
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

                return SparseCalendarPagingState.Page(
                    peerId: peerId,
                    messagesByDay: messagesByDay,
                    nextOffset: minMessageId,
                    bounds: SparseCalendarPeerBounds(minDate: searchResultsCalendarData.minDate, count: searchResultsCalendarData.count)
                )
            }
        }
    }
}

public final class SparseMessageCalendar {
    private final class Impl {
        private let queue: Queue
        private let account: Account
        private let peerId: PeerId
        private let threadId: Int64?
        private let messageTag: MessageTags
        private let displayMedia: Bool

        private var state: SparseCalendarPagingState
        let statePromise = Promise<SparseCalendarPagingState>()

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

        init(queue: Queue, account: Account, peerId: PeerId, threadId: Int64?, messageTag: MessageTags, displayMedia: Bool) {
            self.queue = queue
            self.account = account
            self.peerId = peerId
            self.threadId = threadId
            self.messageTag = messageTag
            self.displayMedia = displayMedia

            self.state = SparseCalendarPagingState(mainPeerId: peerId)
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

        func removeMessagesInRange(minTimestamp: Int32, maxTimestamp: Int32, type: InteractiveHistoryClearingType, completion: @escaping () -> Void) -> Disposable {
            self.state.removeMessages(minTimestamp: minTimestamp, maxTimestamp: maxTimestamp)

            self.statePromise.set(.single(self.state))

            return _internal_clearHistoryInRangeInteractively(postbox: self.account.postbox, peerId: self.peerId, threadId: self.threadId, minTimestamp: minTimestamp, maxTimestamp: maxTimestamp, type: type).start(completed: {
                completion()
            })
        }

        private func loadMore() {
            if !self.state.hasMore {
                return
            }
            if self.threadId != nil {
                return
            }
            if !self.displayMedia {
                return
            }

            self.isLoadingMore = true

            struct LoadResult {
                /// The peers that could be requested, in list order.
                var peerIds: [PeerId]
                var pages: [SparseCalendarPagingState.Page]
            }

            let account = self.account
            let peerId = self.peerId
            let messageTag = self.messageTag
            let state = self.state
            self.disposable.set((account.postbox.transaction { transaction -> [Peer] in
                // The channel, then the group it was migrated from, read as the history views
                // read it.
                var peers: [Peer] = []
                if let peer = transaction.getPeer(peerId) {
                    peers.append(peer)
                }
                if let legacyPeerId = channelMigratedFromGroupId(channelId: peerId, cachedData: transaction.getPeerCachedData(peerId: peerId)), let legacyPeer = transaction.getPeer(legacyPeerId) {
                    peers.append(legacyPeer)
                }
                return peers
            }
            |> mapToSignal { peers -> Signal<LoadResult, NoError> in
                let pages = state.requests(peerIds: peers.map { $0.id }).compactMap { request -> Signal<SparseCalendarPagingState.Page, NoError>? in
                    guard let peer = peers.first(where: { $0.id == request.peerId }) else {
                        return nil
                    }
                    return loadSparseCalendarPage(account: account, peer: peer, messageTag: messageTag, offset: request.offset)
                }
                return combineLatest(pages)
                |> map { pages -> LoadResult in
                    return LoadResult(peerIds: peers.map { $0.id }, pages: pages)
                }
            }
            |> deliverOn(self.queue)).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.state.apply(peerIds: result.peerIds, pages: result.pages)
                strongSelf.statePromise.set(.single(strongSelf.state))
                strongSelf.isLoadingMore = false
            }))
        }
    }

    public struct Entry {
        public var message: Message
        public var count: Int
    }

    public struct State {
        public var messagesByDay: [Int32: Entry]
        public var minTimestamp: Int32?
        public var hasMore: Bool
    }

    private let queue: Queue
    private let impl: QueueLocalObject<Impl>

    public var minTimestamp: Int32?
    private var disposable: Disposable?

    init(account: Account, peerId: PeerId, threadId: Int64?, messageTag: MessageTags, displayMedia: Bool) {
        let queue = Queue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, peerId: peerId, threadId: threadId, messageTag: messageTag, displayMedia: displayMedia)
        })

        self.disposable = self.state.start(next: { [weak self] state in
            self?.minTimestamp = state.minTimestamp
        })
    }

    deinit {
        self.disposable?.dispose()
    }

    public var state: Signal<State, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()

            self.impl.with { impl in
                disposable.set(impl.statePromise.get().start(next: { state in
                    subscriber.putNext(State(
                        messagesByDay: state.messagesByDay,
                        minTimestamp: state.minTimestamp,
                        hasMore: state.hasMore
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

    public func removeMessagesInRange(minTimestamp: Int32, maxTimestamp: Int32, type: InteractiveHistoryClearingType, completion: @escaping () -> Void) -> Disposable {
        let disposable = MetaDisposable()

        self.impl.with { impl in
            disposable.set(impl.removeMessagesInRange(minTimestamp: minTimestamp, maxTimestamp: maxTimestamp, type: type, completion: completion))
        }

        return disposable
    }
}
