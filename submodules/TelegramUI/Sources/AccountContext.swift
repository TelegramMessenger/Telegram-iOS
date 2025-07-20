import Foundation
import SwiftSignalKit
import UIKit
import Postbox
import TelegramCore
import Display
import DeviceAccess
import TelegramPresentationData
import AccountContext
import LiveLocationManager
import TemporaryCachedPeerDataManager
import PhoneNumberFormat
import TelegramUIPreferences
import TelegramVoip
import TelegramCallsUI
import TelegramBaseController
import AsyncDisplayKit
import PresentationDataUtils
import FetchManagerImpl
import InAppPurchaseManager
import AnimationCache
import MultiAnimationRenderer
import AppBundle
import DirectMediaImageCache

private final class DeviceSpecificContactImportContext {
    let disposable = MetaDisposable()
    var reference: DeviceContactBasicDataWithReference?
    
    init() {
    }
    
    deinit {
        self.disposable.dispose()
    }
}

private final class DeviceSpecificContactImportContexts {
    private let queue: Queue
    
    private var contexts: [PeerId: DeviceSpecificContactImportContext] = [:]
    
    init(queue: Queue) {
        self.queue = queue
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }
    
    func update(account: Account, deviceContactDataManager: DeviceContactDataManager, references: [PeerId: DeviceContactBasicDataWithReference]) {
        var validIds = Set<PeerId>()
        for (peerId, reference) in references {
            validIds.insert(peerId)
            
            let context: DeviceSpecificContactImportContext
            if let current = self.contexts[peerId] {
                context = current
            } else {
                context = DeviceSpecificContactImportContext()
                self.contexts[peerId] = context
            }
            if context.reference != reference {
                context.reference = reference
                
                let signal = TelegramEngine(account: account).data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                |> map { peer -> String? in
                    if case let .user(user) = peer {
                        return user.phone
                    } else {
                        return nil
                    }
                }
                |> distinctUntilChanged
                |> mapToSignal { phone -> Signal<Never, NoError> in
                    guard let phone = phone else {
                        return .complete()
                    }
                    var found = false
                    let formattedPhone = formatPhoneNumber(phone)
                    for number in reference.basicData.phoneNumbers {
                        if formatPhoneNumber(number.value) == formattedPhone {
                            found = true
                            break
                        }
                    }
                    if !found {
                        return deviceContactDataManager.appendPhoneNumber(DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: formattedPhone), to: reference.stableId)
                        |> ignoreValues
                    } else {
                        return .complete()
                    }
                }
                context.disposable.set(signal.start())
            }
        }
        
        var removeIds: [PeerId] = []
        for peerId in self.contexts.keys {
            if !validIds.contains(peerId) {
                removeIds.append(peerId)
            }
        }
        for peerId in removeIds {
            self.contexts.removeValue(forKey: peerId)
        }
    }
}

public final class AccountContextImpl: AccountContext {
    public let sharedContextImpl: SharedAccountContextImpl
    public var sharedContext: SharedAccountContext {
        return self.sharedContextImpl
    }
    public let account: Account
    public let engine: TelegramEngine
    
    public let fetchManager: FetchManager
    public let prefetchManager: PrefetchManager?
    
    public var keyShortcutsController: KeyShortcutsController?
    
    public let downloadedMediaStoreManager: DownloadedMediaStoreManager
    
    public let liveLocationManager: LiveLocationManager?
    public let peersNearbyManager: PeersNearbyManager?
    public let wallpaperUploadManager: WallpaperUploadManager?
    private let themeUpdateManager: ThemeUpdateManager?
    public let inAppPurchaseManager: InAppPurchaseManager?
    public let starsContext: StarsContext?
    public let tonContext: StarsContext?
    
    public let peerChannelMemberCategoriesContextsManager = PeerChannelMemberCategoriesContextsManager()
    
    public let currentLimitsConfiguration: Atomic<LimitsConfiguration>
    private let _limitsConfiguration = Promise<LimitsConfiguration>()
    public var limitsConfiguration: Signal<LimitsConfiguration, NoError> {
        return self._limitsConfiguration.get()
    }
    
    public var currentContentSettings: Atomic<ContentSettings>
    private let _contentSettings = Promise<ContentSettings>()
    public var contentSettings: Signal<ContentSettings, NoError> {
        return self._contentSettings.get()
    }
    
    public var currentAppConfiguration: Atomic<AppConfiguration>
    private let _appConfiguration = Promise<AppConfiguration>()
    public var appConfiguration: Signal<AppConfiguration, NoError> {
        return self._appConfiguration.get()
    }
    
    public var currentCountriesConfiguration: Atomic<CountriesConfiguration>
    private let _countriesConfiguration = Promise<CountriesConfiguration>()
    public var countriesConfiguration: Signal<CountriesConfiguration, NoError> {
        return self._countriesConfiguration.get()
    }
    
