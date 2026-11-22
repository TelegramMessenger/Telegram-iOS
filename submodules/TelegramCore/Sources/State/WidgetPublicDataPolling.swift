import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

/// The timing of polling shared message widgets' states (widget-sandbox v0.2; design §4 calls 3–4, upstream
/// integration.md "Polling a shared widget's shared state"), pure: times are seconds of the caller's clock.
///
/// A widget on screen that watches registers its message under its `widget_id`; the oldest registration still present
/// is the id's carrier, the one message polled. The first poll goes at once with hash 0, then one after each answer's
/// period (clamped to 5–3600 s), 30 s after a failure. A not-modified answer changes only the timing; a new hash is
/// written to every registered message, and to each one registered later. A widget back on screen within its id's period
/// waits for the next poll. Polling stops when no registration is left; the id's hash, data and next poll are kept.
struct WidgetPublicDataPollingState {
    enum Action: Equatable {
        case none
        case pollAt(Double)
    }

    static let minimumPeriod: Double = 5.0
    static let maximumPeriod: Double = 3600.0
    /// Before the first answer and after a failure (the server's default period).
    static let defaultPeriod: Double = 30.0

    private struct Registration {
        let token: Int
        let messageId: MessageId
    }

    private struct Entry {
        var registrations: [Registration] = []
        var hash: Int64 = 0
        var data: Data?
        var nextPoll: Double?
        var inFlight = false
        /// The hash the poll in flight was sent with; 0 is a full poll, whose answer goes to every registration.
        var sentHash: Int64 = 0
        /// A disagreement owes a full poll: nothing is adopted until a poll goes without a hash, and a poll with the
        /// old hash that answers "not modified" is followed by one at once.
        var fullPollOwed = false
    }

    private var entries: [Int64: Entry] = [:]
    private var widgetIds: [Int: Int64] = [:]
    private var nextToken = 1

    /// Registers `messageId` under `widgetId`, with the shared state the message carries (`messageHash` nil: a message
    /// stored before `public_data_hash` existed). The action starts polling when the id had no registration and no
    /// poll in flight: at once, or at the stored next poll if that is later.
    ///
    /// The message's hash is taken while the id knows none, no poll is in flight and no full poll is owed. One that
    /// disagrees with the id's is never written over: hashes are not ordered, so the message's may be the newer (a
    /// message loaded after an edit is current). The disagreement owes a full poll (without a hash): at once, or after
    /// the poll in flight if that one answers "not modified"; its answer is written to every registration, and until it
    /// goes no message's hash is adopted. Any registration while one is owed and none is in flight polls at once (the
    /// last registration may have left while it was owed). `writeLatest` is true only for a message without a hash
    /// while the id has a state: it gets the latest state.
    mutating func register(widgetId: Int64, messageId: MessageId, messageHash: Int64?, messageData: Data?, now: Double) -> (token: Int, action: Action, writeLatest: Bool) {
        let token = self.nextToken
        self.nextToken += 1
        self.widgetIds[token] = widgetId
        var entry = self.entries[widgetId] ?? Entry()
        let wasIdle = entry.registrations.isEmpty
        entry.registrations.append(Registration(token: token, messageId: messageId))
        var writeLatest = false
        if let messageHash {
            if entry.hash == 0 && !entry.inFlight && !entry.fullPollOwed {
                entry.hash = messageHash
                entry.data = messageData
            } else if entry.hash != 0 && messageHash != entry.hash {
                entry.hash = 0
                entry.fullPollOwed = true
            }
        } else if entry.data != nil {
            writeLatest = true
        }
        self.entries[widgetId] = entry
        if entry.inFlight {
            return (token, .none, writeLatest)
        }
        if entry.fullPollOwed {
            return (token, .pollAt(now), false)
        }
        if !wasIdle {
            return (token, .none, writeLatest)
        }
        return (token, .pollAt(max(now, entry.nextPoll ?? now)), writeLatest)
    }

    /// `register` for a message whose own shared state is unknown (tests).
    mutating func register(widgetId: Int64, messageId: MessageId, now: Double) -> (token: Int, action: Action) {
        let result = self.register(widgetId: widgetId, messageId: messageId, messageHash: nil, messageData: nil, now: now)
        return (result.token, result.action)
    }

    /// Ends a registration; the carrier passes to the next oldest. Polling stops by itself when none is left.
    mutating func unregister(token: Int) -> Action {
        guard let widgetId = self.widgetIds.removeValue(forKey: token) else {
            return .none
        }
        self.entries[widgetId]?.registrations.removeAll(where: { $0.token == token })
        return .none
    }

    func carrier(widgetId: Int64) -> MessageId? {
        return self.entries[widgetId]?.registrations.first?.messageId
    }

    func hash(widgetId: Int64) -> Int64 {
        return self.entries[widgetId]?.hash ?? 0
    }

