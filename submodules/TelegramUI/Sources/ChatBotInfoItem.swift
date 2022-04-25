import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TextFormat
import UrlEscaping
import PhotoResources
import AccountContext

private let messageFont = Font.regular(17.0)
private let messageBoldFont = Font.semibold(17.0)
private let messageItalicFont = Font.italic(17.0)
private let messageBoldItalicFont = Font.semiboldItalic(17.0)
private let messageFixedFont = UIFont(name: "Menlo-Regular", size: 16.0) ?? UIFont.systemFont(ofSize: 17.0)

final class ChatBotInfoItem: ListViewItem {
    fileprivate let title: String
    fileprivate let text: String
    fileprivate let photo: TelegramMediaImage?
    fileprivate let controllerInteraction: ChatControllerInteraction
    fileprivate let presentationData: ChatPresentationData
    fileprivate let context: AccountContext
    
    init(title: String, text: String, photo: TelegramMediaImage?, controllerInteraction: ChatControllerInteraction, presentationData: ChatPresentationData, context: AccountContext) {
        self.title = title
        self.text = text
        self.photo = photo
        self.controllerInteraction = controllerInteraction
        self.presentationData = presentationData
        self.context = context
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let configure = {
            let node = ChatBotInfoItemNode()
            
            let nodeLayout = node.asyncLayout()
            let (layout, apply) = nodeLayout(self, params)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(.None) })
                })
            }
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ChatBotInfoItemNode {
                let nodeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = nodeLayout(self, params)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation)
                        })
                    }
                }
            }
        }
    }
}

final class ChatBotInfoItemNode: ListViewItemNode {
    var controllerInteraction: ChatControllerInteraction?
    
    let offsetContainer: ASDisplayNode
    let backgroundNode: ASImageNode
    let imageNode: TransformImageNode
    let titleNode: TextNode
    let textNode: TextNode
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private let fetchDisposable = MetaDisposable()
    
    var currentTextAndEntities: (String, [MessageTextEntity])?
    
    private var theme: ChatPresentationThemeData?
    
    private var item: ChatBotInfoItem?
    
    init() {
        self.offsetContainer = ASDisplayNode()
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.imageNode = TransformImageNode()
        self.textNode = TextNode()
        self.titleNode = TextNode()
        
        super.init(layerBacked: false, dynamicBounce: true, rotated: true)
        
        self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        
        self.addSubnode(self.offsetContainer)
        self.offsetContainer.addSubnode(self.backgroundNode)
        self.offsetContainer.addSubnode(self.imageNode)
        self.offsetContainer.addSubnode(self.titleNode)
        self.offsetContainer.addSubnode(self.textNode)
        self.wantsTrailingItemSpaceUpdates = true
    }
    
