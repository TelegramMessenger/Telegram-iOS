import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import SwiftSignalKit
import AsyncDisplayKit
import Display
import DeviceLocationManager
import TemporaryCachedPeerDataManager
import InAppPurchaseManager
import AnimationCache
import MultiAnimationRenderer
import Photos
import TextFormat

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
    case limited
}

public enum TelegramAppBuildType {
    case `internal`
    case `public`
}

public final class TelegramApplicationBindings {
    public let isMainApp: Bool
    public let appBundleId: String
    public let appBuildType: TelegramAppBuildType
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
    public let openSubscriptions: () -> Void
    public let registerForNotifications: (@escaping (Bool) -> Void) -> Void
    public let requestSiriAuthorization: (@escaping (Bool) -> Void) -> Void
    public let siriAuthorization: () -> AccessType
    public let getWindowHost: () -> WindowHost?
    public let presentNativeController: (UIViewController) -> Void
    public let dismissNativeController: () -> Void
    public let getAvailableAlternateIcons: () -> [PresentationAppIcon]
    public let getAlternateIconName: () -> String?
    public let requestSetAlternateIconName: (String?, @escaping (Bool) -> Void) -> Void
    public let forceOrientation: (UIInterfaceOrientation) -> Void
    
    public init(isMainApp: Bool, appBundleId: String, appBuildType: TelegramAppBuildType, containerPath: String, appSpecificScheme: String, openUrl: @escaping (String) -> Void, openUniversalUrl: @escaping (String, TelegramApplicationOpenUrlCompletion) -> Void, canOpenUrl: @escaping (String) -> Bool, getTopWindow: @escaping () -> UIWindow?, displayNotification: @escaping (String) -> Void, applicationInForeground: Signal<Bool, NoError>, applicationIsActive: Signal<Bool, NoError>, clearMessageNotifications: @escaping ([MessageId]) -> Void, pushIdleTimerExtension: @escaping () -> Disposable, openSettings: @escaping () -> Void, openAppStorePage: @escaping () -> Void, openSubscriptions: @escaping () -> Void, registerForNotifications: @escaping (@escaping (Bool) -> Void) -> Void, requestSiriAuthorization: @escaping (@escaping (Bool) -> Void) -> Void, siriAuthorization: @escaping () -> AccessType, getWindowHost: @escaping () -> WindowHost?, presentNativeController: @escaping (UIViewController) -> Void, dismissNativeController: @escaping () -> Void, getAvailableAlternateIcons: @escaping () -> [PresentationAppIcon], getAlternateIconName: @escaping () -> String?, requestSetAlternateIconName: @escaping (String?, @escaping (Bool) -> Void) -> Void, forceOrientation: @escaping (UIInterfaceOrientation) -> Void) {
        self.isMainApp = isMainApp
        self.appBundleId = appBundleId
        self.appBuildType = appBuildType
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
        self.openSubscriptions = openSubscriptions
        self.registerForNotifications = registerForNotifications
        self.requestSiriAuthorization = requestSiriAuthorization
        self.siriAuthorization = siriAuthorization
        self.presentNativeController = presentNativeController
        self.dismissNativeController = dismissNativeController
        self.getWindowHost = getWindowHost
        self.getAvailableAlternateIcons = getAvailableAlternateIcons
        self.getAlternateIconName = getAlternateIconName
        self.requestSetAlternateIconName = requestSetAlternateIconName
        self.forceOrientation = forceOrientation
    }
}

public enum TextLinkItemActionType {
    case tap
    case longTap
}

public enum TextLinkItem: Equatable {
    case url(url: String, concealed: Bool)
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
    case chat(peerId: PeerId, message: Message?, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?)
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
    public static let externalShare = ChatAvailableMessageActionOptions(rawValue: 1 << 10)
    public static let sendGift = ChatAvailableMessageActionOptions(rawValue: 1 << 11)
}

public struct ChatAvailableMessageActions {
    public var options: ChatAvailableMessageActionOptions
    public var banAuthor: Peer?
    public var banAuthors: [Peer]
    public var disableDelete: Bool
    public var isCopyProtected: Bool
    public var setTag: Bool
    public var editTags: Set<MessageReaction.Reaction>
    
    public init(options: ChatAvailableMessageActionOptions, banAuthor: Peer?, banAuthors: [Peer], disableDelete: Bool, isCopyProtected: Bool, setTag: Bool, editTags: Set<MessageReaction.Reaction>) {
        self.options = options
        self.banAuthor = banAuthor
        self.banAuthors = banAuthors
        self.disableDelete = disableDelete
        self.isCopyProtected = isCopyProtected
        self.setTag = setTag
        self.editTags = editTags
    }
}

public enum WallpaperUrlParameter {
    case slug(String, WallpaperPresentationOptions, [UInt32], Int32?, Int32?)
    case color(UIColor)
    case gradient([UInt32], Int32?)
}

public enum ResolvedUrlSettingsSection {
    case theme
    case devices
    case autoremoveMessages
    case twoStepAuth
    case enableLog
    case phonePrivacy
}

public struct ResolvedBotChoosePeerTypes: OptionSet {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let users = ResolvedBotChoosePeerTypes(rawValue: 1)
    public static let bots = ResolvedBotChoosePeerTypes(rawValue: 2)
    public static let groups = ResolvedBotChoosePeerTypes(rawValue: 4)
    public static let channels = ResolvedBotChoosePeerTypes(rawValue: 16)
}

public struct ResolvedBotAdminRights: OptionSet {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let changeInfo = ResolvedBotAdminRights(rawValue: 1)
    public static let postMessages = ResolvedBotAdminRights(rawValue: 2)
    public static let editMessages = ResolvedBotAdminRights(rawValue: 4)
    public static let deleteMessages = ResolvedBotAdminRights(rawValue: 16)
    public static let restrictMembers = ResolvedBotAdminRights(rawValue: 32)
    public static let inviteUsers = ResolvedBotAdminRights(rawValue: 64)
    public static let pinMessages = ResolvedBotAdminRights(rawValue: 128)
    public static let promoteMembers = ResolvedBotAdminRights(rawValue: 256)
    public static let manageVideoChats = ResolvedBotAdminRights(rawValue: 512)
    public static let canBeAnonymous = ResolvedBotAdminRights(rawValue: 1024)
    public static let manageChat = ResolvedBotAdminRights(rawValue: 2048)
    
    public var chatAdminRights: TelegramChatAdminRightsFlags? {
        var flags = TelegramChatAdminRightsFlags()
        
        if self.contains(ResolvedBotAdminRights.changeInfo) {
            flags.insert(.canChangeInfo)
        }
        if self.contains(ResolvedBotAdminRights.postMessages) {
            flags.insert(.canPostMessages)
        }
        if self.contains(ResolvedBotAdminRights.editMessages) {
            flags.insert(.canEditMessages)
        }
        if self.contains(ResolvedBotAdminRights.deleteMessages) {
            flags.insert(.canDeleteMessages)
        }
        if self.contains(ResolvedBotAdminRights.restrictMembers) {
            flags.insert(.canBanUsers)
        }
        if self.contains(ResolvedBotAdminRights.inviteUsers) {
            flags.insert(.canInviteUsers)
        }
        if self.contains(ResolvedBotAdminRights.pinMessages) {
            flags.insert(.canPinMessages)
        }
        if self.contains(ResolvedBotAdminRights.promoteMembers) {
            flags.insert(.canAddAdmins)
        }
        if self.contains(ResolvedBotAdminRights.manageVideoChats) {
            flags.insert(.canManageCalls)
        }
        if self.contains(ResolvedBotAdminRights.canBeAnonymous) {
            flags.insert(.canBeAnonymous)
        }
        
        if flags.isEmpty && !self.contains(ResolvedBotAdminRights.manageChat) {
            return nil
        }
        
        return flags
    }
}

public enum StickerPackUrlType {
    case stickers
    case emoji
}

public enum ResolvedStartAppMode {
    case generic
    case compact
    case fullscreen
}

public enum ResolvedBotStartPeerType {
    case group
    case channel
}

public enum ResolvedUrl {
    case externalUrl(String)
    case urlAuth(String)
    case peer(Peer?, ChatControllerInteractionNavigateToPeer)
    case inaccessiblePeer
    case botStart(peer: Peer, payload: String)
    case groupBotStart(peerId: PeerId, payload: String, adminRights: ResolvedBotAdminRights?, peerType: ResolvedBotStartPeerType?)
    case gameStart(peerId: PeerId, game: String)
    case channelMessage(peer: Peer, messageId: MessageId, timecode: Double?)
    case replyThreadMessage(replyThreadMessage: ChatReplyThreadMessage, messageId: MessageId)
    case replyThread(messageId: MessageId)
    case stickerPack(name: String, type: StickerPackUrlType)
    case instantView(TelegramMediaWebpage, String?)
    case proxy(host: String, port: Int32, username: String?, password: String?, secret: Data?)
    case join(String)
    case joinCall(String)
    case localization(String)
    case confirmationCode(Int)
    case cancelAccountReset(phone: String, hash: String)
    case share(url: String?, text: String?, to: String?)
    case wallpaper(WallpaperUrlParameter)
    case theme(String)
    case settings(ResolvedUrlSettingsSection)
    case joinVoiceChat(PeerId, String?)
    case importStickers
    case startAttach(peerId: PeerId, payload: String?, choose: ResolvedBotChoosePeerTypes?)
    case invoice(slug: String, invoice: TelegramMediaInvoice?)
    case premiumOffer(reference: String?)
    case starsTopup(amount: Int64, purpose: String?)
    case chatFolder(slug: String)
    case story(peerId: PeerId, id: Int32)
    case boost(peerId: PeerId?, status: ChannelBoostStatus?, myBoostStatus: MyBoostStatus?)
    case premiumGiftCode(slug: String)
    case premiumMultiGift(reference: String?)
    case collectible(gift: StarGift.UniqueGift?)
    case messageLink(link: TelegramResolvedMessageLink?)
    case stars
    case shareStory(Int64)
}