    private var storedPassword: (String, CFAbsoluteTime, SwiftSignalKit.Timer)?
    private var limitsConfigurationDisposable: Disposable?
    private var contentSettingsDisposable: Disposable?
    private var appConfigurationDisposable: Disposable?
    private var countriesConfigurationDisposable: Disposable?
    
    private let deviceSpecificContactImportContexts: QueueLocalObject<DeviceSpecificContactImportContexts>
    private var managedAppSpecificContactsDisposable: Disposable?
    
    private var experimentalUISettingsDisposable: Disposable?
    
    public let cachedGroupCallContexts: AccountGroupCallContextCache
    
    public let animationCache: AnimationCache
    public let animationRenderer: MultiAnimationRenderer
    
    private var animatedEmojiStickersDisposable: Disposable?
    public private(set) var animatedEmojiStickersValue: [String: [StickerPackItem]] = [:]
    private let animatedEmojiStickersPromise = Promise<[String: [StickerPackItem]]>()
    public var animatedEmojiStickers: Signal<[String: [StickerPackItem]], NoError> {
        return self.animatedEmojiStickersPromise.get()
    }
    
    private var additionalAnimatedEmojiStickersPromise: Promise<[String: [Int: StickerPackItem]]>?
    public var additionalAnimatedEmojiStickers: Signal<[String: [Int: StickerPackItem]], NoError> {
        let additionalAnimatedEmojiStickersPromise: Promise<[String: [Int: StickerPackItem]]>
        if let current = self.additionalAnimatedEmojiStickersPromise {
            additionalAnimatedEmojiStickersPromise = current
        } else {
            additionalAnimatedEmojiStickersPromise = Promise<[String: [Int: StickerPackItem]]>()
            self.additionalAnimatedEmojiStickersPromise = additionalAnimatedEmojiStickersPromise
            additionalAnimatedEmojiStickersPromise.set(self.engine.stickers.loadedStickerPack(reference: .animatedEmojiAnimations, forceActualized: false)
            |> map { animatedEmoji -> [String: [Int: StickerPackItem]] in
                let sequence = "0️⃣1️⃣2️⃣3️⃣4️⃣5️⃣6️⃣7️⃣8️⃣9️⃣".strippedEmoji
                var animatedEmojiStickers: [String: [Int: StickerPackItem]] = [:]
                switch animatedEmoji {
                case let .result(_, items, _):
                    for item in items {
                        let indexKeys = item.getStringRepresentationsOfIndexKeys()
                        if indexKeys.count > 1, let first = indexKeys.first, let last = indexKeys.last {
                            let emoji: String?
                            let indexEmoji: String?
                            if sequence.contains(first.strippedEmoji) {
                                emoji = last
                                indexEmoji = first
                            } else if sequence.contains(last.strippedEmoji) {
                                emoji = first
                                indexEmoji = last
                            } else {
                                emoji = nil
                                indexEmoji = nil
                            }
                            
                            if let emoji = emoji?.strippedEmoji, let indexEmoji = indexEmoji?.strippedEmoji.first, let strIndex = sequence.firstIndex(of: indexEmoji) {
                                let index = sequence.distance(from: sequence.startIndex, to: strIndex)
                                if animatedEmojiStickers[emoji] != nil {
                                    animatedEmojiStickers[emoji]![index] = item
                                } else {
                                    animatedEmojiStickers[emoji] = [index: item]
                                }
                            }
                        }
                    }
                default:
                    break
                }
                return animatedEmojiStickers
            })
        }
        return additionalAnimatedEmojiStickersPromise.get()
    }
    
    private var availableReactionsValue: Promise<AvailableReactions?>?
    public var availableReactions: Signal<AvailableReactions?, NoError> {
        let availableReactionsValue: Promise<AvailableReactions?>
        if let current = self.availableReactionsValue {
            availableReactionsValue = current
        } else {
            availableReactionsValue = Promise<AvailableReactions?>()
            self.availableReactionsValue = availableReactionsValue
            availableReactionsValue.set(self.engine.stickers.availableReactions())
        }
        return availableReactionsValue.get()
    }
    
    private var availableMessageEffectsValue: Promise<AvailableMessageEffects?>?
    public var availableMessageEffects: Signal<AvailableMessageEffects?, NoError> {
        let availableMessageEffectsValue: Promise<AvailableMessageEffects?>
        if let current = self.availableMessageEffectsValue {
            availableMessageEffectsValue = current
        } else {
            availableMessageEffectsValue = Promise<AvailableMessageEffects?>()
            self.availableMessageEffectsValue = availableMessageEffectsValue
            availableMessageEffectsValue.set(self.engine.stickers.availableMessageEffects())
        }
        return availableMessageEffectsValue.get()
    }
    
    private var userLimitsConfigurationDisposable: Disposable?
    public private(set) var userLimits: EngineConfiguration.UserLimits
    
    private var peerNameColorsConfigurationDisposable: Disposable?
    public private(set) var peerNameColors: PeerNameColors
    
