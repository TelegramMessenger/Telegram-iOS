import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// One step of a session. The app runs from the start until `goOffline` (it is killed: no pushes, no requests);
/// `goOnline` relaunches it. A world event while the app runs queues its push for the next `deliverPushes`.
enum TruthStep: CustomStringConvertible {
    case receive(TruthPeer)
    case sendFromOtherDevice(TruthPeer)
    case edit(TruthPeer)
    case delete(TruthPeer, count: Int)
    case clearHistory(TruthPeer)
    case goOffline
    case goOnline
    case deliverPushes
    case restartApp
    case openChat(TruthPeer)
    /// The chat opened at a random message the app has not loaded (a reply or a search result): an around-anchor fill.
    case openChatAt(TruthPeer)
    /// The chat scrolled up past what it has loaded: a fill of the hole below its newest loaded message, downward.
    case scrollOlder(TruthPeer)
    /// The next `deliverPushes` leaves out its first push, sends it twice, or sends its first two swapped.
    case dropNextPush
    case duplicateNextPush
    case swapNextTwoPushes
    /// The next request with this name fails so, once; its retry is answered as usual.
    case failNext(String, code: Int32, text: String)
    /// A fill of the chat's newest hole starts and its `getHistory` (or, if it confirms, its `messages.getMessages`)
    /// is held, answered from the world as it was when the request arrived, at `releaseHeld`: the stale answer the
    /// record of recent deletions exists for.
    case holdNextFill(TruthPeer)
    case holdNextConfirmation(TruthPeer)
    case releaseHeld

    var description: String {
        switch self {
        case let .receive(chat):
            return "receive(\(chat))"
        case let .sendFromOtherDevice(chat):
            return "sendFromOtherDevice(\(chat))"
        case let .edit(chat):
            return "edit(\(chat))"
        case let .delete(chat, count):
            return "delete(\(chat), \(count))"
        case let .clearHistory(chat):
            return "clearHistory(\(chat))"
        case .goOffline:
            return "goOffline"
        case .goOnline:
            return "goOnline"
        case .deliverPushes:
            return "deliverPushes"
        case .restartApp:
            return "restartApp"
        case let .openChat(chat):
            return "openChat(\(chat))"
        case let .openChatAt(chat):
            return "openChatAt(\(chat))"
        case let .scrollOlder(chat):
            return "scrollOlder(\(chat))"
        case .dropNextPush:
            return "dropNextPush"
        case .duplicateNextPush:
            return "duplicateNextPush"
        case .swapNextTwoPushes:
            return "swapNextTwoPushes"
        case let .failNext(name, code, text):
            return "failNext(\(name), \(code) \(text))"
        case let .holdNextFill(chat):
            return "holdNextFill(\(chat))"
        case let .holdNextConfirmation(chat):
            return "holdNextConfirmation(\(chat))"
        case .releaseHeld:
            return "releaseHeld"
        }
    }
}

/// A random session for `seed`, and the `pts_total_limit` the server sends with it (10…40). 20-60 steps, events
/// weighted towards new messages; in one session of three, an offline stretch long enough for a reset; a fault in
/// at most one step of five; a held request released within 6 steps; no chat opened while one is held. For `.small`
/// the draws are the ones every seed has made since the first run. For a shape with quiet chats, three steps of ten
/// act in a quiet chat, and a few of the new messages open or scroll one of its long chats instead.
func makeTruthSession(seed: UInt64, shape: TruthShape = .small) -> (steps: [TruthStep], ptsTotalLimit: Int32) {
    var random = TruthRandom(seed: seed)
    func draw(_ count: Int) -> Int {
        return Int(random.next() % UInt64(count))
    }
    let quiet = Set(shape.quietChats)
    let allChats: [TruthPeer] = shape.users.map { TruthPeer.user($0) } + shape.basicGroups.map { TruthPeer.chat($0) } + (shape.broadcastChannels + shape.megagroups).map { TruthPeer.channel($0) }
    let chats = allChats.filter { !quiet.contains($0) }
    let quietChats = shape.quietChats
    let longChats = shape.longChats.keys.sorted(by: { $0.description < $1.description })
    let regularChats = chats.filter { !$0.isChannel }
    func pickChat() -> TruthPeer {
        if !quietChats.isEmpty && draw(10) < 3 {
            return quietChats[draw(quietChats.count)]
        }
        return chats[draw(chats.count)]
    }
    let failingRequests = ["updates.getDifference", "updates.getChannelDifference", "messages.getHistory", "messages.getMessages", "messages.getDialogs"]
    let length = 20 + draw(41)
    let ptsTotalLimit = Int32(10 + draw(31))
    let longOfflineAt: Int? = draw(3) == 0 ? draw(length) : nil
    var steps: [TruthStep] = []
    var online = true
    var heldSince: Int?
    for index in 0 ..< length {
        if index == longOfflineAt {
            if heldSince != nil {
                steps.append(.releaseHeld)
                heldSince = nil
            }
            if online {
                steps.append(.goOffline)
            }
            for _ in 0 ..< Int(ptsTotalLimit) + 5 {
                steps.append(.receive(regularChats[draw(regularChats.count)]))
            }
            steps.append(.goOnline)
            online = true
            continue
        }
        if let since = heldSince, index - since >= 6 {
            steps.append(.releaseHeld)
            heldSince = nil
            continue
        }
        let chat = pickChat()
        let roll = draw(100)
        switch roll {
        case 0 ..< 33:
            if !longChats.isEmpty && online && heldSince == nil && roll < 8 {
                let longChat = longChats[draw(longChats.count)]
                steps.append(roll < 4 ? .openChatAt(longChat) : .scrollOlder(longChat))
            } else {
                steps.append(.receive(chat))
            }
        case 33 ..< 40:
            steps.append(.sendFromOtherDevice(chat))
        case 40 ..< 47:
            steps.append(.edit(chat))
        case 47 ..< 54:
            steps.append(.delete(chat, count: 1 + draw(3)))
        case 54 ..< 57:
            steps.append(.clearHistory(regularChats[draw(regularChats.count)]))
        case 57 ..< 66:
            steps.append(.deliverPushes)
        case 66 ..< 72:
            steps.append(online && heldSince == nil ? .openChat(chat) : .receive(chat))
        case 72 ..< 77:
            if heldSince != nil {
                steps.append(.releaseHeld)
                heldSince = nil
            }
            steps.append(online ? .goOffline : .goOnline)
            online.toggle()
        case 77 ..< 80:
            if heldSince != nil {
                steps.append(.releaseHeld)
                heldSince = nil
            }
            steps.append(.restartApp)
            online = true
        case 80 ..< 83:
            steps.append(.dropNextPush)
        case 83 ..< 86:
            steps.append(.duplicateNextPush)
        case 86 ..< 88:
            steps.append(.swapNextTwoPushes)
        case 88 ..< 92:
            steps.append(.failNext(failingRequests[draw(failingRequests.count)], code: 500, text: "INTERNAL_SERVER_ERROR"))
        case 92 ..< 96:
            if online && heldSince == nil {
                steps.append(.holdNextFill(chat))
                heldSince = index
            } else {
                steps.append(.receive(chat))
            }
        default:
            if online && heldSince == nil {
                steps.append(.holdNextConfirmation(regularChats[draw(regularChats.count)]))
                heldSince = index
            } else {
                steps.append(.receive(chat))
            }
        }
    }
    if heldSince != nil {
        steps.append(.releaseHeld)
    }
    if online {
        steps.append(.deliverPushes)
    }
    return (steps, ptsTotalLimit)
}