public enum ResolveUrlResult {
    case progress
    case result(ResolvedUrl)
}

public enum NavigateToChatKeepStack {
    case `default`
    case always
    case never
}

public final class ChatPeekTimeout {
    public let deadline: Int32
    public let linkData: String
    
    public init(deadline: Int32, linkData: String) {
        self.deadline = deadline
        self.linkData = linkData
    }
}

public final class ChatPeerNearbyData: Equatable {
    public static func == (lhs: ChatPeerNearbyData, rhs: ChatPeerNearbyData) -> Bool {
        return lhs.distance == rhs.distance
    }
    
    public let distance: Int32
    
    public init(distance: Int32) {
        self.distance = distance
    }
}

public final class ChatGreetingData: Equatable {
    public static func == (lhs: ChatGreetingData, rhs: ChatGreetingData) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    
    public let uuid: UUID
    public let sticker: Signal<TelegramMediaFile?, NoError>
    
    public init(uuid: UUID, sticker: Signal<TelegramMediaFile?, NoError>) {
        self.uuid = uuid
        self.sticker = sticker
    }
}

public enum ChatSearchDomain: Equatable {
    case everything
    case members
    case member(Peer)
    case tag(MessageReaction.Reaction)
    
    public static func ==(lhs: ChatSearchDomain, rhs: ChatSearchDomain) -> Bool {
        switch lhs {
        case .everything:
            if case .everything = rhs {
                return true
            } else {
                return false
            }
        case .members:
            if case .members = rhs {
                return true
            } else {
                return false
            }
        case let .member(lhsPeer):
            if case let .member(rhsPeer) = rhs, lhsPeer.isEqual(rhsPeer) {
                return true
            } else {
                return false
            }
        case let .tag(reaction):
            if case .tag(reaction) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public enum ChatLocation: Equatable {
    case peer(id: PeerId)
    case replyThread(message: ChatReplyThreadMessage)
    case customChatContents
}

public extension ChatLocation {
    var normalized: ChatLocation {
        switch self {
        case .peer, .customChatContents:
            return self
        case let .replyThread(message):
            return .replyThread(message: message.normalized)
        }
    }
    
    var peerId: PeerId? {
        switch self {
        case let .peer(peerId):
            return peerId
        case let .replyThread(replyThreadMessage):
            return replyThreadMessage.peerId
        case .customChatContents:
            return nil
        }
    }
    
    var threadId: Int64? {
        switch self {
        case .peer:
            return nil
        case let .replyThread(replyThreadMessage):
            return replyThreadMessage.threadId
        case .customChatContents:
            return nil
        }
    }
}

public enum ChatControllerActivateInput {
    case text
    case entityInput
}

public struct ChatNavigationStackItem: Hashable {
    public var peerId: EnginePeer.Id
    public var threadId: Int64?
    
    public init(peerId: EnginePeer.Id, threadId: Int64?) {
        self.peerId = peerId
        self.threadId = threadId
    }
}

public final class NavigateToChatControllerParams {
    public enum Location {
        case peer(EnginePeer)
        case replyThread(ChatReplyThreadMessage)
        
        public var peerId: EnginePeer.Id {
            switch self {
            case let .peer(peer):
                return peer.id
            case let .replyThread(message):
                return message.peerId
            }
        }
        
        public var threadId: Int64? {
            switch self {
            case .peer:
                return nil
            case let .replyThread(message):
                return message.threadId
            }
        }
        
        public var asChatLocation: ChatLocation {
            switch self {
            case let .peer(peer):
                return .peer(id: peer.id)
            case let .replyThread(message):
                return .replyThread(message: message)
            }
        }
    }
    
    public struct ReportReason {
        public let title: String
        public let option: Data
        public let message: String?
        
        public init(title: String, option: Data, message: String?) {
            self.title = title
            self.option = option
            self.message = message
        }
    }
    
    public let navigationController: NavigationController
    public let chatController: ChatController?
    public let context: AccountContext
    public let chatLocation: Location
    public let chatLocationContextHolder: Atomic<ChatLocationContextHolder?>
    public let subject: ChatControllerSubject?
    public let botStart: ChatControllerInitialBotStart?
    public let attachBotStart: ChatControllerInitialAttachBotStart?
    public let botAppStart: ChatControllerInitialBotAppStart?
    public let updateTextInputState: ChatTextInputState?
    public let activateInput: ChatControllerActivateInput?
    public let keepStack: NavigateToChatKeepStack
    public let useExisting: Bool
    public let useBackAnimation: Bool
    public let purposefulAction: (() -> Void)?
    public let scrollToEndIfExists: Bool
    public let activateMessageSearch: (ChatSearchDomain, String)?
    public let peekData: ChatPeekTimeout?
    public let peerNearbyData: ChatPeerNearbyData?
    public let reportReason: NavigateToChatControllerParams.ReportReason?
    public let animated: Bool
    public let forceAnimatedScroll: Bool
    public let options: NavigationAnimationOptions
    public let parentGroupId: PeerGroupId?
    public let chatListFilter: Int32?
    public let chatNavigationStack: [ChatNavigationStackItem]
    public let changeColors: Bool
    public let setupController: (ChatController) -> Void
    public let completion: (ChatController) -> Void
    public let chatListCompletion: ((ChatListController) -> Void)?
    public let pushController: ((ChatController, Bool, @escaping () -> Void) -> Void)?
    public let forceOpenChat: Bool
    public let customChatNavigationStack: [EnginePeer.Id]?
    
    public init(navigationController: NavigationController, chatController: ChatController? = nil, context: AccountContext, chatLocation: Location, chatLocationContextHolder: Atomic<ChatLocationContextHolder?> = Atomic<ChatLocationContextHolder?>(value: nil), subject: ChatControllerSubject? = nil, botStart: ChatControllerInitialBotStart? = nil, attachBotStart: ChatControllerInitialAttachBotStart? = nil, botAppStart: ChatControllerInitialBotAppStart? = nil, updateTextInputState: ChatTextInputState? = nil, activateInput: ChatControllerActivateInput? = nil, keepStack: NavigateToChatKeepStack = .default, useExisting: Bool = true, useBackAnimation: Bool = false, purposefulAction: (() -> Void)? = nil, scrollToEndIfExists: Bool = false, activateMessageSearch: (ChatSearchDomain, String)? = nil, peekData: ChatPeekTimeout? = nil, peerNearbyData: ChatPeerNearbyData? = nil, reportReason: NavigateToChatControllerParams.ReportReason? = nil, animated: Bool = true, forceAnimatedScroll: Bool = false, options: NavigationAnimationOptions = [], parentGroupId: PeerGroupId? = nil, chatListFilter: Int32? = nil, chatNavigationStack: [ChatNavigationStackItem] = [], changeColors: Bool = false, setupController: @escaping (ChatController) -> Void = { _ in }, pushController: ((ChatController, Bool, @escaping () -> Void) -> Void)? = nil, completion: @escaping (ChatController) -> Void = { _ in }, chatListCompletion: @escaping (ChatListController) -> Void = { _ in }, forceOpenChat: Bool = false, customChatNavigationStack: [EnginePeer.Id]? = nil) {
        self.navigationController = navigationController
        self.chatController = chatController
        self.chatLocationContextHolder = chatLocationContextHolder
        self.context = context
        self.chatLocation = chatLocation
        self.subject = subject
        self.botStart = botStart
        self.attachBotStart = attachBotStart
        self.botAppStart = botAppStart
        self.updateTextInputState = updateTextInputState
        self.activateInput = activateInput
        self.keepStack = keepStack
        self.useExisting = useExisting
        self.useBackAnimation = useBackAnimation
        self.purposefulAction = purposefulAction
        self.scrollToEndIfExists = scrollToEndIfExists
        self.activateMessageSearch = activateMessageSearch
        self.peekData = peekData
        self.peerNearbyData = peerNearbyData
        self.reportReason = reportReason
        self.animated = animated
        self.forceAnimatedScroll = forceAnimatedScroll
        self.options = options
        self.parentGroupId = parentGroupId
        self.chatListFilter = chatListFilter
        self.chatNavigationStack = chatNavigationStack
        self.changeColors = changeColors
        self.setupController = setupController
        self.pushController = pushController
        self.completion = completion
        self.chatListCompletion = chatListCompletion
        self.forceOpenChat = forceOpenChat
        self.customChatNavigationStack = customChatNavigationStack
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
    case nearbyPeer(distance: Int32)
    case group(PeerId)
    case reaction(MessageId)
    case forumTopic(thread: ChatReplyThreadMessage)
    case recommendedChannels
    case myProfile
    case gifts
    case myProfileGifts
    case groupsInCommon
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

public enum ChatListSearchFilter: Equatable {
    case chats
    case topics
    case channels
    case apps
    case media
    case downloads
    case links
    case files
    case music
    case voice
    case instantVideo
    case peer(PeerId, Bool, String, String)
    case date(Int32?, Int32, String)
    case publicPosts
    
    public var id: Int64 {
        switch self {
        case .chats:
            return 0
        case .topics:
            return 1
        case .channels:
            return 2
        case .apps:
            return 3
        case .media:
            return 4
        case .downloads:
            return 5
        case .links:
            return 6
        case .files:
            return 7
        case .music:
            return 8
        case .voice:
            return 9
        case .instantVideo:
            return 10
        case .publicPosts:
            return 11
        case let .peer(peerId, _, _, _):
            return peerId.id._internalGetInt64Value()
        case let .date(_, date, _):
            return Int64(date)
        }
    }
}

public enum InstalledStickerPacksControllerMode {
    case general
    case modal
    case masks
    case emoji
}

public let defaultContactLabel: String = "_$!<Mobile>!$_"

public enum CreateGroupMode {
    case generic
    case supergroup
    case locatedGroup(latitude: Double, longitude: Double, address: String?)
    case requestPeer(ReplyMarkupButtonRequestPeerType.Group)
}

public protocol AppLockContext: AnyObject {
    var invalidAttempts: Signal<AccessChallengeAttempts?, NoError> { get }
    var autolockDeadline: Signal<Int32?, NoError> { get }
    
    func lock()
    func unlock()
    func failedUnlockAttempt()
}

public protocol RecentSessionsController: AnyObject {
}

public protocol AttachmentFileController: AnyObject {
}

public struct StoryCameraTransitionIn {
    public weak var sourceView: UIView?
    public let sourceRect: CGRect
    public let sourceCornerRadius: CGFloat
    public let useFillAnimation: Bool
    
    public init(
        sourceView: UIView,
        sourceRect: CGRect,
        sourceCornerRadius: CGFloat,
        useFillAnimation: Bool
    ) {
        self.sourceView = sourceView
        self.sourceRect = sourceRect
        self.sourceCornerRadius = sourceCornerRadius
        self.useFillAnimation = useFillAnimation
    }
}

public struct StoryCameraTransitionOut {
    public weak var destinationView: UIView?
    public let destinationRect: CGRect
    public let destinationCornerRadius: CGFloat
    public let completion: (() -> Void)?
    
    public init(
        destinationView: UIView,
        destinationRect: CGRect,
        destinationCornerRadius: CGFloat,
        completion: (() -> Void)? = nil
    ) {
        self.destinationView = destinationView
        self.destinationRect = destinationRect
        self.destinationCornerRadius = destinationCornerRadius
        self.completion = completion
    }
}

public struct StoryCameraTransitionInCoordinator {
    public let animateIn: () -> Void
    public let updateTransitionProgress: (CGFloat) -> Void
    public let completeWithTransitionProgressAndVelocity: (CGFloat, CGFloat) -> Void
    
    public init(
        animateIn: @escaping () -> Void,
        updateTransitionProgress: @escaping (CGFloat) -> Void,
        completeWithTransitionProgressAndVelocity: @escaping (CGFloat, CGFloat) -> Void
    ) {
        self.animateIn = animateIn
        self.updateTransitionProgress = updateTransitionProgress
        self.completeWithTransitionProgressAndVelocity = completeWithTransitionProgressAndVelocity
    }
}

public class MediaEditorTransitionOutExternalState {
    public var storyTarget: Stories.PendingTarget?
    public var isForcedTarget: Bool
    public var isPeerArchived: Bool
    public var transitionOut: ((Stories.PendingTarget?, Bool) -> StoryCameraTransitionOut?)?
    
    public init(storyTarget: Stories.PendingTarget?, isForcedTarget: Bool,  isPeerArchived: Bool, transitionOut: ((Stories.PendingTarget?, Bool) -> StoryCameraTransitionOut?)?) {
        self.storyTarget = storyTarget
        self.isForcedTarget = isForcedTarget
        self.isPeerArchived = isPeerArchived
        self.transitionOut = transitionOut
    }
}

public protocol CameraScreen: ViewController {
    
}

public protocol MediaEditorScreen: ViewController {
}

public protocol MediaPickerScreen: ViewController {
    func dismissAnimated()
}

public protocol ChatQrCodeScreen: ViewController {
}

public protocol MediaEditorScreenResult {
    var target: Stories.PendingTarget { get }
}

public protocol TelegramRootControllerInterface: NavigationController {
    @discardableResult
    func openStoryCamera(customTarget: Stories.PendingTarget?, transitionIn: StoryCameraTransitionIn?, transitionedIn: @escaping () -> Void, transitionOut: @escaping (Stories.PendingTarget?, Bool) -> StoryCameraTransitionOut?) -> StoryCameraTransitionInCoordinator?
    func proceedWithStoryUpload(target: Stories.PendingTarget, results: [MediaEditorScreenResult], existingMedia: EngineMedia?, forwardInfo: Stories.PendingForwardInfo?, externalState: MediaEditorTransitionOutExternalState, commit: @escaping (@escaping () -> Void) -> Void)
    
    func getContactsController() -> ViewController?
    func getChatsController() -> ViewController?
    func getPrivacySettings() -> Promise<AccountPrivacySettings?>?
    func openSettings()
    func openBirthdaySetup()
    func openPhotoSetup(completedWithUploadingImage: @escaping (UIImage, Signal<PeerInfoAvatarUploadStatus, NoError>) -> UIView?)
    func openAvatars()
}

public protocol QuickReplySetupScreenInitialData: AnyObject {
}

public protocol AutomaticBusinessMessageSetupScreenInitialData: AnyObject {
}

public protocol ChatbotSetupScreenInitialData: AnyObject {
}

public protocol BusinessIntroSetupScreenInitialData: AnyObject {
}

public protocol CollectibleItemInfoScreenInitialData: AnyObject {
    var collectibleItemInfo: TelegramCollectibleItemInfo { get }
}

public protocol BusinessLinksSetupScreenInitialData: AnyObject {
}

public enum AffiliateProgramSetupScreenMode {
    case editProgram
    case connectedPrograms
}

public protocol AffiliateProgramSetupScreenInitialData: AnyObject {
}

public enum CollectibleItemInfoScreenSubject {
    case phoneNumber(String)
    case username(String)
}


public enum StorySearchControllerScope {
    case query(EnginePeer?, String)
    case location(coordinates: MediaArea.Coordinates, venue: MediaArea.Venue)
}

public struct ChatControllerParams {
    public let forcedTheme: PresentationTheme?
    public let forcedNavigationBarTheme: PresentationTheme?
    public let forcedWallpaper: TelegramWallpaper?
    
    public init(
        forcedTheme: PresentationTheme? = nil,
        forcedNavigationBarTheme: PresentationTheme? = nil,
        forcedWallpaper: TelegramWallpaper? = nil
    ) {
        self.forcedTheme = forcedTheme
        self.forcedNavigationBarTheme = forcedNavigationBarTheme
        self.forcedWallpaper = forcedWallpaper
    }
}

public enum ChatOpenWebViewSource: Equatable {
    case generic
    case menu
    case inline(bot: EnginePeer)
}

public final class BotPreviewEditorTransitionOut {
    public weak var destinationView: UIView?
    public let destinationRect: CGRect
    public let destinationCornerRadius: CGFloat
    public let completion: (() -> Void)?
    
    public init(destinationView: UIView?, destinationRect: CGRect, destinationCornerRadius: CGFloat, completion: (() -> Void)?) {
        self.destinationView = destinationView
        self.destinationRect = destinationRect
        self.destinationCornerRadius = destinationCornerRadius
        self.completion = completion
    }
}

public protocol MiniAppListScreenInitialData: AnyObject {
}

public enum JoinAffiliateProgramScreenMode {
    public final class Join {
        public let initialTargetPeer: EnginePeer
        public let canSelectTargetPeer: Bool
        public let completion: (EnginePeer) -> Void
        
        public init(initialTargetPeer: EnginePeer, canSelectTargetPeer: Bool, completion: @escaping (EnginePeer) -> Void) {
            self.initialTargetPeer = initialTargetPeer
            self.canSelectTargetPeer = canSelectTargetPeer
            self.completion = completion
        }
    }

    public final class Active {
        public let targetPeer: EnginePeer
        public let bot: EngineConnectedStarRefBotsContext.Item
        public let copyLink: (EngineConnectedStarRefBotsContext.Item) -> Void
        
        public init(targetPeer: EnginePeer, bot: EngineConnectedStarRefBotsContext.Item, copyLink: @escaping (EngineConnectedStarRefBotsContext.Item) -> Void) {
            self.targetPeer = targetPeer
            self.bot = bot
            self.copyLink = copyLink
        }
    }

    
    case join(Join)
    case active(Active)
}

public enum JoinSubjectScreenMode {
    public final class Group {
        public enum VerificationStatus {
            case fake
            case scam
            case verified
        }

        public let link: String
        public let isGroup: Bool
        public let isPublic: Bool
        public let isRequest: Bool
        public let verificationStatus: VerificationStatus?
        public let image: TelegramMediaImageRepresentation?
        public let title: String
        public let about: String?
        public let memberCount: Int32
        public let members: [EnginePeer]
        
        public init(link: String, isGroup: Bool, isPublic: Bool, isRequest: Bool, verificationStatus: VerificationStatus?, image: TelegramMediaImageRepresentation?, title: String, about: String?, memberCount: Int32, members: [EnginePeer]) {
            self.link = link
            self.isGroup = isGroup
            self.isPublic = isPublic
            self.isRequest = isRequest
            self.verificationStatus = verificationStatus
            self.image = image
            self.title = title
            self.about = about
            self.memberCount = memberCount
            self.members = members
        }
    }
    
    public final class GroupCall {
        public let id: Int64
        public let accessHash: Int64
        public let slug: String
        public let inviter: EnginePeer?
        public let members: [EnginePeer]
        public let totalMemberCount: Int
        public let info: JoinCallLinkInformation
        public let enableMicrophoneByDefault: Bool
        
        public init(id: Int64, accessHash: Int64, slug: String, inviter: EnginePeer?, members: [EnginePeer], totalMemberCount: Int, info: JoinCallLinkInformation, enableMicrophoneByDefault: Bool) {
            self.id = id
            self.accessHash = accessHash
            self.slug = slug
            self.inviter = inviter
            self.members = members
            self.totalMemberCount = totalMemberCount
            self.info = info
            self.enableMicrophoneByDefault = enableMicrophoneByDefault
        }
    }
    
    case group(Group)
    case groupCall(GroupCall)
}

public enum OldChannelsControllerIntent {
    case join
    case create
    case upgrade
}

public enum SendInviteLinkScreenSubject {
    case chat(peer: EnginePeer, link: String?)
    case groupCall(link: String)
}

public enum StarsWithdrawalScreenSubject {
    public enum PaidMessageKind {
        case privacy
        case postSuggestion
    }
    
    case withdraw(completion: (Int64) -> Void)
    case enterAmount(current: StarsAmount, minValue: StarsAmount, fractionAfterCommission: Int, kind: PaidMessageKind, completion: (Int64) -> Void)
    case postSuggestion(channel: EnginePeer, isFromAdmin: Bool, current: CurrencyAmount, timestamp: Int32?, completion: (CurrencyAmount, Int32?) -> Void)
    case postSuggestionModification(current: CurrencyAmount, timestamp: Int32?, completion: (CurrencyAmount, Int32?) -> Void)
}

public protocol SharedAccountContext: AnyObject {
    var sharedContainerPath: String { get }
    var basePath: String { get }
    var networkArguments: NetworkInitializationArguments { get }
    var mainWindow: Window1? { get }
    var accountManager: AccountManager<TelegramAccountManagerTypes> { get }
    var appLockContext: AppLockContext { get }
    
    var currentPresentationData: Atomic<PresentationData> { get }
    var presentationData: Signal<PresentationData, NoError> { get }
    
    var currentAutomaticMediaDownloadSettings: MediaAutoDownloadSettings { get }
    var automaticMediaDownloadSettings: Signal<MediaAutoDownloadSettings, NoError> { get }
    var currentAutodownloadSettings: Atomic<AutodownloadSettings> { get }
    var immediateExperimentalUISettings: ExperimentalUISettings { get }
    var currentInAppNotificationSettings: Atomic<InAppNotificationSettings> { get }
    var currentMediaInputSettings: Atomic<MediaInputSettings> { get }
    var currentStickerSettings: Atomic<StickerSettings> { get }
    var currentMediaDisplaySettings: Atomic<MediaDisplaySettings> { get }
    
    var energyUsageSettings: EnergyUsageSettings { get }
    
    var applicationBindings: TelegramApplicationBindings { get }
    
    var authorizationPushConfiguration: Signal<AuthorizationCodePushNotificationConfiguration?, NoError> { get }
    var firebaseSecretStream: Signal<[String: String], NoError> { get }
    
    var mediaManager: MediaManager { get }
    var locationManager: DeviceLocationManager? { get }
    var callManager: PresentationCallManager? { get }
    var contactDataManager: DeviceContactDataManager? { get }
    
    var activeAccountContexts: Signal<(primary: AccountContext?, accounts: [(AccountRecordId, AccountContext, Int32)], currentAuth: UnauthorizedAccount?), NoError> { get }
    var activeAccountsWithInfo: Signal<(primary: AccountRecordId?, accounts: [AccountWithInfo]), NoError> { get }
        
    var presentGlobalController: (ViewController, Any?) -> Void { get }
    var presentCrossfadeController: () -> Void { get }
    
    func makeTempAccountContext(account: Account) -> AccountContext
    
    func updateNotificationTokensRegistration()
    func setAccountUserInterfaceInUse(_ id: AccountRecordId) -> Disposable
    func handleTextLinkAction(context: AccountContext, peerId: PeerId?, navigateDisposable: MetaDisposable, controller: ViewController, action: TextLinkItemActionType, itemLink: TextLinkItem)
    func openSearch(filter: ChatListSearchFilter, query: String?)
    func navigateToChat(accountId: AccountRecordId, peerId: PeerId, messageId: MessageId?)
    func openChatMessage(_ params: OpenChatMessageParams) -> Bool
    func messageFromPreloadedChatHistoryViewForLocation(id: MessageId, location: ChatHistoryLocationInput, context: AccountContext, chatLocation: ChatLocation, subject: ChatControllerSubject?, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>, tag: HistoryViewInputTag?) -> Signal<(MessageIndex?, Bool), NoError>
    func makeOverlayAudioPlayerController(context: AccountContext, chatLocation: ChatLocation, type: MediaManagerPlayerType, initialMessageId: MessageId, initialOrder: MusicPlaybackSettingsOrder, playlistLocation: SharedMediaPlaylistLocation?, parentNavigationController: NavigationController?) -> ViewController & OverlayAudioPlayerController
    func makePeerInfoController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, peer: Peer, mode: PeerInfoControllerMode, avatarInitiallyExpanded: Bool, fromChat: Bool, requestsContext: PeerInvitationImportersContext?) -> ViewController?
    func makeChannelAdminController(context: AccountContext, peerId: PeerId, adminId: PeerId, initialParticipant: ChannelParticipant) -> ViewController?
    func makeDeviceContactInfoController(context: ShareControllerAccountContext, environment: ShareControllerEnvironment, subject: DeviceContactInfoSubject, completed: (() -> Void)?, cancelled: (() -> Void)?) -> ViewController
    func makePeersNearbyController(context: AccountContext) -> ViewController
    func makeComposeController(context: AccountContext) -> ViewController
    func makeChatListController(context: AccountContext, location: ChatListControllerLocation, controlsHistoryPreload: Bool, hideNetworkActivityStatus: Bool, previewing: Bool, enableDebugActions: Bool) -> ChatListController
    func makeChatController(context: AccountContext, chatLocation: ChatLocation, subject: ChatControllerSubject?, botStart: ChatControllerInitialBotStart?, mode: ChatControllerPresentationMode, params: ChatControllerParams?) -> ChatController
    func makeChatHistoryListNode(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>),
        chatLocation: ChatLocation,
        chatLocationContextHolder: Atomic<ChatLocationContextHolder?>,
        tag: HistoryViewInputTag?,
        source: ChatHistoryListSource,
        subject: ChatControllerSubject?,
        controllerInteraction: ChatControllerInteractionProtocol,
        selectedMessages: Signal<Set<MessageId>?, NoError>,
        mode: ChatHistoryListMode
    ) -> ChatHistoryListNode
    func subscribeChatListData(context: AccountContext, location: ChatListControllerLocation) -> Signal<EngineChatList, NoError>
    func makeChatMessagePreviewItem(context: AccountContext, messages: [Message], theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, chatBubbleCorners: PresentationChatBubbleCorners, dateTimeFormat: PresentationDateTimeFormat, nameOrder: PresentationPersonNameOrder, forcedResourceStatus: FileMediaResourceStatus?, tapMessage: ((Message) -> Void)?, clickThroughMessage: ((UIView?, CGPoint?) -> Void)?, backgroundNode: ASDisplayNode?, availableReactions: AvailableReactions?, accountPeer: Peer?, isCentered: Bool, isPreview: Bool, isStandalone: Bool) -> ListViewItem
    func makeChatMessageDateHeaderItem(context: AccountContext, timestamp: Int32, theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, chatBubbleCorners: PresentationChatBubbleCorners, dateTimeFormat: PresentationDateTimeFormat, nameOrder: PresentationPersonNameOrder) -> ListViewItemHeader
    func makeChatMessageAvatarHeaderItem(context: AccountContext, timestamp: Int32, peer: Peer, message: Message, theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, chatBubbleCorners: PresentationChatBubbleCorners, dateTimeFormat: PresentationDateTimeFormat, nameOrder: PresentationPersonNameOrder) -> ListViewItemHeader
    func makePeerSharedMediaController(context: AccountContext, peerId: PeerId) -> ViewController?
    func makeContactSelectionController(_ params: ContactSelectionControllerParams) -> ContactSelectionController
    func makeContactMultiselectionController(_ params: ContactMultiselectionControllerParams) -> ContactMultiselectionController
    func makePeerSelectionController(_ params: PeerSelectionControllerParams) -> PeerSelectionController
    func makeProxySettingsController(context: AccountContext) -> ViewController
    func makeLocalizationListController(context: AccountContext) -> ViewController
    func makeCreateGroupController(context: AccountContext, peerIds: [PeerId], initialTitle: String?, mode: CreateGroupMode, completion: ((PeerId, @escaping () -> Void) -> Void)?) -> ViewController
    func makeChatRecentActionsController(context: AccountContext, peer: Peer, adminPeerId: PeerId?, starsState: StarsRevenueStats?) -> ViewController
    func makePrivacyAndSecurityController(context: AccountContext) -> ViewController
    func makeBioPrivacyController(context: AccountContext, settings: Promise<AccountPrivacySettings?>, present: @escaping (ViewController) -> Void)
    func makeBirthdayPrivacyController(context: AccountContext, settings: Promise<AccountPrivacySettings?>, openedFromBirthdayScreen: Bool, present: @escaping (ViewController) -> Void)
    func makeSetupTwoFactorAuthController(context: AccountContext) -> ViewController
    func makeStorageManagementController(context: AccountContext) -> ViewController
    func makeAttachmentFileController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, bannedSendMedia: (Int32, Bool)?, presentGallery: @escaping () -> Void, presentFiles: @escaping () -> Void, send: @escaping (AnyMediaReference) -> Void) -> AttachmentFileController
    func makeGalleryCaptionPanelView(context: AccountContext, chatLocation: ChatLocation, isScheduledMessages: Bool, isFile: Bool, customEmojiAvailable: Bool, present: @escaping (ViewController) -> Void, presentInGlobalOverlay: @escaping (ViewController) -> Void) -> NSObject?
    func makeHashtagSearchController(context: AccountContext, peer: EnginePeer?, query: String, stories: Bool, forceDark: Bool) -> ViewController
    func makeStorySearchController(context: AccountContext, scope: StorySearchControllerScope, listContext: SearchStoryListContext?) -> ViewController
    func makeMyStoriesController(context: AccountContext, isArchive: Bool) -> ViewController
    func makeArchiveSettingsController(context: AccountContext) -> ViewController
    func makeFilterSettingsController(context: AccountContext, modal: Bool, scrollToTags: Bool, dismissed: (() -> Void)?) -> ViewController
    func makeBusinessSetupScreen(context: AccountContext) -> ViewController
    func makeChatbotSetupScreen(context: AccountContext, initialData: ChatbotSetupScreenInitialData) -> ViewController
    func makeChatbotSetupScreenInitialData(context: AccountContext) -> Signal<ChatbotSetupScreenInitialData, NoError>
    func makeBusinessLocationSetupScreen(context: AccountContext, initialValue: TelegramBusinessLocation?, completion: @escaping (TelegramBusinessLocation?) -> Void) -> ViewController
    func makeBusinessHoursSetupScreen(context: AccountContext, initialValue: TelegramBusinessHours?, completion: @escaping (TelegramBusinessHours?) -> Void) -> ViewController
    func makeAutomaticBusinessMessageSetupScreen(context: AccountContext, initialData: AutomaticBusinessMessageSetupScreenInitialData, isAwayMode: Bool) -> ViewController
    func makeAutomaticBusinessMessageSetupScreenInitialData(context: AccountContext) -> Signal<AutomaticBusinessMessageSetupScreenInitialData, NoError>
    func makeQuickReplySetupScreen(context: AccountContext, initialData: QuickReplySetupScreenInitialData) -> ViewController
    func makeQuickReplySetupScreenInitialData(context: AccountContext) -> Signal<QuickReplySetupScreenInitialData, NoError>
    func makeBusinessIntroSetupScreen(context: AccountContext, initialData: BusinessIntroSetupScreenInitialData) -> ViewController
    func makeBusinessIntroSetupScreenInitialData(context: AccountContext) -> Signal<BusinessIntroSetupScreenInitialData, NoError>
    func makeBusinessLinksSetupScreen(context: AccountContext, initialData: BusinessLinksSetupScreenInitialData) -> ViewController
    func makeBusinessLinksSetupScreenInitialData(context: AccountContext) -> Signal<BusinessLinksSetupScreenInitialData, NoError>
    func makeCollectibleItemInfoScreen(context: AccountContext, initialData: CollectibleItemInfoScreenInitialData) -> ViewController
    func makeCollectibleItemInfoScreenInitialData(context: AccountContext, peerId: EnginePeer.Id, subject: CollectibleItemInfoScreenSubject) -> Signal<CollectibleItemInfoScreenInitialData?, NoError>
    func makeBotSettingsScreen(context: AccountContext, peerId: EnginePeer.Id?) -> ViewController
    func makeEditForumTopicScreen(context: AccountContext, peerId: EnginePeer.Id, threadId: Int64, threadInfo: EngineMessageHistoryThread.Info, isHidden: Bool) -> ViewController
    
    func navigateToChatController(_ params: NavigateToChatControllerParams)
    func navigateToForumChannel(context: AccountContext, peerId: EnginePeer.Id, navigationController: NavigationController)
    func navigateToForumThread(context: AccountContext, peerId: EnginePeer.Id, threadId: Int64, messageId: EngineMessage.Id?,  navigationController: NavigationController, activateInput: ChatControllerActivateInput?, scrollToEndIfExists: Bool, keepStack: NavigateToChatKeepStack, animated: Bool) -> Signal<Never, NoError>
    func chatControllerForForumThread(context: AccountContext, peerId: EnginePeer.Id, threadId: Int64) -> Signal<ChatController, NoError>
    func openStorageUsage(context: AccountContext)
    func openLocationScreen(context: AccountContext, messageId: MessageId, navigationController: NavigationController)
    func openExternalUrl(context: AccountContext, urlContext: OpenURLContext, url: String, forceExternal: Bool, presentationData: PresentationData, navigationController: NavigationController?, dismissInput: @escaping () -> Void)
    func chatAvailableMessageActions(engine: TelegramEngine, accountPeerId: EnginePeer.Id, messageIds: Set<EngineMessage.Id>, keepUpdated: Bool) -> Signal<ChatAvailableMessageActions, NoError>
    func chatAvailableMessageActions(engine: TelegramEngine, accountPeerId: EnginePeer.Id, messageIds: Set<EngineMessage.Id>, messages: [EngineMessage.Id: EngineMessage], peers: [EnginePeer.Id: EnginePeer]) -> Signal<ChatAvailableMessageActions, NoError>
    func resolveUrl(context: AccountContext, peerId: PeerId?, url: String, skipUrlAuth: Bool) -> Signal<ResolvedUrl, NoError>
    func resolveUrlWithProgress(context: AccountContext, peerId: PeerId?, url: String, skipUrlAuth: Bool) -> Signal<ResolveUrlResult, NoError>
    func openResolvedUrl(_ resolvedUrl: ResolvedUrl, context: AccountContext, urlContext: OpenURLContext, navigationController: NavigationController?, forceExternal: Bool, forceUpdate: Bool, openPeer: @escaping (EnginePeer, ChatControllerInteractionNavigateToPeer) -> Void, sendFile: ((FileMediaReference) -> Void)?, sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)?, sendEmoji: ((String, ChatTextInputTextCustomEmojiAttribute) -> Void)?, requestMessageActionUrlAuth: ((MessageActionUrlSubject) -> Void)?, joinVoiceChat: ((PeerId, String?, CachedChannelData.ActiveCall) -> Void)?, present: @escaping (ViewController, Any?) -> Void, dismissInput: @escaping () -> Void, contentContext: Any?, progress: Promise<Bool>?, completion: (() -> Void)?)
    func openAddContact(context: AccountContext, firstName: String, lastName: String, phoneNumber: String, label: String, present: @escaping (ViewController, Any?) -> Void, pushController: @escaping (ViewController) -> Void, completed: @escaping () -> Void)
    func openAddPersonContact(context: AccountContext, peerId: PeerId, pushController: @escaping (ViewController) -> Void, present: @escaping (ViewController, Any?) -> Void)
    func presentContactsWarningSuppression(context: AccountContext, present: (ViewController, Any?) -> Void)
    func openImagePicker(context: AccountContext, completion: @escaping (UIImage) -> Void, present: @escaping (ViewController) -> Void)
    func openAddPeerMembers(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, parentController: ViewController, groupPeer: Peer, selectAddMemberDisposable: MetaDisposable, addMemberDisposable: MetaDisposable)
    func makeInstantPageController(context: AccountContext, message: Message, sourcePeerType: MediaAutoDownloadPeerType?) -> ViewController?
    func makeInstantPageController(context: AccountContext, webPage: TelegramMediaWebpage, anchor: String?, sourceLocation: InstantPageSourceLocation) -> ViewController
    func openChatWallpaper(context: AccountContext, message: Message, present: @escaping (ViewController, Any?) -> Void)
    
    func makeRecentSessionsController(context: AccountContext, activeSessionsContext: ActiveSessionsContext) -> ViewController & RecentSessionsController
    
    func makeChatQrCodeScreen(context: AccountContext, peer: Peer, threadId: Int64?, temporary: Bool) -> ViewController
    
    func makePremiumIntroController(context: AccountContext, source: PremiumIntroSource, forceDark: Bool, dismissed: (() -> Void)?) -> ViewController
    func makePremiumIntroController(sharedContext: SharedAccountContext, engine: TelegramEngineUnauthorized, inAppPurchaseManager: InAppPurchaseManager, source: PremiumIntroSource, proceed: (() -> Void)?) -> ViewController
    
    func makePremiumDemoController(context: AccountContext, subject: PremiumDemoSubject, forceDark: Bool, action: @escaping () -> Void, dismissed: (() -> Void)?) -> ViewController
    func makePremiumLimitController(context: AccountContext, subject: PremiumLimitSubject, count: Int32, forceDark: Bool, cancel: @escaping () -> Void, action: @escaping () -> Bool) -> ViewController
    
    func makeStarsGiftController(context: AccountContext, birthdays: [EnginePeer.Id: TelegramBirthday]?, completion: @escaping (([EnginePeer.Id]) -> Void)) -> ViewController
    func makePremiumGiftController(context: AccountContext, source: PremiumGiftSource, completion: (([EnginePeer.Id]) -> Signal<Never, TransferStarGiftError>)?) -> ViewController
    func makeGiftOptionsController(context: AccountContext, peerId: EnginePeer.Id, premiumOptions: [CachedPremiumGiftOption], hasBirthday: Bool, completion: (() -> Void)?) -> ViewController
    func makeGiftStoreController(context: AccountContext, peerId: EnginePeer.Id, gift: StarGift.Gift) -> ViewController
    func makePremiumPrivacyControllerController(context: AccountContext, subject: PremiumPrivacySubject, peerId: EnginePeer.Id) -> ViewController
    func makePremiumBoostLevelsController(context: AccountContext, peerId: EnginePeer.Id, subject: BoostSubject, boostStatus: ChannelBoostStatus, myBoostStatus: MyBoostStatus, forceDark: Bool, openStats: (() -> Void)?) -> ViewController
    
    func makeStickerPackScreen(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, mainStickerPack: StickerPackReference, stickerPacks: [StickerPackReference], loadedStickerPacks: [LoadedStickerPack], actionTitle: String?, isEditing: Bool, expandIfNeeded: Bool, parentNavigationController: NavigationController?, sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)?, actionPerformed: ((Bool) -> Void)?) -> ViewController
    
