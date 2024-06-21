import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import LocalizedPeerData
import PhotoResources
import TelegramStringFormatting
import TextFormat
import TextNodeWithEntities
import AnimationCache
import MultiAnimationRenderer
import ComponentFlow
import ChatControllerInteraction

public class ChatMessageUnlockMediaNode: ASDisplayNode {
    public class Arguments {
        public let presentationData: ChatPresentationData
        public let strings: PresentationStrings
        public let context: AccountContext
        public let controllerInteraction: ChatControllerInteraction
        public let message: Message
        public let media: TelegramMediaPaidContent
        public let constrainedSize: CGSize
        public let animationCache: AnimationCache?
        public let animationRenderer: MultiAnimationRenderer?
        
        public init(
            presentationData: ChatPresentationData,
            strings: PresentationStrings,
            context: AccountContext,
            controllerInteraction: ChatControllerInteraction,
            message: Message,
            media: TelegramMediaPaidContent,
            constrainedSize: CGSize,
            animationCache: AnimationCache?,
            animationRenderer: MultiAnimationRenderer?
        ) {
            self.presentationData = presentationData
            self.strings = strings
            self.context = context
            self.controllerInteraction = controllerInteraction
            self.message = message
            self.media = media
            self.constrainedSize = constrainedSize
            self.animationCache = animationCache
            self.animationRenderer = animationRenderer
        }
    }
    
    public var visibility: Bool = false {
        didSet {
            if self.visibility != oldValue {
                self.textNode?.visibilityRect = self.visibility ? CGRect.infinite : nil
            }
        }
    }
        
    private let contentNode: HighlightTrackingButtonNode
    private let backgroundNode: NavigationBackgroundNode
    private var textNode: TextNodeWithEntities?
    
    private var pressed = { }
    
    private var absolutePosition: (CGRect, CGSize)?
    
    override public init() {
        self.contentNode = HighlightTrackingButtonNode()
        
        self.backgroundNode = NavigationBackgroundNode(color: UIColor(rgb: 0x000000, alpha: 0.3))
        
        super.init()
        
        self.contentNode.isUserInteractionEnabled = true
        
        self.addSubnode(self.contentNode)
        self.contentNode.addSubnode(self.backgroundNode)
        
//        self.contentNode.highligthedChanged = { [weak self] highlighted in
//            if let strongSelf = self {
//                if highlighted, !strongSelf.frame.width.isZero {
//                    let scale = (strongSelf.frame.width - 10.0) / strongSelf.frame.width
//                    
//                    strongSelf.contentNode.layer.animateScale(from: 1.0, to: scale, duration: 0.15, removeOnCompletion: false)
//                    
//                    strongSelf.backgroundNode.layer.removeAnimation(forKey: "opacity")
//                    strongSelf.backgroundNode.alpha = 0.2
//                } else if let presentationLayer = strongSelf.contentNode.layer.presentation() {
//                    strongSelf.contentNode.layer.animateScale(from: CGFloat((presentationLayer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0), to: 1.0, duration: 0.25, removeOnCompletion: false)
//                    
//                    strongSelf.backgroundNode.alpha = 1.0
//                    strongSelf.backgroundNode.layer.animateAlpha(from: 0.2, to: 1.0, duration: 0.2)
//                }
//            }
//        }
        
        self.contentNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func buttonPressed() {
        self.pressed()
    }
    
    public class func asyncLayout(_ maybeNode: ChatMessageUnlockMediaNode?) -> (_ arguments: Arguments) -> (CGSize, (Bool) -> ChatMessageUnlockMediaNode) {
        let textNodeLayout = TextNodeWithEntities.asyncLayout(maybeNode?.textNode)
    
        return { arguments in
            let fontSize = floor(arguments.presentationData.fontSize.baseDisplaySize * 14.0 / 17.0)
            let textFont = Font.medium(fontSize)
                           
            let padding: CGFloat = 10.0
            //TODO:localize
            let text = NSMutableAttributedString(string: "Unlock for ⭐️ \(arguments.media.amount)", font: textFont, textColor: .white)
            if let range = text.string.range(of: "⭐️") {
                text.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: NSRange(range, in: text.string))
                text.addAttribute(.baselineOffset, value: 0.5, range: NSRange(range, in: text.string))
            }
            
            let (textLayout, textApply) = textNodeLayout(TextNodeLayoutArguments(attributedString: text, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: arguments.constrainedSize.width, height: arguments.constrainedSize.height), alignment: .natural, cutout: nil, insets: .zero))
            
            let size = CGSize(width: textLayout.size.width + padding * 2.0, height: 32.0)
            
            return (size, { attemptSynchronous in
                let node: ChatMessageUnlockMediaNode
                if let maybeNode = maybeNode {
                    node = maybeNode
                } else {
                    node = ChatMessageUnlockMediaNode()
                }
                
                node.pressed = {
                    let _ = arguments.controllerInteraction.openMessage(arguments.message, OpenMessageParams(mode: .default))
                }
                                 
                node.textNode?.textNode.displaysAsynchronously = !arguments.presentationData.isPreview
                
                var textArguments: TextNodeWithEntities.Arguments?
                if let cache = arguments.animationCache, let renderer = arguments.animationRenderer {
                    textArguments = TextNodeWithEntities.Arguments(context: arguments.context, cache: cache, renderer: renderer, placeholderColor: .clear, attemptSynchronous: attemptSynchronous)
                }
                let textNode = textApply(textArguments)
                textNode.visibilityRect = node.visibility ? CGRect.infinite : nil
                
                if node.textNode == nil {
                    textNode.textNode.isUserInteractionEnabled = false
                    node.textNode = textNode
                    node.contentNode.addSubnode(textNode.textNode)
                }
                
                let textFrame = CGRect(origin: CGPoint(x: padding, y: floorToScreenPixels((size.height - textLayout.size.height) / 2.0)), size: textLayout.size)
                textNode.textNode.frame = textFrame
                 
                node.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
                node.backgroundNode.update(size: size, cornerRadius: size.height / 2.0, transition: .immediate)
                node.contentNode.frame = CGRect(origin: CGPoint(), size: size)
                
                return node
            })
        }
    }
}
