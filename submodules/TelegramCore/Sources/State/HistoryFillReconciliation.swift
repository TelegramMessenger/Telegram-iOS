import Foundation
import Postbox

/// How many stored messages one confirmation round of a history fill checks (spec 2026-10-15 §4,
/// docs/superpowers/specs/2026-10-15-difference-too-long-design.md).
let historyFillConfirmationLimit = 200

/// Whether a history fill reconciles the range it closes (spec §4): a fill of a private chat or a basic
/// group (Saved Messages included), in the Cloud namespace, with no thread. Channels keep their own
/// validation; Saved Messages sublists and bot forums are threads and keep their fills as they are.
func historyFillReconciles(peer: Peer, peerInput: FetchMessageHistoryHoleThreadInput, namespace: MessageId.Namespace, space: MessageHistoryHoleOperationSpace) -> Bool {
    guard case let .direct(peerId, threadId) = peerInput, threadId == nil else {
        return false
    }
    if namespace != Namespaces.Message.Cloud {
        return false
    }
    if peerId.namespace != Namespaces.Peer.CloudUser && peerId.namespace != Namespaces.Peer.CloudGroup {
        return false
    }
    if peer.isForumOrMonoForum {
        return false
    }
    switch space {
    case .everywhere:
        return true
    case let .tag(tag):
        // A live-location answer (messages.getRecentLocations) proves nothing about a range.
        return tag != .liveLocation
    case .customTag:
        return false
    }
}

/// The stored messages one confirmation round of a history fill checks, and the part of the filled
/// range the fill closes once they are confirmed.
struct HistoryFillConfirmationPlan: Equatable {
    /// At most `limit` candidates: the ones nearest the edge the fill started from.
    var batch: [MessageId]
    /// `filledRange` when every candidate is in `batch`. Otherwise `filledRange` cut just before the
    /// nearest candidate left over on each side of the edge, so no unconfirmed message is revealed; the
    /// fill makes the rest a hole for the next fill, also where it was none (Holes.swift). It always holds the edge (the start of a `.range`, the anchor
    /// of an `.aroundId`), so the view's next hole is a new, smaller one, never the one just filled.
    var closedRange: ClosedRange<MessageId.Id>
}

/// Orders `candidates` by distance from the edge the fill started from (nearer first, the lower id on a
/// tie) and plans one round of at most `limit` of them. A downward `.range` starts at
/// `filledRange.upperBound`, an upward one at `filledRange.lowerBound`, an `.aroundId` at its anchor.
/// `candidates` must lie in `filledRange`.
func historyFillConfirmationPlan(candidates: [MessageId], direction: MessageHistoryViewRelativeHoleDirection, filledRange: ClosedRange<MessageId.Id>, limit: Int) -> HistoryFillConfirmationPlan {
    let edge: MessageId.Id
    switch direction {
    case let .range(start, end):
        edge = start.id <= end.id ? filledRange.lowerBound : filledRange.upperBound
    case let .aroundId(anchor):
        edge = anchor.id
    }
    let ordered = candidates.sorted(by: { lhs, rhs in
        let lhsDistance = abs(Int64(lhs.id) - Int64(edge))
        let rhsDistance = abs(Int64(rhs.id) - Int64(edge))
        if lhsDistance != rhsDistance {
            return lhsDistance < rhsDistance
        }
        return lhs.id < rhs.id
    })
    let batchCount = max(1, limit)
    var lowerBound = filledRange.lowerBound
    var upperBound = filledRange.upperBound
    for id in ordered.dropFirst(batchCount) {
        if id.id < edge {
            lowerBound = max(lowerBound, id.id + 1)
        } else {
            upperBound = min(upperBound, id.id - 1)
        }
    }
    // The nearest candidate is always in the batch, so a left-over one is never the edge itself and,
    // with every candidate inside `filledRange`, the bounds cannot cross.
    assert(lowerBound <= upperBound)
    return HistoryFillConfirmationPlan(batch: Array(ordered.prefix(batchCount)), closedRange: lowerBound ... max(lowerBound, upperBound))
}

