import Foundation
import Postbox

/// One entry of `messages.getSearchResultsPositions`: the message at `offset` (0 is the newest)
/// among a peer's messages matching the filter.
struct SparseMessagePosition: Equatable {
    var id: Int32
    var date: Int32
    var offset: Int
}

/// One peer's shared media as the server describes it, newest first: messages whose position is
/// known (`anchor`, carrying the message once it is loaded) and runs known only by their length
/// (`range`). All ids belong to one peer; the hole loader's id ranges rely on that, because
/// `MessageId` orders by namespace and id before peer.
struct SparseMessageSkeleton: Equatable {
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

    var firstAnchorId: MessageId? {
        for item in self.items {
            if case let .anchor(id, _, _) = item {
                return id
            }
        }
        return nil
    }

    var lastAnchorId: MessageId? {
        for item in self.items.reversed() {
            if case let .anchor(id, _, _) = item {
                return id
            }
        }
        return nil
    }

    /// Messages before the first known position are still unloaded.
    var startsWithRange: Bool {
        if case .range? = self.items.first {
            return true
        } else {
            return false
        }
    }

    /// Messages after the last known position are still unloaded.
    var endsWithRange: Bool {
        if case .range? = self.items.last {
            return true
        } else {
            return false
        }
    }

    /// The first known position's message has been loaded.
    var firstAnchorIsLoaded: Bool {
        for item in self.items {
            if case let .anchor(_, _, message) = item {
                return message != nil
            }
        }
        return false
    }

    /// The last known position's message has been loaded.
    var lastAnchorIsLoaded: Bool {
        for item in self.items.reversed() {
            if case let .anchor(_, _, message) = item {
                return message != nil
            }
        }
        return false
    }
}

/// Builds `peerId`'s skeleton from its positions. `includeLeadingRange` represents the messages
/// before the first position; a list whose head the local top section covers leaves them out.
func sparseMessageSkeleton(peerId: PeerId, positions: [SparseMessagePosition], totalCount: Int, includeLeadingRange: Bool) -> SparseMessageSkeleton {
    let positions = positions.sorted(by: { lhs, rhs in
        return lhs.id > rhs.id
    })

    var result = SparseMessageSkeleton(items: [])
    for i in 0 ..< positions.count {
        if i == 0 {
            if includeLeadingRange && positions[i].offset != 0 {
                result.items.append(.range(count: positions[i].offset))
            }
        } else {
            let deltaCount = positions[i].offset - 1 - positions[i - 1].offset
            if deltaCount > 0 {
                result.items.append(.range(count: deltaCount))
            }
        }
        result.items.append(.anchor(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: positions[i].id), timestamp: positions[i].date, message: nil))
        if i == positions.count - 1 {
            let remainingCount = totalCount - 1 - positions[i].offset
            if remainingCount > 0 {
                result.items.append(.range(count: remainingCount))
            }
        }
    }
    return result
}

