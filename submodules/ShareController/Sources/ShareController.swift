import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import AccountContext
import ActionSheetPeerItem
import LocalizedPeerData
import UrlEscaping
import StickerResources
import SaveToCameraRoll
import TelegramStringFormatting
import WallpaperBackgroundNode
import TelegramIntents
import AnimationCache
import MultiAnimationRenderer
import ObjectiveC
import UndoUI
import ChatMessagePaymentAlertController

private var ObjCKey_DeinitWatcher: Int?

public struct ShareControllerAction {
    let title: String
    let action: () -> Void
    
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
    let title: String
    let subject: ShareControllerSubject
    let actionTitle: String
    let formatSendTitle: (Int) -> String
    
    public init(title: String, subject: ShareControllerSubject, actionTitle: String, formatSendTitle: @escaping (Int) -> String) {
        self.title = title
        self.subject = subject
        self.actionTitle = actionTitle
        self.formatSendTitle = formatSendTitle
    }
}

private enum ExternalShareItem {
    case text(String)
    case url(URL)
    case image(UIImage)
    case file(URL, String, String)
}

private enum ExternalShareItemStatus {
    case progress
    case done(ExternalShareItem)
}

private enum ExternalShareResourceStatus {
    case progress
    case done(MediaResourceData)
}

private func collectExternalShareResource(postbox: Postbox, resourceReference: MediaResourceReference, statsCategory: MediaResourceStatsCategory) -> Signal<ExternalShareResourceStatus, NoError> {
    return Signal { subscriber in
        let fetched = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: .other, userContentType: .other, reference: resourceReference, statsCategory: statsCategory).start()
        let data = postbox.mediaBox.resourceData(resourceReference.resource, option: .complete(waitUntilFetchStatus: false)).start(next: { value in
            if value.complete {
                subscriber.putNext(.done(value))
            } else {
                subscriber.putNext(.progress)
            }
        })
        
        return ActionDisposable {
            fetched.dispose()
            data.dispose()
        }
    }
}

private enum ExternalShareItemsState {
    case progress
    case done([ExternalShareItem])
}

private struct CollectableExternalShareItem {
    let url: String?
    let text: String
    let author: PeerId?
    let timestamp: Int32?
    let mediaReference: AnyMediaReference?
}

private func collectExternalShareItems(strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameOrder: PresentationPersonNameOrder, engine: TelegramEngine, postbox: Postbox, collectableItems: [CollectableExternalShareItem], takeOne: Bool = true) -> Signal<ExternalShareItemsState, NoError> {
    var signals: [Signal<ExternalShareItemStatus, NoError>] = []
    let authorsPeerIds = collectableItems.compactMap { $0.author }
    let authorsPromise = Promise<[PeerId: String]>()
    
    let peerTitles = engine.data.get(EngineDataMap(
        authorsPeerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
    ))
    |> map { peerMap -> [EnginePeer.Id: String] in
        return peerMap.compactMapValues { peer -> String? in
            return peer?.displayTitle(strings: strings, displayOrder: nameOrder)
        }
    }
    
    authorsPromise.set(peerTitles)
    for item in collectableItems {
        if let mediaReference = item.mediaReference, let file = mediaReference.media as? TelegramMediaFile {
            signals.append(collectExternalShareResource(postbox: postbox, resourceReference: mediaReference.resourceReference(file.resource), statsCategory: statsCategoryForFileWithAttributes(file.attributes))
                |> mapToSignal { next -> Signal<ExternalShareItemStatus, NoError> in
                    switch next {
                        case .progress:
                            return .single(.progress)
                        case let .done(data):
                            if file.isSticker, !file.isAnimatedSticker, let dimensions = file.dimensions {
                                return chatMessageSticker(postbox: postbox, userLocation: .other, file: file, small: false, fetched: true, onlyFullSize: true)
                                |> map { f -> ExternalShareItemStatus in
                                    let context = f(TransformImageArguments(corners: ImageCorners(), imageSize: dimensions.cgSize, boundingSize: dimensions.cgSize, intrinsicInsets: UIEdgeInsets(), emptyColor: nil, scale: 1.0))
                                    if let image = context?.generateImage() {
                                        return .done(.image(image))
                                    } else {
                                        return .progress
                                    }
                                }
                            } else {
                                let fileName: String
                                if let value = file.fileName {
                                    fileName = value
                                } else if file.isVideo {
                                    fileName = "telegram_video.mp4"
                                } else if file.isVoice {
                                    fileName = "telegram_audio.ogg"
                                } else {
                                    fileName = "file"
                                }
                                let randomDirectory = UUID()
                                let safeFileName = fileName.replacingOccurrences(of: "/", with: "_")
                                let fileDirectory = NSTemporaryDirectory() + "\(randomDirectory)"
                                let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: fileDirectory), withIntermediateDirectories: true, attributes: nil)
                                let filePath = fileDirectory + "/\(safeFileName)"
                                if let _ = try? FileManager.default.copyItem(at: URL(fileURLWithPath: data.path), to: URL(fileURLWithPath: filePath)) {
                                    return .single(.done(.file(URL(fileURLWithPath: filePath), fileName, file.mimeType)))
                                } else {
                                    return .single(.progress)
                                }
                            }
                    }
            })
        } else if let mediaReference = item.mediaReference, let image = mediaReference.media as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
            signals.append(collectExternalShareResource(postbox: postbox, resourceReference: mediaReference.resourceReference(largest.resource), statsCategory: .image)
            |> map { next -> ExternalShareItemStatus in
                switch next {
                    case .progress:
                        return .progress
                    case let .done(data):
                        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: data.path)) else {
                            return .progress
                        }
                        if let image = UIImage(data: fileData) {
                            return .done(.image(image))
                        } else {
                            #if DEBUG
                            if "".isEmpty {
                                return .done(.file(URL(fileURLWithPath: data.path), "image.bin", "application/octet-stream"))
                            }
                            #endif
                            return .progress
                        }
                }
            })
        } else if let mediaReference = item.mediaReference, let poll = mediaReference.media as? TelegramMediaPoll {
            var text = "📊 \(poll.text)"
            text.append("\n\(strings.MessagePoll_LabelAnonymous)")
            for option in poll.options {
                text.append("\n— \(option.text)")
            }
            let totalVoters = poll.results.totalVoters ?? 0
            switch poll.kind {
            case .poll:
                if totalVoters == 0 {
                    text.append("\n\(strings.MessagePoll_NoVotes)")
                } else {
                    text.append("\n\(strings.MessagePoll_VotedCount(totalVoters))")
                }
            case .quiz:
                if totalVoters == 0 {
                    text.append("\n\(strings.MessagePoll_QuizNoUsers)")
                } else {
                    text.append("\n\(strings.MessagePoll_QuizCount(totalVoters))")
                }
            }
            signals.append(.single(.done(.text(text))))
        } else if let mediaReference = item.mediaReference, let contact = mediaReference.media as? TelegramMediaContact {
            let contactData: DeviceContactExtendedData
            if let vCard = contact.vCardData, let vCardData = vCard.data(using: .utf8), let parsed = DeviceContactExtendedData(vcard: vCardData) {
                contactData = parsed
            } else {
                contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName, lastName: contact.lastName, phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: contact.phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
            }
            
            if let vCard = contactData.serializedVCard() {
                let fullName = [contact.firstName, contact.lastName].filter { !$0.isEmpty }.joined(separator: " ")
                let fileName = "\(fullName).vcf"
                let randomDirectory = UUID()
                let safeFileName = fileName.replacingOccurrences(of: "/", with: "_")
                let fileDirectory = NSTemporaryDirectory() + "\(randomDirectory)"
                let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: fileDirectory), withIntermediateDirectories: true, attributes: nil)
                let filePath = fileDirectory + "/\(safeFileName)"
                let vCardData = vCard.data(using: .utf8)
                if let _ = try? vCardData?.write(to: URL(fileURLWithPath: filePath)) {
                    signals.append(.single(.done(.file(URL(fileURLWithPath: filePath), fileName, "text/x-vcard"))))
                }
            }
        }
        if let url = item.url, let parsedUrl = URL(string: url) {
            if signals.isEmpty || !takeOne {
                signals.append(.single(.done(.url(parsedUrl))))
            }
        }
        if !item.text.isEmpty {
            if signals.isEmpty || !takeOne {
                let author: Signal<String?, NoError>
                if let peerId = item.author {
                    author = authorsPromise.get()
                    |> take(1)
                    |> map { authors in
                        return authors[peerId]
                    }
                } else {
                    author = .single(nil)
                }
                signals.append(author
                |> map { author in
                    var text: String = item.text
                    var metadata: [String] = []
                    if let author = author {
                       metadata.append(author)
                    }
                    if let timestamp = item.timestamp {
                        metadata.append("[\(stringForFullDate(timestamp: timestamp, strings: strings, dateTimeFormat: dateTimeFormat))]")
                    }
                    if !metadata.isEmpty {
                        text = metadata.joined(separator: ", ") + "\n" + text + "\n"
                    }
                    return .done(.text(text))
                })
            }
        }
    }
    return combineLatest(signals)
    |> map { statuses -> ExternalShareItemsState in
        var items: [ExternalShareItem] = []
        for status in statuses {
            switch status {
                case .progress:
                    return .progress
                case let .done(item):
                    items.append(item)
            }
        }
        return .done(items)
    }
    |> distinctUntilChanged(isEqual: { lhs, rhs in
        if case .progress = lhs, case .progress = rhs {
            return true
        } else {
            return false
        }
    })
}

public final class ShareControllerAppEnvironment: ShareControllerEnvironment {
    let sharedContext: SharedAccountContext
    
    public private(set) var presentationData: PresentationData
    public var updatedPresentationData: Signal<PresentationData, NoError> {
        return self.sharedContext.presentationData
    }
    public var isMainApp: Bool {
        return self.sharedContext.applicationBindings.isMainApp
    }
    public var energyUsageSettings: EnergyUsageSettings {
        return self.sharedContext.energyUsageSettings
    }
    
    public var mediaManager: MediaManager? {
        return self.sharedContext.mediaManager
    }
    
    public init(sharedContext: SharedAccountContext) {
        self.sharedContext = sharedContext
        
        self.presentationData = sharedContext.currentPresentationData.with { $0 }
    }
    
    public func setAccountUserInterfaceInUse(id: AccountRecordId) -> Disposable {
        return self.sharedContext.setAccountUserInterfaceInUse(id)
    }
    
    public func donateSendMessageIntent(account: ShareControllerAccountContext, peerIds: [EnginePeer.Id]) {
        if let account = account as? ShareControllerAppAccountContext {
            TelegramIntents.donateSendMessageIntent(account: account.context.account, sharedContext: self.sharedContext, intentContext: .share, peerIds: peerIds)
        } else {
            assertionFailure()
        }
    }
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

public final class ShareControllerSwitchableAccount: Equatable {
    public let account: ShareControllerAccountContext
    public let peer: Peer
    
    public init(account: ShareControllerAccountContext, peer: Peer) {
        self.account = account
        self.peer = peer
    }
    
    public static func ==(lhs: ShareControllerSwitchableAccount, rhs: ShareControllerSwitchableAccount) -> Bool {
        if lhs.account !== rhs.account {
            return false
        }
        if !arePeersEqual(lhs.peer, rhs.peer) {
            return false
        }
        return true
    }
}

public final class ShareController: ViewController {
    private var controllerNode: ShareControllerNode {
        return self.displayNode as! ShareControllerNode
    }
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var animatedIn = false
    
    private let environment: ShareControllerEnvironment
    private var currentContext: ShareControllerAccountContext
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let forceTheme: PresentationTheme?
    private let shareAsLink: Bool
    
