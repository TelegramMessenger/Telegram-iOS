struct PeerId: Hashable {
    struct Id: Hashable {
        var value: Int64
        static func _internalFromInt64Value(_ value: Int64) -> Id { Id(value: value) }
    }
    var namespace: Int32
    var id: Id
}

enum Namespaces {
    enum Peer { static let CloudUser: Int32 = 0 }
}

struct Peer { var id: PeerId }

func peerId(_ value: Int64) -> PeerId {
    PeerId(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(value))
}

func apiInputUser(_ peer: Peer) -> Api.InputUser? { .user(peer.id.id.value) }

struct TelegramBusinessRecipients: Equatable {
    var additionalPeers: Set<PeerId> = []
    var excludePeers: Set<PeerId> = []
    init() {}
    init(apiValue: TelegramBusinessRecipients) { self = apiValue }
    func apiInputBotValue(additionalPeers: [Peer], excludePeers: [Peer]) -> Api.InputBusinessBotRecipients {
        .inputBusinessBotRecipients(.init(flags: 0, users: additionalPeers.compactMap(apiInputUser), excludeUsers: excludePeers.compactMap(apiInputUser)))
    }
}

struct TelegramAccountConnectedBot: Equatable {
    var id: PeerId
    var recipients: TelegramBusinessRecipients
    var rights: TelegramBusinessBotRights
    var device: String? = nil
    var date: Int32? = nil
    var location: String? = nil
}

enum Api {
    enum InputUser: Equatable { case user(Int64) }
    enum BusinessBotRights {
        struct Cons_businessBotRights { var flags: Int32 }
        case businessBotRights(Cons_businessBotRights)
        var flags: Int32 { switch self { case let .businessBotRights(data): return data.flags } }
    }
    enum InputBusinessBotRecipients {
        struct Data { var flags: Int32; var users: [InputUser]?; var excludeUsers: [InputUser]? }
        case inputBusinessBotRecipients(Data)
    }
    enum ConnectedBot {
        struct Data {
            var botId: Int64
            var recipients: TelegramBusinessRecipients
            var rights: BusinessBotRights
            var device: String?
            var date: Int32?
            var location: String?
        }
        case connectedBot(Data)
    }
    enum Updates: Equatable { case applied, securityWarning }
    enum account {
        enum ConnectedBots {
            struct Data { var connectedBots: [ConnectedBot]; var users: [Peer] }
            case connectedBots(Data)
        }
    }
    enum functions {
        enum account {
            static func getConnectedBots() -> Request<Api.account.ConnectedBots> { Request(update: nil) }
            static func updateConnectedBot(flags: Int32, rights: BusinessBotRights?, bot: InputUser, recipients: InputBusinessBotRecipients) -> Request<Updates> {
                Request(update: UpdateRequest(flags: flags, rights: rights, bot: bot))
            }
        }
    }
}

struct UpdateRequest { var flags: Int32; var rights: Api.BusinessBotRights?; var bot: Api.InputUser }
struct Request<T> { var update: UpdateRequest? }
struct RpcError { var errorDescription: String }

final class Pending<T> {
    var subscriber: Subscriber<T, RpcError>?
    var signal: Signal<T, RpcError> {
        Signal { subscriber in
            self.subscriber = subscriber
            return EmptyDisposable
        }
    }
    func succeed(_ value: T) { subscriber?.putNext(value); subscriber?.putCompletion() }
    func fail(_ text: String) { subscriber?.putError(RpcError(errorDescription: text)) }
}

final class Network {
    var updates: [(UpdateRequest, Pending<Api.Updates>)] = []
    var reads: [Pending<Api.account.ConnectedBots>] = []
    func request<T>(_ request: Request<T>) -> Signal<T, RpcError> {
        if let update = request.update {
            let pending = Pending<Api.Updates>()
            updates.append((update, pending))
            return pending.signal as! Signal<T, RpcError>
        }
        let pending = Pending<Api.account.ConnectedBots>()
        reads.append(pending)
        return pending.signal as! Signal<T, RpcError>
    }
}

final class CachedUserData {
    var connectedBot: TelegramAccountConnectedBot?
    init(_ bot: TelegramAccountConnectedBot? = nil) { connectedBot = bot }
    func withUpdatedConnectedBot(_ bot: TelegramAccountConnectedBot?) -> CachedUserData { CachedUserData(bot) }
}

final class Transaction {
    var cache = CachedUserData()
    var peers: [PeerId: Peer] = [:]
    var cacheWrites = 0
    func getPeer(_ id: PeerId) -> Peer? { peers[id] }
    func getPeerCachedData(peerId: PeerId) -> Any? { cache }
    func updatePeerCachedData(peerIds: Set<PeerId>, update: (PeerId, Any?) -> CachedUserData) {
        cache = update(peerIds.first!, cache)
        cacheWrites += 1
    }
}