    func makeMediaPickerScreen(context: AccountContext, hasSearch: Bool, completion: @escaping (Any) -> Void) -> ViewController
    
    func makeStoryMediaEditorScreen(context: AccountContext, source: Any?, text: String?, link: (url: String, name: String?)?, remainingCount: Int32, completion: @escaping ([MediaEditorScreenResult], MediaEditorTransitionOutExternalState, @escaping (@escaping () -> Void) -> Void) -> Void) -> ViewController
    
    func makeBotPreviewEditorScreen(context: AccountContext, source: Any?, target: Stories.PendingTarget, transitionArguments: (UIView, CGRect, UIImage?)?, transitionOut: @escaping () -> BotPreviewEditorTransitionOut?, externalState: MediaEditorTransitionOutExternalState, completion: @escaping (MediaEditorScreenResult, @escaping (@escaping () -> Void) -> Void) -> Void, cancelled: @escaping () -> Void) -> ViewController
    
    func makeStickerEditorScreen(context: AccountContext, source: Any?, intro: Bool, transitionArguments: (UIView, CGRect, UIImage?)?, completion: @escaping (TelegramMediaFile, [String], @escaping () -> Void) -> Void, cancelled: @escaping () -> Void) -> ViewController
    
    func makeStickerMediaPickerScreen(context: AccountContext, getSourceRect: @escaping () -> CGRect?, completion: @escaping (Any?, UIView?, CGRect, UIImage?, Bool, @escaping (Bool?) -> (UIView, CGRect)?, @escaping () -> Void) -> Void, dismissed: @escaping () -> Void) -> ViewController
    
