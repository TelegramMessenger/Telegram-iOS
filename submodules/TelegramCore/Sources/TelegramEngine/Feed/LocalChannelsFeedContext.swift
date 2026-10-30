import Foundation
import Postbox
import SwiftSignalKit

/// How many channels the local feed follows (the most recently active ones), and how many of each one's latest
/// posts it shows: the first window, each Load older step, and the most it ever asks for.
private let localFeedChannelLimit = 40
private let localFeedInitialPostsPerChannel = 10
private let localFeedPostsPerChannelStep = 10
private let localFeedMaxPostsPerChannel = 60
/// The window the screen gets (the server feed's pages are this size too): the newest posts of the merged list,
/// grown by a page on Load older. The rows beyond it stay merged but unlisted, so the list never holds every
/// channel's every loaded post at once.
private let localFeedWindowPage = 100
/// Channel histories arrive one hole at a time: updates within this interval are merged into one window.
private let localFeedCoalesceInterval: Double = 0.4
/// The local feed's own read mark, apart from the server feed's filters (which are never negative).
let localChannelsFeedFilterId: Int32 = -1

/// One followed channel's latest posts.
private final class LocalFeedChannel {
    let disposable = MetaDisposable()
    /// Nil until its history view first arrives.
    var posts: [FeedPageMessage]?
    /// The view reaches the channel's first post: nothing older is left to load.
    var isExhausted = false
}

/// The Added feed built on the device, without the server's feed: the latest posts of the subscribed broadcast
/// channels (the chat list's, main and archived), merged by date, newest first. Each channel's history is a plain
/// Postbox view: its holes are filled with `messages.getHistory`, but the channel is never polled (these are the
/// chat list's channels, whose new posts arrive as the chat list's do), so 40 channels cost the server nothing
/// while the feed is open. "Older" asks every channel for more of its posts; there is never anything "newer" than
/// the window, which is live.
final class LocalChannelsFeedContextImpl: AddedFeedContextSource {
    private let queue: Queue
    /// The chat lists' flattening and the posts' merge run here, off `queue` (the main queue).
    private let workQueue = Queue()
    private let account: Account

    private var state: AddedFeedContext.State
    private let statePromise = Promise<AddedFeedContext.State>()

    private var postsPerChannel = localFeedInitialPostsPerChannel
    private var windowSize = localFeedWindowPage
    private var channelIds: [PeerId] = []
    private var channels: [PeerId: LocalFeedChannel] = [:]
    private var merged: [EngineFeedEntry] = []
    private var mergeGeneration = 0
    private var hasPendingPosts = false
    private var coalesceTimer: SwiftSignalKit.Timer?
    private var hasReadState = false
    private var pendingReadPosition: EngineFeedPosition?
    private var readTimer: SwiftSignalKit.Timer?

