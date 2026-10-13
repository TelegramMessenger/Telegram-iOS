import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import AccountContext
import WebsiteType
import UrlHandling
import AlertComponent
import ChatMessageAttachedContentNode
import ChatMessageBubbleContentNode
import ChatHistoryEntry
import ChatMessageItemCommon
import ChatControllerInteraction
import WallpaperPreviewMedia
import ChatPresentationInterfaceState

private struct AlertWebpagePreviewContent {
    var title: String?
    var subtitle: NSAttributedString?
    var text: String?
    var entities: [MessageTextEntity]?
    var mediaAndFlags: ([EngineRawMedia], ChatMessageAttachedContentNodeMediaFlags)?
    var mediaBadge: String?
}

public final class AlertWebpagePreviewComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment
    
    let context: AccountContext
    let presentationData: PresentationData
    let webpage: TelegramMediaWebpage
    let peer: EnginePeer?
    
    public init(
        context: AccountContext,
        presentationData: PresentationData,
        webpage: TelegramMediaWebpage,
        peer: EnginePeer? = nil
    ) {
        self.context = context
        self.presentationData = presentationData
        self.webpage = webpage
        self.peer = peer
    }
    
    public static func ==(lhs: AlertWebpagePreviewComponent, rhs: AlertWebpagePreviewComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.presentationData != rhs.presentationData {
            return false
        }
        if lhs.webpage != rhs.webpage {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let contentNode: ChatMessageAttachedContentNode
        
        private var component: AlertWebpagePreviewComponent?
        private var controllerInteraction: ChatControllerInteraction?
        private weak var controllerInteractionContext: AccountContext?
        
        override init(frame: CGRect) {
            self.contentNode = ChatMessageAttachedContentNode()
            self.contentNode.isUserInteractionEnabled = false
            
            super.init(frame: frame)
            
            self.addSubview(self.contentNode.view)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AlertWebpagePreviewComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            guard case let .Loaded(webpageContent) = component.webpage.content else {
                return CGSize(width: availableSize.width, height: 0.0)
            }
            
            let environment = environment[AlertComponentEnvironment.self]
            let presentationData = ChatPresentationData(
                theme: ChatPresentationThemeData(
                    theme: environment.theme,
                    wallpaper: component.presentationData.chatWallpaper
                ),
                fontSize: component.presentationData.chatFontSize,
                strings: environment.strings,
                dateTimeFormat: component.presentationData.dateTimeFormat,
                nameDisplayOrder: component.presentationData.nameDisplayOrder,
                disableAnimations: true,
                largeEmoji: component.presentationData.largeEmoji,
                chatBubbleCorners: PresentationChatBubbleCorners(
                    mainRadius: component.presentationData.chatBubbleCorners.mainRadius,
                    auxiliaryRadius: component.presentationData.chatBubbleCorners.auxiliaryRadius,
                    mergeBubbleCorners: component.presentationData.chatBubbleCorners.mergeBubbleCorners,
                    hasTails: false
                ),
                animatedEmojiScale: 1.0,
                isPreview: true
            )
            
            let controllerInteraction: ChatControllerInteraction
            if let current = self.controllerInteraction, self.controllerInteractionContext === component.context {
                controllerInteraction = current
            } else {
                controllerInteraction = ChatControllerInteraction(
                    openMessage: { _, _ in
                        return false
                    },
                    openPeer: { _, _, _, _ in },
                    openPeerMention: { _, _ in },
                    openMessageContextMenu: { _, _, _, _, _, _ in },
                    openMessageReactionContextMenu: { _, _, _, _ in },
                    updateMessageReaction: { _, _, _, _ in },
                    activateMessagePinch: { _ in },
                    openMessageContextActions: { _, _, _, _ in },
                    navigateToMessage: { _, _, _ in },
                    navigateToMessageStandalone: { _ in },
                    navigateToThreadMessage: { _, _, _ in },
                    tapMessage: nil,
                    clickThroughMessage: { _, _ in },
                    toggleMessagesSelection: { _, _ in },
                    sendCurrentMessage: { _, _ in },
                    sendMessage: { _, _ in },
                    sendSticker: { _, _, _, _, _, _, _, _, _ in return false },
                    sendEmoji: { _, _, _ in },
                    sendGif: { _, _, _, _, _ in return false },
                    sendBotContextResultAsGif: { _, _, _, _, _, _ in
                        return false
                    },
                    editGif: { _, _ in },
                    requestMessageActionCallback: { _, _, _, _, _ in },
                    requestMessageActionUrlAuth: { _, _ in },
                    activateSwitchInline: { _, _, _ in },
                    openUrl: { _ in },
                    openExternalInstantPage: { _ in },
                    shareCurrentLocation: { _ in },
                    shareAccountContact: { _ in },
                    sendBotCommand: { _, _ in },
                    openInstantPage: { _, _ in },
                    openWallpaper: { _ in },
                    openTheme: { _ in },
                    openHashtag: { _, _ in },
                    updateInputState: { _ in },
                    updateInputMode: { _ in },
                    updatePresentationState: { _ in },
                    openMessageShareMenu: { _ in },
                    presentController: { _, _ in },
                    presentControllerInCurrent: { _, _ in },
                    navigationController: {
                        return nil
                    },
                    chatControllerNode: {
                        return nil
                    },
                    presentGlobalOverlayController: { _, _ in },
                    callPeer: { _, _ in },
                    openConferenceCall: { _ in },
                    longTap: { _, _ in },
                    todoItemLongTap: { _, _ in },
                    pollOptionLongTap: { _, _ in },
                    openCheckoutOrReceipt: { _, _ in },
                    openSearch: {},
                    setupReply: { _ in },
                    canSetupReply: { _ in
                        return .none
                    },
                    canSendMessages: {
                        return false
                    },
                    navigateToFirstDateMessage: { _, _ in },
                    requestRedeliveryOfFailedMessages: { _ in },
                    addContact: { _ in },
                    rateCall: { _, _, _ in },
                    requestSelectMessagePollOptions: { _, _ in },
                    requestAddMessagePollOption: { _, _, _, _, _ in },
                    requestOpenMessagePollResults: { _, _ in },
                    openAppStorePage: {},
                    displayMessageTooltip: { _, _, _, _, _ in },
                    seekToTimecode: { _, _, _ in },
                    scheduleCurrentMessage: { _ in },
                    sendScheduledMessagesNow: { _ in },
                    editScheduledMessagesTime: { _ in },
                    performTextSelectionAction: { _, _, _, _, _ in },
                    displayImportedMessageTooltip: { _ in },
                    displaySwipeToReplyHint: {},
                    dismissReplyMarkupMessage: { _ in },
                    openMessagePollResults: { _, _ in },
                    openPollCreation: { _, _ in },
                    openPollMedia: { _, _ in },
                    displayPollSolution: { _, _ in },
                    displayPsa: { _, _ in },
                    displayDiceTooltip: { _ in },
                    animateDiceSuccess: { _, _ in },
                    displayPremiumStickerTooltip: { _, _ in },
                    displayEmojiPackTooltip: { _, _ in },
                    openPeerContextMenu: { _, _, _, _, _ in },
                    openMessageReplies: { _, _, _ in },
                    openReplyThreadOriginalMessage: { _ in },
                    openMessageStats: { _ in },
                    editMessageMedia: { _, _ in },
                    copyText: { _ in },
                    displayUndo: { _ in },
                    isAnimatingMessage: { _ in
                        return false
                    },
                    getMessageTransitionNode: {
                        return nil
                    },
                    updateChoosingSticker: { _ in },
                    commitEmojiInteraction: { _, _, _, _ in },
                    openLargeEmojiInfo: { _, _, _ in },
                    openJoinLink: { _ in },
                    openWebView: { _, _, _, _, _ in },
                    activateAdAction: { _, _, _, _ in },
                    adContextAction: { _, _, _ in },
                    removeAd: { _ in },
                    openRequestedPeerSelection: { _, _, _, _ in },
                    saveMediaToFiles: { _ in },
                    openNoAdsDemo: {},
                    openAdsInfo: {},
                    displayGiveawayParticipationStatus: { _ in },
                    openPremiumStatusInfo: { _, _, _, _ in },
                    openRecommendedChannelContextMenu: { _, _, _ in },
                    openGroupBoostInfo: { _, _ in },
                    openStickerEditor: {},
                    openAgeRestrictedMessageMedia: { _, _ in },
                    playMessageEffect: { _ in },
                    editMessageFactCheck: { _ in },
                    sendGift: { _ in },
                    openUniqueGift: { _ in },
                    openMessageFeeException: {},
                    requestMessageUpdate: { _, _, _ in },
                    cancelInteractiveKeyboardGestures: {},
                    dismissTextInput: {},
                    scrollToMessageId: { _, _ in },
                    scrollToMessageIdWithAnchor: { _, _ in },
                    navigateToStory: { _, _ in },
                    attemptedNavigationToPrivateQuote: { _ in },
                    forceUpdateWarpContents: {},
                    playShakeAnimation: {},
                    displayQuickShare: { _, _, _ in },
                    updateChatLocationThread: { _, _ in },
                    requestToggleTodoMessageItem: { _, _, _ in },
                    displayTodoToggleUnavailable: { _ in },
                    openStarsPurchase: { _ in },
                    openRankInfo: { _, _, _ in },
                    openSetPeerAvatar: {},
                    displayPollRestrictedToast: { _ in },
                    automaticMediaDownloadSettings: MediaAutoDownloadSettings.defaultSettings,
                    pollActionState: ChatInterfacePollActionState(),
                    stickerSettings: ChatInterfaceStickerSettings(),
                    presentationContext: ChatPresentationContext(context: component.context, backgroundNode: nil)
                )
                self.controllerInteraction = controllerInteraction
                self.controllerInteractionContext = component.context
            }
            
            let author = TelegramUser(id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(0)), accessHash: nil, firstName: "", lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: .preset(.blue), backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
            let message = EngineRawMessage(
                stableId: 0,
                stableVersion: 0,
                id: EngineMessage.Id(peerId: author.id, namespace: Namespaces.Message.Local, id: 0),
                globallyUniqueId: nil,
                groupingKey: nil,
                groupInfo: nil,
                threadId: nil,
                timestamp: Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970),
                flags: [.Incoming],
                tags: [],
                globalTags: [],
                localTags: [],
                customTags: [],
                forwardInfo: nil,
                author: component.peer?._asPeer() ?? author,
                text: "",
                attributes: [],
                media: [component.webpage],
                peers: EngineSimpleDictionary(),
                associatedMessages: EngineSimpleDictionary(),
                associatedMessageIds: [],
                associatedMedia: [:],
                associatedThreadInfo: nil,
                associatedStories: [:]
            )
            let associatedData = ChatMessageItemAssociatedData(
                automaticDownloadPeerType: .contact,
                automaticDownloadPeerId: nil,
                automaticDownloadNetworkType: .cellular,
                isRecentActions: false,
                subject: nil,
                contactsPeerIds: Set(),
                animatedEmojiStickers: [:],
                forcedResourceStatus: nil,
                availableReactions: nil,
                availableMessageEffects: nil,
                savedMessageTags: nil,
                defaultReaction: nil,
                areStarReactionsEnabled: false,
                isPremium: false,
                accountPeer: nil,
                forceInlineReactions: true,
                isStandalone: true
            )
            let previewContent = makeAlertWebpagePreviewContent(
                context: component.context,
                presentationData: presentationData,
                automaticDownloadSettings: controllerInteraction.automaticMediaDownloadSettings,
                associatedData: associatedData,
                message: message,
                webpage: webpageContent
            )
            
            let constrainedWidth = max(1.0, availableSize.width + 50.0)
            let constrainedSize = CGSize(width: constrainedWidth, height: 10000.0)
            let contentNodeLayout = self.contentNode.asyncLayout()
            let position = ChatMessageBubbleRelativePosition.None(.None(.Incoming))
            
            let (initialWidth, continueLayout) = contentNodeLayout(
                presentationData,
                controllerInteraction.automaticMediaDownloadSettings,
                associatedData,
                ChatMessageEntryAttributes(),
                component.context,
                controllerInteraction,
                message,
                true,
                .peer(id: message.id.peerId),
                previewContent.title,
                nil,
                previewContent.subtitle,
                previewContent.text,
                previewContent.entities,
                previewContent.mediaAndFlags,
                previewContent.mediaBadge,
                nil,
                nil,
                true,
                ChatMessageItemLayoutConstants.compact,
                .linear(top: position, bottom: position),
                constrainedSize,
                controllerInteraction.presentationContext.animationCache,
                controllerInteraction.presentationContext.animationRenderer
            )
            let (refinedWidth, finalizeLayout) = continueLayout(constrainedSize,  .linear(top: position, bottom: position))
            let boundingWidth = min(constrainedWidth, max(initialWidth, refinedWidth))
            let (contentSize, apply) = finalizeLayout(boundingWidth)
            apply(.None, true, nil)
            
            let contentFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - contentSize.width) / 2.0), y: -10.0), size: contentSize)
            transition.setFrame(view: self.contentNode.view, frame: contentFrame)
            self.contentNode.visibility = .visible(1.0, CGRect(origin: CGPoint(), size: contentSize))
            
            return CGSize(width: availableSize.width, height: contentSize.height - 18.0)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private func makeAlertWebpagePreviewContent(
    context: AccountContext,
    presentationData: ChatPresentationData,
    automaticDownloadSettings: MediaAutoDownloadSettings,
    associatedData: ChatMessageItemAssociatedData,
    message: EngineRawMessage,
    webpage: TelegramMediaWebpageLoadedContent
) -> AlertWebpagePreviewContent {
    var result = AlertWebpagePreviewContent()
    let type = websiteType(of: webpage.websiteName)
    
    if let websiteName = webpage.websiteName, !websiteName.isEmpty {
        result.title = websiteName
    }
    
    if let title = webpage.title, !title.isEmpty {
        result.subtitle = NSAttributedString(string: title, font: Font.semibold(15.0))
    }
    
    if let textValue = webpage.text, !textValue.isEmpty {
        result.text = textValue
        var entityTypes: EnabledEntityTypes = [.allUrl]
        switch type {
        case .twitter, .instagram:
            entityTypes.insert(.mention)
            entityTypes.insert(.hashtag)
            entityTypes.insert(.external)
        default:
            break
        }
        result.entities = generateTextEntities(textValue, enabledTypes: entityTypes)
    }
    
    var mainMedia: EngineRawMedia?
    var automaticPlayback = false
    if let file = webpage.file, (file.isAnimated && context.sharedContext.energyUsageSettings.autoplayGif) || (!file.isAnimated && context.sharedContext.energyUsageSettings.autoplayVideo) {
        if shouldDownloadMediaAutomatically(settings: automaticDownloadSettings, peerType: associatedData.automaticDownloadPeerType, networkType: associatedData.automaticDownloadNetworkType, authorPeerId: message.author?.id, contactsPeerIds: associatedData.contactsPeerIds, media: file) {
            automaticPlayback = true
        } else {
            automaticPlayback = context.engine.resources.completedResourcePath(id: EngineMediaResource.Id(file.resource.id)) != nil
        }
    }
    
    switch type {
    case .instagram, .twitter:
        if automaticPlayback {
            mainMedia = webpage.story ?? webpage.file ?? webpage.image
        } else {
            mainMedia = webpage.story ?? webpage.image ?? webpage.file
        }
    default:
        mainMedia = webpage.story ?? webpage.file ?? webpage.image
    }
    
    let themeMimeType = "application/x-tgtheme-ios"
    
    switch webpage.type {
    case "telegram_background":
        var colors: [UInt32] = []
        var rotation: Int32?
        if let wallpaper = parseWallpaperUrl(sharedContext: context.sharedContext, url: webpage.url) {
            if case let .color(color) = wallpaper {
                colors = [color.rgb]
            } else if case let .gradient(colorsValue, rotationValue) = wallpaper {
                colors = colorsValue
                rotation = rotationValue
            }
        }
        
        var content: WallpaperPreviewMediaContent?
        if !colors.isEmpty {
            if colors.count >= 2 {
                content = .gradient(colors, rotation)
            } else {
                content = .color(UIColor(rgb: colors[0]))
            }
        }
        if let content {
            let media = WallpaperPreviewMedia(content: content)
            result.mediaAndFlags = ([media], [])
        }
    case "telegram_theme":
        var file: TelegramMediaFile?
        var settings: TelegramThemeSettings?
        var isSupported = false
        
        for attribute in webpage.attributes {
            if case let .theme(attribute) = attribute {
                if let attributeSettings = attribute.settings {
                    settings = attributeSettings
                    isSupported = true
                } else if let filteredFile = attribute.files.filter({ $0.mimeType == themeMimeType }).first {
                    file = filteredFile
                    isSupported = true
                }
            }
        }
        
        if !isSupported, let contentFile = webpage.file {
            isSupported = true
            file = contentFile
        }
        if let file {
            let media = WallpaperPreviewMedia(content: .file(file: file, colors: [], rotation: nil, intensity: nil, true, isSupported))
            result.mediaAndFlags = ([media], [])
        } else if let settings {
            let media = WallpaperPreviewMedia(content: .themeSettings(settings))
            result.mediaAndFlags = ([media], [])
        }
    case "telegram_nft":
        for attribute in webpage.attributes {
            if case let .starGift(gift) = attribute, case let .unique(uniqueGift) = gift.gift {
                let media = UniqueGiftPreviewMedia(content: uniqueGift)
                result.mediaAndFlags = ([media], [])
                break
            }
        }
    case "telegram_auction":
        for attribute in webpage.attributes {
            if case let .giftAuction(giftAuction) = attribute, case let .generic(gift) = giftAuction.gift {
                let media = GiftAuctionPreviewMedia(content: gift, endTime: giftAuction.endDate)
                result.mediaAndFlags = ([media], [])
                break
            }
        }
    default:
        if var file = mainMedia as? TelegramMediaFile, webpage.type != "telegram_theme" {
            if webpage.imageIsVideoCover, let image = webpage.image {
                file = file.withUpdatedVideoCover(image)
            }
            
            if let embedUrl = webpage.embedUrl, !embedUrl.isEmpty {
                if automaticPlayback {
                    result.mediaAndFlags = ([file], [.preferMediaBeforeText])
                } else {
                    result.mediaAndFlags = ([webpage.image ?? file], [.preferMediaBeforeText])
                }
            } else if webpage.type == "telegram_background" {
                var colors: [UInt32] = []
                var rotation: Int32?
                var intensity: Int32?
                if let wallpaper = parseWallpaperUrl(sharedContext: context.sharedContext, url: webpage.url), case let .slug(_, _, colorsValue, intensityValue, rotationValue) = wallpaper {
                    colors = colorsValue
                    rotation = rotationValue
                    intensity = intensityValue
                }
                let media = WallpaperPreviewMedia(content: .file(file: file, colors: colors, rotation: rotation, intensity: intensity, false, false))
                result.mediaAndFlags = ([media], [.preferMediaAspectFilled])
                if let fileSize = file.size {
                    result.mediaBadge = dataSizeString(fileSize, formatting: DataSizeStringFormatting(chatPresentationData: presentationData))
                }
            } else {
                result.mediaAndFlags = ([file], [])
            }
        } else if let image = mainMedia as? TelegramMediaImage {
            if let type = webpage.type, ["photo", "video", "embed", "gif", "document", "telegram_album"].contains(type) {
                var flags = ChatMessageAttachedContentNodeMediaFlags()
                if webpage.instantPage != nil, let largest = largestImageRepresentation(image.representations) {
                    if largest.dimensions.width >= 256 {
                        flags.insert(.preferMediaBeforeText)
                    }
                } else if let embedUrl = webpage.embedUrl, !embedUrl.isEmpty {
                    flags.insert(.preferMediaBeforeText)
                }
                result.mediaAndFlags = ([image], flags)
            } else if largestImageRepresentation(image.representations)?.dimensions != nil {
                result.mediaAndFlags = ([image], [])
            }
        } else if let story = mainMedia as? TelegramMediaStory {
            result.mediaAndFlags = ([story], [.preferMediaBeforeText, .titleBeforeMedia])
        }
    }
    
    switch webpage.type {
    case "telegram_background":
        result.title = presentationData.strings.Conversation_ChatBackground
        result.subtitle = nil
        result.text = nil
        result.entities = nil
    case "telegram_theme":
        result.title = presentationData.strings.Conversation_Theme
        result.text = nil
        result.entities = nil
    case "telegram_nft", "telegram_auction":
        result.text = nil
        result.entities = nil
    default:
        break
    }
    
    for attribute in webpage.attributes {
        if case let .stickerPack(stickerPack) = attribute, !stickerPack.files.isEmpty {
            result.mediaAndFlags = (stickerPack.files, [.preferMediaInline, .stickerPack])
            break
        } else if case let .giftCollection(giftCollection) = attribute, !giftCollection.files.isEmpty {
            result.mediaAndFlags = (giftCollection.files, [.preferMediaInline, .stickerPack])
            break
        }
    }
    
    if defaultWebpageImageSizeIsSmall(webpage: webpage) {
        result.mediaAndFlags?.1.insert(.preferMediaInline)
    }
    
    if let isMediaLargeByDefault = webpage.isMediaLargeByDefault, !isMediaLargeByDefault {
        result.mediaAndFlags?.1.insert(.preferMediaInline)
    }
    
    return result
}