    func makeAvatarMediaPickerScreen(context: AccountContext, getSourceRect: @escaping () -> CGRect?, canDelete: Bool, performDelete: @escaping () -> Void, completion: @escaping (Any?, UIView?, CGRect, UIImage?, Bool, @escaping (Bool?) -> (UIView, CGRect)?, @escaping () -> Void) -> Void, dismissed: @escaping () -> Void) -> ViewController
    
    func makeStoryMediaPickerScreen(context: AccountContext, isDark: Bool, forCollage: Bool, selectionLimit: Int?, getSourceRect: @escaping () -> CGRect, completion: @escaping (Any, UIView, CGRect, UIImage?, @escaping (Bool?) -> (UIView, CGRect)?, @escaping () -> Void) -> Void, multipleCompletion: @escaping ([Any], Bool) -> Void, dismissed: @escaping () -> Void, groupsPresented: @escaping () -> Void) -> ViewController
    
    func makeStickerPickerScreen(context: AccountContext, inputData: Promise<StickerPickerInput>, completion: @escaping (FileMediaReference) -> Void) -> ViewController
    
    func makeProxySettingsController(sharedContext: SharedAccountContext, account: UnauthorizedAccount) -> ViewController
    
    func makeDataAndStorageController(context: AccountContext, sensitiveContent: Bool) -> ViewController
    