    deinit {
        self.fetchDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            if let strongSelf = self {
                let tapAction = strongSelf.tapActionAtPoint(point, gesture: .tap, isEstimating: true)
                switch tapAction {
                    case .none:
                        break
                    case .ignore:
                        return .fail
                    case .url, .peerMention, .textMention, .botCommand, .hashtag, .instantPage, .wallpaper, .theme, .call, .openMessage, .timecode, .bankCard, .tooltip, .openPollResults, .copy, .largeEmoji:
                        return .waitForSingleTap
                }
            }
            
            return .waitForDoubleTap
        }
        recognizer.highlight = { [weak self] point in
            if let strongSelf = self {
                strongSelf.updateTouchesAtPoint(point)
            }
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    func asyncLayout() -> (_ item: ChatBotInfoItem, _ width: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeImageLayout = self.imageNode.asyncLayout()
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let currentTextAndEntities = self.currentTextAndEntities
        let currentTheme = self.theme
        
        let currentItem = self.item
        
        return { [weak self] item, params in
            self?.item = item
            
            var updatedBackgroundImage: UIImage?
            if currentTheme != item.presentationData.theme {
                updatedBackgroundImage = PresentationResourcesChat.chatInfoItemBackgroundImage(item.presentationData.theme.theme, wallpaper: !item.presentationData.theme.wallpaper.isEmpty)
            }
                        
            var updatedTextAndEntities: (String, [MessageTextEntity])
            if let (text, entities) = currentTextAndEntities {
                if text == item.text {
                    updatedTextAndEntities = (text, entities)
                } else {
                    updatedTextAndEntities = (item.text, generateTextEntities(item.text, enabledTypes: .all))
                }
            } else {
                updatedTextAndEntities = (item.text, generateTextEntities(item.text, enabledTypes: .all))
            }
            
            let attributedText = stringWithAppliedEntities(updatedTextAndEntities.0, entities: updatedTextAndEntities.1, baseColor: item.presentationData.theme.theme.chat.message.infoPrimaryTextColor, linkColor: item.presentationData.theme.theme.chat.message.infoLinkTextColor, baseFont: messageFont, linkFont: messageFont, boldFont: messageBoldFont, italicFont: messageItalicFont, boldItalicFont: messageBoldItalicFont, fixedFont: messageFixedFont, blockQuoteFont: messageFont)
            
            let horizontalEdgeInset: CGFloat = 10.0 + params.leftInset
            let horizontalContentInset: CGFloat = 12.0
            let verticalItemInset: CGFloat = 10.0
            let verticalContentInset: CGFloat = 8.0
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: messageBoldFont, textColor: item.presentationData.theme.theme.chat.message.infoPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - horizontalEdgeInset * 2.0 - horizontalContentInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - horizontalEdgeInset * 2.0 - horizontalContentInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let textSpacing: CGFloat = 1.0
            let textSize = CGSize(width: max(titleLayout.size.width, textLayout.size.width), height: (titleLayout.size.height + (titleLayout.size.width.isZero ? 0.0 : textSpacing) + textLayout.size.height))
            
            var mediaUpdated = false
            if let media = item.photo {
                if let currentMedia = currentItem?.photo {
                    mediaUpdated = !media.isSemanticallyEqual(to: currentMedia)
                } else {
                    mediaUpdated = true
                }
            }
            
            var updatedImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?

            var imageSize = CGSize()
            var imageDimensions = CGSize()
            var imageApply: (() -> Void)?
            let imageInset: CGFloat = 1.0 + UIScreenPixel
            if let image = item.photo, let dimensions = largestImageRepresentation(image.representations)?.dimensions {
                imageDimensions = dimensions.cgSize.aspectFitted(CGSize(width: textSize.width + horizontalContentInset * 2.0 - imageInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
                imageSize = imageDimensions
                imageSize.height += 4.0
                
                let arguments = TransformImageArguments(corners: ImageCorners(topLeft: .Corner(17.0), topRight: .Corner(17.0), bottomLeft: .Corner(0.0), bottomRight: .Corner(0.0)), imageSize: dimensions.cgSize.aspectFilled(imageDimensions), boundingSize: imageDimensions, intrinsicInsets: UIEdgeInsets(), emptyColor: item.presentationData.theme.theme.list.mediaPlaceholderColor)
                imageApply = makeImageLayout(arguments)
                
                if mediaUpdated {
                    updatedImageSignal = chatMessagePhoto(postbox: item.context.account.postbox, photoReference: .standalone(media: image), synchronousLoad: true, highQuality: false)
                }
            }
            
            let backgroundFrame = CGRect(origin: CGPoint(x: floor((params.width - textSize.width - horizontalContentInset * 2.0) / 2.0), y: verticalItemInset + 4.0), size: CGSize(width: textSize.width + horizontalContentInset * 2.0, height: imageSize.height + textSize.height + verticalContentInset * 2.0))
            let titleFrame = CGRect(origin: CGPoint(x: backgroundFrame.origin.x + horizontalContentInset, y: backgroundFrame.origin.y + imageSize.height + verticalContentInset), size: titleLayout.size)
            let textFrame = CGRect(origin: CGPoint(x: backgroundFrame.origin.x + horizontalContentInset, y: backgroundFrame.origin.y + imageSize.height + verticalContentInset + titleLayout.size.height + (titleLayout.size.width.isZero ? 0.0 : textSpacing)), size: textLayout.size)
            let imageFrame = CGRect(origin: CGPoint(x: backgroundFrame.origin.x + imageInset, y: backgroundFrame.origin.y + imageInset), size: imageDimensions)
            
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: imageSize.height + textLayout.size.height + verticalItemInset * 2.0 + verticalContentInset * 2.0 + titleLayout.size.height + (titleLayout.size.width.isZero ? 0.0 : textSpacing) - 3.0), insets: UIEdgeInsets())
            return (itemLayout, { _ in
                if let strongSelf = self {
                    strongSelf.theme = item.presentationData.theme
                    
                    if let updatedBackgroundImage = updatedBackgroundImage {
                        strongSelf.backgroundNode.image = updatedBackgroundImage
                    }
                    
                    strongSelf.controllerInteraction = item.controllerInteraction
                    strongSelf.currentTextAndEntities = updatedTextAndEntities
                    
                    
                    if let imageApply = imageApply {
                        let _ = imageApply()
                        if let updatedImageSignal = updatedImageSignal {
                            strongSelf.imageNode.setSignal(updatedImageSignal)
                            if let image = item.photo {
                                strongSelf.fetchDisposable.set(chatMessagePhotoInteractiveFetched(context: item.context, photoReference: .standalone(media: image), displayAtSize: nil, storeToDownloadsPeerType: nil).start())
                            }
                        }
                        strongSelf.imageNode.isHidden = false
                    } else {
                        strongSelf.imageNode.isHidden = true
                    }
                    strongSelf.imageNode.frame = imageFrame
                    
                    let _ = titleApply()
                    let _ = textApply()
                    strongSelf.offsetContainer.frame = CGRect(origin: CGPoint(), size: itemLayout.contentSize)
                    strongSelf.backgroundNode.frame = backgroundFrame
                    strongSelf.titleNode.frame = titleFrame
                    strongSelf.textNode.frame = textFrame
                }
            })
        }
    }
    
    override func updateTrailingItemSpace(_ height: CGFloat, transition: ContainedViewLayoutTransition) {
        if height.isLessThanOrEqualTo(0.0) {
            transition.updateFrame(node: self.offsetContainer, frame: CGRect(origin: CGPoint(), size: self.offsetContainer.bounds.size))
        } else {
            transition.updateFrame(node: self.offsetContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: -floorToScreenPixels(height / 2.0)), size: self.offsetContainer.bounds.size))
        }
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let result = super.point(inside: point, with: event)
        let extra = self.offsetContainer.frame.contains(point)
        return result || extra
    }
    
    func updateTouchesAtPoint(_ point: CGPoint?) {
        if let item = self.item {
            var rects: [CGRect]?
            if let point = point {
                let textNodeFrame = self.textNode.frame
                if let (index, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - self.offsetContainer.frame.minX - textNodeFrame.minX, y: point.y - self.offsetContainer.frame.minY - textNodeFrame.minY)) {
                    let possibleNames: [String] = [
                        TelegramTextAttributes.URL,
                        TelegramTextAttributes.PeerMention,
                        TelegramTextAttributes.PeerTextMention,
                        TelegramTextAttributes.BotCommand,
                        TelegramTextAttributes.Hashtag
                    ]
                    for name in possibleNames {
                        if let _ = attributes[NSAttributedString.Key(rawValue: name)] {
                            rects = self.textNode.attributeRects(name: name, at: index)
                            break
                        }
                    }
                }
            }
            
            if let rects = rects {
                let linkHighlightingNode: LinkHighlightingNode
                if let current = self.linkHighlightingNode {
                    linkHighlightingNode = current
                } else {
                    linkHighlightingNode = LinkHighlightingNode(color: item.presentationData.theme.theme.chat.message.incoming.linkHighlightColor)
                    self.linkHighlightingNode = linkHighlightingNode
                    self.offsetContainer.insertSubnode(linkHighlightingNode, belowSubnode: self.textNode)
                }
                linkHighlightingNode.frame = self.textNode.frame
                linkHighlightingNode.updateRects(rects)
            } else if let linkHighlightingNode = self.linkHighlightingNode {
                self.linkHighlightingNode = nil
                linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                    linkHighlightingNode?.removeFromSupernode()
                })
            }
        }
    }
    
    func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        let textNodeFrame = self.textNode.frame
        if let (index, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - self.offsetContainer.frame.minX - textNodeFrame.minX, y: point.y - self.offsetContainer.frame.minY - textNodeFrame.minY)) {
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let (attributeText, fullText) = self.textNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                    concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                }
                return .url(url: url, concealed: concealed)
            } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                return .peerMention(peerMention.peerId, peerMention.mention)
            } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return .textMention(peerName)
            } else if let botCommand = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                return .botCommand(botCommand)
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return .hashtag(hashtag.peerName, hashtag.hashtag)
            } else {
                return .none
            }
        } else {
            return .none
        }
    }
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            let tapAction = self.tapActionAtPoint(location, gesture: gesture, isEstimating: false)
                            switch tapAction {
                                case .none, .ignore:
                                    break
                                case let .url(url, concealed):
                                    self.item?.controllerInteraction.openUrl(url, concealed, nil, nil)
                                case let .peerMention(peerId, _):
                                    self.item?.controllerInteraction.openPeer(peerId, .chat(textInputState: nil, subject: nil, peekData: nil), nil, nil)
                                case let .textMention(name):
                                    self.item?.controllerInteraction.openPeerMention(name)
                                case let .botCommand(command):
                                    self.item?.controllerInteraction.sendBotCommand(nil, command)
                                case let .hashtag(peerName, hashtag):
                                    self.item?.controllerInteraction.openHashtag(peerName, hashtag)
                                default:
                                    break
                            }
                        case .longTap, .doubleTap:
                            if let item = self.item, self.backgroundNode.frame.contains(location) {
                                let tapAction = self.tapActionAtPoint(location, gesture: gesture, isEstimating: false)
                                switch tapAction {
                                    case .none, .ignore:
                                        break
                                    case let .url(url, _):
                                        item.controllerInteraction.longTap(.url(url), nil)
                                    case let .peerMention(peerId, mention):
                                        item.controllerInteraction.longTap(.peerMention(peerId, mention), nil)
                                    case let .textMention(name):
                                        item.controllerInteraction.longTap(.mention(name), nil)
                                    case let .botCommand(command):
                                        item.controllerInteraction.longTap(.command(command), nil)
                                    case let .hashtag(_, hashtag):
                                        item.controllerInteraction.longTap(.hashtag(hashtag), nil)
                                    default:
                                        break
                                }
                            }
                        default:
                            break
                    }
                }
            default:
                break
        }
    }
}
