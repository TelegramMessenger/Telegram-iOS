import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import SwiftSignalKit
import AsyncDisplayKit
import Display
import DeviceLocationManager
import TemporaryCachedPeerDataManager

#if ENABLE_WALLET
import WalletCore
#endif

public final class TelegramApplicationOpenUrlCompletion {
    public let completion: (Bool) -> Void
    
    public init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }
}

public enum AccessType {
    case notDetermined
    case allowed
    case denied
    case restricted
    case unreachable
}

public final class TelegramApplicationBindings {
    public let isMainApp: Bool
    public let containerPath: String
    public let appSpecificScheme: String
    public let openUrl: (String) -> Void
    public let openUniversalUrl: (String, TelegramApplicationOpenUrlCompletion) -> Void
    public let canOpenUrl: (String) -> Bool
    public let getTopWindow: () -> UIWindow?
    public let displayNotification: (String) -> Void
    public let applicationInForeground: Signal<Bool, NoError>
    public let applicationIsActive: Signal<Bool, NoError>
    public let clearMessageNotifications: ([MessageId]) -> Void
    public let pushIdleTimerExtension: () -> Disposable
    public let openSettings: () -> Void
    public let openAppStorePage: () -> Void
    public let registerForNotifications: (@escaping (Bool) -> Void) -> Void
    public let requestSiriAuthorization: (@escaping (Bool) -> Void) -> Void
    public let siriAuthorization: () -> AccessType
    public let getWindowHost: () -> WindowHost?
    public let presentNativeController: (UIViewController) -> Void
    public let dismissNativeController: () -> Void
    public let getAvailableAlternateIcons: () -> [PresentationAppIcon]
    public let getAlternateIconName: () -> String?
    public let requestSetAlternateIconName: (String?, @escaping (Bool) -> Void) -> Void
    
    public init(isMainApp: Bool, containerPath: String, appSpecificScheme: String, openUrl: @escaping (String) -> Void, openUniversalUrl: @escaping (String, TelegramApplicationOpenUrlCompletion) -> Void, canOpenUrl: @escaping (String) -> Bool, getTopWindow: @escaping () -> UIWindow?, displayNotification: @escaping (String) -> Void, applicationInForeground: Signal<Bool, NoError>, applicationIsActive: Signal<Bool, NoError>, clearMessageNotifications: @escaping ([MessageId]) -> Void, pushIdleTimerExtension: @escaping () -> Disposable, openSettings: @escaping () -> Void, openAppStorePage: @escaping () -> Void, registerForNotifications: @escaping (@escaping (Bool) -> Void) -> Void, requestSiriAuthorization: @escaping (@escaping (Bool) -> Void) -> Void, siriAuthorization: @escaping () -> AccessType, getWindowHost: @escaping () -> WindowHost?, presentNativeController: @escaping (UIViewController) -> Void, dismissNativeController: @escaping () -> Void, getAvailableAlternateIcons: @escaping () -> [PresentationAppIcon], getAlternateIconName: @escaping () -> String?, requestSetAlternateIconName: @escaping (String?, @escaping (Bool) -> Void) -> Void) {
        self.isMainApp = isMainApp
        self.containerPath = containerPath
        self.appSpecificScheme = appSpecificScheme
        self.openUrl = openUrl
        self.openUniversalUrl = openUniversalUrl
        self.canOpenUrl = canOpenUrl
        self.getTopWindow = getTopWindow
        self.displayNotification = displayNotification
        self.applicationInForeground = applicationInForeground
        self.applicationIsActive = applicationIsActive
        self.clearMessageNotifications = clearMessageNotifications
        self.pushIdleTimerExtension = pushIdleTimerExtension
        self.openSettings = openSettings
        self.openAppStorePage = openAppStorePage
        self.registerForNotifications = registerForNotifications
        self.requestSiriAuthorization = requestSiriAuthorization
        self.siriAuthorization = siriAuthorization
        self.presentNativeController = presentNativeController
        self.dismissNativeController = dismissNativeController
        self.getWindowHost = getWindowHost
        self.getAvailableAlternateIcons = getAvailableAlternateIcons
        self.getAlternateIconName = getAlternateIconName
        self.requestSetAlternateIconName = requestSetAlternateIconName
    }
}