    func makeInstalledStickerPacksController(context: AccountContext, mode: InstalledStickerPacksControllerMode, forceTheme: PresentationTheme?) -> ViewController
    
    func makeChannelStatsController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, peerId: EnginePeer.Id, boosts: Bool, boostStatus: ChannelBoostStatus?) -> ViewController
    func makeMessagesStatsController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, messageId: EngineMessage.Id) -> ViewController
    func makeStoryStatsController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, peerId: EnginePeer.Id, storyId: Int32, storyItem: EngineStoryItem, fromStory: Bool) -> ViewController
    
    func makeStarsTransactionsScreen(context: AccountContext, starsContext: StarsContext) -> ViewController
    func makeStarsPurchaseScreen(context: AccountContext, starsContext: StarsContext, options: [Any], purpose: StarsPurchasePurpose, completion: @escaping (Int64) -> Void) -> ViewController
    func makeStarsTransferScreen(context: AccountContext, starsContext: StarsContext, invoice: TelegramMediaInvoice, source: BotPaymentInvoiceSource, extendedMedia: [TelegramExtendedMedia], inputData: Signal<(StarsContext.State, BotPaymentForm, EnginePeer?, EnginePeer?)?, NoError>, completion: @escaping (Bool) -> Void) -> ViewController
    func makeStarsSubscriptionTransferScreen(context: AccountContext, starsContext: StarsContext, invoice: TelegramMediaInvoice, link: String, inputData: Signal<(StarsContext.State, BotPaymentForm, EnginePeer?, EnginePeer?)?, NoError>, navigateToPeer: @escaping (EnginePeer) -> Void) -> ViewController
    func makeStarsTransactionScreen(context: AccountContext, transaction: StarsContext.State.Transaction, peer: EnginePeer) -> ViewController
    func makeStarsReceiptScreen(context: AccountContext, receipt: BotPaymentReceipt) -> ViewController
    func makeStarsSubscriptionScreen(context: AccountContext, subscription: StarsContext.State.Subscription, update: @escaping (Bool) -> Void) -> ViewController
    func makeStarsSubscriptionScreen(context: AccountContext, peer: EnginePeer, pricing: StarsSubscriptionPricing, importer: PeerInvitationImportersState.Importer, usdRate: Double) -> ViewController
    func makeStarsStatisticsScreen(context: AccountContext, peerId: EnginePeer.Id, revenueContext: StarsRevenueStatsContext) -> ViewController
    func makeStarsAmountScreen(context: AccountContext, initialValue: Int64?, completion: @escaping (Int64) -> Void) -> ViewController
    func makeStarsWithdrawalScreen(context: AccountContext, stats: StarsRevenueStats, completion: @escaping (Int64) -> Void) -> ViewController
    func makeStarsWithdrawalScreen(context: AccountContext, subject: StarsWithdrawalScreenSubject) -> ViewController
    func makeStarGiftResellScreen(context: AccountContext, gift: StarGift.UniqueGift, update: Bool, completion: @escaping (Int64) -> Void) -> ViewController
    func makeStarsGiftScreen(context: AccountContext, message: EngineMessage) -> ViewController
    func makeStarsGiveawayBoostScreen(context: AccountContext, peerId: EnginePeer.Id, boost: ChannelBoostersContext.State.Boost) -> ViewController
    func makeStarsIntroScreen(context: AccountContext) -> ViewController
    func makeGiftViewScreen(context: AccountContext, message: EngineMessage, shareStory: ((StarGift.UniqueGift) -> Void)?) -> ViewController
    func makeGiftViewScreen(context: AccountContext, gift: StarGift.UniqueGift, shareStory: ((StarGift.UniqueGift) -> Void)?, dismissed: (() -> Void)?) -> ViewController
    func makeGiftWearPreviewScreen(context: AccountContext, gift: StarGift.UniqueGift) -> ViewController
    
    func makeStorySharingScreen(context: AccountContext, subject: StorySharingSubject, parentController: ViewController) -> ViewController
    
    func makeContentReportScreen(context: AccountContext, subject: ReportContentSubject, forceDark: Bool, present: @escaping (ViewController) -> Void, completion: @escaping () -> Void, requestSelectMessages: ((String, Data, String?) -> Void)?)
    
    func makeShareController(context: AccountContext, subject: ShareControllerSubject, forceExternal: Bool, shareStory: (() -> Void)?, enqueued: (([PeerId], [Int64]) -> Void)?, actionCompleted: (() -> Void)?) -> ViewController
    
    func makeMiniAppListScreenInitialData(context: AccountContext) -> Signal<MiniAppListScreenInitialData, NoError>
    func makeMiniAppListScreen(context: AccountContext, initialData: MiniAppListScreenInitialData) -> ViewController
    
    func makeIncomingMessagePrivacyScreen(context: AccountContext, value: GlobalPrivacySettings.NonContactChatsPrivacy, exceptions: SelectivePrivacySettings, update: @escaping (GlobalPrivacySettings.NonContactChatsPrivacy) -> Void) -> ViewController
    
    func openWebApp(context: AccountContext, parentController: ViewController, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, botPeer: EnginePeer, chatPeer: EnginePeer?, threadId: Int64?, buttonText: String, url: String, simple: Bool, source: ChatOpenWebViewSource, skipTermsOfService: Bool, payload: String?)
    
    func makeAffiliateProgramSetupScreenInitialData(context: AccountContext, peerId: EnginePeer.Id, mode: AffiliateProgramSetupScreenMode) -> Signal<AffiliateProgramSetupScreenInitialData, NoError>
    func makeAffiliateProgramSetupScreen(context: AccountContext, initialData: AffiliateProgramSetupScreenInitialData) -> ViewController
    func makeAffiliateProgramJoinScreen(context: AccountContext, sourcePeer: EnginePeer, commissionPermille: Int32, programDuration: Int32?, revenuePerUser: Double, mode: JoinAffiliateProgramScreenMode) -> ViewController
    
    func makeJoinSubjectScreen(context: AccountContext, mode: JoinSubjectScreenMode) -> ViewController
    
    func makeOldChannelsController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, intent: OldChannelsControllerIntent, completed: @escaping (Bool) -> Void) -> ViewController
    
    func makeGalleryController(context: AccountContext, source: GalleryControllerItemSource, streamSingleVideo: Bool, isPreview: Bool) -> ViewController
    
    func makeAccountFreezeInfoScreen(context: AccountContext) -> ViewController
    func makeSendInviteLinkScreen(context: AccountContext, subject: SendInviteLinkScreenSubject, peers: [TelegramForbiddenInvitePeer], theme: PresentationTheme?) -> ViewController
    
    @available(iOS 13.0, *)
    func makePostSuggestionsSettingsScreen(context: AccountContext, peerId: EnginePeer.Id) async -> ViewController
    
    func makeForumSettingsScreen(context: AccountContext, peerId: EnginePeer.Id) -> ViewController
        
    func makeDebugSettingsController(context: AccountContext?) -> ViewController?
    
    func openCreateGroupCallUI(context: AccountContext, peerIds: [EnginePeer.Id], parentController: ViewController)
    
    func navigateToCurrentCall()
    var hasOngoingCall: ValuePromise<Bool> { get }
    var immediateHasOngoingCall: Bool { get }
    
    var enablePreloads: Promise<Bool> { get }
    var hasPreloadBlockingContent: Promise<Bool> { get }
    
    var deviceContactPhoneNumbers: Promise<Set<String>> { get }
    
    var hasGroupCallOnScreen: Signal<Bool, NoError> { get }
    var currentGroupCallController: ViewController? { get }
        
    func switchToAccount(id: AccountRecordId, fromSettingsController settingsController: ViewController?, withChatListController chatListController: ViewController?)
    func beginNewAuth(testingEnvironment: Bool)
}

