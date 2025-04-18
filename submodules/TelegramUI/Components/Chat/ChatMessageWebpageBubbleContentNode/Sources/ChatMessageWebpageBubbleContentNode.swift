import Foundation
import UIKit
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import TextFormat
import AccountContext
import WebsiteType
import InstantPageUI
import UrlHandling
import GalleryData
import TelegramPresentationData
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import WallpaperPreviewMedia
import ChatMessageInteractiveMediaNode
import ChatMessageAttachedContentNode
import ChatControllerInteraction

private let titleFont: UIFont = Font.semibold(15.0)

public final class ChatMessageWebpageBubbleContentNode: ChatMessageBubbleContentNode {
    private var webPage: TelegramMediaWebpage?
    
    public private(set) var contentNode: ChatMessageAttachedContentNode
    
    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            self.contentNode.visibility = self.visibility
        }
    }
    
    required public init() {
        self.contentNode = ChatMessageAttachedContentNode()
        
        super.init()
        
        self.addSubnode(self.contentNode)
        self.contentNode.openMedia = { [weak self] mode in
            if let strongSelf = self, let item = strongSelf.item {
                if let webPage = strongSelf.webPage, case let .Loaded(content) = webPage.content {
                    if let _ = content.instantPage {
                        if instantPageType(of: content) != .album {
                            item.controllerInteraction.openInstantPage(item.message, item.associatedData)
                            return
                        }
                    } else if content.type == "telegram_background" {
                        item.controllerInteraction.openWallpaper(item.message)
                        return
                    } else if content.type == "telegram_theme" {
                        item.controllerInteraction.openTheme(item.message)
                        return
                    } else {
                        if content.embedUrl == nil && (content.title != nil || content.text != nil) && content.story == nil {
                            var shouldOpenUrl = true
                            if let file = content.file {
                                if file.isVideo {
                                    shouldOpenUrl = false
                                } else if !file.isVideoSticker, !file.isAnimated, !file.isAnimatedSticker, !file.isSticker, !file.isMusic {
                                    shouldOpenUrl = false
                                } else if file.isMusic || file.isVoice {
                                    shouldOpenUrl = false
                                }
                            }
                            
                            if shouldOpenUrl {
                                var isConcealed = true
                                if item.message.text.contains(content.url) {
                                    isConcealed = false
                                }
                                if let attribute = item.message.webpagePreviewAttribute {
                                    if attribute.isSafe {
                                        isConcealed = false
                                    }
                                }
                                item.controllerInteraction.openUrl(ChatControllerInteraction.OpenUrl(url: content.url, concealed: isConcealed, progress: strongSelf.contentNode.makeProgress()))
                                return
                            }
                        }
                    }
                }
                var openChatMessageMode: ChatControllerInteractionOpenMessageMode
                switch mode {
                    case .default:
                        openChatMessageMode = .default
                    case .stream:
                        openChatMessageMode = .stream
                    case .automaticPlayback:
                        openChatMessageMode = .automaticPlayback
                }
                if let adAttribute = item.message.adAttribute, adAttribute.hasContentMedia {
                    openChatMessageMode = .automaticPlayback
                }
                if !item.controllerInteraction.openMessage(item.message, OpenMessageParams(mode: openChatMessageMode)) {
                    if let webPage = strongSelf.webPage, case let .Loaded(content) = webPage.content {
                        var isConcealed = true
                        if item.message.text.contains(content.url) {
                            isConcealed = false
                        }
                        if let attribute = item.message.webpagePreviewAttribute {
                            if attribute.isSafe {
                                isConcealed = false
                            }
                        }
                        item.controllerInteraction.openUrl(ChatControllerInteraction.OpenUrl(url: content.url, concealed: isConcealed, progress: strongSelf.contentNode.makeProgress()))
                    }
                }
            }
        }
        self.contentNode.activateBadgeAction = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                item.controllerInteraction.openAdsInfo()
            }
        }
        self.contentNode.activateAction = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                if let _ = item.message.adAttribute {
                    item.controllerInteraction.activateAdAction(item.message.id, strongSelf.contentNode.makeProgress(), false, false)
                } else {
                    var webPageContent: TelegramMediaWebpageLoadedContent?
                    for media in item.message.media {
                        if let media = media as? TelegramMediaWebpage {
                            if case let .Loaded(content) = media.content {
                                webPageContent = content
                            }
                            break
                        }
                    }
                    if let webpage = webPageContent {
                        if webpage.story != nil {
                            let _ = item.controllerInteraction.openMessage(item.message, OpenMessageParams(mode: .default))
                        } else if webpage.instantPage != nil {
                            strongSelf.contentNode.openMedia?(.default)
                        } else {
                            var isConcealed = true
                            if item.message.text.contains(webpage.url) {
                                isConcealed = false
                            }
                            if let attribute = item.message.webpagePreviewAttribute {
                                if attribute.isSafe {
                                    isConcealed = false
                                }
                            }
                            item.controllerInteraction.openUrl(ChatControllerInteraction.OpenUrl(url: webpage.url, concealed: isConcealed, progress: strongSelf.contentNode.makeProgress()))
                        }
                    }
                }
            }
        }
        self.contentNode.requestUpdateLayout = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                let _ = item.controllerInteraction.requestMessageUpdate(item.message.id, false)
            }
        }
        self.contentNode.defaultContentAction = { [weak self] in
            guard let self, let item = self.item, let webPage = self.webPage, case let .Loaded(content) = webPage.content else {
                return ChatMessageBubbleContentTapAction(content: .none)
            }
            
            if let file = content.file {
                if !file.isVideo, !file.isVideoSticker, !file.isAnimated, !file.isAnimatedSticker, !file.isSticker, !file.isMusic {
                    return ChatMessageBubbleContentTapAction(content: .openMessage)
                }
            }
            
            var isConcealed = true
            if item.message.text.contains(content.url) {
                isConcealed = false
            }
            if let attribute = item.message.webpagePreviewAttribute {
                if attribute.isSafe {
                    isConcealed = false
                }
            }
            return ChatMessageBubbleContentTapAction(content: .url(ChatMessageBubbleContentTapAction.Url(url: content.url, concealed: isConcealed, allowInlineWebpageResolution: true)), hasLongTapAction: false, activate: { [weak self] in
                guard let self else {
                    return nil
                }
                return self.contentNode.makeProgress()
            })
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let currentWebpage = self.webPage
        let currentContentNodeLayout = self.contentNode.asyncLayout()
        
        return { item, layoutConstants, preparePosition, _, constrainedSize, _ in
            var webPage: TelegramMediaWebpage?
            var webPageContent: TelegramMediaWebpageLoadedContent?
            for media in item.message.media {
                if let media = media as? TelegramMediaWebpage {
                    webPage = media
                    if case let .Loaded(content) = media.content {
                        webPageContent = content
                    }
                    break
                }
            }
            
            var updatedContentNode: ChatMessageAttachedContentNode?
            let contentNodeLayout: ChatMessageAttachedContentNode.AsyncLayout
            if currentWebpage == nil || currentWebpage?.webpageId == webPage?.id {
                contentNodeLayout = currentContentNodeLayout
            } else {
                let updatedContentNodeValue = ChatMessageAttachedContentNode()
                updatedContentNode = updatedContentNodeValue
                contentNodeLayout = updatedContentNodeValue.asyncLayout()
            }
            
            var title: String?
            var subtitle: NSAttributedString?
            var text: String?
            var entities: [MessageTextEntity]?
            var titleBadge: String?
            var mediaAndFlags: ([Media], ChatMessageAttachedContentNodeMediaFlags)?
            var badge: String?
            
            var actionIcon: ChatMessageAttachedContentActionIcon?
            var actionTitle: String?

            var displayLine: Bool = true
            
            if let webpage = webPageContent {
                let type = websiteType(of: webpage.websiteName)
                
                if let websiteName = webpage.websiteName, !websiteName.isEmpty {
                    title = websiteName
                }
                
                if let title = webpage.title, !title.isEmpty {
                    subtitle = NSAttributedString(string: title, font: titleFont)
                }
                
                if let textValue = webpage.text, !textValue.isEmpty {
                    text = textValue
                    var entityTypes: EnabledEntityTypes = [.allUrl]
                    switch type {
                        case .twitter, .instagram:
                            entityTypes.insert(.mention)
                            entityTypes.insert(.hashtag)
                            entityTypes.insert(.external)
                        default:
                            break
                    }
                    entities = generateTextEntities(textValue, enabledTypes: entityTypes)
                }
                
                var mainMedia: Media?

                var automaticPlayback = false
                
                if let file = webpage.file, (file.isAnimated && item.context.sharedContext.energyUsageSettings.autoplayGif) || (!file.isAnimated && item.context.sharedContext.energyUsageSettings.autoplayVideo) {
                    var automaticDownload: InteractiveMediaNodeAutodownloadMode = .none
                    if shouldDownloadMediaAutomatically(settings: item.controllerInteraction.automaticMediaDownloadSettings, peerType: item.associatedData.automaticDownloadPeerType, networkType: item.associatedData.automaticDownloadNetworkType, authorPeerId: item.message.author?.id, contactsPeerIds: item.associatedData.contactsPeerIds, media: file) {
                        automaticDownload = .full
                    }
                    if case .full = automaticDownload {
                        automaticPlayback = true
                    } else {
                        automaticPlayback = item.context.account.postbox.mediaBox.completedResourcePath(file.resource) != nil
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
                    if let wallpaper = parseWallpaperUrl(sharedContext: item.context.sharedContext, url: webpage.url) {
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
                    if let content = content {
                        let media = WallpaperPreviewMedia(content: content)
                        mediaAndFlags = ([media], [])
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
                    if let file = file {
                        let media = WallpaperPreviewMedia(content: .file(file: file, colors: [],  rotation: nil, intensity: nil, true, isSupported))
                        mediaAndFlags = ([media], ChatMessageAttachedContentNodeMediaFlags())
                    } else if let settings = settings {
                        let media = WallpaperPreviewMedia(content: .themeSettings(settings))
                        mediaAndFlags = ([media], ChatMessageAttachedContentNodeMediaFlags())
                    }
                case "telegram_nft":
                    for attribute in webpage.attributes {
                        if case let .starGift(gift) = attribute, case let .unique(uniqueGift) = gift.gift {
                            let media = UniqueGiftPreviewMedia(content: uniqueGift)
                            mediaAndFlags = ([media], [])
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
                                mediaAndFlags = ([file], [.preferMediaBeforeText])
                            } else {
                                mediaAndFlags = ([webpage.image ?? file], [.preferMediaBeforeText])
                            }
                        } else if webpage.type == "telegram_background" {
                            var colors: [UInt32] = []
                            var rotation: Int32?
                            var intensity: Int32?
                            if let wallpaper = parseWallpaperUrl(sharedContext: item.context.sharedContext, url: webpage.url), case let .slug(_, _, colorsValue, intensityValue, rotationValue) = wallpaper {
                                colors = colorsValue
                                rotation = rotationValue
                                intensity = intensityValue
                            }
                            let media = WallpaperPreviewMedia(content: .file(file: file, colors: colors, rotation: rotation, intensity: intensity, false, false))
                            mediaAndFlags = ([media], [.preferMediaAspectFilled])
                            if let fileSize = file.size {
                                badge = dataSizeString(fileSize, formatting: DataSizeStringFormatting(chatPresentationData: item.presentationData))
                            }
                        } else {
                            mediaAndFlags = ([file], [])
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
                            mediaAndFlags = ([image], flags)
                        } else if let _ = largestImageRepresentation(image.representations)?.dimensions {
                            let flags = ChatMessageAttachedContentNodeMediaFlags()
                            mediaAndFlags = ([image], flags)
                        }
                    } else if let story = mainMedia as? TelegramMediaStory {
                        mediaAndFlags = ([story], [.preferMediaBeforeText, .titleBeforeMedia])
                        if let storyItem = item.message.associatedStories[story.storyId]?.get(Stories.StoredItem.self), case let .item(itemValue) = storyItem {
                            text = itemValue.text
                            entities = itemValue.entities
                        }
                    }
                }
                
                if let _ = webpage.instantPage {
                    switch instantPageType(of: webpage) {
                        case .generic:
                            actionIcon = .instant
                            actionTitle = item.presentationData.strings.Conversation_InstantPagePreview
                        default:
                            break
                    }
                } else if let type = webpage.type {
                    switch type {
                        case "photo":
                            if webpage.displayUrl.hasPrefix("t.me/") {
                                actionTitle = item.presentationData.strings.Conversation_ViewMessage
                            }
                        case "telegram_user":
                            if webpage.displayUrl.contains("?profile") {
                                actionTitle = item.presentationData.strings.Conversation_OpenProfile
                            } else {
                                actionTitle = item.presentationData.strings.Conversation_UserSendMessage
                            }
                        case "telegram_channel_request":
                            actionTitle = item.presentationData.strings.Conversation_RequestToJoinChannel
                        case "telegram_chat_request", "telegram_megagroup_request":
                            actionTitle = item.presentationData.strings.Conversation_RequestToJoinGroup
                        case "telegram_channel":
                            actionTitle = item.presentationData.strings.Conversation_ViewChannel
                        case "telegram_chat", "telegram_megagroup":
                            actionTitle = item.presentationData.strings.Conversation_ViewGroup
                        case "telegram_message":
                            actionTitle = item.presentationData.strings.Conversation_ViewMessage
                        case "telegram_voicechat", "telegram_videochat", "telegram_livestream":
                            if type == "telegram_livestream" {
                                title = item.presentationData.strings.Conversation_LiveStream
                            } else {
                                title = item.presentationData.strings.Conversation_VoiceChat
                            }
                            if webpage.url.contains("voicechat=") || webpage.url.contains("videochat=") || webpage.url.contains("livestream=") {
                                actionTitle = item.presentationData.strings.Conversation_JoinVoiceChatAsSpeaker
                            } else {
                                actionTitle = item.presentationData.strings.Conversation_JoinVoiceChatAsListener
                            }
                        case "telegram_background":
                            title = item.presentationData.strings.Conversation_ChatBackground
                            subtitle = nil
                            text = nil
                            actionTitle = item.presentationData.strings.Conversation_ViewBackground
                        case "telegram_theme":
                            title = item.presentationData.strings.Conversation_Theme
                            text = nil
                            actionTitle = item.presentationData.strings.Conversation_ViewTheme
                        case "telegram_botapp":
                            title = item.presentationData.strings.Conversation_BotApp
                            actionTitle = item.presentationData.strings.Conversation_OpenBotApp
                        case "telegram_chatlist":
                            actionTitle = item.presentationData.strings.Conversation_OpenChatFolder
                        case "telegram_story":
                            if let story = webpage.story, let peer = item.message.peers[story.storyId.peerId] {
                                title = EnginePeer(peer).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                                subtitle = nil
                            }
                            actionTitle = item.presentationData.strings.Chat_OpenStory
                        case "telegram_channel_boost":
                            actionTitle = item.presentationData.strings.Conversation_BoostChannel
                        case "telegram_group_boost":
                            actionTitle = item.presentationData.strings.Conversation_BoostChannel
                        case "telegram_stickerset":
                            var isEmoji = false
                            for attribute in webpage.attributes {
                                if case let .stickerPack(stickerPack) = attribute {
                                    isEmoji = stickerPack.flags.contains(.isEmoji)
                                    break
                                }
                            }
                            actionTitle = isEmoji ? item.presentationData.strings.Conversation_ViewEmojis : item.presentationData.strings.Conversation_ViewStickers
                        case "telegram_nft":
                            actionTitle = item.presentationData.strings.Conversation_ViewStarGift
                            text = nil
                            entities = nil
                        default:
                            break
                    }
                }
                for attribute in webpage.attributes {
                    if case let .stickerPack(stickerPack) = attribute, !stickerPack.files.isEmpty {
                        mediaAndFlags = (stickerPack.files, [.preferMediaInline, .stickerPack])
                        break
                    }
                }
                
                if defaultWebpageImageSizeIsSmall(webpage: webpage) {
                    mediaAndFlags?.1.insert(.preferMediaInline)
                }
                
                if let webPageContent, let isMediaLargeByDefault = webPageContent.isMediaLargeByDefault, !isMediaLargeByDefault {
                    mediaAndFlags?.1.insert(.preferMediaInline)
                } else if let attribute = item.message.attributes.first(where: { $0 is WebpagePreviewMessageAttribute }) as? WebpagePreviewMessageAttribute {
                    if let forceLargeMedia = attribute.forceLargeMedia {
                        if forceLargeMedia {
                            mediaAndFlags?.1.remove(.preferMediaInline)
                        } else {
                            mediaAndFlags?.1.insert(.preferMediaInline)
                        }
                    }
                }
            } else if let adAttribute = item.message.adAttribute {
                switch adAttribute.messageType {
                case .sponsored:
                    title = item.presentationData.strings.Message_AdSponsoredLabel
                case .recommended:
                    title = item.presentationData.strings.Message_AdRecommendedLabel
                }
                subtitle = item.message.author.flatMap {
                    NSAttributedString(string: EnginePeer($0).compactDisplayTitle, font: titleFont)
                }
                text = item.message.text
                for attribute in item.message.attributes {
                    if let attribute = attribute as? TextEntitiesMessageAttribute {
                        entities = attribute.entities
                    }
                }
                for media in item.message.media {
                    switch media {
                    case _ as TelegramMediaImage, _ as TelegramMediaFile, _ as TelegramMediaStory:
                        mediaAndFlags = ([media], [.preferMediaInline])
                    default:
                        break
                    }
                }

                if adAttribute.canReport {
                    titleBadge = item.presentationData.strings.Message_AdWhatIsThis
                }
                
                actionTitle = adAttribute.buttonText.uppercased()
                if !isTelegramMeLink(adAttribute.url) {
                    actionIcon = .link
                }
                displayLine = true
            }
            
            let (initialWidth, continueLayout) = contentNodeLayout(item.presentationData, item.controllerInteraction.automaticMediaDownloadSettings, item.associatedData, item.attributes, item.context, item.controllerInteraction, item.message, item.read, item.chatLocation, title, titleBadge, subtitle, text, entities, mediaAndFlags, badge, actionIcon, actionTitle, displayLine, layoutConstants, preparePosition, constrainedSize, item.controllerInteraction.presentationContext.animationCache, item.controllerInteraction.presentationContext.animationRenderer)
            
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 8.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, initialWidth, { constrainedSize, position in
                let (refinedWidth, finalizeLayout) = continueLayout(constrainedSize, position)
                
                return (refinedWidth, { boundingWidth in
                    let (size, apply) = finalizeLayout(boundingWidth)
                    
                    return (size, { [weak self] animation, synchronousLoads, applyInfo in
                        guard let self else {
                            return
                        }
                        self.item = item
                        self.webPage = webPage
                        
                        if let updatedContentNode {
                            let previousPosition = self.contentNode.position
                            let updatedPosition = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                            
                            do {
                                //animation.animator.updateScale(layer: self.contentNode.layer, scale: 0.9, completion: nil)
                                animation.animator.updatePosition(layer: self.contentNode.layer, position: updatedPosition, completion: nil)
                                animation.animator.updateAlpha(layer: self.contentNode.layer, alpha: 0.0, completion: { [weak contentNode] _ in
                                    contentNode?.removeFromSupernode()
                                })
                            }
                            
                            self.contentNode = updatedContentNode
                            self.addSubnode(updatedContentNode)
                            
                            do {
                                apply(.None, synchronousLoads, applyInfo)
                                self.contentNode.frame = size.centered(around: previousPosition)
                                
                                //animation.animator.animateScale(layer: self.contentNode.layer, from: 0.9, to: 1.0, completion: nil)
                                self.contentNode.alpha = 0.0
                                animation.animator.updateAlpha(layer: self.contentNode.layer, alpha: 1.0, completion: nil)
                                animation.animator.updatePosition(layer: self.contentNode.layer, position: updatedPosition, completion: nil)
                            }
                        } else {
                            self.contentNode.frame = CGRect(origin: CGPoint(), size: size)
                            apply(animation, synchronousLoads, applyInfo)
                        }
                    })
                })
            })
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
    }
    
    override public func animateInsertionIntoBubble(_ duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override public func playMediaWithSound() -> ((Double?) -> Void, Bool, Bool, Bool, ASDisplayNode?)? {
        return self.contentNode.playMediaWithSound()
    }
    
    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        guard let item = self.item else {
            return ChatMessageBubbleContentTapAction(content: .none)
        }
        if self.bounds.contains(point) {
            let contentNodeFrame = self.contentNode.frame
            let result = self.contentNode.tapActionAtPoint(point.offsetBy(dx: -contentNodeFrame.minX, dy: -contentNodeFrame.minY), gesture: gesture, isEstimating: isEstimating)

            if item.message.adAttribute != nil {
                if case .none = result.content {
                    if self.contentNode.hasActionAtPoint(point.offsetBy(dx: -contentNodeFrame.minX, dy: -contentNodeFrame.minY)) {
                        return ChatMessageBubbleContentTapAction(content: .ignore)
                    }
                }
                return result
            }

            switch result.content {
                case .none:
                    break
                case let .textMention(value):
                    if let webPage = self.webPage, case let .Loaded(content) = webPage.content {
                        var mention = value
                        if mention.hasPrefix("@") {
                            mention = String(mention[mention.index(after: mention.startIndex)...])
                        }
                        switch websiteType(of: content.websiteName) {
                            case .twitter:
                                return ChatMessageBubbleContentTapAction(content: .url(ChatMessageBubbleContentTapAction.Url(url: "https://twitter.com/\(mention)", concealed: false)))
                            case .instagram:
                                return ChatMessageBubbleContentTapAction(content: .url(ChatMessageBubbleContentTapAction.Url(url: "https://instagram.com/\(mention)", concealed: false)))
                            default:
                                break
                        }
                    }
                case let .hashtag(_, value):
                    if let webPage = self.webPage, case let .Loaded(content) = webPage.content {
                        var hashtag = value
                        if hashtag.hasPrefix("#") {
                            hashtag = String(hashtag[hashtag.index(after: hashtag.startIndex)...])
                        }
                        switch websiteType(of: content.websiteName) {
                            case .twitter:
                                return ChatMessageBubbleContentTapAction(content: .url(ChatMessageBubbleContentTapAction.Url(url: "https://twitter.com/hashtag/\(hashtag)", concealed: false)))
                            case .instagram:
                                return ChatMessageBubbleContentTapAction(content: .url(ChatMessageBubbleContentTapAction.Url(url: "https://instagram.com/explore/tags/\(hashtag)", concealed: false)))
                            default:
                                break
                        }
                    }
                default:
                    return result
            }
            
            if let webPage = self.webPage, case let .Loaded(content) = webPage.content {
                if content.instantPage != nil {
                    switch websiteType(of: content.websiteName) {
                        case .instagram, .twitter:
                            return ChatMessageBubbleContentTapAction(content: .none)
                        default:
                            return ChatMessageBubbleContentTapAction(content: .instantPage)
                    }
                } else if content.type == "telegram_background" {
                    return ChatMessageBubbleContentTapAction(content: .wallpaper)
                } else if content.type == "telegram_theme" {
                    return ChatMessageBubbleContentTapAction(content: .theme)
                }
            }
            if self.contentNode.hasActionAtPoint(point.offsetBy(dx: -contentNodeFrame.minX, dy: -contentNodeFrame.minY)) {
                return ChatMessageBubbleContentTapAction(content: .ignore)
            }
            return ChatMessageBubbleContentTapAction(content: .none)
        }
        return ChatMessageBubbleContentTapAction(content: .none)
    }
    
    override public func updateHiddenMedia(_ media: [Media]?) -> Bool {
        if let media = media {
            var updatedMedia = media
            if let current = self.webPage, case let .Loaded(content) = current.content {
                for item in media {
                    if let webpage = item as? TelegramMediaWebpage, webpage.id == current.id {
                        var mediaList: [Media] = [webpage]
                        if let image = content.image {
                            mediaList.append(image)
                        }
                        if var file = content.file {
                            if content.imageIsVideoCover, let image = content.image {
                                file = file.withUpdatedVideoCover(image)
                            }
                            mediaList.append(file)
                        }
                        updatedMedia = mediaList
                    } else if let id = item.id, content.file?.id == id || content.image?.id == id {
                        var mediaList: [Media] = [current]
                        if let image = content.image {
                            mediaList.append(image)
                        }
                        if var file = content.file {
                            if content.imageIsVideoCover, let image = content.image {
                                file = file.withUpdatedVideoCover(image)
                            }
                            mediaList.append(file)
                        }
                        updatedMedia = mediaList
                    }
                }
            }
            return self.contentNode.updateHiddenMedia(updatedMedia)
        } else {
            return self.contentNode.updateHiddenMedia(nil)
        }
    }
    
    override public func transitionNode(messageId: MessageId, media: Media, adjustRect: Bool) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if self.item?.message.id != messageId {
            return nil
        }
        
        if let result = self.contentNode.transitionNode(media: media) {
            return result
        }
        if let current = self.webPage, case let .Loaded(content) = current.content {
            if let webpage = media as? TelegramMediaWebpage, webpage.id == current.id {
                if let image = content.image, let result = self.contentNode.transitionNode(media: image) {
                    return result
                }
                if let file = content.file, let result = self.contentNode.transitionNode(media: file) {
                    return result
                }
            } else if let id = media.id, id == content.file?.id || id == content.image?.id {
                if let image = content.image, let result = self.contentNode.transitionNode(media: image) {
                    return result
                }
                if let file = content.file, let result = self.contentNode.transitionNode(media: file) {
                    return result
                }
            }
        }
        return nil
    }
    
    override public func updateTouchesAtPoint(_ point: CGPoint?) {
        let contentNodeFrame = self.contentNode.frame
        self.contentNode.updateTouchesAtPoint(point.flatMap { $0.offsetBy(dx: -contentNodeFrame.minX, dy: -contentNodeFrame.minY) })
    }
    
    override public func reactionTargetView(value: MessageReaction.Reaction) -> UIView? {
        return self.contentNode.reactionTargetView(value: value)
    }
    
    override public func messageEffectTargetView() -> UIView? {
        return self.contentNode.messageEffectTargetView()
    }
}
