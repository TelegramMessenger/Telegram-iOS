import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif
import TelegramCorePrivateModule

public protocol AccountState: Coding {
    func equalsTo(_ other: AccountState) -> Bool
}

public func ==(lhs: AccountState, rhs: AccountState) -> Bool {
    return lhs.equalsTo(rhs)
}

public class AuthorizedAccountState: AccountState {
    public final class State: Coding, Equatable, CustomStringConvertible {
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
        
        public init(decoder: Decoder) {
            self.pts = decoder.decodeInt32ForKey("pts")
            self.qts = decoder.decodeInt32ForKey("qts")
            self.date = decoder.decodeInt32ForKey("date")
            self.seq = decoder.decodeInt32ForKey("seq")
        }
        
        public func encode(_ encoder: Encoder) {
            encoder.encodeInt32(self.pts, forKey: "pts")
            encoder.encodeInt32(self.qts, forKey: "qts")
            encoder.encodeInt32(self.date, forKey: "date")
            encoder.encodeInt32(self.seq, forKey: "seq")
        }
        
        public var description: String {
            return "(pts: \(pts), qts: \(qts), seq: \(seq), date: \(date))"
        }
    }
    
    let masterDatacenterId: Int32
    let peerId: PeerId
    
    let state: State?
    
    public required init(decoder: Decoder) {
        self.masterDatacenterId = decoder.decodeInt32ForKey("masterDatacenterId")
        self.peerId = PeerId(decoder.decodeInt64ForKey("peerId"))
        self.state = decoder.decodeObjectForKey("state", decoder: { return State(decoder: $0) }) as? State
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.masterDatacenterId, forKey: "masterDatacenterId")
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "peerId")
        if let state = self.state {
            encoder.encodeObject(state, forKey: "state")
        }
    }
    
    public init(masterDatacenterId: Int32, peerId: PeerId, state: State?) {
        self.masterDatacenterId = masterDatacenterId
        self.peerId = peerId
        self.state = state
    }
    
    func changedState(_ state: State) -> AuthorizedAccountState {
        return AuthorizedAccountState(masterDatacenterId: self.masterDatacenterId, peerId: self.peerId, state: state)
    }
    
    public func equalsTo(_ other: AccountState) -> Bool {
        if let other = other as? AuthorizedAccountState {
            return self.masterDatacenterId == other.masterDatacenterId &&
                self.peerId == other.peerId &&
                self.state == other.state
        } else {
            return false
        }
    }
}

public func ==(lhs: AuthorizedAccountState.State, rhs: AuthorizedAccountState.State) -> Bool {
    return lhs.pts == rhs.pts &&
        lhs.qts == rhs.qts &&
        lhs.date == rhs.date &&
        lhs.seq == rhs.seq
}

public class UnauthorizedAccount {
    public let id: AccountRecordId
    public let appGroupPath: String
    public let basePath: String
    public let testingEnvironment: Bool
    public let postbox: Postbox
    public let network: Network
    
    public var masterDatacenterId: Int32 {
        return Int32(self.network.mtProto.datacenterId)
    }
    
    public let shouldBeServiceTaskMaster = Promise<AccountServiceTaskMasterMode>()
    
    init(id: AccountRecordId, appGroupPath: String, basePath: String, testingEnvironment: Bool, postbox: Postbox, network: Network, shouldKeepAutoConnection: Bool = true) {
        self.id = id
        self.appGroupPath = appGroupPath
        self.basePath = basePath
        self.testingEnvironment = testingEnvironment
        self.postbox = postbox
        self.network = network
        
        network.shouldKeepConnection.set(self.shouldBeServiceTaskMaster.get() |> map { mode -> Bool in
            switch mode {
                case .now, .always:
                    return true
                case .never:
                    return false
            }
        })
    }
    