/// The stored ids of `filledRange` nearest the edge a fill started from: at most `limit` from the edge's
/// side of a `.range`, at most `limit` on each side of an `.aroundId` anchor. Those are all
/// `historyFillConfirmationPlan` needs: the round's candidates and the nearest one left over on each side.
///
/// Without `tag`, every stored message, by id (`messageIdsInRange`, so an imported message with a new id
/// and an old date is where its id puts it). With `tag`, only the messages carrying it, from the tag's own
/// index inside the range (`messageIndicesWithTag`), however many newer messages carry the tag. That index
/// is ordered by date, so there "nearest" is by date, and a message of the range dated before the stored
/// message just below it or after the one just above it is not read, whichever side was imported; only when
/// those two neighbours cross is the tag's whole index read. A message missed so is not a candidate: it is
/// left unconfirmed and stays stored, as before reconciliation; it is never deleted.
func historyFillStoredIdsNearEdge(transaction: Transaction, peerId: PeerId, namespace: MessageId.Namespace, tag: MessageTags?, direction: MessageHistoryViewRelativeHoleDirection, filledRange: ClosedRange<MessageId.Id>, limit: Int) -> [MessageId] {
    func read(_ range: ClosedRange<MessageId.Id>, fromUpperBound: Bool) -> [MessageId] {
        if let tag = tag {
            return transaction.messageIndicesWithTag(peerId: peerId, namespace: namespace, tag: tag, range: range, limit: limit, fromUpperBound: fromUpperBound).map { $0.id }
        } else {
            return transaction.messageIdsInRange(peerId: peerId, namespace: namespace, range: range, limit: limit, fromUpperBound: fromUpperBound)
        }
    }
    switch direction {
    case let .range(start, end):
        // A downward fill starts at the top of the range, an upward one at its bottom.
        return read(filledRange, fromUpperBound: start.id > end.id)
    case let .aroundId(anchor):
        var result: [MessageId] = []
        if anchor.id >= filledRange.lowerBound {
            result.append(contentsOf: read(filledRange.lowerBound ... min(anchor.id, filledRange.upperBound), fromUpperBound: true))
        }
        if anchor.id < filledRange.upperBound {
            result.append(contentsOf: read(max(anchor.id + 1, filledRange.lowerBound) ... filledRange.upperBound, fromUpperBound: false))
        }
        return result
    }
}

/// What a history fill confirms before it writes anything.
struct HistoryFillReconciliation {
    var plan: HistoryFillConfirmationPlan
    /// `stableVersion` of each batch candidate when it was read. `applyStoredMessageConfirmation` leaves
    /// alone a candidate written since (an edit or a deletion that arrived meanwhile): the newer write wins.
    var versions: [MessageId: UInt32]
    /// `stableVersion` of each answer message that was already stored when the answer was parsed. The
    /// answer is stored only once the confirmation answers, so it can be older than a deletion or an edit
    /// that arrived meanwhile; `historyFillAnswerToStore` leaves such a message as that write left it.
    var answerVersions: [MessageId: UInt32]
}

/// The answer messages a fill that waited for a confirmation stores: all of them except those stored when
/// the answer was parsed (`answerVersions`) and deleted or written again since. Those writes arrived while
/// the confirmation was in flight and are newer than the answer, so they win, as a candidate's do.
func historyFillAnswerToStore(transaction: Transaction, storeMessages: [StoreMessage], answerVersions: [MessageId: UInt32]) -> [StoreMessage] {
    return storeMessages.filter { message in
        guard case let .Id(id) = message.id, let version = answerVersions[id] else {
            return true
        }
        guard let current = transaction.getMessage(id) else {
            return false
        }
        return current.stableVersion == version
    }
}

