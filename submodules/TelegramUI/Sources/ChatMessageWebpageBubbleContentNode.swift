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

private let titleFont: UIFont = Font.semibold(15.0)

final class ChatMessageWebpageBubbleContentNode: ChatMessageBubbleContentNode {
    private var webPage: TelegramMediaWebpage?
    
    private let contentNode: ChatMessageAttachedContentNode
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            self.contentNode.visibility = self.visibility
        }
    }
    
    required init() {
        self.contentNode = ChatMessageAttachedContentNode()
        
        super.init()
        
        self.addSubnode(self.contentNode)
        self.contentNode.openMedia = { [weak self] mode in
            if let strongSelf = self, let item = strongSelf.item {
                if let webPage = strongSelf.webPage, case let .Loaded(content) = webPage.content {
                    if let _ = content.image, let _ = content.instantPage {
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
                    }
                }
                let openChatMessageMode: ChatControllerInteractionOpenMessageMode
                switch mode {
                    case .default:
                        openChatMessageMode = .default
                    case .stream:
                        openChatMessageMode = .stream
                    case .automaticPlayback:
                        openChatMessageMode = .automaticPlayback
                }
                let _ = item.controllerInteraction.openMessage(item.message, openChatMessageMode)
            }
        }
        self.contentNode.activateAction = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                if let adAttribute = item.message.adAttribute {
                    switch adAttribute.target {
                    case let .peer(id, messageId, startParam):
                        let navigationData: ChatControllerInteractionNavigateToPeer
                        if let bot = item.message.author as? TelegramUser, bot.botInfo != nil, let startParam = startParam {
                            navigationData = .withBotStartPayload(ChatControllerInitialBotStart(payload: startParam, behavior: .interactive))
                        } else {
                            var subject: ChatControllerSubject?
                            if let messageId = messageId {
                                subject = .message(id: .id(messageId), highlight: true, timecode: nil)
                            }
                            navigationData = .chat(textInputState: nil, subject: subject, peekData: nil)
                        }
                        item.controllerInteraction.openPeer(id, navigationData, nil, nil)
                    case let .join(_, joinHash):
                        item.controllerInteraction.openJoinLink(joinHash)
                    }
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
                        item.controllerInteraction.openUrl(webpage.url, false, nil, nil)
                    }
                }
            }
        }
        self.contentNode.requestUpdateLayout = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                let _ = item.controllerInteraction.requestMessageUpdate(item.message.id)
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let contentNodeLayout = self.contentNode.asyncLayout()
        
        return { item, layoutConstants, preparePosition, _, constrainedSize in
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
            
            var title: String?
            var subtitle: NSAttributedString?
            var text: String?
            var entities: [MessageTextEntity]?
            var mediaAndFlags: (Media, ChatMessageAttachedContentNodeMediaFlags)?
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
                
                if let file = webpage.file, (file.isAnimated && item.controllerInteraction.automaticMediaDownloadSettings.autoplayGifs) || (!file.isAnimated && item.controllerInteraction.automaticMediaDownloadSettings.autoplayVideos) {
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
                            mainMedia = webpage.file ?? webpage.image
                        } else {
                            mainMedia = webpage.image ?? webpage.file
                        }
                    default:
                        mainMedia = webpage.file ?? webpage.image
                }
                
                let themeMimeType = "application/x-tgtheme-ios"
                
                if let file = mainMedia as? TelegramMediaFile, webpage.type != "telegram_theme" {
                    if let embedUrl = webpage.embedUrl, !embedUrl.isEmpty {
                        if automaticPlayback {
                            mediaAndFlags = (file, [.preferMediaBeforeText])
                        } else {
                            mediaAndFlags = (webpage.image ?? file, [.preferMediaBeforeText])
                        }
                    } else if webpage.type == "telegram_background" {
                        var colors: [UInt32] = []
                        var rotation: Int32?
                        var intensity: Int32?
                        if let wallpaper = parseWallpaperUrl(webpage.url), case let .slug(_, _, colorsValue, intensityValue, rotationValue) = wallpaper {
                            colors = colorsValue
                            rotation = rotationValue
                            intensity = intensityValue
                        }
                        let media = WallpaperPreviewMedia(content: .file(file: file, colors: colors, rotation: rotation, intensity: intensity, false, false))
                        mediaAndFlags = (media, [.preferMediaAspectFilled])
                        if let fileSize = file.size {
                            badge = dataSizeString(fileSize, formatting: DataSizeStringFormatting(chatPresentationData: item.presentationData))
                        }
                    } else {
                        mediaAndFlags = (file, [])
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
                        mediaAndFlags = (image, flags)
                    } else if let _ = largestImageRepresentation(image.representations)?.dimensions {
                        var flags = ChatMessageAttachedContentNodeMediaFlags()
                        if webpage.instantPage == nil {
                            flags.insert(.preferMediaInline)
                        }
                        mediaAndFlags = (image, flags)
                    }
                } else if let type = webpage.type {
                    if type == "telegram_background" {
                        var colors: [UInt32] = []
                        var rotation: Int32?
                        if let wallpaper = parseWallpaperUrl(webpage.url) {
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
                            mediaAndFlags = (media, [])
                        }
                    } else if type == "telegram_theme" {
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
                            mediaAndFlags = (media, ChatMessageAttachedContentNodeMediaFlags())
                        } else if let settings = settings {
                            let media = WallpaperPreviewMedia(content: .themeSettings(settings))
                            mediaAndFlags = (media, ChatMessageAttachedContentNodeMediaFlags())
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
                            actionTitle = item.presentationData.strings.Conversation_UserSendMessage
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
                        default:
                            break
                    }
                }
            } else if let adAttribute = item.message.adAttribute {
                title = nil
                subtitle = nil
                text = item.message.text
                for attribute in item.message.attributes {
                    if let attribute = attribute as? TextEntitiesMessageAttribute {
                        entities = attribute.entities
                    }
                }
                for media in item.message.media {
                    switch media {
                    case _ as TelegramMediaImage, _ as TelegramMediaFile:
                        mediaAndFlags = (media, ChatMessageAttachedContentNodeMediaFlags())
                    default:
                        break
                    }
                }

                if let author = item.message.author as? TelegramUser, author.botInfo != nil {
                    actionTitle = item.presentationData.strings.Conversation_ViewBot
                } else if let author = item.message.author as? TelegramChannel, case .group = author.info {
                    if case let .peer(_, messageId, _) = adAttribute.target, messageId != nil {
                        actionTitle = item.presentationData.strings.Conversation_ViewPost
                    } else {
                        actionTitle = item.presentationData.strings.Conversation_ViewGroup
                    }
                } else {
                    if case let .peer(_, messageId, _) = adAttribute.target, messageId != nil {
                        actionTitle = item.presentationData.strings.Conversation_ViewMessage
                    } else {
                        actionTitle = item.presentationData.strings.Conversation_ViewChannel
                    }
                }
                displayLine = false
            }
            
            let (initialWidth, continueLayout) = contentNodeLayout(item.presentationData, item.controllerInteraction.automaticMediaDownloadSettings, item.associatedData, item.attributes, item.context, item.controllerInteraction, item.message, item.read, item.chatLocation, title, subtitle, text, entities, mediaAndFlags, badge, actionIcon, actionTitle, displayLine, layoutConstants, preparePosition, constrainedSize)
            
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 8.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, initialWidth, { constrainedSize, position in
                let (refinedWidth, finalizeLayout) = continueLayout(constrainedSize, position)
                
                return (refinedWidth, { boundingWidth in
                    let (size, apply) = finalizeLayout(boundingWidth)
                    
                    return (size, { [weak self] animation, synchronousLoads, applyInfo in
                        if let strongSelf = self {
                            strongSelf.item = item
                            strongSelf.webPage = webPage
                            
                            apply(animation, synchronousLoads, applyInfo)
                            
                            strongSelf.contentNode.frame = CGRect(origin: CGPoint(), size: size)
                        }
                    })
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
    }
    
    override func animateInsertionIntoBubble(_ duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func playMediaWithSound() -> ((Double?) -> Void, Bool, Bool, Bool, ASDisplayNode?)? {
        return self.contentNode.playMediaWithSound()
    }
    
    override func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        guard let item = self.item else {
            return .none
        }
        if self.bounds.contains(point) {
            let contentNodeFrame = self.contentNode.frame
            let result = self.contentNode.tapActionAtPoint(point.offsetBy(dx: -contentNodeFrame.minX, dy: -contentNodeFrame.minY), gesture: gesture, isEstimating: isEstimating)

            if item.message.adAttribute != nil {
                if case .none = result {
                    if self.contentNode.hasActionAtPoint(point.offsetBy(dx: -contentNodeFrame.minX, dy: -contentNodeFrame.minY)) {
                        return .ignore
                    }
                }
                return result
            }

            switch result {
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
                                return .url(url: "https://twitter.com/\(mention)", concealed: false)
                            case .instagram:
                                return .url(url: "https://instagram.com/\(mention)", concealed: false)
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
                                return .url(url: "https://twitter.com/hashtag/\(hashtag)", concealed: false)
                            case .instagram:
                                return .url(url: "https://instagram.com/explore/tags/\(hashtag)", concealed: false)
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
                            return .none
                        default:
                            return .instantPage
                    }
                } else if content.type == "telegram_background" {
                    return .wallpaper
                } else if content.type == "telegram_theme" {
                    return .theme
                }
            }
            if self.contentNode.hasActionAtPoint(point.offsetBy(dx: -contentNodeFrame.minX, dy: -contentNodeFrame.minY)) {
                return .ignore
            }
            return .none
        }
        return .none
    }
    
    override func updateHiddenMedia(_ media: [Media]?) -> Bool {
        if let media = media {
            var updatedMedia = media
            if let current = self.webPage, case let .Loaded(content) = current.content {
                for item in media {
                    if let webpage = item as? TelegramMediaWebpage, webpage.id == current.id {
                        var mediaList: [Media] = [webpage]
                        if let image = content.image {
                            mediaList.append(image)
                        }
                        if let file = content.file {
                            mediaList.append(file)
                        }
                        updatedMedia = mediaList
                    } else if let id = item.id, content.file?.id == id || content.image?.id == id {
                        var mediaList: [Media] = [current]
                        if let image = content.image {
                            mediaList.append(image)
                        }
                        if let file = content.file {
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
    
    override func transitionNode(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
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
    
    override func updateTouchesAtPoint(_ point: CGPoint?) {
        let contentNodeFrame = self.contentNode.frame
        self.contentNode.updateTouchesAtPoint(point.flatMap { $0.offsetBy(dx: -contentNodeFrame.minX, dy: -contentNodeFrame.minY) })
    }
    
    override func reactionTargetView(value: String) -> UIView? {
        return self.contentNode.reactionTargetView(value: value)
    }
}