    private let externalShare: Bool
    private let immediateExternalShare: Bool
    private let subject: ShareControllerSubject
    private let presetText: String?
    private let switchableAccounts: [ShareControllerSwitchableAccount]
    private let immediatePeerId: PeerId?
    private let segmentedValues: [ShareControllerSegmentedValue]?
    private let fromForeignApp: Bool
    private let collectibleItemInfo: TelegramCollectibleItemInfo?
    
    private let peers = Promise<([(peer: EngineRenderedPeer, presence: EnginePeer.Presence?, requiresPremiumForMessaging: Bool, requiresStars: Int64?)], EnginePeer)>()
    private let peersDisposable = MetaDisposable()
    private let readyDisposable = MetaDisposable()
    private let accountActiveDisposable = MetaDisposable()
    
    private var defaultAction: ShareControllerAction?
    public private(set) var actionIsMediaSaving = false
    
    public var actionCompleted: (() -> Void)?
    public var dismissed: ((Bool) -> Void)?
    public var completed: (([PeerId]) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                self.controllerNode.completed = completed
            }
        }
    }
    public var enqueued: (([PeerId], [Int64]) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                self.controllerNode.enqueued = enqueued
            }
        }
    }
    
    public var openShareAsImage: (([Message]) -> Void)?
    
    public var shareStory: (() -> Void)?

    public var debugAction: (() -> Void)?
    
    public var onMediaTimestampLinkCopied: ((Int32?) -> Void)?
    
    public var parentNavigationController: NavigationController?
    
    public convenience init(context: AccountContext, subject: ShareControllerSubject, presetText: String? = nil, preferredAction: ShareControllerPreferredAction = .default, showInChat: ((Message) -> Void)? = nil, fromForeignApp: Bool = false, segmentedValues: [ShareControllerSegmentedValue]? = nil, externalShare: Bool = true, immediateExternalShare: Bool = false, switchableAccounts: [AccountWithInfo] = [], immediatePeerId: PeerId? = nil, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, forceTheme: PresentationTheme? = nil, forcedActionTitle: String? = nil, shareAsLink: Bool = false, collectibleItemInfo: TelegramCollectibleItemInfo? = nil) {
        self.init(
            environment: ShareControllerAppEnvironment(sharedContext: context.sharedContext),
            currentContext: ShareControllerAppAccountContext(context: context),
            subject: subject,
            presetText: presetText,
            preferredAction: preferredAction,
            showInChat: showInChat,
            fromForeignApp: fromForeignApp,
            segmentedValues: segmentedValues,
            externalShare: externalShare,
            immediateExternalShare: immediateExternalShare,
            switchableAccounts: switchableAccounts.map { info in
                return ShareControllerSwitchableAccount(account: ShareControllerAppAccountContext(context: context.sharedContext.makeTempAccountContext(account: info.account)), peer: info.peer)
            },
            immediatePeerId: immediatePeerId,
            updatedPresentationData: updatedPresentationData,
            forceTheme: forceTheme,
            forcedActionTitle: forcedActionTitle,
            shareAsLink: shareAsLink,
            collectibleItemInfo: collectibleItemInfo
        )
    }
    
    public init(environment: ShareControllerEnvironment, currentContext: ShareControllerAccountContext, subject: ShareControllerSubject, presetText: String? = nil, preferredAction: ShareControllerPreferredAction = .default, showInChat: ((Message) -> Void)? = nil, fromForeignApp: Bool = false, segmentedValues: [ShareControllerSegmentedValue]? = nil, externalShare: Bool = true, immediateExternalShare: Bool = false, switchableAccounts: [ShareControllerSwitchableAccount] = [], immediatePeerId: PeerId? = nil, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, forceTheme: PresentationTheme? = nil, forcedActionTitle: String? = nil, shareAsLink: Bool = false, collectibleItemInfo: TelegramCollectibleItemInfo? = nil) {
        self.environment = environment
        self.currentContext = currentContext
        self.subject = subject
        self.presetText = presetText
        self.externalShare = externalShare
        self.immediateExternalShare = immediateExternalShare
        self.switchableAccounts = switchableAccounts
        self.immediatePeerId = immediatePeerId
        self.fromForeignApp = fromForeignApp
        self.segmentedValues = segmentedValues
        self.forceTheme = forceTheme
        self.shareAsLink = shareAsLink
        self.collectibleItemInfo = collectibleItemInfo
        
        self.presentationData = updatedPresentationData?.initial ?? environment.presentationData
        if let forceTheme = self.forceTheme {
            self.presentationData = self.presentationData.withUpdated(theme: forceTheme)
        }
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        self.automaticallyControlPresentationContextLayout = false
        
        switch subject {
            case let .url(text):
                self.defaultAction = ShareControllerAction(title: forcedActionTitle ?? self.presentationData.strings.ShareMenu_CopyShareLink, action: { [weak self] in
                    if let strongSelf = self, let segmentedValues = segmentedValues {
                        let selectedValue = segmentedValues[strongSelf.controllerNode.selectedSegmentedIndex]
                        if case let .url(text) = selectedValue.subject {
                            UIPasteboard.general.string = text
                        }
                    } else {
                        UIPasteboard.general.string = text
                    }
                    self?.controllerNode.cancel?()
                    
                    self?.actionCompleted?()
                })
            case .text:
                break
            case let .mapMedia(media):
                self.defaultAction = ShareControllerAction(title: self.presentationData.strings.ShareMenu_CopyShareLink, action: { [weak self] in
                    let latLong = "\(media.latitude),\(media.longitude)"
                    let url = "https://maps.apple.com/maps?ll=\(latLong)&q=\(latLong)&t=m"
                    UIPasteboard.general.string = url
                    self?.controllerNode.cancel?()
                    
                    self?.actionCompleted?()
                })
                break
            case .quote:
                break
            case let .image(representations):
                if case .saveToCameraRoll = preferredAction {
                    self.actionIsMediaSaving = true
                    self.defaultAction = ShareControllerAction(title: self.presentationData.strings.Gallery_SaveImage, action: { [weak self] in
                        self?.saveToCameraRoll(representations: representations)
                        self?.actionCompleted?()
                    })
                }
            case let .media(mediaReference, _):
                var canSave = false
                var isVideo = false
                if mediaReference.media is TelegramMediaImage {
                    canSave = true
                } else if let file = mediaReference.media as? TelegramMediaFile {
                    canSave = true
                    isVideo = file.isVideo
                }
                if let currentContext = currentContext as? ShareControllerAppAccountContext, case .saveToCameraRoll = preferredAction, canSave {
                    self.actionIsMediaSaving = true
                    self.defaultAction = ShareControllerAction(title: isVideo ? self.presentationData.strings.Gallery_SaveVideo : self.presentationData.strings.Gallery_SaveImage, action: { [weak self] in
                        if let strongSelf = self {
                            if case let .message(message, media) = mediaReference, let messageId = message.id, let file = media as? TelegramMediaFile {
                                let _ = (messageMediaFileStatus(context: currentContext.context, messageId: messageId, file: file)
                                |> take(1)
                                |> deliverOnMainQueue).start(next: { [weak self] fetchStatus in
                                    if let strongSelf = self {
                                        if case .Local = fetchStatus {
                                            strongSelf.saveToCameraRoll(mediaReference: mediaReference, completion: nil)
                                            strongSelf.actionCompleted?()
                                        } else {
                                            strongSelf.saveToCameraRoll(mediaReference: mediaReference, completion: {
                                            })
                                        }
                                    }
                                })
                            } else {
                                strongSelf.saveToCameraRoll(mediaReference: mediaReference, completion: nil)
                                strongSelf.actionCompleted?()
                            }
                        }
                    })
                }
            case let .messages(messages):
                if case .saveToCameraRoll = preferredAction {
                    self.actionIsMediaSaving = true
                    self.defaultAction = ShareControllerAction(title: self.presentationData.strings.Preview_SaveToCameraRoll, action: { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        let actionCompleted = strongSelf.actionCompleted
                        strongSelf.saveToCameraRoll(messages: messages, completion: {
                            actionCompleted?()
                            
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.controllerNode.animateOut(shared: false, completion: {
                                self?.presentingViewController?.dismiss(animated: false, completion: nil)
                            })
                        })
                    })
                } else if let message = messages.first {
                    let groupingKey: Int64? = message.groupingKey
                    var sameGroupingKey = groupingKey != nil
                    if sameGroupingKey {
                        for message in messages {
                            if message.groupingKey != groupingKey {
                                sameGroupingKey = false
                                break
                            }
                        }
                    }
                    if let showInChat = showInChat, messages.count == 1 {
                        self.defaultAction = ShareControllerAction(title: self.presentationData.strings.SharedMedia_ViewInChat, action: { [weak self] in
                            self?.controllerNode.cancel?()
                            showInChat(message)
                            self?.actionCompleted?()
                        })
                    } else if let chatPeer = message.peers[message.id.peerId] as? TelegramChannel, messages.count == 1 || sameGroupingKey {
                        if message.id.namespace == Namespaces.Message.Cloud {
                            self.defaultAction = ShareControllerAction(title: self.presentationData.strings.ShareMenu_CopyShareLink, action: { [weak self] in
                                guard let strongSelf = self else {
                                    return
                                }
                                let _ = (_internal_exportMessageLink(postbox: strongSelf.currentContext.stateManager.postbox, network: strongSelf.currentContext.stateManager.network, peerId: chatPeer.id, messageId: message.id)
                                |> map { result -> String? in
                                    return result
                                }
                                |> deliverOnMainQueue).start(next: { link in
                                    if let link = link {
                                        UIPasteboard.general.string = link
                                    }
                                })
                                strongSelf.controllerNode.cancel?()
                                strongSelf.actionCompleted?()
                            })
                        }
                    }
                }
            case .fromExternal:
                break
        }
        
        if case let .custom(action) = preferredAction {
            self.defaultAction = ShareControllerAction(title: action.title, action: { [weak self] in
                self?.controllerNode.cancel?()
                action.action()
                self?.actionCompleted?()
            })
        }
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? self.environment.updatedPresentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        self.switchToAccount(account: self.currentContext, animateIn: false)
        
        if self.fromForeignApp {
            if let application = UIApplication.value(forKeyPath: #keyPath(UIApplication.shared)) as? UIApplication {
                application.isIdleTimerDisabled = true
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.peersDisposable.dispose()
        self.readyDisposable.dispose()
        self.accountActiveDisposable.dispose()
        
        if self.fromForeignApp {
            if let application = UIApplication.value(forKeyPath: #keyPath(UIApplication.shared)) as? UIApplication {
                application.isIdleTimerDisabled = false
            }
        }
    }
    
    override public func loadDisplayNode() {
        var fromPublicChannel = false
        var messageCount: Int = 1
        if case let .messages(messages) = self.subject, let message = messages.first, let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
            fromPublicChannel = true
        } else if case let .url(link) = self.subject, link.contains("t.me/nft/") {
            fromPublicChannel = true
        }
        
        if case let .messages(messages) = self.subject {
            messageCount = messages.count
        } else if case .image = self.subject {
            messageCount = 1
        } else if case let .fromExternal(count, _) = self.subject {
            messageCount = count
        }
        
        var mediaParameters: ShareControllerSubject.MediaParameters?
        if case let .media(_, parameters) = self.subject {
            mediaParameters = parameters
        }
        
        self.displayNode = ShareControllerNode(controller: self, environment: self.environment, presentationData: self.presentationData, presetText: self.presetText, defaultAction: self.defaultAction, mediaParameters: mediaParameters, requestLayout: { [weak self] transition in
            self?.requestLayout(transition: transition)
        }, presentError: { [weak self] title, text in
            guard let strongSelf = self else {
                return
            }
            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: title, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
        }, externalShare: self.externalShare, immediateExternalShare: self.immediateExternalShare, immediatePeerId: self.immediatePeerId, fromForeignApp: self.fromForeignApp, forceTheme: self.forceTheme, fromPublicChannel: fromPublicChannel, segmentedValues: self.segmentedValues, shareStory: self.shareStory, collectibleItemInfo: self.collectibleItemInfo, messageCount: messageCount)
        self.controllerNode.completed = self.completed
        self.controllerNode.enqueued = self.enqueued
        self.controllerNode.present = { [weak self] c in
            self?.presentInGlobalOverlay(c)
        }
        self.controllerNode.dismiss = { [weak self] shared in
            self?.dismissed?(shared)
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.cancel = { [weak self] in
            self?.controllerNode.view.endEditing(true)
            self?.controllerNode.animateOut(shared: false, completion: {
                self?.dismissed?(false)
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
            })
        }
        
        self.controllerNode.tryShare = { [weak self] text, peers in
            guard let strongSelf = self else {
                return false
            }
            
            var subject = strongSelf.subject
            if let segmentedValues = strongSelf.segmentedValues {
                let selectedValue = segmentedValues[strongSelf.controllerNode.selectedSegmentedIndex]
                subject = selectedValue.subject
            }
            
            switch subject {
            case .url:
                for peer in peers {
                    var banSendText = false
                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendText) != nil {
                        banSendText = true
                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendText) {
                        banSendText = true
                    }
                    
                    if banSendText {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return false
                    }
                }
            case .text:
                for peer in peers {
                    var banSendText = false
                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendText) != nil {
                        banSendText = true
                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendText) {
                        banSendText = true
                    }
                    
                    if banSendText {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return false
                    }
                }
            case .quote:
                for peer in peers {
                    var banSendText = false
                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendText) != nil {
                        banSendText = true
                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendText) {
                        banSendText = true
                    }
                    
                    if banSendText {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return false
                    }
                }
            case .image:
                for peer in peers {
                    var banSendPhotos = false
                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendPhotos) != nil {
                        banSendPhotos = true
                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendPhotos) {
                        banSendPhotos = true
                    }
                    
                    if banSendPhotos {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return false
                    }
                }
            case let .media(mediaReference, _):
                var sendTextAsCaption = false
                if mediaReference.media is TelegramMediaImage || mediaReference.media is TelegramMediaFile {
                    sendTextAsCaption = true
                }
                
                for peer in peers {
                    var banSendType = false
                    if mediaReference.media is TelegramMediaImage {
                        if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendPhotos) != nil {
                            banSendType = true
                        } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendPhotos) {
                            banSendType = true
                        }
                    } else if let file = mediaReference.media as? TelegramMediaFile {
                        if file.isSticker || file.isAnimated {
                            if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendStickers) != nil {
                                banSendType = true
                            } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendStickers) {
                                banSendType = true
                            }
                        } else if file.isInstantVideo {
                            if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendInstantVideos) != nil {
                                banSendType = true
                            } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendInstantVideos) {
                                banSendType = true
                            }
                        } else if file.isVoice {
                            if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendVoice) != nil {
                                banSendType = true
                            } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendVoice) {
                                banSendType = true
                            }
                        } else if file.isMusic {
                            if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendMusic) != nil {
                                banSendType = true
                            } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendMusic) {
                                banSendType = true
                            }
                        } else if file.isVideo {
                            if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendVideos) != nil {
                                banSendType = true
                            } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendVideos) {
                                banSendType = true
                            }
                        } else {
                            if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendFiles) != nil {
                                banSendType = true
                            } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendFiles) {
                                banSendType = true
                            }
                        }
                    }
                    
                    if banSendType {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return false
                    }
                    
                    if !text.isEmpty && !sendTextAsCaption {
                        var banSendText = false
                        if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendText) != nil {
                            banSendText = true
                        } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendText) {
                            banSendText = true
                        }
                        
                        if banSendText {
                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            
                            return false
                        }
                    }
                }
            case .mapMedia:
                for peer in peers {
                    var banSendText = false
                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendText) != nil {
                        banSendText = true
                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendText) {
                        banSendText = true
                    }
                    
                    if banSendText {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return false
                    }
                }
            case let .messages(messages):
                for peer in peers {
                    if !text.isEmpty {
                        var banSendText = false
                        if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendText) != nil {
                            banSendText = true
                        } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendText) {
                            banSendText = true
                        }
                        
                        if banSendText {
                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            
                            return false
                        }
                    }
                    for message in messages {
                        for media in message.media {
                            var banSendType = false
                            if media is TelegramMediaImage {
                                if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendPhotos) != nil {
                                    banSendType = true
                                } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendPhotos) {
                                    banSendType = true
                                }
                            } else if let file = media as? TelegramMediaFile {
                                if file.isSticker || file.isAnimated {
                                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendStickers) != nil {
                                        banSendType = true
                                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendStickers) {
                                        banSendType = true
                                    }
                                } else if file.isInstantVideo {
                                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendInstantVideos) != nil {
                                        banSendType = true
                                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendInstantVideos) {
                                        banSendType = true
                                    }
                                } else if file.isVoice {
                                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendVoice) != nil {
                                        banSendType = true
                                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendVoice) {
                                        banSendType = true
                                    }
                                } else if file.isMusic {
                                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendMusic) != nil {
                                        banSendType = true
                                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendMusic) {
                                        banSendType = true
                                    }
                                } else if file.isVideo {
                                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendVideos) != nil {
                                        banSendType = true
                                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendVideos) {
                                        banSendType = true
                                    }
                                } else {
                                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendFiles) != nil {
                                        banSendType = true
                                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendFiles) {
                                        banSendType = true
                                    }
                                }
                            } else if media is TelegramMediaContact || media is TelegramMediaMap {
                                if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendText) != nil {
                                    banSendType = true
                                } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendText) {
                                    banSendType = true
                                }
                            }
                            
                            if banSendType {
                                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                
                                return false
                            }
                        }
                    }
                }
            case .fromExternal:
                break
            }
            
            return true
        }
        
        self.controllerNode.share = { [weak self] text, peerIds, topicIds, showNames, silently in
            guard let self else {
                return .complete()
            }
            
            var useLegacy = false
            if self.environment.isMainApp {
                useLegacy = true
            }
            if let currentContext = self.currentContext as? ShareControllerAppAccountContext, let data = currentContext.context.currentAppConfiguration.with({ $0 }).data {
                if let _ = data["ios_disable_modern_sharing"] {
                    useLegacy = true
                }
            }
            
            if useLegacy {
                return self.shareLegacy(text: text, peerIds: peerIds, topicIds: topicIds, showNames: showNames, silently: silently)
            } else {
                return self.shareModern(text: text, peerIds: peerIds, topicIds: topicIds, showNames: showNames, silently: silently)
            }
        }
        self.controllerNode.shareExternal = { [weak self] _ in
            if let strongSelf = self, let currentContext = strongSelf.currentContext as? ShareControllerAppAccountContext {
                var collectableItems: [CollectableExternalShareItem] = []
                var subject = strongSelf.subject
                if let segmentedValues = strongSelf.segmentedValues {
                    let selectedValue = segmentedValues[strongSelf.controllerNode.selectedSegmentedIndex]
                    subject = selectedValue.subject
                }
                var messageUrl: String?
                switch subject {
                    case let .url(text):
                        collectableItems.append(CollectableExternalShareItem(url: explicitUrl(text), text: "", author: nil, timestamp: nil, mediaReference: nil))
                    case let .text(string):
                        collectableItems.append(CollectableExternalShareItem(url: "", text: string, author: nil, timestamp: nil, mediaReference: nil))
                    case let .quote(text, url):
                        collectableItems.append(CollectableExternalShareItem(url: "", text: "\"\(text)\"\n\n\(url)", author: nil, timestamp: nil, mediaReference: nil))
                    case let .image(representations):
                        let media = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: Int64.random(in: Int64.min ... Int64.max)), representations: representations.map({ $0.representation }), immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                        collectableItems.append(CollectableExternalShareItem(url: "", text: "", author: nil, timestamp: nil, mediaReference: .standalone(media: media)))
                    case let .media(mediaReference, _):
                        collectableItems.append(CollectableExternalShareItem(url: "", text: "", author: nil, timestamp: nil, mediaReference: mediaReference))
                    case let .mapMedia(media):
                        let latLong = "\(media.latitude),\(media.longitude)"
                        collectableItems.append(CollectableExternalShareItem(url: "https://maps.apple.com/maps?ll=\(latLong)&q=\(latLong)&t=m", text: "", author: nil, timestamp: nil, mediaReference: nil))
                    case let .messages(messages):
                        for message in messages {
                            var url: String?
                            var selectedMedia: Media?
                            loop: for media in message.media {
                                switch media {
                                    case _ as TelegramMediaImage, _ as TelegramMediaFile:
                                        selectedMedia = media
                                        break loop
                                    case let webpage as TelegramMediaWebpage:
                                        if case let .Loaded(content) = webpage.content, ["photo", "document", "video", "gif"].contains(content.type) {
                                            if let file = content.file {
                                                selectedMedia = file
                                            } else if let image = content.image {
                                                selectedMedia = image
                                            }
                                        }
                                    case _ as TelegramMediaPoll:
                                        selectedMedia = media
                                        break loop
                                    default:
                                        break
                                }
                            }
                            if let chatPeer = message.peers[message.id.peerId] as? TelegramChannel {
                                if message.id.namespace == Namespaces.Message.Cloud, let addressName = chatPeer.addressName, !addressName.isEmpty {
                                    url = "https://t.me/\(addressName)/\(message.id.id)"
                                    if messageUrl == nil {
                                        messageUrl = url
                                    }
                                }
                            }
                            let accountPeerId = strongSelf.currentContext.accountPeerId
                            let authorPeerId: PeerId?
                            if let author = message.effectiveAuthor {
                                authorPeerId = author.id
                            } else if message.effectivelyIncoming(accountPeerId) {
                                authorPeerId = message.id.peerId
                            } else {
                                authorPeerId = accountPeerId
                            }
                            
                            var restrictedText: String?
                            for attribute in message.attributes {
                                if let attribute = attribute as? RestrictedContentMessageAttribute {
                                    restrictedText = attribute.platformText(platform: "ios", contentSettings: strongSelf.currentContext.contentSettings) ?? ""
                                }
                            }
                            
                            if let restrictedText = restrictedText {
                                collectableItems.append(CollectableExternalShareItem(url: url, text: restrictedText, author: authorPeerId, timestamp: message.timestamp, mediaReference: nil))
                            } else {
                                collectableItems.append(CollectableExternalShareItem(url: url, text: message.text, author: authorPeerId, timestamp: message.timestamp, mediaReference: selectedMedia.flatMap({ AnyMediaReference.message(message: MessageReference(message), media: $0) })))
                            }
                        }
                    case .fromExternal:
                        break
                }
                return (collectExternalShareItems(strings: strongSelf.presentationData.strings, dateTimeFormat: strongSelf.presentationData.dateTimeFormat, nameOrder: strongSelf.presentationData.nameDisplayOrder, engine: currentContext.context.engine, postbox: strongSelf.currentContext.stateManager.postbox, collectableItems: collectableItems, takeOne: !strongSelf.immediateExternalShare)
                |> deliverOnMainQueue)
                |> map { state in
                    switch state {
                        case .progress:
                            return .preparing
                        case let .done(items):
                            if let strongSelf = self, !items.isEmpty {
                                strongSelf._ready.set(.single(true))
                                var activityItems: [Any] = []
                                if strongSelf.shareAsLink, let messageUrl = messageUrl, let url = NSURL(string: messageUrl) {
                                    activityItems.append(url)
                                } else {
                                    for item in items {
                                        switch item {
                                            case let .url(url):
                                                activityItems.append(url as NSURL)
                                            case let .text(text):
                                                activityItems.append(text as NSString)
                                            case let .image(image):
                                                activityItems.append(image)
                                            case let .file(url, _, _):
                                                activityItems.append(url)
                                        }
                                    }
                                }
                                
                                let activities: [UIActivity]? = nil
                                let _ = (strongSelf.didAppearPromise.get()
                                |> filter { $0 }
                                |> take(1)
                                |> deliverOnMainQueue).start(next: { [weak self] _ in
                                    let activityController = UIActivityViewController(activityItems: activityItems, applicationActivities: activities)
                                    if let strongSelf = self, let window = strongSelf.view.window, let rootViewController = window.rootViewController {
                                        activityController.popoverPresentationController?.sourceView = window
                                        activityController.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
                                        rootViewController.present(activityController, animated: true, completion: nil)
                                        
                                        final class DeinitWatcher: NSObject {
                                            let f: () -> Void
                                            
                                            init(_ f: @escaping () -> Void) {
                                                self.f = f
                                            }
                                            
                                            deinit {
                                                f()
                                            }
                                        }
                                        
                                        let watchDisposable = MetaDisposable()
                                        objc_setAssociatedObject(activityController, &ObjCKey_DeinitWatcher, DeinitWatcher {
                                            watchDisposable.dispose()
                                        }, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                                        
                                        if case let .messages(messages) = subject {
                                            watchDisposable.set((currentContext.context.engine.data.subscribe(
                                                EngineDataMap(messages.map { TelegramEngine.EngineData.Item.Messages.Message(id: $0.id) })
                                            )
                                            |> deliverOnMainQueue).start(next: { [weak activityController] currentMessages in
                                                guard let activityController else {
                                                    return
                                                }
                                                var allFound = true
                                                for message in messages {
                                                    if let value = currentMessages[message.id], value != nil {
                                                    } else {
                                                        allFound = false
                                                        break
                                                    }
                                                }
                                                
                                                if !allFound {
                                                    activityController.presentingViewController?.dismiss(animated: true)
                                                }
                                            }))
                                        }
                                    }
                                })
                            }
                            return .done
                    }
                }
            } else {
                return .single(.done)
            }
        }
        self.controllerNode.switchToAnotherAccount = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.animateOut(shared: false, completion: {})
            
            let presentationData = strongSelf.environment.presentationData
            let controller = ActionSheetController(presentationData: presentationData)
            controller.dismissed = { [weak self] cancelled in
                if cancelled {
                    self?.controllerNode.animateIn()
                }
            }
            let dismissAction: () -> Void = { [weak controller] in
                controller?.dismissAnimated()
            }
            var items: [ActionSheetItem] = []
            for info in strongSelf.switchableAccounts {
                items.append(ActionSheetPeerItem(
                    accountPeerId: info.account.accountPeerId,
                    postbox: info.account.stateManager.postbox,
                    network: info.account.stateManager.network,
                    contentSettings: info.account.contentSettings,
                    peer: EnginePeer(info.peer),
                    title: EnginePeer(info.peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder),
                    isSelected: info.account.accountId == strongSelf.currentContext.accountId,
                    strings: presentationData.strings,
                    theme: presentationData.theme,
                    action: { [weak self] in
                        dismissAction()
                        self?.switchToAccount(account: info.account, animateIn: true)
                    }
                ))
            }
            controller.setItemGroups([
                ActionSheetItemGroup(items: items)
            ])
            strongSelf.view.endEditing(true)
            strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        }
        self.controllerNode.disabledPeerSelected = { [weak self] peer in
            guard let self else {
                return
            }
            
            self.forEachController { c in
                if let c = c as? UndoOverlayController {
                    c.dismiss()
                }
                return true
            }
            
            var hasAction = false
            if let context = self.currentContext as? ShareControllerAppAccountContext {
                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.context.currentAppConfiguration.with { $0 })
                if !premiumConfiguration.isPremiumDisabled {
                    hasAction = true
                }
            }
            
            self.present(UndoOverlayController(presentationData: presentationData, content: .premiumPaywall(title: nil, text: presentationData.strings.Chat_ToastMessagingRestrictedToPremium_Text(peer.compactDisplayTitle).string, customUndoText: hasAction ? presentationData.strings.Chat_ToastMessagingRestrictedToPremium_Action : nil, timeout: nil, linkAction: { _ in
            }), elevatedLayout: false, animateInAsReplacement: false, action: { [weak self] action in
                guard let self, let parentNavigationController = self.parentNavigationController, let context = self.currentContext as? ShareControllerAppAccountContext else {
                    return false
                }
                if case .undo = action {
                    self.controllerNode.cancel?()
                    
                    let premiumController = context.context.sharedContext.makePremiumIntroController(context: context.context, source: .settings, forceDark: false, dismissed: nil)
                    parentNavigationController.pushViewController(premiumController)
                }
                return false
            }), in: .current)
        }
        self.controllerNode.onMediaTimestampLinkCopied = { [weak self] timestamp in
            guard let self else {
                return
            }
            self.onMediaTimestampLinkCopied?(timestamp)
        }
        self.controllerNode.debugAction = { [weak self] in
            self?.debugAction?()
        }
        self.displayNodeDidLoad()
        
        self.peersDisposable.set((self.peers.get()
        |> deliverOnMainQueue).start(next: { [weak self] next in
            if let strongSelf = self {
                strongSelf.controllerNode.updatePeers(context: strongSelf.currentContext, switchableAccounts: strongSelf.switchableAccounts, peers: next.0, accountPeer: next.1, defaultAction: strongSelf.defaultAction)
            }
        }))
        self._ready.set(self.controllerNode.ready.get())
    }
    
    override public func loadView() {
        super.loadView()
    }
    
    private func shareModern(text: String, peerIds: [EnginePeer.Id], topicIds: [EnginePeer.Id: Int64], showNames: Bool, silently: Bool) -> Signal<ShareState, ShareControllerError> {
        return self.currentContext.stateManager.postbox.combinedView(
            keys: peerIds.map { peerId in
                return PostboxViewKey.peer(peerId: peerId, components: [])
            } + peerIds.map { peerId in
                return PostboxViewKey.cachedPeerData(peerId: peerId)
            }
        )
        |> take(1)
        |> map { views -> ([EnginePeer.Id: EnginePeer?], [EnginePeer.Id: StarsAmount]) in
            var result: [EnginePeer.Id: EnginePeer?] = [:]
            var requiresStars: [EnginePeer.Id: StarsAmount] = [:]
            for peerId in peerIds {
                if let view = views.views[PostboxViewKey.peer(peerId: peerId, components: [])] as? PeerView, let peer = peerViewMainPeer(view) {
                    result[peerId] = EnginePeer(peer)
                    if peer is TelegramUser, let cachedPeerDataView = views.views[PostboxViewKey.cachedPeerData(peerId: peerId)] as? CachedPeerDataView {
                        if let cachedData = cachedPeerDataView.cachedPeerData as? CachedUserData {
                            requiresStars[peerId] = cachedData.sendPaidMessageStars
                        }
                    } else if let channel = peer as? TelegramChannel {
                        requiresStars[peerId] = channel.sendPaidMessageStars
                    }
                }
            }
            return (result, requiresStars)
        }
        |> deliverOnMainQueue
        |> castError(ShareControllerError.self)
        |> mapToSignal { [weak self] peers, requiresStars -> Signal<ShareState, ShareControllerError> in
            guard let strongSelf = self else {
                return .complete()
            }
            
            var shareSignals: [Signal<StandaloneSendMessageStatus, StandaloneSendMessagesError>] = []
            var subject = strongSelf.subject
            if let segmentedValues = strongSelf.segmentedValues {
                let selectedValue = segmentedValues[strongSelf.controllerNode.selectedSegmentedIndex]
                subject = selectedValue.subject
            }
            
            func transformMessages(_ messages: [StandaloneSendEnqueueMessage], showNames: Bool, silently: Bool, sendPaidMessageStars: StarsAmount?) -> [StandaloneSendEnqueueMessage] {
                return messages.map { message in
                    var message = message
                    if !showNames {
                        message.forwardOptions = StandaloneSendEnqueueMessage.ForwardOptions(
                            hideNames: true,
                            hideCaptions: false
                        )
                    }
                    if silently {
                        message.isSilent = true
                    }
                    message.sendPaidMessageStars = sendPaidMessageStars
                    return message
                }
            }
            
            switch subject {
            case let .url(url):
                for peerId in peerIds {
                    guard let maybePeer = peers[peerId], let peer = maybePeer else {
                        continue
                    }
                    
                    var banSendText = false
                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendText) != nil {
                        banSendText = true
                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendText) {
                        banSendText = true
                    }
                    
                    if banSendText {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return .fail(.generic)
                    }
                    
                    var replyToMessageId: MessageId?
                    if let topicId = topicIds[peerId] {
                        replyToMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: topicId))
                    }
                    
                    var messages: [StandaloneSendEnqueueMessage] = []
                    if !text.isEmpty {
                        messages.append(StandaloneSendEnqueueMessage(
                            content: .text(text: StandaloneSendEnqueueMessage.Text(
                                string: url + "\n\n" + text,
                                entities: []
                            )),
                            replyToMessageId: replyToMessageId
                        ))
                    } else {
                        messages.append(StandaloneSendEnqueueMessage(
                            content: .text(text: StandaloneSendEnqueueMessage.Text(
                                string: url,
                                entities: []
                            )),
                            replyToMessageId: replyToMessageId
                        ))
                    }
                    messages = transformMessages(messages, showNames: showNames, silently: silently, sendPaidMessageStars: requiresStars[peerId])
                    shareSignals.append(standaloneSendEnqueueMessages(
                        accountPeerId: strongSelf.currentContext.accountPeerId,
                        postbox: strongSelf.currentContext.stateManager.postbox,
                        network: strongSelf.currentContext.stateManager.network,
                        stateManager: strongSelf.currentContext.stateManager,
                        auxiliaryMethods: AccountAuxiliaryMethods(fetchResource: { account, resource, ranges, _ in
                            return nil
                        }, fetchResourceMediaReferenceHash: { resource in
                            return .single(nil)
                        }, prepareSecretThumbnailData: { data in
                            return nil
                        }, backgroundUpload: { postbox, _, resource in
                            return .single(nil)
                        }),
                        peerId: peerId,
                        threadId: topicIds[peerId],
                        messages: messages
                    ))
                }
            case let .text(string):
                for peerId in peerIds {
                    guard let maybePeer = peers[peerId], let peer = maybePeer else {
                        continue
                    }
                    
                    var banSendText = false
                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendText) != nil {
                        banSendText = true
                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendText) {
                        banSendText = true
                    }
                    
                    if banSendText {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return .fail(.generic)
                    }
                    
                    var replyToMessageId: MessageId?
                    if let topicId = topicIds[peerId] {
                        replyToMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: topicId))
                    }
                    
                    var messages: [StandaloneSendEnqueueMessage] = []
                    if !text.isEmpty {
                        messages.append(StandaloneSendEnqueueMessage(
                            content: .text(text: StandaloneSendEnqueueMessage.Text(
                                string: text,
                                entities: []
                            )),
                            replyToMessageId: replyToMessageId
                        ))
                    }
                    messages.append(StandaloneSendEnqueueMessage(
                        content: .text(text: StandaloneSendEnqueueMessage.Text(
                            string: string,
                            entities: []
                        )),
                        replyToMessageId: replyToMessageId
                    ))
                    messages = transformMessages(messages, showNames: showNames, silently: silently, sendPaidMessageStars: requiresStars[peerId])
                    shareSignals.append(standaloneSendEnqueueMessages(
                        accountPeerId: strongSelf.currentContext.accountPeerId,
                        postbox: strongSelf.currentContext.stateManager.postbox,
                        network: strongSelf.currentContext.stateManager.network,
                        stateManager: strongSelf.currentContext.stateManager,
                        auxiliaryMethods: AccountAuxiliaryMethods(fetchResource: { account, resource, ranges, _ in
                            return nil
                        }, fetchResourceMediaReferenceHash: { resource in
                            return .single(nil)
                        }, prepareSecretThumbnailData: { data in
                            return nil
                        }, backgroundUpload: { postbox, _, resource in
                            return .single(nil)
                        }),
                        peerId: peerId,
                        threadId: topicIds[peerId],
                        messages: messages
                    ))
                }
            case let .quote(string, url):
                for peerId in peerIds {
                    guard let maybePeer = peers[peerId], let peer = maybePeer else {
                        continue
                    }
                    
                    var banSendText = false
                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendText) != nil {
                        banSendText = true
                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendText) {
                        banSendText = true
                    }
                    
                    if banSendText {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return .fail(.generic)
                    }
                    
                    var replyToMessageId: MessageId?
                    if let topicId = topicIds[peerId] {
                        replyToMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: topicId))
                    }
                    
                    var messages: [StandaloneSendEnqueueMessage] = []
                    if !text.isEmpty {
                        messages.append(StandaloneSendEnqueueMessage(
                            content: .text(text: StandaloneSendEnqueueMessage.Text(
                                string: text,
                                entities: []
                            )),
                            replyToMessageId: replyToMessageId
                        ))
                    }
                    let attributedText = NSMutableAttributedString(string: string, attributes: [ChatTextInputAttributes.italic: true as NSNumber])
                    attributedText.append(NSAttributedString(string: "\n\n\(url)"))
                    let entities = generateChatInputTextEntities(attributedText)
                    
                    messages.append(StandaloneSendEnqueueMessage(
                        content: .text(text: StandaloneSendEnqueueMessage.Text(
                            string: attributedText.string,
                            entities: entities
                        )),
                        replyToMessageId: replyToMessageId
                    ))
                    messages = transformMessages(messages, showNames: showNames, silently: silently, sendPaidMessageStars: requiresStars[peerId])
                    shareSignals.append(standaloneSendEnqueueMessages(
                        accountPeerId: strongSelf.currentContext.accountPeerId,
                        postbox: strongSelf.currentContext.stateManager.postbox,
                        network: strongSelf.currentContext.stateManager.network,
                        stateManager: strongSelf.currentContext.stateManager,
                        auxiliaryMethods: AccountAuxiliaryMethods(fetchResource: { account, resource, ranges, _ in
                            return nil
                        }, fetchResourceMediaReferenceHash: { resource in
                            return .single(nil)
                        }, prepareSecretThumbnailData: { data in
                            return nil
                        }, backgroundUpload: { postbox, _, resource in
                            return .single(nil)
                        }),
                        peerId: peerId,
                        threadId: topicIds[peerId],
                        messages: messages
                    ))
                }
            case let .image(representations):
                for peerId in peerIds {
                    guard let maybePeer = peers[peerId], let peer = maybePeer else {
                        continue
                    }
                    
                    var banSendPhotos = false
                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendPhotos) != nil {
                        banSendPhotos = true
                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendPhotos) {
                        banSendPhotos = true
                    }
                    
                    if banSendPhotos {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return .fail(.generic)
                    }
                    
                    var replyToMessageId: MessageId?
                    if let topicId = topicIds[peerId] {
                        replyToMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: topicId))
                    }
                    
                    var messages: [StandaloneSendEnqueueMessage] = []
                    
                    if let representation = representations.last {
                        messages.append(StandaloneSendEnqueueMessage(
                            content: .image(
                                image: StandaloneSendEnqueueMessage.Image(
                                    representation: representation.representation
                                ),
                                text: StandaloneSendEnqueueMessage.Text(
                                    string: text,
                                    entities: []
                                )
                            ),
                            replyToMessageId: replyToMessageId
                        ))
                    }
                    messages = transformMessages(messages, showNames: showNames, silently: silently, sendPaidMessageStars: requiresStars[peerId])
                    shareSignals.append(standaloneSendEnqueueMessages(
                        accountPeerId: strongSelf.currentContext.accountPeerId,
                        postbox: strongSelf.currentContext.stateManager.postbox,
                        network: strongSelf.currentContext.stateManager.network,
                        stateManager: strongSelf.currentContext.stateManager,
                        auxiliaryMethods: AccountAuxiliaryMethods(fetchResource: { account, resource, ranges, _ in
                            return nil
                        }, fetchResourceMediaReferenceHash: { resource in
                            return .single(nil)
                        }, prepareSecretThumbnailData: { data in
                            return nil
                        }, backgroundUpload: { postbox, _, resource in
                            return .single(nil)
                        }),
                        peerId: peerId,
                        threadId: topicIds[peerId],
                        messages: messages
                    ))
                }
            case let .media(mediaReference, _):
                var sendTextAsCaption = false
                if mediaReference.media is TelegramMediaImage || mediaReference.media is TelegramMediaFile {
                    sendTextAsCaption = true
                }
                
                for peerId in peerIds {
                    guard let maybePeer = peers[peerId], let peer = maybePeer else {
                        continue
                    }
                    
                    var banSendType = false
                    if mediaReference.media is TelegramMediaImage {
                        if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendPhotos) != nil {
                            banSendType = true
                        } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendPhotos) {
                            banSendType = true
                        }
                    } else if let file = mediaReference.media as? TelegramMediaFile {
                        if file.isSticker || file.isAnimated {
                            if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendStickers) != nil {
                                banSendType = true
                            } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendStickers) {
                                banSendType = true
                            }
                        } else if file.isInstantVideo {
                            if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendInstantVideos) != nil {
                                banSendType = true
                            } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendInstantVideos) {
                                banSendType = true
                            }
                        } else if file.isVoice {
                            if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendVoice) != nil {
                                banSendType = true
                            } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendVoice) {
                                banSendType = true
                            }
                        } else if file.isMusic {
                            if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendMusic) != nil {
                                banSendType = true
                            } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendMusic) {
                                banSendType = true
                            }
                        } else if file.isVideo {
                            if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendVideos) != nil {
                                banSendType = true
                            } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendVideos) {
                                banSendType = true
                            }
                        } else {
                            if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendFiles) != nil {
                                banSendType = true
                            } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendFiles) {
                                banSendType = true
                            }
                        }
                    }
                    
                    if banSendType {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return .fail(.generic)
                    }
                    
                    var replyToMessageId: MessageId?
                    if let topicId = topicIds[peerId] {
                        replyToMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: topicId))
                    }
                    
                    var messages: [StandaloneSendEnqueueMessage] = []
                    if !text.isEmpty && !sendTextAsCaption {
                        messages.append(StandaloneSendEnqueueMessage(
                            content: .text(text: StandaloneSendEnqueueMessage.Text(
                                string: text,
                                entities: []
                            )),
                            replyToMessageId: replyToMessageId
                        ))
                    }
                    
                    messages.append(StandaloneSendEnqueueMessage(
                        content: .arbitraryMedia(
                            media: mediaReference,
                            text: StandaloneSendEnqueueMessage.Text(
                                string: sendTextAsCaption ? text : "",
                                entities: []
                            )
                        ),
                        replyToMessageId: replyToMessageId
                    ))
                    messages = transformMessages(messages, showNames: showNames, silently: silently, sendPaidMessageStars: requiresStars[peerId])
                    shareSignals.append(standaloneSendEnqueueMessages(
                        accountPeerId: strongSelf.currentContext.accountPeerId,
                        postbox: strongSelf.currentContext.stateManager.postbox,
                        network: strongSelf.currentContext.stateManager.network,
                        stateManager: strongSelf.currentContext.stateManager,
                        auxiliaryMethods: AccountAuxiliaryMethods(fetchResource: { account, resource, ranges, _ in
                            return nil
                        }, fetchResourceMediaReferenceHash: { resource in
                            return .single(nil)
                        }, prepareSecretThumbnailData: { data in
                            return nil
                        }, backgroundUpload: { postbox, _, resource in
                            return .single(nil)
                        }),
                        peerId: peerId,
                        threadId: topicIds[peerId],
                        messages: messages
                    ))
                }
            case let .mapMedia(media):
                for peerId in peerIds {
                    guard let maybePeer = peers[peerId], let peer = maybePeer else {
                        continue
                    }
                    
                    var banSendText = false
                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendText) != nil {
                        banSendText = true
                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendText) {
                        banSendText = true
                    }
                    
                    if banSendText {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return .fail(.generic)
                    }
                    
                    var replyToMessageId: MessageId?
                    if let topicId = topicIds[peerId] {
                        replyToMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: topicId))
                    }
                    
                    var messages: [StandaloneSendEnqueueMessage] = []
                    if !text.isEmpty {
                        messages.append(StandaloneSendEnqueueMessage(
                            content: .text(text: StandaloneSendEnqueueMessage.Text(
                                string: text,
                                entities: []
                            )),
                            replyToMessageId: replyToMessageId
                        ))
                    }
                    
                    messages.append(StandaloneSendEnqueueMessage(
                        content: .map(map: media),
                        replyToMessageId: replyToMessageId
                    ))
                    messages = transformMessages(messages, showNames: showNames, silently: silently, sendPaidMessageStars: requiresStars[peerId])
                    shareSignals.append(standaloneSendEnqueueMessages(
                        accountPeerId: strongSelf.currentContext.accountPeerId,
                        postbox: strongSelf.currentContext.stateManager.postbox,
                        network: strongSelf.currentContext.stateManager.network,
                        stateManager: strongSelf.currentContext.stateManager,
                        auxiliaryMethods: AccountAuxiliaryMethods(fetchResource: { account, resource, ranges, _ in
                            return nil
                        }, fetchResourceMediaReferenceHash: { resource in
                            return .single(nil)
                        }, prepareSecretThumbnailData: { data in
                            return nil
                        }, backgroundUpload: { postbox, _, resource in
                            return .single(nil)
                        }),
                        peerId: peerId,
                        threadId: topicIds[peerId],
                        messages: messages
                    ))
                }
            case let .messages(messages):
                for peerId in peerIds {
                    guard let maybePeer = peers[peerId], let peer = maybePeer else {
                        continue
                    }
                    
                    var replyToMessageId: MessageId?
                    var threadId: Int64?
                    if let topicId = topicIds[peerId] {
                        replyToMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: topicId))
                        threadId = topicId
                    }
                    
                    var messagesToEnqueue: [StandaloneSendEnqueueMessage] = []
                    if !text.isEmpty {
                        var banSendText = false
                        if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendText) != nil {
                            banSendText = true
                        } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendText) {
                            banSendText = true
                        }
                        
                        if banSendText {
                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            
                            return .fail(.generic)
                        }
                        
                        messagesToEnqueue.append(StandaloneSendEnqueueMessage(
                            content: .text(text: StandaloneSendEnqueueMessage.Text(
                                string: text,
                                entities: []
                            )),
                            replyToMessageId: replyToMessageId
                        ))
                    }
                    for message in messages {
                        for media in message.media {
                            var banSendType = false
                            if media is TelegramMediaImage {
                                if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendPhotos) != nil {
                                    banSendType = true
                                } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendPhotos) {
                                    banSendType = true
                                }
                            } else if let file = media as? TelegramMediaFile {
                                if file.isSticker || file.isAnimated {
                                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendStickers) != nil {
                                        banSendType = true
                                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendStickers) {
                                        banSendType = true
                                    }
                                } else if file.isInstantVideo {
                                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendInstantVideos) != nil {
                                        banSendType = true
                                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendInstantVideos) {
                                        banSendType = true
                                    }
                                } else if file.isVoice {
                                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendVoice) != nil {
                                        banSendType = true
                                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendVoice) {
                                        banSendType = true
                                    }
                                } else if file.isMusic {
                                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendMusic) != nil {
                                        banSendType = true
                                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendMusic) {
                                        banSendType = true
                                    }
                                } else if file.isVideo {
                                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendVideos) != nil {
                                        banSendType = true
                                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendVideos) {
                                        banSendType = true
                                    }
                                } else {
                                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendFiles) != nil {
                                        banSendType = true
                                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendFiles) {
                                        banSendType = true
                                    }
                                }
                            }
                            
                            if banSendType {
                                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                
                                return .fail(.generic)
                            }
                        }
                        
                        messagesToEnqueue.append(StandaloneSendEnqueueMessage(
                            content: .forward(forward: StandaloneSendEnqueueMessage.Forward(
                                sourceId: message.id,
                                threadId: threadId
                            )),
                            replyToMessageId: replyToMessageId
                        ))
                    }
                    messagesToEnqueue = transformMessages(messagesToEnqueue, showNames: showNames, silently: silently, sendPaidMessageStars: requiresStars[peerId])
                    shareSignals.append(standaloneSendEnqueueMessages(
                        accountPeerId: strongSelf.currentContext.accountPeerId,
                        postbox: strongSelf.currentContext.stateManager.postbox,
                        network: strongSelf.currentContext.stateManager.network,
                        stateManager: strongSelf.currentContext.stateManager,
                        auxiliaryMethods: AccountAuxiliaryMethods(fetchResource: { account, resource, ranges, _ in
                            return nil
                        }, fetchResourceMediaReferenceHash: { resource in
                            return .single(nil)
                        }, prepareSecretThumbnailData: { data in
                            return nil
                        }, backgroundUpload: { postbox, _, resource in
                            return .single(nil)
                        }),
                        peerId: peerId,
                        threadId: topicIds[peerId],
                        messages: messagesToEnqueue
                    ))
                }
            case let .fromExternal(_, f):
                return f(peerIds, topicIds, requiresStars, text, strongSelf.currentContext, silently)
                |> map { state -> ShareState in
                    switch state {
                    case let .preparing(long):
                        return .preparing(long)
                    case let .progress(value):
                        return .progress(value)
                    case .done:
                        return .done([])
                    }
                }
            }
            let account = strongSelf.currentContext
            let queue = Queue.mainQueue()
            //var displayedError = false
            return combineLatest(queue: queue, shareSignals)
            |> `catch` { error -> Signal<[StandaloneSendMessageStatus], ShareControllerError> in
                Queue.mainQueue().async {
                    let _ = (account.stateManager.postbox.combinedView(keys: [PostboxViewKey.basicPeer(error.peerId)])
                    |> take(1)
                    |> map { views -> EnginePeer? in
                        if let view = views.views[PostboxViewKey.basicPeer(error.peerId)] as? BasicPeerView {
                            return view.peer.flatMap(EnginePeer.init)
                        } else {
                            return nil
                        }
                    }
                    |> deliverOnMainQueue).start(next: { peer in
                        guard let strongSelf = self, let peer = peer else {
                            return
                        }
                        if case .slowmodeActive = error.reason {
                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: strongSelf.presentationData.strings.Chat_SlowmodeSendError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        } else if case .mediaRestricted = error.reason {
                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        }
                    })
                }
                
                return .single([])
            }
            |> mapToSignal { progressSets -> Signal<ShareState, ShareControllerError> in
                if progressSets.isEmpty {
                    return .single(.done([]))
                }
                for item in progressSets {
                    if case .progress = item {
                        return .complete()
                    }
                }
                return .single(.done([]))
            }
        }
    }
    
    private func shareLegacy(text: String, peerIds: [EnginePeer.Id], topicIds: [EnginePeer.Id: Int64], showNames: Bool, silently: Bool) -> Signal<ShareState, ShareControllerError> {
        guard let currentContext = self.currentContext as? ShareControllerAppAccountContext else {
            return .single(.done([]))
        }
        return currentContext.stateManager.postbox.combinedView(
            keys: peerIds.map { peerId in
                return PostboxViewKey.peer(peerId: peerId, components: [])
            } + peerIds.map { peerId in
                return PostboxViewKey.cachedPeerData(peerId: peerId)
            }
        )
        |> take(1)
        |> map { views -> ([EnginePeer.Id: EnginePeer?], [EnginePeer.Id: StarsAmount]) in
            var result: [EnginePeer.Id: EnginePeer?] = [:]
            var requiresStars: [EnginePeer.Id: StarsAmount] = [:]
            for peerId in peerIds {
                if let view = views.views[PostboxViewKey.peer(peerId: peerId, components: [])] as? PeerView, let peer = peerViewMainPeer(view) {
                    result[peerId] = EnginePeer(peer)
                    if peer is TelegramUser, let cachedPeerDataView = views.views[PostboxViewKey.cachedPeerData(peerId: peerId)] as? CachedPeerDataView {
                        if let cachedData = cachedPeerDataView.cachedPeerData as? CachedUserData {
                            requiresStars[peerId] = cachedData.sendPaidMessageStars
                        }
                    } else if let channel = peer as? TelegramChannel {
                        requiresStars[peerId] = channel.sendPaidMessageStars
                    }
                }
            }
            return (result, requiresStars)
        }
        |> deliverOnMainQueue
        |> castError(ShareControllerError.self)
        |> mapToSignal { [weak self] peers, requiresStars -> Signal<ShareState, ShareControllerError> in
            guard let strongSelf = self, let currentContext = strongSelf.currentContext as? ShareControllerAppAccountContext else {
                return .complete()
            }
            
            var shareSignals: [Signal<[MessageId?], NoError>] = []
            var subject = strongSelf.subject
            if let segmentedValues = strongSelf.segmentedValues {
                let selectedValue = segmentedValues[strongSelf.controllerNode.selectedSegmentedIndex]
                subject = selectedValue.subject
            }
            
            func transformMessages(_ messages: [EnqueueMessage], showNames: Bool, silently: Bool, sendPaidMessageStars: StarsAmount?) -> [EnqueueMessage] {
                return messages.map { message in
                    return message.withUpdatedAttributes({ attributes in
                        var attributes = attributes
                        if !showNames {
                            attributes.append(ForwardOptionsMessageAttribute(hideNames: true, hideCaptions: false))
                        }
                        if silently {
                            attributes.append(NotificationInfoMessageAttribute(flags: .muted))
                        }
                        if let sendPaidMessageStars {
                            attributes.append(PaidStarsMessageAttribute(stars: sendPaidMessageStars, postponeSending: false))
                        }
                        return attributes
                    })
                }
            }
            
            var correlationIds: [Int64] = []
            
            switch subject {
            case let .url(url):
                for peerId in peerIds {
                    guard let maybePeer = peers[peerId], let peer = maybePeer else {
                        continue
                    }
                    
                    var banSendText = false
                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendText) != nil {
                        banSendText = true
                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendText) {
                        banSendText = true
                    }
                    
                    if banSendText {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return .fail(.generic)
                    }
                    
                    var replyToMessageId: MessageId?
                    var threadId: Int64?
                    if let topicId = topicIds[peerId] {
                        replyToMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: topicId))
                        threadId = topicId
                    }
                    
                    var messages: [EnqueueMessage] = []
                    if !text.isEmpty {
                        messages.append(.message(text: url + "\n\n" + text, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: threadId, replyToMessageId: replyToMessageId.flatMap {
                            EngineMessageReplySubject(messageId: $0, quote: nil)
                        }, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                    } else {
                        messages.append(.message(text: url, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: threadId, replyToMessageId: replyToMessageId.flatMap { EngineMessageReplySubject(messageId: $0, quote: nil) }, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                    }
                    messages = transformMessages(messages, showNames: showNames, silently: silently, sendPaidMessageStars: requiresStars[peerId])
                    shareSignals.append(enqueueMessages(account: currentContext.context.account, peerId: peerId, messages: messages))
                }
            case let .text(string):
                for peerId in peerIds {
                    guard let maybePeer = peers[peerId], let peer = maybePeer else {
                        continue
                    }
                    
                    var banSendText = false
                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendText) != nil {
                        banSendText = true
                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendText) {
                        banSendText = true
                    }
                    
                    if banSendText {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return .fail(.generic)
                    }
                    
                    var replyToMessageId: MessageId?
                    var threadId: Int64?
                    if let topicId = topicIds[peerId] {
                        replyToMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: topicId))
                        threadId = topicId
                    }
                    
                    var messages: [EnqueueMessage] = []
                    if !text.isEmpty {
                        messages.append(.message(text: text, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: threadId, replyToMessageId: replyToMessageId.flatMap { EngineMessageReplySubject(messageId: $0, quote: nil) }, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                    }
                    messages.append(.message(text: string, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: threadId, replyToMessageId: replyToMessageId.flatMap { EngineMessageReplySubject(messageId: $0, quote: nil) }, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                    messages = transformMessages(messages, showNames: showNames, silently: silently, sendPaidMessageStars: requiresStars[peerId])
                    shareSignals.append(enqueueMessages(account: currentContext.context.account, peerId: peerId, messages: messages))
                }
            case let .quote(string, url):
                for peerId in peerIds {
                    guard let maybePeer = peers[peerId], let peer = maybePeer else {
                        continue
                    }
                    
                    var banSendText = false
                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendText) != nil {
                        banSendText = true
                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendText) {
                        banSendText = true
                    }
                    
                    if banSendText {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return .fail(.generic)
                    }
                    
                    var replyToMessageId: MessageId?
                    var threadId: Int64?
                    if let topicId = topicIds[peerId] {
                        replyToMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: topicId))
                        threadId = topicId
                    }
                    
                    var messages: [EnqueueMessage] = []
                    if !text.isEmpty {
                        messages.append(.message(text: text, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: threadId, replyToMessageId: replyToMessageId.flatMap { EngineMessageReplySubject(messageId: $0, quote: nil) }, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                    }
                    let attributedText = NSMutableAttributedString(string: string, attributes: [ChatTextInputAttributes.italic: true as NSNumber])
                    attributedText.append(NSAttributedString(string: "\n\n\(url)"))
                    let entities = generateChatInputTextEntities(attributedText)
                    messages.append(.message(text: attributedText.string, attributes: [TextEntitiesMessageAttribute(entities: entities)], inlineStickers: [:], mediaReference: nil, threadId: threadId, replyToMessageId: replyToMessageId.flatMap { EngineMessageReplySubject(messageId: $0, quote: nil) }, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                    messages = transformMessages(messages, showNames: showNames, silently: silently, sendPaidMessageStars: requiresStars[peerId])
                    shareSignals.append(enqueueMessages(account: currentContext.context.account, peerId: peerId, messages: messages))
                }
            case let .image(representations):
                for peerId in peerIds {
                    guard let maybePeer = peers[peerId], let peer = maybePeer else {
                        continue
                    }
                    
                    var banSendPhotos = false
                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendPhotos) != nil {
                        banSendPhotos = true
                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendPhotos) {
                        banSendPhotos = true
                    }
                    
                    if banSendPhotos {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return .fail(.generic)
                    }
                    
                    var replyToMessageId: MessageId?
                    var threadId: Int64?
                    if let topicId = topicIds[peerId] {
                        replyToMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: topicId))
                        threadId = topicId
                    }
                    
                    var messages: [EnqueueMessage] = []
                    messages.append(.message(text: text, attributes: [], inlineStickers: [:], mediaReference: .standalone(media: TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: Int64.random(in: Int64.min ... Int64.max)), representations: representations.map({ $0.representation }), immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])), threadId: threadId, replyToMessageId: replyToMessageId.flatMap { EngineMessageReplySubject(messageId: $0, quote: nil) }, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                    messages = transformMessages(messages, showNames: showNames, silently: silently, sendPaidMessageStars: requiresStars[peerId])
                    shareSignals.append(enqueueMessages(account: currentContext.context.account, peerId: peerId, messages: messages))
                }
            case let .media(mediaReference, mediaParameters):
                var forwardSourceMessageId: EngineMessage.Id?
                if case let .message(message, _) = mediaReference, let sourceMessageId = message.id, (sourceMessageId.peerId.namespace == Namespaces.Peer.CloudUser || sourceMessageId.peerId.namespace == Namespaces.Peer.CloudGroup || sourceMessageId.peerId.namespace == Namespaces.Peer.CloudChannel) {
                    forwardSourceMessageId = sourceMessageId
                }
                
                var sendTextAsCaption = false
                if forwardSourceMessageId == nil {
                    if mediaReference.media is TelegramMediaImage || mediaReference.media is TelegramMediaFile {
                        sendTextAsCaption = true
                    }
                }
                
                for peerId in peerIds {
                    guard let maybePeer = peers[peerId], let peer = maybePeer else {
                        continue
                    }
                    
                    var banSendType = false
                    if mediaReference.media is TelegramMediaImage {
                        if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendPhotos) != nil {
                            banSendType = true
                        } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendPhotos) {
                            banSendType = true
                        }
                    } else if let file = mediaReference.media as? TelegramMediaFile {
                        if file.isSticker || file.isAnimated {
                            if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendStickers) != nil {
                                banSendType = true
                            } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendStickers) {
                                banSendType = true
                            }
                        } else if file.isInstantVideo {
                            if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendInstantVideos) != nil {
                                banSendType = true
                            } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendInstantVideos) {
                                banSendType = true
                            }
                        } else if file.isVoice {
                            if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendVoice) != nil {
                                banSendType = true
                            } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendVoice) {
                                banSendType = true
                            }
                        } else if file.isMusic {
                            if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendMusic) != nil {
                                banSendType = true
                            } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendMusic) {
                                banSendType = true
                            }
                        } else if file.isVideo {
                            if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendVideos) != nil {
                                banSendType = true
                            } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendVideos) {
                                banSendType = true
                            }
                        } else {
                            if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendFiles) != nil {
                                banSendType = true
                            } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendFiles) {
                                banSendType = true
                            }
                        }
                    }
                    
                    if banSendType {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return .fail(.generic)
                    }
                    
                    var replyToMessageId: MessageId?
                    var threadId: Int64?
                    if let topicId = topicIds[peerId] {
                        replyToMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: topicId))
                        threadId = topicId
                    }
                    
                    var messages: [EnqueueMessage] = []
                    if !text.isEmpty && !sendTextAsCaption {
                        messages.append(.message(text: text, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: threadId, replyToMessageId: replyToMessageId.flatMap { EngineMessageReplySubject(messageId: $0, quote: nil) }, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                    }
                    var attributes: [MessageAttribute] = []
                    if let startAtTimestamp = mediaParameters?.startAtTimestamp, let startAtTimestampNode = strongSelf.controllerNode.startAtTimestampNode, startAtTimestampNode.value {
                        attributes.append(ForwardVideoTimestampAttribute(timestamp: startAtTimestamp))
                    }
                    if let forwardSourceMessageId {
                        messages.append(.forward(source: forwardSourceMessageId, threadId: threadId, grouping: .auto, attributes: attributes, correlationId: nil))
                    } else {
                        messages.append(.message(text: sendTextAsCaption ? text : "", attributes: attributes, inlineStickers: [:], mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId.flatMap { EngineMessageReplySubject(messageId: $0, quote: nil) }, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                    }
                    messages = transformMessages(messages, showNames: showNames, silently: silently, sendPaidMessageStars: requiresStars[peerId])
                    shareSignals.append(enqueueMessages(account: currentContext.context.account, peerId: peerId, messages: messages))
                }
            case let .mapMedia(media):
                for peerId in peerIds {
                    guard let maybePeer = peers[peerId], let peer = maybePeer else {
                        continue
                    }
                    
                    var banSendText = false
                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendText) != nil {
                        banSendText = true
                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendText) {
                        banSendText = true
                    }
                    
                    if banSendText {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        
                        return .fail(.generic)
                    }
                    
                    var replyToMessageId: MessageId?
                    var threadId: Int64?
                    if let topicId = topicIds[peerId] {
                        replyToMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: topicId))
                        threadId = topicId
                    }
                    
                    var messages: [EnqueueMessage] = []
                    if !text.isEmpty {
                        messages.append(.message(text: text, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: threadId, replyToMessageId: replyToMessageId.flatMap { EngineMessageReplySubject(messageId: $0, quote: nil) }, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                    }
                    messages.append(.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), threadId: threadId, replyToMessageId: replyToMessageId.flatMap { EngineMessageReplySubject(messageId: $0, quote: nil) }, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                    messages = transformMessages(messages, showNames: showNames, silently: silently, sendPaidMessageStars: requiresStars[peerId])
                    shareSignals.append(enqueueMessages(account: currentContext.context.account, peerId: peerId, messages: messages))
                }
            case let .messages(messages):
                for peerId in peerIds {
                    guard let maybePeer = peers[peerId], let peer = maybePeer else {
                        continue
                    }
                    
                    var replyToMessageId: MessageId?
                    var threadId: Int64?
                    if let topicId = topicIds[peerId] {
                        replyToMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: topicId))
                        threadId = topicId
                    }
                    
                    var messagesToEnqueue: [EnqueueMessage] = []
                    if !text.isEmpty {
                        var banSendText = false
                        if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendText) != nil {
                            banSendText = true
                        } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendText) {
                            banSendText = true
                        }
                        
                        if banSendText {
                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            
                            return .fail(.generic)
                        }
                        
                        let correlationId = Int64.random(in: Int64.min ... Int64.max)
                        correlationIds.append(correlationId)
                        messagesToEnqueue.append(.message(text: text, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: threadId, replyToMessageId: replyToMessageId.flatMap { EngineMessageReplySubject(messageId: $0, quote: nil) }, replyToStoryId: nil, localGroupingKey: nil, correlationId: correlationId, bubbleUpEmojiOrStickersets: []))
                    }
                    for message in messages {
                        for media in message.media {
                            var banSendType = false
                            if media is TelegramMediaImage {
                                if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendPhotos) != nil {
                                    banSendType = true
                                } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendPhotos) {
                                    banSendType = true
                                }
                            } else if let file = media as? TelegramMediaFile {
                                if file.isSticker || file.isAnimated {
                                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendStickers) != nil {
                                        banSendType = true
                                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendStickers) {
                                        banSendType = true
                                    }
                                } else if file.isInstantVideo {
                                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendInstantVideos) != nil {
                                        banSendType = true
                                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendInstantVideos) {
                                        banSendType = true
                                    }
                                } else if file.isVoice {
                                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendVoice) != nil {
                                        banSendType = true
                                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendVoice) {
                                        banSendType = true
                                    }
                                } else if file.isMusic {
                                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendMusic) != nil {
                                        banSendType = true
                                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendMusic) {
                                        banSendType = true
                                    }
                                } else if file.isVideo {
                                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendVideos) != nil {
                                        banSendType = true
                                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendVideos) {
                                        banSendType = true
                                    }
                                } else {
                                    if case let .channel(channel) = peer, channel.hasBannedPermission(.banSendFiles) != nil {
                                        banSendType = true
                                    } else if case let .legacyGroup(group) = peer, group.hasBannedPermission(.banSendFiles) {
                                        banSendType = true
                                    }
                                }
                            }
                            
                            if banSendType {
                                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                
                                return .fail(.generic)
                            }
                        }
                        
                        let correlationId = Int64.random(in: Int64.min ... Int64.max)
                        correlationIds.append(correlationId)
                        messagesToEnqueue.append(.forward(source: message.id, threadId: threadId, grouping: .auto, attributes: [], correlationId: correlationId))
                    }
                    messagesToEnqueue = transformMessages(messagesToEnqueue, showNames: showNames, silently: silently, sendPaidMessageStars: requiresStars[peerId])
                    shareSignals.append(enqueueMessages(account: currentContext.context.account, peerId: peerId, messages: messagesToEnqueue))
                }
            case let .fromExternal(_, f):
                return f(peerIds, topicIds, requiresStars, text, currentContext, silently)
                |> map { state -> ShareState in
                    switch state {
                    case let .preparing(long):
                        return .preparing(long)
                    case let .progress(value):
                        return .progress(value)
                    case .done:
                        return .done([])
                    }
                }
            }
            let account = currentContext.context.account
            let queue = Queue.mainQueue()
            var displayedError = false
            return combineLatest(queue: queue, shareSignals)
            |> castError(ShareControllerError.self)
            |> mapToSignal { messageIdSets -> Signal<ShareState, ShareControllerError> in
                var statuses: [Signal<(MessageId, PendingMessageStatus?, PendingMessageFailureReason?), ShareControllerError>] = []
                for messageIds in messageIdSets {
                    for case let id? in messageIds {
                        statuses.append(account.pendingMessageManager.pendingMessageStatus(id)
                        |> castError(ShareControllerError.self)
                        |> map { status, error -> (MessageId, PendingMessageStatus?, PendingMessageFailureReason?) in
                            return (id, status, error)
                        })
                    }
                }
                return combineLatest(queue: queue, statuses)
                |> mapToSignal { statuses -> Signal<ShareState, ShareControllerError> in
                    var hasStatuses = false
                    for (id, status, error) in statuses {
                        if let error = error {
                            Queue.mainQueue().async {
                                let _ = TelegramEngine(account: account).messages.deleteMessagesInteractively(messageIds: [id], type: .forEveryone).start()
                                let _ = (TelegramEngine(account: account).data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: id.peerId))
                                         |> deliverOnMainQueue).start(next: { peer in
                                    guard let strongSelf = self, let peer = peer else {
                                        return
                                    }
                                    if !displayedError {
                                        if case .slowmodeActive = error {
                                            displayedError = true
                                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: strongSelf.presentationData.strings.Chat_SlowmodeSendError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                        } else if case .mediaRestricted = error {
                                            displayedError = true
                                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: restrictedSendingContentsText(peer: peer, presentationData: strongSelf.presentationData), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                        }
                                    }
                                })
                            }
                        }
                        if status != nil {
                            hasStatuses = true
                        }
                    }
                    if !hasStatuses {
                        return .single(.done(correlationIds))
                    }
                    return .complete()
                }
                |> take(1)
            }
        }
    }
    
    let didAppearPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.didAppearPromise.set(true)
            if !self.immediateExternalShare {
                self.controllerNode.animateIn()
            }
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.view.endEditing(true)
        self.controllerNode.animateOut(shared: false, completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    private func saveToCameraRoll(messages: [Message], completion: @escaping () -> Void) {
        guard let accountContext = self.currentContext as? ShareControllerAppAccountContext else {
            return
        }
        let context = accountContext.context
        
        let postbox = self.currentContext.stateManager.postbox
        let signals: [Signal<Float, NoError>] = messages.compactMap { message -> Signal<Float, NoError>? in
            if let media = message.media.first {
                return SaveToCameraRoll.saveToCameraRoll(context: context, postbox: postbox, userLocation: .peer(message.id.peerId), mediaReference: .message(message: MessageReference(message), media: media))
            } else {
                return nil
            }
        }
        if !signals.isEmpty {
            let total = combineLatest(signals)
            |> map { values -> Float? in
                var total: Float = 0.0
                for value in values {
                    total += value
                }
                total /= Float(values.count)
                return total
            }
            self.controllerNode.transitionToProgressWithValue(signal: total, completion: completion)
        }
    }
    
    private func saveToCameraRoll(representations: [ImageRepresentationWithReference]) {
        guard let accountContext = self.currentContext as? ShareControllerAppAccountContext else {
            return
        }
        let context = accountContext.context
        
        let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: representations.map({ $0.representation }), immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        self.controllerNode.transitionToProgressWithValue(signal: SaveToCameraRoll.saveToCameraRoll(context: context, postbox: context.account.postbox, userLocation: .other, mediaReference: .standalone(media: media)) |> map(Optional.init), dismissImmediately: true, completion: {})
    }
    
    private func saveToCameraRoll(mediaReference: AnyMediaReference, completion: (() -> Void)?) {
        guard let accountContext = self.currentContext as? ShareControllerAppAccountContext else {
            return
        }
        let context = accountContext.context
        
        self.controllerNode.transitionToProgressWithValue(signal: SaveToCameraRoll.saveToCameraRoll(context: context, postbox: context.account.postbox, userLocation: .other, mediaReference: mediaReference) |> map(Optional.init), dismissImmediately: completion == nil, completion: completion ?? {})
    }
    
    private func switchToAccount(account: ShareControllerAccountContext, animateIn: Bool) {
        self.currentContext = account
        self.accountActiveDisposable.set(self.environment.setAccountUserInterfaceInUse(id: account.accountId))
        
        let tailChatList = account.stateManager.postbox.tailChatListView(
            groupId: .root,
            filterPredicate: nil,
            count: 150,
            summaryComponents: ChatListEntrySummaryComponents(
                components: [
                    ChatListEntryMessageTagSummaryKey(
                        tag: .unseenPersonalMessage,
                        actionType: PendingMessageActionType.consumeUnseenPersonalMessage
                    ): ChatListEntrySummaryComponents.Component(
                        tagSummary: ChatListEntryMessageTagSummaryComponent(namespace: Namespaces.Message.Cloud),
                        actionsSummary: ChatListEntryPendingMessageActionsSummaryComponent(namespace: Namespaces.Message.Cloud)
                    ),
                    ChatListEntryMessageTagSummaryKey(
                        tag: .unseenReaction,
                        actionType: PendingMessageActionType.readReaction
                    ): ChatListEntrySummaryComponents.Component(
                        tagSummary: ChatListEntryMessageTagSummaryComponent(namespace: Namespaces.Message.Cloud),
                        actionsSummary: ChatListEntryPendingMessageActionsSummaryComponent(namespace: Namespaces.Message.Cloud)
                    )
                ]
            )
        )
        let peer = self.currentContext.stateManager.postbox.combinedView(keys: [PostboxViewKey.basicPeer(self.currentContext.accountPeerId)])
        |> take(1)
        |> map { views -> EnginePeer? in
            guard let view = views.views[PostboxViewKey.basicPeer(self.currentContext.accountPeerId)] as? BasicPeerView else {
                return nil
            }
            return view.peer.flatMap(EnginePeer.init)
        }
        
        self.peers.set(combineLatest(
            peer,
            tailChatList |> take(1)
        )
        |> mapToSignal { maybeAccountPeer, view -> Signal<([(peer: EngineRenderedPeer, presence: EnginePeer.Presence?, requiresPremiumForMessaging: Bool, requiresStars: Int64?)], EnginePeer), NoError> in
            let accountPeer = maybeAccountPeer!
            
            var peers: [EngineRenderedPeer] = []
            var possiblePremiumRequiredPeers = Set<EnginePeer.Id>()
            for entry in view.0.entries.reversed() {
                switch entry {
                case let .MessageEntry(entryData):
                    if let peer = entryData.renderedPeer.peers[entryData.renderedPeer.peerId], peer.id != accountPeer.id, canSendMessagesToPeer(peer) {
                        peers.append(EngineRenderedPeer(entryData.renderedPeer))
                        if let user = peer as? TelegramUser, user.flags.contains(.requirePremium) || user.flags.contains(.requireStars) {
                            possiblePremiumRequiredPeers.insert(user.id)
                        } else if let channel = peer as? TelegramChannel, let _ = channel.sendPaidMessageStars {
                            possiblePremiumRequiredPeers.insert(channel.id)
                        }
                    }
                default:
                    break
                }
            }

            let peerPresencesKey = PostboxViewKey.peerPresences(peerIds: Set(peers.map(\.peerId)))
            
            var keys: [PostboxViewKey] = []
            keys.append(peerPresencesKey)
            
            for id in possiblePremiumRequiredPeers {
                keys.append(.peer(peerId: id, components: []))
                keys.append(.cachedPeerData(peerId: id))
            }
            
            return account.stateManager.postbox.combinedView(keys: keys)
            |> map { views -> ([EnginePeer.Id: EnginePeer.Presence?], [EnginePeer.Id: Bool], [EnginePeer.Id: Int64]) in
                var result: [EnginePeer.Id: EnginePeer.Presence?] = [:]
                if let view = views.views[peerPresencesKey] as? PeerPresencesView {
                    result = view.presences.mapValues { value -> EnginePeer.Presence? in
                        return EnginePeer.Presence(value)
                    }
                }
                var requiresPremiumForMessaging: [EnginePeer.Id: Bool] = [:]
                var requiresStars: [EnginePeer.Id: Int64] = [:]
                for id in possiblePremiumRequiredPeers {
                    if let view = views.views[.cachedPeerData(peerId: id)] as? CachedPeerDataView, let data = view.cachedPeerData as? CachedUserData {
                        requiresPremiumForMessaging[id] = data.flags.contains(.premiumRequired)
                        requiresStars[id] = data.sendPaidMessageStars?.value
                    } else if let view = views.views[.peer(peerId: id, components: [])] as? PeerView, let channel = peerViewMainPeer(view) as? TelegramChannel {
                        requiresStars[id] = channel.sendPaidMessageStars?.value
                    } else {
                        requiresPremiumForMessaging[id] = false
                    }
                }
                return (result, requiresPremiumForMessaging, requiresStars)
            }
            |> map { presenceMap, requiresPremiumForMessaging, requiresStars -> ([(peer: EngineRenderedPeer, presence: EnginePeer.Presence?, requiresPremiumForMessaging: Bool, requiresStars: Int64?)], EnginePeer) in
                var resultPeers: [(peer: EngineRenderedPeer, presence: EnginePeer.Presence?, requiresPremiumForMessaging: Bool, requiresStars: Int64?)] = []
                for peer in peers {
                    resultPeers.append((peer, presenceMap[peer.peerId].flatMap { $0 }, requiresPremiumForMessaging[peer.peerId] ?? false, requiresStars[peer.peerId]))
                }
                return (resultPeers, accountPeer)
            }
        })
        var animatedIn = false
        self.peersDisposable.set((self.peers.get()
        |> deliverOnMainQueue).start(next: { [weak self] next in
            if let strongSelf = self {
                strongSelf.controllerNode.updatePeers(context: strongSelf.currentContext, switchableAccounts: strongSelf.switchableAccounts, peers: next.0, accountPeer: next.1, defaultAction: strongSelf.defaultAction)
                
                if animateIn && !animatedIn {
                    animatedIn = true
                    strongSelf.readyDisposable.set((strongSelf.controllerNode.ready.get()
                    |> filter({ $0 })
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] _ in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.controllerNode.animateIn()
                    }))
                }
            }
        }))
    }
}