    public func changedMasterDatacenterId(_ masterDatacenterId: Int32) -> Signal<UnauthorizedAccount, NoError> {
        if masterDatacenterId == Int32(self.network.mtProto.datacenterId) {
            return .single(self)
        } else {
            let postbox = self.postbox
            let keychain = Keychain(get: { key in
                return postbox.keychainEntryForKey(key)
            }, set: { (key, data) in
                postbox.setKeychainEntryForKey(key, value: data)
            }, remove: { key in
                postbox.removeKeychainEntryForKey(key)
            })
            
            return initializedNetwork(datacenterId: Int(masterDatacenterId), keychain: keychain, networkUsageInfoPath: accountNetworkUsageInfoPath(basePath: self.basePath), testingEnvironment: self.testingEnvironment)
                |> map { network in
                    let updated = UnauthorizedAccount(id: self.id, appGroupPath: self.appGroupPath, basePath: self.basePath, testingEnvironment: self.testingEnvironment, postbox: self.postbox, network: network)
                    updated.shouldBeServiceTaskMaster.set(self.shouldBeServiceTaskMaster.get())
                    return updated
                }
        }
    }
}

private var declaredEncodables: Void = {
    declareEncodable(UnauthorizedAccountState.self, f: { UnauthorizedAccountState(decoder: $0) })
    declareEncodable(AuthorizedAccountState.self, f: { AuthorizedAccountState(decoder: $0) })
    declareEncodable(TelegramUser.self, f: { TelegramUser(decoder: $0) })
    declareEncodable(TelegramGroup.self, f: { TelegramGroup(decoder: $0) })
    declareEncodable(TelegramChannel.self, f: { TelegramChannel(decoder: $0) })
    declareEncodable(TelegramMediaImage.self, f: { TelegramMediaImage(decoder: $0) })
    declareEncodable(TelegramMediaImageRepresentation.self, f: { TelegramMediaImageRepresentation(decoder: $0) })
    declareEncodable(TelegramMediaContact.self, f: { TelegramMediaContact(decoder: $0) })
    declareEncodable(TelegramMediaMap.self, f: { TelegramMediaMap(decoder: $0) })
    declareEncodable(TelegramMediaFile.self, f: { TelegramMediaFile(decoder: $0) })
    declareEncodable(TelegramMediaFileAttribute.self, f: { TelegramMediaFileAttribute(decoder: $0) })
    declareEncodable(CloudFileMediaResource.self, f: { CloudFileMediaResource(decoder: $0) })
    declareEncodable(ChannelState.self, f: { ChannelState(decoder: $0) })
    declareEncodable(InlineBotMessageAttribute.self, f: { InlineBotMessageAttribute(decoder: $0) })
    declareEncodable(TextEntitiesMessageAttribute.self, f: { TextEntitiesMessageAttribute(decoder: $0) })
    declareEncodable(ReplyMessageAttribute.self, f: { ReplyMessageAttribute(decoder: $0) })
    declareEncodable(CloudDocumentMediaResource.self, f: { CloudDocumentMediaResource(decoder: $0) })
    declareEncodable(TelegramMediaWebpage.self, f: { TelegramMediaWebpage(decoder: $0) })
    declareEncodable(ViewCountMessageAttribute.self, f: { ViewCountMessageAttribute(decoder: $0) })
    declareEncodable(TelegramMediaAction.self, f: { TelegramMediaAction(decoder: $0) })
    declareEncodable(TelegramPeerNotificationSettings.self, f: { TelegramPeerNotificationSettings(decoder: $0) })
    declareEncodable(CachedUserData.self, f: { CachedUserData(decoder: $0) })
    declareEncodable(BotInfo.self, f: { BotInfo(decoder: $0) })
    declareEncodable(CachedGroupData.self, f: { CachedGroupData(decoder: $0) })
    declareEncodable(CachedChannelData.self, f: { CachedChannelData(decoder: $0) })
    declareEncodable(TelegramUserPresence.self, f: { TelegramUserPresence(decoder: $0) })
    declareEncodable(LocalFileMediaResource.self, f: { LocalFileMediaResource(decoder: $0) })
    declareEncodable(PhotoLibraryMediaResource.self, f: { PhotoLibraryMediaResource(decoder: $0) })
    declareEncodable(StickerPackCollectionInfo.self, f: { StickerPackCollectionInfo(decoder: $0) })
    declareEncodable(StickerPackItem.self, f: { StickerPackItem(decoder: $0) })
    declareEncodable(LocalFileReferenceMediaResource.self, f: { LocalFileReferenceMediaResource(decoder: $0) })
    declareEncodable(OutgoingMessageInfoAttribute.self, f: { OutgoingMessageInfoAttribute(decoder: $0) })
    declareEncodable(ForwardSourceInfoAttribute.self, f: { ForwardSourceInfoAttribute(decoder: $0) })
    declareEncodable(EditedMessageAttribute.self, f: { EditedMessageAttribute(decoder: $0) })
    declareEncodable(ReplyMarkupMessageAttribute.self, f: { ReplyMarkupMessageAttribute(decoder: $0) })
    declareEncodable(CachedResolvedByNamePeer.self, f: { CachedResolvedByNamePeer(decoder: $0) })
    declareEncodable(OutgoingChatContextResultMessageAttribute.self, f: { OutgoingChatContextResultMessageAttribute(decoder: $0) })
    declareEncodable(HttpReferenceMediaResource.self, f: { HttpReferenceMediaResource(decoder: $0) })
    declareEncodable(EmptyMediaResource.self, f: { EmptyMediaResource(decoder: $0) })
    declareEncodable(TelegramSecretChat.self, f: { TelegramSecretChat(decoder: $0) })
    declareEncodable(SecretChatState.self, f: { SecretChatState(decoder: $0) })
    declareEncodable(SecretChatIncomingEncryptedOperation.self, f: { SecretChatIncomingEncryptedOperation(decoder: $0) })
    declareEncodable(SecretChatIncomingDecryptedOperation.self, f: { SecretChatIncomingDecryptedOperation(decoder: $0) })
    declareEncodable(SecretChatOutgoingOperation.self, f: { SecretChatOutgoingOperation(decoder: $0) })
    declareEncodable(SecretFileMediaResource.self, f: { SecretFileMediaResource(decoder: $0) })
    declareEncodable(CloudChatRemoveMessagesOperation.self, f: { CloudChatRemoveMessagesOperation(decoder: $0) })
    declareEncodable(AutoremoveTimeoutMessageAttribute.self, f: { AutoremoveTimeoutMessageAttribute(decoder: $0) })
    declareEncodable(GlobalNotificationSettings.self, f: { GlobalNotificationSettings(decoder: $0) })
    declareEncodable(CloudChatRemoveChatOperation.self, f: { CloudChatRemoveChatOperation(decoder: $0) })
    declareEncodable(SynchronizePinnedChatsOperation.self, f: { SynchronizePinnedChatsOperation(decoder: $0) })
    declareEncodable(RecentMediaItem.self, f: { RecentMediaItem(decoder: $0) })
    declareEncodable(RecentPeerItem.self, f: { RecentPeerItem(decoder: $0) })
    declareEncodable(LoggedOutAccountAttribute.self, f: { LoggedOutAccountAttribute(decoder: $0) })
    declareEncodable(CloudChatClearHistoryOperation.self, f: { CloudChatClearHistoryOperation(decoder: $0) })
    declareEncodable(OutgoingContentInfoMessageAttribute.self, f: { OutgoingContentInfoMessageAttribute(decoder: $0) })
    declareEncodable(ConsumableContentMessageAttribute.self, f: { ConsumableContentMessageAttribute(decoder: $0) })
    
    return
}()

