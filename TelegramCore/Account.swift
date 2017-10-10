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

public protocol AccountState: PostboxCoding {
    func equalsTo(_ other: AccountState) -> Bool
}

public func ==(lhs: AccountState, rhs: AccountState) -> Bool {
    return lhs.equalsTo(rhs)
}

public class AuthorizedAccountState: AccountState {
    public final class State: PostboxCoding, Equatable, CustomStringConvertible {
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
        
        public init(decoder: PostboxDecoder) {
            self.pts = decoder.decodeInt32ForKey("pts", orElse: 0)
            self.qts = decoder.decodeInt32ForKey("qts", orElse: 0)
            self.date = decoder.decodeInt32ForKey("date", orElse: 0)
            self.seq = decoder.decodeInt32ForKey("seq", orElse: 0)
        }
        
        public func encode(_ encoder: PostboxEncoder) {
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
    
    public required init(decoder: PostboxDecoder) {
        self.masterDatacenterId = decoder.decodeInt32ForKey("masterDatacenterId", orElse: 0)
        self.peerId = PeerId(decoder.decodeInt64ForKey("peerId", orElse: 0))
        self.state = decoder.decodeObjectForKey("state", decoder: { return State(decoder: $0) }) as? State
    }
    
    public func encode(_ encoder: PostboxEncoder) {
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
    public let networkArguments: NetworkInitializationArguments
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
    
    init(networkArguments: NetworkInitializationArguments, id: AccountRecordId, appGroupPath: String, basePath: String, testingEnvironment: Bool, postbox: Postbox, network: Network, shouldKeepAutoConnection: Bool = true) {
        self.networkArguments = networkArguments
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
            
            return self.postbox.modify { modifier -> (LocalizationSettings?, ProxySettings?) in
                return (modifier.getPreferencesEntry(key: PreferencesKeys.localizationSettings) as? LocalizationSettings, modifier.getPreferencesEntry(key: PreferencesKeys.proxySettings) as? ProxySettings)
            } |> mapToSignal { (localizationSettings, proxySettings) -> Signal<UnauthorizedAccount, NoError> in
                return initializedNetwork(arguments: self.networkArguments, supplementary: false, datacenterId: Int(masterDatacenterId), keychain: keychain, basePath: self.basePath, testingEnvironment: self.testingEnvironment, languageCode: localizationSettings?.languageCode, proxySettings: proxySettings)
                |> map { network in
                    let updated = UnauthorizedAccount(networkArguments: self.networkArguments, id: self.id, appGroupPath: self.appGroupPath, basePath: self.basePath, testingEnvironment: self.testingEnvironment, postbox: self.postbox, network: network)
                    updated.shouldBeServiceTaskMaster.set(self.shouldBeServiceTaskMaster.get())
                    return updated
                }
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
    declareEncodable(RegularChatState.self, f: { RegularChatState(decoder: $0) })
    declareEncodable(InlineBotMessageAttribute.self, f: { InlineBotMessageAttribute(decoder: $0) })
    declareEncodable(TextEntitiesMessageAttribute.self, f: { TextEntitiesMessageAttribute(decoder: $0) })
    declareEncodable(ReplyMessageAttribute.self, f: { ReplyMessageAttribute(decoder: $0) })
    declareEncodable(CloudDocumentMediaResource.self, f: { CloudDocumentMediaResource(decoder: $0) })
    declareEncodable(TelegramMediaWebpage.self, f: { TelegramMediaWebpage(decoder: $0) })
    declareEncodable(ViewCountMessageAttribute.self, f: { ViewCountMessageAttribute(decoder: $0) })
    declareEncodable(NotificationInfoMessageAttribute.self, f: { NotificationInfoMessageAttribute(decoder: $0) })
    declareEncodable(TelegramMediaAction.self, f: { TelegramMediaAction(decoder: $0) })
    declareEncodable(TelegramPeerNotificationSettings.self, f: { TelegramPeerNotificationSettings(decoder: $0) })
    declareEncodable(CachedUserData.self, f: { CachedUserData(decoder: $0) })
    declareEncodable(BotInfo.self, f: { BotInfo(decoder: $0) })
    declareEncodable(CachedGroupData.self, f: { CachedGroupData(decoder: $0) })
    declareEncodable(CachedChannelData.self, f: { CachedChannelData(decoder: $0) })
    declareEncodable(TelegramUserPresence.self, f: { TelegramUserPresence(decoder: $0) })
    declareEncodable(LocalFileMediaResource.self, f: { LocalFileMediaResource(decoder: $0) })
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
    declareEncodable(WebFileReferenceMediaResource.self, f: { WebFileReferenceMediaResource(decoder: $0) })
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
    declareEncodable(SynchronizeConsumeMessageContentsOperation.self, f: { SynchronizeConsumeMessageContentsOperation(decoder: $0) })
    declareEncodable(RecentMediaItem.self, f: { RecentMediaItem(decoder: $0) })
    declareEncodable(RecentPeerItem.self, f: { RecentPeerItem(decoder: $0) })
    declareEncodable(RecentHashtagItem.self, f: { RecentHashtagItem(decoder: $0) })
    declareEncodable(LoggedOutAccountAttribute.self, f: { LoggedOutAccountAttribute(decoder: $0) })
    declareEncodable(CloudChatClearHistoryOperation.self, f: { CloudChatClearHistoryOperation(decoder: $0) })
    declareEncodable(OutgoingContentInfoMessageAttribute.self, f: { OutgoingContentInfoMessageAttribute(decoder: $0) })
    declareEncodable(ConsumableContentMessageAttribute.self, f: { ConsumableContentMessageAttribute(decoder: $0) })
    declareEncodable(TelegramMediaGame.self, f: { TelegramMediaGame(decoder: $0) })
    declareEncodable(TelegramMediaInvoice.self, f: { TelegramMediaInvoice(decoder: $0) })
    declareEncodable(TelegramMediaWebFile.self, f: { TelegramMediaWebFile(decoder: $0) })
    declareEncodable(SynchronizeInstalledStickerPacksOperation.self, f: { SynchronizeInstalledStickerPacksOperation(decoder: $0) })
    declareEncodable(FeaturedStickerPackItem.self, f: { FeaturedStickerPackItem(decoder: $0) })
    declareEncodable(SynchronizeMarkFeaturedStickerPacksAsSeenOperation.self, f: { SynchronizeMarkFeaturedStickerPacksAsSeenOperation(decoder: $0) })
    declareEncodable(ArchivedStickerPacksInfo.self, f: { ArchivedStickerPacksInfo(decoder: $0) })
    declareEncodable(SynchronizeChatInputStateOperation.self, f: { SynchronizeChatInputStateOperation(decoder: $0) })
    declareEncodable(SynchronizeSavedGifsOperation.self, f: { SynchronizeSavedGifsOperation(decoder: $0) })
    declareEncodable(SynchronizeSavedStickersOperation.self, f: { SynchronizeSavedStickersOperation(decoder: $0) })
    declareEncodable(CacheStorageSettings.self, f: { CacheStorageSettings(decoder: $0) })
    declareEncodable(LocalizationSettings.self, f: { LocalizationSettings(decoder: $0) })
    declareEncodable(ProxySettings.self, f: { ProxySettings(decoder: $0) })
    declareEncodable(LimitsConfiguration.self, f: { LimitsConfiguration(decoder: $0) })
    declareEncodable(SuggestedLocalizationEntry.self, f: { SuggestedLocalizationEntry(decoder: $0) })
    declareEncodable(SynchronizeLocalizationUpdatesOperation.self, f: { SynchronizeLocalizationUpdatesOperation(decoder: $0) })
    declareEncodable(ChannelMessageStateVersionAttribute.self, f: { ChannelMessageStateVersionAttribute(decoder: $0) })
    declareEncodable(CachedSecretChatData.self, f: { CachedSecretChatData(decoder: $0) })
    declareEncodable(ManagedDeviceContactsMetaInfo.self, f: { ManagedDeviceContactsMetaInfo(decoder: $0) })
    declareEncodable(ManagedDeviceContactEntryContents.self, f: { ManagedDeviceContactEntryContents(decoder: $0) })
    declareEncodable(TemporaryTwoStepPasswordToken.self, f: { TemporaryTwoStepPasswordToken(decoder: $0) })
    declareEncodable(AuthorSignatureMessageAttribute.self, f: { AuthorSignatureMessageAttribute(decoder: $0) })
    declareEncodable(TelegramMediaExpiredContent.self, f: { TelegramMediaExpiredContent(decoder: $0) })
    declareEncodable(SavedStickerItem.self, f: { SavedStickerItem(decoder: $0) })
    declareEncodable(ConsumablePersonalMentionMessageAttribute.self, f: { ConsumablePersonalMentionMessageAttribute(decoder: $0) })
    declareEncodable(ConsumePersonalMessageAction.self, f: { ConsumePersonalMessageAction(decoder: $0) })
    declareEncodable(CachedStickerPack.self, f: { CachedStickerPack(decoder: $0) })
    
    return
}()

func accountNetworkUsageInfoPath(basePath: String) -> String {
    return basePath + "/network-usage"
}

public func accountRecordIdPathName(_ id: AccountRecordId) -> String {
    return "account-\(UInt64(bitPattern: id.int64))"
}

public enum AccountResult {
    case upgrading
    case unauthorized(UnauthorizedAccount)
    case authorized(Account)
}

public func accountWithId(networkArguments: NetworkInitializationArguments, id: AccountRecordId, supplementary: Bool, appGroupPath: String, testingEnvironment: Bool, auxiliaryMethods: AccountAuxiliaryMethods, shouldKeepAutoConnection: Bool = true) -> Signal<AccountResult, NoError> {
    let _ = declaredEncodables
    
    let path = "\(appGroupPath)/\(accountRecordIdPathName(id))"
    
    var initializeMessageNamespacesWithHoles: [(PeerId.Namespace, MessageId.Namespace)] = []
    for peerNamespace in peerIdNamespacesWithInitialCloudMessageHoles {
        initializeMessageNamespacesWithHoles.append((peerNamespace, Namespaces.Message.Cloud))
    }
    
    let seedConfiguration = SeedConfiguration(initializeChatListWithHoles: [ChatListHole(index: MessageIndex(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.Empty, id: 0), namespace: Namespaces.Message.Cloud, id: 1), timestamp: 1))], initializeMessageNamespacesWithHoles: initializeMessageNamespacesWithHoles, existingMessageTags: MessageTags.all, messageTagsWithSummary: MessageTags.unseenPersonalMessage, existingGlobalMessageTags: GlobalMessageTags.all, peerNamespacesRequiringMessageTextIndex: [Namespaces.Peer.SecretChat])
    
    let postbox = openPostbox(basePath: path + "/postbox", globalMessageIdsNamespace: Namespaces.Message.Cloud, seedConfiguration: seedConfiguration)
    
    return postbox |> mapToSignal { result -> Signal<AccountResult, NoError> in
        switch result {
            case .upgrading:
                return .single(.upgrading)
            case let .postbox(postbox):
                return postbox.stateView()
                    |> take(1)
                    |> mapToSignal { view -> Signal<AccountResult, NoError> in
                        return postbox.modify { modifier -> (LocalizationSettings?, ProxySettings?) in
                            return (modifier.getPreferencesEntry(key: PreferencesKeys.localizationSettings) as? LocalizationSettings, modifier.getPreferencesEntry(key: PreferencesKeys.proxySettings) as? ProxySettings)
                        } |> mapToSignal { (localizationSettings, proxySettings) -> Signal<AccountResult, NoError> in
                            let accountState = view.state
                            
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
                                        return initializedNetwork(arguments: networkArguments, supplementary: supplementary, datacenterId: Int(unauthorizedState.masterDatacenterId), keychain: keychain, basePath: path, testingEnvironment: testingEnvironment, languageCode: localizationSettings?.languageCode, proxySettings: proxySettings)
                                            |> map { network -> AccountResult in
                                                return .unauthorized(UnauthorizedAccount(networkArguments: networkArguments, id: id, appGroupPath: appGroupPath, basePath: path, testingEnvironment: testingEnvironment, postbox: postbox, network: network, shouldKeepAutoConnection: shouldKeepAutoConnection))
                                            }
                                    case let authorizedState as AuthorizedAccountState:
                                        return initializedNetwork(arguments: networkArguments, supplementary: supplementary, datacenterId: Int(authorizedState.masterDatacenterId), keychain: keychain, basePath: path, testingEnvironment: testingEnvironment, languageCode: localizationSettings?.languageCode, proxySettings: proxySettings)
                                            |> map { network -> AccountResult in
                                                return .authorized(Account(id: id, basePath: path, testingEnvironment: testingEnvironment, postbox: postbox, network: network, peerId: authorizedState.peerId, auxiliaryMethods: auxiliaryMethods))
                                        }
                                    case _:
                                        assertionFailure("Unexpected accountState \(accountState)")
                                }
                            }
                            
                            return initializedNetwork(arguments: networkArguments, supplementary: supplementary, datacenterId: 2, keychain: keychain, basePath: path, testingEnvironment: testingEnvironment, languageCode: localizationSettings?.languageCode, proxySettings: proxySettings)
                                |> map { network -> AccountResult in
                                    return .unauthorized(UnauthorizedAccount(networkArguments: networkArguments, id: id, appGroupPath: appGroupPath, basePath: path, testingEnvironment: testingEnvironment, postbox: postbox, network: network, shouldKeepAutoConnection: shouldKeepAutoConnection))
                            }
                        }
                    }
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

func sha1Digest(_ data : Data) -> Data {
    var res = Data()
    res.count = Int(CC_SHA1_DIGEST_LENGTH)
    res.withUnsafeMutableBytes { mutableBytes -> Void in
        data.withUnsafeBytes { bytes -> Void in
            CC_SHA1(bytes, CC_LONG(data.count), mutableBytes)
        }
    }
    return res
}

func sha256Digest(_ data : Data) -> Data {
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
        let currentPasswordHash = sha256Digest(data)
        
        return account.network.request(Api.functions.auth.checkPassword(passwordHash: Buffer(data: currentPasswordHash)), automaticFloodWait: false)
    }
}

public enum AccountServiceTaskMasterMode {
    case now
    case always
    case never
}

public enum AccountNetworkState: Equatable {
    case waitingForNetwork
    case connecting(toProxy: Bool)
    case updating
    case online
    
    public static func ==(lhs: AccountNetworkState, rhs: AccountNetworkState) -> Bool {
        switch lhs {
            case .waitingForNetwork:
                if case .waitingForNetwork = rhs {
                    return true
                } else {
                    return false
                }
            case let .connecting(toProxy):
                if case .connecting(toProxy) = rhs {
                    return true
                } else {
                    return false
                }
            case .updating:
                if case .updating = rhs {
                    return true
                } else {
                    return false
                }
            case .online:
                if case .online = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public final class AccountAuxiliaryMethods {
    public let updatePeerChatInputState: (PeerChatInterfaceState?, SynchronizeableChatInputState?) -> PeerChatInterfaceState?
    public let fetchResource: (Account, MediaResource, Range<Int>, MediaResourceFetchTag?) -> Signal<MediaResourceDataFetchResult, NoError>?
    
    public init(updatePeerChatInputState: @escaping (PeerChatInterfaceState?, SynchronizeableChatInputState?) -> PeerChatInterfaceState?, fetchResource: @escaping (Account, MediaResource, Range<Int>, MediaResourceFetchTag?) -> Signal<MediaResourceDataFetchResult, NoError>?) {
        self.updatePeerChatInputState = updatePeerChatInputState
        self.fetchResource = fetchResource
    }
}

public class Account {
    public let id: AccountRecordId
    public let basePath: String
    public let testingEnvironment: Bool
    public let postbox: Postbox
    public let network: Network
    public let peerId: PeerId
    
    public let auxiliaryMethods: AccountAuxiliaryMethods
    
    private let serviceQueue = Queue()
    
    public private(set) var stateManager: AccountStateManager!
    public private(set) var callSessionManager: CallSessionManager!
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
    
    public let notificationToken = Promise<Data>()
    public let voipToken = Promise<Data>()
    private let notificationTokenDisposable = MetaDisposable()
    private let voipTokenDisposable = MetaDisposable()
    
    public let deviceContactList = Promise<[DeviceContact]>()
    private let deviceContactListDisposable = MetaDisposable()
    
    public let shouldBeServiceTaskMaster = Promise<AccountServiceTaskMasterMode>()
    public let shouldKeepOnlinePresence = Promise<Bool>()
    
    private let networkStateValue = Promise<AccountNetworkState>(.waitingForNetwork)
    public var networkState: Signal<AccountNetworkState, NoError> {
        return self.networkStateValue.get()
    }
    
    private let _loggedOut = ValuePromise<Bool>(false, ignoreRepeated: true)
    public var loggedOut: Signal<Bool, NoError> {
        return self._loggedOut.get()
    }
    
    var transformOutgoingMessageMedia: TransformOutgoingMessageMedia?
    
    public init(id: AccountRecordId, basePath: String, testingEnvironment: Bool, postbox: Postbox, network: Network, peerId: PeerId, auxiliaryMethods: AccountAuxiliaryMethods) {
        self.id = id
        self.basePath = basePath
        self.testingEnvironment = testingEnvironment
        self.postbox = postbox
        self.network = network
        self.peerId = peerId
        
        self.auxiliaryMethods = auxiliaryMethods
        
        self.peerInputActivityManager = PeerInputActivityManager()
        self.stateManager = AccountStateManager(account: self, peerInputActivityManager: self.peerInputActivityManager, auxiliaryMethods: auxiliaryMethods)
        self.callSessionManager = CallSessionManager(postbox: postbox, network: network, addUpdates: { [weak self] updates in
            self?.stateManager.addUpdates(updates)
        })
        self.localInputActivityManager = PeerInputActivityManager()
        self.viewTracker = AccountViewTracker(account: self)
        self.pendingMessageManager = PendingMessageManager(network: network, postbox: postbox, stateManager: self.stateManager)
        
        self.network.loggedOut = { [weak self] in
            if let strongSelf = self {
                strongSelf._loggedOut.set(true)
                strongSelf.callSessionManager.dropAll()
            }
        }
        
        let networkStateSignal = combineLatest(self.stateManager.isUpdating, network.connectionStatus)
            |> map { isUpdating, connectionStatus -> AccountNetworkState in
                switch connectionStatus {
                    case .waitingForNetwork:
                        return .waitingForNetwork
                    case let .connecting(toProxy):
                        return .connecting(toProxy: toProxy)
                    case .updating:
                        return .updating
                    case .online:
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
                
                return network.request(Api.functions.account.registerDevice(tokenType: 1, token: tokenString, deviceModel: "iPhone", systemVersion: systemVersion, appVersion: appVersionString, appSandbox: appSandbox))
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
                
                return network.request(Api.functions.account.registerDevice(tokenType: 9, token: tokenString, deviceModel: "iPhone", systemVersion: systemVersion, appVersion: appVersionString, appSandbox: appSandbox))
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
        
        let pendingMessageManager = self.pendingMessageManager
        self.managedOperationsDisposable.add(postbox.unsentMessageIdsView().start(next: { [weak pendingMessageManager] view in
            pendingMessageManager?.updatePendingMessageIds(view.ids)
        }))
        
        self.managedOperationsDisposable.add(managedSecretChatOutgoingOperations(postbox: self.postbox, network: self.network).start())
        self.managedOperationsDisposable.add(managedCloudChatRemoveMessagesOperations(postbox: self.postbox, network: self.network, stateManager: self.stateManager).start())
        self.managedOperationsDisposable.add(managedAutoremoveMessageOperations(postbox: self.postbox).start())
        self.managedOperationsDisposable.add(managedGlobalNotificationSettings(postbox: self.postbox, network: self.network).start())
        self.managedOperationsDisposable.add(managedSynchronizePinnedChatsOperations(postbox: self.postbox, network: self.network, stateManager: self.stateManager).start())
        self.managedOperationsDisposable.add(managedSynchronizeInstalledStickerPacksOperations(postbox: self.postbox, network: self.network, stateManager: self.stateManager, namespace: .stickers).start())
        self.managedOperationsDisposable.add(managedSynchronizeInstalledStickerPacksOperations(postbox: self.postbox, network: self.network, stateManager: self.stateManager, namespace: .masks).start())
        self.managedOperationsDisposable.add(managedSynchronizeMarkFeaturedStickerPacksAsSeenOperations(postbox: self.postbox, network: self.network).start())
        self.managedOperationsDisposable.add(managedRecentStickers(postbox: self.postbox, network: self.network).start())
        self.managedOperationsDisposable.add(managedSynchronizeSavedGifsOperations(postbox: self.postbox, network: self.network).start())
        self.managedOperationsDisposable.add(managedSynchronizeSavedStickersOperations(postbox: self.postbox, network: self.network).start())
        self.managedOperationsDisposable.add(managedRecentlyUsedInlineBots(postbox: self.postbox, network: self.network).start())
        self.managedOperationsDisposable.add(managedLocalTypingActivities(activities: self.localInputActivityManager.allActivities(), postbox: self.postbox, network: self.network).start())
        self.managedOperationsDisposable.add(managedSynchronizeConsumeMessageContentOperations(postbox: self.postbox, network: self.network, stateManager: self.stateManager).start())
        self.managedOperationsDisposable.add(managedConsumePersonalMessagesActions(postbox: self.postbox, network: self.network, stateManager: self.stateManager).start())
        self.managedOperationsDisposable.add(managedSynchronizeChatInputStateOperations(postbox: self.postbox, network: self.network).start())
        self.managedOperationsDisposable.add(managedConfigurationUpdates(postbox: self.postbox, network: self.network).start())
        self.managedOperationsDisposable.add(managedLocalizationUpdatesOperations(postbox: self.postbox, network: self.network).start())
        self.managedOperationsDisposable.add(managedPendingPeerNotificationSettings(postbox: self.postbox, network: self.network).start())
        
        let updatedPresence = self.shouldKeepOnlinePresence.get()
            |> distinctUntilChanged
            |> mapToSignal { [weak self] online -> Signal<Void, NoError> in
                if let strongSelf = self {
                    let delayRequest: Signal<Void, NoError> = .complete() |> delay(60.0, queue: Queue.concurrentDefaultQueue())
                    let pushStatusOnce = strongSelf.network.request(Api.functions.account.updateStatus(offline: online ? .boolFalse : .boolTrue))
                        |> retryRequest
                        |> mapToSignal { _ -> Signal<Void, NoError> in return .complete() }
                    let pushStatusRepeatedly = (pushStatusOnce |> then(delayRequest)) |> restart
                    let peerId = strongSelf.peerId
                    let updatePresenceLocally = strongSelf.postbox.modify { modifier -> Void in
                        let timestamp: Double
                        if online {
                            timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970 + 60.0 * 60.0 * 24.0 * 356.0
                        } else {
                            timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970 - 1.0
                        }
                        modifier.updatePeerPresences([peerId: TelegramUserPresence(status: .present(until: Int32(timestamp)))])
                    }
                    return combineLatest(pushStatusRepeatedly, updatePresenceLocally)
                        |> mapToSignal { _ -> Signal<Void, NoError> in return .complete() }
                } else {
                    return .complete()
                }
        }
        self.updatedPresenceDisposable.set(updatedPresence.start())
        
        self.deviceContactListDisposable.set(managedDeviceContacts(postbox: self.postbox, network: self.network, deviceContacts: self.deviceContactList.get()).start())
    }
    
    deinit {
        self.managedContactsDisposable.dispose()
        self.managedStickerPacksDisposable.dispose()
        self.notificationTokenDisposable.dispose()
        self.voipTokenDisposable.dispose()
        self.deviceContactListDisposable.dispose()
        self.managedServiceViewsDisposable.dispose()
        self.updatedPresenceDisposable.dispose()
        self.managedOperationsDisposable.dispose()
    }
    
    public func peerInputActivities(peerId: PeerId) -> Signal<[(PeerId, PeerInputActivity)], NoError> {
        return self.peerInputActivityManager.activities(peerId: peerId)
    }
    
    public func allPeerInputActivities() -> Signal<[PeerId: [PeerId: PeerInputActivity]], NoError> {
        return self.peerInputActivityManager.allActivities()
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

public func accountNetworkUsageStats(account: Account, reset: ResetNetworkUsageStats) -> Signal<NetworkUsageStats, NoError> {
    return networkUsageStats(basePath: account.basePath, reset: reset)
}

public typealias FetchCachedResourceRepresentation = (_ account: Account, _ resource: MediaResource, _ resourceData: MediaResourceData, _ representation: CachedMediaResourceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError>
public typealias TransformOutgoingMessageMedia = (_ postbox: Postbox, _ network: Network, _ media: Media, _ userInteractive: Bool) -> Signal<Media?, NoError>

public func setupAccount(_ account: Account, fetchCachedResourceRepresentation: FetchCachedResourceRepresentation? = nil, transformOutgoingMessageMedia: TransformOutgoingMessageMedia? = nil) {
    account.postbox.mediaBox.fetchResource = { [weak account] resource, range, tag -> Signal<MediaResourceDataFetchResult, NoError> in
        if let strongAccount = account {
            if let result = fetchResource(account: strongAccount, resource: resource, range: range, tag: tag) {
                return result
            } else if let result = strongAccount.auxiliaryMethods.fetchResource(strongAccount, resource, range, tag) {
                return result
            } else {
                return .never()
            }
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
    
    account.managedContactsDisposable.set(manageContacts(network: account.network, postbox: account.postbox, accountPeerId: account.peerId).start())
    account.managedStickerPacksDisposable.set(manageStickerPacks(network: account.network, postbox: account.postbox).start())
    
    /*account.network.request(Api.functions.help.getScheme(version: 0)).start(next: { result in
        if case let .scheme(text, _, _, _) = result {
            print("\(text)")
        }
    })*/
}