public class ShareToInstagramActivity: UIActivity {
    private let context: AccountContext
    private var activityItems = [Any]()
    
    public init(context: AccountContext) {
        self.context = context
        
        super.init()
    }
    
    public override var activityTitle: String? {
        return self.context.sharedContext.currentPresentationData.with { $0 }.strings.Share_ShareToInstagramStories
    }

    public override var activityImage: UIImage? {
        return UIImage(bundleImageName: "Share/Instagram")
    }
    
    public override var activityType: UIActivity.ActivityType? {
        return UIActivity.ActivityType(rawValue: "org.telegram.Telegram.ShareToInstagram")
    }

    public override class var activityCategory: UIActivity.Category {
        return .action
    }
    
    public override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return self.context.sharedContext.applicationBindings.canOpenUrl("instagram-stories://")
    }
    
    public override func prepare(withActivityItems activityItems: [Any]) {
        self.activityItems = activityItems
    }
    
    public override func perform() {
        if let url = self.activityItems.first as? URL, let data = try? Data(contentsOf: url, options: .mappedIfSafe) {
            let pasteboardItems: [[String: Any]]
            if url.path.hasSuffix(".mp4") {
                pasteboardItems = [["com.instagram.sharedSticker.backgroundVideo": data]]
            } else {
                pasteboardItems = [["com.instagram.sharedSticker.backgroundImage": data]]
            }
            if #available(iOS 10.0, *) {
                UIPasteboard.general.setItems(pasteboardItems, options: [.expirationDate: Date().addingTimeInterval(5 * 60)])
            } else {
                UIPasteboard.general.items = pasteboardItems
            }
            context.sharedContext.applicationBindings.openUrl("instagram-stories://share")
        }
        activityDidFinish(true)
    }
}


