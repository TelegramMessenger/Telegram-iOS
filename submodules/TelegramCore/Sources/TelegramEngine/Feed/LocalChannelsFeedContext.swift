import Foundation
import Postbox
import SwiftSignalKit

/// How many channels the local feed follows (the most recently active ones), and how many of each one's latest
/// posts it shows: the first window, each Load older step, and the most it ever asks for.
private let localFeedChannelLimit = 60
private let localFeedInitialPostsPerChannel = 20
private let localFeedPostsPerChannelStep = 20
private let localFeedMaxPostsPerChannel = 100
/// The local feed's own read mark, apart from the server feed's filters (which are never negative).
let localChannelsFeedFilterId: Int32 = -1

/// The Added feed built on the device, without the server's feed: the latest posts of the subscribed broadcast
/// channels (the chat list's, main and archived), merged by date, newest first. Each channel's history comes
/// through the account's view tracker, so holes are filled with `messages.getHistory` as opening the chat would,
/// and the feed follows new posts live. "Older" asks every channel for more of its posts; there is never anything
/// "newer" than the window, which is live.
final class LocalChannelsFeedContextImpl: AddedFeedContextSource {
    private let queue: Queue
    private let account: Account

    private var state: AddedFeedContext.State
    private let statePromise = Promise<AddedFeedContext.State>()

    private var postsPerChannel = localFeedInitialPostsPerChannel
    private var channelIds: [PeerId] = []
    private var hasReadState = false
    private var pendingReadPosition: EngineFeedPosition?
    private var readTimer: SwiftSignalKit.Timer?

    private let readStateDisposable = MetaDisposable()
    private let channelsDisposable = MetaDisposable()
    private let postsDisposable = MetaDisposable()
    private let readWriteDisposable = MetaDisposable()

    var stateSignal: Signal<AddedFeedContext.State, NoError> {
        return self.statePromise.get()
    }

    init(queue: Queue, account: Account) {
        self.queue = queue
        self.account = account
        self.state = AddedFeedContext.State(entries: [], hasNewer: false, hasOlder: true, readMaxPosition: nil, newestKnownPosition: nil, isLoadingInitial: true, isLoadingNewer: false, isLoadingOlder: false, hasError: false, windowGeneration: 0, windowAnchor: .readMark, windowReadMarkPosition: nil)
        self.pushState()

        // The read mark first: the first window opens at it.
        let readStateKey = PostboxViewKey.cachedItem(feedReadStateEntryId(filterId: localChannelsFeedFilterId))
        self.readStateDisposable.set((account.postbox.combinedView(keys: [readStateKey])
        |> deliverOn(queue)).start(next: { [weak self] views in
            guard let self else {
                return
            }
            if let readState = (views.views[readStateKey] as? CachedItemView)?.value?.get(FeedReadState.self), let advanced = advancedFeedReadPosition(current: self.state.readMaxPosition, candidate: readState.maxPosition) {
                self.state.readMaxPosition = advanced
            }
            if !self.hasReadState {
                self.hasReadState = true
                self.state.windowReadMarkPosition = self.state.readMaxPosition
                self.subscribeChannels()
            }
            self.pushState()
        }))
    }

    deinit {
        self.readStateDisposable.dispose()
        self.channelsDisposable.dispose()
        self.postsDisposable.dispose()
        self.readWriteDisposable.dispose()
        self.readTimer?.invalidate()
    }

    private func pushState() {
        self.statePromise.set(.single(self.state))
    }

    /// The subscribed broadcast channels, most recently active first, from the main and archived chat lists.
    private func subscribeChannels() {
        let account = self.account
        let summaryComponents = ChatListEntrySummaryComponents()
        let groupIds: [PeerGroupId] = [.root, Namespaces.PeerGroup.archive]
        let channels = combineLatest(queue: self.queue, groupIds.map { groupId -> Signal<[(ChatListIndex, PeerId)], NoError> in
            return account.postbox.tailChatListView(groupId: groupId, filterPredicate: nil, count: 500, summaryComponents: summaryComponents, extractCachedData: nil, accountPeerId: account.peerId)
            |> map { view, _ -> [(ChatListIndex, PeerId)] in
                var result: [(ChatListIndex, PeerId)] = []
                for entry in view.entries {
                    if case let .MessageEntry(data) = entry, let channel = data.renderedPeer.peer as? TelegramChannel, case .broadcast = channel.info {
                        result.append((data.index, channel.id))
                    }
                }
                return result
            }
        })
        |> map { lists -> [PeerId] in
            let sorted = lists.flatMap { $0 }.sorted(by: { $0.0 > $1.0 })
            return Array(sorted.prefix(localFeedChannelLimit).map(\.1))
        }
        |> distinctUntilChanged
        self.channelsDisposable.set((channels
        |> deliverOn(self.queue)).start(next: { [weak self] channelIds in
            guard let self else {
                return
            }
            self.channelIds = channelIds
            self.subscribePosts()
        }))
    }