/// What the oracle found wrong with one session.
struct TruthDiscrepancy: CustomStringConvertible, Equatable {
    enum Kind: String {
        /// The server has it; the app does not, with every chat filled to no holes.
        case missing
        /// The app has it; the server does not.
        case ghost
        /// A channel ghost below the channel's `invalidatedPts`: the app's history validation, which the harness does
        /// not run, would check it when the chat is shown.
        case validationPending
        /// The texts differ.
        case stale
        /// The server lists the chat; the app's chat list does not.
        case unlisted
        /// The app lists the chat with another top message: `ids` is the app's top, then the server's.
        case wrongTop
        /// The app lists a chat the server does not (no message, no cleared top).
        case extraListed
        /// A request the truth server did not answer (held for good).
        case unanswered
        /// The app did not come to rest, or a chat still had holes after 50 fills.
        case noConvergence
    }

    let kind: Kind
    let chat: TruthPeer?
    let ids: [Int32]
    let note: String

    var description: String {
        let chat = self.chat.map { " \($0)" } ?? ""
        let ids = self.ids.isEmpty ? "" : " \(self.ids)"
        let note = self.note.isEmpty ? "" : " (\(self.note))"
        return "\(self.kind.rawValue)\(chat)\(ids)\(note)"
    }
}

extension TruthPeer {
    var peerId: PeerId {
        switch self {
        case let .user(id):
            return StateSyncFixture.userPeerId(id)
        case let .chat(id):
            return PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(id))
        case let .channel(id):
            return StateSyncFixture.channelPeerId(id)
        case .selfUser:
            return StateSyncFixture.accountPeerId
        }
    }
}

/// Runs one session: a fresh Postbox, scripted server and network, the truth server answering every request it
/// knows from `world`, and the real `AccountStateManager`. Steps run to rest one after another, so a seed replays.
final class TruthSessionDriver {
    static let requestNames: [String] = [
        "updates.getState", "updates.getDifference", "updates.getChannelDifference", "messages.getHistory",
        "messages.getMessages", "channels.getMessages", "messages.getDialogs", "messages.getPinnedDialogs",
        "messages.getPeerDialogs"
    ]

    let world: TruthWorld
    let limits: TruthLimits
    let fixture: StateSyncFixture
    let server: ScriptedServer
    private(set) var network: Network!
    private let lock = NSLock()
    private var random: TruthRandom
    private var isRunning = false
    private var pendingPushes: [(updates: Api.Updates, channelId: Int64?, pts: Int32)] = []
    private enum PushFault {
        case drop
        case duplicate
        case swap
    }
    private var pushFaults: [PushFault] = []
    /// Guarded by `lock`: one-shot failures per request name, the name whose next request is held, and the held
    /// request's answer (computed when it arrived).
    private var failures: [String: [(code: Int32, text: String)]] = [:]
    private var holdNext: String?
    private var heldAnswer: (name: String, answer: ScriptedAnswer)?
    /// The fill a hold step started, recorded until `releaseHeld`.
    private var heldFill: SignalRecorder<FetchMessageHistoryHoleResult?>?
    private(set) var problems: [TruthDiscrepancy] = []
    private(set) var log: [String] = []
    /// How long a fill the driver makes may take, in seconds; tests shorten it.
    var fillTimeout: Double = 30.0
    /// Whether `validateChannels` ran: until it has, a channel post below `invalidatedPts` is validation pending.
    private(set) var validationRan = false