    private let readStateDisposable = MetaDisposable()
    private let channelsDisposable = MetaDisposable()
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
        for channel in self.channels.values {
            channel.disposable.dispose()
        }
        self.readWriteDisposable.dispose()
        self.readTimer?.invalidate()
        self.coalesceTimer?.invalidate()
    }

    private func pushState() {
        self.statePromise.set(.single(self.state))
    }

    /// The subscribed broadcast channels, most recently active first, from the main and archived chat lists.
    private func subscribeChannels() {
        let account = self.account
        let summaryComponents = ChatListEntrySummaryComponents()
        let groupIds: [PeerGroupId] = [.root, Namespaces.PeerGroup.archive]
        let channels = combineLatest(queue: self.workQueue, groupIds.map { groupId -> Signal<[(ChatListIndex, PeerId)], NoError> in
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
            self.updateChannelSubscriptions(resubscribe: false)
        }))
    }

    /// Follows each channel in `channelIds`: a channel that leaves the list is dropped and one that joins it is
    /// added, the others keep their views (a reorder changes nothing). `resubscribe` re-opens every view, for a
    /// new `postsPerChannel`.
    private func updateChannelSubscriptions(resubscribe: Bool) {
        let ids = Set(self.channelIds)
        for (peerId, channel) in self.channels where !ids.contains(peerId) || resubscribe {
            channel.disposable.dispose()
            self.channels.removeValue(forKey: peerId)
        }
        for peerId in self.channelIds where self.channels[peerId] == nil {
            let channel = LocalFeedChannel()
            self.channels[peerId] = channel
            channel.disposable.set((self.channelPosts(peerId: peerId, count: self.postsPerChannel)
            |> deliverOn(self.queue)).start(next: { [weak self, weak channel] posts, isExhausted in
                guard let self, let channel else {
                    return
                }
                channel.posts = posts
                channel.isExhausted = isExhausted
                self.postsUpdated()
            }))
        }
        self.postsUpdated()
    }

    /// A channel's latest `count` posts, newest last, and whether they reach its first post.
    private func channelPosts(peerId: PeerId, count: Int) -> Signal<([FeedPageMessage], Bool), NoError> {
        return self.account.postbox.aroundMessageHistoryViewForLocation(.peer(peerId: peerId, threadId: nil), anchor: .upperBound, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), count: count, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [Namespaces.Message.Cloud], tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .not(Namespaces.Message.allNonRegular), orderStatistics: [])
        |> map { view, _, _ -> ([FeedPageMessage], Bool) in
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
            return (result, view.earlierId == nil && !view.holeEarlier)
        }
    }

    /// The first window goes out once every channel has answered; while channel histories keep arriving, later
    /// ones are merged a few times a second at most.
    private func postsUpdated() {
        if self.channels.values.contains(where: { $0.posts == nil }) {
            return
        }
        if self.state.isLoadingInitial || self.coalesceTimer == nil {
            self.mergePosts()
            self.coalesceTimer?.invalidate()
            let timer = SwiftSignalKit.Timer(timeout: localFeedCoalesceInterval, repeat: false, completion: { [weak self] in
                guard let self else {
                    return
                }
                self.coalesceTimer = nil
                if self.hasPendingPosts {
                    self.hasPendingPosts = false
                    self.postsUpdated()
                }
            }, queue: self.queue)
            self.coalesceTimer = timer
            timer.start()
        } else {
            self.hasPendingPosts = true
        }
    }

    /// Merges the channels' posts on `workQueue`, down to the frontier: the newest of the oldest posts loaded from
    /// each channel that has older ones left. Below it a busier channel's posts are not loaded yet, so listing
    /// a quieter one's there would put them out of order (and Load older would insert rows above them).
    private func mergePosts() {
        self.mergeGeneration += 1
        let generation = self.mergeGeneration
        let lists = self.channels.values.map { ($0.posts ?? [], $0.isExhausted) }
        self.workQueue.async { [weak self] in
            func position(_ message: FeedPageMessage) -> EngineFeedPosition {
                return EngineFeedPosition(date: message.timestamp, peerId: message.id.peerId, id: message.id.id)
            }
            var frontier: EngineFeedPosition?
            for (posts, isExhausted) in lists where !isExhausted {
                if let oldest = posts.map(position).min(), frontier.flatMap({ oldest <= $0 }) != true {
                    frontier = oldest
                }
            }
            var messages = lists.flatMap { $0.0 }
            if let frontier {
                messages = messages.filter { position($0) >= frontier }
            }
            let newestFirst = messages.sorted(by: { position($0) > position($1) })
            let merged = groupFeedMessages(newestFirst).sorted(by: { $0.position > $1.position })
            self?.queue.async {
                guard let self, self.mergeGeneration == generation else {
                    return
                }
                self.merged = merged
                self.applyWindow()
            }
        }
    }

    private func applyWindow() {
        let entries = Array(self.merged.prefix(self.windowSize))
        let isFirstWindow = self.state.isLoadingInitial
        self.state.entries = entries
        self.state.isLoadingInitial = false
        self.state.isLoadingOlder = false
        self.state.isLoadingNewer = false
        self.state.hasError = false
        self.state.hasNewer = false
        self.state.hasOlder = !entries.isEmpty && (self.merged.count > entries.count || self.postsPerChannel < localFeedMaxPostsPerChannel)
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
        self.windowSize = localFeedWindowPage
        if self.hasReadState {
            self.updateChannelSubscriptions(resubscribe: true)
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
        self.windowSize += localFeedWindowPage
        if self.merged.count >= self.windowSize || self.postsPerChannel >= localFeedMaxPostsPerChannel {
            // Enough is merged already, or the channels are exhausted: just widen the window.
            self.state.isLoadingOlder = true
            self.pushState()
            self.applyWindow()
        } else {
            self.postsPerChannel = min(localFeedMaxPostsPerChannel, self.postsPerChannel + localFeedPostsPerChannelStep)
            self.state.isLoadingOlder = true
            self.pushState()
            self.updateChannelSubscriptions(resubscribe: true)
        }
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