    private var audioTranscriptionTrialDisposable: Disposable?
    public private(set) var audioTranscriptionTrial: AudioTranscription.TrialState
    
    public private(set) var isPremium: Bool
    
    private var isFrozenDisposable: Disposable?
    public private(set) var isFrozen: Bool
    
    public let imageCache: AnyObject?
    
    public init(sharedContext: SharedAccountContextImpl, account: Account, limitsConfiguration: LimitsConfiguration, contentSettings: ContentSettings, appConfiguration: AppConfiguration, availableReplyColors: EngineAvailableColorOptions, availableProfileColors: EngineAvailableColorOptions, temp: Bool = false)
    {
        self.sharedContextImpl = sharedContext
        self.account = account
        self.engine = TelegramEngine(account: account)
        
        self.imageCache = DirectMediaImageCache(account: account)
        
        self.userLimits = EngineConfiguration.UserLimits(UserLimitsConfiguration.defaultValue)
        self.peerNameColors = PeerNameColors.with(availableReplyColors: availableReplyColors, availableProfileColors: availableProfileColors)
        self.audioTranscriptionTrial = AudioTranscription.TrialState.defaultValue
        self.isPremium = false
        self.isFrozen = false
        
        self.downloadedMediaStoreManager = DownloadedMediaStoreManagerImpl(postbox: account.postbox, accountManager: sharedContext.accountManager)
        
        if let locationManager = self.sharedContextImpl.locationManager {
            self.liveLocationManager = LiveLocationManagerImpl(engine: self.engine, locationManager: locationManager, inForeground: sharedContext.applicationBindings.applicationInForeground)
        } else {
            self.liveLocationManager = nil
        }
        self.fetchManager = FetchManagerImpl(postbox: account.postbox, storeManager: self.downloadedMediaStoreManager)
        if sharedContext.applicationBindings.isMainApp && !temp {
            self.prefetchManager = PrefetchManagerImpl(sharedContext: sharedContext, account: account, engine: self.engine, fetchManager: self.fetchManager)
            self.wallpaperUploadManager = WallpaperUploadManagerImpl(sharedContext: sharedContext, account: account, presentationData: sharedContext.presentationData)
            self.themeUpdateManager = ThemeUpdateManagerImpl(sharedContext: sharedContext, account: account)
            
            self.inAppPurchaseManager = InAppPurchaseManager(engine: .authorized(self.engine))
            self.starsContext = self.engine.payments.peerStarsContext()
            self.tonContext = self.engine.payments.peerTonContext()
        } else {
            self.prefetchManager = nil
            self.wallpaperUploadManager = nil
            self.themeUpdateManager = nil
            self.inAppPurchaseManager = nil
            self.starsContext = nil
            self.tonContext = nil
        }
        
        self.account.stateManager.starsContext = self.starsContext
        self.account.stateManager.tonContext = self.starsContext
        
        self.peersNearbyManager = nil
        
        self.cachedGroupCallContexts = AccountGroupCallContextCacheImpl()
        
        let cacheStorageBox = self.account.postbox.mediaBox.cacheStorageBox
        self.animationCache = AnimationCacheImpl(basePath: self.account.postbox.mediaBox.basePath + "/animation-cache", allocateTempFile: {
            return TempBox.shared.tempFile(fileName: "file").path
        }, updateStorageStats: { path, size in
            if let pathData = path.data(using: .utf8) {
                cacheStorageBox.update(id: pathData, size: size)
            }
        })
        self.animationRenderer = MultiAnimationRendererImpl()
        (self.animationRenderer as? MultiAnimationRendererImpl)?.useYuvA = sharedContext.immediateExperimentalUISettings.compressedEmojiCache
        
        let updatedLimitsConfiguration = account.postbox.preferencesView(keys: [PreferencesKeys.limitsConfiguration])
        |> map { preferences -> LimitsConfiguration in
            return preferences.values[PreferencesKeys.limitsConfiguration]?.get(LimitsConfiguration.self) ?? LimitsConfiguration.defaultValue
        }
        
        self.currentLimitsConfiguration = Atomic(value: limitsConfiguration)
        self._limitsConfiguration.set(.single(limitsConfiguration) |> then(updatedLimitsConfiguration))
        
        let currentLimitsConfiguration = self.currentLimitsConfiguration
        self.limitsConfigurationDisposable = (self._limitsConfiguration.get()
        |> deliverOnMainQueue).start(next: { value in
            let _ = currentLimitsConfiguration.swap(value)
        })
        
        let updatedContentSettings = getContentSettings(postbox: account.postbox)
        self.currentContentSettings = Atomic(value: contentSettings)
        self._contentSettings.set(.single(contentSettings) |> then(updatedContentSettings))
        
        let currentContentSettings = self.currentContentSettings
        self.contentSettingsDisposable = (self._contentSettings.get()
        |> deliverOnMainQueue).start(next: { value in
            let _ = currentContentSettings.swap(value)
        })
        
        let updatedAppConfiguration = getAppConfiguration(postbox: account.postbox)
        self.currentAppConfiguration = Atomic(value: appConfiguration)
        self._appConfiguration.set(.single(appConfiguration) |> then(updatedAppConfiguration))
                
        let currentAppConfiguration = self.currentAppConfiguration
        self.appConfigurationDisposable = (self._appConfiguration.get()
        |> deliverOnMainQueue).start(next: { value in
            let _ = currentAppConfiguration.swap(value)
        })
        
        let langCode = sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode
        self.currentCountriesConfiguration = Atomic(value: CountriesConfiguration(countries: loadCountryCodes()))
        if !temp {
            let currentCountriesConfiguration = self.currentCountriesConfiguration
            self.countriesConfigurationDisposable = (self.engine.localization.getCountriesList(accountManager: sharedContext.accountManager, langCode: langCode)
            |> deliverOnMainQueue).start(next: { value in
                let _ = currentCountriesConfiguration.swap(CountriesConfiguration(countries: value))
            })
        }
        
        let queue = Queue()
        self.deviceSpecificContactImportContexts = QueueLocalObject(queue: queue, generate: {
            return DeviceSpecificContactImportContexts(queue: queue)
        })
        
        if let contactDataManager = sharedContext.contactDataManager {
            let deviceSpecificContactImportContexts = self.deviceSpecificContactImportContexts
            self.managedAppSpecificContactsDisposable = (contactDataManager.appSpecificReferences()
            |> deliverOn(queue)).start(next: { appSpecificReferences in
                deviceSpecificContactImportContexts.with { context in
                    context.update(account: account, deviceContactDataManager: contactDataManager, references: appSpecificReferences)
                }
            })
        }
        
        account.callSessionManager.updateVersions(versions: PresentationCallManagerImpl.voipVersions(includeExperimental: true, includeReference: true).map { version, supportsVideo -> CallSessionManagerImplementationVersion in
            CallSessionManagerImplementationVersion(version: version, supportsVideo: supportsVideo)
        })
        
        self.animatedEmojiStickersDisposable = (self.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false)
        |> map { animatedEmoji -> [String: [StickerPackItem]] in
            var animatedEmojiStickers: [String: [StickerPackItem]] = [:]
            switch animatedEmoji {
                case let .result(_, items, _):
                    for item in items {
                        if let emoji = item.getStringRepresentationsOfIndexKeys().first {
                            animatedEmojiStickers[emoji.basicEmoji.0] = [item]
                            let strippedEmoji = emoji.basicEmoji.0.strippedEmoji
                            if animatedEmojiStickers[strippedEmoji] == nil {
                                animatedEmojiStickers[strippedEmoji] = [item]
                            }
                        }
                    }
                default:
                    break
            }
            return animatedEmojiStickers
        }
        |> deliverOnMainQueue).start(next: { [weak self] stickers in
            guard let strongSelf = self else {
                return
            }
            strongSelf.animatedEmojiStickersValue = stickers
            strongSelf.animatedEmojiStickersPromise.set(.single(stickers))
        })
        