    /// The last shared state a poll of `widgetId` brought, if any.
    func latestData(widgetId: Int64) -> Data? {
        return self.entries[widgetId]?.data
    }


    mutating func pollStarted(widgetId: Int64) {
        guard var entry = self.entries[widgetId] else {
            return
        }
        entry.inFlight = true
        entry.sentHash = entry.hash
        if entry.hash == 0 {
            entry.fullPollOwed = false
        }
        self.entries[widgetId] = entry
    }

    /// An answer: `hash` nil is not modified. `write` is every registered message when the hash changed or the poll
    /// was a full one.
    mutating func answered(widgetId: Int64, hash: Int64?, data: Data?, period: Int32, now: Double) -> (write: [MessageId], next: Action) {
        guard var entry = self.entries[widgetId] else {
            return ([], .none)
        }
        entry.inFlight = false
        let wasFullPoll = entry.sentHash == 0
        let nextPoll = now + min(max(Double(period), WidgetPublicDataPollingState.minimumPeriod), WidgetPublicDataPollingState.maximumPeriod)
        entry.nextPoll = nextPoll
        var write: [MessageId] = []
        if let hash, hash != entry.hash || wasFullPoll {
            entry.hash = hash
            entry.data = data
            for registration in entry.registrations where !write.contains(registration.messageId) {
                write.append(registration.messageId)
            }
        }
        var next: Action = entry.registrations.isEmpty ? .none : .pollAt(nextPoll)
        if entry.fullPollOwed {
            if hash == nil {
                // The poll was sent with the old hash, so "not modified" leaves the disagreement open: the full poll
                // goes at once.
                if !entry.registrations.isEmpty {
                    next = .pollAt(now)
                }
            } else {
                // A new state was written to every registration.
                entry.fullPollOwed = false
            }
        }
        self.entries[widgetId] = entry
        return (write, next)
    }

    /// A poll that failed: the next one after the default period, while registrations are left.
    mutating func failed(widgetId: Int64, now: Double) -> Action {
        guard var entry = self.entries[widgetId] else {
            return .none
        }
        entry.inFlight = false
        let nextPoll = now + WidgetPublicDataPollingState.defaultPeriod
        entry.nextPoll = nextPoll
        self.entries[widgetId] = entry
        return entry.registrations.isEmpty ? .none : .pollAt(nextPoll)
    }
}

/// Polls the shared states of message widgets while they watch on screen (widget-sandbox v0.2): one of the two requests
/// the app makes for a widget (design §4.A), `messages.getWidgetPublicData`, only for a registered widget id, only to
/// Telegram's server. A new shared state is written into each registered message's stored widget, so its bubble hands it
/// to the running widget (`setState`) as any edit does. Per account, held by `AccountViewTracker`; all state on `queue`.
final class WidgetPublicDataPolling {
    private let queue: Queue
    private let postbox: Postbox
    private let network: Network
    private var state = WidgetPublicDataPollingState()
    /// Per widget id: the wait for its next poll (cancelled when its last registration leaves).
    private var waits: [Int64: MetaDisposable] = [:]
    /// Per widget id: its poll in flight (left to finish, so its state never stays in flight).
    private var requests: [Int64: MetaDisposable] = [:]

    init(queue: Queue, postbox: Postbox, network: Network) {
        self.queue = queue
        self.postbox = postbox
        self.network = network
    }

    deinit {
        for (_, disposable) in self.waits {
            disposable.dispose()
        }
        for (_, disposable) in self.requests {
            disposable.dispose()
        }
    }

    /// Polls `widgetId` with `messageId` as a carrier while subscribed: a subscription is a registration.
    func poll(messageId: MessageId, widgetId: Int64) -> Signal<Never, NoError> {
        return Signal { [weak self] _ in
            guard let self else {
                return EmptyDisposable
            }
            // The shared state the message carries and its hash (none for a message stored before the hash existed).
            let stored = self.postbox.transaction { transaction -> (hash: Int64?, data: Data?) in
                guard let widget = transaction.getMessage(messageId)?.media.first(where: { $0 is TelegramMediaWidget }) as? TelegramMediaWidget, widget.widgetId == widgetId else {
                    return (nil, nil)
                }
                return (widget.publicDataHash, widget.publicData)
            }
            |> deliverOn(self.queue)
            let read = MetaDisposable()
            let registration = MetaDisposable()
            read.set(stored.start(next: { [weak self] stored in
                guard let self else {
                    return
                }
                let (token, action, writeLatest) = self.state.register(widgetId: widgetId, messageId: messageId, messageHash: stored.hash, messageData: stored.data, now: CFAbsoluteTimeGetCurrent())
                if writeLatest, let data = self.state.latestData(widgetId: widgetId) {
                    self.write(data, hash: self.state.hash(widgetId: widgetId), to: [messageId], widgetId: widgetId)
                }
                self.schedule(widgetId: widgetId, action)
                registration.set(ActionDisposable { [weak self] in
                    self?.queue.async {
                        guard let self else {
                            return
                        }
                        let _ = self.state.unregister(token: token)
                        if self.state.carrier(widgetId: widgetId) == nil {
                            self.waits[widgetId]?.set(nil)
                        }
                    }
                })
            }))
            return ActionDisposable {
                read.dispose()
                registration.dispose()
            }
        }
    }

