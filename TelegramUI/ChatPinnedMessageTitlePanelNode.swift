import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

final class ChatPinnedMessageTitlePanelNode: ChatTitleAccessoryPanelNode {
    private let account: Account
    private let tapButton: HighlightTrackingButtonNode
    private let closeButton: HighlightableButtonNode
    private let lineNode: ASImageNode
    private let titleNode: TextNode
    private let textNode: TextNode
    private let separatorNode: ASDisplayNode
    
    private let disposable = MetaDisposable()
    private var currentMessageId: MessageId?

    private var currentLayout: CGFloat?
    private var currentMessage: Message?

    private let queue = Queue()
    
    init(account: Account) {
        self.account = account
        
        self.tapButton = HighlightTrackingButtonNode()
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.hitTestSlop = UIEdgeInsetsMake(-8.0, -8.0, -8.0, -8.0)
        self.closeButton.displaysAsynchronously = false
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.lineNode = ASImageNode()
        self.lineNode.displayWithoutProcessing = true
        self.lineNode.displaysAsynchronously = false
        
        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = true
        self.titleNode.isLayerBacked = true
        
        self.textNode = TextNode()
        self.textNode.displaysAsynchronously = true
        self.textNode.isLayerBacked = true
        
        super.init()
        
        self.tapButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                    strongSelf.textNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.textNode.alpha = 0.4
                    strongSelf.lineNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.lineNode.alpha = 0.4
                } else {
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.textNode.alpha = 1.0
                    strongSelf.textNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.lineNode.alpha = 1.0
                    strongSelf.lineNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
        
        self.addSubnode(self.lineNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        
        self.tapButton.addTarget(self, action: #selector(self.tapped), forControlEvents: [.touchUpInside])
        self.addSubnode(self.tapButton)
        
        self.addSubnode(self.separatorNode)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    private var theme: PresentationTheme?
    
    override func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        let panelHeight: CGFloat = 50.0
        
        if self.theme !== interfaceState.theme {
            self.theme = interfaceState.theme
            self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(interfaceState.theme), for: [])
            self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(interfaceState.theme)
            self.backgroundColor = interfaceState.theme.rootController.navigationBar.backgroundColor
            self.separatorNode.backgroundColor = interfaceState.theme.rootController.navigationBar.separatorColor
        }
        
        if self.currentMessageId != interfaceState.pinnedMessageId {
            self.currentMessageId = interfaceState.pinnedMessageId
            if let pinnedMessageId = interfaceState.pinnedMessageId {
                self.disposable.set((singleMessageView(account: account, messageId: pinnedMessageId, loadIfNotExists: true)
                    |> deliverOnMainQueue).start(next: { [weak self] view in
                        if let strongSelf = self, let message = view.message {
                            strongSelf.currentMessage = message
                            if let currentLayout = strongSelf.currentLayout {
                                strongSelf.enqueueTransition(width: currentLayout, transition: .immediate, message: message, theme: interfaceState.theme, strings: interfaceState.strings)
                            }
                        }
                    }))
            }
        }
        
        let leftInset: CGFloat = 10.0
        let rightInset: CGFloat = 18.0
        
        transition.updateFrame(node: self.lineNode, frame: CGRect(origin: CGPoint(x: leftInset, y: 7.0), size: CGSize(width: 2.0, height: panelHeight - 14.0)))
        
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(x: width - rightInset - closeButtonSize.width, y: 19.0), size: closeButtonSize))
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        self.tapButton.frame = CGRect(origin: CGPoint(), size: CGSize(width: width - rightInset - closeButtonSize.width - 4.0, height: panelHeight))
        
        if self.currentLayout != width {
            self.currentLayout = width
            
            if let currentMessage = self.currentMessage {
                self.enqueueTransition(width: width, transition: .immediate, message: currentMessage, theme: interfaceState.theme, strings: interfaceState.strings)
            }
        }
        
        return panelHeight
    }
    
    private func enqueueTransition(width: CGFloat, transition: ContainedViewLayoutTransition, message: Message, theme: PresentationTheme, strings: PresentationStrings) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        queue.async { [weak self] in
            let leftInset: CGFloat = 10.0
            let textLineInset: CGFloat = 10.0
            let rightInset: CGFloat = 18.0
            let textRightInset: CGFloat = 25.0
            
            let (titleLayout, titleApply) = makeTitleLayout(NSAttributedString(string: strings.Conversation_PinnedMessage, font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlAccentColor), nil, 1, .end, CGSize(width: width - leftInset - rightInset - textRightInset, height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
            
            let (textLayout, textApply) = makeTextLayout(NSAttributedString(string: message.text, font: Font.regular(15.0), textColor: theme.chat.inputPanel.primaryTextColor), nil, 1, .end, CGSize(width: width - leftInset - rightInset - textRightInset, height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
            
            Queue.mainQueue().async {
                if let strongSelf = self {
                    let _ = titleApply()
                    let _ = textApply()
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset, y: 8.0), size: titleLayout.size)
                    
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset, y: 26.0), size: textLayout.size)
                }
            }
        }
    }
    
    @objc func tapped() {
        if let interfaceInteraction = self.interfaceInteraction, let message = self.currentMessage {
            interfaceInteraction.navigateToMessage(message.id)
        }
    }
    
    @objc func closePressed() {
        self.interfaceInteraction?.unpinMessage()
    }
}