        self.userLimitsConfigurationDisposable = (self.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: account.peerId))
        |> mapToSignal { peer -> Signal<(Bool, EngineConfiguration.UserLimits), NoError> in
            let isPremium = peer?.isPremium ?? false
            return self.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: isPremium))
            |> map { userLimits in
                return (isPremium, userLimits)
            }
        }
        |> deliverOnMainQueue).startStrict(next: { [weak self] isPremium, userLimits in
            guard let self = self else {
                return
            }
            self.isPremium = isPremium
            self.userLimits = userLimits
        })
        
        self.peerNameColorsConfigurationDisposable = (combineLatest(
            self.engine.accountData.observeAvailableColorOptions(scope: .replies),
            self.engine.accountData.observeAvailableColorOptions(scope: .profile)
        )
        |> deliverOnMainQueue).startStrict(next: { [weak self] availableReplyColors, availableProfileColors in
            guard let self = self else {
                return
            }
            self.peerNameColors = PeerNameColors.with(availableReplyColors: availableReplyColors, availableProfileColors: availableProfileColors)
        })
        
        self.audioTranscriptionTrialDisposable = (self.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: account.peerId))
        |> mapToSignal { peer -> Signal<AudioTranscription.TrialState, NoError> in
            let isPremium = peer?.isPremium ?? false
            if isPremium {
                return .single(AudioTranscription.TrialState(cooldownUntilTime: nil, remainingCount: 1))
            } else {
                return self.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.AudioTranscriptionTrial())
            }
        }
        |> deliverOnMainQueue).startStrict(next: { [weak self] audioTranscriptionTrial in
            guard let self = self else {
                return
            }
            self.audioTranscriptionTrial = audioTranscriptionTrial
        })
        
        self.isFrozenDisposable = (self.appConfiguration
        |> map { appConfiguration in
            return AccountFreezeConfiguration.with(appConfiguration: appConfiguration).freezeUntilDate != nil
        }
        |> distinctUntilChanged
        |> deliverOnMainQueue).startStrict(next: { [weak self] isFrozen in
            guard let self = self else {
                return
            }
            self.isFrozen = isFrozen
        })
        
        self.experimentalUISettingsDisposable = (sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.experimentalUISettings])
        |> deliverOnMainQueue).start(next: { [weak self] sharedData in
            guard let self else {
                return
            }
            guard let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings]?.get(ExperimentalUISettings.self) else {
                return
            }
            (self.animationRenderer as? MultiAnimationRendererImpl)?.useYuvA = settings.compressedEmojiCache
        })
    }
    
    deinit {
        self.limitsConfigurationDisposable?.dispose()
        self.managedAppSpecificContactsDisposable?.dispose()
        self.contentSettingsDisposable?.dispose()
        self.appConfigurationDisposable?.dispose()
        self.countriesConfigurationDisposable?.dispose()
        self.experimentalUISettingsDisposable?.dispose()
        self.animatedEmojiStickersDisposable?.dispose()
        self.userLimitsConfigurationDisposable?.dispose()
        self.peerNameColorsConfigurationDisposable?.dispose()
        self.isFrozenDisposable?.dispose()
    }
    
    public func storeSecureIdPassword(password: String) {
        self.storedPassword?.2.invalidate()
        let timer = SwiftSignalKit.Timer(timeout: 1.0 * 60.0 * 60.0, repeat: false, completion: { [weak self] in
            self?.storedPassword = nil
        }, queue: Queue.mainQueue())
        self.storedPassword = (password, CFAbsoluteTimeGetCurrent(), timer)
        timer.start()
    }
    
    public func getStoredSecureIdPassword() -> String? {
        if let (password, timestamp, timer) = self.storedPassword {
            if CFAbsoluteTimeGetCurrent() > timestamp + 1.0 * 60.0 * 60.0 {
                timer.invalidate()
                self.storedPassword = nil
            }
            return password
        } else {
            return nil
        }
    }
    
    public func chatLocationInput(for location: ChatLocation, contextHolder: Atomic<ChatLocationContextHolder?>) -> ChatLocationInput {
        switch location {
        case let .peer(peerId):
            return .peer(peerId: peerId, threadId: nil)
        case let .replyThread(data):
            if data.isForumPost || data.peerId.namespace != Namespaces.Peer.CloudChannel {
                return .peer(peerId: data.peerId, threadId: data.threadId)
            } else {
                let context = chatLocationContext(holder: contextHolder, account: self.account, data: data)
                return .thread(peerId: data.peerId, threadId: data.threadId, data: context.state)
            }
        case .customChatContents:
            preconditionFailure()
        }
    }
    
    public func chatLocationOutgoingReadState(for location: ChatLocation, contextHolder: Atomic<ChatLocationContextHolder?>) -> Signal<MessageId?, NoError> {
        switch location {
        case .peer:
            return .single(nil)
        case let .replyThread(data):
            if data.isForumPost, let peerId = location.peerId {
                let viewKey: PostboxViewKey = .messageHistoryThreadInfo(peerId: data.peerId, threadId: data.threadId)
                return self.account.postbox.combinedView(keys: [viewKey])
                |> map { views -> MessageId? in
                    if let threadInfo = views.views[viewKey] as? MessageHistoryThreadInfoView, let data = threadInfo.info?.data.get(MessageHistoryThreadData.self) {
                        return MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: data.maxOutgoingReadId)
                    } else {
                        return nil
                    }
                }
            } else if data.peerId.namespace == Namespaces.Peer.CloudChannel {
                let context = chatLocationContext(holder: contextHolder, account: self.account, data: data)
                return context.maxReadOutgoingMessageId
            } else {
                return .single(nil)
            }
        case .customChatContents:
            return .single(nil)
        }
    }

    public func chatLocationUnreadCount(for location: ChatLocation, contextHolder: Atomic<ChatLocationContextHolder?>) -> Signal<Int, NoError> {
        switch location {
        case let .peer(peerId):
            let unreadCountsKey: PostboxViewKey = .unreadCounts(items: [.peer(id: peerId, handleThreads: false), .total(nil)])
            return self.account.postbox.combinedView(keys: [unreadCountsKey])
            |> map { views in
                var unreadCount: Int32 = 0
                
                if let view = views.views[unreadCountsKey] as? UnreadMessageCountsView {
                    if let count = view.count(for: .peer(id: peerId, handleThreads: false)) {
                        unreadCount = count
                    }
                }
                
                return Int(unreadCount)
            }
        case let .replyThread(data):
            if data.isForumPost {
                let viewKey: PostboxViewKey = .messageHistoryThreadInfo(peerId: data.peerId, threadId: data.threadId)
                return self.account.postbox.combinedView(keys: [viewKey])
                |> map { views -> Int in
                    if let threadInfo = views.views[viewKey] as? MessageHistoryThreadInfoView, let data = threadInfo.info?.data.get(MessageHistoryThreadData.self) {
                        return Int(data.incomingUnreadCount)
                    } else {
                        return 0
                    }
                }
            } else if data.peerId.namespace != Namespaces.Peer.CloudChannel {
                return .single(0)
            } else {
                let context = chatLocationContext(holder: contextHolder, account: self.account, data: data)
                return context.unreadCount
            }
        case .customChatContents:
            return .single(0)
        }
    }
    
    public func applyMaxReadIndex(for location: ChatLocation, contextHolder: Atomic<ChatLocationContextHolder?>, messageIndex: MessageIndex) {
        switch location {
        case .peer:
            let _ = self.engine.messages.applyMaxReadIndexInteractively(index: messageIndex).start()
        case let .replyThread(data):
            let context = chatLocationContext(holder: contextHolder, account: self.account, data: data)
            context.applyMaxReadIndex(messageIndex: messageIndex)
        case .customChatContents:
            break
        }
    }
    
    public func scheduleGroupCall(peerId: PeerId, parentController: ViewController) {
        let _ = self.sharedContext.callManager?.scheduleGroupCall(context: self, peerId: peerId, endCurrentIfAny: true, parentController: parentController)
    }
    
    public func joinGroupCall(peerId: PeerId, invite: String?, requestJoinAsPeerId: ((@escaping (PeerId?) -> Void) -> Void)?, activeCall: EngineGroupCallDescription) {
        let callResult = self.sharedContext.callManager?.joinGroupCall(context: self, peerId: peerId, invite: invite, requestJoinAsPeerId: requestJoinAsPeerId, initialCall: activeCall, endCurrentIfAny: false)
        if let callResult = callResult, case let .alreadyInProgress(currentPeerId) = callResult {
            if currentPeerId == peerId {
                self.sharedContext.navigateToCurrentCall()
            } else {
                let dataInput: Signal<(EnginePeer?, EnginePeer?), NoError>
                if let currentPeerId = currentPeerId {
                    dataInput = self.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
                        TelegramEngine.EngineData.Item.Peer.Peer(id: currentPeerId)
                    )
                } else {
                    dataInput = self.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                    )
                    |> map { peer -> (EnginePeer?, EnginePeer?) in
                        return (peer, nil)
                    }
                }
                
                let _ = (dataInput
                |> deliverOnMainQueue).start(next: { [weak self] peer, current in
                    guard let strongSelf = self else {
                        return
                    }
                    guard let peer = peer else {
                        return
                    }
                    let presentationData = strongSelf.sharedContext.currentPresentationData.with { $0 }
                    if let current = current {
                        switch current {
                        case .channel, .legacyGroup:
                            let title: String
                            let text: String
                            if case let .channel(channel) = current, case .broadcast = channel.info {
                                title = presentationData.strings.Call_LiveStreamInProgressTitle
                                text = presentationData.strings.Call_LiveStreamInProgressMessage(current.compactDisplayTitle, peer.compactDisplayTitle).string
                            } else {
                                title = presentationData.strings.Call_VoiceChatInProgressTitle
                                text = presentationData.strings.Call_VoiceChatInProgressMessage(current.compactDisplayTitle, peer.compactDisplayTitle).string
                            }

                            strongSelf.sharedContext.mainWindow?.present(textAlertController(context: strongSelf, title: title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                                guard let strongSelf = self else {
                                    return
                                }
                                let _ = strongSelf.sharedContext.callManager?.joinGroupCall(context: strongSelf, peerId: peer.id, invite: invite, requestJoinAsPeerId: requestJoinAsPeerId, initialCall: activeCall, endCurrentIfAny: true)
                            })]), on: .root)
                        default:
                            let text: String
                            if case let .channel(channel) = peer, case .broadcast = channel.info {
                                text = presentationData.strings.Call_CallInProgressLiveStreamMessage(current.compactDisplayTitle, peer.compactDisplayTitle).string
                            } else {
                                text = presentationData.strings.Call_CallInProgressVoiceChatMessage(current.compactDisplayTitle, peer.compactDisplayTitle).string
                            }
                            strongSelf.sharedContext.mainWindow?.present(textAlertController(context: strongSelf, title: presentationData.strings.Call_CallInProgressTitle, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                                guard let strongSelf = self else {
                                    return
                                }
                                let _ = strongSelf.sharedContext.callManager?.joinGroupCall(context: strongSelf, peerId: peer.id, invite: invite, requestJoinAsPeerId: requestJoinAsPeerId, initialCall: activeCall, endCurrentIfAny: true)
                            })]), on: .root)
                        }
                    } else {
                        strongSelf.sharedContext.mainWindow?.present(textAlertController(context: strongSelf, title: presentationData.strings.Call_CallInProgressTitle, text: presentationData.strings.Call_ExternalCallInProgressMessage, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                        })]), on: .root)
                    }
                })
            }
        }
    }
    
    public func joinConferenceCall(call: JoinCallLinkInformation, isVideo: Bool, unmuteByDefault: Bool) {
        guard let callManager = self.sharedContext.callManager else {
            return
        }
        let result = callManager.joinConferenceCall(
            accountContext: self,
            initialCall: EngineGroupCallDescription(
                id: call.id,
                accessHash: call.accessHash,
                title: nil,
                scheduleTimestamp: nil,
                subscribedToScheduled: false,
                isStream: false
            ),
            reference: call.reference,
            beginWithVideo: isVideo,
            invitePeerIds: [],
            endCurrentIfAny: false,
            unmuteByDefault: unmuteByDefault
        )
        if case let .alreadyInProgress(currentPeerId) = result {
            let dataInput: Signal<EnginePeer?, NoError>
            if let currentPeerId {
                dataInput = self.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: currentPeerId)
                )
            } else {
                dataInput = .single(nil)
            }
            
            let _ = (dataInput
            |> deliverOnMainQueue).start(next: { [weak self] current in
                guard let strongSelf = self else {
                    return
                }
                let presentationData = strongSelf.sharedContext.currentPresentationData.with { $0 }
                if let current = current {
                    switch current {
                    case .channel, .legacyGroup:
                        let title: String
                        let text: String
                        if case let .channel(channel) = current, case .broadcast = channel.info {
                            title = presentationData.strings.Call_LiveStreamInProgressTitle
                            text = presentationData.strings.Call_LiveStreamInProgressConferenceMessage(current.compactDisplayTitle).string
                        } else {
                            title = presentationData.strings.Call_VoiceChatInProgressTitle
                            text = presentationData.strings.Call_VoiceChatInProgressConferenceMessage(current.compactDisplayTitle).string
                        }

                        strongSelf.sharedContext.mainWindow?.present(textAlertController(context: strongSelf, title: title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                            guard let self else {
                                return
                            }
                            let _ = callManager.joinConferenceCall(
                                accountContext: self,
                                initialCall: EngineGroupCallDescription(
                                    id: call.id,
                                    accessHash: call.accessHash,
                                    title: nil,
                                    scheduleTimestamp: nil,
                                    subscribedToScheduled: false,
                                    isStream: false
                                ),
                                reference: call.reference,
                                beginWithVideo: isVideo,
                                invitePeerIds: [],
                                endCurrentIfAny: true,
                                unmuteByDefault: unmuteByDefault
                            )
                        })]), on: .root)
                    default:
                        let text: String
                        text = presentationData.strings.Call_VoiceChatInProgressConferenceMessage(current.compactDisplayTitle).string
                        strongSelf.sharedContext.mainWindow?.present(textAlertController(context: strongSelf, title: presentationData.strings.Call_CallInProgressTitle, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                            guard let self else {
                                return
                            }
                            let _ = callManager.joinConferenceCall(
                                accountContext: self,
                                initialCall: EngineGroupCallDescription(
                                    id: call.id,
                                    accessHash: call.accessHash,
                                    title: nil,
                                    scheduleTimestamp: nil,
                                    subscribedToScheduled: false,
                                    isStream: false
                                ),
                                reference: call.reference,
                                beginWithVideo: isVideo,
                                invitePeerIds: [],
                                endCurrentIfAny: true,
                                unmuteByDefault: unmuteByDefault
                            )
                        })]), on: .root)
                    }
                } else {
                    strongSelf.sharedContext.mainWindow?.present(textAlertController(context: strongSelf, title: presentationData.strings.Call_CallInProgressTitle, text: presentationData.strings.Call_ExternalCallInProgressMessage, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                    })]), on: .root)
                }
            })
        }
    }
    
    public func requestCall(peerId: PeerId, isVideo: Bool, completion: @escaping () -> Void) {
        guard let callResult = self.sharedContext.callManager?.requestCall(context: self, peerId: peerId, isVideo: isVideo, endCurrentIfAny: false) else {
            return
        }
        
        if case let .alreadyInProgress(currentPeerId) = callResult {
            if currentPeerId == peerId {
                completion()
                self.sharedContext.navigateToCurrentCall()
            } else {
                let dataInput: Signal<(EnginePeer?, EnginePeer?), NoError>
                if let currentPeerId = currentPeerId {
                    dataInput = self.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
                        TelegramEngine.EngineData.Item.Peer.Peer(id: currentPeerId)
                    )
                } else {
                    dataInput = self.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                    )
                    |> map { peer -> (EnginePeer?, EnginePeer?) in
                        return (peer, nil)
                    }
                }
                
                let _ = (dataInput
                |> deliverOnMainQueue).start(next: { [weak self] peer, current in
                    guard let strongSelf = self else {
                        return
                    }
                    guard let peer = peer else {
                        return
                    }
                    let presentationData = strongSelf.sharedContext.currentPresentationData.with { $0 }
                    if let current = current {
                        switch current {
                        case .channel, .legacyGroup:
                            let text: String
                            if case let .channel(channel) = current, case .broadcast = channel.info {
                                text = presentationData.strings.Call_LiveStreamInProgressCallMessage(current.compactDisplayTitle, peer.compactDisplayTitle).string
                            } else {
                                text = presentationData.strings.Call_VoiceChatInProgressCallMessage(current.compactDisplayTitle, peer.compactDisplayTitle).string
                            }
                            strongSelf.sharedContext.mainWindow?.present(textAlertController(context: strongSelf, title: presentationData.strings.Call_VoiceChatInProgressTitle, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                                guard let strongSelf = self else {
                                    return
                                }
                                let _ = strongSelf.sharedContext.callManager?.requestCall(context: strongSelf, peerId: peerId, isVideo: isVideo, endCurrentIfAny: true)
                                completion()
                            })]), on: .root)
                        default:
                            strongSelf.sharedContext.mainWindow?.present(textAlertController(context: strongSelf, title: presentationData.strings.Call_CallInProgressTitle, text: presentationData.strings.Call_CallInProgressMessage(current.compactDisplayTitle, peer.compactDisplayTitle).string, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                                guard let strongSelf = self else {
                                    return
                                }
                                let _ = strongSelf.sharedContext.callManager?.requestCall(context: strongSelf, peerId: peerId, isVideo: isVideo, endCurrentIfAny: true)
                                completion()
                            })]), on: .root)
                        }
                    } else if let strongSelf = self {
                        strongSelf.sharedContext.mainWindow?.present(textAlertController(context: strongSelf, title: presentationData.strings.Call_CallInProgressTitle, text: presentationData.strings.Call_ExternalCallInProgressMessage, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                        })]), on: .root)
                    }
                })
            }
        } else {
            completion()
        }
    }
}

