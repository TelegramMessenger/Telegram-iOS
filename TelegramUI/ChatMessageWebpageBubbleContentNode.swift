import Foundation
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore

enum WebsiteType {
    case generic
    case twitter
    case instagram
}

func websiteType(of webpage: TelegramMediaWebpageLoadedContent) -> WebsiteType {
    if let websiteName = webpage.websiteName?.lowercased() {
        if websiteName == "twitter" {
            return .twitter
        } else if websiteName == "instagram" {
            return .instagram
        }
    }
    return .generic
}

func instantPageGalleryMedia(webpageId: MediaId, page: InstantPage, galleryMedia: Media) -> [InstantPageGalleryEntry] {
    var result: [InstantPageGalleryEntry] = []
    var counter: Int = 0
    
    for block in page.blocks {
        result.append(contentsOf: instantPageBlockMedia(pageId: webpageId, block: block, media: page.media, counter: &counter))
    }
    
    var found = false
    for item in result {
        if item.media.media.id == galleryMedia.id {
            found = true
            break
        }
    }
    
    if !found {
        result.insert(InstantPageGalleryEntry(index: Int32(counter), pageId: webpageId, media: InstantPageMedia(index: counter, media: galleryMedia, caption: ""), caption: "", location: InstantPageGalleryEntryLocation(position: Int32(counter), totalCount: 0)), at: 0)
    }
    
    for i in 0 ..< result.count {
        let item = result[i]
        result[i] = InstantPageGalleryEntry(index: Int32(i), pageId: item.pageId, media: item.media, caption: item.caption, location: InstantPageGalleryEntryLocation(position: Int32(i), totalCount: Int32(result.count)))
    }
    return result
}

