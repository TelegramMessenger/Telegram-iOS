import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AnimationCache
import MultiAnimationRenderer
import Display

public enum StorySharingSubject {
    case messages([Message])
    case gift(StarGift.UniqueGift)
}

public protocol ShareControllerAccountContext: AnyObject {
    var accountId: AccountRecordId { get }
    var accountPeerId: EnginePeer.Id { get }
    var stateManager: AccountStateManager { get }
    var engineData: TelegramEngine.EngineData { get }
    var animationCache: AnimationCache { get }
    var animationRenderer: MultiAnimationRenderer { get }
    var contentSettings: ContentSettings { get }
    var appConfiguration: AppConfiguration { get }
    
    func resolveInlineStickers(fileIds: [Int64]) -> Signal<[Int64: TelegramMediaFile], NoError>
}

public protocol ShareControllerEnvironment: AnyObject {
    var presentationData: PresentationData { get }
    var updatedPresentationData: Signal<PresentationData, NoError> { get }
    var isMainApp: Bool { get }
    var energyUsageSettings: EnergyUsageSettings { get }
    
    var mediaManager: MediaManager? { get }
    
    func setAccountUserInterfaceInUse(id: AccountRecordId) -> Disposable
    func donateSendMessageIntent(account: ShareControllerAccountContext, peerIds: [EnginePeer.Id])
}

public final class ShareControllerAppAccountContext: ShareControllerAccountContext {
    public let context: AccountContext
    
    public var accountId: AccountRecordId {
        return self.context.account.id
    }
    public var accountPeerId: EnginePeer.Id {
        return self.context.account.stateManager.accountPeerId
    }
    public var stateManager: AccountStateManager {
        return self.context.account.stateManager
    }
    public var engineData: TelegramEngine.EngineData {
        return self.context.engine.data
    }
    public var animationCache: AnimationCache {
        return self.context.animationCache
    }
    public var animationRenderer: MultiAnimationRenderer {
        return self.context.animationRenderer
    }
    public var contentSettings: ContentSettings {
        return self.context.currentContentSettings.with { $0 }
    }
    public var appConfiguration: AppConfiguration {
        return self.context.currentAppConfiguration.with { $0 }
    }
    
    public init(context: AccountContext) {
        self.context = context
    }
    
    public func resolveInlineStickers(fileIds: [Int64]) -> Signal<[Int64: TelegramMediaFile], NoError> {
        return self.context.engine.stickers.resolveInlineStickers(fileIds: fileIds)
    }
}

public enum ShareControllerExternalStatus {
    case preparing(Bool)
    case progress(Float)
    case done
}

public enum ShareControllerError {
    case generic
    case fileTooBig(Int64)
}

public enum ShareControllerSubject {
    public final class PublicLinkPrefix {
        public let visibleString: String
        public let actualString: String
        
        public init(visibleString: String, actualString: String) {
            self.visibleString = visibleString
            self.actualString = actualString
        }
    }
    
    public final class MediaParameters {
        public let startAtTimestamp: Int32?
        public let publicLinkPrefix: PublicLinkPrefix?
        
        public init(startAtTimestamp: Int32?, publicLinkPrefix: PublicLinkPrefix?) {
            self.startAtTimestamp = startAtTimestamp
            self.publicLinkPrefix = publicLinkPrefix
        }
    }
    
    case url(String)
    case text(String)
    case quote(text: String, url: String)
    case messages([Message])
    case image([ImageRepresentationWithReference])
    case media(AnyMediaReference, MediaParameters?)
    case mapMedia(TelegramMediaMap)
    case fromExternal(Int, ([PeerId], [PeerId: Int64], [PeerId: StarsAmount], String, ShareControllerAccountContext, Bool) -> Signal<ShareControllerExternalStatus, ShareControllerError>)
}

public struct ShareControllerAction {
    public let title: String
    public let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
}

public enum ShareControllerPreferredAction {
    case `default`
    case saveToCameraRoll
    case custom(action: ShareControllerAction)
}

public struct ShareControllerSegmentedValue {
    public let title: String
    public let subject: ShareControllerSubject
    public let actionTitle: String
    public let formatSendTitle: (Int) -> String

    public init(title: String, subject: ShareControllerSubject, actionTitle: String, formatSendTitle: @escaping (Int) -> String) {
        self.title = title
        self.subject = subject
        self.actionTitle = actionTitle
        self.formatSendTitle = formatSendTitle
    }
}

public final class ShareControllerParams {
    public let subject: ShareControllerSubject
    public let presetText: String?
    public let preferredAction: ShareControllerPreferredAction
    public let showInChat: ((Message) -> Void)?
    public let fromForeignApp: Bool
    public let segmentedValues: [ShareControllerSegmentedValue]?
    public let externalShare: Bool
    public let immediateExternalShare: Bool
    public let immediatePeerId: PeerId?
    public let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    public let forceTheme: PresentationTheme?
    public let forcedActionTitle: String?
    public let shareAsLink: Bool
    public let collectibleItemInfo: TelegramCollectibleItemInfo?

    public let actionCompleted: (() -> Void)?
    public let dismissed: ((Bool) -> Void)?
    public let completed: (([PeerId]) -> Void)?
    public let enqueued: (([PeerId], [Int64]) -> Void)?
    public let shareStory: (() -> Void)?
    public let debugAction: (() -> Void)?
    public let onMediaTimestampLinkCopied: ((Int32?) -> Void)?
    public weak var parentNavigationController: NavigationController?
    public let canSendInHighQuality: Bool

    public init(
        subject: ShareControllerSubject,
        presetText: String? = nil,
        preferredAction: ShareControllerPreferredAction = .default,
        showInChat: ((Message) -> Void)? = nil,
        fromForeignApp: Bool = false,
        segmentedValues: [ShareControllerSegmentedValue]? = nil,
        externalShare: Bool = true,
        immediateExternalShare: Bool = false,
        immediatePeerId: PeerId? = nil,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        forceTheme: PresentationTheme? = nil,
        forcedActionTitle: String? = nil,
        shareAsLink: Bool = false,
        collectibleItemInfo: TelegramCollectibleItemInfo? = nil,
        actionCompleted: (() -> Void)? = nil,
        dismissed: ((Bool) -> Void)? = nil,
        completed: (([PeerId]) -> Void)? = nil,
        enqueued: (([PeerId], [Int64]) -> Void)? = nil,
        shareStory: (() -> Void)? = nil,
        debugAction: (() -> Void)? = nil,
        onMediaTimestampLinkCopied: ((Int32?) -> Void)? = nil,
        parentNavigationController: NavigationController? = nil,
        canSendInHighQuality: Bool = false
    ) {
        self.subject = subject
        self.presetText = presetText
        self.preferredAction = preferredAction
        self.showInChat = showInChat
        self.fromForeignApp = fromForeignApp
        self.segmentedValues = segmentedValues
        self.externalShare = externalShare
        self.immediateExternalShare = immediateExternalShare
        self.immediatePeerId = immediatePeerId
        self.updatedPresentationData = updatedPresentationData
        self.forceTheme = forceTheme
        self.forcedActionTitle = forcedActionTitle
        self.shareAsLink = shareAsLink
        self.collectibleItemInfo = collectibleItemInfo
        self.actionCompleted = actionCompleted
        self.dismissed = dismissed
        self.completed = completed
        self.enqueued = enqueued
        self.shareStory = shareStory
        self.debugAction = debugAction
        self.onMediaTimestampLinkCopied = onMediaTimestampLinkCopied
        self.parentNavigationController = parentNavigationController
        self.canSendInHighQuality = canSendInHighQuality
    }
}