private func chatLocationContext(holder: Atomic<ChatLocationContextHolder?>, account: Account, data: ChatReplyThreadMessage) -> ReplyThreadHistoryContext {
    let holder = holder.modify { current in
        if let current = current as? ChatLocationReplyContextHolderImpl {
            return current
        } else {
            return ChatLocationReplyContextHolderImpl(account: account, data: data)
        }
    } as! ChatLocationReplyContextHolderImpl
    return holder.context
}

private final class ChatLocationReplyContextHolderImpl: ChatLocationContextHolder {
    let context: ReplyThreadHistoryContext
    
    init(account: Account, data: ChatReplyThreadMessage) {
        self.context = ReplyThreadHistoryContext(account: account, peerId: data.peerId, data: data)
    }
}

func getAppConfiguration(postbox: Postbox) -> Signal<AppConfiguration, NoError> {
    return postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
    |> map { view -> AppConfiguration in
        let appConfiguration: AppConfiguration = view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? AppConfiguration.defaultValue
        return appConfiguration
    }
    |> distinctUntilChanged
}

private func loadCountryCodes() -> [Country] {
    guard let filePath = getAppBundle().path(forResource: "PhoneCountries", ofType: "txt") else {
        return []
    }
    guard let stringData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
        return []
    }
    guard let data = String(data: stringData, encoding: .utf8) else {
        return []
    }
    
    let delimiter = ";"
    let endOfLine = "\n"
    
    var result: [Country] = []