public protocol ComposeController: ViewController {
}

public protocol ChatLocationContextHolder: AnyObject {
}

public protocol AccountGroupCallContext: AnyObject {
}

public protocol AccountGroupCallContextCache: AnyObject {
}

public struct ChatSendMessageActionSheetControllerSendParameters {
    public struct Effect {
        public let id: Int64
        
        public init(id: Int64) {
            self.id = id
        }
    }
    
    public var effect: Effect?
    public var textIsAboveMedia: Bool
    
    public init(
        effect: Effect?,
        textIsAboveMedia: Bool
    ) {
        self.effect = effect
        self.textIsAboveMedia = textIsAboveMedia
    }
}

public enum ChatSendMessageActionSheetControllerSendMode {
    case generic
    case silently
    case whenOnline
}

public protocol ChatSendMessageActionSheetControllerSourceSendButtonNode: ASDisplayNode {
    func makeCustomContents() -> UIView?
}

public protocol ChatSendMessageActionSheetController: ViewController {
    typealias SendMode = ChatSendMessageActionSheetControllerSendMode
    typealias SendParameters = ChatSendMessageActionSheetControllerSendParameters
}

public protocol AccountContext: AnyObject {
    var sharedContext: SharedAccountContext { get }
    var account: Account { get }
    var engine: TelegramEngine { get }
    
