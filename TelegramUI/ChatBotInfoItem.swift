import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

private let messageFont: UIFont = UIFont.systemFont(ofSize: 17.0)
private let messageBoldFont: UIFont = UIFont.boldSystemFont(ofSize: 17.0)
private let messageItalicFont: UIFont = UIFont.italicSystemFont(ofSize: 17.0)
private let messageFixedFont: UIFont = UIFont(name: "Menlo-Regular", size: 16.0) ?? UIFont.systemFont(ofSize: 17.0)

final class ChatBotInfoItem: ListViewItem {
    fileprivate let text: String
    fileprivate let controllerInteraction: ChatControllerInteraction
    fileprivate let presentationData: ChatPresentationData
    
    init(text: String, controllerInteraction: ChatControllerInteraction, presentationData: ChatPresentationData) {
        self.text = text
        self.controllerInteraction = controllerInteraction
        self.presentationData = presentationData
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        let configure = {
            let node = ChatBotInfoItemNode()
            
            let nodeLayout = node.asyncLayout()
            let (layout, apply) = nodeLayout(self, params)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { apply(.None) })
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
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ChatBotInfoItemNode {
                let nodeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = nodeLayout(self, params)
                    Queue.mainQueue().async {
                        completion(layout, {
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
    let textNode: TextNode
    
    var currentTextAndEntities: (String, [MessageTextEntity])?
    
    private var theme: ChatPresentationThemeData?
    
    private var item: ChatBotInfoItem?
    
    init() {
        self.offsetContainer = ASDisplayNode()
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.textNode = TextNode()
        
        super.init(layerBacked: false, dynamicBounce: true, rotated: true)
        
        self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        
        self.addSubnode(self.offsetContainer)
        self.offsetContainer.addSubnode(self.backgroundNode)
        self.offsetContainer.addSubnode(self.textNode)
        self.wantsTrailingItemSpaceUpdates = true
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapGesture(_:))))
    }
    
    func asyncLayout() -> (_ item: ChatBotInfoItem, _ width: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let currentTextAndEntities = self.currentTextAndEntities
        let currentTheme = self.theme
        return { [weak self] item, params in
            self?.item = item
            
            var updatedBackgroundImage: UIImage?
            if currentTheme != item.presentationData.theme {
                //let principalGraphics = PresentationResourcesChat.principalGraphics(item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper)
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
            
            let attributedText = stringWithAppliedEntities(updatedTextAndEntities.0, entities: updatedTextAndEntities.1, baseColor: item.presentationData.theme.theme.chat.bubble.infoPrimaryTextColor, linkColor: item.presentationData.theme.theme.chat.bubble.infoLinkTextColor, baseFont: messageFont, linkFont: messageFont, boldFont: messageBoldFont, italicFont: messageItalicFont, fixedFont: messageFixedFont)
            
            let horizontalEdgeInset: CGFloat = 10.0 + params.leftInset
            let horizontalContentInset: CGFloat = 12.0
            let verticalItemInset: CGFloat = 10.0
            let verticalContentInset: CGFloat = 8.0
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - horizontalEdgeInset * 2.0 - horizontalContentInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let backgroundFrame = CGRect(origin: CGPoint(x: floor((params.width - textLayout.size.width - horizontalContentInset * 2.0) / 2.0), y: verticalItemInset + 4.0), size: CGSize(width: textLayout.size.width + horizontalContentInset * 2.0, height: textLayout.size.height + verticalContentInset * 2.0))
            let textFrame = CGRect(origin: CGPoint(x: backgroundFrame.origin.x + horizontalContentInset, y: backgroundFrame.origin.y + verticalContentInset), size: textLayout.size)
            
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: textLayout.size.height + verticalItemInset * 2.0 + verticalContentInset * 2.0 + 4.0), insets: UIEdgeInsets())
            return (itemLayout, { _ in
                if let strongSelf = self {
                    strongSelf.theme = item.presentationData.theme
                    
                    if let updatedBackgroundImage = updatedBackgroundImage {
                        strongSelf.backgroundNode.image = updatedBackgroundImage
                    }
                    
                    strongSelf.controllerInteraction = item.controllerInteraction
                    strongSelf.currentTextAndEntities = updatedTextAndEntities
                    let _ = textApply()
                    strongSelf.offsetContainer.frame = CGRect(origin: CGPoint(), size: itemLayout.contentSize)
                    strongSelf.backgroundNode.frame = backgroundFrame
                    strongSelf.textNode.frame = textFrame
                }
            })
        }
    }
    
    override func updateTrailingItemSpace(_ height: CGFloat, transition: ContainedViewLayoutTransition) {
        if height.isLessThanOrEqualTo(0.0) {
            transition.updateBounds(node: self.offsetContainer, bounds: CGRect(origin: CGPoint(), size: self.offsetContainer.bounds.size))
        } else {
            transition.updateBounds(node: self.offsetContainer, bounds: CGRect(origin: CGPoint(x: 0.0, y: floor(height) / 2.0), size: self.offsetContainer.bounds.size))
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
    
    func tapActionAtPoint(_ point: CGPoint) -> ChatMessageBubbleContentTapAction {
        let textNodeFrame = self.textNode.frame
        if let (index, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
            if let url = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let attributeText = self.textNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                    concealed = !doesUrlMatchText(url: url, text: attributeText)
                }
                return .url(url: url, concealed: concealed)
            } else if let peerMention = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                return .peerMention(peerMention.peerId, peerMention.mention)
            } else if let peerName = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return .textMention(peerName)
            } else if let botCommand = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                return .botCommand(botCommand)
            } else if let hashtag = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return .hashtag(hashtag.peerName, hashtag.hashtag)
            } else {
                return .none
            }
        } else {
            return .none
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                var foundTapAction = false
                let tapAction = self.tapActionAtPoint(recognizer.location(in: self.view))
                switch tapAction {
                    case .none:
                        break
                    case let .url(url, concealed):
                        foundTapAction = true
                        if let controllerInteraction = self.controllerInteraction {
                            controllerInteraction.openUrl(url, concealed, nil)
                        }
                    case let .peerMention(peerId, _):
                        foundTapAction = true
                        if let controllerInteraction = self.controllerInteraction {
                            controllerInteraction.openPeer(peerId, .chat(textInputState: nil, messageId: nil), nil)
                        }
                    case let .textMention(name):
                        foundTapAction = true
                        if let controllerInteraction = self.controllerInteraction {
                            controllerInteraction.openPeerMention(name)
                        }
                    case let .botCommand(command):
                        foundTapAction = true
                        if let controllerInteraction = self.controllerInteraction {
                            controllerInteraction.sendBotCommand(nil, command)
                        }
                    default:
                        break
                }
                if !foundTapAction {
                    self.controllerInteraction?.clickThroughMessage()
                }
            default:
                break
        }
    }
}