//    var countriesByPrefix: [String: (Country, Country.CountryCode)] = [:]
    
    var currentLocation = data.startIndex
    
    let locale = Locale(identifier: "en-US")
    
    while true {
        guard let codeRange = data.range(of: delimiter, options: [], range: currentLocation ..< data.endIndex) else {
            break
        }
        
        let countryCode = String(data[currentLocation ..< codeRange.lowerBound])
        
        guard let idRange = data.range(of: delimiter, options: [], range: codeRange.upperBound ..< data.endIndex) else {
            break
        }
        
        let countryId = String(data[codeRange.upperBound ..< idRange.lowerBound])
        
        guard let patternRange = data.range(of: delimiter, options: [], range: idRange.upperBound ..< data.endIndex) else {
            break
        }
        
        let pattern = String(data[idRange.upperBound ..< patternRange.lowerBound])
        
        let maybeNameRange = data.range(of: endOfLine, options: [], range: patternRange.upperBound ..< data.endIndex)
        
        let countryName = locale.localizedString(forIdentifier: countryId) ?? ""
        if let _ = Int(countryCode) {
            let code = Country.CountryCode(code: countryCode, prefixes: [], patterns: !pattern.isEmpty ? [pattern] : [])
            let country = Country(id: countryId, name: countryName, localizedName: nil, countryCodes: [code], hidden: false)
            result.append(country)
//            countriesByPrefix["\(code.code)"] = (country, code)
        }
        
        if let maybeNameRange = maybeNameRange {
            currentLocation = maybeNameRange.upperBound
        } else {
            break
        }
    }
        
    return result
}