    var liveLocationManager: LiveLocationManager? { get }
    var peersNearbyManager: PeersNearbyManager? { get }
    var fetchManager: FetchManager { get }
    var prefetchManager: PrefetchManager? { get }
    var downloadedMediaStoreManager: DownloadedMediaStoreManager { get }
    var peerChannelMemberCategoriesContextsManager: PeerChannelMemberCategoriesContextsManager { get }
    var wallpaperUploadManager: WallpaperUploadManager? { get }
    var inAppPurchaseManager: InAppPurchaseManager? { get }
    var starsContext: StarsContext? { get }
    var tonContext: StarsContext? { get }
    
    var currentLimitsConfiguration: Atomic<LimitsConfiguration> { get }
    var currentContentSettings: Atomic<ContentSettings> { get }
    var currentAppConfiguration: Atomic<AppConfiguration> { get }
    var currentCountriesConfiguration: Atomic<CountriesConfiguration> { get }
    
    var cachedGroupCallContexts: AccountGroupCallContextCache { get }
    
    var animationCache: AnimationCache { get }
    var animationRenderer: MultiAnimationRenderer { get }
    
    var animatedEmojiStickers: Signal<[String: [StickerPackItem]], NoError> { get }
    var animatedEmojiStickersValue: [String: [StickerPackItem]] { get }
    var additionalAnimatedEmojiStickers: Signal<[String: [Int: StickerPackItem]], NoError> { get }
    var availableReactions: Signal<AvailableReactions?, NoError> { get }
    var availableMessageEffects: Signal<AvailableMessageEffects?, NoError> { get }
    
    var isPremium: Bool { get }
    var isFrozen: Bool { get }
    var userLimits: EngineConfiguration.UserLimits { get }
    var peerNameColors: PeerNameColors { get }
    
    var imageCache: AnyObject? { get }
    
    func storeSecureIdPassword(password: String)
    func getStoredSecureIdPassword() -> String?
    
    func chatLocationInput(for location: ChatLocation, contextHolder: Atomic<ChatLocationContextHolder?>) -> ChatLocationInput
    func chatLocationOutgoingReadState(for location: ChatLocation, contextHolder: Atomic<ChatLocationContextHolder?>) -> Signal<MessageId?, NoError>
    func chatLocationUnreadCount(for location: ChatLocation, contextHolder: Atomic<ChatLocationContextHolder?>) -> Signal<Int, NoError>
    func applyMaxReadIndex(for location: ChatLocation, contextHolder: Atomic<ChatLocationContextHolder?>, messageIndex: MessageIndex)
    
    func scheduleGroupCall(peerId: PeerId, parentController: ViewController)
    func joinGroupCall(peerId: PeerId, invite: String?, requestJoinAsPeerId: ((@escaping (PeerId?) -> Void) -> Void)?, activeCall: EngineGroupCallDescription)
    func joinConferenceCall(call: JoinCallLinkInformation, isVideo: Bool, unmuteByDefault: Bool)
    func requestCall(peerId: PeerId, isVideo: Bool, completion: @escaping () -> Void)
}

public struct AntiSpamBotConfiguration {
    public static var defaultValue: AntiSpamBotConfiguration {
        return AntiSpamBotConfiguration(antiSpamBotId: nil, minimumGroupParticipants: 100)
    }
    
    public let antiSpamBotId: EnginePeer.Id?
    public let minimumGroupParticipants: Int32
    
    fileprivate init(antiSpamBotId: EnginePeer.Id?, minimumGroupParticipants: Int32) {
        self.antiSpamBotId = antiSpamBotId
        self.minimumGroupParticipants = minimumGroupParticipants
    }
    
    public static func with(appConfiguration: AppConfiguration) -> AntiSpamBotConfiguration {
        if let data = appConfiguration.data, let botIdString = data["telegram_antispam_user_id"] as? String, let botIdValue = Int64(botIdString), let groupSize = data["telegram_antispam_group_size_min"] as? Double {
            return AntiSpamBotConfiguration(antiSpamBotId: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(botIdValue)), minimumGroupParticipants: Int32(groupSize))
        } else {
            return .defaultValue
        }
    }
}

public struct StoriesConfiguration {
    public enum PostingAvailability {
        case enabled
        case premium
        case disabled
    }
    
    public enum CaptionEntitiesAvailability {
        case enabled
        case premium
    }
    
    static var defaultValue: StoriesConfiguration {
        return StoriesConfiguration(posting: .disabled, captionEntities: .premium, venueSearchBot: "foursquare")
    }
    
    public let posting: PostingAvailability
    public let captionEntities: CaptionEntitiesAvailability
    public let venueSearchBot: String
    
    fileprivate init(posting: PostingAvailability, captionEntities: CaptionEntitiesAvailability, venueSearchBot: String) {
        self.posting = posting
        self.captionEntities = captionEntities
        self.venueSearchBot = venueSearchBot
    }
    
    public static func with(appConfiguration: AppConfiguration) -> StoriesConfiguration {
        if let data = appConfiguration.data {
            let posting: PostingAvailability
            let captionEntities: CaptionEntitiesAvailability
            let venueSearchBot: String
            if let postingString = data["stories_posting"] as? String {
                switch postingString {
                case "enabled":
                    posting = .enabled
                case "premium":
                    posting = .premium
                default:
                    posting = .disabled
                }
            } else {
                posting = .disabled
            }
            if let entitiesString = data["stories_entities"] as? String {
                switch entitiesString {
                case "enabled":
                    captionEntities = .enabled
                default:
                    captionEntities = .premium
                }
            } else {
                captionEntities = .premium
            }
            if let venueSearchBotString = data["stories_venue_search_username"] as? String {
                venueSearchBot = venueSearchBotString
            } else {
                venueSearchBot = "foursquare"
            }
            return StoriesConfiguration(posting: posting, captionEntities: captionEntities, venueSearchBot: venueSearchBot)
        } else {
            return .defaultValue
        }
    }
}

public struct StickersSearchConfiguration {
    static var defaultValue: StickersSearchConfiguration {
        return StickersSearchConfiguration(disableLocalSuggestions: false)
    }
    
    public let disableLocalSuggestions: Bool
    
