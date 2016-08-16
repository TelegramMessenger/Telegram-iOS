import Foundation
import SwiftSignalKit
import Postbox
import MtProtoKit
import Display
import TelegramCorePrivate

struct AccountId {
    let stringValue: String
}

class AccountState: Coding, Equatable {
    required init(decoder: Decoder) {
    }
    
    func encode(_ encoder: Encoder) {
    }
    
    private init() {
    }
    
    private func equalsTo(_ other: AccountState) -> Bool {
        return false
    }
}

func ==(lhs: AccountState, rhs: AccountState) -> Bool {
    return lhs.equalsTo(rhs)
}

final class UnauthorizedAccountState: AccountState {
    let masterDatacenterId: Int32
    
    required init(decoder: Decoder) {
        self.masterDatacenterId = decoder.decodeInt32ForKey("masterDatacenterId")
        super.init()
    }
    
    override func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.masterDatacenterId, forKey: "masterDatacenterId")
    }
    
    init(masterDatacenterId: Int32) {
        self.masterDatacenterId = masterDatacenterId
        super.init()
    }
    
    override func equalsTo(_ other: AccountState) -> Bool {
        if let other = other as? UnauthorizedAccountState {
            return self.masterDatacenterId == other.masterDatacenterId
        } else {
            return false
        }
    }
}

class AuthorizedAccountState: AccountState {
    final class State: Coding, Equatable, CustomStringConvertible {
        let pts: Int32
        let qts: Int32
        let date: Int32
        let seq: Int32
        
        init(pts: Int32, qts: Int32, date: Int32, seq: Int32) {
            self.pts = pts
            self.qts = qts
            self.date = date
            self.seq = seq
        }
        
        init(decoder: Decoder) {
            self.pts = decoder.decodeInt32ForKey("pts")
            self.qts = decoder.decodeInt32ForKey("qts")
            self.date = decoder.decodeInt32ForKey("date")
            self.seq = decoder.decodeInt32ForKey("seq")
        }
        
        func encode(_ encoder: Encoder) {
            encoder.encodeInt32(self.pts, forKey: "pts")
            encoder.encodeInt32(self.qts, forKey: "qts")
            encoder.encodeInt32(self.date, forKey: "date")
            encoder.encodeInt32(self.seq, forKey: "seq")
        }
        
        var description: String {
            return "(pts: \(pts), qts: \(qts), seq: \(seq), date: \(date))"
        }
    }
    
    let masterDatacenterId: Int32
    let peerId: PeerId
    
    let state: State?
    
    required init(decoder: Decoder) {
        self.masterDatacenterId = decoder.decodeInt32ForKey("masterDatacenterId")
        self.peerId = PeerId(decoder.decodeInt64ForKey("peerId"))
        self.state = decoder.decodeObjectForKey("state", decoder: { return State(decoder: $0) }) as? State
        
        super.init()
    }
    
    override func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.masterDatacenterId, forKey: "masterDatacenterId")
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "peerId")
        if let state = self.state {
            encoder.encodeObject(state, forKey: "state")
        }
    }
    
    init(masterDatacenterId: Int32, peerId: PeerId, state: State?) {
        self.masterDatacenterId = masterDatacenterId
        self.peerId = peerId
        self.state = state
        
        super.init()
    }
    
    func changedState(_ state: State) -> AuthorizedAccountState {
        return AuthorizedAccountState(masterDatacenterId: self.masterDatacenterId, peerId: self.peerId, state: state)
    }
    
    override func equalsTo(_ other: AccountState) -> Bool {
        if let other = other as? AuthorizedAccountState {
            return self.masterDatacenterId == other.masterDatacenterId &&
                self.peerId == other.peerId &&
                self.state == other.state
        } else {
            return false
        }
    }
}

func ==(lhs: AuthorizedAccountState.State, rhs: AuthorizedAccountState.State) -> Bool {
    return lhs.pts == rhs.pts &&
        lhs.qts == rhs.qts &&
        lhs.date == rhs.date &&
        lhs.seq == rhs.seq
}

func currentAccountId() -> AccountId {
    let key = "Telegram_currentAccountId"
    if let id = UserDefaults.standard.object(forKey: key) as? String {
        return AccountId(stringValue: id)
    } else {
        let id = generateAccountId()
        UserDefaults.standard.set(id.stringValue, forKey: key)
        return id
    }
}

func generateAccountId() -> AccountId {
    return AccountId(stringValue: NSUUID().uuidString)
}

class UnauthorizedAccount {
    let id: AccountId
    let postbox: Postbox
    let network: Network
    
    var masterDatacenterId: Int32 {
        return Int32(self.network.mtProto.datacenterId)
    }
    
    init(id: AccountId, postbox: Postbox, network: Network) {
        self.id = id
        self.postbox = postbox
        self.network = network
    }
    
