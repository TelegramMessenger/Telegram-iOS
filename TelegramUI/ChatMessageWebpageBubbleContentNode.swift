import Foundation
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore

final class ChatMessageWebpageBubbleContentNode: ChatMessageBubbleContentNode {
    private var item: ChatMessageItem?
    private var webPage: TelegramMediaWebpage?
    
    private let contentNode: ChatMessageAttachedContentNode
    
    override var properties: ChatMessageBubbleContentProperties {
        return ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 8.0)
    }
    
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
            if let strongSelf = self, let item = strongSelf.item, let controllerInteraction = strongSelf.controllerInteraction {
                controllerInteraction.openMessage(item.message.id)
            }
        }
        self.contentNode.activateAction = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item, let controllerInteraction = strongSelf.controllerInteraction {
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
                    controllerInteraction.openUrl(webpage.url)
                }
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ position: ChatMessageBubbleContentPosition, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))) {
        let contentNodeLayout = self.contentNode.asyncLayout()
        
        return { item, layoutConstants, position, constrainedSize in
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
            var mediaAndFlags: (Media, ChatMessageAttachedContentNodeMediaFlags)?
            var actionTitle: String?
            
            if let webpage = webPageContent {
                if let websiteName = webpage.websiteName, !websiteName.isEmpty {
                    title = websiteName
                }
                
                if let title = webpage.title, !title.isEmpty {
                    subtitle = title
                }
                
                if let textValue = webpage.text, !textValue.isEmpty {
                    text = textValue
                }
                
                if let file = webpage.file {
                    if let image = webpage.image, let embedUrl = webpage.embedUrl, !embedUrl.isEmpty {
                        mediaAndFlags = (image, [])
                    } else {
                        mediaAndFlags = (file, [])
                    }
                } else if let image = webpage.image {
                    if let type = webpage.type, ["photo", "video", "embed", "article"].contains(type) {
                        var flags = ChatMessageAttachedContentNodeMediaFlags()
                        if webpage.instantPage != nil, let largest = largestImageRepresentation(image.representations) {
                            if largest.dimensions.width >= 256.0 {
                                flags.insert(.preferMediaBeforeText)
                            }
                        }
                        mediaAndFlags = (image, flags)
                    } else if let _ = largestImageRepresentation(image.representations)?.dimensions {
                        mediaAndFlags = (image, [.preferMediaInline])
                    }
                }
                
                if let _ = webpage.instantPage {
                    actionTitle = item.strings.Conversation_InstantPagePreview
                } else if let type = webpage.type {
                    switch type {
                        case "telegram_channel":
                            actionTitle = item.strings.Conversation_ViewChannel
                        case "telegram_supergroup":
                            actionTitle = item.strings.Conversation_ViewGroup
                        default:
                            break
                    }
                }
            }
            
            let (initialWidth, continueLayout) = contentNodeLayout(item.theme, item.strings, item.controllerInteraction.automaticMediaDownloadSettings, item.account, item.message, item.read, title, subtitle, text, nil, mediaAndFlags, actionTitle, true, layoutConstants, position, constrainedSize)
            
            return (initialWidth, { constrainedSize in
                let (refinedWidth, finalizeLayout) = continueLayout(constrainedSize)
                
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
            if let webPage = self.webPage, case let .Loaded(content) = webPage.content {
                if content.instantPage != nil {
                    return .instantPage
                }
            }
            let contentNodeFrame = self.contentNode.frame
            if self.contentNode.hasActionAtPoint(point.offsetBy(dx: -contentNodeFrame.minX, dy: -contentNodeFrame.minY)) {
                return .ignore
            }
            return .none
        }
        return .none
    }
    
    override func updateHiddenMedia(_ media: [Media]?) {
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
            self.contentNode.updateHiddenMedia(updatedMedia)
        } else {
            self.contentNode.updateHiddenMedia(nil)
        }
    }
    
    override func transitionNode(media: Media) -> ASDisplayNode? {
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
}