public func presentExternalShare(context: AccountContext, text: String, parentController: ViewController) {
    let activityController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
    if let window = parentController.view.window {
        activityController.popoverPresentationController?.sourceView = window
        activityController.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
    }
    context.sharedContext.applicationBindings.presentNativeController(activityController)
}

private func restrictedSendingContentsText(peer: EnginePeer, presentationData: PresentationData) -> String {
    var itemList: [String] = []
    
    let order: [TelegramChatBannedRightsFlags] = [
        .banSendText,
        .banSendPhotos,
        .banSendVideos,
        .banSendVoice,
        .banSendInstantVideos,
        .banSendFiles,
        .banSendMusic,
        .banSendStickers
    ]
    
    for right in order {
        if case let .channel(channel) = peer {
            if channel.hasBannedPermission(right) != nil {
                continue
            }
        } else if case let .legacyGroup(group) = peer {
            if group.hasBannedPermission(right) {
                continue
            }
        }
        
        var title: String?
        switch right {
        case .banSendText:
            title = presentationData.strings.Chat_SendAllowedContentTypeText
        case .banSendPhotos:
            title = presentationData.strings.Chat_SendAllowedContentTypePhoto
        case .banSendVideos:
            title = presentationData.strings.Chat_SendAllowedContentTypeVideo
        case .banSendVoice:
            title = presentationData.strings.Chat_SendAllowedContentTypeVoiceMessage
        case .banSendInstantVideos:
            title = presentationData.strings.Chat_SendAllowedContentTypeVideoMessage
        case .banSendFiles:
            title = presentationData.strings.Chat_SendAllowedContentTypeFile
        case .banSendMusic:
            title = presentationData.strings.Chat_SendAllowedContentTypeMusic
        case .banSendStickers:
            title = presentationData.strings.Chat_SendAllowedContentTypeSticker
        default:
            break
        }
        if let title {
            itemList.append(title)
        }
    }
    
    if itemList.isEmpty {
        return presentationData.strings.Chat_SendNotAllowedPeerText(peer.compactDisplayTitle).string
    }
    
    var itemListString = ""
    
    if #available(iOS 13.0, *) {
        let listFormatter = ListFormatter()
        listFormatter.locale = localeWithStrings(presentationData.strings)
        if let value = listFormatter.string(from: itemList) {
            itemListString = value
        }
    }
    
    if itemListString.isEmpty {
        for i in 0 ..< itemList.count {
            if i != 0 {
                itemListString.append(", ")
            }
            itemListString.append(itemList[i])
        }
    }
    
    return presentationData.strings.Chat_SendAllowedContentPeerText(peer.compactDisplayTitle, itemListString).string
}