struct AccumulatedPeers { var users: [Peer] }
func updatePeers(transaction: Transaction, accountPeerId: PeerId, peers: AccumulatedPeers) {
    for peer in peers.users { transaction.peers[peer.id] = peer }
}

final class Postbox {
    let storage = Transaction()
    func transaction<T>(_ body: @escaping (Transaction) -> T) -> Signal<T, NoError> {
        Signal { subscriber in
            subscriber.putNext(body(self.storage))
            subscriber.putCompletion()
            return EmptyDisposable
        }
    }
}

final class StateManager {
    var updates: [Api.Updates] = []
    func addUpdates(_ value: Api.Updates) { updates.append(value) }
}

final class Account {
    let peerId = PeerId(namespace: 0, id: ._internalFromInt64Value(1))
    let network = Network()
    let postbox = Postbox()
    let stateManager = StateManager()
}

final class BusinessBotSyncTests: XCTestCase {
    var account: Account!
    var disposable: Disposable?
    var values: [TelegramAccountConnectedBot?] = []
    var errors: [String] = []
    var completed = false
    let basicRights: TelegramBusinessBotRights = [.reply, .viewGifts]

    override func setUp() {
        account = Account()
        account.postbox.storage.peers[peerId(2)] = Peer(id: peerId(2))
    }
    override func tearDown() { disposable?.dispose() }
    func bot(_ rights: TelegramBusinessBotRights) -> TelegramAccountConnectedBot {
        TelegramAccountConnectedBot(id: peerId(2), recipients: TelegramBusinessRecipients(), rights: rights)
    }
    func response(_ bot: TelegramAccountConnectedBot?) -> Api.account.ConnectedBots {
        .connectedBots(.init(connectedBots: bot.map { bot in
            [.connectedBot(.init(botId: bot.id.id.value, recipients: bot.recipients, rights: .businessBotRights(.init(flags: bot.rights.rawValue)), device: bot.device, date: bot.date, location: bot.location))]
        } ?? [], users: bot.map { [Peer(id: $0.id)] } ?? []))
    }
    func observe(_ signal: Signal<TelegramAccountConnectedBot?, AccountConnectedBotError>) {
        disposable = signal.start(next: { self.values.append($0) }, error: {
            switch $0 {
            case .generic: self.errors.append("generic")
            case let .server(text): self.errors.append(text)
            }
        }, completed: { self.completed = true })
    }

    func testSuccessfulSaveWaitsForReadbackAndPreservesServerMetadata() {
        let requested = bot(basicRights)
        observe(_internal_updateAccountConnectedBot(account: account, bot: requested))
        XCTAssertEqual(account.postbox.storage.cacheWrites, 0)
        XCTAssertTrue(account.network.reads.isEmpty)
        XCTAssertEqual(account.network.updates[0].0.rights?.flags, basicRights.rawValue)
        account.network.updates[0].1.succeed(.applied)
        XCTAssertTrue(values.isEmpty)
        XCTAssertFalse(completed)
        XCTAssertEqual(account.postbox.storage.cacheWrites, 0)
        var saved = requested
        saved.device = "Mac"
        saved.date = 123
        saved.location = "Tashkent"
        account.network.reads[0].succeed(response(saved))
        XCTAssertEqual(values, [saved])
        XCTAssertEqual(account.postbox.storage.cache.connectedBot, saved)
        XCTAssertEqual(account.stateManager.updates, [.applied])
        XCTAssertTrue(completed)
    }

    func testSecurityWarningRestoresServerRightsForEachRestrictedPermission() {
        for right: TelegramBusinessBotRights in [.sellGifts, .changeGiftSettings, .transferAndUpgradeGifts, .transferStars] {
            account = Account()
            account.postbox.storage.peers[peerId(2)] = Peer(id: peerId(2))
            let saved = bot(basicRights)
            account.postbox.storage.cache = CachedUserData(saved)
            let requested = bot(basicRights.union(right))
            observe(_internal_updateAccountConnectedBot(account: account, bot: requested))
            XCTAssertEqual(account.postbox.storage.cache.connectedBot, saved)
            account.network.updates[0].1.succeed(.securityWarning)
            XCTAssertEqual(account.stateManager.updates, [.securityWarning])
            account.network.reads[0].succeed(response(saved))
            XCTAssertEqual(values.last!, saved)
            XCTAssertEqual(account.postbox.storage.cache.connectedBot, saved)
            XCTAssertNotEqual(values.last!, requested)
            disposable?.dispose()
        }
    }