    private func schedule(widgetId: Int64, _ action: WidgetPublicDataPollingState.Action) {
        guard case let .pollAt(time) = action else {
            return
        }
        let wait: MetaDisposable
        if let current = self.waits[widgetId] {
            wait = current
        } else {
            wait = MetaDisposable()
            self.waits[widgetId] = wait
        }
        let waitTime = max(0.0, time - CFAbsoluteTimeGetCurrent())
        wait.set((Signal<Never, NoError>.complete() |> delay(waitTime, queue: self.queue)).start(completed: { [weak self] in
            self?.pollNow(widgetId: widgetId)
        }))
    }

    private func pollNow(widgetId: Int64) {
        guard let carrier = self.state.carrier(widgetId: widgetId) else {
            return
        }
        self.state.pollStarted(widgetId: widgetId)
        let hash = self.state.hash(widgetId: widgetId)
        let network = self.network
        let request = self.postbox.transaction { transaction -> Api.InputPeer? in
            return transaction.getPeer(carrier.peerId).flatMap(apiInputPeer)
        }
        |> castError(MTRpcError.self)
        |> mapToSignal { inputPeer -> Signal<Api.messages.WidgetPublicData, MTRpcError> in
            guard let inputPeer else {
                return .fail(MTRpcError(errorCode: 400, errorDescription: "PEER_ID_INVALID"))
            }
            return network.request(Api.functions.messages.getWidgetPublicData(peer: inputPeer, msgId: carrier.id, hash: hash))
        }
        |> deliverOn(self.queue)
        let disposable: MetaDisposable
        if let current = self.requests[widgetId] {
            disposable = current
        } else {
            disposable = MetaDisposable()
            self.requests[widgetId] = disposable
        }
        disposable.set(request.start(next: { [weak self] result in
            guard let self else {
                return
            }
            let now = CFAbsoluteTimeGetCurrent()
            let answer: (write: [MessageId], next: WidgetPublicDataPollingState.Action)
            switch result {
            case let .widgetPublicData(widgetPublicDataData):
                let data = Data(widgetPublicDataData.data.utf8)
                answer = self.state.answered(widgetId: widgetId, hash: widgetPublicDataData.hash, data: data, period: widgetPublicDataData.period, now: now)
                self.write(data, hash: widgetPublicDataData.hash, to: answer.write, widgetId: widgetId)
            case let .widgetPublicDataNotModified(widgetPublicDataNotModifiedData):
                answer = self.state.answered(widgetId: widgetId, hash: nil, data: nil, period: widgetPublicDataNotModifiedData.period, now: now)
            }
            self.schedule(widgetId: widgetId, answer.next)
        }, error: { [weak self] _ in
            guard let self else {
                return
            }
            self.schedule(widgetId: widgetId, self.state.failed(widgetId: widgetId, now: CFAbsoluteTimeGetCurrent()))
        }))
    }

    /// Writes `data` (empty: none) and its `hash` as the shared state of the stored widget `widgetId` of each message in
    /// `messageIds`.
    private func write(_ data: Data, hash: Int64, to messageIds: [MessageId], widgetId: Int64) {
        if messageIds.isEmpty {
            return
        }
        let publicData: MessageWidgetDataChange = .set(data.isEmpty ? nil : data)
        let _ = self.postbox.transaction { transaction -> Void in
            for messageId in messageIds {
                var edited: StoreMessage?
                transaction.updateMessage(messageId, update: { currentMessage in
                    guard let widget = currentMessage.media.first(where: { $0 is TelegramMediaWidget }) as? TelegramMediaWidget, widget.widgetId == widgetId else {
                        return .skip
                    }
                    let updated = widget.withUpdatedState(chatData: .unchanged, publicData: publicData, publicDataHash: hash)
                    if updated.isEqual(to: widget) {
                        return .skip
                    }
                    let message = storeMessageReplacingWidget(currentMessage, widget: updated)
                    edited = message
                    return .update(message)
                })
                // Recorded as an edit, as a pushed state edit is: a history fill already in flight, whose answer predates
                // this poll, stores this state in its older answer's place (`fetchedMessagesWithRecentEdits`).
                if let edited {
                    transaction.recordMessageEdit(edited)
                }
            }
        }.start()
    }
}