/// Lays out one peer's list: its newest local messages, then the skeleton past them.
///
/// `topMessages` is the local history view, newest first. Only `peerId`'s own messages count:
/// Postbox turns a channel's view into its `.associated` merge with the group it was migrated
/// from on the next cached-data write, whatever the view asked for, and those messages belong to
/// the group's own list. Every group message predates every channel message, so the ones kept
/// are always the newest of the peer's history, the same start the skeleton describes; the
/// skeleton's first `count` messages are therefore the top section's and are skipped.
func sparseMessageListSegmentItems(peerId: PeerId, topMessages: [Message], skeleton: SparseMessageSkeleton?) -> (items: [SparseMessageList.State.Item], totalCount: Int) {
    var items: [SparseMessageList.State.Item] = []
    for message in topMessages where message.id.peerId == peerId {
        items.append(SparseMessageList.State.Item(index: items.count, content: .message(message: message, isLocal: true)))
    }

    let topItemCount = items.count
    var totalCount = items.count
    if let skeleton {
        var sparseIndex = 0
        for item in skeleton.items {
            switch item {
            case let .anchor(id, timestamp, message):
                if sparseIndex >= topItemCount {
                    if let message {
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
                    // A run straddling the end of the top section: only its part past the top
                    // section is not already shown.
                    let overflowCount = sparseIndex + count - topItemCount
                    if overflowCount > 0 {
                        totalCount += overflowCount
                    }
                }
                sparseIndex += count
            }
        }
    }

    return (items, totalCount)
}

/// Whether a segment's count is its full length. Its server positions give it; so does a local
/// window (`topMessages`, the history view before the peer filter) that reaches another peer's
/// messages: a channel's `.associated` view continues into the group it was migrated from, every
/// group message predates every channel message, and a history view stops at a gap, so such a
/// window already holds the channel's whole history. That keeps the group's stored media
/// visible without a round trip, offline included.
func sparseMessageListSegmentCountIsFinal(peerId: PeerId, topMessages: [Message], skeleton: SparseMessageSkeleton?) -> Bool {
    if skeleton != nil {
        return true
    }
    return topMessages.contains(where: { $0.id.peerId != peerId })
}

/// The list the grid shows for a channel and the group it was migrated from: every item of
/// `main`, then every item of `legacy` shifted past `main`. Nil while there is nothing to
/// publish yet.
///
/// `mainCountIsFinal`: the channel's count is its full length (`sparseMessageListSegmentCountIsFinal`).
/// Until then it covers only its local messages, so it is not yet the group's offset.
///
/// `holdForLegacyFocus`: the list opens focused on a group message. The pane consumes its focus
/// on the first state that contains any message and drops it when none matches
/// (`PeerInfoVisualMediaPaneNode`), so until both lists have settled only the empty loading
/// state is published.
func mergedSparseMessageListState(main: SparseMessageList.State?, mainCountIsFinal: Bool, legacy: SparseMessageList.State?, holdForLegacyFocus: Bool) -> SparseMessageList.State? {
    if holdForLegacyFocus {
        guard let main, !main.isLoading, mainCountIsFinal, let legacy, !legacy.isLoading else {
            return SparseMessageList.State(items: [], totalCount: 0, isLoading: true)
        }
    }
    guard let main else {
        return nil
    }
    // Until the channel has loaded and knows its full length, its count is not yet the group's
    // offset.
    guard let legacy, !main.isLoading, mainCountIsFinal else {
        return main
    }

    var items = main.items
    for item in legacy.items {
        items.append(SparseMessageList.State.Item(index: main.totalCount + item.index, content: item.content))
    }
    return SparseMessageList.State(items: items, totalCount: main.totalCount + legacy.totalCount, isLoading: false)
}

/// What one peer's `messages.getSearchResultsCalendar` reported about its whole matching history.
struct SparseCalendarPeerBounds: Equatable {
    /// The date of the oldest matching message.
    var minDate: Int32
    /// How many messages match.
    var count: Int32
}

/// The oldest date the calendar lays out months for: the earliest `minDate` among peers that
/// have matching messages. A peer without any has no oldest message, so a `minDate` is used
/// without results only when no peer has any, and then only the main peer's (the value the
/// calendar used before it read more than one peer).
func sparseCalendarMinTimestamp(mainPeerId: PeerId, bounds: [PeerId: SparseCalendarPeerBounds]) -> Int32? {
    if let value = bounds.values.filter({ $0.count > 0 }).map({ $0.minDate }).min() {
        return value
    }
    return bounds[mainPeerId]?.minDate
}

/// The calendar's days for a channel and the group it was migrated from, from each peer's own
/// days. A day both peers have (the migration day) counts both and shows the older message, as
/// each peer's day already shows its oldest (`period.minMsgId`).
func mergedSparseCalendarDays(_ daysByPeer: [[Int32: SparseMessageCalendar.Entry]]) -> [Int32: SparseMessageCalendar.Entry] {
    var result: [Int32: SparseMessageCalendar.Entry] = [:]
    for days in daysByPeer {
        for (day, entry) in days {
            if let current = result[day] {
                let message = current.message.index < entry.message.index ? current.message : entry.message
                result[day] = SparseMessageCalendar.Entry(message: message, count: current.count + entry.count)
            } else {
                result[day] = entry
            }
        }
    }
    return result
}

/// The media calendar's paging over a channel and the group it was migrated from: a cursor and
/// the loaded days per peer.
struct SparseCalendarPagingState {
    struct Cursor: Equatable {
        var peerId: PeerId
        /// Where the peer's next page starts; nil once the peer is exhausted.
        var nextOffset: Int32?
    }

    struct Request: Equatable {
        var peerId: PeerId
        var offset: Int32
    }

    /// One page of one peer's `messages.getSearchResultsCalendar`.
    struct Page {
        var peerId: PeerId
        var messagesByDay: [Int32: SparseMessageCalendar.Entry]
        var nextOffset: Int32?
        /// Nil when the request failed.
        var bounds: SparseCalendarPeerBounds?
    }

    let mainPeerId: PeerId
    /// In list order: the channel, then the group it was migrated from.
    private(set) var cursors: [Cursor]
    private(set) var hasLoaded: Bool = false
    private var boundsByPeer: [PeerId: SparseCalendarPeerBounds] = [:]
    private var messagesByDayByPeer: [PeerId: [Int32: SparseMessageCalendar.Entry]] = [:]

    init(mainPeerId: PeerId) {
        self.mainPeerId = mainPeerId
        self.cursors = [Cursor(peerId: mainPeerId, nextOffset: 0)]
    }

    var hasMore: Bool {
        return self.cursors.contains(where: { $0.nextOffset != nil })
    }

    var minTimestamp: Int32? {
        return sparseCalendarMinTimestamp(mainPeerId: self.mainPeerId, bounds: self.boundsByPeer)
    }

    var messagesByDay: [Int32: SparseMessageCalendar.Entry] {
        return mergedSparseCalendarDays(self.cursors.compactMap { self.messagesByDayByPeer[$0.peerId] })
    }

    /// The pages the next load asks for, given the peers that exist now, in list order. The first
    /// load asks every peer, so that `minTimestamp` covers all of them before the calendar lays
    /// out its months (it reads the value once). Later loads continue the first peer still open,
    /// so the channel is paged to its end before the group.
    func requests(peerIds: [PeerId]) -> [Request] {
        var result: [Request] = []
        for peerId in peerIds {
            let offset: Int32?
            if let cursor = self.cursors.first(where: { $0.peerId == peerId }) {
                offset = cursor.nextOffset
            } else {
                // A peer seen for the first time starts at its newest message.
                offset = 0
            }
            guard let offset else {
                continue
            }
            result.append(Request(peerId: peerId, offset: offset))
            if self.hasLoaded {
                break
            }
        }
        return result
    }

    /// Applies a load. `peerIds` are the peers that exist now, in list order. A known peer missing
    /// from them can never be requested and is closed, so `hasMore` cannot stay true with
    /// nothing left to ask for.
    mutating func apply(peerIds: [PeerId], pages: [Page]) {
        self.hasLoaded = true

        for peerId in peerIds where !self.cursors.contains(where: { $0.peerId == peerId }) {
            self.cursors.append(Cursor(peerId: peerId, nextOffset: 0))
        }
        for i in 0 ..< self.cursors.count where !peerIds.contains(self.cursors[i].peerId) {
            self.cursors[i].nextOffset = nil
        }

        for page in pages {
            if let index = self.cursors.firstIndex(where: { $0.peerId == page.peerId }) {
                self.cursors[index].nextOffset = page.nextOffset
            }
            if let bounds = page.bounds {
                self.boundsByPeer[page.peerId] = bounds
            }
            // A later page of the same peer replaces its day, as the calendar always did; only
            // days of different peers are added together (`mergedSparseCalendarDays`).
            for (day, entry) in page.messagesByDay {
                self.messagesByDayByPeer[page.peerId, default: [:]][day] = entry
            }
        }
    }

    mutating func removeMessages(minTimestamp: Int32, maxTimestamp: Int32) {
        for peerId in Array(self.messagesByDayByPeer.keys) {
            self.messagesByDayByPeer[peerId] = self.messagesByDayByPeer[peerId]?.filter { _, entry in
                return entry.message.timestamp < minTimestamp || entry.message.timestamp > maxTimestamp
            }
        }
    }
}

/// The anchor a hole request should load, given the channel's and the group's skeletons.
///
/// The grid loads the hole anchor nearest the first missing cell it shows, and near the migration
/// boundary that can be the other segment's anchor: a cell in the channel's trailing run (after
/// its last known position) can be nearer the group's first anchor, and a cell in the group's
/// leading run nearer the channel's last one. A segment never loads past its own edge, so that
/// request would load nothing the grid is missing, and the grid, which asks again as soon as a
/// load completes, would repeat it without end. Such a request loads the other segment's edge
/// run instead; once that run is loaded, requests go where they were aimed.
///
/// Only while that edge anchor is still a placeholder: once it is loaded, the run beside it is
/// longer than one load can take, so loading there again would make no progress either, and the
/// request is better spent where it was aimed. With the group's top section in front of its first
/// anchor, this matters mostly while that section is empty or loading, and with a focus.
func sparseMessageListHoleAnchor(requested: MessageId, main: SparseMessageSkeleton?, legacy: SparseMessageSkeleton?) -> MessageId {
    guard let main, let legacy else {
        return requested
    }
    if requested == legacy.firstAnchorId, main.endsWithRange, !main.lastAnchorIsLoaded, let mainLastAnchorId = main.lastAnchorId {
        return mainLastAnchorId
    }
    if requested == main.lastAnchorId, legacy.startsWithRange, !legacy.firstAnchorIsLoaded, let legacyFirstAnchorId = legacy.firstAnchorId {
        return legacyFirstAnchorId
    }
    return requested
}

/// Where `SparseMessageList`'s initial focus goes: to the main segment when it is the peer's own
/// message, otherwise (outside threads) to the segment of the group the channel was migrated
/// from, which is not known yet when the list opens.
struct SparseMessageListFocus: Equatable {
    var main: MessageIndex?
    var legacy: MessageIndex?
}

func sparseMessageListFocus(initialMessageIndex: MessageIndex?, peerId: PeerId, threadId: Int64?) -> SparseMessageListFocus {
    guard let initialMessageIndex else {
        return SparseMessageListFocus(main: nil, legacy: nil)
    }
    if initialMessageIndex.id.peerId == peerId {
        return SparseMessageListFocus(main: initialMessageIndex, legacy: nil)
    } else if threadId == nil {
        return SparseMessageListFocus(main: nil, legacy: initialMessageIndex)
    } else {
        return SparseMessageListFocus(main: nil, legacy: nil)
    }
}

/// What a change of the channel's migrated-from group does: whether the group's segment is
/// replaced (created, dropped or swapped), and the focus left for it. A focus on a message of any
/// other peer is dropped, so the list never waits for a group that is not coming.
struct SparseMessageListLegacyPeerChange: Equatable {
    var replacesSegment: Bool
    var focus: MessageIndex?
}

func sparseMessageListLegacyPeerChange(currentPeerId: PeerId?, updatedPeerId: PeerId?, focus: MessageIndex?) -> SparseMessageListLegacyPeerChange {
    var focus = focus
    if let currentFocus = focus, currentFocus.id.peerId != updatedPeerId {
        focus = nil
    }
    return SparseMessageListLegacyPeerChange(replacesSegment: currentPeerId != updatedPeerId, focus: focus)
}

/// The focus still held after publishing `state`. The pane looks for its focus in the first state
/// that is not loading; after that a reload of either list must show what it has instead of
/// holding the grid empty again.
func sparseMessageListHeldFocus(afterPublishing state: SparseMessageList.State, focus: MessageIndex?) -> MessageIndex? {
    return state.isLoading ? focus : nil
}

/// The segment a hole request loads in, after the boundary redirect (`sparseMessageListHoleAnchor`).
struct SparseMessageListHoleTarget: Equatable {
    enum Segment: Equatable {
        case main
        case legacy
    }

    var segment: Segment
    var anchor: MessageId
}

/// Nil when no segment holds the anchor: it outlived its segment (the group was replaced or
/// dropped), and the request completes without loading.
func sparseMessageListHoleTarget(requested: MessageId, mainPeerId: PeerId, mainSkeleton: SparseMessageSkeleton?, legacyPeerId: PeerId?, legacySkeleton: SparseMessageSkeleton?) -> SparseMessageListHoleTarget? {
    let anchor = sparseMessageListHoleAnchor(requested: requested, main: mainSkeleton, legacy: legacySkeleton)
    if anchor.peerId == mainPeerId {
        return SparseMessageListHoleTarget(segment: .main, anchor: anchor)
    } else if let legacyPeerId, anchor.peerId == legacyPeerId {
        return SparseMessageListHoleTarget(segment: .legacy, anchor: anchor)
    } else {
        return nil
    }
}