    func testRejectedConnectionReturnsNoBot() {
        observe(_internal_updateAccountConnectedBot(account: account, bot: bot([.transferStars])))
        account.network.updates[0].1.succeed(.securityWarning)
        account.network.reads[0].succeed(response(nil))
        XCTAssertEqual(values.count, 1)
        XCTAssertNil(values[0])
        XCTAssertNil(account.postbox.storage.cache.connectedBot)
    }

    func testOpeningFetchReplacesStaleCacheAndUpdatesPeer() {
        account.postbox.storage.cache = CachedUserData(bot(.All))
        account.postbox.storage.peers = [:]
        observe(_internal_requestAccountConnectedBot(account: account))
        let saved = bot(basicRights)
        account.network.reads[0].succeed(response(saved))
        XCTAssertEqual(values, [saved])
        XCTAssertEqual(account.postbox.storage.cache.connectedBot, saved)
        XCTAssertNotNil(account.postbox.storage.peers[saved.id])
    }

    func testOpeningFetchClearsDisconnectedBot() {
        account.postbox.storage.cache = CachedUserData(bot(.All))
        observe(_internal_requestAccountConnectedBot(account: account))
        account.network.reads[0].succeed(response(nil))
        XCTAssertNil(account.postbox.storage.cache.connectedBot)
        XCTAssertEqual(values.count, 1)
    }

    func testReadFailureDoesNotReplaceCacheWithRequestedRights() {
        let saved = bot(basicRights)
        account.postbox.storage.cache = CachedUserData(saved)
        observe(_internal_updateAccountConnectedBot(account: account, bot: bot(.All)))
        account.network.updates[0].1.succeed(.applied)
        account.network.reads[0].fail("NETWORK_ERROR")
        XCTAssertEqual(account.postbox.storage.cache.connectedBot, saved)
        XCTAssertEqual(account.postbox.storage.cacheWrites, 0)
        XCTAssertTrue(values.isEmpty)
        XCTAssertEqual(errors, ["NETWORK_ERROR"])
        XCTAssertFalse(completed)
    }

    func testRpcFailureRefreshesCacheAndPropagatesOriginalError() {
        account.postbox.storage.cache = CachedUserData(bot(.All))
        observe(_internal_updateAccountConnectedBot(account: account, bot: bot([.transferStars])))
        account.network.updates[0].1.fail("FRESH_CHANGE_FORBIDDEN")
        XCTAssertTrue(errors.isEmpty)
        let saved = bot(basicRights)
        account.network.reads[0].succeed(response(saved))
        XCTAssertEqual(account.postbox.storage.cache.connectedBot, saved)
        XCTAssertEqual(errors, ["FRESH_CHANGE_FORBIDDEN"])
        XCTAssertTrue(values.isEmpty)
        XCTAssertTrue(account.stateManager.updates.isEmpty)
    }

    func testRpcAndRefreshFailurePreserveCacheAndOriginalError() {
        let saved = bot(basicRights)
        account.postbox.storage.cache = CachedUserData(saved)
        observe(_internal_updateAccountConnectedBot(account: account, bot: bot(.All)))
        account.network.updates[0].1.fail("FRESH_CHANGE_FORBIDDEN")
        account.network.reads[0].fail("NETWORK_ERROR")
        XCTAssertEqual(account.postbox.storage.cache.connectedBot, saved)
        XCTAssertEqual(account.postbox.storage.cacheWrites, 0)
        XCTAssertEqual(errors, ["FRESH_CHANGE_FORBIDDEN"])
    }

    func testDisconnectSendsExistingBotAndWaitsForServer() {
        let saved = bot(basicRights)
        account.postbox.storage.cache = CachedUserData(saved)
        observe(_internal_updateAccountConnectedBot(account: account, bot: nil))
        XCTAssertEqual(account.network.updates[0].0.bot, .user(2))
        XCTAssertEqual(account.network.updates[0].0.flags, 2)
        XCTAssertNil(account.network.updates[0].0.rights)
        XCTAssertEqual(account.postbox.storage.cache.connectedBot, saved)
        account.network.updates[0].1.succeed(.applied)
        account.network.reads[0].succeed(response(nil))
        XCTAssertNil(account.postbox.storage.cache.connectedBot)
        XCTAssertEqual(values.count, 1)
    }

    func testMissingSelectedPeerDoesNotSendDelete() {
        account.postbox.storage.peers = [:]
        observe(_internal_updateAccountConnectedBot(account: account, bot: bot(basicRights)))
        XCTAssertTrue(account.network.updates.isEmpty)
        XCTAssertEqual(errors, ["generic"])
    }
}