    func changedMasterDatacenterId(_ masterDatacenterId: Int32) -> UnauthorizedAccount {
        if masterDatacenterId == Int32(self.network.mtProto.datacenterId) {
            return self
        } else {
            let postbox = self.postbox
            let keychain = Keychain(get: { key in
                return postbox.keychainEntryForKey(key)
                }, set: { (key, data) in
                    postbox.setKeychainEntryForKey(key, value: data)
                }, remove: { key in
                    postbox.removeKeychainEntryForKey(key)
            })
            
            return UnauthorizedAccount(id: self.id, postbox: self.postbox, network: Network(datacenterId: Int(masterDatacenterId), keychain: keychain))
        }
    }
}

func accountWithId(_ id: AccountId) -> Signal<Either<UnauthorizedAccount, Account>, NoError> {
    return Signal<(Postbox, AccountState?), NoError> { subscriber in
        declareEncodable(UnauthorizedAccountState.self, f: { UnauthorizedAccountState(decoder: $0) })
        declareEncodable(AuthorizedAccountState.self, f: { AuthorizedAccountState(decoder: $0) })
        declareEncodable(TelegramUser.self, f: { TelegramUser(decoder: $0) })
        declareEncodable(TelegramGroup.self, f: { TelegramGroup(decoder: $0) })
        declareEncodable(TelegramMediaImage.self, f: { TelegramMediaImage(decoder: $0) })
        declareEncodable(TelegramMediaImageRepresentation.self, f: { TelegramMediaImageRepresentation(decoder: $0) })
        declareEncodable(TelegramMediaVoiceNote.self, f: { TelegramMediaVoiceNote(decoder: $0) })
        declareEncodable(TelegramMediaContact.self, f: { TelegramMediaContact(decoder: $0) })
        declareEncodable(TelegramMediaMap.self, f: { TelegramMediaMap(decoder: $0) })
        declareEncodable(TelegramMediaFile.self, f: { TelegramMediaFile(decoder: $0) })
        declareEncodable(TelegramMediaFileAttribute.self, f: { TelegramMediaFileAttribute(decoder: $0) })
        declareEncodable(TelegramCloudFileLocation.self, f: { TelegramCloudFileLocation(decoder: $0) })
        declareEncodable(ChannelState.self, f: { ChannelState(decoder: $0) })
        declareEncodable(InlineBotMessageAttribute.self, f: { InlineBotMessageAttribute(decoder: $0) })
        declareEncodable(TextEntitiesMessageAttribute.self, f: { TextEntitiesMessageAttribute(decoder: $0) })
        declareEncodable(ReplyMessageAttribute.self, f: { ReplyMessageAttribute(decoder: $0) })
        declareEncodable(TelegramCloudDocumentLocation.self, f: { TelegramCloudDocumentLocation(decoder: $0) })
        declareEncodable(TelegramMediaWebpage.self, f: { TelegramMediaWebpage(decoder: $0) })
        declareEncodable(ViewCountMessageAttribute.self, f: { ViewCountMessageAttribute(decoder: $0) })
        declareEncodable(TelegramMediaAction.self, f: { TelegramMediaAction(decoder: $0) })
        declareEncodable(StreamingResource.self, f: { StreamingResource(decoder: $0) })
        
        let path = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String) + "/\(id.stringValue)"
        
        let seedConfiguration = SeedConfiguration(initializeChatListWithHoles: [ChatListHole(index: MessageIndex(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.Empty, id: 0), namespace: Namespaces.Message.Cloud, id: 1), timestamp: 1))], initializeMessageNamespacesWithHoles: [Namespaces.Message.Cloud], existingMessageTags: [.PhotoOrVideo])
        
        let postbox = Postbox(basePath: path + "/postbox", globalMessageIdsNamespace: Namespaces.Message.Cloud, seedConfiguration: seedConfiguration)
        return (postbox.state() |> take(1) |> map { accountState in
            return (postbox, accountState as? AccountState)
        }).start(next: { pair in
            subscriber.putNext(pair)
            subscriber.putCompletion()
        })
    } |> map { (postbox, accountState) in
        let keychain = Keychain(get: { key in
            return postbox.keychainEntryForKey(key)
        }, set: { (key, data) in
            postbox.setKeychainEntryForKey(key, value: data)
        }, remove: { key in
            postbox.removeKeychainEntryForKey(key)
        })
        
        if let accountState = accountState {
            switch accountState {
                case let unauthorizedState as UnauthorizedAccountState:
                    return .left(value: UnauthorizedAccount(id: id, postbox: postbox, network: Network(datacenterId: Int(unauthorizedState.masterDatacenterId), keychain: keychain)))
                case let authorizedState as AuthorizedAccountState:
                    return .right(value: Account(id: id, postbox: postbox, network: Network(datacenterId: Int(authorizedState.masterDatacenterId), keychain: keychain), peerId: authorizedState.peerId))
                case _:
                    assertionFailure("Unexpected accountState \(accountState)")
            }
        }
        
        return .left(value: UnauthorizedAccount(id: id, postbox: postbox, network: Network(datacenterId: 2, keychain: keychain)))
    }
}