/// `messages` without those deleted in the last few minutes (`Transaction.wasMessageDeletedRecently`; owner
/// decision D2, 2026-10-15). An answer to a request that was in flight while such a deletion landed can predate
/// it: storing one of its messages would bring a deleted message back. This covers a message never stored here
/// too (an update deleting a message the fetch was bringing), which a fill's `answerVersions` cannot see. Every
/// history fill applies it to its answer and to the reply targets its follow-up fetches, with or without a
/// confirmation; the account reset and the chat-list hole fill apply it to the dialogs' top messages and their
/// reply targets. A skip is logged under `logTag` as `logPrefix: not storing [...]`.
func fetchedMessagesWithoutRecentDeletions(transaction: Transaction, messages: [StoreMessage], logTag: String, logPrefix: String) -> [StoreMessage] {
    var result: [StoreMessage] = []
    var skipped: [MessageId] = []
    for message in messages {
        if case let .Id(id) = message.id, transaction.wasMessageDeletedRecently(id) {
            skipped.append(id)
        } else {
            result.append(message)
        }
    }
    if !skipped.isEmpty {
        Logger.shared.log(logTag, "\(logPrefix): not storing \(skipped): deleted while the fetch was in flight")
    }
    return result
}

/// `messages`, each one edited since `since` replaced by its edit (`Transaction.recentMessageEdit`; owner decision
/// 2026-10-25, the edit counterpart of D2). The update replay records every edit it receives, applied to the stored
/// message or, with none stored, to nothing; an answer to a request that went out before the edit can predate it,
/// and storing that answer's message would undo the edit or show the old content. The edit carries the whole message
/// as the server sent it after the change, so it is stored in the answer's place, where the answer put it. `since` is
/// when the request went out, on `FetchedAnswerAge`'s clock: an edit recorded before then is in the answer, which may
/// be newer still. A `since` earlier than the request (a fetch of several requests, timed from its first) is safe: an
/// edit made between the two is stored over an answer that already holds it, or a later edit whose own update then
/// rewrites the message. Applied wherever `fetchedMessagesWithoutRecentDeletions` is, after it: by every history fill
/// to its answer and to the reply targets its follow-up fetches, and by the account reset and the chat-list hole fill
/// to the top messages and their reply targets. A replacement is logged under `logTag` as
/// `logPrefix: storing the edits of [...]`.
func fetchedMessagesWithRecentEdits(transaction: Transaction, messages: [StoreMessage], since: Double, logTag: String, logPrefix: String) -> [StoreMessage] {
    var replaced: [MessageId] = []
    let result = messages.map { message -> StoreMessage in
        if case let .Id(id) = message.id, let edit = transaction.recentMessageEdit(id, since: since) {
            replaced.append(id)
            return edit
        }
        return message
    }
    if !replaced.isEmpty {
        Logger.shared.log(logTag, "\(logPrefix): storing the edits of \(replaced): edited while the fetch was in flight")
    }
    return result
}

/// How old an answer may be when it is stored, so that `fetchedMessagesWithoutRecentDeletions` still sees every
/// deletion the answer can predate. Postbox keeps a deletion on its record for
/// `Transaction.recentlyDeletedMessagesLifetime` (5 minutes), and the waits between an answer and its store
/// have no bound: a fill's confirmation, a forum fill's thread resolution and the chat-list requests of the reset and
/// the chat-list fill all retry until they succeed. An answer older than `maximum` when it is stored may predate a
/// deletion the record has already forgotten, so it is not stored: a history fill applies only its confirmation of
/// what was already stored (which touches only messages still at the version they were read at, so it is safe at
/// any age), the reset and the chat-list fill write nothing; each closes nothing and is made again (the
/// never-give-up rule). The times are on the record's clock, the system uptime,
/// which a change of the wall clock does not move.
enum FetchedAnswerAge {
    /// The record's lifetime less a margin, `min(30 s, lifetime / 2)`: 270 s for the 5-minute record. The margin
    /// covers the answer's own flight: a deletion the answer predates was recorded after the server produced
    /// the answer, which is at most that flight before it arrived.
    static let defaultMaximum: Double = Transaction.recentlyDeletedMessagesLifetime - min(30.0, Transaction.recentlyDeletedMessagesLifetime / 2.0)