public enum TextLinkItemActionType {
    case tap
    case longTap
}

public enum TextLinkItem {
    case url(String)
    case mention(String)
    case hashtag(String?, String)
}

public final class AccountWithInfo: Equatable {
    public let account: Account
    public let peer: Peer
    
    public init(account: Account, peer: Peer) {
        self.account = account
        self.peer = peer
    }
    
    public static func ==(lhs: AccountWithInfo, rhs: AccountWithInfo) -> Bool {
        if lhs.account !== rhs.account {
            return false
        }
        if !arePeersEqual(lhs.peer, rhs.peer) {
            return false
        }
        return true
    }
}

public enum OpenURLContext {
    case generic
    case chat
}

public struct ChatAvailableMessageActionOptions: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let deleteLocally = ChatAvailableMessageActionOptions(rawValue: 1 << 0)
    public static let deleteGlobally = ChatAvailableMessageActionOptions(rawValue: 1 << 1)
    public static let forward = ChatAvailableMessageActionOptions(rawValue: 1 << 2)
    public static let report = ChatAvailableMessageActionOptions(rawValue: 1 << 3)
    public static let viewStickerPack = ChatAvailableMessageActionOptions(rawValue: 1 << 4)
    public static let rateCall = ChatAvailableMessageActionOptions(rawValue: 1 << 5)
    public static let cancelSending = ChatAvailableMessageActionOptions(rawValue: 1 << 6)
    public static let unsendPersonal = ChatAvailableMessageActionOptions(rawValue: 1 << 7)
    public static let sendScheduledNow = ChatAvailableMessageActionOptions(rawValue: 1 << 8)
    public static let editScheduledTime = ChatAvailableMessageActionOptions(rawValue: 1 << 9)
}

public struct ChatAvailableMessageActions {
    public var options: ChatAvailableMessageActionOptions
    public var banAuthor: Peer?
    
    public init(options: ChatAvailableMessageActionOptions, banAuthor: Peer?) {
        self.options = options
        self.banAuthor = banAuthor
    }
}

public enum WallpaperUrlParameter {
    case slug(String, WallpaperPresentationOptions, UIColor?, UIColor?, Int32?, Int32?)
    case color(UIColor)
    case gradient(UIColor, UIColor, Int32?)
}

public enum ResolvedUrlSettingsSection {
    case theme
    case devices
}

public enum ResolvedUrl {
    case externalUrl(String)
    case peer(PeerId?, ChatControllerInteractionNavigateToPeer)
    case inaccessiblePeer
    case botStart(peerId: PeerId, payload: String)
    case groupBotStart(peerId: PeerId, payload: String)
    case channelMessage(peerId: PeerId, messageId: MessageId)
    case stickerPack(name: String)
    case instantView(TelegramMediaWebpage, String?)
    case proxy(host: String, port: Int32, username: String?, password: String?, secret: Data?)
    case join(String)
    case localization(String)
    case confirmationCode(Int)
    case cancelAccountReset(phone: String, hash: String)
    case share(url: String?, text: String?, to: String?)
    case wallpaper(WallpaperUrlParameter)
    case theme(String)
    #if ENABLE_WALLET
    case wallet(address: String, amount: Int64?, comment: String?)
    #endif
    case settings(ResolvedUrlSettingsSection)
}

public enum NavigateToChatKeepStack {
    case `default`
    case always
    case never
}

public final class NavigateToChatControllerParams {
    public let navigationController: NavigationController
    public let chatController: ChatController?
    public let context: AccountContext
    public let chatLocation: ChatLocation
    public let subject: ChatControllerSubject?
    public let botStart: ChatControllerInitialBotStart?
    public let updateTextInputState: ChatTextInputState?
    public let activateInput: Bool
    public let keepStack: NavigateToChatKeepStack
    public let useExisting: Bool
    public let purposefulAction: (() -> Void)?
    public let scrollToEndIfExists: Bool
    public let activateMessageSearch: Bool
    public let animated: Bool
    public let options: NavigationAnimationOptions
    public let parentGroupId: PeerGroupId?
    public let completion: (ChatController) -> Void
    