struct TwoStepAuthData {
    let nextSalt: Data
    let currentSalt: Data?
    let hasRecovery: Bool
    let currentHint: String?
    let unconfirmedEmailPattern: String?
}

func twoStepAuthData(_ network: Network) -> Signal<TwoStepAuthData, MTRpcError> {
    return network.request(Api.functions.account.getPassword(), dependsOnPasswordEntry: false)
    |> map { config -> TwoStepAuthData in
        switch config {
            case let .noPassword(newSalt, emailUnconfirmedPattern):
                return TwoStepAuthData(nextSalt: newSalt.makeData(), currentSalt: nil, hasRecovery: false, currentHint: nil, unconfirmedEmailPattern: emailUnconfirmedPattern)
            case let .password(currentSalt, newSalt, hint, hasRecovery, emailUnconfirmedPattern):
                return TwoStepAuthData(nextSalt: newSalt.makeData(), currentSalt: currentSalt.makeData(), hasRecovery: hasRecovery == .boolTrue, currentHint: hint, unconfirmedEmailPattern: emailUnconfirmedPattern)
        }
    }
}

private func sha256(_ data : Data) -> Data {
    var res = Data()
    res.count = Int(CC_SHA256_DIGEST_LENGTH)
    res.withUnsafeMutableBytes { mutableBytes -> Void in
        data.withUnsafeBytes { bytes -> Void in
            CC_SHA256(bytes, CC_LONG(data.count), mutableBytes)
        }
    }
    return res
}

func verifyPassword(_ account: UnauthorizedAccount, password: String) -> Signal<Api.auth.Authorization, MTRpcError> {
    return twoStepAuthData(account.network)
    |> mapToSignal { authData -> Signal<Api.auth.Authorization, MTRpcError> in
        var data = Data()
        data.append(authData.currentSalt!)
        data.append(password.data(using: .utf8, allowLossyConversion: true)!)
        data.append(authData.currentSalt!)
        let currentPasswordHash = sha256(data)
        
        return account.network.request(Api.functions.auth.checkPassword(passwordHash: Buffer(data: currentPasswordHash)), dependsOnPasswordEntry: false)
    }
}

class Account {
    let id: AccountId
    let postbox: Postbox
    let network: Network
    let peerId: PeerId
    
    private(set) var stateManager: StateManager!
    private(set) var viewTracker: AccountViewTracker!
    private let managedContactsDisposable = MetaDisposable()
    
    let graphicsThreadPool = ThreadPool(threadCount: 3, threadPriority: 0.1)
    //let imageCache: ImageCache = ImageCache(maxResidentSize: 5 * 1024 * 1024)
    
    let settings: AccountSettings = defaultAccountSettings()
    
    var player: AnyObject?
    
    init(id: AccountId, postbox: Postbox, network: Network, peerId: PeerId) {
        self.id = id
        self.postbox = postbox
        self.network = network
        self.peerId = peerId
        
        self.stateManager = StateManager(account: self)
        self.viewTracker = AccountViewTracker(account: self)
    }
    
    deinit {
        self.managedContactsDisposable.dispose()
    }
}

func setupAccount(_ account: Account) {
    account.postbox.setFetchMessageHistoryHole { [weak account] hole, direction, tagMask in
        if let strongAccount = account {
            return fetchMessageHistoryHole(strongAccount, hole: hole, direction: direction, tagMask: tagMask)
        } else {
            return never(Void.self, NoError.self)
        }
    }
    account.postbox.setFetchChatListHole { [weak account] hole in
        if let strongAccount = account {
            return fetchChatListHole(strongAccount, hole: hole)
        } else {
            return never(Void.self, NoError.self)
        }
    }
    
    account.postbox.setSendUnsentMessage { [weak account] message in
        if let strongAccount = account {
            return sendUnsentMessage(account: strongAccount, message: message)
        } else {
            return never(Void.self, NoError.self)
        }
    }
    
    account.postbox.setSynchronizePeerReadState { [weak account] peerId, operation -> Signal<Void, NoError> in
        if let strongAccount = account {
            switch operation {
                case .Validate:
                    return synchronizePeerReadState(account: strongAccount, peerId: peerId, push: false, validate: true)
                case let .Push(thenSync):
                    return synchronizePeerReadState(account: strongAccount, peerId: peerId, push: true, validate: thenSync)
            }
        } else {
            return .never()
        }
    }
    
    account.postbox.mediaBox.fetchResource = { [weak account] resource, range -> Signal<Data, NoError> in
        if let strongAccount = account {
            return fetchResource(account: strongAccount, resource: resource, range: range)
        } else {
            return .never()
        }
    }
    
    account.managedContactsDisposable.set(manageContacts(network: account.network, postbox: account.postbox).start())
}
