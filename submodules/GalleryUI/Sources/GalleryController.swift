import Foundation
import UIKit
import Display
import QuickLook
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import SafariServices
import TelegramPresentationData
import TextFormat
import AccountContext
import TelegramUniversalVideoContent
import WebsiteType
import OpenInExternalAppUI
import ScreenCaptureDetection
import UndoUI

private func tagsForMessage(_ message: Message) -> MessageTags? {
    for media in message.media {
        switch media {
            case _ as TelegramMediaImage:
                return .photoOrVideo
            case let file as TelegramMediaFile:
                if file.isVideo {
                    if file.isAnimated {
                        return .gif
                    } else {
                        return .photoOrVideo
                    }
                } else if file.isVoice {
                    return .voiceOrInstantVideo
                } else if file.isSticker {
                    return nil
                } else {
                    return .file
                }
            default:
                break
        }
    }
    return nil
}

private func galleryMediaForMedia(media: Media) -> Media? {
    if let media = media as? TelegramMediaImage {
        return media
    } else if let file = media as? TelegramMediaFile {
        if file.mimeType.hasPrefix("audio/") {
            return nil
        } else if !file.isVideo && file.mimeType.hasPrefix("video/") {
            return file
        } else {
            return file
        }
    }
    return nil
}

private func mediaForMessage(message: Message) -> (Media, TelegramMediaImage?)? {
    for media in message.media {
        if let result = galleryMediaForMedia(media: media) {
            return (result, nil)
        } else if let webpage = media as? TelegramMediaWebpage {
            switch webpage.content {
                case let .Loaded(content):
                    if let embedUrl = content.embedUrl, !embedUrl.isEmpty {
                        return (webpage, nil)
                    } else if let file = content.file {
                        if let result = galleryMediaForMedia(media: file) {
                            return (result, content.image)
                        }
                    } else if let image = content.image {
                        if let result = galleryMediaForMedia(media: image) {
                            return (result, nil)
                        }
                    }
                case .Pending:
                    break
            }
        }
    }
    return nil
}

private let internalExtensions = Set<String>([
    "jpg",
    "png",
    "jpeg"
])

private let internalNotSupportedExtensions = Set<String>([
    "djvu"
])

private let internalMimeTypes = Set<String>([
])

private let internalMimePrefixes: [String] = [
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/heic"
]

public func internalDocumentItemSupportsMimeType(_ type: String, fileName: String?) -> Bool {
    if let fileName = fileName {
        let ext = (fileName as NSString).pathExtension
        if internalExtensions.contains(ext.lowercased()) {
            return true
        }
        if internalNotSupportedExtensions.contains(ext.lowercased()) {
            return false
        }
    }
    
    if internalMimeTypes.contains(type) {
        return true
    }
    for prefix in internalMimePrefixes {
        if type.hasPrefix(prefix) {
            return true
        }
    }
    return false
}

private let textFont = Font.regular(16.0)
private let boldFont = Font.bold(16.0)
private let italicFont = Font.italic(16.0)
private let boldItalicFont = Font.semiboldItalic(16.0)
private let fixedFont = UIFont(name: "Menlo-Regular", size: 15.0) ?? textFont

public func galleryCaptionStringWithAppliedEntities(_ text: String, entities: [MessageTextEntity]) -> NSAttributedString {
    return stringWithAppliedEntities(text, entities: entities, baseColor: .white, linkColor: UIColor(rgb: 0x5ac8fa), baseFont: textFont, linkFont: textFont, boldFont: boldFont, italicFont: italicFont, boldItalicFont: boldItalicFont, fixedFont: fixedFont, blockQuoteFont: textFont, underlineLinks: false)
}

private func galleryMessageCaptionText(_ message: Message) -> String {
    for media in message.media {
        if let _ = media as? TelegramMediaWebpage {
            return ""
        }
    }
    return message.text
}

