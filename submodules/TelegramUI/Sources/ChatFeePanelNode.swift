import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import TelegramStringFormatting
import TextFormat
import ChatPresentationInterfaceState
import TextNodeWithEntities
import ChatControllerInteraction

final class ChatFeePanelNode: ASDisplayNode {
    private let context: AccountContext
    
    var controllerInteraction: ChatControllerInteraction?
    
    private let contextContainer: ContextControllerSourceNode
    private let clippingContainer: ASDisplayNode
    private let contentContainer: ASDisplayNode
    
    private let textNode: ImmediateTextNodeWithEntities
    
    private let removeButtonNode: HighlightTrackingButtonNode
    private let removeTextNode: ImmediateTextNode
        
    private let separatorNode: ASDisplayNode

    private var currentLayout: (CGFloat, CGFloat, CGFloat)?
    
    init(context: AccountContext) {
        self.context = context
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.contextContainer = ContextControllerSourceNode()
        
        self.clippingContainer = ASDisplayNode()
        self.clippingContainer.clipsToBounds = true
        
        self.contentContainer = ASDisplayNode()
        self.contextContainer.isGestureEnabled = false
                 
        self.textNode = ImmediateTextNodeWithEntities()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        self.removeButtonNode = HighlightTrackingButtonNode()
        
        self.removeTextNode = ImmediateTextNode()
        self.removeTextNode.displaysAsynchronously = false
        self.removeTextNode.isUserInteractionEnabled = false
    
        super.init()
                
        self.addSubnode(self.contextContainer)
        
        self.contextContainer.addSubnode(self.clippingContainer)
        self.clippingContainer.addSubnode(self.contentContainer)
                        
        self.contextContainer.addSubnode(self.textNode)
        self.contextContainer.addSubnode(self.removeTextNode)
        self.contextContainer.addSubnode(self.removeButtonNode)
        
        self.addSubnode(self.separatorNode)
        
        self.removeButtonNode.addTarget(self, action: #selector(self.removePressed), forControlEvents: [.touchUpInside])
        self.removeButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.removeTextNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.removeTextNode.alpha = 0.4
                } else {
                    strongSelf.removeTextNode.alpha = 1.0
                    strongSelf.removeTextNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }

    private var theme: PresentationTheme?
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        if self.theme !== interfaceState.theme {
            self.theme = interfaceState.theme
            self.separatorNode.backgroundColor = interfaceState.theme.rootController.navigationBar.separatorColor
            self.removeTextNode.attributedText = NSAttributedString(string: interfaceState.strings.Chat_PaidMessageFee_RemoveFee, font: Font.regular(17.0), textColor: interfaceState.theme.chat.inputPanel.panelControlAccentColor)
        }

        let paidMessageStars = interfaceState.contactStatus?.peerStatusSettings?.paidMessageStars?.value ?? 0
        
        if let peer = interfaceState.renderedPeer?.peer.flatMap(EnginePeer.init) {
            let attributedText = NSMutableAttributedString(string: interfaceState.strings.Chat_PaidMessageFee_Text(peer.compactDisplayTitle, "⭐️\(paidMessageStars)").string, font: Font.regular(12.0), textColor: interfaceState.theme.rootController.navigationBar.secondaryTextColor)
            let range = (attributedText.string as NSString).range(of: "⭐️")
            if range.location != NSNotFound {
                attributedText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: true)), range: range)
                attributedText.addAttribute(.baselineOffset, value: 0.0, range: range)
            }
            self.textNode.attributedText = attributedText
                        
            self.textNode.visibility = true
            self.textNode.arguments = TextNodeWithEntities.Arguments(
                context: self.context,
                cache: self.context.animationCache,
                renderer: self.context.animationRenderer,
                placeholderColor: UIColor(white: 1.0, alpha: 0.1),
                attemptSynchronous: false
            )
        }
                
        let sideInset = 16.0 + leftInset
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((width - textSize.width) / 2.0), y: 9.0), size: textSize))
        
        let removeSize = self.removeTextNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        let removeFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - removeSize.width) / 2.0), y: 33.0), size: removeSize)
        transition.updateFrame(node: self.removeTextNode, frame: removeFrame)
        transition.updateFrame(node: self.removeButtonNode, frame: removeFrame.insetBy(dx: -8.0, dy: -4.0))
        
        let panelHeight: CGFloat = 62.0
        
        self.contextContainer.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight))
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
                
        self.clippingContainer.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight))
        self.contentContainer.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight))
        
        self.currentLayout = (width, leftInset, rightInset)
        
        return panelHeight
    }
    
    @objc func removePressed() {
        self.controllerInteraction?.openMessageFeeException()
    }
}
