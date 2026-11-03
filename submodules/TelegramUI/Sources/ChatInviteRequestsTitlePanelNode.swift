import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import LocalizedPeerData
import TelegramStringFormatting
import TelegramNotices
import AnimatedAvatarSetNode
import AccountContext
import ChatPresentationInterfaceState
import LegacyChatHeaderPanelComponent

final class ChatInviteRequestsTitlePanelNode: ChatTitleAccessoryPanelNode {
    private final class Params {
        let width: CGFloat
        let leftInset: CGFloat
        let rightInset: CGFloat
        let interfaceState: ChatPresentationInterfaceState

        init(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, interfaceState: ChatPresentationInterfaceState) {
            self.width = width
            self.leftInset = leftInset
            self.rightInset = rightInset
            self.interfaceState = interfaceState
        }
    }
    
    private let context: AccountContext
    
    private let separatorNode: ASDisplayNode
    
    private let closeButton: HighlightableButtonNode
    private let button: HighlightableButtonNode
    private let buttonTitle: ImmediateTextNode
    
    private let avatarsContext: AnimatedAvatarSetContext
    private var avatarsContent: AnimatedAvatarSetContext.Content?
    private let avatarsNode: AnimatedAvatarSetNode
    
    private let activateAreaNode: AccessibilityAreaNode
    
    private var theme: PresentationTheme?
    
    private var peerId: EnginePeer.Id?
    private var peers: [EnginePeer] = []
    private var count: Int32 = 0
    
    private var params: Params?
    
    init(context: AccountContext) {
        self.context = context
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
        
        self.button = HighlightableButtonNode()
        self.buttonTitle = ImmediateTextNode()
        self.buttonTitle.anchorPoint = CGPoint()
        
        self.avatarsContext = AnimatedAvatarSetContext()
        self.avatarsNode = AnimatedAvatarSetNode()
        
        self.activateAreaNode = AccessibilityAreaNode()
        self.activateAreaNode.accessibilityTraits = .button
        
        super.init()

        self.addSubnode(self.separatorNode)
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.addSubnode(self.button)
        
        self.buttonTitle.isUserInteractionEnabled = false
        self.button.addSubnode(self.buttonTitle)
        
        self.addSubnode(self.avatarsNode)
        
        self.addSubnode(self.activateAreaNode)
    }
    

    func update(peerId: EnginePeer.Id, peers: [EnginePeer], count: Int32) {
        self.peerId = peerId
        self.peers = peers
        self.count = count
        
        self.avatarsContent = self.avatarsContext.update(peers: peers, animated: false)
        
        if let params = self.params {
            let _ = self.updateLayout(width: params.width, leftInset: params.leftInset, rightInset: params.rightInset, transition: .immediate, interfaceState: params.interfaceState)
        }
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        self.params = Params(width: width, leftInset: leftInset, rightInset: rightInset, interfaceState: interfaceState)
        
        if interfaceState.theme !== self.theme {
            self.theme = interfaceState.theme
            
            self.closeButton.setImage(generateImage(CGSize(width: 12.0, height: 12.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setStrokeColor(interfaceState.theme.chat.inputPanel.panelControlColor.cgColor)
                context.setLineWidth(1.33)
                context.setLineCap(.round)
                context.move(to: CGPoint(x: 1.0, y: 1.0))
                context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - 1.0))
                context.strokePath()
                context.move(to: CGPoint(x: size.width - 1.0, y: 1.0))
                context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
                context.strokePath()
            }), for: [])
            self.separatorNode.backgroundColor = interfaceState.theme.rootController.navigationBar.separatorColor
        }

        let panelHeight: CGFloat = 40.0
        
        let contentRightInset: CGFloat = 14.0 + rightInset
        
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(x: width - contentRightInset - closeButtonSize.width - 3.0, y: floorToScreenPixels((panelHeight - closeButtonSize.height) / 2.0)), size: closeButtonSize))
        
        self.buttonTitle.attributedText = NSAttributedString(string: interfaceState.strings.Conversation_RequestsToJoin(self.count), font: Font.medium(15.0), textColor: interfaceState.theme.chat.inputPanel.panelControlColor)
        
        transition.updateFrame(node: self.button, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: panelHeight)))
        
        let titleSize = self.buttonTitle.updateLayout(CGSize(width: width - leftInset - 90.0 - contentRightInset, height: 100.0))
        var buttonTitleFrame = CGRect(origin: CGPoint(x: leftInset + floor((width - leftInset - titleSize.width) * 0.5), y: floor((panelHeight - titleSize.height) * 0.5) + 1.0), size: titleSize)
        buttonTitleFrame.origin.x = max(buttonTitleFrame.minX, leftInset + 90.0)
        transition.updatePosition(node: self.buttonTitle, position: buttonTitleFrame.origin)
        self.buttonTitle.bounds = CGRect(origin: CGPoint(), size: buttonTitleFrame.size)
        
        let initialPanelHeight = panelHeight
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        
        if let avatarsContent = self.avatarsContent {
            let avatarsSize = self.avatarsNode.update(context: self.context, content: avatarsContent, itemSize: CGSize(width: 32.0, height: 32.0), animated: true, synchronousLoad: true)
            transition.updateFrame(node: self.avatarsNode, frame: CGRect(origin: CGPoint(x: leftInset + 4.0, y: floor((panelHeight - avatarsSize.height) / 2.0)), size: avatarsSize))
        }
        
        self.activateAreaNode.frame = CGRect(origin: .zero, size: CGSize(width: width, height: panelHeight))
        self.activateAreaNode.accessibilityLabel = interfaceState.strings.Conversation_RequestsToJoin(self.count)
        
        return LayoutResult(backgroundHeight: initialPanelHeight, insetHeight: panelHeight, hitTestSlop: 0.0)
    }
    
    @objc func buttonPressed() {
        self.interfaceInteraction?.openInviteRequests()
    }
    
    @objc func closePressed() {
        guard let peerId = self.peerId else {
            return
        }

        let ids = peers.map { $0.id.toInt64() }
        let _ = ApplicationSpecificNotice.setDismissedInvitationRequests(accountManager: context.sharedContext.accountManager, peerId: peerId, values: ids).startStandalone()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.closeButton.hitTest(CGPoint(x: point.x - self.closeButton.frame.minX, y: point.y - self.closeButton.frame.minY), with: event) {
            return result
        }
        return super.hitTest(point, with: event)
    }
}