private func instantPageBlockMedia(pageId: MediaId, block: InstantPageBlock, media: [MediaId: Media], counter: inout Int) -> [InstantPageGalleryEntry] {
    switch block {
        case let .image(id, caption):
            if let m = media[id] {
                let captionText = caption.plainText
                let result = [InstantPageGalleryEntry(index: Int32(counter), pageId: pageId, media: InstantPageMedia(index: counter, media: m, caption: captionText), caption: captionText, location: InstantPageGalleryEntryLocation(position: Int32(counter), totalCount: 0))]
                counter += 1
                return result
            }
        case let .video(id, caption, _, loop):
            if let m = media[id] {
                let captionText = caption.plainText
                let result = [InstantPageGalleryEntry(index: Int32(counter), pageId: pageId, media: InstantPageMedia(index: counter, media: m, caption: captionText), caption: captionText, location: InstantPageGalleryEntryLocation(position: Int32(counter), totalCount: 0))]
                counter += 1
                return result
            }
        case let .collage(items, _):
            var result: [InstantPageGalleryEntry] = []
            for item in items {
                result.append(contentsOf: instantPageBlockMedia(pageId: pageId, block: item, media: media, counter: &counter))
            }
            return result
        case let .slideshow(items, _):
            var result: [InstantPageGalleryEntry] = []
            for item in items {
                result.append(contentsOf: instantPageBlockMedia(pageId: pageId, block: item, media: media, counter: &counter))
            }
            return result
        default:
            break
    }
    return []
}

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
        self.contentNode.openMedia = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                item.controllerInteraction.openMessage(item.message)
            }
        }
        self.contentNode.activateAction = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
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
                    item.controllerInteraction.openUrl(webpage.url)
                }
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))) {
        let contentNodeLayout = self.contentNode.asyncLayout()
        
        return { item, layoutConstants, _, _, constrainedSize in
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
            var subtitle: String?
            var text: String?
            var entities: [MessageTextEntity]?
            var mediaAndFlags: (Media, ChatMessageAttachedContentNodeMediaFlags)?
            var actionIcon: ChatMessageAttachedContentActionIcon?
            var actionTitle: String?
            
            if let webpage = webPageContent {
                let type = websiteType(of: webpage)
                
                if let websiteName = webpage.websiteName, !websiteName.isEmpty {
                    title = websiteName
                }
                
                if let title = webpage.title, !title.isEmpty {
                    subtitle = title
                }
                
                if let textValue = webpage.text, !textValue.isEmpty {
                    text = textValue
                    var entityTypes: EnabledEntityTypes = [.url]
                    switch type {
                        case .twitter, .instagram:
                            entityTypes.insert(.mention)
                        default:
                            break
                    }
                    entities = generateTextEntities(textValue, enabledTypes: entityTypes)
                }
                
                var mainMedia: Media?
                
                switch type {
                    case .instagram, .twitter:
                        mainMedia = webpage.image
                    default:
                        mainMedia = webpage.file ?? webpage.image
                }
                
                if let file = mainMedia as? TelegramMediaFile {
                    if let image = webpage.image, let embedUrl = webpage.embedUrl, !embedUrl.isEmpty {
                        mediaAndFlags = (image, [.preferMediaBeforeText])
                    } else {
                        mediaAndFlags = (file, [])
                    }
                } else if let image = mainMedia as? TelegramMediaImage {
                    if let type = webpage.type, ["photo", "video", "embed", "article"].contains(type) {
                        var flags = ChatMessageAttachedContentNodeMediaFlags()
                        if webpage.instantPage != nil, let largest = largestImageRepresentation(image.representations) {
                            if largest.dimensions.width >= 256.0 {
                                flags.insert(.preferMediaBeforeText)
                            }
                        } else if let embedUrl = webpage.embedUrl, !embedUrl.isEmpty {
                            flags.insert(.preferMediaBeforeText)
                        }
                        mediaAndFlags = (image, flags)
                    } else if let _ = largestImageRepresentation(image.representations)?.dimensions {
                        mediaAndFlags = (image, [.preferMediaInline])
                    }
                }
                
                if let _ = webpage.instantPage {
                    switch type {
                        case .twitter, .instagram:
                            break
                        default:
                            actionIcon = .instant
                            actionTitle = item.presentationData.strings.Conversation_InstantPagePreview
                    }
                } else if let type = webpage.type {
                    switch type {
                        case "telegram_channel":
                            actionTitle = item.presentationData.strings.Conversation_ViewChannel
                        case "telegram_chat":
                            actionTitle = item.presentationData.strings.Conversation_ViewGroup
                        case "telegram_message":
                            actionTitle = item.presentationData.strings.Conversation_ViewMessage
                        default:
                            break
                    }
                }
            }
            
            let (initialWidth, continueLayout) = contentNodeLayout(item.presentationData, item.controllerInteraction.automaticMediaDownloadSettings, item.account, item.message, item.read, title, subtitle, text, entities, mediaAndFlags, actionIcon, actionTitle, true, layoutConstants, constrainedSize)
            
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 8.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, initialWidth, { constrainedSize, position in
                let (refinedWidth, finalizeLayout) = continueLayout(constrainedSize, position)
                
                return (refinedWidth, { boundingWidth in
                    let (size, apply) = finalizeLayout(boundingWidth)
                    
                    return (size, { [weak self] animation in
                        if let strongSelf = self {
                            strongSelf.item = item
                            strongSelf.webPage = webPage
                            
                            apply(animation)
                            
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
    
    override func tapActionAtPoint(_ point: CGPoint) -> ChatMessageBubbleContentTapAction {
        if self.bounds.contains(point) {
            let contentNodeFrame = self.contentNode.frame
            let result = self.contentNode.tapActionAtPoint(point.offsetBy(dx: -contentNodeFrame.minX, dy: -contentNodeFrame.minY))
            switch result {
                case .none:
                    break
                case let .textMention(value):
                    if let webPage = self.webPage, case let .Loaded(content) = webPage.content {
                        var mention = value
                        if mention.hasPrefix("@") {
                            mention = String(mention[mention.index(after: mention.startIndex)...])
                        }
                        switch websiteType(of: content) {
                            case .twitter:
                                return .url("https://twitter.com/\(mention)")
                            case .instagram:
                                return .url("https://instagram.com/\(mention)")
                            default:
                                break
                        }
                    }
                default:
                    return result
            }
            
            if let webPage = self.webPage, case let .Loaded(content) = webPage.content {
                if content.instantPage != nil {
                    return .instantPage
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
            for item in media {
                if let webpage = item as? TelegramMediaWebpage, let current = self.webPage, webpage.isEqual(current) {
                    var mediaList: [Media] = [webpage]
                    if case let .Loaded(content) = webpage.content {
                        if let image = content.image {
                            mediaList.append(image)
                        }
                        if let file = content.file {
                            mediaList.append(file)
                        }
                    }
                    updatedMedia = mediaList
                }
            }
            return self.contentNode.updateHiddenMedia(updatedMedia)
        } else {
            return self.contentNode.updateHiddenMedia(nil)
        }
    }
    
    override func transitionNode(messageId: MessageId, media: Media) -> (ASDisplayNode, () -> UIView?)? {
        if self.item?.message.id != messageId {
            return nil
        }
        
        if let result = self.contentNode.transitionNode(media: media) {
            return result
        }
        if let webpage = media as? TelegramMediaWebpage, let current = self.webPage, webpage.isEqual(current) {
            if case let .Loaded(content) = webpage.content {
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
}