public func galleryItemForEntry(context: AccountContext, presentationData: PresentationData, entry: MessageHistoryEntry, isCentral: Bool = false, streamVideos: Bool, loopVideos: Bool = false, hideControls: Bool = false, fromPlayingVideo: Bool = false, isSecret: Bool = false, landscape: Bool = false, timecode: Double? = nil, playbackRate: @escaping () -> Double?, displayInfoOnTop: Bool = false, configuration: GalleryConfiguration? = nil, tempFilePath: String? = nil, playbackCompleted: @escaping () -> Void = {}, performAction: @escaping (GalleryControllerInteractionTapAction) -> Void = { _ in }, openActionOptions: @escaping (GalleryControllerInteractionTapAction, Message) -> Void = { _, _ in }, storeMediaPlaybackState: @escaping (MessageId, Double?, Double) -> Void = { _, _, _ in }, present: @escaping (ViewController, Any?) -> Void) -> GalleryItem? {
    let message = entry.message
    let location = entry.location
    if let (media, mediaImage) = mediaForMessage(message: message) {
        if let _ = media as? TelegramMediaImage {
            return ChatImageGalleryItem(context: context, presentationData: presentationData, message: message, location: location, displayInfoOnTop: displayInfoOnTop, performAction: performAction, openActionOptions: openActionOptions, present: present)
        } else if let file = media as? TelegramMediaFile {
            if file.isVideo {
                let content: UniversalVideoContent
                if file.isAnimated {
                    content = NativeVideoContent(id: .message(message.stableId, file.fileId), fileReference: .message(message: MessageReference(message), media: file), imageReference: mediaImage.flatMap({ ImageMediaReference.message(message: MessageReference(message), media: $0) }), loopVideo: true, enableSound: false, tempFilePath: tempFilePath, captureProtected: message.isCopyProtected())
                } else {
                    if true || (file.mimeType == "video/mpeg4" || file.mimeType == "video/mov" || file.mimeType == "video/mp4") {
                        content = NativeVideoContent(id: .message(message.stableId, file.fileId), fileReference: .message(message: MessageReference(message), media: file), imageReference: mediaImage.flatMap({ ImageMediaReference.message(message: MessageReference(message), media: $0) }), streamVideo: .conservative, loopVideo: loopVideos, tempFilePath: tempFilePath, captureProtected: message.isCopyProtected())
                    } else {
                        content = PlatformVideoContent(id: .message(message.id, message.stableId, file.fileId), content: .file(.message(message: MessageReference(message), media: file)), streamVideo: streamVideos, loopVideo: loopVideos)
                    }
                }
                
                var entities: [MessageTextEntity] = []
                for attribute in message.attributes {
                    if let attribute = attribute as? TextEntitiesMessageAttribute {
                        entities = attribute.entities
                        break
                    }
                }
                
                let text = galleryMessageCaptionText(message)
                if let result = addLocallyGeneratedEntities(text, enabledTypes: [.timecode], entities: entities, mediaDuration: file.duration.flatMap(Double.init)) {
                    entities = result
                }
                                
                let caption = galleryCaptionStringWithAppliedEntities(text, entities: entities)
                return UniversalVideoGalleryItem(context: context, presentationData: presentationData, content: content, originData: GalleryItemOriginData(title: message.effectiveAuthor.flatMap(EnginePeer.init)?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), timestamp: message.timestamp), indexData: location.flatMap { GalleryItemIndexData(position: Int32($0.index), totalCount: Int32($0.count)) }, contentInfo: .message(message), caption: caption, displayInfoOnTop: displayInfoOnTop, hideControls: hideControls, fromPlayingVideo: fromPlayingVideo, isSecret: isSecret, landscape: landscape, timecode: timecode, playbackRate: playbackRate, configuration: configuration, playbackCompleted: playbackCompleted, performAction: performAction, openActionOptions: openActionOptions, storeMediaPlaybackState: storeMediaPlaybackState, present: present)
            } else {
                if let fileName = file.fileName, (fileName as NSString).pathExtension.lowercased() == "json" {
                    return ChatAnimationGalleryItem(context: context, presentationData: presentationData, message: message, location: location)
                }
                else if file.mimeType.hasPrefix("image/") && file.mimeType != "image/gif" {
                    var pixelsCount: Int = 0
                    if let dimensions = file.dimensions {
                        pixelsCount = Int(dimensions.width) * Int(dimensions.height)
                    }
                    if pixelsCount < 10000 * 10000 {
                        return ChatImageGalleryItem(context: context, presentationData: presentationData, message: message, location: location, displayInfoOnTop: displayInfoOnTop, performAction: performAction, openActionOptions: openActionOptions, present: present)
                    } else {
                        return ChatDocumentGalleryItem(context: context, presentationData: presentationData, message: message, location: location)
                    }
                } else if internalDocumentItemSupportsMimeType(file.mimeType, fileName: file.fileName) {
                    return ChatDocumentGalleryItem(context: context, presentationData: presentationData, message: message, location: location)
                } else {
                    return ChatExternalFileGalleryItem(context: context, presentationData: presentationData, message: message, location: location)
                }
            }
        } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(webpageContent) = webpage.content {
            var content: UniversalVideoContent?
            switch websiteType(of: webpageContent.websiteName) {
                case .instagram where webpageContent.file != nil && webpageContent.image != nil && webpageContent.file!.isVideo:
                    content = NativeVideoContent(id: .message(message.stableId, webpageContent.file?.id ?? webpage.webpageId), fileReference: .message(message: MessageReference(message), media: webpageContent.file!), imageReference: webpageContent.image.flatMap({ ImageMediaReference.message(message: MessageReference(message), media: $0) }), streamVideo: .conservative, enableSound: true, captureProtected: message.isCopyProtected())
                default:
                    if let embedUrl = webpageContent.embedUrl, let image = webpageContent.image {
                        if let file = webpageContent.file, file.isVideo {
                            content = NativeVideoContent(id: .message(message.stableId, file.fileId), fileReference: .message(message: MessageReference(message), media: file), imageReference: mediaImage.flatMap({ ImageMediaReference.message(message: MessageReference(message), media: $0) }), streamVideo: .conservative, loopVideo: loopVideos, tempFilePath: tempFilePath, captureProtected: message.isCopyProtected())
                        } else if URL(string: embedUrl)?.pathExtension == "mp4" {
                            content = SystemVideoContent(url: embedUrl, imageReference: .webPage(webPage: WebpageReference(webpage), media: image), dimensions: webpageContent.embedSize?.cgSize ?? CGSize(width: 640.0, height: 640.0), duration: Int32(webpageContent.duration ?? 0))
                        }
                    }
                    if content == nil, let webEmbedContent = WebEmbedVideoContent(webPage: webpage, webpageContent: webpageContent, forcedTimestamp: timecode.flatMap(Int.init), openUrl: { url in
                        performAction(.url(url: url.absoluteString, concealed: false))
                    }) {
                        content = webEmbedContent
                    }
            }
            if let content = content {
                var description: NSAttributedString?
                if let descriptionText = webpageContent.text {
                    var entities: [MessageTextEntity] = []
                    if let result = addLocallyGeneratedEntities(descriptionText, enabledTypes: [.timecode], entities: entities, mediaDuration: 86400) {
                        entities = result
                    }
                    description = galleryCaptionStringWithAppliedEntities(descriptionText, entities: entities)
                }
                return UniversalVideoGalleryItem(context: context, presentationData: presentationData, content: content, originData: GalleryItemOriginData(title: message.effectiveAuthor.flatMap(EnginePeer.init)?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), timestamp: message.timestamp), indexData: location.flatMap { GalleryItemIndexData(position: Int32($0.index), totalCount: Int32($0.count)) }, contentInfo: .message(message), caption: NSAttributedString(string: ""), description: description, displayInfoOnTop: displayInfoOnTop, fromPlayingVideo: fromPlayingVideo, isSecret: isSecret, landscape: landscape, timecode: timecode, playbackRate: playbackRate, configuration: configuration, performAction: performAction, openActionOptions: openActionOptions, storeMediaPlaybackState: storeMediaPlaybackState, present: present)
            } else {
                return nil
            }
        }
    }
    return nil
}

public final class GalleryTransitionArguments {
    public let transitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))
    public let addToTransitionSurface: (UIView) -> Void
    
    public init(transitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: @escaping (UIView) -> Void) {
        self.transitionNode = transitionNode
        self.addToTransitionSurface = addToTransitionSurface
    }
}

public final class GalleryControllerPresentationArguments {
    public let animated: Bool
    public let transitionArguments: (MessageId, Media) -> GalleryTransitionArguments?
    
    public init(animated: Bool = true, transitionArguments: @escaping (MessageId, Media) -> GalleryTransitionArguments?) {
        self.animated = animated
        self.transitionArguments = transitionArguments
    }
}

private enum GalleryMessageHistoryView {
    case view(MessageHistoryView)
    case entries([MessageHistoryEntry], Bool, Bool)
    
    var entries: [MessageHistoryEntry] {
        switch self {
            case let .view(view):
                return view.entries
            case let .entries(entries, _, _):
                return entries
        }
    }
    
    var tagMask: MessageTags? {
        switch self {
        case .entries:
            return nil
        case let .view(view):
            return view.tagMask
        }
    }
    
    var hasEarlier: Bool {
        switch self {
        case let .entries(_, hasEarlier, _):
            return hasEarlier
        case let .view(view):
            return view.earlierId != nil
        }
    }
    
    var hasLater: Bool {
        switch self {
        case let .entries(_ , _, hasLater):
            return hasLater
        case let .view(view):
            return view.laterId != nil
        }
    }
}

public enum GalleryControllerInteractionTapAction {
    case url(url: String, concealed: Bool)
    case textMention(String)
    case peerMention(PeerId, String)
    case botCommand(String)
    case hashtag(String?, String)
    case timecode(Double, String)
}

public enum GalleryControllerItemNodeAction {
    case timecode(Double)
}

public struct GalleryConfiguration {
    static var defaultValue: GalleryConfiguration {
        return GalleryConfiguration(youtubePictureInPictureEnabled: false)
    }
    