    public init(navigationController: NavigationController, chatController: ChatController? = nil, context: AccountContext, chatLocation: ChatLocation, subject: ChatControllerSubject? = nil, botStart: ChatControllerInitialBotStart? = nil, updateTextInputState: ChatTextInputState? = nil, activateInput: Bool = false, keepStack: NavigateToChatKeepStack = .default, useExisting: Bool = true, purposefulAction: (() -> Void)? = nil, scrollToEndIfExists: Bool = false, activateMessageSearch: Bool = false, animated: Bool = true, options: NavigationAnimationOptions = [], parentGroupId: PeerGroupId? = nil, completion: @escaping (ChatController) -> Void = { _ in }) {
        self.navigationController = navigationController
        self.chatController = chatController
        self.context = context
        self.chatLocation = chatLocation
        self.subject = subject
        self.botStart = botStart
        self.updateTextInputState = updateTextInputState
        self.activateInput = activateInput
        self.keepStack = keepStack
        self.useExisting = useExisting
        self.purposefulAction = purposefulAction
        self.scrollToEndIfExists = scrollToEndIfExists
        self.activateMessageSearch = activateMessageSearch
        self.animated = animated
        self.options = options
        self.parentGroupId = parentGroupId
        self.completion = completion
    }
}

public enum DeviceContactInfoSubject {
    case vcard(Peer?, DeviceContactStableId?, DeviceContactExtendedData)
    case filter(peer: Peer?, contactId: DeviceContactStableId?, contactData: DeviceContactExtendedData, completion: (Peer?, DeviceContactExtendedData) -> Void)
    case create(peer: Peer?, contactData: DeviceContactExtendedData, isSharing: Bool, shareViaException: Bool, completion: (Peer?, DeviceContactStableId, DeviceContactExtendedData) -> Void)
    
    public var peer: Peer? {
        switch self {
        case let .vcard(peer, _, _):
            return peer
        case let .filter(peer, _, _, _):
            return peer
        case .create:
            return nil
        }
    }
    
    public var contactData: DeviceContactExtendedData {
        switch self {
        case let .vcard(_, _, data):
            return data
        case let .filter(_, _, data, _):
            return data
        case let .create(_, data, _, _, _):
            return data
        }
    }
}

public enum PeerInfoControllerMode {
    case generic
    case calls(messages: [Message])
    case nearbyPeer
    case group(PeerId)
}

public enum ContactListActionItemInlineIconPosition {
    case left
    case right
}

public enum ContactListActionItemIcon : Equatable {
    case none
    case generic(UIImage)
    case inline(UIImage, ContactListActionItemInlineIconPosition)
    
    public var image: UIImage? {
        switch self {
        case .none:
            return nil
        case let .generic(image):
            return image
        case let .inline(image, _):
            return image
        }
    }
    