    fileprivate init(disableLocalSuggestions: Bool) {
        self.disableLocalSuggestions = disableLocalSuggestions
    }
    
    public static func with(appConfiguration: AppConfiguration) -> StickersSearchConfiguration {
        if let data = appConfiguration.data, let suggestOnlyApi = data["stickers_emoji_suggest_only_api"] as? Bool {
            return StickersSearchConfiguration(disableLocalSuggestions: suggestOnlyApi)
        } else {
            return .defaultValue
        }
    }
}

public struct StarsSubscriptionConfiguration {
    static var defaultValue: StarsSubscriptionConfiguration {
        return StarsSubscriptionConfiguration(
            maxFee: 2500,
            usdWithdrawRate: 1200,
            tonUsdRate: 0,
            paidMessageMaxAmount: 10000,
            paidMessageCommissionPermille: 850,
            paidMessagesAvailable: false,
            starGiftResaleMinAmount: 125,
            starGiftResaleMaxAmount: 3500,
            starGiftCommissionPermille: 80,
            channelMessageSuggestionStarsCommissionPermille: 850,
            channelMessageSuggestionTonCommissionPermille: 850,
            channelMessageSuggestionMaxStarsAmount: 10000,
            channelMessageSuggestionMaxTonAmount: 10000000000000,
            channelMessageSuggestionMinStarsAmount: 5
        )
    }
        
    public let maxFee: Int64
    public let usdWithdrawRate: Int64
    public let tonUsdRate: Int64
    public let paidMessageMaxAmount: Int64
    public let paidMessageCommissionPermille: Int32
    public let paidMessagesAvailable: Bool
    public let starGiftResaleMinAmount: Int64
    public let starGiftResaleMaxAmount: Int64
    public let starGiftCommissionPermille: Int32
    public let channelMessageSuggestionStarsCommissionPermille: Int32
    public let channelMessageSuggestionTonCommissionPermille: Int32
    public let channelMessageSuggestionMaxStarsAmount: Int64
    public let channelMessageSuggestionMaxTonAmount: Int64
    public let channelMessageSuggestionMinStarsAmount: Int64
    
    fileprivate init(
        maxFee: Int64,
        usdWithdrawRate: Int64,
        tonUsdRate: Int64,
        paidMessageMaxAmount: Int64,
        paidMessageCommissionPermille: Int32,
        paidMessagesAvailable: Bool,
        starGiftResaleMinAmount: Int64,
        starGiftResaleMaxAmount: Int64,
        starGiftCommissionPermille: Int32,
        channelMessageSuggestionStarsCommissionPermille: Int32,
        channelMessageSuggestionTonCommissionPermille: Int32,
        channelMessageSuggestionMaxStarsAmount: Int64,
        channelMessageSuggestionMaxTonAmount: Int64,
        channelMessageSuggestionMinStarsAmount: Int64
    ) {
        self.maxFee = maxFee
        self.usdWithdrawRate = usdWithdrawRate
        self.tonUsdRate = tonUsdRate
        self.paidMessageMaxAmount = paidMessageMaxAmount
        self.paidMessageCommissionPermille = paidMessageCommissionPermille
        self.paidMessagesAvailable = paidMessagesAvailable
        self.starGiftResaleMinAmount = starGiftResaleMinAmount
        self.starGiftResaleMaxAmount = starGiftResaleMaxAmount
        self.starGiftCommissionPermille = starGiftCommissionPermille
        self.channelMessageSuggestionStarsCommissionPermille = channelMessageSuggestionStarsCommissionPermille
        self.channelMessageSuggestionTonCommissionPermille = channelMessageSuggestionTonCommissionPermille
        self.channelMessageSuggestionMaxStarsAmount = channelMessageSuggestionMaxStarsAmount
        self.channelMessageSuggestionMaxTonAmount = channelMessageSuggestionMaxTonAmount
        self.channelMessageSuggestionMinStarsAmount = channelMessageSuggestionMinStarsAmount
    }
    
    public static func with(appConfiguration: AppConfiguration) -> StarsSubscriptionConfiguration {
        if let data = appConfiguration.data {
            let maxFee = (data["stars_subscription_amount_max"] as? Double).flatMap(Int64.init) ?? StarsSubscriptionConfiguration.defaultValue.maxFee
            let usdWithdrawRate = (data["stars_usd_withdraw_rate_x1000"] as? Double).flatMap(Int64.init) ?? StarsSubscriptionConfiguration.defaultValue.usdWithdrawRate
            let tonUsdRate = (data["ton_usd_rate"] as? Double).flatMap(Int64.init) ?? StarsSubscriptionConfiguration.defaultValue.tonUsdRate
            let paidMessageMaxAmount = (data["stars_paid_message_amount_max"] as? Double).flatMap(Int64.init) ?? StarsSubscriptionConfiguration.defaultValue.paidMessageMaxAmount
            let paidMessageCommissionPermille = (data["stars_paid_message_commission_permille"] as? Double).flatMap(Int32.init) ?? StarsSubscriptionConfiguration.defaultValue.paidMessageCommissionPermille
            let paidMessagesAvailable = (data["stars_paid_messages_available"] as? Bool) ?? StarsSubscriptionConfiguration.defaultValue.paidMessagesAvailable
            let starGiftResaleMinAmount = (data["stars_stargift_resale_amount_min"] as? Double).flatMap(Int64.init) ?? StarsSubscriptionConfiguration.defaultValue.starGiftResaleMinAmount
            let starGiftResaleMaxAmount = (data["stars_stargift_resale_amount_max"] as? Double).flatMap(Int64.init) ?? StarsSubscriptionConfiguration.defaultValue.starGiftResaleMaxAmount
            let starGiftCommissionPermille = (data["stars_stargift_resale_commission_permille"] as? Double).flatMap(Int32.init) ?? StarsSubscriptionConfiguration.defaultValue.starGiftCommissionPermille
            
            let channelMessageSuggestionStarsCommissionPermille = (data["stars_suggested_post_commission_permille"] as? Double).flatMap(Int32.init) ?? StarsSubscriptionConfiguration.defaultValue.channelMessageSuggestionStarsCommissionPermille
            let channelMessageSuggestionTonCommissionPermille = (data["ton_suggested_post_commission_permille"] as? Double).flatMap(Int32.init) ?? StarsSubscriptionConfiguration.defaultValue.channelMessageSuggestionTonCommissionPermille
            let channelMessageSuggestionMaxStarsAmount = (data["stars_suggested_post_amount_max"] as? Double).flatMap(Int64.init) ?? StarsSubscriptionConfiguration.defaultValue.channelMessageSuggestionMaxStarsAmount
            let channelMessageSuggestionMaxTonAmount = (data["ton_suggested_post_amount_max"] as? Double).flatMap(Int64.init) ?? StarsSubscriptionConfiguration.defaultValue.channelMessageSuggestionMaxTonAmount
            
            let channelMessageSuggestionMinStarsAmount = (data["stars_suggested_post_amount_min"] as? Double).flatMap(Int64.init) ?? StarsSubscriptionConfiguration.defaultValue.channelMessageSuggestionMinStarsAmount
            
            return StarsSubscriptionConfiguration(
                maxFee: maxFee,
                usdWithdrawRate: usdWithdrawRate,
                tonUsdRate: tonUsdRate,
                paidMessageMaxAmount: paidMessageMaxAmount,
                paidMessageCommissionPermille: paidMessageCommissionPermille,
                paidMessagesAvailable: paidMessagesAvailable,
                starGiftResaleMinAmount: starGiftResaleMinAmount,
                starGiftResaleMaxAmount: starGiftResaleMaxAmount,
                starGiftCommissionPermille: starGiftCommissionPermille,
                channelMessageSuggestionStarsCommissionPermille: channelMessageSuggestionStarsCommissionPermille,
                channelMessageSuggestionTonCommissionPermille: channelMessageSuggestionTonCommissionPermille,
                channelMessageSuggestionMaxStarsAmount: channelMessageSuggestionMaxStarsAmount,
                channelMessageSuggestionMaxTonAmount: channelMessageSuggestionMaxTonAmount,
                channelMessageSuggestionMinStarsAmount: channelMessageSuggestionMinStarsAmount
            )
        } else {
            return .defaultValue
        }
    }
}

public struct TranslationConfiguration {
    static var defaultValue: TranslationConfiguration {
        return TranslationConfiguration(manual: .disabled, auto: .disabled)
    }
    
    public enum TranslationAvailability {
        case enabled
        case system
        case alternative
        case disabled
        
        init(string: String) {
            switch string {
            case "enabled":
                #if DEBUG
                self = .system
                #else
                self = .enabled
                #endif
            case "system":
                self = .system
            case "alternative":
                self = .alternative
            default:
                self = .disabled
            }
        }
    }
    
    public let manual: TranslationAvailability
    public let auto: TranslationAvailability
    
    fileprivate init(manual: TranslationAvailability, auto: TranslationAvailability) {
        self.manual = manual
        self.auto = auto
    }
    
    public static func with(appConfiguration: AppConfiguration) -> TranslationConfiguration {
        if let data = appConfiguration.data {
            let manualValue = data["translations_manual_enabled"] as? String ?? "disabled"
            var autoValue = data["translations_auto_enabled"] as? String ?? "disabled"
            if autoValue == "alternative" {
                autoValue = "disabled"
            }
            return TranslationConfiguration(manual: TranslationAvailability(string: manualValue), auto: TranslationAvailability(string: autoValue))
        } else {
            return .defaultValue
        }
    }
}