    /// Every followed channel's latest posts, merged whenever any of them changes.
    private func subscribePosts() {
        let account = self.account
        let count = self.postsPerChannel
        let signals = self.channelIds.map { peerId -> Signal<[FeedPageMessage], NoError> in
            return account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: peerId, threadId: nil), index: .upperBound, anchorIndex: .upperBound, count: count, fixedCombinedReadStates: nil)
            |> map { view, _, _ -> [FeedPageMessage] in
                var result: [FeedPageMessage] = []
                for entry in view.entries {
                    let message = entry.message
                    guard message.id.namespace == Namespaces.Message.Cloud else {
                        continue
                    }
                    // Service messages (a pinned post, a changed photo) are no posts; nor is an empty message.
                    if message.media.contains(where: { $0 is TelegramMediaAction }) {
                        continue
                    }
                    if message.text.isEmpty && message.media.isEmpty {
                        continue
                    }
                    result.append(FeedPageMessage(id: message.id, timestamp: message.timestamp, groupingKey: message.groupingKey))
                }
                return result
            }
        }
        guard !signals.isEmpty else {
            self.postsDisposable.set(nil)
            self.applyPosts([])
            return
        }
        self.postsDisposable.set((combineLatest(queue: self.queue, signals)
        |> deliverOn(self.queue)).start(next: { [weak self] lists in
            self?.applyPosts(lists.flatMap { $0 })
        }))
    }

    private func applyPosts(_ messages: [FeedPageMessage]) {
        func position(_ message: FeedPageMessage) -> EngineFeedPosition {
            return EngineFeedPosition(date: message.timestamp, peerId: message.id.peerId, id: message.id.id)
        }
        let newestFirst = messages.sorted(by: { position($0) > position($1) })
        let entries = groupFeedMessages(newestFirst).sorted(by: { $0.position > $1.position })
        let isFirstWindow = self.state.isLoadingInitial
        self.state.entries = entries
        self.state.isLoadingInitial = false
        self.state.isLoadingOlder = false
        self.state.isLoadingNewer = false
        self.state.hasError = false
        self.state.hasNewer = false
        self.state.hasOlder = self.postsPerChannel < localFeedMaxPostsPerChannel && !entries.isEmpty
        self.state.newestKnownPosition = entries.first?.position
        if isFirstWindow {
            self.state.windowGeneration += 1
            self.state.windowAnchor = .readMark
            self.state.windowReadMarkPosition = self.state.readMaxPosition
        }
        self.pushState()
    }

    func loadInitial() {
        self.state.isLoadingInitial = true
        self.state.hasError = false
        self.pushState()
        self.postsPerChannel = localFeedInitialPostsPerChannel
        if self.hasReadState {
            self.subscribePosts()
        }
    }

    /// The window is live: a pull only shows its refresh and ends.
    func loadNewer(force: Bool) {
        guard !self.state.isLoadingInitial, !self.state.isLoadingNewer else {
            return
        }
        self.state.isLoadingNewer = true
        self.pushState()
        self.queue.after(0.35, { [weak self] in
            guard let self, self.state.isLoadingNewer else {
                return
            }
            self.state.isLoadingNewer = false
            self.pushState()
        })
    }

    func loadOlder() {
        guard !self.state.isLoadingInitial, !self.state.isLoadingOlder, self.state.hasOlder else {
            return
        }
        self.postsPerChannel = min(localFeedMaxPostsPerChannel, self.postsPerChannel + localFeedPostsPerChannelStep)
        self.state.isLoadingOlder = true
        self.pushState()
        self.subscribePosts()
    }

    func jumpToNewest(completion: @escaping (Bool) -> Void) {
        self.state.windowGeneration += 1
        self.state.windowAnchor = .top
        self.state.windowReadMarkPosition = nil
        self.state.hasNewer = false
        self.pushState()
        completion(true)
    }

    func revalidate() {
    }

    func markRead(upTo position: EngineFeedPosition) {
        guard let advanced = advancedFeedReadPosition(current: self.state.readMaxPosition, candidate: position) else {
            return
        }
        self.state.readMaxPosition = advanced
        self.pushState()
        self.pendingReadPosition = advanced
        if self.readTimer == nil {
            let timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: false, completion: { [weak self] in
                guard let self else {
                    return
                }
                self.readTimer = nil
                self.commitRead()
            }, queue: self.queue)
            self.readTimer = timer
            timer.start()
        }
    }

    func markAllRead() {
        if let position = self.state.newestKnownPosition ?? self.state.entries.first?.position {
            self.markRead(upTo: position)
        }
    }

    private func commitRead() {
        guard let position = self.pendingReadPosition else {
            return
        }
        self.pendingReadPosition = nil
        self.readWriteDisposable.set(self.account.postbox.transaction({ transaction -> Void in
            applyFeedReadState(transaction: transaction, filterId: localChannelsFeedFilterId, maxPosition: position)
        }).start())
    }
}