func accountNetworkUsageInfoPath(basePath: String) -> String {
    return basePath + "/network-usage"
}

private func accountRecordIdPathName(_ id: AccountRecordId) -> String {
    return "account-\(UInt64(bitPattern: id.int64))"
}

public func accountWithId(_ id: AccountRecordId, appGroupPath: String, testingEnvironment: Bool, shouldKeepAutoConnection: Bool = true) -> Signal<Either<UnauthorizedAccount, Account>, NoError> {
    return Signal<(String, Postbox, Coding?), NoError> { subscriber in
        let _ = declaredEncodables
        
        let path = "\(appGroupPath)/\(accountRecordIdPathName(id))"
        
        var initializeMessageNamespacesWithHoles: [(PeerId.Namespace, MessageId.Namespace)] = []
        for peerNamespace in peerIdNamespacesWithInitialCloudMessageHoles {
            initializeMessageNamespacesWithHoles.append((peerNamespace, Namespaces.Message.Cloud))
        }
        
        let seedConfiguration = SeedConfiguration(initializeChatListWithHoles: [ChatListHole(index: MessageIndex(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.Empty, id: 0), namespace: Namespaces.Message.Cloud, id: 1), timestamp: 1))], initializeMessageNamespacesWithHoles: initializeMessageNamespacesWithHoles, existingMessageTags: allMessageTags)
        
        let postbox = Postbox(basePath: path + "/postbox", globalMessageIdsNamespace: Namespaces.Message.Cloud, seedConfiguration: seedConfiguration)
        
        return (postbox.stateView() |> take(1) |> map { view -> (String, Postbox, Coding?) in
            let accountState = view.state
            return (path, postbox, accountState)
        }).start(next: { args in
            subscriber.putNext(args)
            subscriber.putCompletion()
        })
    } |> mapToSignal { (basePath, postbox, accountState) -> Signal<Either<UnauthorizedAccount, Account>, NoError> in
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
                    return initializedNetwork(datacenterId: Int(unauthorizedState.masterDatacenterId), keychain: keychain, networkUsageInfoPath: accountNetworkUsageInfoPath(basePath: basePath), testingEnvironment: testingEnvironment)
                        |> map { network -> Either<UnauthorizedAccount, Account> in
                            .left(value: UnauthorizedAccount(id: id, appGroupPath: appGroupPath, basePath: basePath, testingEnvironment: testingEnvironment, postbox: postbox, network: network, shouldKeepAutoConnection: shouldKeepAutoConnection))
                        }
                case let authorizedState as AuthorizedAccountState:
                    return initializedNetwork(datacenterId: Int(authorizedState.masterDatacenterId), keychain: keychain, networkUsageInfoPath: accountNetworkUsageInfoPath(basePath: basePath), testingEnvironment: testingEnvironment)
                        |> map { network -> Either<UnauthorizedAccount, Account> in
                            return .right(value: Account(id: id, basePath: basePath, testingEnvironment: testingEnvironment, postbox: postbox, network: network, peerId: authorizedState.peerId))
                        }
                case _:
                    assertionFailure("Unexpected accountState \(accountState)")
            }
        }
        
        return initializedNetwork(datacenterId: 2, keychain: keychain, networkUsageInfoPath: accountNetworkUsageInfoPath(basePath: basePath), testingEnvironment: testingEnvironment)
            |> map { network -> Either<UnauthorizedAccount, Account> in
                return .left(value: UnauthorizedAccount(id: id, appGroupPath: appGroupPath, basePath: basePath, testingEnvironment: testingEnvironment, postbox: postbox, network: network, shouldKeepAutoConnection: shouldKeepAutoConnection))
        }
    }
}