    /// The oldest an answer may be when it is stored, in seconds. Tests shorten it (and restore it); nothing
    /// else writes it.
    static var maximum: Double = FetchedAnswerAge.defaultMaximum

    /// Now, on the record's clock.
    static func now() -> Double {
        return ProcessInfo.processInfo.systemUptime
    }

    /// Whether an answer that arrived at `answeredAt` (a `now()`) is too old to store now.
    static func isTooOldToStore(answeredAt: Double) -> Bool {
        return FetchedAnswerAge.now() - answeredAt > FetchedAnswerAge.maximum
    }

    /// How long the account reset or a chat-list hole fill waits before its `n`-th restart in a row after answers
    /// too old to store (`n` from 1): 1 s, doubling up to 60 s, the curve `AccountStateManager.consecutiveResetDelay`
    /// follows from its second reset on. The wait keeps attempts that stay slower than `maximum` from following each
    /// other back to back.
    /// They never stop. Tests replace it (and restore it); nothing else writes it.
    static var staleRestartDelay: (Int) -> Double = { n in
        return min(60.0, Double(1 << min(max(n - 1, 0), 6)))
    }
}

/// Reads, in the fill's parsing transaction (after the answer arrived, before anything is written), the
/// stored Cloud messages of the chat inside `filledRange` that the answer does not hold, and plans their
/// confirmation; then the versions of the batch and of the answer's stored messages. Nil when the fill is
/// out of scope or nothing stored is left out, the normal case: the fill then proceeds exactly as before,
/// and the candidate read is its only added cost.
func historyFillReconciliation(transaction: Transaction, peer: Peer, peerInput: FetchMessageHistoryHoleThreadInput, namespace: MessageId.Namespace, space: MessageHistoryHoleOperationSpace, direction: MessageHistoryViewRelativeHoleDirection, filledRange: ClosedRange<MessageId.Id>, storeMessages: [StoreMessage]) -> HistoryFillReconciliation? {
    if !historyFillReconciles(peer: peer, peerInput: peerInput, namespace: namespace, space: space) {
        return nil
    }
    var answerIds = Set<MessageId>()
    for message in storeMessages {
        if case let .Id(id) = message.id {
            answerIds.insert(id)
        }
    }
    // Of the stored ids nearest the edge, at most `answerIds.count` are the answer's own, so this many hold
    // the round's candidates and the nearest candidate left over on each side.
    let limit = historyFillConfirmationLimit + 1 + answerIds.count
    let storedIds: [MessageId]
    switch space {
    case .everywhere:
        storedIds = historyFillStoredIdsNearEdge(transaction: transaction, peerId: peer.id, namespace: namespace, tag: nil, direction: direction, filledRange: filledRange, limit: limit)
    case let .tag(tag):
        // In a tag fill only the stored messages carrying the tag count: the tag's own index, inside
        // `filledRange`.
        storedIds = historyFillStoredIdsNearEdge(transaction: transaction, peerId: peer.id, namespace: namespace, tag: tag, direction: direction, filledRange: filledRange, limit: limit)
    case .customTag:
        storedIds = []
    }
    let candidates = storedIds.filter { id in
        return id.peerId == peer.id && id.namespace == namespace && filledRange.contains(id.id) && !answerIds.contains(id)
    }
    if candidates.isEmpty {
        return nil
    }
    let plan = historyFillConfirmationPlan(candidates: candidates, direction: direction, filledRange: filledRange, limit: historyFillConfirmationLimit)
    var versions: [MessageId: UInt32] = [:]
    for id in plan.batch {
        if let message = transaction.getMessage(id) {
            versions[id] = message.stableVersion
        }
    }
    var answerVersions: [MessageId: UInt32] = [:]
    for id in answerIds {
        if let message = transaction.getMessage(id) {
            answerVersions[id] = message.stableVersion
        }
    }
    return HistoryFillReconciliation(plan: plan, versions: versions, answerVersions: answerVersions)
}
