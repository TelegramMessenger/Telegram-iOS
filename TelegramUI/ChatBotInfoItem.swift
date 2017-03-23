import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

private let messageFont: UIFont = UIFont.systemFont(ofSize: 17.0)
private let messageBoldFont: UIFont = UIFont.boldSystemFont(ofSize: 17.0)
private let messageFixedFont: UIFont = UIFont(name: "Menlo-Regular", size: 16.0) ?? UIFont.systemFont(ofSize: 17.0)

final class ChatBotInfoItem: ListViewItem {
    fileprivate let text: String
    fileprivate let controllerInteraction: ChatControllerInteraction
    
    init(text: String, controllerInteraction: ChatControllerInteraction) {
        self.text = text
        self.controllerInteraction = controllerInteraction
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        let configure = {
            let node = ChatBotInfoItemNode()
            
            let nodeLayout = node.asyncLayout()
            let (layout, apply) = nodeLayout(self, width)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { apply(.None) })
            })
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? ChatBotInfoItemNode {
            Queue.mainQueue().async {
                let nodeLayout = node.asyncLayout()
                
                async {
                    let (layout, apply) = nodeLayout(self, width)
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

private let infoItemBackground = messageSingleBubbleLikeImage(incoming: true, highlighted: false)

final class ChatBotInfoItemNode: ListViewItemNode {
    var controllerInteraction: ChatControllerInteraction?
    
    let offsetContainer: ASDisplayNode
    let backgroundNode: ASImageNode
    let textNode: TextNode
    
    var currentTextAndEntities: (String, [MessageTextEntity])?
    
    init() {
        self.offsetContainer = ASDisplayNode()
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = infoItemBackground
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
    
    func asyncLayout() -> (_ item: ChatBotInfoItem, _ width: CGFloat) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let currentTextAndEntities = self.currentTextAndEntities
        return { [weak self] item, width in
            var updatedTextAndEntities: (String, [MessageTextEntity])
            if let (text, entities) = currentTextAndEntities {
                if text == item.text {
                    updatedTextAndEntities = (text, entities)
                } else {
                    updatedTextAndEntities = (item.text, generateTextEntities(item.text))
                }
            } else {
                updatedTextAndEntities = (item.text, generateTextEntities(item.text))
            }
            
            let attributedText = stringWithAppliedEntities(updatedTextAndEntities.0, entities: updatedTextAndEntities.1, baseFont: messageFont, boldFont: messageBoldFont, fixedFont: messageFixedFont)
            
            let horizontalEdgeInset: CGFloat = 10.0
            let horizontalContentInset: CGFloat = 12.0
            let verticalItemInset: CGFloat = 10.0
            let verticalContentInset: CGFloat = 8.0
            
            let (textLayout, textApply) = makeTextLayout(attributedText, nil, 0, .end, CGSize(width: width - horizontalEdgeInset * 2.0 - horizontalContentInset * 2.0, height: CGFloat.greatestFiniteMagnitude), .natural, nil)
            
            let backgroundFrame = CGRect(origin: CGPoint(x: floor((width - textLayout.size.width - horizontalContentInset * 2.0) / 2.0), y: verticalItemInset + 4.0), size: CGSize(width: textLayout.size.width + horizontalContentInset * 2.0, height: textLayout.size.height + verticalContentInset * 2.0))
            let textFrame = CGRect(origin: CGPoint(x: backgroundFrame.origin.x + horizontalContentInset, y: backgroundFrame.origin.y + verticalContentInset), size: textLayout.size)
            
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: width, height: textLayout.size.height + verticalItemInset * 2.0 + verticalContentInset * 2.0 + 4.0), insets: UIEdgeInsets())
            return (itemLayout, { _ in
                if let strongSelf = self {
                    strongSelf.controllerInteraction = item.controllerInteraction
                    strongSelf.currentTextAndEntities = updatedTextAndEntities
                    textApply()
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
        let attributes = self.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY))
        if let url = attributes[TextNode.UrlAttribute] as? String {
            return .url(url)
        } else if let peerId = attributes[TextNode.TelegramPeerMentionAttribute] as? NSNumber {
            return .peerMention(PeerId(peerId.int64Value))
        } else if let peerName = attributes[TextNode.TelegramPeerTextMentionAttribute] as? String {
            return .textMention(peerName)
        } else if let botCommand = attributes[TextNode.TelegramBotCommandAttribute] as? String {
            return .botCommand(botCommand)
        } else if let hashtag = attributes[TextNode.TelegramHashtagAttribute] as? TelegramHashtag {
            return .hashtag(hashtag.peerName, hashtag.hashtag)
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
                    case let .url(url):
                        foundTapAction = true
                        if let controllerInteraction = self.controllerInteraction {
                            controllerInteraction.openUrl(url)
                        }
                    case let .peerMention(peerId):
                        foundTapAction = true
                        if let controllerInteraction = self.controllerInteraction {
                            controllerInteraction.openPeer(peerId, .chat(textInputState: nil), nil)
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