public struct TwoStepAuthData {
    let nextSalt: Data
    let currentSalt: Data?
    let hasRecovery: Bool
    let currentHint: String?
    let unconfirmedEmailPattern: String?
}

public func twoStepAuthData(_ network: Network) -> Signal<TwoStepAuthData, MTRpcError> {
    return network.request(Api.functions.account.getPassword())
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

public func verifyPassword(_ account: UnauthorizedAccount, password: String) -> Signal<Api.auth.Authorization, MTRpcError> {
    return twoStepAuthData(account.network)
    |> mapToSignal { authData -> Signal<Api.auth.Authorization, MTRpcError> in
        var data = Data()
        data.append(authData.currentSalt!)
        data.append(password.data(using: .utf8, allowLossyConversion: true)!)
        data.append(authData.currentSalt!)
        let currentPasswordHash = sha256(data)
        
        return account.network.request(Api.functions.auth.checkPassword(passwordHash: Buffer(data: currentPasswordHash)), automaticFloodWait: false)
    }
}

public enum AccountServiceTaskMasterMode {
    case now
    case always
    case never
}

public enum AccountNetworkState {
    case waitingForNetwork
    case connecting
    case updating
    case online
}

public class Account {
    public let id: AccountRecordId
    public let basePath: String
    public let testingEnvironment: Bool
    public let postbox: Postbox
    public let network: Network
    public let peerId: PeerId
    
    private let serviceQueue = Queue()
    
    public private(set) var stateManager: AccountStateManager!
    public private(set) var viewTracker: AccountViewTracker!
    public private(set) var pendingMessageManager: PendingMessageManager!
    private var peerInputActivityManager: PeerInputActivityManager!
    private var localInputActivityManager: PeerInputActivityManager!
    fileprivate let managedContactsDisposable = MetaDisposable()
    fileprivate let managedStickerPacksDisposable = MetaDisposable()
    private let becomeMasterDisposable = MetaDisposable()
    private let updatedPresenceDisposable = MetaDisposable()
    private let managedServiceViewsDisposable = MetaDisposable()
    private let managedOperationsDisposable = DisposableSet()
    
    public let graphicsThreadPool = ThreadPool(threadCount: 3, threadPriority: 0.1)
    
    public var applicationContext: Any?
    
    public let settings: AccountSettings = defaultAccountSettings()
    
    public let notificationToken = Promise<Data>()
    public let voipToken = Promise<Data>()
    private let notificationTokenDisposable = MetaDisposable()
    private let voipTokenDisposable = MetaDisposable()
    
    public let shouldBeServiceTaskMaster = Promise<AccountServiceTaskMasterMode>()
    public let shouldKeepOnlinePresence = Promise<Bool>()
    
    private let networkStateValue = Promise<AccountNetworkState>(.connecting)
    public var networkState: Signal<AccountNetworkState, NoError> {
        return self.networkStateValue.get()
    }
    
    private let _loggedOut = ValuePromise<Bool>(false, ignoreRepeated: true)
    public var loggedOut: Signal<Bool, NoError> {
        return self._loggedOut.get()
    }
    
    var transformOutgoingMessageMedia: TransformOutgoingMessageMedia?
    
    public init(id: AccountRecordId, basePath: String, testingEnvironment: Bool, postbox: Postbox, network: Network, peerId: PeerId) {
        self.id = id
        self.basePath = basePath
        self.testingEnvironment = testingEnvironment
        self.postbox = postbox
        self.network = network
        self.peerId = peerId
        
        self.peerInputActivityManager = PeerInputActivityManager()
        self.stateManager = AccountStateManager(account: self, peerInputActivityManager: self.peerInputActivityManager)
        self.localInputActivityManager = PeerInputActivityManager()
        self.viewTracker = AccountViewTracker(account: self)
        self.pendingMessageManager = PendingMessageManager(network: network, postbox: postbox, stateManager: self.stateManager)
        
        self.network.loggedOut = { [weak self] in
            self?._loggedOut.set(true)
        }
        
        let networkStateSignal = combineLatest(self.stateManager.isUpdating, network.connectionStatus)
            |> map { isUpdating, connectionStatus -> AccountNetworkState in
                switch connectionStatus {
                    case .WaitingForNetwork:
                        return .waitingForNetwork
                    case .Connecting:
                        return .connecting
                    case .Updating:
                        return .updating
                    case .Online:
                        if isUpdating {
                            return .updating
                        } else {
                            return .online
                        }
                }
            }
        self.networkStateValue.set(networkStateSignal |> distinctUntilChanged)
        
        let appliedNotificationToken = self.notificationToken.get()
            |> distinctUntilChanged
            |> mapToSignal { token -> Signal<Void, NoError> in                
                var tokenString = ""
                token.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                    for i in 0 ..< token.count {
                        let byte = bytes.advanced(by: i).pointee
                        tokenString = tokenString.appendingFormat("%02x", Int32(byte))
                    }
                }
                
                let appVersionString = "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? ""))"
                
                #if os(macOS)
                    let pInfo = ProcessInfo.processInfo
                    let systemVersion = pInfo.operatingSystemVersionString
                #else
                    let systemVersion = UIDevice.current.systemVersion
                #endif
                
                var appSandbox: Api.Bool = .boolFalse
                #if DEBUG
                    appSandbox = .boolTrue
                #endif
                
                return network.request(Api.functions.account.registerDevice(tokenType: 1, token: tokenString, deviceModel: "iPhone Simulator", systemVersion: systemVersion, appVersion: appVersionString, appSandbox: appSandbox))
                    |> retryRequest
                    |> mapToSignal { _ -> Signal<Void, NoError> in
                        return .complete()
                    }
            }
        self.notificationTokenDisposable.set(appliedNotificationToken.start())
        
        let appliedVoipToken = self.voipToken.get()
            |> distinctUntilChanged
            |> mapToSignal { token -> Signal<Void, NoError> in
                var tokenString = ""
                token.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                    for i in 0 ..< token.count {
                        let byte = bytes.advanced(by: i).pointee
                        tokenString = tokenString.appendingFormat("%02x", Int32(byte))
                    }
                }
                
                let appVersionString = "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? ""))"
                
                #if os(macOS)
                    let pInfo = ProcessInfo.processInfo
                    let systemVersion = pInfo.operatingSystemVersionString
                #else
                    let systemVersion = UIDevice.current.systemVersion
                #endif
                
                var appSandbox: Api.Bool = .boolFalse
                #if DEBUG
                    appSandbox = .boolTrue
                #endif
                
                return network.request(Api.functions.account.registerDevice(tokenType: 9, token: tokenString, deviceModel: "iPhone Simulator", systemVersion: systemVersion, appVersion: appVersionString, appSandbox: appSandbox))
                    |> retryRequest
                    |> mapToSignal { _ -> Signal<Void, NoError> in
                        return .complete()
                    }
            }
        self.voipTokenDisposable.set(appliedVoipToken.start())
        
        let serviceTasksMasterBecomeMaster = shouldBeServiceTaskMaster.get()
            |> distinctUntilChanged
            |> deliverOn(self.serviceQueue)
        
        self.becomeMasterDisposable.set(serviceTasksMasterBecomeMaster.start(next: { [weak self] value in
            if let strongSelf = self, (value == .now || value == .always) {
                strongSelf.postbox.becomeMasterClient()
            }
        }))
        
        let shouldBeMaster = combineLatest(shouldBeServiceTaskMaster.get(), postbox.isMasterClient())
            |> map { [weak self] shouldBeMaster, isMaster -> Bool in
                if shouldBeMaster == .always && !isMaster {
                    self?.postbox.becomeMasterClient()
                }
                return (shouldBeMaster == .now || shouldBeMaster == .always) && isMaster
            }
            |> distinctUntilChanged
        
        self.network.shouldKeepConnection.set(shouldBeMaster)
        
        let serviceTasksMaster = shouldBeMaster
            |> deliverOn(self.serviceQueue)
            |> mapToSignal { [weak self] value -> Signal<Void, NoError> in
                if let strongSelf = self, value {
                    Logger.shared.log("Account", "Became master")
                    return managedServiceViews(network: strongSelf.network, postbox: strongSelf.postbox, stateManager: strongSelf.stateManager, pendingMessageManager: strongSelf.pendingMessageManager)
                } else {
                    Logger.shared.log("Account", "Resigned master")
                    return .never()
                }
            }
        self.managedServiceViewsDisposable.set(serviceTasksMaster.start())
        
        self.managedOperationsDisposable.add(managedSecretChatOutgoingOperations(postbox: self.postbox, network: self.network).start())
        self.managedOperationsDisposable.add(managedCloudChatRemoveMessagesOperations(postbox: self.postbox, network: self.network, stateManager: self.stateManager).start())
        self.managedOperationsDisposable.add(managedAutoremoveMessageOperations(postbox: self.postbox).start())
        self.managedOperationsDisposable.add(managedGlobalNotificationSettings(postbox: self.postbox, network: self.network).start())
        self.managedOperationsDisposable.add(managedSynchronizePinnedChatsOperations(postbox: self.postbox, network: self.network, stateManager: self.stateManager).start())
        self.managedOperationsDisposable.add(managedRecentStickers(postbox: self.postbox, network: self.network).start())
        self.managedOperationsDisposable.add(managedRecentGifs(postbox: self.postbox, network: self.network).start())
        self.managedOperationsDisposable.add(managedRecentlyUsedInlineBots(postbox: self.postbox, network: self.network).start())
        self.managedOperationsDisposable.add(managedLocalTypingActivities(activities: self.localInputActivityManager.allActivities(), postbox: self.postbox, network: self.network).start())
        
        let updatedPresence = self.shouldKeepOnlinePresence.get()
            |> distinctUntilChanged
            |> mapToSignal { [weak self] online -> Signal<Void, NoError> in
                if let strongSelf = self {
                    if online {
                        let delayRequest: Signal<Void, NoError> = .complete() |> delay(60.0, queue: Queue.concurrentDefaultQueue())
                        let pushStatusOnce = strongSelf.network.request(Api.functions.account.updateStatus(offline: .boolFalse))
                            |> retryRequest
                            |> mapToSignal { _ -> Signal<Void, NoError> in return .complete() }
                        let pushStatusRepeatedly = (pushStatusOnce |> then(delayRequest)) |> restart
                        let peerId = strongSelf.peerId
                        let updatePresenceLocally = strongSelf.postbox.modify { modifier -> Void in
                            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970 + 60.0 * 60.0 * 24.0 * 356.0
                            modifier.updatePeerPresences([peerId: TelegramUserPresence(status: .present(until: Int32(timestamp)))])
                        }
                        return combineLatest(pushStatusRepeatedly, updatePresenceLocally)
                            |> mapToSignal { _ -> Signal<Void, NoError> in return .complete() }
                    } else {
                        let pushStatusOnce = strongSelf.network.request(Api.functions.account.updateStatus(offline: .boolTrue))
                            |> retryRequest
                            |> mapToSignal { _ -> Signal<Void, NoError> in return .complete() }
                        let peerId = strongSelf.peerId
                        let updatePresenceLocally = strongSelf.postbox.modify { modifier -> Void in
                            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970 - 1.0
                            modifier.updatePeerPresences([peerId: TelegramUserPresence(status: .present(until: Int32(timestamp)))])
                        }
                        return combineLatest(pushStatusOnce, updatePresenceLocally)
                            |> mapToSignal { _ -> Signal<Void, NoError> in return .complete() }
                    }
                } else {
                    return .complete()
                }
            }
        self.updatedPresenceDisposable.set(updatedPresence.start())
    }
    
    deinit {
        self.managedContactsDisposable.dispose()
        self.managedStickerPacksDisposable.dispose()
        self.notificationTokenDisposable.dispose()
        self.voipTokenDisposable.dispose()
        self.managedServiceViewsDisposable.dispose()
        self.updatedPresenceDisposable.dispose()
        self.managedOperationsDisposable.dispose()
    }
    
    /*public func currentNetworkStats() -> Signal<MTNetworkUsageManagerStats, NoError> {
        return Signal { subscriber in
            let manager = MTNetworkUsageManager(info: MTNetworkUsageCalculationInfo(filePath: accountNetworkUsageInfoPath(basePath: self.basePath)))!
            manager.currentStats().start(next: { next in
                if let stats = next as? MTNetworkUsageManagerStats {
                    subscriber.putNext(stats)
                }
                subscriber.putCompletion()
            }, error: nil, completed: nil)
            
            return EmptyDisposable
        }
    }*/
    
    public func peerInputActivities(peerId: PeerId) -> Signal<[(PeerId, PeerInputActivity)], NoError> {
        return self.peerInputActivityManager.activities(peerId: peerId)
    }
    
    public func updateLocalInputActivity(peerId: PeerId, activity: PeerInputActivity, isPresent: Bool) {
        self.localInputActivityManager.transaction { manager in
            if isPresent {
                manager.addActivity(chatPeerId: peerId, peerId: self.peerId, activity: activity)
            } else {
                manager.removeActivity(chatPeerId: peerId, peerId: self.peerId, activity: activity)
            }
        }
    }
}