    /// `ptsTotalLimit` goes to the app configuration (`pts_total_limit`), as the server would send it. `jitter`
    /// delivers every answer and push 0…50 ms late (`ScriptedServer.deliveryDelay`), drawn from the seed, so pushes land
    /// while requests are in flight and answers overtake each other, as over a real network.
    init(world: TruthWorld, limits: TruthLimits = TruthLimits(), ptsTotalLimit: Int32?, seed: UInt64, jitter: Bool = false) throws {
        self.world = world
        self.limits = limits
        self.random = TruthRandom(seed: seed ^ 0xd41fe7)
        self.fixture = try StateSyncFixture(name: "truth")
        self.server = ScriptedServer()
        if jitter {
            let delays = Atomic<TruthRandom>(value: TruthRandom(seed: seed ^ 0x717e))
            self.server.deliveryDelay = { _ in
                var drawn: UInt64 = 0
                let _ = delays.modify { random in
                    var random = random
                    drawn = random.next()
                    return random
                }
                return Double(drawn % 51) / 1000.0
            }
        }
        self.network = Network.makeForTesting(engine: self.server, basePath: self.fixture.basePath + "/network", encryptionProvider: UnusedEncryptionProvider())
        self.network.shouldKeepConnection.set(.single(true))
        if let ptsTotalLimit {
            self.fixture.seedAppConfiguration(["pts_total_limit": Int(ptsTotalLimit)])
        }
        self.installAnswers()
        self.seedAppInStepWithTheWorld()
    }

    /// Releases the session. False when the Postbox outlived it, which the caller reports.
    func close() -> Bool {
        self.server.dropHeld()
        self.network = nil
        return self.fixture.close()
    }

    private func withWorld<T>(_ f: () -> T) -> T {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return f()
    }

    private func installAnswers() {
        for name in TruthSessionDriver.requestNames {
            self.server.always(name, { [weak self] request in
                guard let self else {
                    return .hold
                }
                let decoded = decodeTruthRequest(name: name, payload: request.payload)
                return self.withWorld { () -> ScriptedAnswer in
                    if var queued = self.failures[name], !queued.isEmpty {
                        let failure = queued.removeFirst()
                        self.failures[name] = queued
                        return .error(code: failure.code, text: failure.text)
                    }
                    guard let value = truthAnswer(decoded, world: self.world, limits: self.limits) else {
                        return .hold
                    }
                    if self.holdNext == name {
                        self.holdNext = nil
                        self.heldAnswer = (name, .result(value))
                        return .hold
                    }
                    return .result(value)
                }
            })
        }
    }