    public static func ==(lhs: ContactListActionItemIcon, rhs: ContactListActionItemIcon) -> Bool {
        switch lhs {
        case .none:
            if case .none = rhs {
                return true
            } else {
                return false
            }
        case let .generic(image):
            if case .generic(image) = rhs {
                return true
            } else {
                return false
            }
        case let .inline(image, position):
            if case .inline(image, position) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public struct ContactListAdditionalOption: Equatable {
    public let title: String
    public let icon: ContactListActionItemIcon
    public let action: () -> Void
    
    public init(title: String, icon: ContactListActionItemIcon, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    public static func ==(lhs: ContactListAdditionalOption, rhs: ContactListAdditionalOption) -> Bool {
        return lhs.title == rhs.title && lhs.icon == rhs.icon
    }
}

public enum ContactListPeerId: Hashable {
    case peer(PeerId)
    case deviceContact(DeviceContactStableId)
}

public enum ContactListPeer: Equatable {
    case peer(peer: Peer, isGlobal: Bool, participantCount: Int32?)
    case deviceContact(DeviceContactStableId, DeviceContactBasicData)
    
    public var id: ContactListPeerId {
        switch self {
        case let .peer(peer, _, _):
            return .peer(peer.id)
        case let .deviceContact(id, _):
            return .deviceContact(id)
        }
    }
    
    public var indexName: PeerIndexNameRepresentation {
        switch self {
        case let .peer(peer, _, _):
            return peer.indexName
        case let .deviceContact(_, contact):
            return .personName(first: contact.firstName, last: contact.lastName, addressName: "", phoneNumber: "")
        }
    }
    
    public static func ==(lhs: ContactListPeer, rhs: ContactListPeer) -> Bool {
        switch lhs {
        case let .peer(lhsPeer, lhsIsGlobal, lhsParticipantCount):
            if case let .peer(rhsPeer, rhsIsGlobal, rhsParticipantCount) = rhs, lhsPeer.isEqual(rhsPeer), lhsIsGlobal == rhsIsGlobal, lhsParticipantCount == rhsParticipantCount {
                return true
            } else {
                return false
            }
        case let .deviceContact(id, contact):
            if case .deviceContact(id, contact) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public final class ContactSelectionControllerParams {
    public let context: AccountContext
    public let autoDismiss: Bool
    public let title: (PresentationStrings) -> String
    public let options: [ContactListAdditionalOption]
    public let displayDeviceContacts: Bool
    public let confirmation: (ContactListPeer) -> Signal<Bool, NoError>
    
    public init(context: AccountContext, autoDismiss: Bool = true, title: @escaping (PresentationStrings) -> String, options: [ContactListAdditionalOption] = [], displayDeviceContacts: Bool = false, confirmation: @escaping (ContactListPeer) -> Signal<Bool, NoError> = { _ in .single(true) }) {
        self.context = context
        self.autoDismiss = autoDismiss
        self.title = title
        self.options = options
        self.displayDeviceContacts = displayDeviceContacts
        self.confirmation = confirmation
    }
}

#if ENABLE_WALLET
public enum OpenWalletContext {
    case generic
    case send(address: String, amount: Int64?, comment: String?)
}
#endif

public let defaultContactLabel: String = "_$!<Mobile>!$_"

public enum CreateGroupMode {
    case generic
    case supergroup
    case locatedGroup(latitude: Double, longitude: Double, address: String?)
}

public protocol AppLockContext: class {
    var invalidAttempts: Signal<AccessChallengeAttempts?, NoError> { get }
    var autolockDeadline: Signal<Int32?, NoError> { get }
    
    func lock()
    func unlock()
    func failedUnlockAttempt()
}

public protocol RecentSessionsController: class {
}

public protocol SharedAccountContext: class {
    var basePath: String { get }
    var mainWindow: Window1? { get }
    var accountManager: AccountManager { get }
    var appLockContext: AppLockContext { get }
    
    var currentPresentationData: Atomic<PresentationData> { get }
    var presentationData: Signal<PresentationData, NoError> { get }
    
    var currentAutomaticMediaDownloadSettings: Atomic<MediaAutoDownloadSettings> { get }
    var automaticMediaDownloadSettings: Signal<MediaAutoDownloadSettings, NoError> { get }
    var currentAutodownloadSettings: Atomic<AutodownloadSettings> { get }
    var immediateExperimentalUISettings: ExperimentalUISettings { get }
    var currentInAppNotificationSettings: Atomic<InAppNotificationSettings> { get }
    var currentMediaInputSettings: Atomic<MediaInputSettings> { get }
    
    var applicationBindings: TelegramApplicationBindings { get }
    
    var mediaManager: MediaManager { get }
    var locationManager: DeviceLocationManager? { get }
    var callManager: PresentationCallManager? { get }
    var contactDataManager: DeviceContactDataManager? { get }
    
    var activeAccounts: Signal<(primary: Account?, accounts: [(AccountRecordId, Account, Int32)], currentAuth: UnauthorizedAccount?), NoError> { get }
    var activeAccountsWithInfo: Signal<(primary: AccountRecordId?, accounts: [AccountWithInfo]), NoError> { get }
    
    var presentGlobalController: (ViewController, Any?) -> Void { get }
    
    func makeTempAccountContext(account: Account) -> AccountContext
    
    func updateNotificationTokensRegistration()
    func setAccountUserInterfaceInUse(_ id: AccountRecordId) -> Disposable
    func handleTextLinkAction(context: AccountContext, peerId: PeerId?, navigateDisposable: MetaDisposable, controller: ViewController, action: TextLinkItemActionType, itemLink: TextLinkItem)
    func navigateToChat(accountId: AccountRecordId, peerId: PeerId, messageId: MessageId?)
    func openChatMessage(_ params: OpenChatMessageParams) -> Bool
    func messageFromPreloadedChatHistoryViewForLocation(id: MessageId, location: ChatHistoryLocationInput, account: Account, chatLocation: ChatLocation, tagMask: MessageTags?) -> Signal<(MessageIndex?, Bool), NoError>
    func makeOverlayAudioPlayerController(context: AccountContext, peerId: PeerId, type: MediaManagerPlayerType, initialMessageId: MessageId, initialOrder: MusicPlaybackSettingsOrder, parentNavigationController: NavigationController?) -> ViewController & OverlayAudioPlayerController
    func makePeerInfoController(context: AccountContext, peer: Peer, mode: PeerInfoControllerMode, avatarInitiallyExpanded: Bool, fromChat: Bool) -> ViewController?
    func makeDeviceContactInfoController(context: AccountContext, subject: DeviceContactInfoSubject, completed: (() -> Void)?, cancelled: (() -> Void)?) -> ViewController
    func makePeersNearbyController(context: AccountContext) -> ViewController
    func makeComposeController(context: AccountContext) -> ViewController
    func makeChatListController(context: AccountContext, groupId: PeerGroupId, controlsHistoryPreload: Bool, hideNetworkActivityStatus: Bool, previewing: Bool, enableDebugActions: Bool) -> ChatListController
    func makeChatController(context: AccountContext, chatLocation: ChatLocation, subject: ChatControllerSubject?, botStart: ChatControllerInitialBotStart?, mode: ChatControllerPresentationMode) -> ChatController
    func makeChatMessagePreviewItem(context: AccountContext, message: Message, theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, chatBubbleCorners: PresentationChatBubbleCorners, dateTimeFormat: PresentationDateTimeFormat, nameOrder: PresentationPersonNameOrder, forcedResourceStatus: FileMediaResourceStatus?, tapMessage: ((Message) -> Void)?, clickThroughMessage: (() -> Void)?) -> ListViewItem
    func makeChatMessageDateHeaderItem(context: AccountContext, timestamp: Int32, theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, chatBubbleCorners: PresentationChatBubbleCorners, dateTimeFormat: PresentationDateTimeFormat, nameOrder: PresentationPersonNameOrder) -> ListViewItemHeader
    func makePeerSharedMediaController(context: AccountContext, peerId: PeerId) -> ViewController?
    func makeContactSelectionController(_ params: ContactSelectionControllerParams) -> ContactSelectionController
    func makeContactMultiselectionController(_ params: ContactMultiselectionControllerParams) -> ContactMultiselectionController
    func makePeerSelectionController(_ params: PeerSelectionControllerParams) -> PeerSelectionController
    func makeProxySettingsController(context: AccountContext) -> ViewController
    func makeLocalizationListController(context: AccountContext) -> ViewController
    func makeCreateGroupController(context: AccountContext, peerIds: [PeerId], initialTitle: String?, mode: CreateGroupMode, completion: ((PeerId, @escaping () -> Void) -> Void)?) -> ViewController
    func makeChatRecentActionsController(context: AccountContext, peer: Peer) -> ViewController
    func navigateToChatController(_ params: NavigateToChatControllerParams)
    func openExternalUrl(context: AccountContext, urlContext: OpenURLContext, url: String, forceExternal: Bool, presentationData: PresentationData, navigationController: NavigationController?, dismissInput: @escaping () -> Void)
    func chatAvailableMessageActions(postbox: Postbox, accountPeerId: PeerId, messageIds: Set<MessageId>) -> Signal<ChatAvailableMessageActions, NoError>
    func resolveUrl(account: Account, url: String) -> Signal<ResolvedUrl, NoError>
    func openResolvedUrl(_ resolvedUrl: ResolvedUrl, context: AccountContext, urlContext: OpenURLContext, navigationController: NavigationController?, openPeer: @escaping (PeerId, ChatControllerInteractionNavigateToPeer) -> Void, sendFile: ((FileMediaReference) -> Void)?, sendSticker: ((FileMediaReference, ASDisplayNode, CGRect) -> Bool)?, present: @escaping (ViewController, Any?) -> Void, dismissInput: @escaping () -> Void, contentContext: Any?)
    func openAddContact(context: AccountContext, firstName: String, lastName: String, phoneNumber: String, label: String, present: @escaping (ViewController, Any?) -> Void, pushController: @escaping (ViewController) -> Void, completed: @escaping () -> Void)
    func openAddPersonContact(context: AccountContext, peerId: PeerId, pushController: @escaping (ViewController) -> Void, present: @escaping (ViewController, Any?) -> Void)
    func presentContactsWarningSuppression(context: AccountContext, present: (ViewController, Any?) -> Void)
    #if ENABLE_WALLET
    func openWallet(context: AccountContext, walletContext: OpenWalletContext, present: @escaping (ViewController) -> Void)
    #endif
    func openImagePicker(context: AccountContext, completion: @escaping (UIImage) -> Void, present: @escaping (ViewController) -> Void)
    
    func makeRecentSessionsController(context: AccountContext, activeSessionsContext: ActiveSessionsContext) -> ViewController & RecentSessionsController
    
    func navigateToCurrentCall()
    var hasOngoingCall: ValuePromise<Bool> { get }
    var immediateHasOngoingCall: Bool { get }
    
    func switchToAccount(id: AccountRecordId, fromSettingsController settingsController: ViewController?, withChatListController chatListController: ViewController?)
    func beginNewAuth(testingEnvironment: Bool)
}

#if ENABLE_WALLET
private final class TonInstanceData {
    var config: String?
    var blockchainName: String?
    var instance: TonInstance?
}

private final class TonNetworkProxyImpl: TonNetworkProxy {
    private let network: Network
    
    init(network: Network) {
        self.network = network
    }
    
    func request(data: Data, timeout timeoutValue: Double, completion: @escaping (TonNetworkProxyResult) -> Void) -> Disposable {
        return (walletProxyRequest(network: self.network, data: data)
        |> timeout(timeoutValue, queue: .concurrentDefaultQueue(), alternate: .fail(.generic(500, "Local Timeout")))).start(next: { data in
            completion(.reponse(data))
        }, error: { error in
            switch error {
            case let .generic(_, text):
                completion(.error(text))
            }
        })
    }
}

public final class StoredTonContext {
    private let basePath: String
    private let postbox: Postbox
    private let network: Network
    public let keychain: TonKeychain
    private let currentInstance = Atomic<TonInstanceData>(value: TonInstanceData())
    
    public init(basePath: String, postbox: Postbox, network: Network, keychain: TonKeychain) {
        self.basePath = basePath
        self.postbox = postbox
        self.network = network
        self.keychain = keychain
    }
    
    public func context(config: String, blockchainName: String, enableProxy: Bool) -> TonContext {
        return self.currentInstance.with { data -> TonContext in
            if let instance = data.instance, data.config == config, data.blockchainName == blockchainName {
                return TonContext(instance: instance, keychain: self.keychain)
            } else {
                data.config = config
                let instance = TonInstance(basePath: self.basePath, config: config, blockchainName: blockchainName, proxy: enableProxy ? TonNetworkProxyImpl(network: self.network) : nil)
                data.instance = instance
                return TonContext(instance: instance, keychain: self.keychain)
            }
        }
    }
}

public final class TonContext {
    public let instance: TonInstance
    public let keychain: TonKeychain
    
    fileprivate init(instance: TonInstance, keychain: TonKeychain) {
        self.instance = instance
        self.keychain = keychain
    }
}

#endif

public protocol AccountContext: class {
    var sharedContext: SharedAccountContext { get }
    var account: Account { get }
    
    #if ENABLE_WALLET
    var tonContext: StoredTonContext? { get }
    #endif
    
    var liveLocationManager: LiveLocationManager? { get }
    var peersNearbyManager: PeersNearbyManager? { get }
    var fetchManager: FetchManager { get }
    var downloadedMediaStoreManager: DownloadedMediaStoreManager { get }
    var peerChannelMemberCategoriesContextsManager: PeerChannelMemberCategoriesContextsManager { get }
    var wallpaperUploadManager: WallpaperUploadManager? { get }
    var watchManager: WatchManager? { get }
    
    #if ENABLE_WALLET
    var hasWallets: Signal<Bool, NoError> { get }
    var hasWalletAccess: Signal<Bool, NoError> { get }
    #endif
    
    var currentLimitsConfiguration: Atomic<LimitsConfiguration> { get }
    var currentContentSettings: Atomic<ContentSettings> { get }
    
    func storeSecureIdPassword(password: String)
    func getStoredSecureIdPassword() -> String?
}