    public let youtubePictureInPictureEnabled: Bool
    
    fileprivate init(youtubePictureInPictureEnabled: Bool) {
        self.youtubePictureInPictureEnabled = youtubePictureInPictureEnabled
    }
    
    static func with(appConfiguration: AppConfiguration) -> GalleryConfiguration {
        if let data = appConfiguration.data, let value = data["youtube_pip"] as? String {
            return GalleryConfiguration(youtubePictureInPictureEnabled: value != "disabled")
        } else {
            return .defaultValue
        }
    }
}

public class GalleryController: ViewController, StandalonePresentableController {
    public static let darkNavigationTheme = NavigationBarTheme(buttonColor: .white, disabledButtonColor: UIColor(rgb: 0x525252), primaryTextColor: .white, backgroundColor: UIColor(white: 0.0, alpha: 0.6), enableBackgroundBlur: false, separatorColor: UIColor(white: 0.0, alpha: 0.8), badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear)
    public static let lightNavigationTheme = NavigationBarTheme(buttonColor: UIColor(rgb: 0x007aff), disabledButtonColor: UIColor(rgb: 0xd0d0d0), primaryTextColor: .black, backgroundColor: UIColor(red: 0.968626451, green: 0.968626451, blue: 0.968626451, alpha: 1.0), enableBackgroundBlur: false, separatorColor: UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0), badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear)
    
    private var galleryNode: GalleryControllerNode {
        return self.displayNode as! GalleryControllerNode
    }
    
    private let context: AccountContext
    private var presentationData: PresentationData
    private let source: GalleryControllerItemSource
    private let invertItemOrder: Bool
    
    private let streamVideos: Bool
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private var adjustedForInitialPreviewingLayout = false
    
    public var temporaryDoNotWaitForReady = false
    private let fromPlayingVideo: Bool
    private let landscape: Bool
    private let timecode: Double?
    private var playbackRate: Double?
    
    private let accountInUseDisposable = MetaDisposable()
    private let disposable = MetaDisposable()
    
    private var entries: [MessageHistoryEntry] = []
    private var hasLeftEntries: Bool = false
    private var hasRightEntries: Bool = false
    private var loadingMore: Bool = false
    private var tagMask: MessageTags?
    private var centralEntryStableId: UInt32?
    private var configuration: GalleryConfiguration?
    
    private let centralItemTitle = Promise<String>()
    private let centralItemTitleView = Promise<UIView?>()
    private let centralItemRightBarButtonItem = Promise<UIBarButtonItem?>()
    private let centralItemRightBarButtonItems = Promise<[UIBarButtonItem]?>(nil)
    private let centralItemNavigationStyle = Promise<GalleryItemNodeNavigationStyle>()
    private let centralItemFooterContentNode = Promise<(GalleryFooterContentNode?, GalleryOverlayContentNode?)>()
    private let centralItemAttributesDisposable = DisposableSet();
    
    private let _hiddenMedia = Promise<(MessageId, Media)?>(nil)
    
    private let replaceRootController: (ViewController, Promise<Bool>?) -> Void
    private let baseNavigationController: NavigationController?
    
    private var hiddenMediaManagerIndex: Int?
    
    private let actionInteraction: GalleryControllerActionInteraction?
    private var performAction: (GalleryControllerInteractionTapAction) -> Void
    private var openActionOptions: (GalleryControllerInteractionTapAction, Message) -> Void
    
    private let updateVisibleDisposable = MetaDisposable()
    
    private var screenCaptureEventsDisposable: Disposable?
    
    public var centralItemUpdated: ((MessageId) -> Void)?
    public var onDidAppear: (() -> Void)?
    public var useSimpleAnimation: Bool = false
    
    private var initialOrientation: UIInterfaceOrientation?
    
    public init(context: AccountContext, source: GalleryControllerItemSource, invertItemOrder: Bool = false, streamSingleVideo: Bool = false, fromPlayingVideo: Bool = false, landscape: Bool = false, timecode: Double? = nil, playbackRate: Double? = nil, synchronousLoad: Bool = false, replaceRootController: @escaping (ViewController, Promise<Bool>?) -> Void, baseNavigationController: NavigationController?, actionInteraction: GalleryControllerActionInteraction? = nil) {
        self.context = context
        self.source = source
        self.invertItemOrder = invertItemOrder
        self.replaceRootController = replaceRootController
        self.baseNavigationController = baseNavigationController
        self.actionInteraction = actionInteraction
        self.streamVideos = streamSingleVideo
        self.fromPlayingVideo = fromPlayingVideo
        self.landscape = landscape
        self.timecode = timecode
        self.playbackRate = playbackRate
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        var performActionImpl: ((GalleryControllerInteractionTapAction) -> Void)?
        self.performAction = { action in
            performActionImpl?(action)
        }
        
        var openActionOptionsImpl: ((GalleryControllerInteractionTapAction, Message) -> Void)?
        self.openActionOptions = { action, message in
            openActionOptionsImpl?(action, message)
        }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: GalleryController.darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        let backItem = UIBarButtonItem(backButtonAppearanceWithTitle: presentationData.strings.Common_Back, target: self, action: #selector(self.donePressed))
        self.navigationItem.leftBarButtonItem = backItem
        
        self.statusBar.statusBarStyle = .White
        
        let message: Signal<Message?, NoError>
        switch source {
            case let .peerMessagesAtId(messageId, _, _):
                message = context.account.postbox.messageAtId(messageId)
            case let .standaloneMessage(m):
                message = .single(m)
            case let .custom(messages, messageId, _):
                message = messages
                |> take(1)
                |> map { messages, _, _ in
                    return messages.first(where: { $0.id == messageId })
                }
        }
        
        let messageView = message
        |> filter({ $0 != nil })
        |> mapToSignal { message -> Signal<GalleryMessageHistoryView?, NoError> in
            switch source {
                case let .peerMessagesAtId(_, chatLocation, chatLocationContextHolder):
                    if let tags = tagsForMessage(message!) {
                        let namespaces: MessageIdNamespaces
                        if Namespaces.Message.allScheduled.contains(message!.id.namespace) {
                            namespaces = .just(Namespaces.Message.allScheduled)
                        } else {
                            namespaces = .not(Namespaces.Message.allScheduled)
                        }
                        return context.account.postbox.aroundMessageHistoryViewForLocation(context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder), anchor: .index(message!.index), ignoreMessagesInTimestampRange: nil, count: 50, clipHoles: false, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tagMask: tags, appendMessagesFromTheSameGroup: false, namespaces: namespaces, orderStatistics: [.combinedLocation])
                        |> mapToSignal { (view, _, _) -> Signal<GalleryMessageHistoryView?, NoError> in
                            let mapped = GalleryMessageHistoryView.view(view)
                            return .single(mapped)
                        }
                    } else {
                        return .single(GalleryMessageHistoryView.entries([MessageHistoryEntry(message: message!, isRead: false, location: nil, monthLocation: nil, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: false))], false, false))
                }
                case .standaloneMessage:
                    return .single(GalleryMessageHistoryView.entries([MessageHistoryEntry(message: message!, isRead: false, location: nil, monthLocation: nil, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: false))], false ,false))
                case let .custom(messages, _, _):
                    return messages
                    |> map { messages, totalCount, hasMore in
                        var entries: [MessageHistoryEntry] = []
                        var index = messages.count
                        for message in messages.reversed() {
                            entries.append(MessageHistoryEntry(message: message, isRead: false, location: nil, monthLocation: nil, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: false)))
                            index -= 1
                        }
                        return GalleryMessageHistoryView.entries(entries, hasMore, false)
                    }
            }
        }
        |> take(1)
        
        let semaphore: DispatchSemaphore?
        if synchronousLoad {
            semaphore = DispatchSemaphore(value: 0)
        } else {
            semaphore = nil
        }
        
        var displayInfoOnTop = false
        if case .custom = source {
            displayInfoOnTop = true
        }
        
        let syncResult = Atomic<(Bool, (() -> Void)?)>(value: (false, nil))
        self.disposable.set(combineLatest(messageView, self.context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])).start(next: { [weak self] view, preferencesView in
            let f: () -> Void = {
                if let strongSelf = self {
                    if let view = view {
                        let appConfiguration: AppConfiguration = preferencesView.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? .defaultValue
                        let configuration = GalleryConfiguration.with(appConfiguration: appConfiguration)
                        strongSelf.configuration = configuration
                        
                        let entries = view.entries
                        var centralEntryStableId: UInt32?
                        loop: for i in 0 ..< entries.count {
                            let message = entries[i].message
                            switch source {
                                case let .peerMessagesAtId(messageId, _, _):
                                    if message.id == messageId {
                                        centralEntryStableId = message.stableId
                                        break loop
                                    }
                                case let .standaloneMessage(m):
                                    if message.id == m.id {
                                        centralEntryStableId = message.stableId
                                        break loop
                                    }
                                case let .custom(_, messageId, _):
                                    if message.id == messageId {
                                        centralEntryStableId = message.stableId
                                        break loop
                                    }
                            }
                        }
                        
                        strongSelf.tagMask = view.tagMask
                        
                        if invertItemOrder {
                            strongSelf.entries = entries.reversed()
                            strongSelf.hasLeftEntries = view.hasLater
                            strongSelf.hasRightEntries = view.hasEarlier
                            if let centralEntryStableId = centralEntryStableId {
                                strongSelf.centralEntryStableId = centralEntryStableId
                            }
                        } else {
                            strongSelf.entries = entries
                            strongSelf.hasLeftEntries = view.hasEarlier
                            strongSelf.hasRightEntries = view.hasLater
                            strongSelf.centralEntryStableId = centralEntryStableId
                        }
                        if strongSelf.isViewLoaded {
                            var items: [GalleryItem] = []
                            var centralItemIndex: Int?
                            for entry in strongSelf.entries {
                                var isCentral = false
                                if entry.message.stableId == strongSelf.centralEntryStableId {
                                    isCentral = true
                                }
                                if let item = galleryItemForEntry(context: context, presentationData: strongSelf.presentationData, entry: entry, isCentral: isCentral, streamVideos: streamSingleVideo, fromPlayingVideo: isCentral && fromPlayingVideo, landscape: isCentral && landscape, timecode: isCentral ? timecode : nil, playbackRate: { return self?.playbackRate }, displayInfoOnTop: displayInfoOnTop, configuration: configuration, performAction: strongSelf.performAction, openActionOptions: strongSelf.openActionOptions, storeMediaPlaybackState: strongSelf.actionInteraction?.storeMediaPlaybackState ?? { _, _, _ in }, present: { [weak self] c, a in
                                    if let strongSelf = self {
                                        strongSelf.presentInGlobalOverlay(c, with: a)
                                    }
                                }) {
                                    if isCentral {
                                        centralItemIndex = items.count
                                    }
                                    items.append(item)
                                }
                            }
                            
                            strongSelf.galleryNode.pager.replaceItems(items, centralItemIndex: centralItemIndex)
                            
                            if strongSelf.temporaryDoNotWaitForReady {
                                strongSelf.didSetReady = true
                                strongSelf._ready.set(.single(true))
                            } else {
                                let ready = strongSelf.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak strongSelf] _ in
                                    strongSelf?.didSetReady = true
                                }
                                strongSelf._ready.set(ready |> map { true })
                            }
                        }
                    }
                }
            }
            var process = false
            let _ = syncResult.modify { processed, _ in
                if !processed {
                    return (processed, f)
                }
                process = true
                return (true, nil)
            }
            semaphore?.signal()
            if process {
                Queue.mainQueue().async {
                    f()
                }
            }
        }))
        
        if let semaphore = semaphore {
            let _ = semaphore.wait(timeout: DispatchTime.now() + 1.0)
        }
        
        var syncResultApply: (() -> Void)?
        let _ = syncResult.modify { processed, f in
            syncResultApply = f
            return (true, nil)
        }
        
        syncResultApply?()
        
        self.centralItemAttributesDisposable.add(self.centralItemTitle.get().start(next: { [weak self] title in
            self?.navigationItem.title = title
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemTitleView.get().start(next: { [weak self] titleView in
            self?.navigationItem.titleView = titleView
        }))
        
        self.centralItemAttributesDisposable.add(combineLatest(self.centralItemRightBarButtonItem.get(), self.centralItemRightBarButtonItems.get()).start(next: { [weak self] rightBarButtonItem, rightBarButtonItems in
            if let rightBarButtonItem = rightBarButtonItem {
                self?.navigationItem.rightBarButtonItem = rightBarButtonItem
            } else if let rightBarButtonItems = rightBarButtonItems {
                self?.navigationItem.rightBarButtonItems = rightBarButtonItems
            } else {
                self?.navigationItem.rightBarButtonItem = nil
                self?.navigationItem.rightBarButtonItems = nil
            }
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemFooterContentNode.get().start(next: { [weak self] footerContentNode, overlayContentNode in
            self?.galleryNode.updatePresentationState({
                $0.withUpdatedFooterContentNode(footerContentNode).withUpdatedOverlayContentNode(overlayContentNode)
            }, transition: .immediate)
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemNavigationStyle.get().start(next: { [weak self] style in
            if let strongSelf = self {
                switch style {
                    case .dark:
                        strongSelf.statusBar.statusBarStyle = .White
                        strongSelf.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: GalleryController.darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: strongSelf.presentationData.strings)))
                        strongSelf.galleryNode.backgroundNode.backgroundColor = UIColor.black
                        strongSelf.galleryNode.isBackgroundExtendedOverNavigationBar = true
                    case .light:
                        strongSelf.statusBar.statusBarStyle = .Black
                        strongSelf.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: GalleryController.darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: strongSelf.presentationData.strings)))
                        strongSelf.galleryNode.backgroundNode.backgroundColor = UIColor(rgb: 0xbdbdc2)
                        strongSelf.galleryNode.isBackgroundExtendedOverNavigationBar = false
                }
            }
        }))
        
        let mediaManager = context.sharedContext.mediaManager
        self.hiddenMediaManagerIndex = mediaManager.galleryHiddenMediaManager.addSource(self._hiddenMedia.get()
        |> map { messageIdAndMedia in
            if let (messageId, media) = messageIdAndMedia {
                return .chat(context.account.id, messageId, media)
            } else {
                return nil
            }
        })
        
        performActionImpl = { [weak self] action in
            if let strongSelf = self {
                if case .timecode = action {
                } else {
                    strongSelf.dismiss(forceAway: false)
                }
                switch action {
                    case let .url(url, concealed):
                        strongSelf.actionInteraction?.openUrl(url, concealed)
                    case let .textMention(mention):
                        strongSelf.actionInteraction?.openPeerMention(mention)
                    case let .peerMention(peerId, _):
                        strongSelf.actionInteraction?.openPeer(peerId)
                    case let .botCommand(command):
                        strongSelf.actionInteraction?.openBotCommand(command)
                    case let .hashtag(peerName, hashtag):
                        strongSelf.actionInteraction?.openHashtag(peerName, hashtag)
                    case let .timecode(timecode, _):
                        strongSelf.galleryNode.pager.centralItemNode()?.processAction(.timecode(timecode))
                }
            }
        }
        
        openActionOptionsImpl = { [weak self] action, message in
            if let strongSelf = self {
                var presentationData = strongSelf.presentationData
                if !presentationData.theme.overallDarkAppearance {
                    presentationData = presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
                }
                switch action {
                    case let .url(url, _):
                        var cleanUrl = url
                        var canAddToReadingList = true
                        let canOpenIn = availableOpenInOptions(context: strongSelf.context, item: .url(url: url)).count > 1
                        let mailtoString = "mailto:"
                        let telString = "tel:"
                        var openText = presentationData.strings.Conversation_LinkDialogOpen
                        var phoneNumber: String?
                        
                        var isEmail = false
                        var isPhoneNumber = false
                        if cleanUrl.hasPrefix(mailtoString) {
                            canAddToReadingList = false
                            cleanUrl = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: mailtoString.distance(from: mailtoString.startIndex, to: mailtoString.endIndex))...])
                            isEmail = true
                        } else if cleanUrl.hasPrefix(telString) {
                            canAddToReadingList = false
                            phoneNumber = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: telString.distance(from: telString.startIndex, to: telString.endIndex))...])
                            cleanUrl = phoneNumber!
                            openText = presentationData.strings.UserInfo_PhoneCall
                            isPhoneNumber = true
                        } else if canOpenIn {
                            openText = presentationData.strings.Conversation_FileOpenIn
                        }
                        let actionSheet = ActionSheetController(presentationData: presentationData)
                        
                        var items: [ActionSheetItem] = []
                        items.append(ActionSheetTextItem(title: cleanUrl))
                        items.append(ActionSheetButtonItem(title: openText, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                if canOpenIn {
                                    strongSelf.actionInteraction?.openUrlIn(url)
                                } else {
                                    strongSelf.dismiss(forceAway: false)
                                    strongSelf.actionInteraction?.openUrl(url, false)
                                }
                            }
                        }))
                        if let phoneNumber = phoneNumber {
                            items.append(ActionSheetButtonItem(title: presentationData.strings.Conversation_AddContact, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    strongSelf.dismiss(forceAway: false)
                                    strongSelf.actionInteraction?.addContact(phoneNumber)
                                }
                            }))
                        }
                        items.append(ActionSheetButtonItem(title: canAddToReadingList ? presentationData.strings.ShareMenu_CopyShareLink : presentationData.strings.Conversation_ContextMenuCopy, color: .accent, action: { [weak actionSheet, weak self] in
                            actionSheet?.dismissAnimated()
                            UIPasteboard.general.string = cleanUrl
                            
                            let content: UndoOverlayContent
                            if isPhoneNumber {
                                content = .copy(text: presentationData.strings.Conversation_PhoneCopied)
                            } else if isEmail {
                                content = .copy(text: presentationData.strings.Conversation_EmailCopied)
                            } else if canAddToReadingList {
                                content = .linkCopied(text: presentationData.strings.Conversation_LinkCopied)
                            } else {
                                content = .copy(text: presentationData.strings.Conversation_TextCopied)
                            }
                            self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                        }))
                        if canAddToReadingList {
                            items.append(ActionSheetButtonItem(title: presentationData.strings.Conversation_AddToReadingList, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let link = URL(string: url) {
                                    let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
                                }
                            }))
                        }
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.present(actionSheet, in: .window(.root))
                    case let .peerMention(peerId, mention):
                        let actionSheet = ActionSheetController(presentationData: presentationData)
                        var items: [ActionSheetItem] = []
                        if !mention.isEmpty {
                            items.append(ActionSheetTextItem(title: mention))
                        }
                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                strongSelf.dismiss(forceAway: false)
                                strongSelf.actionInteraction?.openPeer(peerId)
                            }
                        }))
                        if !mention.isEmpty {
                            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet, weak self] in
                                actionSheet?.dismissAnimated()
                                UIPasteboard.general.string = mention
                                
                                let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_UsernameCopied)
                                self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                            }))
                        }
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.present(actionSheet, in: .window(.root))
                    case let .textMention(mention):
                        let actionSheet = ActionSheetController(presentationData: presentationData)
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                            ActionSheetTextItem(title: mention),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    strongSelf.dismiss(forceAway: false)
                                    strongSelf.actionInteraction?.openPeerMention(mention)
                                }
                            }),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet, weak self] in
                                actionSheet?.dismissAnimated()
                                UIPasteboard.general.string = mention
                                
                                let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_TextCopied)
                                self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                            })
                        ]), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.present(actionSheet, in: .window(.root))
                    case let .botCommand(command):
                        let actionSheet = ActionSheetController(presentationData: presentationData)
                        var items: [ActionSheetItem] = []
                        items.append(ActionSheetTextItem(title: command))
                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet, weak self] in
                            actionSheet?.dismissAnimated()
                            UIPasteboard.general.string = command
                            
                            let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_TextCopied)
                            self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                        }))
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.present(actionSheet, in: .window(.root))
                    case let .hashtag(peerName, hashtag):
                        let actionSheet = ActionSheetController(presentationData: presentationData)
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                            ActionSheetTextItem(title: hashtag),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    strongSelf.dismiss(forceAway: false)
                                    strongSelf.actionInteraction?.openHashtag(peerName, hashtag)
                                }
                            }),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet, weak self] in
                                actionSheet?.dismissAnimated()
                                UIPasteboard.general.string = hashtag
                                
                                let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_HashtagCopied)
                                self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                            })
                        ]), ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])
                        ])
                        strongSelf.present(actionSheet, in: .window(.root))
                    case let .timecode(timecode, text):
                        let isCopyLink: Bool
                        if message.id.namespace == Namespaces.Message.Cloud, let _ = message.peers[message.id.peerId] as? TelegramChannel, !(message.media.first is TelegramMediaAction) {
                            isCopyLink = true
                        } else {
                            isCopyLink = false
                        }
                        
                        let actionSheet = ActionSheetController(presentationData: presentationData)
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                            ActionSheetTextItem(title: text),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    strongSelf.dismiss(forceAway: false)
                                    strongSelf.galleryNode.pager.centralItemNode()?.processAction(.timecode(timecode))
                                }
                            }),
                            ActionSheetButtonItem(title: isCopyLink ? strongSelf.presentationData.strings.Conversation_ContextMenuCopyLink : strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet, weak self] in
                                actionSheet?.dismissAnimated()
                                if isCopyLink, let channel = message.peers[message.id.peerId] as? TelegramChannel {
                                    let _ = (context.engine.messages.exportMessageLink(peerId: message.id.peerId, messageId: message.id, isThread: false)
                                    |> map { result -> String? in
                                        return result
                                    }
                                    |> deliverOnMainQueue).start(next: { link in
                                        if let link = link {
                                            UIPasteboard.general.string = link + "?t=\(Int32(timecode))"
                                            
                                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                            
                                            var warnAboutPrivate = false
                                            if channel.addressName == nil {
                                                warnAboutPrivate = true
                                            }
                                            
                                            Queue.mainQueue().after(0.2, {
                                                let content: UndoOverlayContent
                                                if warnAboutPrivate {
                                                    content = .linkCopied(text: presentationData.strings.Conversation_PrivateMessageLinkCopiedLong)
                                                } else {
                                                    content = .linkCopied(text: presentationData.strings.Conversation_LinkCopied)
                                                }
                                                self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                                            })
                                        } else {
                                            UIPasteboard.general.string = text
                                            
                                            let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_TextCopied)
                                            self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                                        }
                                    })
                                } else {
                                    UIPasteboard.general.string = text
                                
                                    let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_TextCopied)
                                    self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                                }
                            })
                        ]), ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])
                        ])
                        strongSelf.present(actionSheet, in: .window(.root))
                }
            }
        }
        
        self.blocksBackgroundWhenInOverlay = true
        self.acceptsFocusWhenInOverlay = true
        self.isOpaqueWhenInOverlay = true
        
        switch source {
        case let .peerMessagesAtId(id, _, _):
            if id.peerId.namespace == Namespaces.Peer.SecretChat {
                self.screenCaptureEventsDisposable = (screenCaptureEvents()
                |> deliverOnMainQueue).start(next: { [weak self] _ in
                    if let strongSelf = self, strongSelf.traceVisibility() {
                        let _ = strongSelf.context.engine.messages.addSecretChatMessageScreenshot(peerId: id.peerId).start()
                    }
                })
            }
        default:
            break
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let initialOrientation = self.initialOrientation {
            self.context.sharedContext.applicationBindings.forceOrientation(initialOrientation)
        }
        
        self.accountInUseDisposable.dispose()
        self.disposable.dispose()
        self.centralItemAttributesDisposable.dispose()
        if let hiddenMediaManagerIndex = self.hiddenMediaManagerIndex {
            self.context.sharedContext.mediaManager.galleryHiddenMediaManager.removeSource(hiddenMediaManagerIndex)
        }
        self.updateVisibleDisposable.dispose()
        self.screenCaptureEventsDisposable?.dispose()
    }
    
    @objc private func donePressed() {
        self.dismiss(forceAway: false)
    }
    
    private func dismiss(forceAway: Bool) {
        var animatedOutNode = true
        var animatedOutInterface = false
        
        let completion = { [weak self] in
            if animatedOutNode && animatedOutInterface {
                self?._hiddenMedia.set(.single(nil))
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
            }
        }
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? GalleryControllerPresentationArguments {
            let message = self.entries[centralItemNode.index].message
            if let (media, _) = mediaForMessage(message: message), let transitionArguments = presentationArguments.transitionArguments(message.id, media), !forceAway {
                animatedOutNode = false
                centralItemNode.animateOut(to: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface, completion: {
                    animatedOutNode = true
                    completion()
                })
            }
        }
        
        self.galleryNode.animateOut(animateContent: animatedOutNode, completion: {
            animatedOutInterface = true
            completion()
        })
    }
    
    override public func loadDisplayNode() {
        let controllerInteraction = GalleryControllerInteraction(presentController: { [weak self] controller, arguments in
            if let strongSelf = self {
                strongSelf.present(controller, in: .window(.root), with: arguments, blockInteraction: true)
            }
        }, pushController: { [weak self] c in
            self?.baseNavigationController?.pushViewController(c)
            self?.dismiss(forceAway: true)
        },  dismissController: { [weak self] in
            self?.dismiss(forceAway: true)
        }, replaceRootController: { [weak self] controller, ready in
            if let strongSelf = self {
                strongSelf.replaceRootController(controller, ready)
            }
        }, editMedia: { [weak self] messageId in
            if let strongSelf = self {
                var snapshots: [UIView] = []
                if let navigationBar = strongSelf.navigationBar, let snapshotView = navigationBar.view.snapshotContentTree() {
                    snapshotView.frame = navigationBar.frame
                    snapshots.append(snapshotView)
                }
                if let snapshotView = strongSelf.galleryNode.footerNode.view.snapshotContentTree() {
                    snapshotView.frame = strongSelf.galleryNode.footerNode.frame
                    snapshots.append(snapshotView)
                }
                
                strongSelf.actionInteraction?.editMedia(messageId, snapshots, { [weak self] in
                    self?.dismiss(forceAway: true)
                })
            }
        })
        self.displayNode = GalleryControllerNode(controllerInteraction: controllerInteraction)
        self.displayNodeDidLoad()
        
        self.galleryNode.statusBar = self.statusBar
        self.galleryNode.navigationBar = self.navigationBar
        
        self.galleryNode.transitionDataForCentralItem = { [weak self] in
            if let strongSelf = self {
                if let centralItemNode = strongSelf.galleryNode.pager.centralItemNode(), let presentationArguments = strongSelf.presentationArguments as? GalleryControllerPresentationArguments {
                    let message = strongSelf.entries[centralItemNode.index].message
                    if let (media, _) = mediaForMessage(message: message), let transitionArguments = presentationArguments.transitionArguments(message.id, media) {
                        return (transitionArguments.transitionNode, transitionArguments.addToTransitionSurface)
                    }
                }
            }
            return nil
        }
        self.galleryNode.dismiss = { [weak self] in
            self?._hiddenMedia.set(.single(nil))
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        self.galleryNode.beginCustomDismiss = { [weak self] simpleAnimation in
            if let strongSelf = self {
                strongSelf._hiddenMedia.set(.single(nil))
                
                let animatedOutNode = !simpleAnimation
                
                strongSelf.galleryNode.animateOut(animateContent: animatedOutNode, completion: {
                })
            }
        }
        
        self.galleryNode.completeCustomDismiss = { [weak self] in
            self?._hiddenMedia.set(.single(nil))
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        self.galleryNode.controlsVisibilityChanged = { [weak self] visible in
            self?.prefersOnScreenNavigationHidden = !visible
            self?.galleryNode.pager.centralItemNode()?.controlsVisibilityUpdated(isVisible: visible)
        }
        
        self.galleryNode.updateOrientation = { [weak self] orientation in
            if let strongSelf = self {
                if strongSelf.initialOrientation == nil {
                    strongSelf.initialOrientation = orientation == .portrait ? .landscapeRight : .portrait
                } else if strongSelf.initialOrientation == orientation {
                    strongSelf.initialOrientation = nil
                }
                strongSelf.context.sharedContext.applicationBindings.forceOrientation(orientation)
            }
        }
        
        let baseNavigationController = self.baseNavigationController
        self.galleryNode.baseNavigationController = { [weak baseNavigationController] in
            return baseNavigationController
        }
        self.galleryNode.galleryController = { [weak self] in
            return self
        }
        
        var displayInfoOnTop = false
        if case .custom = source {
            displayInfoOnTop = true
        }
        
        var items: [GalleryItem] = []
        var centralItemIndex: Int?
        for entry in self.entries {
            var isCentral = false
            if entry.message.stableId == self.centralEntryStableId {
                isCentral = true
            }
            if let item = galleryItemForEntry(context: self.context, presentationData: self.presentationData, entry: entry, streamVideos: self.streamVideos, fromPlayingVideo: isCentral && self.fromPlayingVideo, landscape: isCentral && self.landscape, timecode: isCentral ? self.timecode : nil, playbackRate: { [weak self] in return self?.playbackRate }, displayInfoOnTop: displayInfoOnTop, configuration: self.configuration, performAction: self.performAction, openActionOptions: self.openActionOptions, storeMediaPlaybackState: self.actionInteraction?.storeMediaPlaybackState ?? { _, _, _ in }, present: { [weak self] c, a in
                if let strongSelf = self {
                    strongSelf.presentInGlobalOverlay(c, with: a)
                }
            }) {
                if isCentral {
                    centralItemIndex = items.count
                }
                items.append(item)
            }
        }
        
        self.galleryNode.pager.replaceItems(items, centralItemIndex: centralItemIndex)
        
        self.galleryNode.pager.centralItemIndexUpdated = { [weak self] index in
            if let strongSelf = self {
                var hiddenItem: (MessageId, Media)?
                if let index = index {
                    let message = strongSelf.entries[index].message
                    strongSelf.centralEntryStableId = message.stableId
                    if let (media, _) = mediaForMessage(message: message) {
                        hiddenItem = (message.id, media)
                    }
                    
                    if let node = strongSelf.galleryNode.pager.centralItemNode() {
                        strongSelf.centralItemTitle.set(node.title())
                        strongSelf.centralItemTitleView.set(node.titleView())
                        strongSelf.centralItemRightBarButtonItem.set(node.rightBarButtonItem())
                        strongSelf.centralItemRightBarButtonItems.set(node.rightBarButtonItems())
                        strongSelf.centralItemNavigationStyle.set(node.navigationStyle())
                        strongSelf.centralItemFooterContentNode.set(node.footerContent())
                        strongSelf.galleryNode.pager.pagingEnabledPromise.set(node.isPagingEnabled())
                    }
                    
                    switch strongSelf.source {
                        case let .peerMessagesAtId(_, chatLocation, chatLocationContextHolder):
                            var reloadAroundIndex: MessageIndex?
                            if index <= 2 && strongSelf.hasLeftEntries {
                                reloadAroundIndex = strongSelf.entries.first?.index
                            } else if index >= strongSelf.entries.count - 3 && strongSelf.hasRightEntries {
                                reloadAroundIndex = strongSelf.entries.last?.index
                            }
                            if let reloadAroundIndex = reloadAroundIndex, let tagMask = strongSelf.tagMask {
                                let namespaces: MessageIdNamespaces
                                if Namespaces.Message.allScheduled.contains(message.id.namespace) {
                                    namespaces = .just(Namespaces.Message.allScheduled)
                                } else {
                                    namespaces = .not(Namespaces.Message.allScheduled)
                                }
                                let signal = strongSelf.context.account.postbox.aroundMessageHistoryViewForLocation(strongSelf.context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder), anchor: .index(reloadAroundIndex), ignoreMessagesInTimestampRange: nil, count: 50, clipHoles: false, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tagMask: tagMask, appendMessagesFromTheSameGroup: false, namespaces: namespaces, orderStatistics: [.combinedLocation])
                                    |> mapToSignal { (view, _, _) -> Signal<GalleryMessageHistoryView?, NoError> in
                                        let mapped = GalleryMessageHistoryView.view(view)
                                        return .single(mapped)
                                    }
                                    |> take(1)
                                
                                strongSelf.updateVisibleDisposable.set((signal
                                    |> deliverOnMainQueue).start(next: { view in
                                        guard let strongSelf = self, let view = view else {
                                            return
                                        }
                                        
                                        let entries = view.entries
                                        
                                        if strongSelf.invertItemOrder {
                                            strongSelf.entries = entries.reversed()
                                            strongSelf.hasLeftEntries = view.hasLater
                                            strongSelf.hasRightEntries = view.hasEarlier
                                        } else {
                                            strongSelf.entries = entries
                                            strongSelf.hasLeftEntries = view.hasEarlier
                                            strongSelf.hasRightEntries = view.hasLater
                                        }
                                        if strongSelf.isViewLoaded {
                                            var items: [GalleryItem] = []
                                            var centralItemIndex: Int?
                                            for entry in strongSelf.entries {
                                                var isCentral = false
                                                if entry.message.stableId == strongSelf.centralEntryStableId {
                                                    isCentral = true
                                                }
                                                if let item = galleryItemForEntry(context: strongSelf.context, presentationData: strongSelf.presentationData, entry: entry, isCentral: isCentral, streamVideos: false, fromPlayingVideo: isCentral && strongSelf.fromPlayingVideo, landscape: isCentral && strongSelf.landscape, timecode: isCentral ? strongSelf.timecode : nil, playbackRate: { return self?.playbackRate }, displayInfoOnTop: displayInfoOnTop, configuration: strongSelf.configuration, performAction: strongSelf.performAction, openActionOptions: strongSelf.openActionOptions, storeMediaPlaybackState: strongSelf.actionInteraction?.storeMediaPlaybackState ?? { _, _, _ in }, present: { [weak self] c, a in
                                                    if let strongSelf = self {
                                                        strongSelf.presentInGlobalOverlay(c, with: a)
                                                    }
                                                }) {
                                                    if isCentral {
                                                        centralItemIndex = items.count
                                                    }
                                                    items.append(item)
                                                }
                                            }
                                            
                                            strongSelf.galleryNode.pager.replaceItems(items, centralItemIndex: centralItemIndex)
                                        }
                                    }))
                        }
                        case let .custom(messages, _, loadMore):
                            if index >= strongSelf.entries.count - 3 && strongSelf.hasRightEntries && !strongSelf.loadingMore {
                                strongSelf.loadingMore = true
                                loadMore?()
                                
                                strongSelf.updateVisibleDisposable.set((messages
                                |> deliverOnMainQueue).start(next: { messages, totalCount, hasMore in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    var entries: [MessageHistoryEntry] = []
                                    var index = messages.count
                                    for message in messages.reversed() {
                                        entries.append(MessageHistoryEntry(message: message, isRead: false, location: nil, monthLocation: nil, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: false)))
                                        index -= 1
                                    }
                                    
                                    if entries.count > strongSelf.entries.count {
                                        if strongSelf.invertItemOrder {
                                            strongSelf.entries = entries.reversed()
                                            strongSelf.hasLeftEntries = false
                                            strongSelf.hasRightEntries = hasMore
                                        } else {
                                            strongSelf.entries = entries
                                            strongSelf.hasLeftEntries = hasMore
                                            strongSelf.hasRightEntries = false
                                        }
                                        if strongSelf.isViewLoaded {
                                            var items: [GalleryItem] = []
                                            var centralItemIndex: Int?
                                            for entry in strongSelf.entries {
                                                var isCentral = false
                                                if entry.message.stableId == strongSelf.centralEntryStableId {
                                                    isCentral = true
                                                }
                                                if let item = galleryItemForEntry(context: strongSelf.context, presentationData: strongSelf.presentationData, entry: entry, isCentral: isCentral, streamVideos: false, fromPlayingVideo: isCentral && strongSelf.fromPlayingVideo, landscape: isCentral && strongSelf.landscape, timecode: isCentral ? strongSelf.timecode : nil, playbackRate: { return self?.playbackRate }, displayInfoOnTop: displayInfoOnTop, configuration: strongSelf.configuration, performAction: strongSelf.performAction, openActionOptions: strongSelf.openActionOptions, storeMediaPlaybackState: strongSelf.actionInteraction?.storeMediaPlaybackState ?? { _, _, _ in }, present: { [weak self] c, a in
                                                    if let strongSelf = self {
                                                        strongSelf.presentInGlobalOverlay(c, with: a)
                                                    }
                                                }) {
                                                    if isCentral {
                                                        centralItemIndex = items.count
                                                    }
                                                    items.append(item)
                                                }
                                            }
                                            
                                            strongSelf.galleryNode.pager.replaceItems(items, centralItemIndex: centralItemIndex)
                                        }
                                        
                                        strongSelf.updateVisibleDisposable.set(nil)
                                        strongSelf.loadingMore = false
                                    }
                                }))
                            }
                        default:
                            break
                    }
                }
                if strongSelf.didSetReady {
                    strongSelf._hiddenMedia.set(.single(hiddenItem))
                    if let hiddenItem = hiddenItem {
                        strongSelf.centralItemUpdated?(hiddenItem.0)
                    }
                }
            }
        }
        
        if !self.entries.isEmpty && !self.didSetReady {
            if self.temporaryDoNotWaitForReady {
                self.didSetReady = true
                self._ready.set(.single(true))
            } else {
                let ready = self.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak self] _ in
                    self?.didSetReady = true
                }
                self._ready.set(ready |> map { true })
            }
        }
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var nodeAnimatesItself = false
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode() {
            let message = self.entries[centralItemNode.index].message
            self.centralItemTitle.set(centralItemNode.title())
            self.centralItemTitleView.set(centralItemNode.titleView())
            self.centralItemRightBarButtonItem.set(centralItemNode.rightBarButtonItem())
            self.centralItemRightBarButtonItems.set(centralItemNode.rightBarButtonItems())
            self.centralItemNavigationStyle.set(centralItemNode.navigationStyle())
            self.centralItemFooterContentNode.set(centralItemNode.footerContent())
            self.galleryNode.pager.pagingEnabledPromise.set(centralItemNode.isPagingEnabled())
            
            if let (media, _) = mediaForMessage(message: message) {
                if let presentationArguments = self.presentationArguments as? GalleryControllerPresentationArguments, let transitionArguments = presentationArguments.transitionArguments(message.id, media) {
                    nodeAnimatesItself = true
                    if presentationArguments.animated {
                        centralItemNode.animateIn(from: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface, completion: {})
                    }
                    
                    self._hiddenMedia.set(.single((message.id, media)))
                }
                centralItemNode.activateAsInitial()
            }

            self.onDidAppear?()
        }
        
        if !self.isPresentedInPreviewingContext() {
            self.galleryNode.setControlsHidden(self.landscape, animated: false)
            if let presentationArguments = self.presentationArguments as? GalleryControllerPresentationArguments {
                if presentationArguments.animated {
                    self.galleryNode.animateIn(animateContent: !nodeAnimatesItself && !self.useSimpleAnimation, useSimpleAnimation: self.useSimpleAnimation)
                }
            }
        }
        
        self.accountInUseDisposable.set(self.context.sharedContext.setAccountUserInterfaceInUse(self.context.account.id))
    }
    
    override public func didAppearInContextPreview() {
        if let centralItemNode = self.galleryNode.pager.centralItemNode() {
            let message = self.entries[centralItemNode.index].message
            self.centralItemTitle.set(centralItemNode.title())
            self.centralItemTitleView.set(centralItemNode.titleView())
            self.centralItemRightBarButtonItem.set(centralItemNode.rightBarButtonItem())
            self.centralItemRightBarButtonItems.set(centralItemNode.rightBarButtonItems())
            self.centralItemNavigationStyle.set(centralItemNode.navigationStyle())
            self.centralItemFooterContentNode.set(centralItemNode.footerContent())
            self.galleryNode.pager.pagingEnabledPromise.set(centralItemNode.isPagingEnabled())
            
            if let _ = mediaForMessage(message: message) {
                centralItemNode.activateAsInitial()
            }
        }
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.accountInUseDisposable.set(nil)
    }
    
    override public func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let itemSize = centralItemNode.contentSize() {
            return itemSize.aspectFitted(layout.size)
        } else {
            return nil
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.galleryNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.galleryNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
        
        if !self.adjustedForInitialPreviewingLayout && self.isPresentedInPreviewingContext() {
            self.adjustedForInitialPreviewingLayout = true
            self.galleryNode.setControlsHidden(true, animated: false)
            if let centralItemNode = self.galleryNode.pager.centralItemNode(), let itemSize = centralItemNode.contentSize() {
                centralItemNode.adjustForPreviewing()
                self.preferredContentSize = itemSize.aspectFitted(layout.size)
                self.containerLayoutUpdated(ContainerViewLayout(size: self.preferredContentSize, metrics: LayoutMetrics(), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: .immediate)
            }
        }
    }

    func updateSharedPlaybackRate(_ playbackRate: Double?) {
        self.playbackRate = playbackRate

        self.galleryNode.pager.forEachItemNode { itemNode in
            if let itemNode = itemNode as? UniversalVideoGalleryItemNode {
                itemNode.updatePlaybackRate(playbackRate)
            }
        }
    }
}