    /// The app as a fresh login leaves it: in step with the world (the account and channel pts), every chat stored with
    /// its peer and chat-list inclusion, and a hole over each chat's whole history.
    private func seedAppInStepWithTheWorld() {
        let world = self.world
        self.fixture.seedAccount(state: AuthorizedAccountState.State(pts: world.pts, qts: world.qts, date: world.date, seq: world.seq))
        var peers: [Peer] = world.users.map { StateSyncFixture.makeUser(id: StateSyncFixture.userPeerId($0), accessHash: 1, firstName: "U\($0)") }
        for groupId in world.basicGroups {
            peers.append(TelegramGroup(id: TruthPeer.chat(groupId).peerId, title: "G\(groupId)", photo: [], participantCount: world.shape.groupMembers.count + 1, role: .member, membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0))
        }
        self.fixture.seedPeers(peers)
        for channelId in world.channels {
            let channel = StateSyncFixture.makeChannel(id: StateSyncFixture.channelPeerId(channelId), accessHash: 1, title: "C\(channelId)", isBroadcast: world.broadcastChannels.contains(channelId))
            self.fixture.seedChannel(channel, state: ChannelState(pts: world.channelPts[channelId]!, invalidatedPts: nil, synchronizedUntilMessageId: nil))
        }
        for chat in world.chats() {
            self.fixture.seedChat(peerId: chat.peerId)
        }
        self.fixture.transaction { transaction -> Void in
            for chat in world.chats() {
                transaction.addHole(peerId: chat.peerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
            }
        }
        self.launch()
    }

    // MARK: - Running

    func run(_ steps: [TruthStep]) {
        for step in steps {
            self.log.append(step.description)
            self.perform(step)
        }
    }

    private func perform(_ step: TruthStep) {
        switch step {
        case let .receive(chat):
            self.worldEvent { $0.receive(in: chat, from: nil, text: "m") }
        case let .sendFromOtherDevice(chat):
            self.worldEvent { $0.sendFromOtherDevice(in: chat, text: "out") }
        case let .edit(chat):
            self.worldEvent { world in
                let existing = world.existing(chat)
                guard !existing.isEmpty else {
                    return nil
                }
                let target = existing[Int(self.random.next() % UInt64(existing.count))]
                return world.edit(chat, target.id, text: "edited \(world.pts)")
            }
        case let .delete(chat, count):
            self.worldEvent { world in
                var existing = world.existing(chat)
                guard !existing.isEmpty else {
                    return nil
                }
                var ids: [Int32] = []
                while ids.count < count && !existing.isEmpty {
                    ids.append(existing.remove(at: Int(self.random.next() % UInt64(existing.count))).id)
                }
                return world.delete(chat, ids.sorted())
            }
        case let .clearHistory(chat):
            self.worldEvent { $0.clearHistory(chat) }
        case .goOffline:
            if self.isRunning {
                self.kill()
            }
        case .goOnline:
            if !self.isRunning {
                self.launch()
            }
        case .deliverPushes:
            self.deliverPushes()
        case .restartApp:
            if self.isRunning {
                self.kill()
            }
            self.launch()
        case let .openChat(chat):
            if self.isRunning {
                self.open(chat)
            }
        case let .openChatAt(chat):
            if self.isRunning {
                self.openAtRandomMessage(chat)
            }
        case let .scrollOlder(chat):
            if self.isRunning {
                self.scrollOlder(chat)
            }
        case .dropNextPush:
            self.pushFaults.append(.drop)
        case .duplicateNextPush:
            self.pushFaults.append(.duplicate)
        case .swapNextTwoPushes:
            self.pushFaults.append(.swap)
        case let .failNext(name, code, text):
            self.withWorld {
                self.failures[name, default: []].append((code, text))
            }
        case let .holdNextFill(chat):
            self.startHeldFill(chat, holding: "messages.getHistory")
        case let .holdNextConfirmation(chat):
            self.startHeldFill(chat, holding: "messages.getMessages")
        case .releaseHeld:
            self.releaseHeld()
        }
    }

    /// Starts a fill of `chat`'s newest hole whose next `name` request is held, and returns once that request is held
    /// or the fill ended without sending it (nothing to confirm, say).
    private func startHeldFill(_ chat: TruthPeer, holding name: String) {
        guard self.isRunning, self.heldFill == nil, let direction = self.newestHoleDirection(chat) else {
            return
        }
        self.withWorld {
            self.holdNext = name
        }
        let fill = fetchMessageHistoryHole(accountPeerId: StateSyncFixture.accountPeerId, source: .network(self.network), postbox: self.fixture.postbox, peerInput: .direct(peerId: chat.peerId, threadId: nil), namespace: Namespaces.Message.Cloud, direction: direction, space: .everywhere, count: 100)
        let recorder = self.fixture.observe(fill)
        self.heldFill = recorder
        let deadline = Date().addingTimeInterval(10.0)
        while Date() < deadline && !self.server.heldNames.contains(name) && recorder.values.isEmpty {
            Thread.sleep(forTimeInterval: 0.005)
        }
        self.withWorld {
            if self.holdNext == name {
                self.holdNext = nil
            }
        }
    }

    /// Answers the held request with what it was answered when it arrived and waits for its fill to end.
    private func releaseHeld() {
        guard let recorder = self.heldFill else {
            return
        }
        let held = self.withWorld { () -> (name: String, answer: ScriptedAnswer)? in
            let held = self.heldAnswer
            self.heldAnswer = nil
            return held
        }
        if let held {
            let _ = self.server.release(held.name, with: held.answer)
        }
        let _ = recorder.wait(timeout: 30.0, until: { !$0.isEmpty })
        self.heldFill = nil
        self.settle(after: "releaseHeld")
    }

    /// Applies a world event; while the app runs, its push waits for `deliverPushes`.
    private func worldEvent(_ f: (TruthWorld) -> TruthLogEntry?) {
        let pushed: (Api.Updates, Int64?, Int32)? = self.withWorld {
            guard let entry = f(self.world) else {
                return nil
            }
            return (truthPush(entry, world: self.world), entry.channelId, entry.pts)
        }
        if let pushed, self.isRunning {
            self.pendingPushes.append((pushed.0, pushed.1, pushed.2))
        }
    }

    private func deliverPushes() {
        guard self.isRunning else {
            return
        }
        let pushes = self.pendingPushes
        self.pendingPushes = []
        var faults = self.pushFaults
        self.pushFaults = []
        let send: ((updates: Api.Updates, channelId: Int64?, pts: Int32)) -> Void = { push in
            if let channelId = push.channelId {
                self.withWorld {
                    self.world.deliveredChannelPts[channelId] = max(self.world.deliveredChannelPts[channelId] ?? 0, push.pts)
                }
            }
            self.server.push(push.updates)
        }
        var index = 0
        while index < pushes.count {
            let fault = faults.isEmpty ? nil : faults.removeFirst()
            switch fault {
            case .drop:
                index += 1
            case .duplicate:
                send(pushes[index])
                send(pushes[index])
                index += 1
            case .swap where index + 1 < pushes.count:
                send(pushes[index + 1])
                send(pushes[index])
                index += 2
            default:
                send(pushes[index])
                index += 1
            }
        }
        self.settle(after: "deliverPushes")
    }

    /// The app is killed: its manager goes, and with it its update sink, so nothing reaches it until `launch`. A held
    /// request is answered first (a fill in flight is not left behind).
    private func kill() {
        self.releaseHeld()
        self.settle(after: "kill")
        self.server.dropUpdateSinks()
        self.fixture.releaseStateManager()
        self.pendingPushes = []
        self.isRunning = false
    }

    /// The app starts: a new manager, `reset()` (the launch getDifference), to rest; then the chat list on screen fills
    /// its first hole.
    private func launch() {
        let stateManager = self.fixture.makeStateManager(network: self.network)
        stateManager.reset()
        self.isRunning = true
        self.settle(after: "launch")
        self.fillChatListHoles(limit: 1)
    }

    /// Fills the root chat list's holes from the newest, as the chat list fills them while it is shown and scrolled
    /// (`ManagedChatListHoles`, `fetchChatListHole`): at most `limit` fills. False when a hole is left; a fill that
    /// produces nothing in `fillTimeout` seconds is no convergence.
    @discardableResult
    private func fillChatListHoles(limit: Int) -> Bool {
        for _ in 0 ..< limit {
            let hole = self.fixture.transaction { transaction -> ChatListHole? in
                return transaction.allChatListHoles(groupId: .root).max(by: { $0.index < $1.index })
            } ?? nil
            guard let hole else {
                return true
            }
            let fill = fetchChatListHole(postbox: self.fixture.postbox, network: self.network, accountPeerId: StateSyncFixture.accountPeerId, groupId: .root, hole: hole)
            if !self.waitForEnd(fill) {
                self.problems.append(TruthDiscrepancy(kind: .noConvergence, chat: nil, ids: [], note: "a chat-list fill of \(hole.index) produced nothing in \(self.fillTimeout) s"))
                return false
            }
            self.settle(after: "chat list fill")
        }
        return (self.fixture.transaction { transaction -> Bool in
            return transaction.allChatListHoles(groupId: .root).isEmpty
        }) ?? false
    }

    /// Waits for `signal`'s first value or its end, at most `fillTimeout` seconds; false when it timed out. Not
    /// `fixture.wait`, which fails the test outright: a stall is reported with the session's seed.
    private func waitForEnd<T>(_ signal: Signal<T, NoError>) -> Bool {
        let ended = DispatchSemaphore(value: 0)
        let disposable = (signal |> take(1)).start(next: { _ in
            ended.signal()
        }, completed: {
            ended.signal()
        })
        let timedOut = ended.wait(timeout: .now() + self.fillTimeout) == .timedOut
        disposable.dispose()
        return !timedOut
    }

    /// Opens `chat` at a random message the app has not loaded, as a reply or a search result opens it: the view asks
    /// an around-anchor fill (`.aroundId`). Nothing when every message is loaded.
    private func openAtRandomMessage(_ chat: TruthPeer) {
        let holes = self.fixture.holes(peerId: chat.peerId)
        let candidates = self.withWorld { self.world.existing(chat).map { $0.id } }.filter { holes.contains(Int($0)) }
        guard !candidates.isEmpty else {
            return
        }
        let target = candidates[Int(self.random.next() % UInt64(candidates.count))]
        self.fill(chat, direction: .aroundId(MessageId(peerId: chat.peerId, namespace: Namespaces.Message.Cloud, id: target)))
        self.settle(after: "open \(chat) at \(target)")
    }

    /// Scrolls `chat` up past its loaded messages: a fill of the highest hole below a loaded message, downward to 1,
    /// as a view asks for the hole below its anchor. Nothing when no hole is below a loaded message.
    private func scrollOlder(_ chat: TruthPeer) {
        let holes = self.fixture.holes(peerId: chat.peerId)
        guard let newestLoaded = self.storedIds(chat).max(), let hole = holes.rangeView.last(where: { $0.upperBound - 1 < Int(newestLoaded) }) else {
            return
        }
        let start = MessageId(peerId: chat.peerId, namespace: Namespaces.Message.Cloud, id: Int32(hole.upperBound - 1))
        self.fill(chat, direction: .range(start: start, end: MessageId(peerId: chat.peerId, namespace: Namespaces.Message.Cloud, id: 1)))
        self.settle(after: "scroll \(chat) older")
    }

    /// The ids of `chat`'s stored messages.
    private func storedIds(_ chat: TruthPeer) -> [Int32] {
        let peerId = chat.peerId
        return self.fixture.transaction { transaction -> [Int32] in
            var result: [Int32] = []
            transaction.withAllMessages(peerId: peerId, namespace: Namespaces.Message.Cloud, { message in
                result.append(message.id.id)
                return true
            })
            return result
        } ?? []
    }

    /// What opening a chat starts: a channel's first poll, and one fill of the chat's newest hole.
    private func open(_ chat: TruthPeer) {
        if case let .channel(channelId) = chat {
            self.pollChannel(channelId)
        }
        self.fillNewestHole(chat)
        self.settle(after: "open \(chat)")
    }

    /// One poll of an open channel (`pollChannelOnce`), to rest.
    private func pollChannel(_ channelId: Int64) {
        guard let stateManager = self.fixture.stateManager else {
            return
        }
        let _ = self.fixture.wait(pollChannelOnce(accountPeerId: StateSyncFixture.accountPeerId, postbox: self.fixture.postbox, network: self.network, peerId: TruthPeer.channel(channelId).peerId, stateManager: stateManager, delayCompletion: false), timeout: 30.0)
        self.settle(after: "poll channel\(channelId)")
    }

    /// Fills the newest hole of `chat` once, as a view at the newest end asks. False when the chat had none, and when
    /// the fill timed out (`fill`).
    @discardableResult
    private func fillNewestHole(_ chat: TruthPeer) -> Bool {
        guard let direction = self.newestHoleDirection(chat) else {
            return false
        }
        return self.fill(chat, direction: direction)
    }

    /// One history fill of `chat` in `direction`, to its end. False when it produced nothing in `fillTimeout` seconds:
    /// that is the session's finding, no convergence for the chat, and filling the chat again would wait out the same
    /// stall.
    @discardableResult
    private func fill(_ chat: TruthPeer, direction: MessageHistoryViewRelativeHoleDirection) -> Bool {
        let fill = fetchMessageHistoryHole(accountPeerId: StateSyncFixture.accountPeerId, source: .network(self.network), postbox: self.fixture.postbox, peerInput: .direct(peerId: chat.peerId, threadId: nil), namespace: Namespaces.Message.Cloud, direction: direction, space: .everywhere, count: 100)
        if !self.waitForEnd(fill) {
            self.problems.append(TruthDiscrepancy(kind: .noConvergence, chat: chat, ids: [], note: "a fill of \(direction) produced nothing in \(self.fillTimeout) s"))
            return false
        }
        return true
    }

    /// What a view at the newest end asks for the chat's newest hole: from its top down to 1, as
    /// `MessageHistoryViewState` asks for a hole below its anchor (`endId: 1`). A range that ends inside the history
    /// would lose its end id to the request's exclusive `min_id`/`max_id`; no view asks one.
    private func newestHoleDirection(_ chat: TruthPeer) -> MessageHistoryViewRelativeHoleDirection? {
        let peerId = chat.peerId
        guard let newest = self.fixture.holes(peerId: peerId).rangeView.last else {
            return nil
        }
        let start = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(newest.upperBound - 1))
        let end = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 1)
        return .range(start: start, end: end)
    }

    /// Waits until the app has nothing left to do: the operation queue drained and no request sent while it drained.
    private func settle(after what: String) {
        guard let stateManager = self.fixture.stateManager else {
            self.server.flush()
            return
        }
        for _ in 0 ..< 50 {
            let before = self.server.requests.count
            self.server.flush()
            let _ = self.fixture.wait(stateManager.addCustomOperation(Signal<Void, NoError>.single(Void())), timeout: 30.0)
            self.server.flush()
            if self.server.requests.count == before {
                return
            }
        }
        self.problems.append(TruthDiscrepancy(kind: .noConvergence, chat: nil, ids: [], note: "the app did not come to rest after \(what)"))
    }

    // MARK: - The oracle

    /// Brings the app to rest as a user who opens every chat would: running and relaunched once (a launch
    /// getDifference), every channel polled, every chat filled to no holes.
    func converge() {
        self.releaseHeld()
        if self.isRunning {
            self.deliverPushes()
            self.kill()
        }
        self.launch()
        // An open channel keeps polling (`keepPollingChannel`): a DEBUG build asks for 2 entries at a time, and the
        // rest of a difference that is not final comes with the next poll. Polled here until the app's channel pts is
        // the server's.
        for channelId in self.world.channels {
            let peerId = TruthPeer.channel(channelId).peerId
            var polls = 0
            while (self.fixture.channelState(peerId)?.pts ?? 0) < (self.withWorld { self.world.channelPts[channelId] ?? 0 }) {
                if polls >= 50 {
                    self.problems.append(TruthDiscrepancy(kind: .noConvergence, chat: .channel(channelId), ids: [], note: "channel pts \(self.fixture.channelState(peerId)?.pts ?? 0) behind the server's after 50 polls"))
                    break
                }
                self.pollChannel(channelId)
                polls += 1
            }
        }
        // The chat list scrolled to its end: a reset lists one page of dialogs, and the rest come with its holes' fills.
        if !self.fillChatListHoles(limit: 20) {
            self.problems.append(TruthDiscrepancy(kind: .noConvergence, chat: nil, ids: [], note: "chat-list holes left after 20 fills"))
        }
        for chat in self.world.chats() {
            var fills = 0
            while self.fillNewestHole(chat) {
                self.settle(after: "fill \(chat)")
                fills += 1
                if fills >= 50 {
                    self.problems.append(TruthDiscrepancy(kind: .noConvergence, chat: chat, ids: [], note: "holes left after 50 fills: \(self.fixture.holes(peerId: chat.peerId))"))
                    break
                }
            }
        }
        self.validateChannels()
        let unanswered = Set(self.server.unscripted.map { $0.name })
        for name in unanswered.sorted() {
            self.problems.append(TruthDiscrepancy(kind: .unanswered, chat: nil, ids: [], note: name))
        }
    }

    /// Runs the app's revalidation of each channel's stored posts, as an open chat runs it: `AccountViewTracker` feeds
    /// every history view of a channel, with the channel state as additional data, to `HistoryViewStateValidationContexts`
    /// on its queue, which asks the server about the posts below `invalidatedPts` and updates or deletes them. Each view
    /// holds 200 posts, the first the newest, each next one around the newest post still invalid, until no post in the
    /// channel is below `invalidatedPts`: at most 20 views of 2 s, past which the channel did not converge. Afterwards
    /// `compare` judges a post below `invalidatedPts` as it judges any other.
    func validateChannels() {
        let queue = Queue(name: "TruthSession.validation")
        let contexts = HistoryViewStateValidationContexts(queue: queue, postbox: self.fixture.postbox, network: self.network, accountPeerId: StateSyncFixture.accountPeerId)
        for (index, channelId) in self.world.channels.enumerated() {
            let peerId = TruthPeer.channel(channelId).peerId
            if self.invalidChannelPostIds(peerId).isEmpty {
                continue
            }
            let location = ChatLocationInput.peer(peerId: peerId, threadId: nil)
            let viewId = Int32(index + 1)
            // The chat opens at its newest posts; older ones are validated as it is scrolled to them: each next view is
            // anchored at the newest post still invalid.
            var anchor: HistoryViewInputAnchor = .upperBound
            var rounds = 0
            while true {
                let viewIds = Atomic<Set<Int32>>(value: Set())
                let disposable = self.fixture.postbox.aroundMessageHistoryViewForLocation(location, anchor: anchor, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), count: 200, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .not(Namespaces.Message.allNonRegular), orderStatistics: [], additionalData: [.peerChatState(peerId)]).start(next: { view, _, _ in
                    let _ = viewIds.swap(Set(view.entries.map { $0.message.id.id }))
                    queue.async {
                        contexts.updateView(id: viewId, view: view, location: location)
                    }
                })
                let deadline = Date().addingTimeInterval(2.0)
                while Date() < deadline {
                    self.server.flush()
                    let inView = viewIds.with { $0 }
                    if !inView.isEmpty && Set(self.invalidChannelPostIds(peerId)).isDisjoint(with: inView) {
                        break
                    }
                    Thread.sleep(forTimeInterval: 0.01)
                }
                disposable.dispose()
                queue.sync {
                    contexts.updateView(id: viewId, view: nil, location: location)
                }
                let invalid = self.invalidChannelPostIds(peerId)
                guard let newestInvalid = invalid.last else {
                    break
                }
                rounds += 1
                if rounds >= 20 {
                    self.problems.append(TruthDiscrepancy(kind: .noConvergence, chat: .channel(channelId), ids: invalid, note: "posts below invalidatedPts after 20 validation rounds"))
                    break
                }
                anchor = .message(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: newestInvalid))
            }
        }
        self.validationRan = true
    }

    /// The posts of the channel `peerId` that its revalidation would ask about: below the channel's `invalidatedPts`
    /// (`HistoryState.isMessageValid`), none when it has none.
    private func invalidChannelPostIds(_ peerId: PeerId) -> [Int32] {
        guard let invalidatedPts = self.fixture.channelState(peerId)?.invalidatedPts else {
            return []
        }
        return self.fixture.transaction { transaction -> [Int32] in
            var result: [Int32] = []
            transaction.withAllMessages(peerId: peerId, namespace: Namespaces.Message.Cloud, { message in
                let pts = message.attributes.compactMap({ $0 as? ChannelMessageStateVersionAttribute }).first?.pts
                if (pts ?? 0) < invalidatedPts {
                    result.append(message.id.id)
                }
                return true
            })
            return result.sorted()
        } ?? []
    }

    /// What a failing session prints, on one line so other threads' log lines cannot split it: its seed, what was
    /// found, its steps and every request with its arguments.
    func report(seed: UInt64, found: [TruthDiscrepancy], detailed: Bool = false) -> String {
        var parts = ["TRUTH failure seed=\(seed): \(found)", "steps: \(self.log.joined(separator: " | "))"]
        for request in self.server.requests {
            parts.append("#\(request.index) \(request.arguments)")
        }
        if detailed {
            // Each chat the oracle reported: the world's messages and logs, and what the app stores.
            for chat in Set(found.compactMap { $0.chat }).sorted(by: { $0.description < $1.description }) {
                let world = self.withWorld { () -> String in
                    let messages = self.world.existing(chat).map { "\($0.id)" }.joined(separator: ",")
                    let log: [TruthLogEntry]
                    if case let .channel(channelId) = chat {
                        log = self.world.channelLogs[channelId] ?? []
                    } else {
                        log = self.world.accountLog.filter { entry in
                            switch entry.event {
                            case let .newMessage(message), let .edit(message):
                                return message.chat == chat
                            case let .delete(deleted, _):
                                return deleted == chat
                            }
                        }
                    }
                    let entries = log.map { entry -> String in
                        switch entry.event {
                        case let .newMessage(message):
                            return "pts \(entry.pts) new \(message.id)"
                        case let .edit(message):
                            return "pts \(entry.pts) edit \(message.id)"
                        case let .delete(_, ids):
                            return "pts \(entry.pts) delete \(ids)"
                        }
                    }
                    return "world \(chat): messages [\(messages)] cleared top \(self.world.clearedTop[chat].map { "\($0.id)" } ?? "none") log: \(entries.joined(separator: "; "))"
                }
                parts.append(world)
                let stored = self.fixture.transaction { transaction -> String in
                    var ids: [Int32] = []
                    transaction.withAllMessages(peerId: chat.peerId, namespace: Namespaces.Message.Cloud, { message in
                        ids.append(message.id.id)
                        return true
                    })
                    return ids.sorted().map { "\($0)" }.joined(separator: ",")
                } ?? "?"
                parts.append("app \(chat): stored [\(stored)] holes \(self.fixture.holes(peerId: chat.peerId))")
            }
        }
        return parts.joined(separator: detailed ? "\n" : " ‖ ")
    }

    /// Every chat of the app against the world: missing, ghost (or validation-pending), stale. A cleared chat's
    /// tops (`TruthWorld.historyClearIds`, the history-cleared service messages the chat list shows) are not judged:
    /// whether the server also has them in history is not known (K1 showed one in the chat list only).
    func compare() -> [TruthDiscrepancy] {
        var result = self.problems
        for chat in self.world.chats() {
            let peerId = chat.peerId
            let stored = self.fixture.transaction { transaction -> [Int32: (text: String, pts: Int32?)] in
                var result: [Int32: (text: String, pts: Int32?)] = [:]
                transaction.withAllMessages(peerId: peerId, namespace: Namespaces.Message.Cloud, { message in
                    let pts = message.attributes.compactMap({ $0 as? ChannelMessageStateVersionAttribute }).first?.pts
                    result[message.id.id] = (message.text, pts)
                    return true
                })
                return result
            } ?? [:]
            let truth = self.withWorld { Dictionary(uniqueKeysWithValues: self.world.existing(chat).map { ($0.id, $0.text) }) }
            let missing = truth.keys.filter { stored[$0] == nil }.sorted()
            if !missing.isEmpty {
                result.append(TruthDiscrepancy(kind: .missing, chat: chat, ids: missing, note: ""))
            }
            let invalidatedPts = (self.fixture.channelState(peerId)?.invalidatedPts)
            var ghosts: [Int32] = []
            var pending: [Int32] = []
            let historyClearIds = self.withWorld { self.world.historyClearIds[chat] ?? [] }
            for (id, value) in stored where truth[id] == nil && !historyClearIds.contains(id) {
                if !self.validationRan, let invalidatedPts, (value.pts ?? 0) < invalidatedPts {
                    pending.append(id)
                } else {
                    ghosts.append(id)
                }
            }
            if !ghosts.isEmpty {
                result.append(TruthDiscrepancy(kind: .ghost, chat: chat, ids: ghosts.sorted(), note: ""))
            }
            var stale: [Int32] = []
            for id in truth.keys.sorted() {
                guard let value = stored[id], value.text != truth[id] else {
                    continue
                }
                if !self.validationRan, let invalidatedPts, (value.pts ?? 0) < invalidatedPts {
                    pending.append(id)
                } else {
                    stale.append(id)
                }
            }
            if !pending.isEmpty {
                result.append(TruthDiscrepancy(kind: .validationPending, chat: chat, ids: pending.sorted(), note: ""))
            }
            if !stale.isEmpty {
                result.append(TruthDiscrepancy(kind: .stale, chat: chat, ids: stale, note: ""))
            }
        }
        result.append(contentsOf: self.compareChatList())
        return result
    }

    /// The app's chat list against the server's: every chat the world lists is listed, its index the world's top
    /// message, and no other chat is listed by a message. A chat listed with no message (index id 0: a channel the
    /// account is in stays in the list with no posts) is not extra. A chat whose top is, or was, a history-cleared
    /// service message is not judged (`historyClearIds`: whether the server keeps that message is unknown).
    private func compareChatList() -> [TruthDiscrepancy] {
        var result: [TruthDiscrepancy] = []
        for chat in self.world.chats() {
            let (worldTop, cleared, clearIds) = self.withWorld { () -> (Int32?, Bool, Set<Int32>) in
                return (self.world.existing(chat).last?.id, self.world.clearedTop[chat] != nil, self.world.historyClearIds[chat] ?? [])
            }
            let appTop = self.fixture.transaction { transaction -> Int32? in
                return transaction.getPeerChatListIndex(chat.peerId)?.1.messageIndex.id.id
            } ?? nil
            if (worldTop == nil && cleared) || appTop.map({ clearIds.contains($0) }) == true {
                continue
            }
            switch (appTop, worldTop) {
            case (nil, .some):
                result.append(TruthDiscrepancy(kind: .unlisted, chat: chat, ids: [], note: ""))
            case let (.some(app), nil) where app != 0:
                result.append(TruthDiscrepancy(kind: .extraListed, chat: chat, ids: [app], note: ""))
            case let (.some(app), .some(world)) where app != world:
                result.append(TruthDiscrepancy(kind: .wrongTop, chat: chat, ids: [app, world], note: ""))
            default:
                break
            }
        }
        return result
    }
}