public typealias FetchCachedResourceRepresentation = (_ account: Account, _ resource: MediaResource, _ resourceData: MediaResourceData, _ representation: CachedMediaResourceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError>
public typealias TransformOutgoingMessageMedia = (_ postbox: Postbox, _ network: Network, _ media: Media, _ userInteractive: Bool) -> Signal<Media?, NoError>

public func setupAccount(_ account: Account, fetchCachedResourceRepresentation: FetchCachedResourceRepresentation? = nil, transformOutgoingMessageMedia: TransformOutgoingMessageMedia? = nil) {
    account.postbox.mediaBox.fetchResource = { [weak account] resource, range -> Signal<MediaResourceDataFetchResult, NoError> in
        if let strongAccount = account {
            return fetchResource(account: strongAccount, resource: resource, range: range)
        } else {
            return .never()
        }
    }
    
    account.postbox.mediaBox.fetchCachedResourceRepresentation = { [weak account] resource, resourceData, representation in
        if let strongAccount = account, let fetchCachedResourceRepresentation = fetchCachedResourceRepresentation {
            return fetchCachedResourceRepresentation(strongAccount, resource, resourceData, representation)
        } else {
            return .never()
        }
    }
    
    account.transformOutgoingMessageMedia = transformOutgoingMessageMedia
    account.pendingMessageManager.transformOutgoingMessageMedia = transformOutgoingMessageMedia
    
    account.managedContactsDisposable.set(manageContacts(network: account.network, postbox: account.postbox).start())
    account.managedStickerPacksDisposable.set(manageStickerPacks(network: account.network, postbox: account.postbox).start())
    
    /*account.network.request(Api.functions.help.getScheme(version: 0)).start(next: { result in
        if case let .scheme(text, _, _, _) = result {
            print("\(text)")
        }
    })*/
}
