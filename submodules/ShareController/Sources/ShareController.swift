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

public enum ShareControllerExternalStatus {
    case preparing(Bool)
    case progress(Float)
    case done
}

public enum ShareControllerError {
    case fileTooBig(Int64)
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

public enum ShareControllerSubject {
    case url(String)
    case text(String)
    case quote(text: String, url: String)
    case messages([Message])
    case image([ImageRepresentationWithReference])
    case media(AnyMediaReference)
    case mapMedia(TelegramMediaMap)
    case fromExternal(([PeerId], String, Account, Bool) -> Signal<ShareControllerExternalStatus, ShareControllerError>)
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
        let fetched = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: resourceReference, statsCategory: statsCategory).start()
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
                                return chatMessageSticker(postbox: postbox, file: file, small: false, fetched: true, onlyFullSize: true)
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
                        if let fileData = try? Data(contentsOf: URL(fileURLWithPath: data.path)), let image = UIImage(data: fileData) {
                            return .done(.image(image))
                        } else {
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

public final class ShareController: ViewController {
    private var controllerNode: ShareControllerNode {
        return self.displayNode as! ShareControllerNode
    }
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var animatedIn = false
    
    private let sharedContext: SharedAccountContext
    private let currentContext: AccountContext
    private var currentAccount: Account
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let forceTheme: PresentationTheme?
    private let shareAsLink: Bool
    
    private let externalShare: Bool
    private let immediateExternalShare: Bool
    private let subject: ShareControllerSubject
    private let presetText: String?
    private let switchableAccounts: [AccountWithInfo]
    private let immediatePeerId: PeerId?
    private let segmentedValues: [ShareControllerSegmentedValue]?
    private let fromForeignApp: Bool
    
    private let peers = Promise<([(EngineRenderedPeer, EnginePeer.Presence?)], EnginePeer)>()
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
    
    public var openShareAsImage: (([Message]) -> Void)?

    public var debugAction: (() -> Void)?
    
    public convenience init(context: AccountContext, subject: ShareControllerSubject, presetText: String? = nil, preferredAction: ShareControllerPreferredAction = .default, showInChat: ((Message) -> Void)? = nil, fromForeignApp: Bool = false, segmentedValues: [ShareControllerSegmentedValue]? = nil, externalShare: Bool = true, immediateExternalShare: Bool = false, switchableAccounts: [AccountWithInfo] = [], immediatePeerId: PeerId? = nil, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, forceTheme: PresentationTheme? = nil, forcedActionTitle: String? = nil, shareAsLink: Bool = false) {
        self.init(sharedContext: context.sharedContext, currentContext: context, subject: subject, presetText: presetText, preferredAction: preferredAction, showInChat: showInChat, fromForeignApp: fromForeignApp, segmentedValues: segmentedValues, externalShare: externalShare, immediateExternalShare: immediateExternalShare, switchableAccounts: switchableAccounts, immediatePeerId: immediatePeerId, updatedPresentationData: updatedPresentationData, forceTheme: forceTheme, forcedActionTitle: forcedActionTitle, shareAsLink: shareAsLink)
    }
    
    public init(sharedContext: SharedAccountContext, currentContext: AccountContext, subject: ShareControllerSubject, presetText: String? = nil, preferredAction: ShareControllerPreferredAction = .default, showInChat: ((Message) -> Void)? = nil, fromForeignApp: Bool = false, segmentedValues: [ShareControllerSegmentedValue]? = nil, externalShare: Bool = true, immediateExternalShare: Bool = false, switchableAccounts: [AccountWithInfo] = [], immediatePeerId: PeerId? = nil, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, forceTheme: PresentationTheme? = nil, forcedActionTitle: String? = nil, shareAsLink: Bool = false) {
        self.sharedContext = sharedContext
        self.currentContext = currentContext
        self.currentAccount = currentContext.account
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
        
        self.presentationData = updatedPresentationData?.initial ?? sharedContext.currentPresentationData.with { $0 }
        if let forceTheme = self.forceTheme {
            self.presentationData = self.presentationData.withUpdated(theme: forceTheme)
        }
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
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
            case let .media(mediaReference):
                var canSave = false
                var isVideo = false
                if mediaReference.media is TelegramMediaImage {
                    canSave = true
                } else if let file = mediaReference.media as? TelegramMediaFile {
                    canSave = true
                    isVideo = file.isVideo
                }
                if case .saveToCameraRoll = preferredAction, canSave {
                    self.actionIsMediaSaving = true
                    self.defaultAction = ShareControllerAction(title: isVideo ? self.presentationData.strings.Gallery_SaveVideo : self.presentationData.strings.Gallery_SaveImage, action: { [weak self] in
                        self?.saveToCameraRoll(mediaReference: mediaReference)
                        self?.actionCompleted?()
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
                                let _ = (TelegramEngine(account: strongSelf.currentAccount).messages.exportMessageLink(peerId: chatPeer.id, messageId: message.id)
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
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? self.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        self.switchToAccount(account: currentAccount, animateIn: false)
        
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
        if case let .messages(messages) = self.subject, let message = messages.first, let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
            fromPublicChannel = true
        }
        
        self.displayNode = ShareControllerNode(sharedContext: self.sharedContext, presentationData: self.presentationData, presetText: self.presetText, defaultAction: self.defaultAction, requestLayout: { [weak self] transition in
            self?.requestLayout(transition: transition)
        }, presentError: { [weak self] title, text in
            guard let strongSelf = self else {
                return
            }
            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: title, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
        }, externalShare: self.externalShare, immediateExternalShare: self.immediateExternalShare, immediatePeerId: self.immediatePeerId, fromForeignApp: self.fromForeignApp, forceTheme: self.forceTheme, fromPublicChannel: fromPublicChannel, segmentedValues: self.segmentedValues)
        self.controllerNode.completed = self.completed
        self.controllerNode.present = { [weak self] c in
            self?.present(c, in: .window(.root))
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
        self.controllerNode.share = { [weak self] text, peerIds, showNames, silently in
            guard let strongSelf = self else {
                return .complete()
            }
                        
            var shareSignals: [Signal<[MessageId?], NoError>] = []
            var subject = strongSelf.subject
            if let segmentedValues = strongSelf.segmentedValues {
                let selectedValue = segmentedValues[strongSelf.controllerNode.selectedSegmentedIndex]
                subject = selectedValue.subject
            }
            
            func transformMessages(_ messages: [EnqueueMessage], showNames: Bool, silently: Bool) -> [EnqueueMessage] {
                return messages.map { message in
                    return message.withUpdatedAttributes({ attributes in
                        var attributes = attributes
                        if !showNames {
                            attributes.append(ForwardOptionsMessageAttribute(hideNames: true, hideCaptions: false))
                        }
                        if silently {
                            attributes.append(NotificationInfoMessageAttribute(flags: .muted))
                        }
                        return attributes
                    })
                }
            }
            
            switch subject {
            case let .url(url):
                for peerId in peerIds {
                    var messages: [EnqueueMessage] = []
                    if !text.isEmpty {
                        messages.append(.message(text: url + "\n\n" + text, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil))
                    } else {
                        messages.append(.message(text: url, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil))
                    }
                    messages = transformMessages(messages, showNames: showNames, silently: silently)
                    shareSignals.append(enqueueMessages(account: strongSelf.currentAccount, peerId: peerId, messages: messages))
                }
            case let .text(string):
                for peerId in peerIds {
                    var messages: [EnqueueMessage] = []
                    if !text.isEmpty {
                        messages.append(.message(text: text, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil))
                    }
                    messages.append(.message(text: string, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil))
                    messages = transformMessages(messages, showNames: showNames, silently: silently)
                    shareSignals.append(enqueueMessages(account: strongSelf.currentAccount, peerId: peerId, messages: messages))
                }
            case let .quote(string, url):
                for peerId in peerIds {
                    var messages: [EnqueueMessage] = []
                    if !text.isEmpty {
                        messages.append(.message(text: text, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil))
                    }
                    let attributedText = NSMutableAttributedString(string: string, attributes: [ChatTextInputAttributes.italic: true as NSNumber])
                    attributedText.append(NSAttributedString(string: "\n\n\(url)"))
                    let entities = generateChatInputTextEntities(attributedText)
                    messages.append(.message(text: attributedText.string, attributes: [TextEntitiesMessageAttribute(entities: entities)], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil))
                    messages = transformMessages(messages, showNames: showNames, silently: silently)
                    shareSignals.append(enqueueMessages(account: strongSelf.currentAccount, peerId: peerId, messages: messages))
                }
            case let .image(representations):
                for peerId in peerIds {
                    var messages: [EnqueueMessage] = []
                    messages.append(.message(text: text, attributes: [], mediaReference: .standalone(media: TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: Int64.random(in: Int64.min ... Int64.max)), representations: representations.map({ $0.representation }), immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil))
                    messages = transformMessages(messages, showNames: showNames, silently: silently)
                    shareSignals.append(enqueueMessages(account: strongSelf.currentAccount, peerId: peerId, messages: messages))
                }
            case let .media(mediaReference):
                var sendTextAsCaption = false
                if mediaReference.media is TelegramMediaImage || mediaReference.media is TelegramMediaFile {
                    sendTextAsCaption = true
                }
                
                for peerId in peerIds {
                    var messages: [EnqueueMessage] = []
                    if !text.isEmpty && !sendTextAsCaption {
                        messages.append(.message(text: text, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil))
                    }
                    messages.append(.message(text: sendTextAsCaption ? text : "", attributes: [], mediaReference: mediaReference, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil))
                    messages = transformMessages(messages, showNames: showNames, silently: silently)
                    shareSignals.append(enqueueMessages(account: strongSelf.currentAccount, peerId: peerId, messages: messages))
                }
            case let .mapMedia(media):
                for peerId in peerIds {
                    var messages: [EnqueueMessage] = []
                    if !text.isEmpty {
                        messages.append(.message(text: text, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil))
                    }
                    messages.append(.message(text: "", attributes: [], mediaReference: .standalone(media: media), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil))
                    messages = transformMessages(messages, showNames: showNames, silently: silently)
                    shareSignals.append(enqueueMessages(account: strongSelf.currentAccount, peerId: peerId, messages: messages))
                }
            case let .messages(messages):
                for peerId in peerIds {
                    var messagesToEnqueue: [EnqueueMessage] = []
                    if !text.isEmpty {
                        messagesToEnqueue.append(.message(text: text, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil))
                    }
                    for message in messages {
                        messagesToEnqueue.append(.forward(source: message.id, grouping: .auto, attributes: [], correlationId: nil))
                    }
                    messagesToEnqueue = transformMessages(messagesToEnqueue, showNames: showNames, silently: silently)
                    shareSignals.append(enqueueMessages(account: strongSelf.currentAccount, peerId: peerId, messages: messagesToEnqueue))
                }
            case let .fromExternal(f):
                return f(peerIds, text, strongSelf.currentAccount, silently)
                |> map { state -> ShareState in
                    switch state {
                        case let .preparing(long):
                            return .preparing(long)
                        case let .progress(value):
                            return .progress(value)
                        case .done:
                            return .done
                    }
                }
            }
            let account = strongSelf.currentAccount
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
                                    if !displayedError, case .slowmodeActive = error {
                                        displayedError = true
                                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), text: strongSelf.presentationData.strings.Chat_SlowmodeSendError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                    }
                                })
                            }
                        }
                        if status != nil {
                            hasStatuses = true
                        }
                    }
                    if !hasStatuses {
                        return .single(.done)
                    }
                    return .complete()
                }
                |> take(1)
            }
        }
        self.controllerNode.shareExternal = { [weak self] _ in
            if let strongSelf = self {
                var collectableItems: [CollectableExternalShareItem] = []
                var subject = strongSelf.subject
                if let segmentedValues = strongSelf.segmentedValues {
                    let selectedValue = segmentedValues[strongSelf.controllerNode.selectedSegmentedIndex]
                    subject = selectedValue.subject
                }
                var messageUrl: String?
//                var messagesToShare: [Message]?
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
                    case let .media(mediaReference):
                        collectableItems.append(CollectableExternalShareItem(url: "", text: "", author: nil, timestamp: nil, mediaReference: mediaReference))
                    case let .mapMedia(media):
                        let latLong = "\(media.latitude),\(media.longitude)"
                        collectableItems.append(CollectableExternalShareItem(url: "https://maps.apple.com/maps?ll=\(latLong)&q=\(latLong)&t=m", text: "", author: nil, timestamp: nil, mediaReference: nil))
                    case let .messages(messages):
//                        messagesToShare = messages
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
                            let accountPeerId = strongSelf.currentAccount.peerId
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
                                    restrictedText = attribute.platformText(platform: "ios", contentSettings: strongSelf.currentContext.currentContentSettings.with { $0 }) ?? ""
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
                return (collectExternalShareItems(strings: strongSelf.presentationData.strings, dateTimeFormat: strongSelf.presentationData.dateTimeFormat, nameOrder: strongSelf.presentationData.nameDisplayOrder, engine: TelegramEngine(account: strongSelf.currentAccount), postbox: strongSelf.currentAccount.postbox, collectableItems: collectableItems, takeOne: !strongSelf.immediateExternalShare)
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
//                                    if asImage, let messages = messagesToShare {
//                                        self?.openShareAsImage?(messages)
//                                    } else {
                                        let activityController = UIActivityViewController(activityItems: activityItems, applicationActivities: activities)
                                        if let strongSelf = self, let window = strongSelf.view.window, let rootViewController = window.rootViewController {
                                            activityController.popoverPresentationController?.sourceView = window
                                            activityController.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
                                            rootViewController.present(activityController, animated: true, completion: nil)
                                        }
//                                    }
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
            
            let presentationData = strongSelf.sharedContext.currentPresentationData.with { $0 }
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
                items.append(ActionSheetPeerItem(context: strongSelf.sharedContext.makeTempAccountContext(account: info.account), peer: EnginePeer(info.peer), title: EnginePeer(info.peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), isSelected: info.account.id == strongSelf.currentAccount.id, strings: presentationData.strings, theme: presentationData.theme, action: { [weak self] in
                    dismissAction()
                    self?.switchToAccount(account: info.account, animateIn: true)
                }))
            }
            controller.setItemGroups([
                ActionSheetItemGroup(items: items)
            ])
            strongSelf.view.endEditing(true)
            strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        }
        self.controllerNode.debugAction = { [weak self] in
            self?.debugAction?()
        }
        self.displayNodeDidLoad()
        
        self.peersDisposable.set((self.peers.get()
        |> deliverOnMainQueue).start(next: { [weak self] next in
            if let strongSelf = self {
                strongSelf.controllerNode.updatePeers(context: strongSelf.sharedContext.makeTempAccountContext(account: strongSelf.currentAccount), switchableAccounts: strongSelf.switchableAccounts, peers: next.0, accountPeer: next.1, defaultAction: strongSelf.defaultAction)
            }
        }))
        self._ready.set(self.controllerNode.ready.get())
    }
    
    override public func loadView() {
        super.loadView()
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
        let postbox = self.currentAccount.postbox
        let signals: [Signal<Float, NoError>] = messages.compactMap { message -> Signal<Float, NoError>? in
            if let media = message.media.first {
                let context: AccountContext
                if self.currentContext.account.id == self.currentAccount.id {
                    context = self.currentContext
                } else {
                    context = self.sharedContext.makeTempAccountContext(account: self.currentAccount)
                }
                return SaveToCameraRoll.saveToCameraRoll(context: context, postbox: postbox, mediaReference: .message(message: MessageReference(message), media: media))
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
        let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: representations.map({ $0.representation }), immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let context: AccountContext
        if self.currentContext.account.id == self.currentAccount.id {
            context = self.currentContext
        } else {
            context = self.sharedContext.makeTempAccountContext(account: self.currentAccount)
        }
        self.controllerNode.transitionToProgressWithValue(signal: SaveToCameraRoll.saveToCameraRoll(context: context, postbox: context.account.postbox, mediaReference: .standalone(media: media)) |> map(Optional.init), dismissImmediately: true, completion: {})
    }
    
    private func saveToCameraRoll(mediaReference: AnyMediaReference) {
        let context: AccountContext
        if self.currentContext.account.id == self.currentAccount.id {
            context = self.currentContext
        } else {
            context = self.sharedContext.makeTempAccountContext(account: self.currentAccount)
        }
        self.controllerNode.transitionToProgressWithValue(signal: SaveToCameraRoll.saveToCameraRoll(context: context, postbox: context.account.postbox, mediaReference: mediaReference) |> map(Optional.init), dismissImmediately: true, completion: {})
    }
    
    private func switchToAccount(account: Account, animateIn: Bool) {
        self.currentAccount = account
        self.accountActiveDisposable.set(self.sharedContext.setAccountUserInterfaceInUse(account.id))
        
        self.peers.set(combineLatest(
            TelegramEngine(account: self.currentAccount).data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.currentAccount.peerId)),
            self.currentAccount.viewTracker.tailChatListView(groupId: .root, count: 150)
            |> take(1)
        )
        |> mapToSignal { maybeAccountPeer, view -> Signal<([(EngineRenderedPeer, EnginePeer.Presence?)], EnginePeer), NoError> in
            let accountPeer = maybeAccountPeer!
            
            var peers: [EngineRenderedPeer] = []
            for entry in view.0.entries.reversed() {
                switch entry {
                    case let .MessageEntry(_, _, _, _, _, renderedPeer, _, _, _, _):
                        if let peer = renderedPeer.peers[renderedPeer.peerId], peer.id != accountPeer.id, canSendMessagesToPeer(peer) {
                            peers.append(EngineRenderedPeer(renderedPeer))
                        }
                    default:
                        break
                }
            }

            return TelegramEngine(account: account).data.subscribe(EngineDataMap(
                peers.map { TelegramEngine.EngineData.Item.Peer.Presence(id: $0.peerId) }
            ))
            |> map { presenceMap -> ([(EngineRenderedPeer, EnginePeer.Presence?)], EnginePeer) in
                var resultPeers: [(EngineRenderedPeer, EnginePeer.Presence?)] = []
                for peer in peers {
                    resultPeers.append((peer, presenceMap[peer.peerId].flatMap { $0 }))
                }
                return (resultPeers, accountPeer)
            }
        })
        self.peersDisposable.set((self.peers.get()
        |> deliverOnMainQueue).start(next: { [weak self] next in
            if let strongSelf = self {
                strongSelf.controllerNode.updatePeers(context: strongSelf.sharedContext.makeTempAccountContext(account: strongSelf.currentAccount), switchableAccounts: strongSelf.switchableAccounts, peers: next.0, accountPeer: next.1, defaultAction: strongSelf.defaultAction)
                
                if animateIn {
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


final class MessageStoryRenderer {
    private let context: AccountContext
    private let presentationData: PresentationData
    private let messages: [Message]
    
    let containerNode: ASDisplayNode
    private let instantChatBackgroundNode: WallpaperBackgroundNode
    private let messagesContainerNode: ASDisplayNode
    private var dateHeaderNode: ListViewItemHeaderNode?
    private var messageNodes: [ListViewItemNode]?
    private let addressNode: ImmediateTextNode
    
    init(context: AccountContext, messages: [Message]) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.messages = messages

        self.containerNode = ASDisplayNode()
        
        self.instantChatBackgroundNode = createWallpaperBackgroundNode(context: context, forChatDisplay: false)
        self.instantChatBackgroundNode.displaysAsynchronously = false
        
        self.messagesContainerNode = ASDisplayNode()
        self.messagesContainerNode.clipsToBounds = true
        self.messagesContainerNode.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
        
        let message = messages.first!
        let addressName = message.peers[message.id.peerId]?.addressName ?? ""

        self.addressNode = ImmediateTextNode()
        self.addressNode.displaysAsynchronously = false
        self.addressNode.attributedText = NSAttributedString(string: "t.me/\(addressName)/\(message.id.id)", font: Font.medium(14.0), textColor: UIColor(rgb: 0xffffff))
        self.addressNode.textShadowColor = UIColor(rgb: 0x929292, alpha: 0.8)
        
        self.containerNode.addSubnode(self.instantChatBackgroundNode)
        self.containerNode.addSubnode(self.messagesContainerNode)
        self.containerNode.addSubnode(self.addressNode)
    }
    
    func update(layout: ContainerViewLayout, completion: @escaping (UIImage?) -> Void) {
        self.updateMessagesLayout(layout: layout)
        
        Queue.mainQueue().after(0.01) {
            UIGraphicsBeginImageContextWithOptions(layout.size, false, 3.0)
            self.containerNode.view.drawHierarchy(in: CGRect(origin: CGPoint(), size: layout.size), afterScreenUpdates: true)
            let img = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            completion(img)
        }
    }
    
    private func updateMessagesLayout(layout: ContainerViewLayout) {
        let size = layout.size
        self.containerNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.instantChatBackgroundNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.instantChatBackgroundNode.updateLayout(size: size, transition: .immediate)
        self.messagesContainerNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        
        let addressLayout = self.addressNode.updateLayout(size)
        
        let theme = self.presentationData.theme.withUpdated(preview: true)
        let headerItem = self.context.sharedContext.makeChatMessageDateHeaderItem(context: self.context, timestamp: self.messages.first?.timestamp ?? 0, theme: theme, strings: self.presentationData.strings, wallpaper: self.presentationData.chatWallpaper, fontSize: self.presentationData.chatFontSize, chatBubbleCorners: self.presentationData.chatBubbleCorners, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder)
    
        let items: [ListViewItem] = [self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, messages: self.messages, theme: theme, strings: self.presentationData.strings, wallpaper: self.presentationData.theme.chat.defaultWallpaper, fontSize: self.presentationData.chatFontSize, chatBubbleCorners: self.presentationData.chatBubbleCorners, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: nil, availableReactions: nil, isCentered: false)]
    
        let inset: CGFloat = 16.0
        let width = layout.size.width - inset * 2.0
        let params = ListViewItemLayoutParams(width: width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, availableHeight: layout.size.height)
        if let messageNodes = self.messageNodes {
            for i in 0 ..< items.count {
                let itemNode = messageNodes[i]
                items[i].updateNode(async: { $0() }, node: {
                    return itemNode
                }, params: params, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], animation: .None, completion: { (layout, apply) in
                    let nodeFrame = CGRect(origin: CGPoint(x: 0.0, y: floor((size.height - layout.size.height) / 2.0)), size: CGSize(width: width, height: layout.size.height))
                    
                    itemNode.contentSize = layout.contentSize
                    itemNode.insets = layout.insets
                    itemNode.frame = nodeFrame
                    itemNode.isUserInteractionEnabled = false
                    
                    apply(ListViewItemApply(isOnScreen: true))
                })
            }
        } else {
            var messageNodes: [ListViewItemNode] = []
            for i in 0 ..< items.count {
                var itemNode: ListViewItemNode?
                items[i].nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: true, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], completion: { node, apply in
                    itemNode = node
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
                itemNode!.subnodeTransform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                itemNode!.isUserInteractionEnabled = false
                messageNodes.append(itemNode!)
                self.messagesContainerNode.addSubnode(itemNode!)
            }
            self.messageNodes = messageNodes
        }
        
        var bottomOffset: CGFloat = 0.0
        if let messageNodes = self.messageNodes {
            for itemNode in messageNodes {
                itemNode.frame = CGRect(origin: CGPoint(x: inset, y: floor((size.height - itemNode.frame.height) / 2.0)), size: itemNode.frame.size)
                bottomOffset += itemNode.frame.maxY
                itemNode.updateFrame(itemNode.frame, within: layout.size)
            }
        }
        
        self.addressNode.frame = CGRect(origin: CGPoint(x: inset + 16.0, y: bottomOffset + 3.0), size: CGSize(width: addressLayout.width, height: addressLayout.height + 3.0))
        
        let dateHeaderNode: ListViewItemHeaderNode
        if let currentDateHeaderNode = self.dateHeaderNode {
            dateHeaderNode = currentDateHeaderNode
            headerItem.updateNode(dateHeaderNode, previous: nil, next: headerItem)
        } else {
            dateHeaderNode = headerItem.node(synchronousLoad: true)
            dateHeaderNode.subnodeTransform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
            self.messagesContainerNode.addSubnode(dateHeaderNode)
            self.dateHeaderNode = dateHeaderNode
        }
        
        dateHeaderNode.frame = CGRect(origin: CGPoint(x: 0.0, y: bottomOffset), size: CGSize(width: layout.size.width, height: headerItem.height))
        dateHeaderNode.updateLayout(size: self.containerNode.frame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right)
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