extension TruthLogEntry {
    /// The channel whose log holds the entry, nil for the account's.
    var channelId: Int64? {
        let chat: TruthPeer
        switch self.event {
        case let .newMessage(message), let .edit(message):
            chat = message.chat
        case let .delete(deleted, _):
            chat = deleted
        }
        if case let .channel(id) = chat {
            return id
        }
        return nil
    }
}

/// The push the server sends the running app for `entry`: `updateShortMessage` / `updateShortChatMessage` for a new
/// private-chat or basic-group message, `updates` with the update otherwise (seq 0: no seq to check).
func truthPush(_ entry: TruthLogEntry, world: TruthWorld) -> Api.Updates {
    switch entry.event {
    case let .newMessage(message):
        switch message.chat {
        case let .user(userId):
            let flags: Int32 = message.outgoing ? (1 << 1) : 0
            return .updateShortMessage(.init(flags: flags, id: message.id, userId: userId, message: message.text, pts: entry.pts, ptsCount: entry.ptsCount, date: message.date, fwdFrom: nil, viaBotId: nil, replyTo: nil, entities: nil, ttlPeriod: nil))
        case let .chat(chatId):
            let flags: Int32 = message.outgoing ? (1 << 1) : 0
            return .updateShortChatMessage(.init(flags: flags, id: message.id, fromId: message.fromUserId ?? TruthWorld.accountId, chatId: chatId, message: message.text, pts: entry.pts, ptsCount: entry.ptsCount, date: message.date, fwdFrom: nil, viaBotId: nil, replyTo: nil, entities: nil, ttlPeriod: nil))
        case .channel:
            return StateSyncApi.updates([StateSyncApi.updateNewChannelMessage(TruthApi.message(message), pts: entry.pts, ptsCount: entry.ptsCount)], users: TruthApi.users(world), chats: TruthApi.chats(world), date: message.date, seq: 0)
        case .selfUser:
            preconditionFailure()
        }
    case let .edit(message):
        let update: Api.Update
        if message.chat.isChannel {
            update = .updateEditChannelMessage(.init(message: TruthApi.message(message), pts: entry.pts, ptsCount: entry.ptsCount))
        } else {
            update = .updateEditMessage(.init(message: TruthApi.message(message), pts: entry.pts, ptsCount: entry.ptsCount))
        }
        return StateSyncApi.updates([update], users: TruthApi.users(world), chats: TruthApi.chats(world), date: world.date, seq: 0)
    case let .delete(chat, ids):
        if case let .channel(channelId) = chat {
            return StateSyncApi.updates([StateSyncApi.updateDeleteChannelMessages(channelId: channelId, messages: ids, pts: entry.pts, ptsCount: entry.ptsCount)], users: TruthApi.users(world), chats: TruthApi.chats(world), date: world.date, seq: 0)
        }
        return StateSyncApi.updateShort(.updateDeleteMessages(.init(messages: ids, pts: entry.pts, ptsCount: entry.ptsCount)), date: world.date)
    }
}
